#!/bin/bash
set -euo pipefail
trap 'log_error "Pipeline failed at line $LINENO"; exit 1' ERR


if [[ -t 1 ]] && command -v tput &>/dev/null && [[ $(tput colors 2>/dev/null) -ge 8 ]]; then
    readonly RED='\033[0;31m'
    readonly GREEN='\033[0;32m'
    readonly YELLOW='\033[1;33m'
    readonly BLUE='\033[0;34m'
    readonly CYAN='\033[0;36m'
    readonly MAGENTA='\033[0;35m'
    readonly NC='\033[0m'
else
    # No color support
    readonly RED=''
    readonly GREEN=''
    readonly YELLOW=''
    readonly BLUE=''
    readonly CYAN=''
    readonly MAGENTA=''
    readonly NC=''
fi


THREADS=8
MEM_GB=""
CLEAN_INTERMEDIATE=true
ADAPTER_SEQ="CTGTCTCTTATACACATCT"
EFFECTIVE_GENOME_SIZE=""
PEAK_MODE="narrow"
ASSAY_TYPE=""


PIPELINE_START_TIME=$(date +%s)

log_header() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

log_step() {
    echo -e "${CYAN}[STEP $(date '+%H:%M:%S')] $1${NC}"
}

log_info() {
    echo -e "${GREEN}[INFO $(date '+%H:%M:%S')] $1${NC}"
}

log_warn() {
    echo -e "${YELLOW}[WARN $(date '+%H:%M:%S')] $1${NC}" >&2
}

log_error() {
    echo -e "${RED}[ERROR $(date '+%H:%M:%S')] $1${NC}" >&2
}

log_metric() {
    echo -e "${MAGENTA}[METRIC] $1: $2${NC}"
}

log_qc() {
    echo "$1,$2" >> "${SUMMARY_QC}"
}

log_progress() {
    echo -e "${GREEN}  ✓ $1${NC}"
}

log_elapsed() {
    local end_time=$(date +%s)
    local elapsed=$((end_time - PIPELINE_START_TIME))
    local hours=$((elapsed / 3600))
    local minutes=$(((elapsed % 3600) / 60))
    local seconds=$((elapsed % 60))
    log_info "Total elapsed time: ${hours}h ${minutes}m ${seconds}s"
}

fail() {
    log_error "$1"
    log_elapsed
    exit 1
}

check_tool() {
    if ! command -v "$1" &>/dev/null; then
        fail "Required tool not found: $1"
    fi
}

check_file() {
    if [[ ! -f "$1" ]]; then
        fail "Required file not found: $1"
    fi
}

# --- UTILITY FUNCTIONS ---
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

format_percentage() {
    awk "BEGIN {printf \"%.2f%%\", $1}"
}


usage() {
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  EPI-FLOW: Unified Chromatin Analysis Pipeline${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${GREEN}Required Arguments:${NC}"
    echo "  -a  Assay type [atac | cutrun | cuttag | chip]"
    echo "  -1  R1 fastq.gz (comma-separated for multiple files)"
    echo "  -n  Sample name"
    echo "  -x  Bowtie2 index prefix"
    echo "  -o  Output directory"
    echo "  -g  Effective genome size (hs, mm, or integer)"
    echo ""
    echo -e "${GREEN}Optional Arguments:${NC}"
    echo "  -2  R2 fastq.gz (comma-separated, required for ATAC/CUT&RUN/CUT&Tag)"
    echo "  -p  Peak mode [narrow | broad] (default: narrow)"
    echo "  -b  Blacklist BED file"
    echo "  -t  Number of threads (default: 8)"
    echo "  -m  Memory in GB (auto-detected if not specified)"
    echo "  --keep-tmp  Keep intermediate files"
    echo ""
    echo -e "${GREEN}Example:${NC}"
    echo "  $(basename "$0") -a atac -1 sample_R1.fastq.gz -2 sample_R2.fastq.gz \\"
    echo "     -n MySample -x /ref/hg38 -o ./output -g hs"
    echo ""
    exit 1
}


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
        -h|--help) usage ;;
        *) log_error "Unknown option: $1"; usage ;;
    esac
done


log_header "VALIDATION & SETUP"

if [[ -z "${R1_INPUT}" || -z "${SAMPLE}" || -z "${BOWTIE2_INDEX}" || -z "${OUTDIR}" || -z "${EFFECTIVE_GENOME_SIZE}" || -z "${ASSAY_TYPE}" ]]; then
    log_error "Missing required arguments"
    usage
fi


if [[ ! "$ASSAY_TYPE" =~ ^(atac|cutrun|cuttag|chip)$ ]]; then
    fail "Invalid assay type: $ASSAY_TYPE. Valid options: atac, cutrun, cuttag, chip"
fi


IS_PE=false
[[ -n "${R2_INPUT}" ]] && IS_PE=true


if [[ "$ASSAY_TYPE" =~ ^(atac|cutrun|cuttag)$ ]] && [[ "$IS_PE" == "false" ]]; then
    fail "Assay '$ASSAY_TYPE' requires paired-end reads (R2 not provided)"
fi


