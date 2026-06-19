#!/bin/bash
#SBATCH --job-name=genomicsdb_mito
#SBATCH --partition=guest
#SBATCH --time=2-00:00:00
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=2
#SBATCH --mem=100G
#SBATCH --output=logs/genomicsdb_mito_%j.out
#SBATCH --error=logs/genomicsdb_mito_%j.err

set -euo pipefail

module purge
module load gatk4/4.6

export TILEDB_DISABLE_FILE_LOCKING=1

BASE="/work/fauverlab/zachpella/tick_mitochondira_bams_gatk"
REF="${BASE}/reference/mito_burg_ixodes_combined.fasta"
GVCF_DIR="${BASE}/genotyping/gathered_gvcfs"
SAMPLE_LIST="${BASE}/scripts/sample_names.txt"

OUT_PARENT="${BASE}/genotyping/genomicsdb"
FINAL_DB="${OUT_PARENT}/mito_nc067904_genomicsdb"

SCRATCH_BASE="/scratch/${SLURM_JOBID}"
SCRATCH_TMP="${SCRATCH_BASE}/tmp"
SCRATCH_DB="${SCRATCH_BASE}/mito_nc067904_genomicsdb"

mkdir -p logs
mkdir -p "$OUT_PARENT"
mkdir -p "$SCRATCH_TMP"

echo "Starting GenomicsDBImport at: $(date)"
echo "Host: $(hostname)"
echo "Base: $BASE"
echo "Reference: $REF"
echo "GVCF dir: $GVCF_DIR"
echo "Sample list: $SAMPLE_LIST"
echo ""

if [[ ! -s "$REF" ]]; then
    echo "ERROR: reference not found: $REF" >&2
    exit 1
fi

if [[ ! -s "${REF}.fai" ]]; then
    echo "ERROR: reference fai not found: ${REF}.fai" >&2
    exit 1
fi

if [[ ! -s "${REF%.fasta}.dict" && ! -s "${REF}.dict" ]]; then
    echo "WARNING: reference dict not found next to reference with expected names"
fi

if [[ ! -s "$SAMPLE_LIST" ]]; then
    echo "ERROR: sample list not found: $SAMPLE_LIST" >&2
    exit 1
fi

GVCF_INPUT=()
GVCF_COUNT=0
MISSING=0

while IFS= read -r SAMPLE; do
    [[ -z "$SAMPLE" || "$SAMPLE" =~ ^# ]] && continue

    GVCF="${GVCF_DIR}/${SAMPLE}.g.vcf.gz"

    if [[ -s "$GVCF" && -s "${GVCF}.tbi" ]]; then
        GVCF_INPUT+=("-V" "$GVCF")
        ((++GVCF_COUNT))
    else
        echo "ERROR: missing GVCF or index for sample $SAMPLE:"
        echo "  $GVCF"
        echo "  ${GVCF}.tbi"
        ((++MISSING))
    fi
done < "$SAMPLE_LIST"

echo "Found $GVCF_COUNT GVCFs."
echo "Missing $MISSING samples."

if [[ "$GVCF_COUNT" -ne 265 ]]; then
    echo "ERROR: expected 265 GVCFs, found $GVCF_COUNT" >&2
    exit 1
fi

if [[ "$MISSING" -ne 0 ]]; then
    echo "ERROR: missing one or more GVCFs" >&2
    exit 1
fi

if [[ -d "$FINAL_DB" ]]; then
    echo "Removing old final GenomicsDB: $FINAL_DB"
    rm -rf "$FINAL_DB"
fi

echo ""
echo "Running GenomicsDBImport..."
echo "Scratch DB: $SCRATCH_DB"
echo ""

gatk --java-options "-Djava.io.tmpdir=${SCRATCH_TMP} -Xms4G -Xmx80G -XX:ParallelGCThreads=2" \
    GenomicsDBImport \
    --genomicsdb-workspace-path "$SCRATCH_DB" \
    --genomicsdb-shared-posixfs-optimizations true \
    --tmp-dir "$SCRATCH_TMP" \
    "${GVCF_INPUT[@]}" \
    -L NC_067904.1 \
    --reference "$REF"

echo ""
echo "Copying GenomicsDB to final location..."
cp -r "$SCRATCH_DB" "$FINAL_DB"

if [[ ! -d "$FINAL_DB" ]]; then
    echo "ERROR: final GenomicsDB was not copied correctly" >&2
    exit 1
fi

echo "Final GenomicsDB:"
echo "$FINAL_DB"
echo "Completed at: $(date)"
