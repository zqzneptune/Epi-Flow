# Epi-Flow: Unified Chromatin Analysis Pipeline

**Epi-Flow** is a robust, automated Bash pipeline designed for the processing of chromatin profiling NGS data. It unifies preprocessing, alignment, filtering, quality control, and peak calling into a single execution stream.

## Supported Assays

The pipeline dynamically adjusts parameters (alignment scoring, insert size handling, and peak calling strategies) based on the specific assay type provided:

| Assay Type | Flag | Description | Key Processing Differences |
| :--- | :--- | :--- | :--- |
| **ATAC-seq** | `-a atac` | Chromatin Accessibility | Tn5 shift correction, PE required, MACS3 (shift/extsize), 2kb max insert. |
| **CUT&RUN** | `-a cutrun` | Protein-DNA Interaction | SEACR peak calling, PE required, 700bp max insert. |
| **CUT&Tag** | `-a cuttag` | Protein-DNA Interaction | SEACR peak calling, Tn5 shift visualization, PE required. |
| **ChIP-seq** | `-a chip` | Protein-DNA Interaction | Standard MACS3 calling, supports SE or PE reads. |

---

## Environment Setup

### Conda / Mamba (Recommended)

To run the Epi-Flow pipeline, you need a specific set of bioinformatics tools. We recommend using **Mamba** (a faster replacement for Conda) to manage these dependencies in an isolated environment.

1.  **Create the environment**
    Run the following command to create an environment named `epiflow` with all required tools:

    ```bash
    mamba create -n epiflow -c bioconda -c conda-forge \
        fastqc \
        cutadapt \
        bowtie2 \
        samtools \
        picard \
        bedtools \
        macs3 \
        deeptools \
        multiqc \
        seacr
    ```

2.  **Activate the environment**
    Before running the pipeline, activate the environment:

    ```bash
    mamba activate epiflow
    ```

3.  **SEACR Configuration (Important)**
    The pipeline specifically looks for an executable named `SEACR_1.3.sh` for CUT&RUN/CUT&Tag analysis. The Conda installation typically installs this tool simply as `seacr`.

    To ensure the pipeline finds the tool correctly, create a symbolic link after activating the environment:

    ```bash
    # Ensure you are inside the active environment
    ln -s $(which seacr) $CONDA_PREFIX/bin/SEACR_1.3.sh
    ```

---

## Reference Data Setup

### 1. Bowtie2 Index (-x)
The pipeline requires a Bowtie2 index. If your reference genome is `hg38.fa`, the index files typically look like `hg38.1.bt2`, `hg38.2.bt2`, etc.
**Pass the prefix only.**

*   **File structure:** `/data/genomes/hg38.1.bt2`
*   **Argument:** `-x /data/genomes/hg38`

### 2. Effective Genome Size (-g)
Required for normalization (RPGC) and MACS3 peak calling. This parameter **only accepts integer values**. Do not use shortcuts like 'hs' or 'mm'.