if [[ ! "$PEAK_MODE" =~ ^(narrow|broad)$ ]]; then
    fail "Invalid peak mode: $PEAK_MODE. Valid options: narrow, broad"
fi

log_info "Assay type: ${ASSAY_TYPE^^}"
log_info "Read type: $([ "$IS_PE" == "true" ] && echo "Paired-End" || echo "Single-End")"
log_info "Peak mode: ${PEAK_MODE}"
log_info "Sample: ${SAMPLE}"


log_step "Checking dependencies"

REQUIRED_TOOLS="fastqc cutadapt bowtie2 samtools picard bedtools macs3"

if [[ "$ASSAY_TYPE" == "atac" ]]; then
    REQUIRED_TOOLS="$REQUIRED_TOOLS alignmentSieve bamCoverage bamPEFragmentSize"
fi

if [[ "$ASSAY_TYPE" =~ ^(cutrun|cuttag)$ ]]; then
    REQUIRED_TOOLS="$REQUIRED_TOOLS SEACR_1.3.sh"
fi

for tool in $REQUIRED_TOOLS; do
    check_tool "$tool"
    log_progress "Found: $tool"
done


log_step "Configuring resources"

MAX_THREADS=$(nproc)
[[ "${THREADS}" -gt "$((MAX_THREADS-1))" ]] && THREADS=$((MAX_THREADS-1))
[[ "${THREADS}" -lt 1 ]] && THREADS=1

if [[ -n "${MEM_GB}" ]]; then
    TOTAL_MEM=$((MEM_GB*1024*1024*1024))
else
    TOTAL_MEM=$(get_memory_limit_bytes)
    MEM_GB=$((TOTAL_MEM / 1024 / 1024 / 1024))
fi

MEM_BYTES=$(( TOTAL_MEM * 80 / 100 / THREADS ))
[[ "${MEM_BYTES}" -lt 536870912 ]] && MEM_BYTES=536870912

JAVA_MAX=$(( TOTAL_MEM * 70 / 100 ))
[[ "${JAVA_MAX}" -gt $((8*1024*1024*1024)) ]] && JAVA_MAX=$((8*1024*1024*1024))
export _JAVA_OPTIONS="-Xmx${JAVA_MAX}"

log_info "Threads: ${THREADS} / ${MAX_THREADS}"
log_info "Memory: ${MEM_GB}GB total"
log_info "Java heap: $((JAVA_MAX / 1024 / 1024 / 1024))GB"


log_step "Creating directory structure"


LOGDIR="${OUTDIR}/logs"
QCDIR="${OUTDIR}/qc"
ALIGNDIR="${OUTDIR}/alignments"
PEAKDIR="${OUTDIR}/peaks"
TRACKDIR="${OUTDIR}/tracks"


if [[ -n "${TMPDIR:-}" ]] && [[ -d "${TMPDIR}" ]] && [[ -w "${TMPDIR}" ]]; then
    WORKDIR="${TMPDIR}/${SAMPLE}_$"
    log_info "Using system temporary directory: ${TMPDIR}"
else
    WORKDIR="${OUTDIR}/tmp"
    log_info "Using local temporary directory"
fi

mkdir -p "${LOGDIR}" "${QCDIR}" "${ALIGNDIR}" "${PEAKDIR}" "${TRACKDIR}" "${WORKDIR}"
export TMPDIR="${WORKDIR}"

SUMMARY_QC="${QCDIR}/${SAMPLE}_summary_qc.csv"
echo "metric,value" > "$SUMMARY_QC"

log_progress "Output: ${OUTDIR}"
log_progress "Working: ${WORKDIR}"
log_progress "Logs: ${LOGDIR}"
log_progress "QC: ${QCDIR}"


log_step "Validating input files"

IFS=',' read -r -a R1_FILES <<< "${R1_INPUT}"
for f in "${R1_FILES[@]}"; do
    check_file "$f"
    log_progress "R1: $(basename "$f")"
done

if [[ "$IS_PE" == "true" ]]; then
    IFS=',' read -r -a R2_FILES <<< "${R2_INPUT}"
    [[ "${#R1_FILES[@]}" -ne "${#R2_FILES[@]}" ]] && fail "R1/R2 file count mismatch"
    for f in "${R2_FILES[@]}"; do
        check_file "$f"
        log_progress "R2: $(basename "$f")"
    done
fi


if [[ ! -f "${BOWTIE2_INDEX}.1.bt2" && ! -f "${BOWTIE2_INDEX}.1.bt2l" ]]; then
    fail "Bowtie2 index not found: ${BOWTIE2_INDEX}"
fi
log_progress "Bowtie2 index: ${BOWTIE2_INDEX}"


if [[ -n "${BLACKLIST}" ]]; then
    check_file "${BLACKLIST}"
    log_progress "Blacklist: ${BLACKLIST}"
fi


