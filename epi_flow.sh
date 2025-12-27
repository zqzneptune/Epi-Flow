#!/bin/bash
set -euo pipefail
trap 'echo "[ERROR] Pipeline failed at line $LINENO"; exit 1' ERR

#######################################
# EPI-FLOW: Unified Chromatin Pipeline
# Refactored from prototype
#######################################

# --- ANSI Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# --- DEFAULTS ---
THREADS=8
MEM_GB=""
CLEAN_INTERMEDIATE=true
ADAPTER_SEQ="CTGTCTCTTATACACATCT"
EFFECTIVE_GENOME_SIZE=""
PEAK_MODE="narrow" # Default
ASSAY_TYPE=""      # Must be provided

# --- LOGGING ---
log_info()  { echo -e "${GREEN}[INFO] $(date '+%F %T') $1${NC}"; }
log_warn()  { echo -e "${YELLOW}[WARN] $(date '+%F %T') $1${NC}"; }
log_error() { echo -e "${RED}[ERROR] $(date '+%F %T') $1${NC}"; }
log_qc()    { echo "$1,$2" >> "${SUMMARY_QC}"; }

fail() { log_error "$1"; exit 1; }
check_tool() { command -v "$1" &>/dev/null || fail "Missing tool: $1"; }

# --- MEMORY DETECTION ---
get_memory_limit_bytes() {
    local mem=""
    if [[ -f /proc/meminfo ]]; then
        mem=$(awk '/MemTotal/ {print $2*1024}' /proc/meminfo)
    fi
    [[ -z "$mem" ]] && mem=$((32*1024*1024*1024))
    echo "$mem"
}

format_reads() {
    awk -v n="$1" 'BEGIN {
        if (n >= 1000000000) printf "%.2fG", n/1000000000;
        else if (n >= 1000000) printf "%.2fM", n/1000000;
        else if (n >= 1000) printf "%.2fK", n/1000;
        else print n
    }'
}


# --- USAGE ---
usage() {
    echo -e "${BLUE}Epi-Flow Usage:${NC}"
    echo "  -a  Assay Type [atac | cutrun | cuttag | chip]"
    echo "  -1  R1 fastq.gz (comma-separated)"
    echo "  -2  R2 fastq.gz (comma-separated, optional for ChIP)"
    echo "  -n  Sample name"
    echo "  -x  Bowtie2 index prefix"
    echo "  -o  Output directory"
    echo "  -g  Effective genome size (e.g., hs, mm, or integer)"
    echo "Optional:"
    echo "  -p  Peak mode [narrow | broad] (Default: narrow)"
    echo "  -t  Threads [8]"
    echo "  -m  Memory in GB"
    echo "  -b  Blacklist BED"
    echo "  --keep-tmp  Keep intermediate files"
    exit 1
}

# --- PARSE ARGUMENTS ---
R1_INPUT=""
R2_INPUT=""
SAMPLE=""
BOWTIE2_INDEX=""
BLACKLIST=""
OUTDIR=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -a) ASSAY_TYPE=$(echo "$2" | tr '[:upper:]' '[:lower:]'); shift 2 ;;
        -1) R1_INPUT="$2"; shift 2 ;;
        -2) R2_INPUT="$2"; shift 2 ;;
        -n) SAMPLE="$2"; shift 2 ;;
        -x) BOWTIE2_INDEX="$2"; shift 2 ;;
        -o) OUTDIR="$2"; shift 2 ;;
        -g) EFFECTIVE_GENOME_SIZE="$2"; shift 2 ;;
        -p) PEAK_MODE=$(echo "$2" | tr '[:upper:]' '[:lower:]'); shift 2 ;;
        -b) BLACKLIST="$2"; shift 2 ;;
        -t) THREADS="$2"; shift 2 ;;
        -m) MEM_GB="$2"; shift 2 ;;
        --keep-tmp) CLEAN_INTERMEDIATE=false; shift ;;
        *) usage ;;
    esac
done

