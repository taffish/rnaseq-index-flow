rnaseq-index-flow 0.2.0-r1

Purpose:
  Prepare a reusable transcriptome reference bundle for TAFFISH RNA-seq flows.
  0.2 accepts either genome FASTA plus GTF/GFF3 annotation, or transcript FASTA
  plus tx2gene.tsv, and builds Salmon and optional Kallisto transcriptome
  indexes plus an optional HISAT2 genome index with logs and provenance.
  0.2 keeps the r1 interface and adds advanced per-step @: passthrough slots.

Usage:
  taf-rnaseq-index-flow \
    --genome genome.fa \
    --annotation genes.gff3 \
    --outdir ref-out \
    [options]

  taf-rnaseq-index-flow \
    --transcripts transcripts.fa \
    --tx2gene tx2gene.tsv \
    --outdir ref-out \
    [options]

Input modes:
  Genome + annotation mode:
    --genome PATH
        Genome FASTA. Requires --annotation.

    --annotation PATH
        GTF or GFF3 annotation. Requires --genome.

  Transcripts-only mode:
    --transcripts PATH
        Transcript FASTA. Requires --tx2gene and must not be combined with
        --genome or --annotation.

    --tx2gene PATH
        Tab-delimited table with columns tx_id and gene_id.

Required output:
  --outdir PATH, -o PATH
      Output directory. The flow refuses to run if PATH already exists unless
      --force is used.

Common options:
  --threads N, -t N
      Threads for index builders. Default: 1.

  --indexer salmon, kallisto, or both
      Index type to build. Default: salmon.

  --genome-indexer none or hisat2
      Optional genome aligner index to build. Default: none.
      hisat2 requires genome + annotation mode and writes
      <outdir>/03_results/hisat2_index/genome.*.ht2 files.

  --kmer N
      Salmon k-mer size. Default: 31. Tiny smoke fixtures can use --kmer 15.

  --force
      Replace the standard rnaseq-index-flow output files inside an existing
      output directory.

Key outputs:
  <outdir>/03_results/transcripts/transcripts.fa
      Transcript FASTA for quantification.

  <outdir>/03_results/tx2gene.tsv
      Tab-delimited tx_id/gene_id map for expression summarization.

  <outdir>/03_results/salmon_index/
      Salmon transcriptome index for rnaseq-expression-flow.

  <outdir>/03_results/kallisto_index/
      Optional Kallisto index when --indexer kallisto or both is used.

  <outdir>/03_results/hisat2_index/genome
      Optional HISAT2 prefix when --genome-indexer hisat2 is used.

  <outdir>/04_reports/
      Summary tables, commands.sh, versions.tsv, methods.txt, and provenance.

Upstream/downstream:
  Upstream:
    genome FASTA + GTF/GFF3 annotation, or transcript FASTA + tx2gene.tsv.

  Downstream:
    rnaseq-expression-flow uses salmon_index and tx2gene.tsv.
    rnaseq-alignment-flow can use hisat2_index/genome when built.

Advanced step passthrough:
  These slots are optional expert escape hatches for native tool parameters.
  They default to empty and are not needed for normal use. Flow-managed inputs,
  outputs, threads, k-mer, and index choices remain top-level options above.

  @agat-convert-step: ... @:
      Extra native arguments for agat_convert_sp_gxf2gxf.pl.

  @gffread-gtf-step: ... @:
      Extra native arguments for the gffread GTF conversion step.

  @gffread-transcripts-step: ... @:
      Extra native arguments for the gffread transcript FASTA extraction step.

  @salmon-index-step: ... @:
      Extra native arguments for salmon index.

  @kallisto-index-step: ... @:
      Extra native arguments for kallisto index.

  @hisat2-build-step: ... @:
      Extra native arguments for hisat2-build.

  Example:
      taf-rnaseq-index-flow --genome genome.fa --annotation genes.gff3 \
        --outdir ref-out --genome-indexer hisat2 \
        @hisat2-build-step: --quiet @:

Boundaries:
  0.2 does not build STAR, RSEM, decoy-aware Salmon, or species-specific
  reference resources. It does not download reference data or edit input files.
  Annotation attributes must contain recognizable transcript and gene
  relationships after AGAT normalization, or the user should provide
  transcripts plus tx2gene.tsv. Genome FASTA header IDs must match annotation
  seqids; inputs are copied into <outdir>/00_inputs/ before taf-tool
  dependencies consume them.

Detailed documentation:
  https://github.com/taffish/rnaseq-index-flow

Wrapper options:
  -h, --help       Show this help.
  -v, --version    Show package and command version.
  --compile        Print generated shell code instead of running it.
