# Installation

## Prerequisites
Epi-Flow relies on standard bioinformatics tools. We recommend using Conda/Mamba for reproducibility.

## Quick Start (Conda)

```bash
# 1. Create the environment
mamba create -n epiflow -c bioconda -c conda-forge \
    fastqc cutadapt bowtie2 samtools picard \
    bedtools macs3 deeptools multiqc seacr

# 2. Activate
mamba activate epiflow

# 3. Clone the repository
git clone https://github.com/zqzneptune/epi-flow.git
cd epi-flow
chmod +x epi_flow.sh
```

## HPC Modules
If you are on a cluster without Conda, load these modules:
*   `bowtie2/2.4.x`
*   `samtools/1.16+`
*   `macs3`
*   `bedtools`