# --- VALIDATION ---
[[ -z "${R1_INPUT}" || -z "${SAMPLE}" || -z "${BOWTIE2_INDEX}" || -z "${OUTDIR}" || -z "${EFFECTIVE_GENOME_SIZE}" || -z "${ASSAY_TYPE}" ]] && usage

# Valid Assays
if [[ ! "$ASSAY_TYPE" =~ ^(atac|cutrun|cuttag|chip)$ ]]; then
    fail "Invalid assay type: $ASSAY_TYPE. Choose: atac, cutrun, cuttag, chip"
fi

# Detect Paired-End
IS_PE=false
if [[ -n "${R2_INPUT}" ]]; then
    IS_PE=true
fi

# Assay Constraints
if [[ "$ASSAY_TYPE" == "atac" || "$ASSAY_TYPE" == "cutrun" || "$ASSAY_TYPE" == "cuttag" ]]; then
    if [[ "$IS_PE" == "false" ]]; then
        fail "Assay '$ASSAY_TYPE' requires Paired-End reads (R2 not provided)."
    fi
fi

# Check Dependencies
REQUIRED_TOOLS="fastqc cutadapt bowtie2 samtools picard bedtools macs3"
if [[ "$ASSAY_TYPE" == "atac" ]]; then
    REQUIRED_TOOLS="$REQUIRED_TOOLS alignmentSieve bamCoverage bamPEFragmentSize"
fi
# SEACR is a script, might not be in path as binary, checking usually tricky, assumed present for CUT
if [[ "$ASSAY_TYPE" =~ "cut" ]]; then
    REQUIRED_TOOLS="$REQUIRED_TOOLS SEACR_1.3.sh"
fi

for t in $REQUIRED_TOOLS; do check_tool "$t"; done

# --- RESOURCE SETUP ---
MAX_THREADS=$(nproc)
[[ "${THREADS}" -gt "$((MAX_THREADS-1))" ]] && THREADS=$((MAX_THREADS-1))
[[ "${THREADS}" -lt 1 ]] && THREADS=1

if [[ -n "${MEM_GB}" ]]; then
    TOTAL_MEM=$((MEM_GB*1024*1024*1024))
else
    TOTAL_MEM=$(get_memory_limit_bytes)
fi

# Calculations for Samtools/Picard
MEM_BYTES=$(( TOTAL_MEM * 80 / 100 / THREADS ))
[[ "${MEM_BYTES}" -lt 536870912 ]] && MEM_BYTES=536870912 # Min 512MB per thread
JAVA_MAX=$(( TOTAL_MEM * 70 / 100 ))
[[ "${JAVA_MAX}" -gt $((8*1024*1024*1024)) ]] && JAVA_MAX=$((8*1024*1024*1024)) # Cap Java at 8GB
export _JAVA_OPTIONS="-Xmx${JAVA_MAX}"

log_info "Configuration: Assay=${ASSAY_TYPE}, PE=${IS_PE}, Peak=${PEAK_MODE}, Threads=${THREADS}"

# --- DIRECTORIES ---
LOGDIR="${OUTDIR}/logs"
QCDIR="${OUTDIR}/qc"
FINALDIR="${OUTDIR}/final"
TMPDIR="${OUTDIR}/tmp"
PEAKDIR="${FINALDIR}/peaks"
mkdir -p "${LOGDIR}" "${QCDIR}" "${FINALDIR}" "${TMPDIR}" "${PEAKDIR}"
export TMPDIR

SUMMARY_QC="${QCDIR}/${SAMPLE}_summary_qc.csv"
echo "metric,value" > "$SUMMARY_QC"

# --- INPUT ARRAYS ---
IFS=',' read -r -a R1_FILES <<< "${R1_INPUT}"
if [[ "$IS_PE" == "true" ]]; then
    IFS=',' read -r -a R2_FILES <<< "${R2_INPUT}"
    [[ "${#R1_FILES[@]}" -eq "${#R2_FILES[@]}" ]] || fail "R1/R2 count mismatch"
fi

#######################################
# PIPELINE STEPS
#######################################

