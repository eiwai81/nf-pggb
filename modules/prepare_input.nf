process PREPARE_INPUT {
    tag "${meta.id}"
    label 'process_low'
    conda 'bioconda::samtools=1.20'

    input:
    tuple val(meta), path(fasta)

    output:
    tuple val(meta), path("${meta.id}.fa.gz"), path("${meta.id}.fa.gz.fai"), path("${meta.id}.fa.gz.gzi"), emit: indexed

    script:
    """
    if [[ '${fasta}' == *.gz ]]; then
        gzip -cd '${fasta}' | bgzip -@ ${task.cpus} -c > '${meta.id}.fa.gz'
    else
        bgzip -@ ${task.cpus} -c '${fasta}' > '${meta.id}.fa.gz'
    fi
    samtools faidx '${meta.id}.fa.gz'
    """

    stub:
    """
    printf '>seq\nACGTACGTACGT\n' | bgzip -c > '${meta.id}.fa.gz'
    touch '${meta.id}.fa.gz.fai' '${meta.id}.fa.gz.gzi'
    """
}
