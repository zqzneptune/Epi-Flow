# Preparing Analysis Resources

A successful analysis begins long before you run the first command. Proper preparation of your reference files is the single most important factor in generating accurate and reproducible results. This guide covers the three essential resources you need: a **Bowtie2 index**, the **effective genome size**, and a **blacklist file**.

> **The Rule of Consistency**
>
> All your reference files—the genome FASTA, the Bowtie2 index, gene annotations (GTF/GFF), and the blacklist—**must** be derived from the exact same genome assembly version (e.g., `hg38` or `GRCh38.p13`). Mixing assemblies is a common and critical source of errors.

---

## 1. The Reference Genome & Bowtie2 Index (`-x`)

Epi-Flow uses a specialized, pre-computed **Bowtie2 index** for ultra-fast read alignment. You only need to build this index once for each genome assembly.

### Step 1: Obtain the Reference Genome FASTA

First, you need the official DNA sequence for your organism. The best sources are major genomics consortia:
*   **GENCODE:** The gold standard for human and mouse, providing comprehensive annotation.
*   **Ensembl:** A massive database for hundreds of vertebrate species.
*   **UCSC:** A popular source with many useful tools and genome builds.

```bash
# Example: Downloading the primary human genome assembly from GENCODE
wget https://ftp.ebi.ac.uk/pub/databases/gencode/Gencode_human/release_45/GRCh38.primary_assembly.genome.fa.gz
gunzip GRCh38.primary_assembly.genome.fa.gz
```

### Step 2: Build the Bowtie2 Index

Once you have the FASTA file, use the `bowtie2-build` command to create the index files.

```bash
# Command format: bowtie2-build <input_fasta_file> <output_index_prefix>

bowtie2-build GRCh38.primary_assembly.genome.fa /path/to/your/genomes/hg38
```

*   **`<input_fasta_file>`:** The `GRCh38.primary_assembly.genome.fa` file you just downloaded.
*   **`<output_index_prefix>`:** This is the crucial part. It's a name you choose that will be used as the base name for all the index files. This prefix (e.g., `/path/to/your/genomes/hg38`) is the **exact value you will provide to Epi-Flow using the `-x` flag.**

After the command finishes (which can take an hour for a human genome), your directory will contain several files with a `.bt2` or `.bt2l` extension. This is your index.

> **Pro Tip: Organize Your Genomes!**
>
> Create a dedicated directory on your system (e.g., `/data/genomes/`) to store all reference files. Within it, create a folder for each genome assembly (`hg38`, `mm10`, etc.). This keeps your indices, annotations, and blacklists neatly organized and easy to find for all your future projects.

### Command-Line Quick Start: Genome Indexing

Below are self-contained command blocks to download a reference genome from UCSC, build the Bowtie2 index, and clean up the downloaded files.

**Prerequisites:** You must have `wget` and `bowtie2` installed and available in your `PATH`.

Simply copy the entire block for your desired organism and paste it into your terminal. The indexing process can take a significant amount of time (over an hour for human/mouse) and memory.

---

#### Human (hg38)

This will download the hg38 reference genome, build the Bowtie2 index with the prefix `hg38`, and then remove the large FASTA file to save space.

```bash
# --- Human (hg38) ---
echo "Downloading hg38 reference genome from UCSC..."
wget -c -O hg38.fa.gz https://hgdownload.soe.ucsc.edu/goldenPath/hg38/bigZips/hg38.fa.gz && \
echo "Decompressing..." && \
gunzip hg38.fa.gz && \
echo "Building Bowtie2 index (this will take a while)..." && \
bowtie2-build hg38.fa hg38 && \
echo "Cleaning up large FASTA file..." && \
rm hg38.fa && \
echo "Done. Bowtie2 index 'hg38' is ready in the current folder."
```

---

#### Mouse (mm10)

This will download the mm10 reference genome, build the Bowtie2 index with the prefix `mm10`, and clean up.

```bash
# --- Mouse (mm10) ---
echo "Downloading mm10 reference genome from UCSC..."
wget -c -O mm10.fa.gz https://hgdownload.soe.ucsc.edu/goldenPath/mm10/bigZips/mm10.fa.gz && \
echo "Decompressing..." && \
gunzip mm10.fa.gz && \
echo "Building Bowtie2 index (this will take a while)..." && \
bowtie2-build mm10.fa mm10 && \
echo "Cleaning up large FASTA file..." && \
rm mm10.fa && \
echo "Done. Bowtie2 index 'mm10' is ready in the current folder."
```

---

#### Rat (rn7)