step_prepare() {
    log_info "Step: Pre-QC and Merging"
    
    local qc_inputs=("${R1_FILES[@]}")
    [[ "$IS_PE" == "true" ]] && qc_inputs+=("${R2_FILES[@]}")
    
    fastqc -t "${THREADS}" -o "${QCDIR}" "${qc_inputs[@]}" 2>> "${LOGDIR}/fastqc.log"
    
    MERGED_R1="${TMPDIR}/${SAMPLE}_R1.fastq.gz"
    cat "${R1_FILES[@]}" > "${MERGED_R1}"
    
    if [[ "$IS_PE" == "true" ]]; then
        MERGED_R2="${TMPDIR}/${SAMPLE}_R2.fastq.gz"
        cat "${R2_FILES[@]}" > "${MERGED_R2}"
    fi
}

step_trim() {
    log_info "Step: Adapter Trimming"
    TRIM_R1="${TMPDIR}/${SAMPLE}_R1.trim.fastq.gz"
    
    if [[ "$IS_PE" == "true" ]]; then
        TRIM_R2="${TMPDIR}/${SAMPLE}_R2.trim.fastq.gz"
        cutadapt -a "${ADAPTER_SEQ}" -A "${ADAPTER_SEQ}" -q 20 -m 20 -j "${THREADS}" \
            -o "${TRIM_R1}" -p "${TRIM_R2}" "${MERGED_R1}" "${MERGED_R2}" >"${LOGDIR}/cutadapt.log"
    else
        cutadapt -a "${ADAPTER_SEQ}" -q 20 -m 20 -j "${THREADS}" \
            -o "${TRIM_R1}" "${MERGED_R1}" >"${LOGDIR}/cutadapt.log"
    fi
}

step_align() {
    SORTED_BAM="${TMPDIR}/${SAMPLE}.sorted.bam"
    
    # Define Bowtie2 Parameters based on Assay
    local BT2_ARGS=""
    
    if [[ "$ASSAY_TYPE" == "atac" ]]; then
        # ATAC: Allow larger inserts (2k) for nucleosomes
        BT2_ARGS="--very-sensitive --local --no-mixed --no-discordant --phred33 -I 10 -X 2000"
    elif [[ "$ASSAY_TYPE" =~ cut ]]; then
        # CUT&RUN/Tag: Strict sizes (700bp), dovetail often allowed but here we stick to standard PE constraints
        BT2_ARGS="--local --very-sensitive --no-mixed --no-discordant --phred33 -I 10 -X 700"
    else 
        # ChIP-seq
        BT2_ARGS="--local --sensitive --phred33"
        [[ "$IS_PE" == "true" ]] && BT2_ARGS="$BT2_ARGS -I 10 -X 700"
    fi

    log_info "Step: Alignment (${ASSAY_TYPE})"
    log_info "Params: ${BT2_ARGS}"

    if [[ "$IS_PE" == "true" ]]; then
        bowtie2 -x "${BOWTIE2_INDEX}" -1 "${TRIM_R1}" -2 "${TRIM_R2}" -p "${THREADS}" \
            ${BT2_ARGS} --rg-id "${SAMPLE}" --rg "SM:${SAMPLE}" \
            2>"${LOGDIR}/bowtie2.log" \
        | samtools view -@ "${THREADS}" -bS - \
        | samtools sort -@ "${THREADS}" -m "${MEM_BYTES}" -o "${SORTED_BAM}"
    else
        bowtie2 -x "${BOWTIE2_INDEX}" -U "${TRIM_R1}" -p "${THREADS}" \
            ${BT2_ARGS} --rg-id "${SAMPLE}" --rg "SM:${SAMPLE}" \
            2>"${LOGDIR}/bowtie2.log" \
        | samtools view -@ "${THREADS}" -bS - \
        | samtools sort -@ "${THREADS}" -m "${MEM_BYTES}" -o "${SORTED_BAM}"
    fi

    log_info "Report: Generating post alignment basic stats"
    samtools index -@ "${THREADS}" "${SORTED_BAM}"
    samtools flagstat -@ "${THREADS}" "${SORTED_BAM}" > "${LOGDIR}/${SAMPLE}_raw_flagstat.txt"
    samtools stats -@ "${THREADS}" "${SORTED_BAM}" > "${LOGDIR}/${SAMPLE}_raw_samstats.txt"
    samtools idxstats -@ "${THREADS}" "${SORTED_BAM}" > "${LOGDIR}/${SAMPLE}_raw_idxstats.txt"

}

