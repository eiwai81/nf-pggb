#!/usr/bin/env nextflow

/*
 * pggb-nf
 *
 * A streamlined Nextflow DSL2 wrapper around upstream PGGB.
 *
 * Standard route:
 *   samplesheet -> PREPARE_INPUT -> PGGB
 *
 * Community route:
 *   samplesheet -> PREPARE_INPUT -> PARTITION
 *               -> PREPARE_COMMUNITY -> PGGB
 */

nextflow.enable.dsl = 2


/*
 * Module imports
 */

include { PREPARE_INPUT } from './modules/prepare_input'
include { PREPARE_INPUT as PREPARE_COMMUNITY } from './modules/prepare_input'
include { PARTITION } from './modules/partition'
include { PGGB } from './modules/pggb'


/*
 * Command-line help
 */

def helpMessage() {
    log.info """
    pggb-nf
    =======

    Run upstream PGGB over one or more independent pangenome FASTA files.

    Usage:
      nextflow run . \\
          --input samplesheet.csv \\
          --outdir results \\
          -profile conda

    Required workflow parameter:
      --input
          CSV samplesheet containing these required columns:

              id,fasta

          Optional columns:

              n_haplotypes,vcf_spec,pct_id

    Samplesheet example:
      id,fasta,n_haplotypes,vcf_spec,pct_id
      chr1,/absolute/path/chr1.fa.gz,5,,95
      chr2,/absolute/path/chr2.fa.gz,5,,94

    Important:
      If vcf_spec is blank but pct_id is populated, retain the empty CSV
      field using two consecutive commas before pct_id.

    Common options:
      --outdir               Output directory
      --map_pct_id           Global PGGB -p fallback
      --segment_length       PGGB -s
      --block_length         PGGB -l
      --min_match_length     PGGB/Seqwish -k
      --n_mappings           PGGB -c
      --vcf_spec             Global PGGB -V fallback
      --community            Run partition-before-pggb first
      --pggb_args            Additional trusted PGGB arguments
      --help                 Display this message

    Per-row overrides:
      pct_id                 Overrides --map_pct_id for that input
      n_haplotypes           Supplies PGGB -n for that input
      vcf_spec               Overrides --vcf_spec for that input
    """.stripIndent()
}


/*
 * Print global workflow parameters.
 *
 * The per-input pct_id, n_haplotypes, and vcf_spec values are printed later,
 * when the samplesheet rows are consumed.
 */

def logHeader() {
    def globalPctId = params.map_pct_id != null
        ? "${params.map_pct_id} %"
        : 'not set; pct_id must be supplied in the samplesheet'

    def blockLength = params.block_length != null
        ? params.block_length
        : 'PGGB default'

    def mappings = params.n_mappings != null
        ? params.n_mappings
        : 'PGGB default'

    def defaultVcfSpec = params.vcf_spec
        ? params.vcf_spec
        : 'not set'

    def additionalArgs = params.pggb_args
        ? params.pggb_args
        : 'none'

    def activeProfile = workflow.profile
        ? workflow.profile
        : 'standard'

    log.info """\
======================================================================================
                                pggb-nf
                                -------
        Build pangenome graphs using the upstream PGGB toolkit
--------------------------------------------------------------------------------------
  Input and output:

    Samplesheet                 : ${params.input}
    Results directory           : ${params.outdir}
    PGGB package                : ${params.pggb_package}

  Global PGGB parameters:

    Mapping identity fallback   : ${globalPctId}
    Segment length              : ${params.segment_length}
    Block length                : ${blockLength}
    Minimum exact-match length  : ${params.min_match_length}
    Mappings per segment        : ${mappings}
    Default VCF specification   : ${defaultVcfSpec}
    Additional PGGB arguments   : ${additionalArgs}

  Workflow options:

    Community partitioning      : ${params.community}
    Active profile              : ${activeProfile}

  Samplesheet overrides:

    pct_id                      : per-input PGGB -p
    n_haplotypes                : per-input PGGB -n
    vcf_spec                    : per-input PGGB -V

======================================================================================
""".stripIndent(false)
}


/*
 * Entry workflow
 */

