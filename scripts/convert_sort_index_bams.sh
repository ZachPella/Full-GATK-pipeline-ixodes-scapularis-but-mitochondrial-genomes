#!/bin/bash
#SBATCH --job-name=convsort_mito
#SBATCH --partition=guest
#SBATCH --array=1-265
#SBATCH --cpus-per-task=4
#SBATCH --mem=8G
#SBATCH --time=08:00:00
#SBATCH --output=logs/convsort_%A_%a.out
#SBATCH --error=logs/convsort_%A_%a.err

set -euo pipefail

module load samtools/1.20

BASE="/work/fauverlab/zachpella/tick_mitochondira_bams_gatk"
BAM_LIST="${BASE}/scripts/bam_list.txt"
OUTBASE="${BASE}/real_sorted_bams"

inbam=$(sed -n "${SLURM_ARRAY_TASK_ID}p" "$BAM_LIST")
subdir=$(basename "$(dirname "$inbam")")
name=$(basename "$inbam" .bam)

outdir="${OUTBASE}/${subdir}"
outbam="${outdir}/${name}.sorted.bam"

mkdir -p "$outdir"

echo "Input SAM-mislabeled-as-BAM: $inbam"
echo "Output real sorted BAM:      $outbam"

samtools view -@ "$SLURM_CPUS_PER_TASK" -b -h "$inbam" \
  | samtools sort -@ "$SLURM_CPUS_PER_TASK" -o "$outbam" -

samtools index -@ "$SLURM_CPUS_PER_TASK" "$outbam"

samtools quickcheck -v "$outbam"

echo "Done: $outbam"
