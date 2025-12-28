# Parameters

## Required Arguments

| Flag | Argument | Description |
| :--- | :--- | :--- |
| `-a` | `type` | Assay type: `atac`, `chip`, `cutrun`, `cuttag`, `chipmentation`. |
| `-1` | `file` | Path to Read 1 FASTQ file (gzipped). |
| `-n` | `string` | Sample name (no spaces). |
| `-x` | `path` | Bowtie2 index prefix. |
| `-o` | `path` | Output directory. |
| `-g` | `int` | Effective genome size (integer). |

## Optional Arguments

| Flag | Argument | Default | Description |
| :--- | :--- | :--- | :--- |
| `-2` | `file` | N/A | Path to Read 2. Required for paired-end assays. |
| `-b` | `file` | None | Blacklist BED file for filtering artifacts. |
| `-p` | `mode` | `narrow` | Peak calling mode (`narrow` or `broad`). |
| `-t` | `int` | `8` | Number of threads. |
| `-m` | `int` | Auto | Max memory in GB. |