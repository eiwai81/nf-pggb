process PGGB {
    tag "${meta.id}"
    label 'process_high'
    conda "${params.pggb_package}"
    publishDir { "${params.outdir}/${meta.id}" }, mode: 'copy', overwrite: false

    input:
    tuple val(meta), path(fasta_gz), path(fai), path(gzi)

    output:
    tuple val(meta), path("${meta.id}"), emit: results
    tuple val(meta), path("${meta.id}/*.gfa"), optional: true, emit: gfa
    tuple val(meta), path("${meta.id}/*.og"), optional: true, emit: odgi
    tuple val(meta), path("${meta.id}/*.vcf.gz"), optional: true, emit: vcf
    tuple val(meta), path("${meta.id}/*.png"), optional: true, emit: viz
    path 'versions.yml', emit: versions
    path 'command.txt', emit: command

    script:
    def extArgs = task.ext.args ?: ''
    def nHapArg = meta.n_haplotypes ? "-n ${meta.n_haplotypes}" : ''
    def vcfArg = meta.vcf_spec ? "-V '${meta.vcf_spec}'" : ''
    def blockArg = params.block_length != null ? "-l ${params.block_length}" : ''
    def nMappingsArg = params.n_mappings != null ? "-c ${params.n_mappings}" : ''
    def pctId = meta.pct_id != null ? meta.pct_id : params.map_pct_id
    def cmd = "pggb -i '${fasta_gz}' -o '${meta.id}' -t ${task.cpus} -p ${pctId} -s ${params.segment_length} ${blockArg} -k ${params.min_match_length} ${nMappingsArg} ${nHapArg} ${vcfArg} ${extArgs} ${params.pggb_args}".trim()

    """
    printf '%s\n' "${cmd}" > command.txt
    eval "${cmd}"
    cat > versions.yml <<EOF_VERSION
    "${task.process}":
      pggb: "\$(pggb --version 2>&1 | head -n 1 | sed 's/"/\\"/g')"
      package: "${params.pggb_package}"
      pct_id: "${pctId}"
    EOF_VERSION
    """

    stub:
    """
    mkdir -p '${meta.id}'
    touch '${meta.id}/${meta.id}.smooth.final.gfa'
    printf 'stub\n' > command.txt
    printf '"${task.process}":\n  pggb: stub\n' > versions.yml
    """
}
