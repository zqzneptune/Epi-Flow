# Installation & Setup

Epi-Flow is designed to be lightweight and portable, but it relies on a set of standard, powerful bioinformatics tools. This guide will walk you through the recommended setup process.

## Dependencies

Before installation, it's helpful to know what software the pipeline orchestrates. Epi-Flow is essentially a "conductor" for these tools:

| Tool | Purpose in Epi-Flow |
| :--- | :--- |
| **FastQC** | Gathers raw read quality metrics. |
| **Cutadapt** | Trims adapter sequences and low-quality bases. |
| **Bowtie2** | Performs fast and memory-efficient read alignment. |
| **Samtools** | The toolkit for manipulating alignment (BAM) files. |
| **Picard** | Marks PCR duplicates and collects alignment metrics. |
| **Bedtools** | Handles genomic interval operations (e.g., blacklist filtering). |
| **MACS3** | The primary peak caller for identifying signal enrichment. |
| **SEACR** | A specialized peak caller for low-background CUT&RUN/Tag data. |
| **DeepTools** | Generates normalized signal tracks (bigWig) and QC plots. |
| **MultiQC** | Aggregates all QC reports into a single interactive HTML file. |

## Recommended Method: Using Conda / Mamba

The most reliable and reproducible way to manage these dependencies is with a dedicated Conda environment. This isolates the pipeline's software from your system's other tools, preventing version conflicts.

We recommend using **Mamba**, a fast, drop-in replacement for Conda. The commands are interchangeable.

### Step 1: Create a Project Directory
First, create a directory for your project and navigate into it.
```bash
mkdir my_chromatin_analysis
cd my_chromatin_analysis
```

### Step 2: Create the Conda Environment

This is the most critical step. We provide an `environment.yml` file for a simple, one-command installation.

1.  **Create a file named `environment.yml`** in your project directory and paste the following content into it:

    ```yaml
    # environment.yml for Epi-Flow
    name: epiflow
    channels:
      - bioconda
      - conda-forge
    dependencies:
      - fastqc
      - cutadapt
      - bowtie2
      - samtools>=1.16
      - picard
      - bedtools
      - macs3
      - seacr
      - deeptools
      - multiqc
    ```

2.  **Create the environment** from this file using Mamba or Conda. Mamba is significantly faster.

    ```bash
    # Using Mamba (Recommended)
    mamba env create -f environment.yml

    # Or, using Conda
    conda env create -f environment.yml
    ```
    This command will download and install all the specified tools into an isolated environment named `epiflow`.

### Step 3: Get the Epi-Flow Script

Clone the Epi-Flow repository from GitHub.

```bash
git clone https://github.com/zqzneptune/epi-flow.git
```

This will create an `epi-flow` directory containing the pipeline script.

### Step 4: Verify the Installation

Now, let's confirm everything is working correctly.

1.  **Activate the Conda environment:**
    ```bash
    mamba activate epiflow
    ```
    Your command prompt should now be prefixed with `(epiflow)`.

2.  **Make the script executable:**
    This command gives your system permission to run the script. You only need to do this once.
    ```bash
    chmod +x ./epi-flow/epi_flow.sh
    ```

3.  **Run the help command:**
    ```bash
    ./epi-flow/epi_flow.sh --help
    ```

If the installation was successful, you will see the pipeline's usage information and a list of all available parameters printed to your screen. You are now ready to run your analysis!

---
## Alternative: Using HPC Modules

If you are on an HPC cluster and cannot use Conda, you can use the module system. **Note:** This method is less reproducible as module versions can vary between systems.

1.  **Find the required modules** on your system. Commands like `module avail` or `module spider` can help.
2.  **Load the modules.** The exact names will differ, but the command will look something like this:

    ```bash
    # Example module loading script for an HPC
    module load fastqc/0.11.9
    module load cutadapt/4.1
    module load bowtie2/2.4.5
    module load samtools/1.16.1
    module load picard/2.27.5
    module load bedtools/2.30.0
    module load macs3/3.0.0
    module load deeptools/3.5.1
    # ...and so on for all dependencies.
    ```
3.  After loading the modules, you can proceed directly to **Step 3** above to get the script and run it.
