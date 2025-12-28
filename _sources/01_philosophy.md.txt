# Design Philosophy

## The "White Box" Approach
Epi-Flow was born out of frustration with "black box" pipelines that hide their logic behind complex wrappers or containers. 

Our philosophy is transparency:
1.  **Pure Bash:** The logic is written in standard Bash. You can open the script and read exactly how `bowtie2` or `macs3` is being called.
2.  **Auditability:** Every step logs its exact parameters to `stderr` and log files.
3.  **PC & HPC Friendly:** Designed to run efficiently on a local workstation (automatically detecting RAM) or scale up on an HPC cluster.

## Unified Workflow
Instead of maintaining separate scripts for ATAC-seq, ChIP-seq, and CUT&RUN, Epi-Flow acts as a central engine. It detects the assay type and switches the underlying statistical models (e.g., peak calling thresholds, insert size filters) automatically.