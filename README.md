# Epi-Flow

**Unified Chromatin Profiling Pipeline**

Epi-Flow is a streamlined, end-centric Bash pipeline designed for the standardized processing of chromatin accessibility and occupancy assays. It provides a single entry point to handle **ATAC-seq**, **CUT&RUN**, **CUT&Tag**, and **ChIP-seq** data with minimal configuration.

## 🚀 Features

*   **Unified Interface:** One script (`epi_flow.sh`) handles multiple assay types.
*   **Smart Automation:** Automatically detects Paired-End/Single-End reads and adjusts parameters.
*   **Assay-Specific Optimization:**
    *   **ATAC-seq:** Tn5 shifting, library complexity metrics (NRF, PBC), BAMPE peak calling.
    *   **CUT&RUN/Tag:** Strict alignment constraints, dual peak calling (MACS3 + SEACR).
    *   **ChIP-seq:** Supports both broad and narrow peaks.
*   **Comprehensive QC:** Automated generation of fragment size plots, TSS enrichment surrogate (FRiP), duplication rates, and insert size metrics.
*   **Resource Efficient:** Dynamic memory allocation based on system limits.

## 🛠 Dependencies

Ensure the following tools are in your `$PATH` (Conda/Mamba recommended):
*   `fastqc` & `multiqc`
*   `cutadapt`
*   `bowtie2`
*   `samtools` & `bedtools`
*   `picard` (Java)
*   `macs3`
*   `deepTools` (`bamCoverage`, `bamPEFragmentSize`, `alignmentSieve`)
*   `SEACR_1.3.sh` (for CUT&RUN/Tag)

## 📖 Usage

### Basic Command
```bash
bash epi_flow.sh -a <ASSAY> -n <SAMPLE_NAME> -x <BOWTIE2_INDEX> -g <GENOME_SIZE> -o <OUTPUT_DIR> -1 <R1.fastq> [-2 <R2.fastq>]
```

### Options
| Flag | Description | Required |
| :--- | :--- | :---: |
| `-a` | Assay type: `atac`, `cutrun`, `cuttag`, or `chip` | ✅ |
| `-n` | Sample Name (used for file prefixes) | ✅ |
| `-x` | Path to Bowtie2 index prefix | ✅ |
| `-g` | Effective genome size (e.g., `hs`, `mm`, `ce`, or integer) | ✅ |
| `-o` | Output directory | ✅ |
| `-1` | R1 FastQ file (comma-separated for multiple lanes) | ✅ |
| `-2` | R2 FastQ file (required for ATAC/CUT& assays) | ⚠️ |
| `-p` | Peak mode: `narrow` (default) or `broad` | ❌ |
| `-b` | Blacklist BED file for filtering peaks | ❌ |
| `-t` | Number of threads (default: 8) | ❌ |

### Examples

**ATAC-seq (Paired-End):**
```bash
bash epi_flow.sh \
  -a atac \
  -n Sample_ATAC \
  -x /ref/hg38 \
  -g hs \
  -o ./results \
  -1 read1.fq.gz -2 read2.fq.gz \
  -b hg38.blacklist.bed
```

**CUT&RUN (Paired-End):**
```bash
bash epi_flow.sh \
  -a cutrun \
  -n Sample_H3K27me3 \
  -x /ref/mm10 \
  -g mm \
  -o ./results \
  -1 read1.fq.gz -2 read2.fq.gz
```

**ChIP-seq (Single-End):**
```bash
bash epi_flow.sh \
  -a chip \
  -n Sample_TF \
  -x /ref/hg38 \
  -g hs \
  -o ./results \
  -1 read1.fq.gz
```

## 📂 Output Structure

```text
results/
├── final/          # Clean BAMs, BigWigs, and Peaks
├── qc/             # FastQC, Fragment sizes, Library Complexity, Insert sizes
├── logs/           # Tool execution logs
├── multiqc/        # Aggregated MultiQC report
└── tmp/            # Intermediate files (deleted if --keep-tmp not set)
```

## License
[MIT License](LICENSE)