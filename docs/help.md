rnaseq-index-flow 0.1.0-r1

Purpose:
  Prepare a reusable transcriptome reference bundle for TAFFISH RNA-seq flows.
  r1 accepts either genome FASTA plus GTF/GFF3 annotation, or transcript FASTA
  plus tx2gene.tsv, and builds Salmon and optional Kallisto transcriptome
  indexes plus an optional HISAT2 genome index with logs and provenance.

Flow family role:
  This is a TAFFISH RNA-seq subflow. It can be run directly to prepare
  reference/index outputs, and its stable output contract is intended for
  future rnaseq-standard-flow orchestration.

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

Output tree:
  <outdir>/00_inputs/reference_inputs.tsv
  <outdir>/00_inputs/genome.fa and annotation.gxf in genome+annotation mode
  <outdir>/00_inputs/transcripts.fa and tx2gene.tsv in transcripts-only mode
  <outdir>/01_logs/flow.log
  <outdir>/01_logs/steps/
  <outdir>/02_intermediate/annotation/
  <outdir>/03_results/annotation/genes.gff3
  <outdir>/03_results/annotation/genes.gtf
  <outdir>/03_results/transcripts/transcripts.fa
  <outdir>/03_results/tx2gene.tsv
  <outdir>/03_results/salmon_index/
  <outdir>/03_results/kallisto_index/
  <outdir>/03_results/hisat2_index/
  <outdir>/04_reports/reference_summary.tsv
  <outdir>/04_reports/genome_index.tsv
  <outdir>/04_reports/flow_summary.tsv
  <outdir>/04_reports/versions.tsv
  <outdir>/04_reports/commands.sh
  <outdir>/04_reports/methods.txt
  <outdir>/run.manifest.json

tx2gene.tsv format:
  tx_id<TAB>gene_id
  TX1<TAB>GENE1
  TX2<TAB>GENE1

Dependencies:
  taf-agat 1.7.0-r1
  taf-gffread 0.12.9-r1
  taf-salmon 1.11.4-r1
  taf-kallisto 0.52.0-r1
  taf-hisat2 2.2.2-r2

Boundaries:
  r1 does not build STAR, RSEM, decoy-aware Salmon, or species-specific
  reference resources. It does not download reference data or edit input files.
  Annotation attributes must contain recognizable transcript and gene
  relationships after AGAT normalization, or the user should provide
  transcripts plus tx2gene.tsv. Genome FASTA header IDs must match annotation
  seqids; inputs are copied into <outdir>/00_inputs/ before taf-tool
  dependencies consume them.

Wrapper options:
  -h, --help       Show this help.
  -v, --version    Show package and command version.
  --compile        Print generated shell code instead of running it.