step_prepare() {
    log_header "STEP 1: PRE-QC AND MERGING"
    
    log_info "Running FastQC on input files"
    local qc_inputs=("${R1_FILES[@]}")
    [[ "$IS_PE" == "true" ]] && qc_inputs+=("${R2_FILES[@]}")
    
    fastqc -t "${THREADS}" -o "${QCDIR}" "${qc_inputs[@]}" \
        &>> "${LOGDIR}/fastqc.log" || fail "FastQC failed"
    log_progress "FastQC completed"
    
    log_info "Merging R1 files"
    MERGED_R1="${WORKDIR}/${SAMPLE}_R1.fastq.gz"
    cat "${R1_FILES[@]}" > "${MERGED_R1}" || fail "R1 merge failed"
    log_progress "R1 merged: $(basename "$MERGED_R1")"
    
    if [[ "$IS_PE" == "true" ]]; then
        log_info "Merging R2 files"
        MERGED_R2="${WORKDIR}/${SAMPLE}_R2.fastq.gz"
        cat "${R2_FILES[@]}" > "${MERGED_R2}" || fail "R2 merge failed"
        log_progress "R2 merged: $(basename "$MERGED_R2")"
    fi
}

step_trim() {
    log_header "STEP 2: ADAPTER TRIMMING"
    
    TRIM_R1="${WORKDIR}/${SAMPLE}_R1.trim.fastq.gz"
    
    log_info "Adapter sequence: ${ADAPTER_SEQ}"
    log_info "Quality cutoff: Q20, minimum length: 20bp"
    
    if [[ "$IS_PE" == "true" ]]; then
        TRIM_R2="${WORKDIR}/${SAMPLE}_R2.trim.fastq.gz"
        log_info "Running cutadapt (paired-end mode)"
        cutadapt -a "${ADAPTER_SEQ}" -A "${ADAPTER_SEQ}" \
            -q 20 -m 20 -j "${THREADS}" \
            -o "${TRIM_R1}" -p "${TRIM_R2}" \
            "${MERGED_R1}" "${MERGED_R2}" \
            &> "${LOGDIR}/cutadapt.log" || fail "Cutadapt failed"
        log_progress "Trimmed: $(basename "$TRIM_R1"), $(basename "$TRIM_R2")"
    else
        log_info "Running cutadapt (single-end mode)"
        cutadapt -a "${ADAPTER_SEQ}" -q 20 -m 20 -j "${THREADS}" \
            -o "${TRIM_R1}" "${MERGED_R1}" \
            &> "${LOGDIR}/cutadapt.log" || fail "Cutadapt failed"
        log_progress "Trimmed: $(basename "$TRIM_R1")"
    fi
    
    # Extract trimming stats
    local reads_processed=$(grep "Total reads processed:" "${LOGDIR}/cutadapt.log" | awk '{print $NF}' | tr -d ',')
    local reads_written=$(grep "Reads written" "${LOGDIR}/cutadapt.log" | awk '{print $NF}' | tr -d ',')
    
    if [[ -n "$reads_processed" && -n "$reads_written" ]]; then
        log_qc "Reads_Input" "$reads_processed"
        log_qc "Reads_After_Trim" "$reads_written"
    fi
}

