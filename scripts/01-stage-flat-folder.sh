#!/bin/bash
# ---------------------------------------------------------------------------
# Stage a GEO submission: symlink every file into ONE FLAT FOLDER, then verify.
#
# Why symlinks: GEO wants a single flat subfolder with no nesting, but
# sequencing output is scattered across per-sample directories. Copying
# hundreds of GB wastes disk and time; symlinks cost bytes.
#
# IMPORTANT: GEO does NOT accept symbolic links in a submission -
#   "Do not submit symbolic links, raw files downloaded from SRA, or
#    duplicate files previously submitted to GEO/SRA."
# The links are a LOCAL staging device only. Your upload command must
# dereference them (lftp: `mirror -R -L`). See 03-ftp-upload.sh.
#
# Edit the CONFIG block, then run. Re-running is safe: it clears only
# symlinks, and refuses to touch the folder if anything else appears in it.
# ---------------------------------------------------------------------------
set -euo pipefail

# ----------------------------- CONFIG --------------------------------------
FLAT=./geo_submission_flat                 # the folder you will upload
SAMPLES=(SAMPLE_A SAMPLE_B SAMPLE_C)       # your sample IDs
FASTQ_DIR_TEMPLATE='/path/to/fastq/<SAMPLE>'                       # <SAMPLE> is substituted
PROC_FILE_TEMPLATE='/path/to/cellranger/<SAMPLE>/outs/filtered_feature_bc_matrix.h5'
PROC_NAME_TEMPLATE='<SAMPLE>_filtered_feature_bc_matrix.h5'        # name GEO will see
EXPECT_FASTQ_PER_SAMPLE=0                  # 0 = don't check; set it if you know
# ---------------------------------------------------------------------------

MANIFEST=./staged_files.tsv

if [ -d "$FLAT" ] && [ -n "$(ls -A "$FLAT" 2>/dev/null)" ]; then
  if find "$FLAT" -mindepth 1 ! -type l -print -quit | grep -q .; then
    echo "FATAL: $FLAT contains non-symlink entries. Refusing to touch it." >&2; exit 1
  fi
  echo "Clearing $(find "$FLAT" -type l | wc -l) symlinks from a previous run."
  find "$FLAT" -type l -delete
fi
mkdir -p "$FLAT"
printf 'geo_filename\tfile_type\tsample\tbytes\tsource_path\n' > "$MANIFEST"

link() {  # $1 source  $2 name GEO will see  $3 raw|processed  $4 sample
  [ -f "$1" ]           || { echo "FATAL: missing source: $1" >&2; exit 1; }
  [ ! -e "$FLAT/$2" ]   || { echo "FATAL: duplicate GEO filename: $2" >&2; exit 1; }
  case "$2" in *[!A-Za-z0-9._-]*)
    echo "FATAL: '$2' has characters GEO rejects. Allowed: A-Z a-z 0-9 . _ -  (no spaces)" >&2; exit 1;;
  esac
  ln -s "$1" "$FLAT/$2"
  printf '%s\t%s\t%s\t%s\t%s\n' "$2" "$3" "$4" "$(stat -Lc %s "$1" 2>/dev/null || stat -f %z "$1")" "$1" >> "$MANIFEST"
}

for s in "${SAMPLES[@]}"; do
  n=0
  fqdir="${FASTQ_DIR_TEMPLATE//<SAMPLE>/$s}"
  while IFS= read -r f; do
    link "$f" "$(basename "$f")" raw "$s"; n=$((n+1))
  done < <(find "$fqdir" -name '*.fastq.gz' -type f | sort)
  if [ "$EXPECT_FASTQ_PER_SAMPLE" -gt 0 ] && [ "$n" -ne "$EXPECT_FASTQ_PER_SAMPLE" ]; then
    echo "FATAL: $s has $n FASTQ, expected $EXPECT_FASTQ_PER_SAMPLE" >&2; exit 1
  fi
  link "${PROC_FILE_TEMPLATE//<SAMPLE>/$s}" "${PROC_NAME_TEMPLATE//<SAMPLE>/$s}" processed "$s"
  printf '  %-16s %2d raw + 1 processed\n' "$s" "$n"
done

echo
echo "== verification =="
n_all=$(find "$FLAT" -maxdepth 1 -type l | wc -l)
n_dangling=$(find "$FLAT" -maxdepth 1 -xtype l | wc -l)
n_other=$(find "$FLAT" -mindepth 1 ! -type l | wc -l)
n_subdir=$(find "$FLAT" -mindepth 1 -type d | wc -l)
n_uniq=$(find "$FLAT" -maxdepth 1 -type l -exec basename {} \; | sort -u | wc -l)
bytes=$(find "$FLAT" -maxdepth 1 -type l -exec stat -Lc %s {} + 2>/dev/null | awk '{s+=$1} END{print s+0}')

printf '  links            %s\n'            "$n_all"
printf '  unique names     %s   (must equal links)\n' "$n_uniq"
printf '  dangling         %s   (must be 0)\n' "$n_dangling"
printf '  non-symlinks     %s   (must be 0)\n' "$n_other"
printf '  subdirectories   %s   (must be 0 - GEO wants a flat folder)\n' "$n_subdir"
printf '  bytes behind     %s  (%.1f GB)\n' "$bytes" "$(awk -v b="$bytes" 'BEGIN{print b/1e9}')"
printf '  disk actually    %s\n'            "$(du -sh "$FLAT" | cut -f1)"

fail=0
[ "$n_uniq"      -eq "$n_all" ] || { echo "  FAIL: duplicate names" >&2; fail=1; }
[ "$n_dangling"  -eq 0 ] || { echo "  FAIL: dangling links"  >&2; fail=1; }
[ "$n_other"     -eq 0 ] || { echo "  FAIL: non-symlinks"    >&2; fail=1; }
[ "$n_subdir"    -eq 0 ] || { echo "  FAIL: subdirectories"  >&2; fail=1; }
find "$FLAT" -maxdepth 1 \( -iname '*.xls*' -o -iname '*.csv' \) | grep -q . && {
  echo "  FAIL: a spreadsheet is staged - GEO forbids uploading metadata by FTP" >&2; fail=1; }

echo
[ "$fail" -eq 0 ] && echo "STAGING OK -> $FLAT   (manifest: $MANIFEST)" \
                  || { echo "STAGING FAILED" >&2; exit 1; }
