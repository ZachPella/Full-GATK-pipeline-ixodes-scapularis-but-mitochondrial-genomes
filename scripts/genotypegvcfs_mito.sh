#!/bin/bash
#SBATCH --job-name=genotype_mito
#SBATCH --partition=guest
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=2
#SBATCH --mem=64G
#SBATCH --time=1-00:00:00
#SBATCH --error=logs/%x_%j.err
#SBATCH --output=logs/%x_%j.out

set -euo pipefail

module purge
module load gatk4/4.6

START_DIR=$(pwd)

BASE="/work/fauverlab/zachpella/tick_mitochondira_bams_gatk"
REF_DIR="${BASE}/reference"
REF_NAME="mito_burg_ixodes_combined.fasta"
REF="${REF_DIR}/${REF_NAME}"

WORKDIR="${BASE}/genotyping"
GENOMICSDB_PATH="${WORKDIR}/genomicsdb/mito_nc067904_genomicsdb"
FINAL_OUTPUT_DIR="${WORKDIR}/final_vcf"
OUTPUT_VCF_NAME="tick_mito_NC_067904.1.cohort.vcf.gz"

TARGET_CONTIG="NC_067904.1"

SCRATCH_DIR="/scratch/${SLURM_JOBID}"
SCRATCH_TMP="${SCRATCH_DIR}/tmp"
SCRATCH_OUT="${SCRATCH_DIR}/output"
SCRATCH_DB="${SCRATCH_DIR}/mito_nc067904_genomicsdb"

mkdir -p "$SCRATCH_TMP"
mkdir -p "$SCRATCH_OUT"
mkdir -p "$FINAL_OUTPUT_DIR"
mkdir -p logs

echo "Starting working directory: ${START_DIR}"
echo "Host name: $(hostname)"
echo "Run date: $(date)"
echo ""
echo "Reference: ${REF}"
echo "GenomicsDB Path: ${GENOMICSDB_PATH}"
echo "Output Directory: ${FINAL_OUTPUT_DIR}"
echo "Output VCF: ${OUTPUT_VCF_NAME}"
echo "Target contig: ${TARGET_CONTIG}"
echo ""

if [[ ! -s "$REF" ]]; then
    echo "ERROR: Reference not found: $REF" >&2
    exit 1
fi

if [[ ! -s "${REF}.fai" ]]; then
    echo "ERROR: Reference index not found: ${REF}.fai" >&2
    exit 1
fi

DICT="${REF_DIR}/mito_burg_ixodes_combined.dict"
if [[ ! -s "$DICT" ]]; then
    echo "ERROR: Reference dict not found: $DICT" >&2
    exit 1
fi

if [[ ! -d "$GENOMICSDB_PATH" ]]; then
    echo "ERROR: GenomicsDB not found: $GENOMICSDB_PATH" >&2
    echo "Did GenomicsDBImport finish successfully?" >&2
    exit 1
fi

echo "Copying reference files to scratch..."
cp "$REF" "$SCRATCH_DIR/"
cp "${REF}.fai" "$SCRATCH_DIR/"
cp "$DICT" "$SCRATCH_DIR/"

echo "Copying GenomicsDB to scratch..."
cp -r "$GENOMICSDB_PATH" "$SCRATCH_DB"

if [[ ! -d "$SCRATCH_DB" ]]; then
    echo "ERROR: failed to copy GenomicsDB to scratch" >&2
    exit 1
fi

echo "Input files copied to scratch."
echo ""

echo "Starting GenotypeGVCFs..."
gatk --java-options "-Djava.io.tmpdir=${SCRATCH_TMP} -Xms4G -Xmx50G -XX:ParallelGCThreads=2" \
    GenotypeGVCFs \
    -R "${SCRATCH_DIR}/${REF_NAME}" \
    -V "gendb://${SCRATCH_DB}" \
    -L "${TARGET_CONTIG}" \
    -O "${SCRATCH_OUT}/${OUTPUT_VCF_NAME}"

echo "GenotypeGVCFs completed."

echo "Indexing final VCF..."
gatk IndexFeatureFile \
    -I "${SCRATCH_OUT}/${OUTPUT_VCF_NAME}"

echo "Copying final VCF and index to ${FINAL_OUTPUT_DIR}..."
cp "${SCRATCH_OUT}/${OUTPUT_VCF_NAME}" "${FINAL_OUTPUT_DIR}/"
cp "${SCRATCH_OUT}/${OUTPUT_VCF_NAME}.tbi" "${FINAL_OUTPUT_DIR}/"

if [[ ! -s "${FINAL_OUTPUT_DIR}/${OUTPUT_VCF_NAME}" ]]; then
    echo "ERROR: final VCF was not copied correctly" >&2
    exit 1
fi

if [[ ! -s "${FINAL_OUTPUT_DIR}/${OUTPUT_VCF_NAME}.tbi" ]]; then
    echo "ERROR: final VCF index was not copied correctly" >&2
    exit 1
fi

echo "Cleaning up scratch directory: ${SCRATCH_DIR}"
rm -rf "$SCRATCH_DIR"

echo "Job finished successfully."
echo "Output VCF: ${FINAL_OUTPUT_DIR}/${OUTPUT_VCF_NAME}"
echo "Completed at: $(date)"