step_mark_dups() {
    log_info "Step: Mark Duplicates"
    MARKED_BAM="${TMPDIR}/${SAMPLE}.marked.bam"
    METRICS="${QCDIR}/${SAMPLE}.dup_metrics.txt"
    
    # For CUT&RUN/TAG, high duplication is expected (targeted), but usually we mark them anyway.
    # Note: Some protocols suggest NOT removing dups for CUT&RUN, but we mark them here. 
    # The filter step decides whether to remove them based on flags.
    
    picard MarkDuplicates \
            --INPUT "${SORTED_BAM}" \
            --OUTPUT "${MARKED_BAM}" \
            --METRICS_FILE "${METRICS}" \
            --VALIDATION_STRINGENCY SILENT \
            --ASSUME_SORT_ORDER coordinate \
            --REMOVE_DUPLICATES false \
            --READ_NAME_REGEX null \
            2>> "${LOGDIR}/picard_dup.log"
        
    samtools index -@ "${THREADS}" "${MARKED_BAM}"
}

step_complexity() {
    log_info "Step: Library Complexity (NRF, PBC1, PBC2)..."
    
    local NSORT_BAM="${TMPDIR}/${SAMPLE}.name_sorted.bam"
    
    # Sort by name for bedtools bedpe
    samtools sort -n -@ "${THREADS}" -o "${NSORT_BAM}" "${MARKED_BAM}"
    log_info "Report: Computing complexity metrics (this may take a while)..."
    # Calculate NRF, PBC1, PBC2
    # Note: Requires PE reads (bedpe) which matches ATAC requirements
    bedtools bamtobed -bedpe -i "${NSORT_BAM}" 2>/dev/null \
    | awk 'BEGIN{OFS="\t"}{print $1,$2,$4,$6,$9,$10}' \
    | sort \
    | uniq -c \
    | awk '{
        count=$1; 
        TOTAL_READS += count; 
        total_distinct++; 
        if(count==1) n1++; 
        if(count==2) n2++;
    } END {
        if(TOTAL_READS>0) {
            nrf = total_distinct/TOTAL_READS;
            pbc1 = n1/total_distinct;
            if (n2 > 0) pbc2 = n1 / n2; else pbc2 = 0;
            print "NRF," nrf;
            print "PBC1," pbc1;
            print "PBC2," pbc2;
            
            # QC Threshold logging (optional visual feedback)
            if(nrf < 0.9) print "[WARN] Low NRF: " nrf > "/dev/stderr";
            if(pbc1 < 0.9) print "[WARN] Low PBC1: " pbc1 > "/dev/stderr";
            if(pbc2 < 3) print "[WARN] Low PBC2: " pbc2 > "/dev/stderr";
        } else {
            print "NRF,0"; print "PBC1,0"; print "PBC2,0";
        }
    }' >> "${SUMMARY_QC}" || log_warn "Complexity calculation failed"
    
    # Clean up large name-sorted bam immediately to save space
    rm -f "${NSORT_BAM}"
}

