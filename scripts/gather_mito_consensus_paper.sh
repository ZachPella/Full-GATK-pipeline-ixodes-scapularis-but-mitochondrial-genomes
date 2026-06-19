#!/bin/bash
#SBATCH --job-name=gather_mito_cons
#SBATCH --partition=guest
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=8G
#SBATCH --time=01:00:00
#SBATCH --error=../logs/%x_%j.err
#SBATCH --output=../logs/%x_%j.out

set -euo pipefail

module purge

BASE="/work/fauverlab/zachpella/tick_mitochondira_bams_gatk"
OUT="${BASE}/consensus_fastas_paper_method"
REF_FILL="${OUT}/reference_fill_fastas"
N_MASKED="${OUT}/N_masked_fastas"

SAMPLES="${OUT}/samples.txt"

REF_OUT="${OUT}/tick_mito_consensus_refFill_alignment.fasta"
N_OUT="${OUT}/tick_mito_consensus_Nmasked_alignment.fasta"

echo "Started gather at: $(date)"

rm -f "$REF_OUT" "$N_OUT"

while read -r SAMPLE; do
    SAFE_SAMPLE=$(echo "$SAMPLE" | sed 's#[/ :]#_#g')

    REF_FA="${REF_FILL}/${SAFE_SAMPLE}.refFill.fasta"
    N_FA="${N_MASKED}/${SAFE_SAMPLE}.Nmasked.fasta"

    if [[ ! -s "$REF_FA" ]]; then
        echo "ERROR: Missing ref-fill FASTA: $REF_FA" >&2
        exit 1
    fi

    if [[ ! -s "$N_FA" ]]; then
        echo "ERROR: Missing N-masked FASTA: $N_FA" >&2
        exit 1
    fi

    cat "$REF_FA" >> "$REF_OUT"
    cat "$N_FA" >> "$N_OUT"

done < "$SAMPLES"

echo ""
echo "Sequence counts:"
grep -c "^>" "$REF_OUT"
grep -c "^>" "$N_OUT"

echo ""
echo "Unique lengths, ref-fill:"
awk '/^>/ {if (seq!="") print length(seq); seq=""; next} {seq=seq$0} END {print length(seq)}' "$REF_OUT" | sort -nu

echo ""
echo "Unique lengths, N-masked:"
awk '/^>/ {if (seq!="") print length(seq); seq=""; next} {seq=seq$0} END {print length(seq)}' "$N_OUT" | sort -nu

echo ""
echo "Total Ns in N-masked:"
grep -v "^>" "$N_OUT" | tr -cd 'Nn' | wc -c

echo ""
echo "Done gather at: $(date)"
echo "$REF_OUT"
echo "$N_OUT"
