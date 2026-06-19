#!/bin/bash
#SBATCH --job-name=hc_mito10
#SBATCH --time=1-00:00:00
#SBATCH --output=logs/hc_mito10_%A_%a.out
#SBATCH --error=logs/hc_mito10_%A_%a.err
#SBATCH --nodes=1
#SBATCH --cpus-per-task=10
#SBATCH --mem=40G
#SBATCH --array=1-265%5
#SBATCH --partition=guest

set -euo pipefail

START_DIR=$(pwd)
HOST_NAME=$(hostname)
RUN_DATE=$(date)

echo "Starting working directory: ${START_DIR}"
echo "Host name: ${HOST_NAME}"
echo "Run date: ${RUN_DATE}"
printf "\n"

BASE="/work/fauverlab/zachpella/tick_mitochondira_bams_gatk"
WORKDIR="${BASE}/genotyping"
BAM_LIST="${BASE}/scripts/dedup_bam_list.txt"
BAMDIR="${BASE}/dedup"

REF="${BASE}/reference/mito_burg_ixodes_combined.fasta"
GLOBAL_INTERVAL_DIR="${BASE}/global_intervals_mito_10"

SCATTER_COUNT=10
CPUS_PER_CHUNK=1
MEM_PER_CHUNK=3

mkdir -p "${WORKDIR}/scattered_gvcfs" "${BASE}/logs"

if [[ ! -f "${BAM_LIST}" ]]; then
    echo "Error: BAM list not found: ${BAM_LIST}"
    exit 1
fi

if [[ ! -f "${REF}" ]]; then
    echo "Error: Reference not found: ${REF}"
    exit 1
fi

if [[ ! -f "${REF}.fai" ]]; then
    echo "Error: Reference index not found: ${REF}.fai"
    exit 1
fi

if [[ ! -f "${BASE}/reference/mito_burg_ixodes_combined.dict" ]]; then
    echo "Error: Reference dict not found"
    exit 1
fi

BAM_FILE=$(sed -n "${SLURM_ARRAY_TASK_ID}p" "${BAM_LIST}")

if [[ -z "${BAM_FILE}" ]]; then
    echo "Error: Empty BAM for array task ${SLURM_ARRAY_TASK_ID}"
    exit 1
fi

if [[ ! -f "${BAM_FILE}" ]]; then
    echo "Error: BAM not found: ${BAM_FILE}"
    exit 1
fi

SAMPLE=$(basename "${BAM_FILE}" .dedup.rg.sorted.bam)

echo "Array Task ID: ${SLURM_ARRAY_TASK_ID}"
echo "Sample: ${SAMPLE}"
echo "BAM: ${BAM_FILE}"
echo "Reference: ${REF}"
echo "Intervals: ${GLOBAL_INTERVAL_DIR}"
echo "Scatter count: ${SCATTER_COUNT}"
echo "Memory per chunk: ${MEM_PER_CHUNK}G"
printf "\n"

module purge
module load gatk4/4.6
module load samtools/1.20

echo "Checking BAM..."
samtools quickcheck -v "${BAM_FILE}"

mkdir -p "${WORKDIR}/scattered_gvcfs/${SAMPLE}"
cd "${WORKDIR}"

echo "Running ${SCATTER_COUNT} parallel HaplotypeCaller jobs..."

pids=()

for i in $(seq 0 $((SCATTER_COUNT-1))); do
    CHUNK=$(printf "%04d" "$i")
    SCATTERED_INTERVAL="${GLOBAL_INTERVAL_DIR}/${CHUNK}-scattered.interval_list"

    if [[ ! -f "${SCATTERED_INTERVAL}" ]]; then
        echo "Error: interval file not found: ${SCATTERED_INTERVAL}"
        exit 1
    fi

    CHUNK_GVCF="scattered_gvcfs/${SAMPLE}/${SAMPLE}.${CHUNK}.g.vcf.gz"

    gatk --java-options "-Xmx${MEM_PER_CHUNK}G -Djava.io.tmpdir=/tmp" HaplotypeCaller \
        -R "${REF}" \
        -I "${BAM_FILE}" \
        -native-pair-hmm-threads "${CPUS_PER_CHUNK}" \
        -L "${SCATTERED_INTERVAL}" \
        -ploidy 2 \
        -O "${CHUNK_GVCF}" \
        --ERC GVCF &

    pids+=($!)
done

echo "Waiting for HaplotypeCaller chunks..."
fail=0
for pid in "${pids[@]}"; do
    if ! wait "$pid"; then
        echo "A HaplotypeCaller chunk failed."
        fail=1
    fi
done

if [[ "$fail" -ne 0 ]]; then
    echo "Error: one or more HaplotypeCaller chunks failed for ${SAMPLE}"
    exit 1
fi

echo "Verifying scattered GVCFs..."
for i in $(seq 0 $((SCATTER_COUNT-1))); do
    CHUNK=$(printf "%04d" "$i")
    CHUNK_GVCF="scattered_gvcfs/${SAMPLE}/${SAMPLE}.${CHUNK}.g.vcf.gz"

    if [[ ! -s "${CHUNK_GVCF}" ]]; then
        echo "Error: missing or empty GVCF: ${CHUNK_GVCF}"
        exit 1
    fi

    if [[ ! -s "${CHUNK_GVCF}.tbi" ]]; then
        echo "Error: missing or empty index: ${CHUNK_GVCF}.tbi"
        exit 1
    fi
done

echo "HaplotypeCaller completed successfully for ${SAMPLE}"
echo "Output: ${WORKDIR}/scattered_gvcfs/${SAMPLE}/"
echo "Completed at: $(date)"
