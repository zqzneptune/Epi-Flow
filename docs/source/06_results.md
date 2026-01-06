# Interpreting Your Results

The pipeline has finished, and you have a folder full of files. This is where the real scientific discovery begins. A pipeline's output is not a final answer; it is a statistical hypothesis that must be critically evaluated. This guide will walk you through understanding your results, performing essential quality checks, and thinking like a bioinformatician to ensure your data is telling an accurate story.

## The Output Directory Structure

First, let's map out the files Epi-Flow has generated for you.

```
<output_dir>/
├── alignments/
│   ├── {sample_name}.clean.bam      # Final, filtered alignments for visualization
│   └── {sample_name}.clean.bam.bai  # Index for the BAM file
├── peaks/
│   ├── {sample_name}.final.narrowPeak # Final, blacklist-filtered peaks
│   └── ... (other MACS3/SEACR files)
├── tracks/
│   └── {sample_name}.RPGC.bw        # Normalized signal track for genome browsers
├── qc/
│   ├── {sample_name}_summary_qc.csv # Key metrics in a machine-readable format
│   └── ... (All raw QC files from Picard, etc.)
├── logs/
│   └── ... (Log files for every step, crucial for debugging)
└── multiqc/
    └── {sample_name}_multiqc_report.html # Your primary quality control dashboard
```

---
## The Critical First Step: Your QC Dashboard

**Before you look at a single peak, you must assess the quality of your data.** The most important file for this is the **`multiqc/` report**. Open the `.html` file in any web browser.

This interactive report is your lab notebook for the experiment's health. Here are the key plots to inspect:

#### 1. Alignment Rate (Bowtie2)
*   **What it is:** The percentage of reads that successfully aligned to the reference genome.
*   **What to look for:** A high alignment rate (typically > 80-90%) is expected. A low rate could indicate sample contamination, a major library prep issue, or using the wrong reference genome.

#### 2. Duplication Rate (Picard)
*   **What it is:** The percentage of reads that are identical and likely originated from PCR amplification of the same initial DNA fragment.
*   **What it means:**
    *   For **ChIP-seq & ATAC-seq**, a high duplication rate (> 20-30%) can indicate a low-complexity library, where you sequenced the same few fragments over and over. This reduces the effective depth of your experiment.
    *   For **CUT&RUN & CUT&Tag**, a high duplication rate is **expected and normal**. These methods are highly efficient and often target the same region repeatedly, leading to what looks like high duplication.

#### 3. Fragment Size Distribution (deepTools)
*   **What it is (Paired-End Only):** A plot showing the length of the DNA fragments that were sequenced.
*   **What to look for in ATAC-seq:** A healthy ATAC-seq library will show a beautiful, periodic pattern with a large peak at < 100 bp (nucleosome-free regions) followed by smaller peaks at ~200 bp intervals (mono-, di-, and tri-nucleosomes). The absence of this pattern can indicate issues with the transposition reaction.

#### 4. FRiP Score (Fraction of Reads in Peaks)
*   **What it is:** The single best metric for signal-to-noise. It calculates the percentage of all your high-quality, filtered reads that fall inside a called peak.
*   **What it means:** A high FRiP score indicates good signal enrichment (your antibody worked well, or your open chromatin regions were captured efficiently). A low score suggests poor enrichment or high background noise.
*   **Rule of Thumb (use with caution):**
    *   **Poor:** < 1%
    *   **Acceptable:** 1-5%
    *   **Good:** 5-10%
    *   **Excellent:** > 10-20%+ (often seen with sharp TFs or in CUT&RUN)

> If your QC metrics look poor, **STOP**. Do not proceed with downstream analysis. A conclusion drawn from bad data is worse than no conclusion at all. Go back and troubleshoot your wet lab protocol or initial data quality.

---

## Exploring Your Biological Signal

Once you are confident in your data's quality, you can explore the primary results.

### 1. Visualize, Visualize, Visualize!

**You must always look at your data in a genome browser.** This is a non-negotiable sanity check. The most popular tool is the [Integrative Genomics Viewer (IGV)](https://software.broadinstitute.org/software/igv/).

1.  **Load your reference genome** in IGV.
2.  **Load your data files** from the Epi-Flow output:
    *   `peaks/{sample_name}.final.narrowPeak`: Shows the locations of your called peaks.
    *   `tracks/{sample_name}.RPGC.bw`: Shows the normalized signal density. This is the smoothest and most quantitative way to view your data.
    *   `alignments/{sample_name}.clean.bam`: (Optional) Shows the raw read alignments. This is useful for troubleshooting and deep-dives into specific regions.

### 2. Let Your Data "Speak": Ask Critical Questions

As you browse your data, don't just passively look. Actively question it:
*   **Do the peaks match the signal?** The regions defined in your `.narrowPeak` file should correspond to the highest mountains in your `.bw` signal track.
*   **Check a positive control gene:** Navigate to a gene locus where you *expect* to see a signal. For example:
    *   If you did a CTCF ChIP-seq, go to a known insulator region.
    *   If you did an ATAC-seq on an active cell line, go to the promoter of a housekeeping gene like `GAPDH`. Does it have an open chromatin peak?
*   **Check a negative control gene:** Go to the locus of a gene you know should be silent in your cells. Is the region free of signal as expected?
*   **Does the peak shape make sense?** Are your transcription factor peaks sharp and narrow? Are your H3K27me3 domains broad and diffuse?

This visual validation is your final and most important confirmation that the pipeline's output reflects the underlying biology.

### 3. Next Steps on Your Scientific Journey

The files generated by Epi-Flow are the starting point for countless downstream analyses:

*   **Motif Discovery:** Use your `.final.narrowPeak` file as input for tools like **MEME Suite** to discover DNA motifs enriched under your peaks.
*   **Functional Annotation:** Use tools like **HOMER** or **GREAT** to determine what genes are near your peaks and what biological pathways they are involved in.
*   **Differential Analysis:** After running Epi-Flow on multiple samples (e.g., treatment vs. control), use your peak and BAM files in specialized packages like **DiffBind** or **DESeq2** to find statistically significant differences.