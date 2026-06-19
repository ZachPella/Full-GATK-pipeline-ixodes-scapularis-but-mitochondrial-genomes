#!/bin/bash
#SBATCH --job-name=force_N_masks
#SBATCH --partition=guest
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=8G
#SBATCH --time=02:00:00
#SBATCH --error=../logs/%x_%j.err
#SBATCH --output=../logs/%x_%j.out

set -euo pipefail

module purge
module load bcftools
module load python/3.11

BASE="/work/fauverlab/zachpella/tick_mitochondira_bams_gatk"
OUT="${BASE}/consensus_fastas_paper_method"

SAMPLES="${OUT}/samples.txt"
REF_FILL_DIR="${OUT}/reference_fill_fastas"
MASK_DIR="${OUT}/no_call_masks"
N_FORCED_DIR="${OUT}/N_masked_fastas_forced"

mkdir -p "$N_FORCED_DIR"

python - <<'PY'
import os
import subprocess

base = "/work/fauverlab/zachpella/tick_mitochondira_bams_gatk"
out = f"{base}/consensus_fastas_paper_method"

samples_file = f"{out}/samples.txt"
ref_fill_dir = f"{out}/reference_fill_fastas"
mask_dir = f"{out}/no_call_masks"
n_forced_dir = f"{out}/N_masked_fastas_forced"

def safe_name(sample):
    return sample.replace("/", "_").replace(" ", "_").replace(":", "_")

def read_fasta(path):
    header = None
    seq_parts = []
    with open(path) as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            if line.startswith(">"):
                header = line
            else:
                seq_parts.append(line)
    return header, "".join(seq_parts)

def wrap(seq, width=80):
    return "\n".join(seq[i:i+width] for i in range(0, len(seq), width))

with open(samples_file) as fh:
    samples = [x.strip() for x in fh if x.strip()]

total_masked = 0

for sample in samples:
    safe = safe_name(sample)

    fasta_in = f"{ref_fill_dir}/{safe}.refFill.fasta"
    mask_vcf = f"{mask_dir}/{safe}.nocall_mask.vcf.gz"
    fasta_out = f"{n_forced_dir}/{safe}.Nmasked.fasta"

    if not os.path.exists(fasta_in):
        raise FileNotFoundError(f"Missing ref-fill FASTA: {fasta_in}")
    if not os.path.exists(mask_vcf):
        raise FileNotFoundError(f"Missing mask VCF: {mask_vcf}")

    header, seq = read_fasta(fasta_in)
    seq = list(seq)

    result = subprocess.run(
        ["bcftools", "query", "-f", "%POS\n", mask_vcf],
        check=True,
        capture_output=True,
        text=True
    )

    masked_this_sample = 0

    for line in result.stdout.splitlines():
        if not line.strip():
            continue

        pos = int(line.strip())      # VCF is 1-based
        idx = pos - 1               # Python is 0-based

        if idx < 0 or idx >= len(seq):
            raise ValueError(f"{sample}: mask position {pos} outside sequence length {len(seq)}")

        seq[idx] = "N"
        masked_this_sample += 1

    total_masked += masked_this_sample

    with open(fasta_out, "w") as outfh:
        outfh.write(f">{sample}\n")
        outfh.write(wrap("".join(seq)) + "\n")

print(f"Samples processed: {len(samples)}")
print(f"Total forced N positions: {total_masked}")
PY

echo ""
echo "Forced N FASTA count:"
ls "$N_FORCED_DIR"/*.Nmasked.fasta | wc -l

echo "Done at: $(date)"