step_filter() {
    log_info "Step: Filtering (Canonical Chromosomes & Quality)"
    CLEAN_BAM="${FINALDIR}/${SAMPLE}.clean.bam"
    
    # Standard filter: -F 1804 (unmapped, secondary, qc fail, dup) -f 2 (proper pair if PE) -q 30
    local SAM_FLAGS="-F 1804 -q 30"
    if [[ "$IS_PE" == "true" ]]; then
        SAM_FLAGS="$SAM_FLAGS -f 2"
    fi

    # Canonical Regex
    local canonical_pattern='(^(chr)?([1-9]|1[0-9]|2[0-2]|X|Y)$)|(^(chr)?(I|II|III|IV|V|VI|VII|VIII|IX|X|XI|XII|XIII|XIV|XV|XVI|XVII|XVIII|XIX|XX|XXI|XXII|2L|2R|3L|3R|4)$)'

    samtools view -h -@ "${THREADS}" ${SAM_FLAGS} "${MARKED_BAM}" \
    | awk -v pattern="${canonical_pattern}" '
        BEGIN {
            mito["chrM"]=1; mito["MT"]=1; mito["M"]=1;
            exclude["_"]=1; exclude["chrUn"]=1; exclude["random"]=1; exclude["chrEBV"]=1;
        }
        /^@/ { print; next }
        {
            chrom = $3
            if (chrom == "*") next
            if (chrom in mito) next
            for (k in exclude) if (index(chrom, k)>0) next
            if (chrom ~ pattern) print
        }
    ' \
    | samtools view -b -@ "${THREADS}" -o "${CLEAN_BAM}"
    
    samtools index -@ "${THREADS}" "${CLEAN_BAM}"
    
    # Log filtering statistics
    local TOTAL_READS=$(samtools view -c -@ "${THREADS}" "${MARKED_BAM}")
    local FILTERED_READS=$(samtools view -c -@ "${THREADS}" "${CLEAN_BAM}")
    local REMOVED_READS=$((TOTAL_READS - FILTERED_READS))
    local PCT_KEPT=$(awk "BEGIN {printf \"%.2f\", ($FILTERED_READS/$TOTAL_READS)*100}")
    # 2. Replace the logging section in 'step_filter' with this:
    
    # Calculate percentages and human-readable numbers
    local PCT_KEPT=$(awk "BEGIN {printf \"%.2f\", ($FILTERED_READS/$TOTAL_READS)*100}")
    local H_TOTAL=$(format_reads "$TOTAL_READS")
    local H_KEPT=$(format_reads "$FILTERED_READS")
    local H_REMOVED=$(format_reads "$REMOVED_READS")
    
    log_info "Filtering complete: kept ${H_KEPT}/${H_TOTAL} reads (${PCT_KEPT}%)"
    log_info "Removed ${H_REMOVED} non-canonical/low-quality reads"
    log_info "Report: Generating clean BAM basic stats"
    samtools flagstat -@ "${THREADS}" "${CLEAN_BAM}" > "${LOGDIR}/${SAMPLE}_clean_flagstat.txt"
    samtools stats -@ "${THREADS}" "${CLEAN_BAM}" > "${LOGDIR}/${SAMPLE}_clean_samstats.txt"
    samtools idxstats -@ "${THREADS}" "${CLEAN_BAM}" > "${LOGDIR}/${SAMPLE}_clean_idxstats.txt"
}

step_peaks_macs() {
    log_info "Step: MACS3 Peak Calling"
    
    local MACS_FORMAT="BAM"
    [[ "$IS_PE" == "true" ]] && MACS_FORMAT="BAMPE"
    
    local MACS_ARGS="-g ${EFFECTIVE_GENOME_SIZE} -n ${SAMPLE} --outdir ${PEAKDIR} -q 0.05"
    
    # --nomodel logic for ATAC
    if [[ "$ASSAY_TYPE" == "atac" ]]; then
        MACS_ARGS="$MACS_ARGS --nomodel --shift -100 --extsize 200"
    fi
    
    # Peak Type
    if [[ "$PEAK_MODE" == "broad" ]]; then
        MACS_ARGS="$MACS_ARGS --broad --broad-cutoff 0.1"
        RAW_PEAKS="${PEAKDIR}/${SAMPLE}_peaks.broadPeak"
        FINAL_PEAKS="${PEAKDIR}/${SAMPLE}.final.broadPeak"
    else
        RAW_PEAKS="${PEAKDIR}/${SAMPLE}_peaks.narrowPeak"
        FINAL_PEAKS="${PEAKDIR}/${SAMPLE}.final.narrowPeak"
    fi

    macs3 callpeak -t "${CLEAN_BAM}" -f "${MACS_FORMAT}" ${MACS_ARGS} 2>> "${LOGDIR}/macs3.log" || fail "MACS3 failed"
    
    # Blacklist Filter
    if [[ -n "${BLACKLIST}" && -f "${BLACKLIST}" ]]; then
        log_info "Filtering Blacklist..."
        bedtools intersect -v -a "${RAW_PEAKS}" -b "${BLACKLIST}" > "${FINAL_PEAKS}"
    else
        cp "${RAW_PEAKS}" "${FINAL_PEAKS}"
    fi
    
    log_qc "MACS3_Peaks" "$(wc -l < "${FINAL_PEAKS}")"
}