step_align() {
    log_header "STEP 3: ALIGNMENT"
    
    SORTED_BAM="${WORKDIR}/${SAMPLE}.sorted.bam"
    
    # Configure alignment parameters based on assay
    local BT2_ARGS=""
    local assay_desc=""
    
    case "$ASSAY_TYPE" in
        atac)
            BT2_ARGS="--very-sensitive --local --no-mixed --no-discordant --phred33 -I 10 -X 2000"
            assay_desc="ATAC-seq (max insert: 2kb for nucleosomes)"
            ;;
        cutrun|cuttag)
            BT2_ARGS="--local --very-sensitive --no-mixed --no-discordant --phred33 -I 10 -X 700"
            assay_desc="CUT&RUN/Tag (max insert: 700bp)"
            ;;
        chip)
            BT2_ARGS="--local --sensitive --phred33"
            [[ "$IS_PE" == "true" ]] && BT2_ARGS="$BT2_ARGS -I 10 -X 700"
            assay_desc="ChIP-seq"
            ;;
    esac

    log_info "Alignment mode: ${assay_desc}"
    log_info "Parameters: ${BT2_ARGS}"
    log_info "Reference: ${BOWTIE2_INDEX}"
    
    if [[ "$IS_PE" == "true" ]]; then
        log_info "Aligning paired-end reads"
        bowtie2 -x "${BOWTIE2_INDEX}" -1 "${TRIM_R1}" -2 "${TRIM_R2}" \
            -p "${THREADS}" ${BT2_ARGS} \
            --rg-id "${SAMPLE}" --rg "SM:${SAMPLE}" \
            2>"${LOGDIR}/bowtie2.log" \
        | samtools view -@ "${THREADS}" -bS - \
        | samtools sort -@ "${THREADS}" -m "${MEM_BYTES}" -o "${SORTED_BAM}" \
        || fail "Alignment failed"
    else
        log_info "Aligning single-end reads"
        bowtie2 -x "${BOWTIE2_INDEX}" -U "${TRIM_R1}" \
            -p "${THREADS}" ${BT2_ARGS} \
            --rg-id "${SAMPLE}" --rg "SM:${SAMPLE}" \
            2>"${LOGDIR}/bowtie2.log" \
        | samtools view -@ "${THREADS}" -bS - \
        | samtools sort -@ "${THREADS}" -m "${MEM_BYTES}" -o "${SORTED_BAM}" \
        || fail "Alignment failed"
    fi
    
    log_progress "Alignment completed: $(basename "$SORTED_BAM")"
    
    log_info "Indexing BAM file"
    samtools index -@ "${THREADS}" "${SORTED_BAM}" || fail "BAM indexing failed"
    log_progress "Index created"
    
    log_info "Generating alignment statistics"
    samtools flagstat -@ "${THREADS}" "${SORTED_BAM}" > "${LOGDIR}/${SAMPLE}_raw_flagstat.txt"
    samtools stats -@ "${THREADS}" "${SORTED_BAM}" > "${LOGDIR}/${SAMPLE}_raw_samstats.txt"
    samtools idxstats -@ "${THREADS}" "${SORTED_BAM}" > "${LOGDIR}/${SAMPLE}_raw_idxstats.txt"
    log_progress "Statistics generated"
    

    local RAW_TOTAL_READS=0
    local RAW_MAP_READS=0
    
    RAW_TOTAL_READS=$(awk '
        # Match lines that begin with SN (allow tabs/spaces) and contain the tag
        /^SN([[:space:]]|$)/ && /raw total sequences:/ {
        # Find the first numeric span; match works in POSIX awk
        if (match($0, /[0-9][0-9,]*/)) {
            v = substr($0, RSTART, RLENGTH)
            gsub(",", "", v)        # remove thousands separators
            last = v                # keep last match if multiple lines exist
        }
        }
        END {
        if (last == "" || last !~ /^[0-9]+$/) last = 0
        print last
        }
    ' "${LOGDIR}/${SAMPLE}_raw_samstats.txt" 2>/dev/null || echo "0")

    RAW_MAP_READS=$(awk '/^SN.*reads mapped:/ {print $NF}' "${LOGDIR}/${SAMPLE}_raw_samstats.txt" 2>/dev/null || echo "0")
    
    # Ensure numeric values
    RAW_TOTAL_READS=${RAW_TOTAL_READS:-0}
    RAW_MAP_READS=${RAW_MAP_READS:-0}
    
    if [[ "$RAW_TOTAL_READS" -gt 0 ]] && [[ "$RAW_MAP_READS" -gt 0 ]]; then
        local RAW_PCT_MAP=$(awk "BEGIN {printf \"%.2f\", ($RAW_MAP_READS/$RAW_TOTAL_READS)*100}")
        log_metric "Total reads" "$(format_reads "$RAW_TOTAL_READS")"
        log_metric "Mapped reads" "$(format_reads "$RAW_MAP_READS") (${RAW_PCT_MAP}%)"
        log_qc "Total_Reads_Raw" "$RAW_TOTAL_READS"
        log_qc "Mapped_Reads_Raw" "$RAW_MAP_READS"
    else
        log_warn "Unable to extract read counts from alignment statistics"
    fi
}

step_mark_dups() {
    log_header "STEP 4: DUPLICATE MARKING"
    
    MARKED_BAM="${WORKDIR}/${SAMPLE}.marked.bam"
    METRICS="${QCDIR}/${SAMPLE}.dup_metrics.txt"
    
    log_info "Running Picard MarkDuplicates"
    if [[ "$ASSAY_TYPE" =~ ^(cutrun|cuttag)$ ]]; then
        log_info "Note: High duplication expected for ${ASSAY_TYPE^^} (targeted assay)"
    fi
    
    picard MarkDuplicates \
        --INPUT "${SORTED_BAM}" \
        --OUTPUT "${MARKED_BAM}" \
        --METRICS_FILE "${METRICS}" \
        --VALIDATION_STRINGENCY SILENT \
        --ASSUME_SORT_ORDER coordinate \
        --REMOVE_DUPLICATES false \
        --READ_NAME_REGEX null \
        &>> "${LOGDIR}/picard_dup.log" || fail "MarkDuplicates failed"
    
    log_progress "Duplicates marked: $(basename "$MARKED_BAM")"
    
    log_info "Indexing marked BAM"
    samtools index -@ "${THREADS}" "${MARKED_BAM}" || fail "BAM indexing failed"
    log_progress "Index created"
    
    
    local dup_rate=$(awk -F'\t' 'BEGIN{col=0} $1=="LIBRARY"{for(i=1;i<=NF;i++) if($i=="PERCENT_DUPLICATION") col=i; next} /^#/ {next} col{print $col; exit}' "${METRICS}")
    if [[ -n "$dup_rate" ]] && [[ "$dup_rate" != "PERCENT_DUPLICATION" ]]; then
        local dup_pct=$(awk "BEGIN {printf \"%.2f%%\", $dup_rate * 100}")
        log_metric "Duplication rate" "$dup_pct"
        log_qc "Duplication_Rate" "$dup_rate"
    else
        log_warn "Unable to extract duplication rate from metrics"
    fi
}

