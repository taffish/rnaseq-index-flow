#!/bin/sh
set -eu

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
project_dir=$(CDPATH= cd "$script_dir/.." && pwd)
bio_apps_dir=$(CDPATH= cd "$project_dir/../../../.." && pwd)
default_data_root=$(CDPATH= cd "$project_dir/../../test-data/yeast/data/03_results" 2>/dev/null && pwd || printf '%s\n' "$project_dir/../../test-data/yeast/data/03_results")
data_root=${TAFFISH_RNASEQ_TESTDATA:-$default_data_root}

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

TAFFISH_CONTAINER_BACKEND=${TAFFISH_CONTAINER_BACKEND:-podman}
export TAFFISH_CONTAINER_BACKEND
TAF_HISTORY_MODE=${TAF_HISTORY_MODE:-off}
export TAF_HISTORY_MODE

skip_formal() {
    echo "formal: skipped: $*" >&2
    exit 0
}

if [ ! -d "$data_root" ]; then
    skip_formal "RNA-seq formal data root not found: $data_root"
fi

genome=$(find "$data_root" -type f \( -name '*.fa' -o -name '*.fasta' -o -name '*.fna' \) | grep -Ei 'genome|reference|s288c|r64|yeast' | head -n 1 || true)
annotation=$(find "$data_root" -type f \( -name '*.gff3' -o -name '*.gff' -o -name '*.gtf' \) | grep -Ei 'gene|annotation|s288c|r64|yeast' | head -n 1 || true)

if [ -z "$genome" ]; then
    skip_formal "missing yeast reference genome FASTA under $data_root"
fi

if [ -z "$annotation" ]; then
    skip_formal "missing yeast reference GTF/GFF3 annotation under $data_root"
fi

if ! command -v taf >/dev/null 2>&1; then
    echo "formal: taf command not found in PATH." >&2
    exit 127
fi

for dep in \
    taf-agat-v1.7.0-r1 \
    taf-gffread-v0.12.9-r1 \
    taf-salmon-v1.11.4-r1 \
    taf-hisat2-v2.2.2-r2
do
    if ! command -v "$dep" >/dev/null 2>&1; then
        echo "formal: dependency wrapper not found in PATH: $dep" >&2
        exit 127
    fi
done

tmpdir=$(mktemp -d "$project_dir/.taf-formal.XXXXXX")
cleanup() {
    cd "$project_dir" 2>/dev/null || :
    rm -rf "$tmpdir"
}
trap cleanup EXIT INT TERM HUP

cd "$project_dir"

echo "[FORMAL] taf check"
taf check

echo "[FORMAL] taf build"
taf build

flow_cmd="$project_dir/target/taf-rnaseq-index-flow-v0.1.0-r1"
if [ ! -x "$flow_cmd" ]; then
    echo "formal: built flow command is missing or not executable: $flow_cmd" >&2
    exit 1
fi

run_dir="$tmpdir/run"
mkdir -p "$run_dir"

echo "[FORMAL] rnaseq-index-flow yeast reference"
(
    cd "$run_dir"
    "$flow_cmd" \
        --genome "$genome" \
        --annotation "$annotation" \
        --outdir ref-out \
        --threads 2 \
        --indexer salmon \
        --genome-indexer hisat2
)

out="$run_dir/ref-out"
test -s "$out/03_results/transcripts/transcripts.fa"
test -s "$out/03_results/tx2gene.tsv"
test -s "$out/03_results/salmon_index/info.json"
test -s "$out/03_results/hisat2_index/genome.1.ht2"
test -s "$out/04_reports/reference_summary.tsv"
test -s "$out/04_reports/genome_index.tsv"
test -s "$out/04_reports/versions.tsv"
test -s "$out/04_reports/commands.sh"
test -s "$out/run.manifest.json"
grep -F 'hisat2	genome	built' "$out/04_reports/genome_index.tsv" >/dev/null
grep -F '"genome_indexer": "hisat2"' "$out/run.manifest.json" >/dev/null

echo "[FORMAL] ok"