step_peaks_seacr() {
    # Only for CUT&RUN / CUT&Tag
    log_info "Step: SEACR Peak Calling"
    
    # 1. Generate BedGraph (requires bedtools bamtobed -> sort -> genomecov)
    bedtools bamtobed -bedpe -i "${CLEAN_BAM}" \
    | awk '$1==$4 && $6-$2 < 1000 {print $0}' \
    | cut -f 1,2,6 | sort -k1,1 -k2,2n -k3,3n > "${TMPDIR}/${SAMPLE}.fragments.bed" 2>> "${LOGDIR}/seacr.log" || fail "SEACR bedtools cut failed"
    
    # Get chrom sizes from BAM header
    samtools view -H "${CLEAN_BAM}" | grep "@SQ" | sed 's/@SQ\tSN:\|LN://g' > "${TMPDIR}/chrom.sizes"
    
    bedtools genomecov -bg -i "${TMPDIR}/${SAMPLE}.fragments.bed" -g "${TMPDIR}/chrom.sizes" > "${TMPDIR}/${SAMPLE}.bg" 2>> "${LOGDIR}/seacr.log" || fail "SEACR bedtools genomecov failed"
    
    # 2. Run SEACR
    # Norm mode: stringent (uses top 1% of regions by AUC)
    SEACR_1.3.sh "${TMPDIR}/${SAMPLE}.bg" 0.01 non stringent "${PEAKDIR}/${SAMPLE}_SEACR" 2>> "${LOGDIR}/seacr.log" || log_warn "SEACR failed"
    
    if [[ -f "${PEAKDIR}/${SAMPLE}_SEACR.stringent.bed" ]]; then
        log_qc "SEACR_Peaks" "$(wc -l < "${PEAKDIR}/${SAMPLE}_SEACR.stringent.bed")"
    fi
}

step_frip() {
    local peak_file="$1"
    local label="$2"
    
    if [[ ! -s "${peak_file}" ]]; then
        log_warn "FRiP: Peak file empty or missing for $label"
        return
    fi
    
    log_info "Step: Calculating FRiP ($label)"
    
    # Total fragments (proper pairs or reads)
    local TOTAL_READS
    if [[ "$IS_PE" == "true" ]]; then
        TOTAL_READS=$(samtools view -c -f 66 "${CLEAN_BAM}")
    else
        TOTAL_READS=$(samtools view -c -F 4 "${CLEAN_BAM}")
    fi
    
    local READS_IN_PEAKS
    READS_IN_PEAKS=$(bedtools intersect -a "${CLEAN_BAM}" -b "${peak_file}" -bed -u -f 0.2 | wc -l)
    
    local FRIP=0
    if [[ "$TOTAL_READS" -gt 0 ]]; then
        FRIP=$(awk "BEGIN {printf \"%.4f\", $READS_IN_PEAKS/$TOTAL_READS}")
    fi
    
    log_qc "FRiP_${label}" "${FRIP}"
}

step_insert_size() {
    if [[ "$IS_PE" == "true" ]]; then
        log_info "Step: Insert Size Metrics"
        picard CollectInsertSizeMetrics \
            -I "${CLEAN_BAM}" \
            -O "${QCDIR}/${SAMPLE}_insert_size.txt" \
            -H "${QCDIR}/${SAMPLE}_insert_size.pdf" \
            -M 0.5 \
            --VALIDATION_STRINGENCY SILENT 2>> "${LOGDIR}/picard.log"
    fi
}

