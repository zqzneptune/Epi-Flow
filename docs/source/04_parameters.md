# Pipeline Parameters

Epi-Flow is controlled by a set of command-line flags. Understanding these parameters is key to tailoring the pipeline to your specific data and research questions.

## Required Arguments

These flags are the bare minimum required to start any Epi-Flow run.

| Flag | Argument | Description & Guidance |
| :--- | :--- | :--- |
| **`-a`** | `<string>` | **Assay Type.** This is the most important flag, as it tells the pipeline which internal logic to use. <br><br> **Accepted Values:**<br> • `atac`: For ATAC-seq data. Activates Tn5 shift correction and ATAC-specific MACS3 settings.<br> • `cutrun`: For CUT&RUN data. Activates SEACR peak calling.<br> • `cuttag`: For CUT&Tag data. Activates Tn5 shifting and SEACR.<br> • `chip`: For general ChIP-seq data. Uses standard MACS3 settings. |
| **`-1`** | `<path>` | **Path to Read 1 FASTQ file(s).** Must be gzipped (`.fastq.gz` or `.fq.gz`).<br><br> **For multiple files from the same sample** (e.g., from different sequencing lanes), provide them as a single, comma-separated string with no spaces: <br> ` -1 lane1_R1.fq.gz,lane2_R1.fq.gz` |
| **`-n`** | `<string>` | **Sample Name.** A unique identifier for your sample. This name will be used as the prefix for all output files. <br><br> **Best Practice:** Use a descriptive name without spaces or special characters (underscores are okay). <br> *Example:* `HCT116_H3K27ac_Rep1` |
| **`-x`** | `<path>` | **Bowtie2 Index Prefix.** The full path to the reference genome index you built in the preparation step. This is the base name of the index files (e.g., `/path/to/genomes/hg38`). |
| **`-o`** | `<path>` | **Output Directory.** The path to a directory where all results will be saved. <br><br> **Note:** The pipeline will create this directory if it doesn't exist. |
| **`-g`** | `<integer>` | **Effective Genome Size.** The integer value for the mappable size of your genome. <br><br> **Crucial for accurate peak calling statistics.** See the [**Preparation Guide**](./03_preparation.md) for a list of common values and how to calculate it for other organisms. |

---
## Paired-End Data

| Flag | Argument | Description & Guidance |
| :--- | :--- | :--- |
| **`-2`** | `<path>` | **Path to Read 2 FASTQ file(s).** This is **required** for all paired-end assays (`atac`, `cutrun`, `cuttag`, and paired-end `chip`). <br><br> The number and order of files must exactly match the files provided with `-1`: <br> ` -1 lane1_R1.fq.gz,lane2_R1.fq.gz ` <br> ` -2 lane1_R2.fq.gz,lane2_R2.fq.gz ` |

---
## Optional Arguments (Tuning & QC)

These flags allow you to customize the analysis, control resource usage, and improve filtering.

| Flag | Argument | Default | Description & Guidance |
| :--- | :--- | :--- | :--- |
| **`-p`** | `<string>` | `narrow` | **Peak Calling Mode.** Determines the type of peaks `MACS3` will look for. <br><br> **How to choose:** <br> • `narrow`: For sharp, punctate signals like transcription factors (e.g., CTCF), H3K4me3, and H3K27ac. <br> • `broad`: For diffuse histone marks that cover wide genomic domains (e.g., H3K27me3, H3K36me3, H3K9me3). |
| **`-b`** | `<path>` | None | **Blacklist BED file.** The path to a BED file containing artifact-prone genomic regions. <br><br> **Highly Recommended.** Using a blacklist file significantly improves the quality of your final peak set by removing false positives. |
| **`-t`** | `<integer>` | `8` | **Number of Threads.** The number of CPU cores to use for parallelizable tasks. <br><br> **Guidance:** Set this to the number of cores available on your machine, but it's often wise to leave one or two free for system processes (e.g., `nproc - 2`). |
| **`-m`** | `<integer>` | Auto-detect | **Maximum Memory in GB.** The total memory available for the pipeline. <br><br> Epi-Flow automatically detects system RAM, but you can override it on memory-limited systems or HPC nodes to ensure the pipeline requests the correct resources. |
| **`--keep-tmp`** | None | `false` | **Keep Temporary Files.** By default, the pipeline cleans up the `WORKDIR` to save space. <br><br> This flag prevents the deletion of intermediate files (merged FASTQs, raw BAMs, etc.), which is useful for debugging a failed run. |

### Putting It All Together: A Real-World Example

This command processes a **paired-end ChIP-seq** experiment for a **broad histone mark**, using **16 threads** and a **blacklist file**.

```bash
./epi_flow.sh \
    -a chip \
    -n K562_H3K27me3_Rep1 \
    -1 K562_H3K27me3_Rep1_R1.fq.gz \
    -2 K562_H3K27me3_Rep1_R2.fq.gz \
    -x /data/genomes/hg38 \
    -g 2913022398 \
    -b /data/genomes/hg38-blacklist.v2.bed \
    -p broad \
    -t 16 \
    -o ./results/K562_H3K27me3
```