step_complexity() {
    log_header "STEP 5: LIBRARY COMPLEXITY ANALYSIS"
    
    log_info "Computing NRF, PBC1, and PBC2 metrics"
    log_info "This may take several minutes for large libraries..."
    
    local NSORT_BAM="${WORKDIR}/${SAMPLE}.name_sorted.bam"
    
    log_info "Sorting BAM by read name"
    samtools sort -n -@ "${THREADS}" -o "${NSORT_BAM}" "${MARKED_BAM}" \
        || fail "Name sorting failed"
    log_progress "Name-sorted BAM created"
    
    log_info "Calculating complexity metrics"
    bedtools bamtobed -bedpe -i "${NSORT_BAM}" 2>/dev/null \
    | awk 'BEGIN{OFS="\t"}{print $1,$2,$4,$6,$9,$10}' \
    | sort \
    | uniq -c \
    | awk -v sample="${SAMPLE}" '{
        count=$1; 
        TOTAL_READS += count; 
        total_distinct++; 
        if(count==1) n1++; 
        if(count==2) n2++;
    } END {
        if(TOTAL_READS>0) {
            nrf = total_distinct/TOTAL_READS;
            pbc1 = n1/total_distinct;
            pbc2 = (n2 > 0) ? n1/n2 : 0;
            
            print "NRF," nrf;
            print "PBC1," pbc1;
            print "PBC2," pbc2;
            
            # Quality assessment
            nrf_status = (nrf >= 0.9) ? "PASS" : "FAIL";
            pbc1_status = (pbc1 >= 0.9) ? "PASS" : "FAIL";
            pbc2_status = (pbc2 >= 3) ? "PASS" : "FAIL";
            
            printf "[METRIC] NRF: %.4f [%s]\n", nrf, nrf_status > "/dev/stderr";
            printf "[METRIC] PBC1: %.4f [%s]\n", pbc1, pbc1_status > "/dev/stderr";
            printf "[METRIC] PBC2: %.4f [%s]\n", pbc2, pbc2_status > "/dev/stderr";
            
            if(nrf < 0.9) print "[WARN] Low NRF indicates poor library complexity" > "/dev/stderr";
            if(pbc1 < 0.9) print "[WARN] Low PBC1 indicates bottlenecking" > "/dev/stderr";
            if(pbc2 < 3) print "[WARN] Low PBC2 indicates severe bottlenecking" > "/dev/stderr";
        } else {
            print "NRF,0"; print "PBC1,0"; print "PBC2,0";
            print "[ERROR] No reads for complexity calculation" > "/dev/stderr";
        }
    }' >> "${SUMMARY_QC}" 2>&1 || log_warn "Complexity calculation failed"
    
    log_progress "Complexity analysis complete"
    
    log_info "Cleaning up name-sorted BAM"
    rm -f "${NSORT_BAM}"
}

step_filter() {
    log_header "STEP 6: FILTERING & QC"
    
    CLEAN_BAM="${ALIGNDIR}/${SAMPLE}.clean.bam"
    
    log_info "Applying quality filters:"
    log_info "  - Remove unmapped, secondary, QC-fail, and duplicate reads"
    log_info "  - Minimum MAPQ: 30"
    [[ "$IS_PE" == "true" ]] && log_info "  - Require proper pairs"
    log_info "  - Keep only canonical chromosomes"
    log_info "  - Remove mitochondrial reads"
    
    local SAM_FLAGS="-F 1804 -q 30"
    [[ "$IS_PE" == "true" ]] && SAM_FLAGS="$SAM_FLAGS -f 2"

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
    | samtools view -b -@ "${THREADS}" -o "${CLEAN_BAM}" \
    || fail "Filtering failed"
    
    log_progress "Filtered BAM created: $(basename "$CLEAN_BAM")"
    
    log_info "Indexing filtered BAM"
    samtools index -@ "${THREADS}" "${CLEAN_BAM}" || fail "BAM indexing failed"
    log_progress "Index created"
    
    
    local TOTAL_READS=$(samtools view -c -@ "${THREADS}" "${MARKED_BAM}")
    local FILTERED_READS=$(samtools view -c -@ "${THREADS}" "${CLEAN_BAM}")
    local REMOVED_READS=$((TOTAL_READS - FILTERED_READS))
    
    if [[ "$TOTAL_READS" -gt 0 ]]; then
        local PCT_KEPT=$(awk "BEGIN {printf \"%.2f\", ($FILTERED_READS/$TOTAL_READS)*100}")
        
        local H_TOTAL=$(format_reads "$TOTAL_READS")
        local H_KEPT=$(format_reads "$FILTERED_READS")
        local H_REMOVED=$(format_reads "$REMOVED_READS")
        
        log_metric "Reads retained" "${H_KEPT} / ${H_TOTAL} (${PCT_KEPT}%)"
        log_metric "Reads removed" "${H_REMOVED}"
        
        log_qc "Reads_After_Filter" "$FILTERED_READS"
        log_qc "Percent_Retained" "$PCT_KEPT"
    else
        log_warn "No reads found in marked BAM for filtering statistics"
    fi
    
    log_info "Generating filtered BAM statistics"
    samtools flagstat -@ "${THREADS}" "${CLEAN_BAM}" > "${LOGDIR}/${SAMPLE}_clean_flagstat.txt"
    samtools stats -@ "${THREADS}" "${CLEAN_BAM}" > "${LOGDIR}/${SAMPLE}_clean_samstats.txt"
    samtools idxstats -@ "${THREADS}" "${CLEAN_BAM}" > "${LOGDIR}/${SAMPLE}_clean_idxstats.txt"
    log_progress "Statistics generated"
}

