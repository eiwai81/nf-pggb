# pggb-nf

A streamlined Nextflow DSL2 wrapper around PGGB. The workflow prepares BGZF FASTA inputs, optionally partitions multi-chromosome pangenomes into communities, and runs PGGB as one task per input or community.

## Input

CSV with required `id,fasta` columns and optional `n_haplotypes,vcf_spec` columns:

```csv
id,fasta,n_haplotypes,vcf_spec,pct_id
chr1,/absolute/path/chr1.fa.gz,5,,95
chr2,/absolute/path/chr2.fa.gz,5,,94

```

## Run

```bash
nextflow run . --input samplesheet.csv --outdir results -profile docker
```

Apptainer on EC2:

```bash
export NXF_WORK=/home/ubuntu/scratch/nextflow-work
nextflow run . --input samplesheet.csv --outdir results -profile apptainer,ec2 -resume
```

Optional community partitioning:

```bash
nextflow run . --input samplesheet.csv --community true --outdir results -profile apptainer,ec2
```

Ryegrass starting preset:

```bash
nextflow run . --input samplesheet.csv -c conf/ryegrass.config -profile apptainer,ec2
```

## Key parameters

- `map_pct_id`: PGGB `-p`
- `segment_length`: PGGB `-s`
- `block_length`: PGGB `-l`
- `min_match_length`: PGGB/Seqwish `-k`
- `n_mappings`: PGGB `-c`
- `pggb_args`: additional trusted PGGB arguments
- `pggb_package`: pinned Bioconda package specification

The default settings are generic only. Estimate divergence and repeat structure, then pilot representative sequence before scaling. For long repeat-rich genomes, longer segment and block lengths are commonly necessary.

## Checks

```bash
nextflow lint .
nextflow config -flat .
nextflow run . --input assets/samplesheet_example.csv -profile test,docker -stub-run
```

## Notes

The PGGB package is pinned to `bioconda::pggb=0.7.4`. If the package solver uses a different accepted spelling in your environment, update `params.pggb_package`. Command-line options should be checked against the pinned release using `pggb --help`.
