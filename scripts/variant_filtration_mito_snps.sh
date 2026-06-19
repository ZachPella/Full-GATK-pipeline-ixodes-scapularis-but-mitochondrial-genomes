#!/bin/bash
#SBATCH --job-name=filter_mito_snps
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

VCF_DIR="${BASE}/genotyping/filtered_vcf"

INPUT_SNP_VCF="${VCF_DIR}/tick_mito_NC_067904.1.snps_only.vcf.gz"
OUTPUT_FILTERED_VCF="${VCF_DIR}/tick_mito_NC_067904.1.snps_filtered.vcf.gz"
OUTPUT_PASS_VCF="${VCF_DIR}/tick_mito_NC_067904.1.snps_filtered_PASS.vcf.gz"

mkdir -p logs

echo "Starting VariantFiltration for mito SNPs..."
echo "Input SNP VCF: ${INPUT_SNP_VCF}"
echo "Filtered VCF: ${OUTPUT_FILTERED_VCF}"
echo "PASS-only VCF: ${OUTPUT_PASS_VCF}"
echo "Started at: $(date)"
echo ""

if [[ ! -s "$INPUT_SNP_VCF" ]]; then
    echo "ERROR: input SNP VCF not found: $INPUT_SNP_VCF" >&2
    exit 1
fi

gatk --java-options "-Xms2G -Xmx24G" \
    VariantFiltration \
    -R "$REF" \
    -V "$INPUT_SNP_VCF" \
    --filter-expression "QD < 2.0" --filter-name "QD2" \
    --filter-expression "QUAL < 30.0" --filter-name "QUAL30" \
    --filter-expression "SOR > 3.0" --filter-name "SOR3" \
    --filter-expression "FS > 60.0" --filter-name "FS60" \
    --filter-expression "MQ < 40.0" --filter-name "MQ40" \
    --filter-expression "MQRankSum < -12.5" --filter-name "MQRankSum-12.5" \
    --filter-expression "ReadPosRankSum < -8.0" --filter-name "ReadPosRankSum-8" \
    --missing-values-evaluate-as-failing false \
    -O "$OUTPUT_FILTERED_VCF"

gatk IndexFeatureFile \
    -I "$OUTPUT_FILTERED_VCF"

echo ""
echo "Making PASS-only filtered SNP VCF..."

gatk --java-options "-Xms2G -Xmx24G" \
    SelectVariants \
    -R "$REF" \
    -V "$OUTPUT_FILTERED_VCF" \
    --exclude-filtered true \
    -O "$OUTPUT_PASS_VCF"

gatk IndexFeatureFile \
    -I "$OUTPUT_PASS_VCF"

echo ""
echo "VariantFiltration completed successfully."
echo "Filtered VCF: ${OUTPUT_FILTERED_VCF}"
echo "PASS-only VCF: ${OUTPUT_PASS_VCF}"
echo ""

echo "Raw SNP stats:"
bcftools stats "$INPUT_SNP_VCF" | grep '^SN'

echo ""
echo "Filtered SNP stats:"
bcftools stats "$OUTPUT_FILTERED_VCF" | grep '^SN'

echo ""
echo "PASS-only SNP stats:"
bcftools stats "$OUTPUT_PASS_VCF" | grep '^SN'

echo ""
echo "Filter counts:"
bcftools view -H "$OUTPUT_FILTERED_VCF" | cut -f7 | sort | uniq -c

echo "Completed at: $(date)"
