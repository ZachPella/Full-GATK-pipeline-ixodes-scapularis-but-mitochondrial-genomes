#!/bin/bash
#SBATCH --job-name=filter_mito_paper
#SBATCH --partition=guest
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=32G
#SBATCH --time=12:00:00
#SBATCH --error=../logs/%x_%j.err
#SBATCH --output=../logs/%x_%j.out

set -euo pipefail

module purge
module load gatk4/4.6
module load bcftools

BASE="/work/fauverlab/zachpella/tick_mitochondira_bams_gatk"
REF="${BASE}/reference/mito_burg_ixodes_combined.fasta"

VCF_DIR="${BASE}/genotyping/filtered_vcf"

INPUT_SNP_VCF="${VCF_DIR}/tick_mito_NC_067904.1.snps_only.vcf.gz"

# Paper-style outputs
GT_FILTERED_VCF="${VCF_DIR}/tick_mito_NC_067904.1.snps_paperFilters_gtFiltered.vcf.gz"
SET_NOCALL_VCF="${VCF_DIR}/tick_mito_NC_067904.1.snps_paperFilters_setFilteredGtToNocall.vcf.gz"
PASS_NOCALL_VCF="${VCF_DIR}/tick_mito_NC_067904.1.snps_paperFilters_PASS_setFilteredGtToNocall.vcf.gz"

mkdir -p "${BASE}/logs"

echo "Starting paper-style SNP/genotype filtering..."
echo "Input SNP VCF: ${INPUT_SNP_VCF}"
echo "GT/site filtered VCF: ${GT_FILTERED_VCF}"
echo "Set-filtered-GT-to-no-call VCF: ${SET_NOCALL_VCF}"
echo "PASS-only no-call VCF: ${PASS_NOCALL_VCF}"
echo "Started at: $(date)"
echo ""

if [[ ! -s "$INPUT_SNP_VCF" ]]; then
    echo "ERROR: input SNP VCF not found: $INPUT_SNP_VCF" >&2
    exit 1
fi

# Paper filters:
# QD < 2.0
# FS > 60.0
# MQ < 40.0
# MQRankSum < -12.5
# ReadPosRankSum < -8.0
# GQ < 20
# SOR > 4.0
#
# The -G-filter applies a genotype-level filter to individual sample genotypes.
gatk --java-options "-Xms2G -Xmx24G" \
    VariantFiltration \
    -R "$REF" \
    -V "$INPUT_SNP_VCF" \
    --filter-expression "QD < 2.0" --filter-name "QD2" \
    --filter-expression "FS > 60.0" --filter-name "FS60" \
    --filter-expression "MQ < 40.0" --filter-name "MQ40" \
    --filter-expression "MQRankSum < -12.5" --filter-name "MQRankSum-12.5" \
    --filter-expression "ReadPosRankSum < -8.0" --filter-name "ReadPosRankSum-8" \
    --filter-expression "SOR > 4.0" --filter-name "SOR4" \
    -G-filter "GQ < 20.0" \
    -G-filter-name "GQ20" \
    --missing-values-evaluate-as-failing false \
    -O "$GT_FILTERED_VCF"

gatk IndexFeatureFile -I "$GT_FILTERED_VCF"

echo ""
echo "Converting filtered genotypes to no-call using --set-filtered-gt-to-nocall..."

gatk --java-options "-Xms2G -Xmx24G" \
    SelectVariants \
    -R "$REF" \
    -V "$GT_FILTERED_VCF" \
    --set-filtered-gt-to-nocall \
    -O "$SET_NOCALL_VCF"

gatk IndexFeatureFile -I "$SET_NOCALL_VCF"

echo ""
echo "Keeping only PASS SNP sites, while retaining sample-level no-calls..."

gatk --java-options "-Xms2G -Xmx24G" \
    SelectVariants \
    -R "$REF" \
    -V "$SET_NOCALL_VCF" \
    --exclude-filtered true \
    -O "$PASS_NOCALL_VCF"

gatk IndexFeatureFile -I "$PASS_NOCALL_VCF"

echo ""
echo "Paper-style filtering completed."
echo ""

echo "Raw SNP stats:"
bcftools stats "$INPUT_SNP_VCF" | grep '^SN'

echo ""
echo "After site + genotype filtering:"
bcftools stats "$GT_FILTERED_VCF" | grep '^SN'

echo ""
echo "After setFilteredGtToNocall:"
bcftools stats "$SET_NOCALL_VCF" | grep '^SN'

echo ""
echo "PASS-only after setFilteredGtToNocall:"
bcftools stats "$PASS_NOCALL_VCF" | grep '^SN'

echo ""
echo "Site filter counts:"
bcftools view -H "$GT_FILTERED_VCF" | cut -f7 | sort | uniq -c

echo ""
echo "Number of no-call genotypes in final PASS no-call VCF:"
bcftools query -f '[%SAMPLE\t%CHROM\t%POS\t%GT\n]' "$PASS_NOCALL_VCF" \
    | awk '$4=="./." || $4=="." {n++} END{print n+0}'

echo ""
echo "Top samples by no-call count:"
bcftools query -f '[%SAMPLE\t%GT\n]' "$PASS_NOCALL_VCF" \
    | awk '$2=="./." || $2=="." {n[$1]++} END{for (s in n) print s,n[s]}' \
    | sort -k2,2nr \
    | head -30

echo ""
echo "Completed at: $(date)"