workflow {

    workflow.onComplete = {
        log.info """\
=====================================================================================
  Pipeline status              : ${workflow.success ? 'COMPLETED' : 'FAILED'}
  Results directory            : ${params.outdir}
=====================================================================================
""".stripIndent(false)
    }

    if (params.help) {
        helpMessage()
        return
    }

    if (!params.input) {
        helpMessage()
        error 'ERROR: --input samplesheet.csv is required.'
    }

    logHeader()


    /*
     * Parse, validate, and report samplesheet rows.
     */

    ch_samples = channel
        .fromPath(params.input, checkIfExists: true)
        .splitCsv(header: true, strip: true)
        .map { row ->

            def sampleId = row.id?.toString()?.trim()
            def fastaPath = row.fasta?.toString()?.trim()

            if (!sampleId || !fastaPath) {
                error "Samplesheet rows require non-empty 'id' and 'fasta' values. Offending row: ${row}"
            }

            def sampleNHaplotypes = row.n_haplotypes?.toString()?.trim()
            def sampleVcfSpec = row.vcf_spec?.toString()?.trim()
            def samplePctId = row.pct_id?.toString()?.trim()

            Integer resolvedNHaplotypes = null
            BigDecimal samplesheetPctId = null

            if (sampleNHaplotypes) {
                if (!(sampleNHaplotypes ==~ /[0-9]+/)) {
                    error "n_haplotypes must be an integer for sample '${sampleId}'. Observed: ${sampleNHaplotypes}"
                }

                resolvedNHaplotypes = sampleNHaplotypes as Integer

                if (resolvedNHaplotypes < 2) {
                    error "n_haplotypes must be at least 2 for sample '${sampleId}'. Observed: ${resolvedNHaplotypes}"
                }
            }

            if (samplePctId) {
                if (!(samplePctId ==~ /[0-9]+(?:\.[0-9]+)?/)) {
                    error "pct_id must be numeric for sample '${sampleId}'. Observed: ${samplePctId}"
                }

                samplesheetPctId = samplePctId as BigDecimal

                if (samplesheetPctId <= 0 || samplesheetPctId > 100) {
                    error "pct_id must be greater than 0 and no greater than 100 for sample '${sampleId}'. Observed: ${samplesheetPctId}"
                }
            }

            def resolvedVcfSpec = params.vcf_spec ?: null

            if (sampleVcfSpec) {
                resolvedVcfSpec = sampleVcfSpec
            }

            def effectivePctId = samplesheetPctId != null
                ? samplesheetPctId
                : params.map_pct_id

            if (effectivePctId == null) {
                error "No mapping identity was provided for sample '${sampleId}'. Set pct_id in the samplesheet or set --map_pct_id."
            }

            BigDecimal validatedPctId = effectivePctId as BigDecimal

            if (validatedPctId <= 0 || validatedPctId > 100) {
                error "The resolved mapping identity must be greater than 0 and no greater than 100 for sample '${sampleId}'. Observed: ${validatedPctId}"
            }

            def pctIdSource = samplesheetPctId != null
                ? 'samplesheet pct_id'
                : 'global map_pct_id fallback'

            def displayedNHaplotypes = resolvedNHaplotypes != null
                ? resolvedNHaplotypes
                : 'not set'

            def displayedVcfSpec = resolvedVcfSpec
                ? resolvedVcfSpec
                : 'not set'

            log.info """\
------------------------------------------------------------------------------------------------------------------------
  Resolved input: ${sampleId}

    FASTA                       : ${fastaPath}
    Haplotypes                  : ${displayedNHaplotypes}
    Mapping identity            : ${validatedPctId} %
    Mapping identity source     : ${pctIdSource}
    VCF specification           : ${displayedVcfSpec}
------------------------------------------------------------------------------------------------------------------------
""".stripIndent(false)

            def meta = [
                id           : sampleId,
                n_haplotypes : resolvedNHaplotypes,
                vcf_spec     : resolvedVcfSpec,
                pct_id       : validatedPctId
            ]

            tuple(
                meta,
                file(fastaPath, checkIfExists: true)
            )
        }


    /*
     * Normalize each FASTA to BGZF and create .fai/.gzi indexes.
     */

    PREPARE_INPUT(ch_samples)


    /*
     * Optionally partition each pangenome into communities before PGGB.
     */

    if (params.community) {

        PARTITION(PREPARE_INPUT.out.indexed)

        ch_communities = PARTITION.out.communities
            .flatMap { meta, files ->

                def fileList = files instanceof List
                    ? files
                    : [files]

                fileList.collect { communityFasta ->

                    def communityMatch = communityFasta.name =~ /community\.(\d+)/
                    def suffix = communityFasta.baseName

                    if (communityMatch.find()) {
                        suffix = "community${communityMatch.group(1)}"
                    }

                    def communityMeta = meta + [
                        id: "${meta.id}_${suffix}"
                    ]

                    tuple(
                        communityMeta,
                        communityFasta
                    )
                }
            }

        PREPARE_COMMUNITY(ch_communities)
        PGGB(PREPARE_COMMUNITY.out.indexed)

    } else {

        PGGB(PREPARE_INPUT.out.indexed)
    }
}
