#!/bin/bash
#SBATCH --job-name=select_snps_mito
#SBATCH --partition=guest
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=32G
#SBATCH --time=12:00:00
#SBATCH --error=logs/%x_%j.err
#SBATCH --output=logs/%x_%j.out

set -euo pipefail

module purge
module load gatk4/4.6
module load bcftools

BASE="/work/fauverlab/zachpella/tick_mitochondira_bams_gatk"
REF="${BASE}/reference/mito_burg_ixodes_combined.fasta"

INPUT_VCF="${BASE}/genotyping/final_vcf/tick_mito_NC_067904.1.cohort.vcf.gz"

OUTDIR="${BASE}/genotyping/filtered_vcf"
OUTPUT_SNP_VCF="${OUTDIR}/tick_mito_NC_067904.1.snps_only.vcf.gz"

mkdir -p "$OUTDIR" logs

echo "Starting SelectVariants to extract SNPs..."
echo "Input VCF: ${INPUT_VCF}"
echo "Output SNP VCF: ${OUTPUT_SNP_VCF}"
echo "Started at: $(date)"

if [[ ! -s "$INPUT_VCF" ]]; then
    echo "ERROR: input VCF not found: $INPUT_VCF" >&2
    exit 1
fi

gatk --java-options "-Xms2G -Xmx24G" \
    SelectVariants \
    -R "$REF" \
    -V "$INPUT_VCF" \
    --select-type-to-include SNP \
    -O "$OUTPUT_SNP_VCF"

gatk IndexFeatureFile \
    -I "$OUTPUT_SNP_VCF"

echo "SelectVariants completed successfully."
echo "SNPs-only VCF: ${OUTPUT_SNP_VCF}"
echo ""
echo "Stats:"
bcftools stats "$OUTPUT_SNP_VCF" | grep '^SN'

echo "Completed at: $(date)"
