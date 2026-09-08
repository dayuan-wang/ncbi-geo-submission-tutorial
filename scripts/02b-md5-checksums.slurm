#!/bin/bash
#SBATCH --job-name=geo_md5
#SBATCH --cpus-per-task=16
#SBATCH --mem=16gb
#SBATCH --time=08:00:00
#SBATCH --output=geo_md5_%j.out
# --- add your cluster's account/QOS, e.g.:
# #SBATCH --account=YOURACCOUNT
# #SBATCH --qos=YOURQOS
# ---------------------------------------------------------------------------
# Same as 02-md5-checksums.sh, for submissions large enough that you should not
# hash them on a login node. Reference point: 479.5 GB across 173 files took
# 13 min 26 s with 16 workers (two read passes: md5 + gzip -t).
# ---------------------------------------------------------------------------
set -uo pipefail
FLAT=${FLAT:?set FLAT=/path/to/flat_folder when submitting: sbatch --export=ALL,FLAT=... }
bash "$(dirname "$0")/02-md5-checksums.sh" "$FLAT" "${SLURM_CPUS_PER_TASK:-16}"
