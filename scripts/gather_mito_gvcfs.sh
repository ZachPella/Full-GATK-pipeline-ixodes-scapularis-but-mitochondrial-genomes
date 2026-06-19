#!/bin/bash
#SBATCH --job-name=gather_mito_gvcfs
#SBATCH --partition=guest
#SBATCH --time=12:00:00
#SBATCH --cpus-per-task=2
#SBATCH --mem=16G
#SBATCH --output=logs/gather_mito_gvcfs_%A_%a.out
#SBATCH --error=logs/gather_mito_gvcfs_%A_%a.err
#SBATCH --array=1-265%50

set -euo pipefail

module purge
module load gatk4/4.6

BASE="/work/fauverlab/zachpella/tick_mitochondira_bams_gatk"
SCATTER="${BASE}/genotyping/scattered_gvcfs"
OUTDIR="${BASE}/genotyping/gathered_gvcfs"
SAMPLE_LIST="${BASE}/scripts/sample_names.txt"

mkdir -p "$OUTDIR" logs

sample=$(sed -n "${SLURM_ARRAY_TASK_ID}p" "$SAMPLE_LIST")

echo "Gathering sample: $sample"
echo "Started: $(date)"

inputs=()
for chunk in {0..9}; do
    chunk4=$(printf "%04d" "$chunk")
    gvcf="${SCATTER}/${sample}/${sample}.${chunk4}.g.vcf.gz"

    if [[ ! -s "$gvcf" ]]; then
        echo "ERROR: missing $gvcf" >&2
        exit 1
    fi

    if [[ ! -s "${gvcf}.tbi" ]]; then
        echo "ERROR: missing ${gvcf}.tbi" >&2
        exit 1
    fi

    inputs+=("-I" "$gvcf")
done

out="${OUTDIR}/${sample}.g.vcf.gz"

rm -f "$out" "${out}.tbi"

gatk GatherVcfs \
    "${inputs[@]}" \
    -O "$out"

gatk IndexFeatureFile \
    -I "$out"

echo "Finished: $(date)"
