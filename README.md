# nf-pggb

A streamlined Nextflow DSL2 wrapper around PanGenome Graph Builder (PGGB) [https://pggb.readthedocs.io/en/latest/index.html]. The workflow prepares BGZF FASTA inputs, optionally partitions multi-chromosome pangenomes into communities, and runs PGGB as one task per input or community.

## Input

CSV with headers `id,fasta,n_haplotypes,vcf_spec,pct_id`:

```csv
id,fasta,n_haplotypes,vcf_spec,pct_id
chr1,/absolute/path/chr1.fa.gz,5,,95
chr2,/absolute/path/chr2.fa.gz,5,,94

```

## Run

```bash
nextflow run . --input samplesheet.csv --outdir results -profile conda
```

Optional community partitioning:

```bash
nextflow run . --input samplesheet.csv --community true --outdir results -profile conda
```

## Key parameters used in pipeline
- `map_pct_id`: PGGB `-p`
- `segment_length`: PGGB `-s`
- `block_length`: PGGB `-l`
- `min_match_length`: PGGB/Seqwish `-k`
- `n_mappings`: PGGB `-c`
- `pggb_args`: additional PGGB arguments
- `pggb_package`: pinned version of Bioconda::pggb package

### Explanation on parameters
- Essential parameters: https://pggb.readthedocs.io/en/latest/rst/essential_parameters.html
- Optional parameters: https://pggb.readthedocs.io/en/latest/rst/optional_parameters.html
- For Organism specific example: https://pggb.readthedocs.io/en/latest/rst/organism_example_parameters.html
- For larger pangenomes: https://pggb.readthedocs.io/en/latest/rst/larger_pangenomes_parameters.html

## Estimating divergence (`map_pct_id`).
```bash
# Install mash
mamba install mash

# For only chr1
mash triangle /absolute/path/chr1.fa.gz > chr1_mash_triangle.txt

cat chr1_mash_triangle.txt
```
>Use percentage identity between the most diverged pair of sequence as the value for `-p`

For long repeat-rich genomes, longer segment and block lengths are encouraged. See PGGB GitHub (https://github.com/pangenome/pggb) for more information.
