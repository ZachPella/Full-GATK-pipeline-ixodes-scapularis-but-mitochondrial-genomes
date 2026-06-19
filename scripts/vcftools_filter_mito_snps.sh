#!/bin/bash
#SBATCH --job-name=vcftools_mito
#SBATCH --time=12:00:00
#SBATCH --output=logs/%x_%j.out
#SBATCH --error=logs/%x_%j.err
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=1
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
module load vcftools/0.1
module load bcftools

BASE="/work/fauverlab/zachpella/tick_mitochondira_bams_gatk"
WORKDIR="${BASE}/genotyping/filtered_vcf"

INPUT_VCF="${WORKDIR}/tick_mito_NC_067904.1.snps_filtered_PASS.vcf.gz"
OUTPUT_PREFIX="tick_mito_NC_067904.1.snps_filtered_PASS"

OUTPUT_VCF="${WORKDIR}/${OUTPUT_PREFIX}.maf01.miss05.mac2.bi.vcf.gz"

cd "$WORKDIR"

if [[ ! -s "$INPUT_VCF" ]]; then
    echo "ERROR: input VCF file not found: $INPUT_VCF" >&2
    exit 1
fi

echo "Filtering input VCF: ${INPUT_VCF}"
echo "Output VCF: ${OUTPUT_VCF}"
echo "Applying filters:"
echo "  MAF >= 0.1"
echo "  max-missing >= 0.95"
echo "  MAC >= 2"
echo "  biallelic only"
echo ""

vcftools --gzvcf "$INPUT_VCF" \
    --maf 0.1 \
    --max-missing 0.95 \
    --mac 2 \
    --min-alleles 2 \
    --max-alleles 2 \
    --recode \
    --stdout | gzip -c > "$OUTPUT_VCF"

if [[ ! -s "$OUTPUT_VCF" ]]; then
    echo "ERROR: VCFtools output was not created correctly" >&2
    exit 1
fi

bcftools index -t "$OUTPUT_VCF"

echo ""
echo "VCFtools filtering completed successfully."
echo "Filtered VCF saved to: ${OUTPUT_VCF}"
echo ""

echo "Filtered VCF stats:"
bcftools stats "$OUTPUT_VCF" | grep '^SN'

echo ""
echo "Filter column counts:"
bcftools view -H "$OUTPUT_VCF" | cut -f7 | sort | uniq -c

echo ""
echo "Sample count:"
bcftools query -l "$OUTPUT_VCF" | wc -l

echo ""
echo "Completed at: $(date)"
