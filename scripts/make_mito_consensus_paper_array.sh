#!/bin/bash
#SBATCH --job-name=mito_cons_arr
#SBATCH --partition=guest
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=12G
#SBATCH --time=04:00:00
#SBATCH --array=1-265
#SBATCH --error=../logs/%x_%A_%a.err
#SBATCH --output=../logs/%x_%A_%a.out

set -euo pipefail

module purge
module load gatk4/4.6
module load bcftools
module load samtools

BASE="/work/fauverlab/zachpella/tick_mitochondira_bams_gatk"
REF="${BASE}/reference/mito_burg_ixodes_combined.fasta"

VCF="${BASE}/genotyping/filtered_vcf/tick_mito_NC_067904.1.snps_paperFilters_PASS_setFilteredGtToNocall.vcf.gz"

OUT="${BASE}/consensus_fastas_paper_method"
VCF_PER_SAMPLE="${OUT}/per_sample_vcfs"
MASKS="${OUT}/no_call_masks"
REF_FILL="${OUT}/reference_fill_fastas"
N_MASKED="${OUT}/N_masked_fastas"

mkdir -p "${BASE}/logs" "$OUT" "$VCF_PER_SAMPLE" "$MASKS" "$REF_FILL" "$N_MASKED"

SAMPLES="${OUT}/samples.txt"

# Make sample list if missing. Safe if multiple tasks try; same output.
if [[ ! -s "$SAMPLES" ]]; then
    bcftools query -l "$VCF" > "$SAMPLES"
fi

SAMPLE=$(sed -n "${SLURM_ARRAY_TASK_ID}p" "$SAMPLES")

if [[ -z "${SAMPLE:-}" ]]; then
    echo "ERROR: No sample found for array task ${SLURM_ARRAY_TASK_ID}" >&2
    exit 1
fi

SAFE_SAMPLE=$(echo "$SAMPLE" | sed 's#[/ :]#_#g')

SAMPLE_VCF="${VCF_PER_SAMPLE}/${SAFE_SAMPLE}.vcf.gz"
MASK_VCF="${MASKS}/${SAFE_SAMPLE}.nocall_mask.vcf.gz"

REF_FILL_FA="${REF_FILL}/${SAFE_SAMPLE}.refFill.fasta"
N_MASKED_FA="${N_MASKED}/${SAFE_SAMPLE}.Nmasked.fasta"

echo "Started at: $(date)"
echo "Array task: ${SLURM_ARRAY_TASK_ID}"
echo "Sample: $SAMPLE"
echo "Safe sample: $SAFE_SAMPLE"

gatk --java-options "-Xms1G -Xmx8G" \
    SelectVariants \
    -R "$REF" \
    -V "$VCF" \
    -sn "$SAMPLE" \
    -O "$SAMPLE_VCF"

gatk IndexFeatureFile -I "$SAMPLE_VCF"

# Version 1: no-calls default to reference.
gatk --java-options "-Xms1G -Xmx8G" \
    FastaAlternateReferenceMaker \
    -L NC_067904.1 \
    -R "$REF" \
    -V "$SAMPLE_VCF" \
    -O "$REF_FILL_FA"

# Mask VCF: no-call sites for this sample.
bcftools view \
    -i 'GT="./." || GT="."' \
    -Oz \
    -o "$MASK_VCF" \
    "$SAMPLE_VCF"

bcftools index -t "$MASK_VCF"

# Version 2: no-calls become Ns.
gatk --java-options "-Xms1G -Xmx8G" \
    FastaAlternateReferenceMaker \
    -L NC_067904.1 \
    -R "$REF" \
    -V "$SAMPLE_VCF" \
    --snp-mask "$MASK_VCF" \
    --snp-mask-priority true \
    -O "$N_MASKED_FA"

sed -i "1s/^>.*/>${SAMPLE}/" "$REF_FILL_FA"
sed -i "1s/^>.*/>${SAMPLE}/" "$N_MASKED_FA"

echo "Done at: $(date)"
echo "$REF_FILL_FA"
echo "$N_MASKED_FA"
