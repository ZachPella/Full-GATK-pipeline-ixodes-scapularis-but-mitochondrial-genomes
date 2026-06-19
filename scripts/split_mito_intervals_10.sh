#!/bin/bash
#SBATCH --job-name=split_mito_10
#SBATCH --partition=guest
#SBATCH --time=01:00:00
#SBATCH --mem=8G
#SBATCH --cpus-per-task=1
#SBATCH --output=logs/split_mito_10_%j.out
#SBATCH --error=logs/split_mito_10_%j.err

set -euo pipefail

module purge
module load gatk4/4.6

BASE="/work/fauverlab/zachpella/tick_mitochondira_bams_gatk"
REF="${BASE}/reference/mito_burg_ixodes_combined.fasta"
TARGETS="${BASE}/scripts/mito_targets.interval_list"
OUTDIR="${BASE}/global_intervals_mito_10"

mkdir -p "${OUTDIR}" "${BASE}/logs"
rm -rf "${OUTDIR:?}"/*

gatk SplitIntervals \
  -R "${REF}" \
  -L "${TARGETS}" \
  -O "${OUTDIR}" \
  --scatter-count 10

ls -lh "${OUTDIR}"
