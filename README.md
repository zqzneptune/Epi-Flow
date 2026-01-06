# Epi-Flow

[![Documentation](https://img.shields.io/badge/docs-latest-blue.svg)](https://zqzneptune.github.io/Epi-Flow/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Language](https://img.shields.io/badge/language-Bash-green.svg)]()

**A transparent and unified Bash pipeline for processing raw sequencing data from epigenetics experiments.**

Epi-Flow takes your raw FASTQ files and produces analysis-ready alignments, peaks, signal tracks, and a comprehensive quality control report. It is designed to be readable, reproducible, and portable, running on anything from a personal workstation to an HPC cluster.

## Key Features

**Unified Workflow:** A single, intelligent script handles multiple chromatin profiling assays with protocol-aware parameter adjustments.

**White-Box Design:** Written in pure Bash for ultimate transparency. No complex wrappers or containers—you can read and understand every step of the analysis.

**Comprehensive QC:** Integrates FastQC, Picard, deepTools, and more, culminating in a single, interactive MultiQC report to give you full confidence in your data.

**Portable & Reproducible:** Runs anywhere Bash is available. With strict error handling and detailed logging, your analyses are robust and entirely reproducible.

---

## Getting Started

A quick two-step guide to get up and running.

### 1. Clone the Repository

```bash
git clone https://github.com/zqzneptune/epi-flow.git
cd epi-flow
chmod +x epi_flow.sh
```

### 2. Visit the Full Documentation

**All installation instructions, tutorials, and parameter guides have been moved to our dedicated documentation site.** This is the best place to start.

### ➡️ [**Read the Full Documentation at zqzneptune.github.io/Epi-Flow/**](https://zqzneptune.github.io/Epi-Flow/)

---

## Quick Example

The pipeline is run from the command line. Here is a typical command for an ATAC-seq experiment:

```bash
./epi_flow.sh \
    -a atac \
    -n MySample_ATAC_Rep1 \
    -1 path/to/MySample_R1.fastq.gz \
    -2 path/to/MySample_R2.fastq.gz \
    -x /path/to/genomes/hg38 \
    -g 2913022398 \
    -b /path/to/genomes/hg38-blacklist.v2.bed \
    -o ./results/MySample_ATAC_Rep1
```
_For detailed parameter explanations and examples for other assays, please see the [**Usage**](https://zqzneptune.github.io/Epi-Flow/05_use_cases.html) section in our documentation._

---

## Contributing

We welcome contributions! Please see the [**Support & Contributions**](https://zqzneptune.github.io/Epi-Flow/08_support.html) page in our documentation for details on how to report issues or submit a pull request.

## License

This project is licensed under the MIT License. See the `LICENSE` file for details.