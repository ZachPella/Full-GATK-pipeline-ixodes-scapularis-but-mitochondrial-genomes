#!/bin/bash
#SBATCH --job-name=mito_bam_stats
#SBATCH --partition=guest
#SBATCH --array=1-265
#SBATCH --cpus-per-task=2
#SBATCH --mem=16G
#SBATCH --time=08:00:00
#SBATCH --output=logs/mito_bam_stats_%A_%a.out
#SBATCH --error=logs/mito_bam_stats_%A_%a.err

set -euo pipefail

module purge
module load samtools/1.20

BASE="/work/fauverlab/zachpella/tick_mitochondira_bams_gatk"
BAM_LIST="${BASE}/scripts/real_sorted_bam_list.txt"

STATS_DIR="${BASE}/bam_stats"
MAPPED_DIR="${BASE}/mapped_bams"

mkdir -p "${STATS_DIR}" "${MAPPED_DIR}"

BAM_SORTED=$(sed -n "${SLURM_ARRAY_TASK_ID}p" "${BAM_LIST}")

if [[ -z "${BAM_SORTED}" ]]; then
    echo "Error: Empty BAM for array task ${SLURM_ARRAY_TASK_ID}"
    exit 1
fi

if [[ ! -f "${BAM_SORTED}" ]]; then
    echo "Error: BAM not found: ${BAM_SORTED}"
    exit 1
fi

SAMPLE=$(basename "${BAM_SORTED}" .sorted.bam)
BAM_MAPPED="${MAPPED_DIR}/${SAMPLE}.sorted.mapped.bam"

echo "Array Task ID: ${SLURM_ARRAY_TASK_ID}"
echo "Sample: ${SAMPLE}"
echo "Input sorted BAM: ${BAM_SORTED}"
echo "Mapped BAM output: ${BAM_MAPPED}"
printf "\n"

echo "Checking BAM..."
samtools quickcheck -v "${BAM_SORTED}"

echo "Generating flagstat..."
samtools flagstat "${BAM_SORTED}" > "${STATS_DIR}/flagstats.${SAMPLE}.out"

echo "Generating general samtools stats..."
samtools stats "${BAM_SORTED}" > "${STATS_DIR}/stats.general.${SAMPLE}.out"

echo "Generating depth..."
samtools depth -a "${BAM_SORTED}" > "${STATS_DIR}/${SAMPLE}.depth"

echo "Calculating average depth of coverage..."
awk '{ total += $3; count++ } END { if (count > 0) print total/count; else print "NA" }' \
    "${STATS_DIR}/${SAMPLE}.depth" > "${STATS_DIR}/averageDOC.${SAMPLE}.out"

echo "Generating samtools coverage..."
samtools coverage -o "${STATS_DIR}/coverage.${SAMPLE}.out" "${BAM_SORTED}"

echo "Generating coverage histogram..."
samtools coverage --plot-depth -o "${STATS_DIR}/hist.coverage.${SAMPLE}.out" "${BAM_SORTED}"

echo "Creating mapped-only BAM..."
samtools view -@ "${SLURM_CPUS_PER_TASK}" -b -F 4 "${BAM_SORTED}" > "${BAM_MAPPED}"

echo "Indexing mapped-only BAM..."
samtools index -@ "${SLURM_CPUS_PER_TASK}" "${BAM_MAPPED}"

echo "Checking mapped-only BAM..."
samtools quickcheck -v "${BAM_MAPPED}"

echo "✓ Processing completed for ${SAMPLE}"
echo "Stats output: ${STATS_DIR}"
echo "Mapped BAM output: ${MAPPED_DIR}"
