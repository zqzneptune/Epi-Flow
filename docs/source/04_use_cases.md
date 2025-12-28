# Use Cases & Examples

## Scenario 1: Standard ATAC-seq
Processing paired-end ATAC-seq data from human cells. This run includes blacklist filtering and Tn5 shift correction.

```bash
./epi_flow.sh \
    -a atac \
    -n HeLa_ATAC_Rep1 \
    -1 data/R1.fq.gz -2 data/R2.fq.gz \
    -x /ref/hg38 -g 2913022398 \
    -b /ref/hg38.blacklist.bed \
    -o ./results
```

## Scenario 2: CUT&RUN (SEACR Mode)
Processing Histone modification profiling. The pipeline automatically switches to SEACR for peak calling, which is optimized for the low-background noise of CUT&RUN.

```bash
./epi_flow.sh \
    -a cutrun \
    -n K27me3_Rep1 \
    -1 data/R1.fq.gz -2 data/R2.fq.gz \
    -x /ref/mm10 -g 2652783500 \
    -o ./results_cutrun
```