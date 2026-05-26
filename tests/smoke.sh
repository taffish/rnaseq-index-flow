#!/bin/sh
set -eu

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
project_dir=$(CDPATH= cd "$script_dir/.." && pwd)
bio_apps_dir=$(CDPATH= cd "$project_dir/../../../.." && pwd)

for target_dir in \
    "$bio_apps_dir/tools/agat/target" \
    "$bio_apps_dir/tools/gffread/target" \
    "$bio_apps_dir/tools/salmon/target" \
    "$bio_apps_dir/tools/kallisto/target" \
    "$bio_apps_dir/tools/hisat2/target"
do
    if [ -d "$target_dir" ]; then
        PATH="$target_dir:$PATH"
    fi
done
export PATH

if ! command -v taf >/dev/null 2>&1; then
    echo "smoke: taf command not found in PATH." >&2
    exit 127
fi

if ! command -v taffish >/dev/null 2>&1; then
    echo "smoke: taffish command not found in PATH." >&2
    exit 127
fi

for dep in \
    taf-agat-v1.7.0-r1 \
    taf-gffread-v0.12.9-r1 \
    taf-salmon-v1.11.4-r1 \
    taf-kallisto-v0.52.0-r1 \
    taf-hisat2-v2.2.2-r2
do
    if ! command -v "$dep" >/dev/null 2>&1; then
        echo "smoke: dependency wrapper not found in PATH: $dep" >&2
        exit 127
    fi
done

TAFFISH_CONTAINER_BACKEND=${TAFFISH_CONTAINER_BACKEND:-podman}
export TAFFISH_CONTAINER_BACKEND
TAF_HISTORY_MODE=${TAF_HISTORY_MODE:-off}
export TAF_HISTORY_MODE

tmpdir=$(mktemp -d "$project_dir/.taf-smoke.XXXXXX")
cleanup() {
    cd "$project_dir" 2>/dev/null || :
    rm -rf "$tmpdir"
}
trap cleanup EXIT INT TERM HUP

cd "$project_dir"

echo "[SMOKE] taf check"
taf check

echo "[SMOKE] taf build"
taf build

flow_cmd="$project_dir/target/taf-rnaseq-index-flow-v0.1.0-r1"
if [ ! -x "$flow_cmd" ]; then
    echo "smoke: built flow command is missing or not executable: $flow_cmd" >&2
    exit 1
fi

echo "[SMOKE] help and version"
"$flow_cmd" --help >/dev/null
"$flow_cmd" --version >/dev/null

run_dir="$tmpdir/run"
mkdir -p "$run_dir"

echo "[SMOKE] rnaseq-index-flow genome+annotation --indexer both"
(
    cd "$run_dir"
    "$flow_cmd" \
        --genome "$project_dir/testdata/genome.fa" \
        --annotation "$project_dir/testdata/annotation.gff3" \
        --outdir ref-out \
        --threads 1 \
        --indexer both \
        --genome-indexer hisat2 \
        --kmer 15
)
cd "$project_dir"

out="$run_dir/ref-out"

echo "[SMOKE] output checks"
test -s "$out/00_inputs/reference_inputs.tsv"
test -s "$out/01_logs/flow.log"
test -s "$out/01_logs/steps/01_validate_inputs.log"
test -s "$out/01_logs/steps/02_prepare_annotation.log"
test -s "$out/01_logs/steps/03_extract_transcripts.log"
test -s "$out/01_logs/steps/04_build_salmon_index.log"
test -s "$out/01_logs/steps/05_build_kallisto_index.log"
test -s "$out/01_logs/steps/06_build_hisat2_index.log"
test -s "$out/03_results/annotation/genes.gff3"
test -s "$out/03_results/annotation/genes.gtf"
test -s "$out/03_results/transcripts/transcripts.fa"
test -s "$out/03_results/tx2gene.tsv"
test -s "$out/03_results/salmon_index/info.json"
test -s "$out/03_results/kallisto_index/transcripts.idx"
test -s "$out/03_results/hisat2_index/genome.1.ht2"
test -s "$out/03_results/hisat2_index/genome.2.ht2"
test -s "$out/04_reports/reference_summary.tsv"
test -s "$out/04_reports/genome_index.tsv"
test -s "$out/04_reports/flow_summary.tsv"
test -s "$out/04_reports/versions.tsv"
test -s "$out/04_reports/commands.sh"
test -s "$out/04_reports/methods.txt"
test -s "$out/run.manifest.json"

