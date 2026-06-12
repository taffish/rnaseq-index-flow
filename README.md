# rnaseq-index-flow

`taf-rnaseq-index-flow` prepares a reusable transcriptome reference bundle for
the TAFFISH RNA-seq flow family. It accepts either a genome FASTA plus
GTF/GFF3 annotation, or a prebuilt transcript FASTA plus `tx2gene.tsv`, and
writes transcript FASTA, `tx2gene.tsv`, Salmon index files, optional Kallisto
index files, an optional HISAT2 genome index, logs, commands, versions,
methods, and a manifest under one explicit output directory.

Package identity:

- name: `rnaseq-index-flow`
- command: `taf-rnaseq-index-flow`
- kind: `flow`
- version: `0.2.0-r1`
- license: Apache-2.0
- repository: https://github.com/taffish/rnaseq-index-flow

## Flow Position

This app is a reusable subflow in the TAFFISH bulk RNA-seq flow family. It can
be run directly when users only need a reference/index bundle, and it is also
designed to be called by the future `rnaseq-standard-flow` umbrella. The
umbrella should reuse this flow's stable output contract rather than duplicate
its internal reference-preparation logic.

## Scope

0.2 supports:

- genome FASTA + GTF/GFF3 annotation input
- transcript FASTA + `tx2gene.tsv` input
- annotation normalization with AGAT
- transcript FASTA extraction with gffread
- strict two-column `tx2gene.tsv`
- Salmon transcriptome index
- optional Kallisto transcriptome index
- optional HISAT2 genome index from the same genome FASTA
- fixed output tree under `<outdir>/`
- container-local input snapshots under `<outdir>/00_inputs/`
- provenance files: `commands.sh`, `versions.tsv`, `methods.txt`,
  `flow_summary.tsv`, `reference_summary.tsv`, and `run.manifest.json`
- optional expert `@:` passthrough slots for each biological tool call

0.2 does not build STAR, RSEM, decoy-aware Salmon, or species-specific reference
resources. It does not download reference data during normal execution.

## Dependencies

The flow depends on version-pinned TAFFISH tool apps for biological work:

| Dependency | Version | Role |
| --- | --- | --- |
| `taf-agat` | `1.7.0-r1` | annotation normalization |
| `taf-gffread` | `0.12.9-r1` | GTF conversion and transcript FASTA extraction |
| `taf-salmon` | `1.11.4-r1` | Salmon transcriptome index |
| `taf-kallisto` | `0.52.0-r1` | optional Kallisto transcriptome index |
| `taf-hisat2` | `2.2.2-r2` | optional HISAT2 genome index |

The script also uses ordinary shell utilities (`sh`, `awk`, `sed`, `date`,
`mkdir`, `cp`, `rm`, `grep`, and related POSIX tools) for validation,
bookkeeping, and provenance. It does not call host-installed `agat`,
`gffread`, `salmon`, `kallisto`, or `hisat2`.

## Input Formats

This flow has two mutually exclusive input modes.

Genome + annotation mode:

- `--genome`: genome FASTA. FASTA record IDs must match annotation seqids.
- `--annotation`: GTF or GFF3 annotation with recognizable gene/transcript
  relationships after AGAT normalization.

Transcripts-only mode:

- `--transcripts`: transcript FASTA.
- `--tx2gene`: tab-delimited transcript-to-gene map with columns `tx_id` and
  `gene_id`.

```text
tx_id	gene_id
TX1	GENE1
TX2	GENE1
```

All input files are copied into `<outdir>/00_inputs/` before dependency tools
consume them.

## Usage

Build a Salmon index from genome and annotation:

```sh
taf-rnaseq-index-flow \
  --genome genome.fa \
  --annotation genes.gff3 \
  --outdir ref-out \
  --threads 4
```

Build both Salmon and Kallisto indexes:

```sh
taf-rnaseq-index-flow \
  --genome genome.fa \
  --annotation genes.gtf \
  --outdir ref-out \
  --threads 8 \
  --indexer both
```

Build a reference bundle for both expression and alignment branches:

```sh
taf-rnaseq-index-flow \
  --genome genome.fa \
  --annotation genes.gff3 \
  --outdir ref-out \
  --threads 8 \
  --indexer both \
  --genome-indexer hisat2
```

