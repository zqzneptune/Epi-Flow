# Use Cases & Practical Examples

This section translates common biological experiments into ready-to-use Epi-Flow commands. Each example includes a detailed breakdown of the parameter choices to help you understand the "why" behind the "how."

---

## Scenario 1: Standard Paired-End ATAC-seq

**Goal:** To identify regions of open chromatin in a human cell line (GM12878) using standard paired-end ATAC-seq data.

**The Command:**
```bash
./epi_flow.sh \
    -a atac \
    -n GM12878_ATAC_Rep1 \
    -1 data/GM12878_Rep1_R1.fastq.gz \
    -2 data/GM12878_Rep1_R2.fastq.gz \
    -x /path/to/genomes/hg38 \
    -g 2913022398 \
    -b /path/to/genomes/hg38-blacklist.v2.bed \
    -t 16 \
    -o ./results/atac_seq
```

### Parameter Breakdown:

*   `-a atac`: This is the most important flag here. It tells Epi-Flow to activate the specialized ATAC-seq workflow, which includes:
    1.  **Tn5 Shift Correction:** It will use `alignmentSieve` to adjust the read alignments to the center of the Tn5 transposon binding event, which is essential for high-resolution footprinting.
    2.  **MACS3 in ATAC-seq Mode:** It passes the `--nomodel --shift -100 --extsize 200` parameters to `macs3`, which are the recommended settings for nucleosome-free peak calling.
*   `-n GM12878_ATAC_Rep1`: A clear and descriptive sample name.
*   `-2 ...`: The Read 2 FASTQ file is provided, confirming this is a paired-end run.
*   `-b ...`: We provide a blacklist file to filter out artifactual regions, which is a critical step for clean ATAC-seq results.
*   `-t 16`: We are allocating 16 CPU threads for the analysis. Adjust this based on your system's resources.

---

## Scenario 2: ChIP-seq for a Transcription Factor (Narrow Peaks)

**Goal:** To map the binding sites of the CTCF transcription factor in a human cell line (HeLa). The data for this sample was sequenced across two lanes and needs to be merged.

**The Command:**
```bash
./epi_flow.sh \
    -a chip \
    -n HeLa_CTCF_Rep1 \
    -1 data/L001_R1.fq.gz,data/L002_R1.fq.gz \
    -2 data/L001_R2.fq.gz,data/L002_R2.fq.gz \
    -x /path/to/genomes/hg38 \
    -g 2913022398 \
    -b /path/to/genomes/hg38-blacklist.v2.bed \
    -p narrow \
    -o ./results/chip_seq/ctcf
```

### Parameter Breakdown:

*   `-a chip`: We use the general-purpose `chip` mode.
*   `-1 ...,...` and `-2 ...,...`: This demonstrates how to handle multiple FASTQ files for a single sample. By providing a comma-separated list (with no spaces), Epi-Flow will automatically concatenate the files from each lane before alignment.
*   `-p narrow`: **This is the key parameter for this experiment.** CTCF binds to specific DNA motifs, creating sharp, well-defined signal peaks. The `narrow` setting tells `macs3` to use a model optimized for finding these punctate binding events.
*   `-b ...`: As always, using a blacklist is a best practice for ChIP-seq to avoid false positives.

---

## Scenario 3: ChIP-seq for a Broad Histone Mark (Single-End)

**Goal:** To identify genomic regions decorated with the repressive histone mark H3K27me3 in mouse embryonic stem cells (mESCs). The data is single-end.

**The Command:**
```bash
./epi_flow.sh \
    -a chip \
    -n mESC_H3K27me3_Rep1 \
    -1 data/mESC_H3K27me3_SE.fastq.gz \
    -x /path/to/genomes/mm10 \
    -g 2652783500 \
    -b /path/to/genomes/mm10-blacklist.v2.bed \
    -p broad \
    -o ./results/chip_seq/h3k27me3
```

### Parameter Breakdown:

*   **Absence of `-2`**: By omitting the `-2` flag, Epi-Flow automatically detects that the data is single-end and adjusts the alignment and peak calling steps accordingly.
*   `-x /path/to/genomes/mm10` and `-g 2652783500`: We correctly specify the Bowtie2 index and effective genome size for the mouse `mm10` assembly.
*   `-p broad`: **This is the most critical setting for this analysis.** Unlike a transcription factor, H3K27me3 is a repressive mark that covers large genomic domains, often spanning multiple genes. The `broad` mode tells `macs3` to stitch together nearby enriched regions into larger "domain" peaks, which accurately reflects the underlying biology.

---

## Scenario 4: CUT&RUN for a Histone Modification

**Goal:** Profile the active histone mark H3K4me3 using CUT&RUN in a low-input sample of Drosophila cells.

**The Command:**
```bash
./epi_flow.sh \
    -a cutrun \
    -n S2_H3K4me3_Rep1 \
    -1 data/S2_H3K4me3_R1.fq.gz \
    -2 data/S2_H3K4me3_R2.fq.gz \
    -x /path/to/genomes/dm6 \
    -g 142573017 \
    -b /path/to/genomes/dm6-blacklist.bed \
    -o ./results/cutrun
```

### Parameter Breakdown:

*   `-a cutrun`: This flag is essential. It informs Epi-Flow that this is CUT&RUN data, which has a very low background signal compared to ChIP-seq. This triggers a key special behavior:
    1.  **SEACR Peak Calling:** In addition to a standard MACS3 run, the pipeline will automatically run **SEACR**, a peak caller specifically designed for the high signal-to-noise ratio of CUT&RUN data. The SEACR output (`{sample_name}_SEACR.stringent.bed`) is often the most reliable peak set for this type of data.
*   `-x /path/to/genomes/dm6` and `-g 142573017`: We use the correct reference files for the *Drosophila melanogaster* dm6 genome assembly.
*   `-p narrow` (Implied): Even though we don't specify it, the default MACS3 mode is `narrow`, which is appropriate for a sharp mark like H3K4me3. SEACR does not use this parameter.