grep -F '>tx1' "$out/03_results/transcripts/transcripts.fa" >/dev/null
grep -F '>tx2' "$out/03_results/transcripts/transcripts.fa" >/dev/null
grep -F 'tx_id	gene_id' "$out/03_results/tx2gene.tsv" >/dev/null
grep -F 'tx1	gene1' "$out/03_results/tx2gene.tsv" >/dev/null
grep -F 'tx2	gene2' "$out/03_results/tx2gene.tsv" >/dev/null
grep -F 'taf-agat-v1.7.0-r1' "$out/04_reports/commands.sh" >/dev/null
grep -F 'taf-gffread-v0.12.9-r1' "$out/04_reports/commands.sh" >/dev/null
grep -F 'taf-salmon-v1.11.4-r1' "$out/04_reports/commands.sh" >/dev/null
grep -F 'taf-kallisto-v0.52.0-r1' "$out/04_reports/commands.sh" >/dev/null
grep -F 'taf-hisat2-v2.2.2-r2' "$out/04_reports/commands.sh" >/dev/null
grep -F 'taf-salmon	1.11.4-r1' "$out/04_reports/versions.tsv" >/dev/null
grep -F 'taf-hisat2	2.2.2-r2' "$out/04_reports/versions.tsv" >/dev/null
grep -F 'transcript_count	2' "$out/04_reports/reference_summary.tsv" >/dev/null
grep -F 'hisat2_index	yes' "$out/04_reports/reference_summary.tsv" >/dev/null
grep -F 'hisat2	genome	built' "$out/04_reports/genome_index.tsv" >/dev/null
grep -F 'hisat2_index_prefix' "$out/04_reports/flow_summary.tsv" >/dev/null
grep -F '"flow": "rnaseq-index-flow"' "$out/run.manifest.json" >/dev/null
grep -F '"indexer": "both"' "$out/run.manifest.json" >/dev/null
grep -F '"genome_indexer": "hisat2"' "$out/run.manifest.json" >/dev/null
grep -F '"hisat2_index_prefix":' "$out/run.manifest.json" >/dev/null
if command -v python3 >/dev/null 2>&1; then
    python3 -m json.tool "$out/run.manifest.json" >/dev/null
fi

echo "[SMOKE] existing outdir is refused"
if (
    cd "$run_dir"
    "$flow_cmd" \
        --genome "$project_dir/testdata/genome.fa" \
        --annotation "$project_dir/testdata/annotation.gff3" \
        --outdir ref-out \
        --threads 1 \
        --indexer salmon \
        --kmer 15
) >/dev/null 2>&1; then
    echo "smoke: existing outdir was not refused." >&2
    exit 1
fi

echo "[SMOKE] --force rerun"
(
    cd "$run_dir"
    "$flow_cmd" \
        --genome "$project_dir/testdata/genome.fa" \
        --annotation "$project_dir/testdata/annotation.gff3" \
        --outdir ref-out \
        --threads 1 \
        --indexer salmon \
        --kmer 15 \
        --force
)
test -s "$out/03_results/salmon_index/info.json"
test ! -e "$out/03_results/kallisto_index/transcripts.idx"
test ! -e "$out/03_results/hisat2_index/genome.1.ht2"
grep -F 'hisat2	genome	skipped' "$out/04_reports/genome_index.tsv" >/dev/null

stray=$(find "$run_dir" -mindepth 1 -maxdepth 1 ! -name ref-out -print)
if [ -n "$stray" ]; then
    echo "smoke: flow wrote unexpected files outside outdir:" >&2
    printf '%s\n' "$stray" >&2
    exit 1
fi

echo "[SMOKE] ok"