Use prebuilt transcripts:

```sh
taf-rnaseq-index-flow \
  --transcripts transcripts.fa \
  --tx2gene tx2gene.tsv \
  --outdir ref-out \
  --indexer salmon
```

Tiny or highly fragmented transcript fixtures may need a smaller Salmon k-mer,
for example `--kmer 15`. Real eukaryotic references normally use the default
`--kmer 31`.

## Parameters

Required input/output:

- `--genome PATH`: genome FASTA. Requires `--annotation`.
- `--annotation PATH`: GTF or GFF3 annotation. Requires `--genome`.
- `--transcripts PATH`: transcript FASTA. Requires `--tx2gene` and must not be
  combined with `--genome` or `--annotation`.
- `--tx2gene PATH`: two-column transcript-to-gene table for transcripts-only
  mode.
- `--outdir PATH`, `-o PATH`: output directory. The flow refuses to run if it
  already exists unless `--force` is used.

Common controls:

- `--threads N`, `-t N`: threads for index builders. Default: `1`.
- `--indexer salmon|kallisto|both`: index type to build. Default: `salmon`.
- `--genome-indexer none|hisat2`: optional genome aligner index to build.
  Default: `none`. `hisat2` is available only in genome+annotation mode.
- `--kmer N`: Salmon k-mer size. Default: `31`.
- `--force`: replace only the standard rnaseq-index-flow output files inside an
  existing output directory.

## Advanced Per-Step Passthrough

These `@:` slots are optional expert escape hatches for native tool arguments.
They default to empty and are not required for normal use. The flow keeps
inputs, outputs, thread count, k-mer size, and index choices as stable top-level
parameters; use these slots only when you intentionally need an upstream tool
option that is not modeled by the flow.

