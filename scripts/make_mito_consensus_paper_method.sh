#!/bin/bash
#SBATCH --job-name=mito_consensus_paper
#SBATCH --partition=guest
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=2
#SBATCH --mem=48G
#SBATCH --time=24:00:00
#SBATCH --error=../logs/%x_%j.err
#SBATCH --output=../logs/%x_%j.out

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

echo "Started at: $(date)"
echo "Reference: $REF"
echo "Paper-style VCF: $VCF"
echo "Output dir: $OUT"
echo ""

if [[ ! -s "$VCF" ]]; then
    echo "ERROR: VCF not found: $VCF" >&2
    exit 1
fi

if [[ ! -s "${REF}.fai" ]]; then
    samtools faidx "$REF"
fi

# Create sequence dictionary if missing.
DICT="${REF%.*}.dict"
if [[ ! -s "$DICT" ]]; then
    gatk CreateSequenceDictionary -R "$REF"
fi

bcftools query -l "$VCF" > "${OUT}/samples.txt"

echo "Number of samples:"
wc -l "${OUT}/samples.txt"
echo ""

while read -r SAMPLE; do
    echo "Processing sample: $SAMPLE"

    SAFE_SAMPLE=$(echo "$SAMPLE" | sed 's#[/ :]#_#g')

    SAMPLE_VCF="${VCF_PER_SAMPLE}/${SAFE_SAMPLE}.vcf.gz"
    MASK_VCF="${MASKS}/${SAFE_SAMPLE}.nocall_mask.vcf.gz"

    REF_FILL_FA="${REF_FILL}/${SAFE_SAMPLE}.refFill.fasta"
    N_MASKED_FA="${N_MASKED}/${SAFE_SAMPLE}.Nmasked.fasta"

    # One-sample VCF.
    gatk --java-options "-Xms1G -Xmx8G" \
        SelectVariants \
        -R "$REF" \
        -V "$VCF" \
        -sn "$SAMPLE" \
        -O "$SAMPLE_VCF"

    gatk IndexFeatureFile -I "$SAMPLE_VCF"

    # Consensus version 1:
    # no-calls default to reference bases.
    gatk --java-options "-Xms1G -Xmx8G" \
        FastaAlternateReferenceMaker \
        -R "$REF" \
        -V "$SAMPLE_VCF" \
        -O "$REF_FILL_FA"

    # Select this sample's no-call sites to use as mask.
    bcftools view \
        -i 'GT="./." || GT="."' \
        -Oz \
        -o "$MASK_VCF" \
        "$SAMPLE_VCF"

    bcftools index -t "$MASK_VCF"

    # Consensus version 2:
    # no-calls become Ns using --snp-mask.
    gatk --java-options "-Xms1G -Xmx8G" \
        FastaAlternateReferenceMaker \
        -R "$REF" \
        -V "$SAMPLE_VCF" \
        --snp-mask "$MASK_VCF" \
        -O "$N_MASKED_FA"

    # Rename FASTA header from reference contig to sample name.
    sed -i "1s/^>.*/>${SAMPLE}/" "$REF_FILL_FA"
    sed -i "1s/^>.*/>${SAMPLE}/" "$N_MASKED_FA"

done < "${OUT}/samples.txt"

echo ""
echo "Combining FASTAs..."

cat "$REF_FILL"/*.refFill.fasta > "${OUT}/tick_mito_consensus_refFill_alignment.fasta"
cat "$N_MASKED"/*.Nmasked.fasta > "${OUT}/tick_mito_consensus_Nmasked_alignment.fasta"

echo ""
echo "Sequence counts:"
grep -c "^>" "${OUT}/tick_mito_consensus_refFill_alignment.fasta"
grep -c "^>" "${OUT}/tick_mito_consensus_Nmasked_alignment.fasta"

echo ""
echo "Unique sequence lengths in ref-fill alignment:"
awk '/^>/ {if (seq!="") print length(seq); seq=""; next} {seq=seq$0} END {print length(seq)}' \
    "${OUT}/tick_mito_consensus_refFill_alignment.fasta" | sort -nu

echo ""
echo "Unique sequence lengths in N-masked alignment:"
awk '/^>/ {if (seq!="") print length(seq); seq=""; next} {seq=seq$0} END {print length(seq)}' \
    "${OUT}/tick_mito_consensus_Nmasked_alignment.fasta" | sort -nu

echo ""
echo "N counts per sample:"
awk '
    /^>/ {
        if (name!="") print name "\t" n
        name=substr($0,2)
        n=0
        next
    }
    {
        n += gsub(/[Nn]/,"")
    }
    END {
        if (name!="") print name "\t" n
    }
' "${OUT}/tick_mito_consensus_Nmasked_alignment.fasta" \
    > "${OUT}/N_counts_per_sample.tsv"

sort -k2,2nr "${OUT}/N_counts_per_sample.tsv" | head -30

echo ""
echo "Done at: $(date)"
echo "Reference-fill alignment:"
echo "${OUT}/tick_mito_consensus_refFill_alignment.fasta"
echo "N-masked alignment:"
echo "${OUT}/tick_mito_consensus_Nmasked_alignment.fasta"
