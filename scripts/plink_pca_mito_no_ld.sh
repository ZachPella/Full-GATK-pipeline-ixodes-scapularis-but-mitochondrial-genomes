#!/bin/bash
#SBATCH --job-name=plink_mito_pca
#SBATCH --time=04:00:00
#SBATCH --output=logs/%x_%j.out
#SBATCH --error=logs/%x_%j.err
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=2
#SBATCH --mem=32G
#SBATCH --partition=guest

set -euo pipefail

START_DIR=$(pwd)
HOST_NAME=$(hostname)
RUN_DATE=$(date)

echo "Starting working directory: ${START_DIR}"
echo "Host name: ${HOST_NAME}"
echo "Run date: ${RUN_DATE}"
echo ""

module purge
module load plink2

BASE="/work/fauverlab/zachpella/tick_mitochondira_bams_gatk"
WORKDIR="${BASE}/genotyping/filtered_vcf"

JOINTVCF="tick_mito_NC_067904.1.snps_filtered_PASS.maf01.miss05.mac2.bi"
OUTPUT_PREFIX="${JOINTVCF}.noLD_PCA"

cd "$WORKDIR"

if [[ ! -s "${JOINTVCF}.vcf.gz" ]]; then
    echo "ERROR: input VCF not found: ${WORKDIR}/${JOINTVCF}.vcf.gz" >&2
    exit 1
fi

echo "Running PLINK PCA without LD pruning."
echo "Input VCF: ${JOINTVCF}.vcf.gz"
echo "Output prefix: ${OUTPUT_PREFIX}"
echo ""

plink2 \
    --vcf "${JOINTVCF}.vcf.gz" \
    --double-id \
    --allow-extra-chr \
    --set-missing-var-ids @:# \
    --make-bed \
    --pca 20 \
    --out "${OUTPUT_PREFIX}"

echo ""
echo "PLINK PCA completed."
echo "PCA eigenvectors: ${WORKDIR}/${OUTPUT_PREFIX}.eigenvec"
echo "PCA eigenvalues:  ${WORKDIR}/${OUTPUT_PREFIX}.eigenval"
echo "PLINK files:      ${WORKDIR}/${OUTPUT_PREFIX}.bed/.bim/.fam"
echo "Completed at: $(date)"