step_peaks_macs() {
    log_header "STEP 7: PEAK CALLING (MACS3)"
    
    local MACS_FORMAT="BAM"
    [[ "$IS_PE" == "true" ]] && MACS_FORMAT="BAMPE"
    
    log_info "Peak mode: ${PEAK_MODE}"
    log_info "Format: ${MACS_FORMAT}"
    log_info "Genome size: ${EFFECTIVE_GENOME_SIZE}"
    
    local MACS_ARGS="-g ${EFFECTIVE_GENOME_SIZE} -n ${SAMPLE} --outdir ${PEAKDIR} -q 0.05"
    
    if [[ "$ASSAY_TYPE" == "atac" ]]; then
        MACS_ARGS="$MACS_ARGS --nomodel --shift -100 --extsize 200"
        log_info "ATAC-seq mode: using --nomodel with shift/extsize adjustments"
    fi
    
    if [[ "$PEAK_MODE" == "broad" ]]; then
        MACS_ARGS="$MACS_ARGS --broad --broad-cutoff 0.1"
        RAW_PEAKS="${PEAKDIR}/${SAMPLE}_peaks.broadPeak"
        FINAL_PEAKS="${PEAKDIR}/${SAMPLE}.final.broadPeak"
        log_info "Broad peak calling enabled (cutoff: 0.1)"
    else
        RAW_PEAKS="${PEAKDIR}/${SAMPLE}_peaks.narrowPeak"
        FINAL_PEAKS="${PEAKDIR}/${SAMPLE}.final.narrowPeak"
        log_info "Narrow peak calling (default)"
    fi

    log_info "Running MACS3 callpeak"
    macs3 callpeak -t "${CLEAN_BAM}" -f "${MACS_FORMAT}" ${MACS_ARGS} \
        &>> "${LOGDIR}/macs3.log" || fail "MACS3 peak calling failed"
    log_progress "Peak calling completed"
    
    local peak_count=$(wc -l < "${RAW_PEAKS}")
    log_metric "Peaks called" "$peak_count"
    
    if [[ -n "${BLACKLIST}" && -f "${BLACKLIST}" ]]; then
        log_info "Filtering blacklisted regions"
        bedtools intersect -v -a "${RAW_PEAKS}" -b "${BLACKLIST}" > "${FINAL_PEAKS}" \
            || fail "Blacklist filtering failed"
        local filtered_peaks=$(wc -l < "${FINAL_PEAKS}")
        local removed_peaks=$((peak_count - filtered_peaks))
        log_progress "Blacklist filter: removed ${removed_peaks} peaks"
        log_metric "Final peaks" "$filtered_peaks"
        log_qc "MACS3_Peaks_Final" "$filtered_peaks"
    else
        cp "${RAW_PEAKS}" "${FINAL_PEAKS}"
        log_info "No blacklist provided, using all peaks"
        log_qc "MACS3_Peaks_Final" "$peak_count"
    fi
}

step_peaks_seacr() {
    log_header "PEAK CALLING (SEACR)"
    
    log_info "Generating bedgraph for SEACR"
    
    log_info "Converting BAM to BED fragments"
    
    samtools sort -n -@ "${THREADS}" -o "${WORKDIR}/${SAMPLE}.namesorted.bam" "${CLEAN_BAM}" \
        2>> "${LOGDIR}/seacr.log" || fail "Name sorting failed"
    
    
    bedtools bamtobed -bedpe -i "${WORKDIR}/${SAMPLE}.namesorted.bam" 2>&1 \
    | grep -v "WARNING: Query.*is marked as paired" \
    | awk '$1==$4 && $6-$2 < 1000 {print $0}' \
    | cut -f 1,2,6 \
    | sort -k1,1 -k2,2n -k3,3n > "${WORKDIR}/${SAMPLE}.fragments.bed" \
        2>> "${LOGDIR}/seacr.log" || fail "Fragment generation failed"
    
    
    rm -f "${WORKDIR}/${SAMPLE}.namesorted.bam"
    log_progress "Fragments generated"
    
    log_info "Extracting chromosome sizes"
    samtools view -H "${CLEAN_BAM}" \
    | grep "@SQ" \
    | sed 's/@SQ\tSN:\|LN://g' > "${WORKDIR}/chrom.sizes" \
        || fail "Chromosome size extraction failed"
    log_progress "Chromosome sizes extracted"
    
    log_info "Creating bedgraph coverage"
    bedtools genomecov -bg -i "${WORKDIR}/${SAMPLE}.fragments.bed" \
        -g "${WORKDIR}/chrom.sizes" > "${WORKDIR}/${SAMPLE}.bg" \
        2>> "${LOGDIR}/seacr.log" || fail "Bedgraph generation failed"
    log_progress "Bedgraph created"
    
    log_info "Running SEACR (stringent mode, top 1% threshold)"
    SEACR_1.3.sh "${WORKDIR}/${SAMPLE}.bg" 0.01 non stringent \
        "${PEAKDIR}/${SAMPLE}_SEACR" \
        &>> "${LOGDIR}/seacr.log" || log_warn "SEACR peak calling failed"
    
    if [[ -f "${PEAKDIR}/${SAMPLE}_SEACR.stringent.bed" ]]; then
        local seacr_peaks=$(wc -l < "${PEAKDIR}/${SAMPLE}_SEACR.stringent.bed")
        log_metric "SEACR peaks" "$seacr_peaks"
        log_qc "SEACR_Peaks" "$seacr_peaks"
        log_progress "SEACR peak calling completed"
    else
        log_warn "SEACR did not produce output file"
    fi
}