The general syntax is documented in the
[TAFFISH Flow Developer Guide (English)](https://github.com/taffish/taffish-docs/blob/main/en/taf-flow-developer-guide.en.md)
and [TAFFISH Flow 开发者指南（中文）](https://github.com/taffish/taffish-docs/blob/main/zh/taf-flow-developer-guide.cn.md).

| Slot | Call site |
| --- | --- |
| `@agat-convert-step: ... @:` | `agat_convert_sp_gxf2gxf.pl` annotation normalization |
| `@gffread-gtf-step: ... @:` | `gffread` GTF conversion |
| `@gffread-transcripts-step: ... @:` | `gffread` transcript FASTA extraction |
| `@salmon-index-step: ... @:` | `salmon index` |
| `@kallisto-index-step: ... @:` | `kallisto index` |
| `@hisat2-build-step: ... @:` | `hisat2-build` |

Example:

```sh
taf-rnaseq-index-flow \
  --genome genome.fa \
  --annotation genes.gff3 \
  --outdir ref-out \
  --genome-indexer hisat2 \
  @hisat2-build-step: --quiet @:
```

## Output Layout

All flow-created outputs are written under `<outdir>/`:

```text
<outdir>/
  00_inputs/
    reference_inputs.tsv
    genome.fa / annotation.gxf
    transcripts.fa / tx2gene.tsv
  01_logs/
    flow.log
    steps/
      01_validate_inputs.log
      02_prepare_annotation.log
      03_extract_transcripts.log
      04_build_salmon_index.log
      05_build_kallisto_index.log
      06_build_hisat2_index.log
  02_intermediate/
    annotation/
  03_results/
    annotation/
      genes.gff3
      genes.gtf
    transcripts/
      transcripts.fa
    tx2gene.tsv
    salmon_index/
    kallisto_index/
    hisat2_index/
      genome.1.ht2
      genome.2.ht2
      ...
  04_reports/
    reference_summary.tsv
    genome_index.tsv
    flow_summary.tsv
    versions.tsv
    commands.sh
    methods.txt
  run.manifest.json
```

`03_results/annotation/genes.gff3` and `genes.gtf` are produced in
genome+annotation mode. In transcripts-only mode the annotation directory
contains a note describing the supplied transcript resources.

`03_results/tx2gene.tsv` is always tab-delimited:

```text
tx_id	gene_id
TX1	GENE1
TX2	GENE1
```

Downstream RNA-seq flows should consume:

- `03_results/salmon_index/`
- `03_results/kallisto_index/transcripts.idx`, when `--indexer kallisto` or
  `--indexer both` was used
- `03_results/hisat2_index/genome`, when `--genome-indexer hisat2` was used
- `03_results/tx2gene.tsv`
- `03_results/transcripts/transcripts.fa`

For the alignment branch, pass the HISAT2 prefix directly:

```sh
taf-rnaseq-alignment-flow \
  --samples samples.tsv \
  --index ref-out/03_results/hisat2_index/genome \
  --outdir align-out
```

## Data Flow and Contracts

1. Validate inputs and refuse an existing output directory unless `--force` is
   set.
2. Copy supplied input files into `<outdir>/00_inputs/` as container-local
   snapshots, then check that genome FASTA IDs cover annotation seqids in
   genome+annotation mode.
3. In genome+annotation mode, normalize annotation with AGAT.
4. Convert normalized annotation to GTF and extract transcript FASTA with
   gffread.
5. Create a strict `tx2gene.tsv` table from transcript features.
6. Build the requested Salmon and/or Kallisto index.
7. Optionally build a HISAT2 genome index from the same genome FASTA.
8. Write summary tables, commands, versions, methods, logs, and manifest.

## Resource Notes

For toy fixtures, `--threads 1` and `--kmer 15` are enough. For real references,
start with `--threads 4` to `--threads 8` and the default `--kmer 31`.

Runtime and disk usage mostly follow the reference size and the selected
indexers. Salmon and Kallisto indexes are transcriptome indexes and are usually
smaller than whole-genome aligner indexes. HISAT2 is lighter than STAR, but a
large genome still creates a larger index and needs more local disk than the
Salmon-only default. AGAT and gffread are usually lighter than index
construction, but very large or messy annotations can make the annotation step
the slowest part.

The flow has no GPU requirement and performs no runtime downloads. Platform
support follows the five dependency apps listed above and the configured
TAFFISH container backend.

## Boundaries

The flow preserves source FASTA, annotation, transcript, and `tx2gene` files. It
writes only under `<outdir>/`; input files are copied into `00_inputs/` so
containerized taf-tool dependencies can read stable local paths without editing
the originals. It does not infer organism, download genomes, download
annotations, or validate scientific completeness of annotation models.

In genome+annotation mode, the first token of each FASTA header must match the
seqids in the first column of the annotation for all annotated sequences. If the
annotation uses `chrI`/`chrII` style names, the genome FASTA must expose those
same names rather than unrelated RefSeq accessions.

Annotation attributes differ across sources. 0.2 expects transcript features
with recognizable IDs and parent gene IDs after AGAT normalization. If
`tx2gene.tsv` has no data rows, clean or simplify the annotation first, or use
transcripts-only mode with a curated `tx2gene.tsv`.

## Troubleshooting

If the flow fails, check `01_logs/flow.log` first and then the matching file
under `01_logs/steps/`. AGAT may also write `agat_log_annotation` under
`01_logs/steps/`.

If a dependency wrapper such as `taf-salmon-v1.11.4-r1` is missing, expose or
build the dependency app before running this flow. If `<outdir>` already exists,
choose a new output directory or use `--force` after confirming that it contains
only replaceable rnaseq-index-flow outputs.

## Testing

`tests/smoke.sh` builds the flow and runs a tiny two-transcript fixture through
`--indexer both --genome-indexer hisat2 --kmer 15`. It checks the generated
transcript FASTA, `tx2gene.tsv`, Salmon, Kallisto, and HISAT2 index files,
logs, reports, manifest, commands, versions, and current-directory cleanliness.

`tests/formal.sh` is reserved for the central RNA-seq mini reference data under
`repos/apps/bio/flows/rna-seq/test-data/yeast/data/03_results`. If the reference
genome and annotation are not present, it prints `formal: skipped` with the
missing resource and exits successfully without downloading anything. The
central data tree can be prepared with
`repos/apps/bio/flows/rna-seq/test-data/yeast/rnaseq-yeast-get-data`; downstream
formal tests read it via `TAFFISH_RNASEQ_TESTDATA` or the default local
`test-data/yeast/data/03_results` path.

## License and Citation

TAFFISH app packaging: Apache-2.0.

Upstream tools keep their own license and citation requirements. See the
dependency app records and upstream projects for details.