This will download the rn7 reference genome, build the Bowtie2 index with the prefix `rn7`, and clean up.

```bash
# --- Rat (rn7) ---
echo "Downloading rn7 reference genome from UCSC..."
wget -c -O rn7.fa.gz https://hgdownload.soe.ucsc.edu/goldenPath/rn7/bigZips/rn7.fa.gz && \
echo "Decompressing..." && \
gunzip rn7.fa.gz && \
echo "Building Bowtie2 index..." && \
bowtie2-build rn7.fa rn7 && \
echo "Cleaning up large FASTA file..." && \
rm rn7.fa && \
echo "Done. Bowtie2 index 'rn7' is ready in the current folder."
```

---

#### Zebrafish (danRer11)

This will download the danRer11 reference genome, build the Bowtie2 index with the prefix `danRer11`, and clean up.

```bash
# --- Zebrafish (danRer11) ---
echo "Downloading danRer11 reference genome from UCSC..."
wget -c -O danRer11.fa.gz https://hgdownload.soe.ucsc.edu/goldenPath/danRer11/bigZips/danRer11.fa.gz && \
echo "Decompressing..." && \
gunzip danRer11.fa.gz && \
echo "Building Bowtie2 index..." && \
bowtie2-build danRer11.fa danRer11 && \
echo "Cleaning up large FASTA file..." && \
rm danRer11.fa && \
echo "Done. Bowtie2 index 'danRer11' is ready in the current folder."```
```

---

#### Fruit Fly (dm6)

This will download the dm6 reference genome, build the Bowtie2 index with the prefix `dm6`, and clean up.

```bash
# --- Fruit Fly (dm6) ---
echo "Downloading dm6 reference genome from UCSC..."
wget -c -O dm6.fa.gz https://hgdownload.soe.ucsc.edu/goldenPath/dm6/bigZips/dm6.fa.gz && \
echo "Decompressing..." && \
gunzip dm6.fa.gz && \
echo "Building Bowtie2 index..." && \
bowtie2-build dm6.fa dm6 && \
echo "Cleaning up large FASTA file..." && \
rm dm6.fa && \
echo "Done. Bowtie2 index 'dm6' is ready in the current folder."
```

After running one of these blocks, the output prefix (`hg38`, `mm10`, etc.) in your current directory is what you should provide to the `-x` flag when running Epi-Flow.

---

## 2. Effective Genome Size (`-g`)

The "effective genome size" is the portion of the genome that is mappable. It's smaller than the full genome sequence because it excludes repetitive regions and areas filled with 'N's where reads cannot be uniquely aligned. This value is essential for the statistical models used in peak calling by `MACS3`.

For common organisms, you can use these pre-calculated values:

| Genome Assembly | Shorthand | Effective Size (Integer for `-g`) |
| :--- | :--- | :--- |
| Human (GRCh38 / hg38) | `hs` | `2913022398` |
| Mouse (GRCm38 / mm10) | `mm` | `2652783500` |
| C. elegans (ce10) | `ce` | `97985443` |
| D. melanogaster (dm6) | `dm` | `142573017` |

### What if my organism isn't listed?
You can calculate the effective size yourself and find more information from the [deepTools](https://deeptools.readthedocs.io/en/latest/index.html) package.



---

## 3. Blacklist Regions (`-b`)

Blacklist regions are the Achilles' heel of chromatin analysis. They are genomic regions that consistently attract high, artificial signals in sequencing experiments regardless of the cell type or protein being targeted. They are like "sticky" spots on the genome that can be easily mistaken for real biological peaks.

**Filtering these regions is not optional; it is essential for high-quality results.**

### Where to get Blacklist Files
The **ENCODE project** maintains the most widely used set of blacklist files.
*   **[Download Blacklist Files from Boyle-Lab/Blacklist on GitHub](https://github.com/Boyle-Lab/Blacklist)**

Find the appropriate file for your genome assembly (e.g., `hg38-blacklist.v2.bed`), download it, and provide the path to it using the `-b` flag in Epi-Flow.

**What does a blacklist region look like?** In a genome browser, they often appear as extremely sharp, narrow towers of signal that are present across many different experiments, including input controls. By removing them, you ensure your final peak set is enriched for true biological signals.

---

### Preparation Checklist

Before you run Epi-Flow, make sure you have:

- [ ] **A Bowtie2 Index:** You know the full path to the index prefix (for the `-x` flag).
- [ ] **The Effective Genome Size:** You have the correct integer value for your assembly (for the `-g` flag).
- [ ] **A Blacklist File:** You have downloaded the BED file for your assembly (for the `-b` flag).