#!/bin/bash
#SBATCH --job-name=markdups_mito
#SBATCH --time=08:00:00
#SBATCH --output=logs/markdups_%A_%a.out
#SBATCH --error=logs/markdups_%A_%a.err
#SBATCH --nodes=1
#SBATCH --cpus-per-task=2
#SBATCH --mem=12G
#SBATCH --array=1-265
#SBATCH --partition=guest

set -euo pipefail

BASE="/work/fauverlab/zachpella/tick_mitochondira_bams_gatk"
INPUT_LIST="${BASE}/scripts/rg_bam_list.txt"
INPUTDIR="${BASE}/readgroups"
WORKDIR="${BASE}/dedup"

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

# example: SRR30758383_aln_Mito.rg.sorted.bam -> SRR30758383_aln_Mito
SAMPLE=$(basename "${INPUT_BAM}" .rg.sorted.bam)

OUTPUT_BAM="${WORKDIR}/${SAMPLE}.dedup.rg.sorted.bam"
METRICS_FILE="${WORKDIR}/${SAMPLE}.dedup_metrics.txt"
OUTPUT_BAI="${OUTPUT_BAM}.bai"

echo "Array Task ID: ${SLURM_ARRAY_TASK_ID}"
echo "Sample: ${SAMPLE}"
echo "Input BAM: ${INPUT_BAM}"
echo "Output BAM: ${OUTPUT_BAM}"
echo "Metrics file: ${METRICS_FILE}"
echo "Marking/removing duplicates at: $(date)"
printf "\n"

module purge
module load picard/3.0
module load samtools/1.20

echo "Checking input BAM..."
samtools quickcheck -v "${INPUT_BAM}"

echo "Running Picard MarkDuplicates..."
picard -Xmx10g MarkDuplicates \
    I="${INPUT_BAM}" \
    O="${OUTPUT_BAM}" \
    M="${METRICS_FILE}" \
    REMOVE_DUPLICATES=true \
    OPTICAL_DUPLICATE_PIXEL_DISTANCE=2500 \
    CREATE_INDEX=true \
    VALIDATION_STRINGENCY=SILENT

if [[ -s "${OUTPUT_BAM}" && -f "${OUTPUT_BAI}" ]]; then
    echo "Duplicate removal completed successfully for ${SAMPLE}"
else
    echo "Error: deduplicated BAM or index not created for ${SAMPLE}"
    exit 1
fi

echo "Checking output BAM..."
samtools quickcheck -v "${OUTPUT_BAM}"

echo "Completed at: $(date)"
