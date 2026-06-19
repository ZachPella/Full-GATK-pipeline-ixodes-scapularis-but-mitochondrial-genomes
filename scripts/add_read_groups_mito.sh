#!/bin/bash
#SBATCH --job-name=add_rg_mito
#SBATCH --time=08:00:00
#SBATCH --output=logs/add_rg_%A_%a.out
#SBATCH --error=logs/add_rg_%A_%a.err
#SBATCH --nodes=1
#SBATCH --cpus-per-task=2
#SBATCH --mem=12G
#SBATCH --array=1-265
#SBATCH --partition=guest

set -euo pipefail

BASE="/work/fauverlab/zachpella/tick_mitochondira_bams_gatk"
INPUT_LIST="${BASE}/scripts/mapped_bam_list.txt"
WORKDIR="${BASE}/readgroups"

mkdir -p "${WORKDIR}" "${BASE}/logs"

if [ ! -f "${INPUT_LIST}" ]; then
    echo "Error: input BAM list not found: ${INPUT_LIST}"
    exit 1
fi

INPUT_BAM=$(sed -n "${SLURM_ARRAY_TASK_ID}p" "${INPUT_LIST}")

if [[ -z "${INPUT_BAM}" ]]; then
    echo "Error: Empty BAM for array task ${SLURM_ARRAY_TASK_ID}"
    exit 1
fi

if [[ ! -f "${INPUT_BAM}" ]]; then
    echo "Error: Input BAM not found: ${INPUT_BAM}"
    exit 1
fi

# sample name from mapped BAM filename
# example: SRR30758383_aln_Mito.sorted.mapped.bam -> SRR30758383_aln_Mito
SAMPLE=$(basename "${INPUT_BAM}" .sorted.mapped.bam)

OUTPUT_BAM="${WORKDIR}/${SAMPLE}.rg.sorted.bam"
OUTPUT_BAI="${OUTPUT_BAM}.bai"

echo "Array Task ID: ${SLURM_ARRAY_TASK_ID}"
echo "Sample: ${SAMPLE}"
echo "Input BAM: ${INPUT_BAM}"
echo "Output BAM: ${OUTPUT_BAM}"
echo "Adding read groups at: $(date)"
printf "\n"

module purge
module load picard/3.0
module load samtools/1.20

echo "Checking input BAM..."
samtools quickcheck -v "${INPUT_BAM}"

echo "Adding read groups using Picard..."
picard AddOrReplaceReadGroups \
    I="${INPUT_BAM}" \
    O="${OUTPUT_BAM}" \
    RGID="${SAMPLE}" \
    RGLB="${SAMPLE}" \
    RGPL=ILLUMINA \
    RGPU="${SAMPLE}" \
    RGSM="${SAMPLE}" \
    SORT_ORDER=coordinate \
    VALIDATION_STRINGENCY=SILENT

if [[ -s "${OUTPUT_BAM}" ]]; then
    echo "Read groups added successfully for ${SAMPLE}"
else
    echo "Error: output BAM missing or empty: ${OUTPUT_BAM}"
    exit 1
fi

echo "Indexing read-group BAM..."
samtools index -@ "${SLURM_CPUS_PER_TASK}" "${OUTPUT_BAM}"

if [[ -f "${OUTPUT_BAI}" ]]; then
    echo "Index created successfully: ${OUTPUT_BAI}"
else
    echo "Error: index not created: ${OUTPUT_BAI}"
    exit 1
fi

echo "Checking output BAM..."
samtools quickcheck -v "${OUTPUT_BAM}"

echo "Completed at: $(date)"