step_frip() {
    local peak_file="$1"
    local label="$2"
    
    log_step "Computing FRiP for ${label}"
    
    if [[ ! -s "${peak_file}" ]]; then
        log_warn "Peak file empty or missing: ${peak_file}"
        return
    fi
    
    log_info "Peak file: $(basename "$peak_file")"
    
    local TOTAL_READS
    if [[ "$IS_PE" == "true" ]]; then
        TOTAL_READS=$(samtools view -c -f 66 "${CLEAN_BAM}")
        log_info "Counting proper pairs"
    else
        TOTAL_READS=$(samtools view -c -F 4 "${CLEAN_BAM}")
        log_info "Counting mapped reads"
    fi
    
    log_info "Intersecting reads with peaks (minimum 20% overlap)"
    local READS_IN_PEAKS
    READS_IN_PEAKS=$(bedtools intersect -a "${CLEAN_BAM}" -b "${peak_file}" \
        -bed -u -f 0.2 | wc -l) || fail "FRiP calculation failed"
    
    local FRIP=0
    if [[ "$TOTAL_READS" -gt 0 ]]; then
        FRIP=$(awk "BEGIN {printf \"%.4f\", $READS_IN_PEAKS/$TOTAL_READS}")
        local FRIP_PCT=$(awk "BEGIN {printf \"%.2f%%\", ($READS_IN_PEAKS/$TOTAL_READS)*100}")
        
        log_metric "FRiP (${label})" "${FRIP} (${FRIP_PCT})"
        log_qc "FRiP_${label}" "${FRIP}"
        
        
        local quality="POOR"
        if (( $(awk "BEGIN {print ($FRIP >= 0.3)}") )); then
            quality="GOOD"
        elif (( $(awk "BEGIN {print ($FRIP >= 0.2)}") )); then
            quality="ACCEPTABLE"
        fi
        log_info "FRiP quality: ${quality}"
        
    else
        log_warn "No reads found for FRiP calculation"
    fi
}

step_insert_size() {
    if [[ "$IS_PE" != "true" ]]; then
        log_info "Skipping insert size (single-end data)"
        return
    fi
    
    log_step "Computing insert size distribution"
    
    log_info "Running Picard CollectInsertSizeMetrics"
    picard CollectInsertSizeMetrics \
        -I "${CLEAN_BAM}" \
        -O "${QCDIR}/${SAMPLE}_insert_size.txt" \
        -H "${QCDIR}/${SAMPLE}_insert_size.pdf" \
        -M 0.5 \
        --VALIDATION_STRINGENCY SILENT \
        &>> "${LOGDIR}/picard.log" || fail "Insert size calculation failed"
    
    log_progress "Insert size metrics generated"
    
    
    local median_insert=$(awk 'NR>7 && NF>0 && $1 ~ /^[0-9]+$/ {print $1; exit}' "${QCDIR}/${SAMPLE}_insert_size.txt")
    if [[ -n "$median_insert" ]] && [[ "$median_insert" =~ ^[0-9]+$ ]]; then
        log_metric "Median insert size" "${median_insert}bp"
        log_qc "Median_Insert_Size" "$median_insert"
    else
        log_warn "Unable to extract median insert size from metrics"
    fi
}

