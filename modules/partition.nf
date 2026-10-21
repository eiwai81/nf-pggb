process PARTITION {
    tag "${meta.id}"
    label 'process_medium'
    conda "${params.pggb_package}"

    input:
    tuple val(meta), path(fasta_gz), path(fai), path(gzi)

    output:
    tuple val(meta), path('communities/*community*.fa*'), emit: communities

    script:
    def nHapArg = meta.n_haplotypes ? "-n ${meta.n_haplotypes}" : ''
    def pctId = meta.pct_id != null ? meta.pct_id : params.map_pct_id

    """
    mkdir -p communities
    partition-before-pggb \\
        -i '${fasta_gz}' \\
        -o communities \\
        -t ${task.cpus} \\
        -p ${pctId} \\
        -s ${params.segment_length} \\
        ${nHapArg}
    rm -f communities/*.sh
    """

    stub:
    """
    mkdir -p communities
    printf '>seq\nACGTACGTACGT\n' > 'communities/${meta.id}.community.0.fa'
    """
}