step_post_deeptools() {
    VIZ_BAM="${CLEAN_BAM}"

    if [[ "$ASSAY_TYPE" == "atac" || "$ASSAY_TYPE" == "cuttag" ]]; then
        log_info "Step:Tn5 Shift Post-Processing"
        ulimit -n 65536
        SHIFTED_BAM="${TMPDIR}/${SAMPLE}.shifted.bam"
        SHIFTED_SORT_BAM="${TMPDIR}/${SAMPLE}.shifted.sort.bam"
        alignmentSieve --bam "${CLEAN_BAM}" --outFile "${SHIFTED_BAM}" \
            --ATACshift -p "${THREADS}" 2>>"${LOGDIR}/shift.log" || fail "alignmentSieve failed"
        
        samtools sort -@ "${THREADS}" -o "${SHIFTED_SORT_BAM}" "${SHIFTED_BAM}"
        samtools index -@ "${THREADS}" "${SHIFTED_SORT_BAM}"
        VIZ_BAM="${SHIFTED_SORT_BAM}"
    fi

    log_info "Step: Generating BigWig Coverage Tracks"
    bamCoverage --bam "${VIZ_BAM}" --outFileName "${FINALDIR}/${SAMPLE}.RPGC.bw" \
        --binSize 10 --normalizeUsing RPGC \
        --effectiveGenomeSize "${EFFECTIVE_GENOME_SIZE}" \
        -p "${THREADS}" 2>>"${LOGDIR}/bamcoverage.log" || fail "bamCoverage failed"
    bamCoverage --bam "${VIZ_BAM}" --outFileName "${FINALDIR}/${SAMPLE}.CPM.bw" \
        --binSize 10 --normalizeUsing CPM \
        --effectiveGenomeSize "${EFFECTIVE_GENOME_SIZE}" \
        -p "${THREADS}" 2>>"${LOGDIR}/bamcoverage.log" || fail "bamCoverage failed"

    log_info "Step: DeepTools Fragment Size Distribution"
    bamPEFragmentSize \
        -hist "${QCDIR}/${SAMPLE}_fragmentSize.png" \
        -T "Fragment size: ${SAMPLE}" \
        --maxFragmentLength 1000 \
        -b "${CLEAN_BAM}" \
        --samplesLabel "${SAMPLE}" \
        --table "${QCDIR}/${SAMPLE}_fragmentSize.txt" \
        -p "${THREADS}" > "${LOGDIR}/bamPEFragmentSize.log" || fail "bamPEFragmentSize failed"

}

#######################################
# EXECUTION
#######################################
step_prepare
step_trim
step_align
step_mark_dups
# Inserted step: Complexity Analysis for ATAC-seq
if [[ "$ASSAY_TYPE" == "atac" ]]; then
    step_complexity
fi

step_filter
step_peaks_macs

# QC: FRiP for MACS
if [[ "$PEAK_MODE" == "broad" ]]; then
    step_frip "${PEAKDIR}/${SAMPLE}.final.broadPeak" "MACS3_Broad"
else
    step_frip "${PEAKDIR}/${SAMPLE}.final.narrowPeak" "MACS3_Narrow"
fi

# Assay Specific Flows
if [[ "$ASSAY_TYPE" =~ cut ]]; then
    step_peaks_seacr
    step_frip "${PEAKDIR}/${SAMPLE}_SEACR.stringent.bed" "SEACR"
fi

step_insert_size
step_post_deeptools

# Cleanup
if [[ "$CLEAN_INTERMEDIATE" == "true" ]]; then
    rm -rf "${TMPDIR}"
    log_info "Cleanup complete."
fi

# MultiQC
if command -v multiqc &>/dev/null; then
    multiqc "${LOGDIR}" "${QCDIR}" -o "${OUTDIR}/multiqc" --filename "${SAMPLE}_report" || true
fi

log_info "Epi-Flow pipeline completed successfully."