step_post_deeptools() {
    log_header "STEP 8: SIGNAL TRACKS & DEEPTOOLS"
    
    VIZ_BAM="${CLEAN_BAM}"

    if [[ "$ASSAY_TYPE" =~ ^(atac|cuttag)$ ]]; then
        log_info "Applying Tn5 shift correction"
        log_info "Increasing file descriptor limit for processing"
        ulimit -n 65536
        
        SHIFTED_BAM="${WORKDIR}/${SAMPLE}.shifted.bam"
        SHIFTED_SORT_BAM="${WORKDIR}/${SAMPLE}.shifted.sort.bam"
        
        log_info "Running alignmentSieve with ATACshift"
        alignmentSieve --bam "${CLEAN_BAM}" --outFile "${SHIFTED_BAM}" \
            --ATACshift -p "${THREADS}" \
            &>> "${LOGDIR}/shift.log" || fail "Tn5 shift correction failed"
        log_progress "Tn5 shift applied"
        
        log_info "Sorting shifted BAM"
        samtools sort -@ "${THREADS}" -o "${SHIFTED_SORT_BAM}" "${SHIFTED_BAM}" \
            || fail "Shifted BAM sorting failed"
        log_progress "Shifted BAM sorted"
        
        log_info "Indexing shifted BAM"
        samtools index -@ "${THREADS}" "${SHIFTED_SORT_BAM}" \
            || fail "Shifted BAM indexing failed"
        log_progress "Shifted BAM indexed"
        
        VIZ_BAM="${SHIFTED_SORT_BAM}"
    fi

    log_info "Generating normalized coverage tracks"
    
    log_info "Creating RPGC-normalized BigWig"
    bamCoverage --bam "${VIZ_BAM}" \
        --outFileName "${TRACKDIR}/${SAMPLE}.RPGC.bw" \
        --binSize 10 \
        --normalizeUsing RPGC \
        --effectiveGenomeSize "${EFFECTIVE_GENOME_SIZE}" \
        -p "${THREADS}" \
        &>> "${LOGDIR}/bamcoverage.log" || fail "RPGC BigWig generation failed"
    log_progress "RPGC track: ${SAMPLE}.RPGC.bw"
    
    log_info "Creating CPM-normalized BigWig"
    bamCoverage --bam "${VIZ_BAM}" \
        --outFileName "${TRACKDIR}/${SAMPLE}.CPM.bw" \
        --binSize 10 \
        --normalizeUsing CPM \
        --effectiveGenomeSize "${EFFECTIVE_GENOME_SIZE}" \
        -p "${THREADS}" \
        &>> "${LOGDIR}/bamcoverage.log" || fail "CPM BigWig generation failed"
    log_progress "CPM track: ${SAMPLE}.CPM.bw"

    if [[ "$IS_PE" == "true" ]]; then
        log_info "Computing fragment size distribution"
        bamPEFragmentSize \
            -hist "${QCDIR}/${SAMPLE}_fragmentSize.png" \
            -T "Fragment size: ${SAMPLE}" \
            --maxFragmentLength 1000 \
            -b "${CLEAN_BAM}" \
            --samplesLabel "${SAMPLE}" \
            --table "${QCDIR}/${SAMPLE}_fragmentSize.txt" \
            -p "${THREADS}" \
            &>> "${LOGDIR}/bamPEFragmentSize.log" || fail "Fragment size analysis failed"
        log_progress "Fragment size plot: ${SAMPLE}_fragmentSize.png"
    fi
}

step_multiqc() {
    log_header "GENERATING QC REPORT"
    
    if ! command -v multiqc &>/dev/null; then
        log_warn "MultiQC not found, skipping consolidated report"
        return
    fi
    
    log_info "Running MultiQC on all QC outputs"
    multiqc "${LOGDIR}" "${QCDIR}" -o "${OUTDIR}/multiqc" \
        --filename "${SAMPLE}_multiqc_report" \
        --force \
        &>> "${LOGDIR}/multiqc.log" || log_warn "MultiQC failed"
    
    if [[ -f "${OUTDIR}/multiqc/${SAMPLE}_multiqc_report.html" ]]; then
        log_progress "MultiQC report: ${OUTDIR}/multiqc/${SAMPLE}_multiqc_report.html"
    fi
}

step_cleanup() {
    if [[ "$CLEAN_INTERMEDIATE" != "true" ]]; then
        log_info "Keeping intermediate files (--keep-tmp specified)"
        return
    fi
    
    log_header "CLEANUP"
    
    log_info "Removing intermediate files"
    local tmp_size=$(du -sh "${WORKDIR}" 2>/dev/null | cut -f1 || echo "unknown")
    rm -rf "${WORKDIR}" || log_warn "Failed to remove working directory"
    log_progress "Freed ${tmp_size} of disk space"
}


log_header "EPI-FLOW PIPELINE START"
log_info "Sample: ${SAMPLE}"
log_info "Assay: ${ASSAY_TYPE^^}"
log_info "Mode: $([ "$IS_PE" == "true" ] && echo "Paired-End" || echo "Single-End")"
echo


step_prepare
step_trim
step_align
step_mark_dups


if [[ "$ASSAY_TYPE" == "atac" ]]; then
    step_complexity
fi

step_filter


step_peaks_macs


if [[ "$PEAK_MODE" == "broad" ]]; then
    step_frip "${PEAKDIR}/${SAMPLE}.final.broadPeak" "MACS3_Broad"
else
    step_frip "${PEAKDIR}/${SAMPLE}.final.narrowPeak" "MACS3_Narrow"
fi


if [[ "$ASSAY_TYPE" =~ ^(cutrun|cuttag)$ ]]; then
    step_peaks_seacr
    if [[ -f "${PEAKDIR}/${SAMPLE}_SEACR.stringent.bed" ]]; then
        step_frip "${PEAKDIR}/${SAMPLE}_SEACR.stringent.bed" "SEACR"
    fi
fi


step_insert_size


step_post_deeptools


step_multiqc


step_cleanup


log_header "PIPELINE COMPLETE"
log_info "Sample: ${SAMPLE}"
log_info "Output directory: ${OUTDIR}"
echo
log_info "Key outputs:"
log_info "  • Final BAM: ${ALIGNDIR}/${SAMPLE}.clean.bam"
log_info "  • Peaks: ${PEAKDIR}/"
log_info "  • Tracks: ${TRACKDIR}/"
log_info "  • QC summary: ${SUMMARY_QC}"
log_info "  • MultiQC report: ${OUTDIR}/multiqc/"
log_elapsed

echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  ✓ Epi-Flow pipeline completed successfully${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"