Use the table below to find the correct integer for your genome reported in [deeptools site](https://deeptools.readthedocs.io/en/latest/content/feature/effectiveGenomeSize.html):

| Genome | Effective size |
| :--- | :--- |
| **GRCh37** | 2864785220 |
| **GRCh38** | 2913022398 |
| **T2T/CHM13CAT_v2** | 3117292070 |
| **GRCm37** | 2620345972 |
| **GRCm38** | 2652783500 |
| **GRCm39** | 2654621783 |
| **dm3** | 162367812 |
| **dm6** | 142573017 |
| **GRCz10** | 1369631918 |
| **GRCz11** | 1368780147 |
| **WBcel235** | 100286401 |
| **TAIR10** | 119482012 |


### 3. Blacklist (-b)
A BED file containing genomic regions to exclude. This is highly recommended to reduce false positives in ATAC, ChIP, and other chromatin profiling data, which often contain high-signal artifact regions.

**Recommended Resources:**
1.  **Boyle-Lab (ENCODE):** The standard source for ENCODE blacklists.
    *   URL: https://github.com/Boyle-Lab/Blacklist/tree/master

2.  **Dozmorov Lab:** A comprehensive and cross-referenced collection of exclusion ranges.
    *   URL: https://github.com/dozmorovlab/excluderanges/

**Important:** You must choose a blacklist file that matches your Bowtie2 index genome version exactly (e.g., do not use an hg19 blacklist with an hg38 index) to avoid mismatches.

*Note: This argument is optional. The pipeline will execute successfully without a blacklist, but results should be treated with caution as peak calls may include known genomic artifacts.*

---

## Usage

### Basic Syntax
```bash
./epi_flow.sh -a [ASSAY] -n [SAMPLE_NAME] -1 [R1] -2 [R2] -x [INDEX] -o [OUTDIR] -g [GENOME_SIZE_INT]
```

### Example: ATAC-seq (Paired-End)
```bash
./epi_flow.sh \
    -a atac \
    -n Sample_01 \
    -1 data/S1_L001_R1.fastq.gz,data/S1_L002_R1.fastq.gz \
    -2 data/S1_L001_R2.fastq.gz,data/S1_L002_R2.fastq.gz \
    -x /ref/bowtie2/hg38 \
    -g 2913022398 \
    -b /ref/blacklist/hg38-blacklist.v2.bed \
    -o ./results_atac \
    -t 16
```

### Example: ChIP-seq (Single-End)
```bash
./epi_flow.sh \
    -a chip \
    -n TF_ChIP \
    -1 data/TF_R1.fastq.gz \
    -x /ref/bowtie2/mm10 \
    -g 2652783500 \
    -o ./results_chip \
    -t 8
```

---

## Parameters Detailed

| Flag | Argument | Required | Description |
| :--- | :--- | :--- | :--- |
| **-a** | `atac`, `cutrun`, `cuttag`, `chip` | **Yes** | Defines the analysis mode and parameter presets. |
| **-1** | `path/to/R1.fq.gz` | **Yes** | Read 1 input. Multiple files can be comma-separated (no spaces). |
| **-2** | `path/to/R2.fq.gz` | Opt | Read 2 input. **Required** for ATAC, CUT&RUN, and CUT&Tag. |
| **-n** | `string` | **Yes** | Sample name used for output filenames and plot labels. |
| **-x** | `path/prefix` | **Yes** | Bowtie2 index prefix (e.g., `/data/hg38`). |
| **-o** | `path/dir` | **Yes** | Output directory. Will be created if it doesn't exist. |
| **-g** | `int` | **Yes** | Effective genome size integer. See Reference Data Setup table. |
| **-b** | `path/to/blacklist.bed` | No | BED file of regions to exclude from peaks. Highly recommended. |
| **-p** | `narrow` or `broad` | No | Peak calling mode for MACS3. Default: `narrow`. |
| **-t** | `int` | No | Number of CPU threads to use. Default: `8`. |
| **-m** | `int` | No | Max memory in GB. If omitted, script auto-detects system RAM. |
| **--keep-tmp** | N/A | No | If set, temporary intermediate files are not deleted at the end. |

---

## Output Structure

After a successful run, the output directory (`-o`) will contain:

```text
output_dir/
├── alignments/        # Final filtered BAM files
│   └── Sample.clean.bam
├── peaks/             # Peak calls
│   ├── Sample.final.narrowPeak  # MACS3 peaks (blacklist filtered)
│   └── Sample_SEACR.stringent.bed # SEACR peaks (CUT&RUN/Tag only)
├── tracks/            # Visualization files for IGV/UCSC
│   ├── Sample.RPGC.bw # Normalized by reads per genome coverage
│   └── Sample.CPM.bw  # Normalized by counts per million
├── qc/                # Quality Control metrics
│   ├── Sample_summary_qc.csv    # CSV of all calculated metrics
│   ├── Sample_insert_size.pdf   # Insert size distribution plot
│   └── Sample_fragmentSize.png  # Fragment size histogram
├── logs/              # Tool execution logs
└── multiqc/           # Consolidated HTML report
    └── Sample_multiqc_report.html
```

---

## Pipeline Steps Overview

1.  **Validation:** Checks inputs, pairs, and dependencies.
2.  **Pre-QC & Merge:** Runs FastQC and merges multiple lane files if comma-separated.
3.  **Trimming:** Uses `cutadapt` to remove adapters (default Nextera) and low-quality bases.
4.  **Alignment:** `bowtie2` with assay-specific parameters:
    *   *ATAC/CUT&RUN:* `--very-sensitive`, no discordant alignment, specific insert size limits.
5.  **Mark Duplicates:** Uses `picard MarkDuplicates`. Note: Duplicates are marked but usually *not removed* until the filtering step.
6.  **Complexity Analysis:** Calculates NRF (Non-Redundant Fraction), PBC1, and PBC2 to assess library bottlenecking.
7.  **Filtering:** `samtools` removes unmapped, low quality (MAPQ < 30), mitochondrial, and blacklisted reads.
8.  **Peak Calling:**
    *   **MACS3:** Standard for ChIP/ATAC.
    *   **SEACR:** Top 1% stringent peaks for CUT&RUN/Tag.
9.  **Metrics:** Calculates FRiP (Fraction of Reads in Peaks) scores.
10. **Visualization:** Generates BigWigs (`bamCoverage`) and applies Tn5 shifting for ATAC/CUT&Tag.
11. **Reporting:** Aggregates all stats into `MultiQC`.