# Design Philosophy

Epi-Flow was born out of a common frustration in bioinformatics: the "black box" pipeline. Many powerful tools are wrapped in complex frameworks or containers that hide the underlying logic, making them difficult to debug, modify, or truly understand.

My philosophy is the opposite. I believe that the best tools are the ones that empower researchers, and empowerment comes from **transparency, control, and trust.** This document outlines the core principles that guided the development of Epi-Flow.

## The "White Box" Approach

Epi-Flow is a "white box" by design. You should always know what's happening to your data. This is achieved through three key features:

### 1. Pure Bash for Ultimate Readability
The entire pipeline is a single, self-contained Bash script. There is no compiled code, no complex installation, and no hidden dependencies that need a specific container to run. If you can read a command-line instruction, you can understand the pipeline's logic. This makes it:
*   **Easy to Audit:** You can see the exact parameters passed to `bowtie2`, `macs3`, or any other tool.

*   **Easy to Modify:** Want to change a specific `samtools` flag or add a new step? You can edit the script directly without breaking a complex framework.

### 2. Built for Reproducibility
Scientific analysis must be reproducible. Epi-Flow ensures this by:

*   **Strict Error Handling:** Using `set -euo pipefail`, the pipeline will stop immediately if any command fails, preventing the propagation of errors.

*   **Detailed Logging:** Every step prints its status and parameters to the console and saves detailed logs in the `logs/` directory. This creates a permanent, auditable record of your analysis, which is crucial for publications.

### 3. Runs Anywhere: PC to HPC
Because it's a standard Bash script with common dependencies, Epi-Flow is incredibly portable. It runs natively on any Linux-based system, from a personal workstation to a high-performance computing (HPC) cluster. It automatically detects available memory and cores but allows for manual overrides, making it flexible for any environment.

## A Unified Engine for Multiple Assays

Instead of maintaining separate, slightly different scripts for ATAC-seq, ChIP-seq, and CUT&RUN, Epi-Flow provides a single, intelligent engine.

### Consistent Interface, Consistent Outputs
No matter the assay type, the user experience is the same. You use the same flags for sample names (`-n`), reference genomes (`-x`), and outputs (`-o`). More importantly, the output directory structure is identical, making it simple to automate downstream analysis across different experiments and data types.

### Protocol-Aware Intelligence
The `--assay` (`-a`) flag does more than just record the experiment type; it actively changes the pipeline's behavior based on the underlying biology of the technique.

*   **For ATAC-seq & CUT&Tag:** It automatically applies the **Tn5 shift correction**, which is critical for achieving base-pair resolution at transcription factor binding sites.

*   **For CUT&RUN & CUT&Tag:** It runs **SEACR**, a peak caller specifically designed for the low-background, high-signal-to-noise data characteristic of these assays.

*   **For ChIP-seq:** It adjusts `bowtie2` parameters to handle the expected insert sizes and allows for `broad` vs. `narrow` peak calling with `macs3`.

## Guiding Principles

1.  **Robustness Over Features:** The pipeline prioritizes stability and correctness. Every function is designed to be as fail-safe as possible.

2.  **Sensible, Science-Driven Defaults:** The default parameters are chosen based on best practices from peer-reviewed literature and consortium guidelines (like ENCODE) to provide excellent results for standard datasets.

3.  **Quality Control is Paramount:** The goal is not just to produce peaks, but to provide the context needed to judge their quality. Comprehensive QC is integrated at every stage, culminating in a MultiQC report that gives a holistic view of the data's health.

4.  **Adherence to Community Standards:** Epi-Flow uses industry-standard file formats (FASTQ, BAM, BED, bigWig) to ensure its outputs are compatible with the vast ecosystem of downstream analysis tools and genome browsers.

Ultimately, Epi-Flow is designed to be a tool you can understand, trust, and adapt to your specific research needs.
