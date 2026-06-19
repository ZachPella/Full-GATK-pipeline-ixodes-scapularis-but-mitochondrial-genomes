#!/bin/bash
#SBATCH --job-name=index_mito_bams
#SBATCH --partition=guest
#SBATCH --array=1-265
#SBATCH --cpus-per-task=2
#SBATCH --mem=4G
#SBATCH --time=04:00:00
#SBATCH --output=logs/index_bams_%A_%a.out
#SBATCH --error=logs/index_bams_%A_%a.err

set -euo pipefail

module load samtools/1.20

BASE="/work/fauverlab/zachpella/tick_mitochondira_bams_gatk"
BAM_LIST="${BASE}/scripts/bam_list.txt"

bam=$(sed -n "${SLURM_ARRAY_TASK_ID}p" "$BAM_LIST")

echo "Indexing: $bam"
samtools quickcheck -v "$bam"
samtools index -@ "$SLURM_CPUS_PER_TASK" "$bam"

echo "Done: $bam"
