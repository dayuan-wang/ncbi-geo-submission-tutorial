#!/bin/bash
# ---------------------------------------------------------------------------
# MD5 checksums + gzip integrity for a staged GEO submission.
#
# Writes a PLAIN TEXT table you copy by hand into the "MD5 Checksums" tab of
# the metadata spreadsheet. It deliberately does NOT write an .xlsx:
#   * GEO: "Do not submit MD5 checksums in separate file(s)."
#     The values must live in the spreadsheet tab, not a file you upload.
#   * Scripting Excel for a one-off, hand-filled workbook is more trouble
#     than pasting two columns.
#
# The gzip -t pass is not optional in spirit: a mid-file or tail truncation is
# invisible to a magic-byte check and would only surface after NCBI has
# ingested the whole submission.
#
# Usage:  ./02-md5-checksums.sh <flat_folder> [n_parallel]
# ---------------------------------------------------------------------------
set -uo pipefail
FLAT=${1:?usage: $0 <flat_folder> [n_parallel]}
NPROC=${2:-4}
OUT=./md5_checksums.txt

command -v md5sum >/dev/null && MD5="md5sum" || MD5="md5 -r"   # Linux / macOS

worker() {
  f=$1
  h=$( { md5sum -- "$f" 2>/dev/null || md5 -q -- "$f"; } | cut -d' ' -f1 )
  case "$f" in
    *.gz) gzip -t -- "$f" 2>/dev/null && g=OK || g=CORRUPT ;;
    *)    g=NA ;;
  esac
  printf '%s\t%s\t%s\n' "$(basename "$f")" "$h" "$g"
}
export -f worker

echo "Hashing $(find "$FLAT" -maxdepth 1 -type l -o -maxdepth 1 -type f | wc -l) files with $NPROC workers..."
find "$FLAT" -maxdepth 1 \( -type l -o -type f \) -print0 \
  | xargs -0 -P "$NPROC" -I{} bash -c 'worker "$@"' _ {} \
  | sort > "$OUT.body"
{ printf 'file_name\tfile_checksum\tgzip_test\n'; cat "$OUT.body"; } > "$OUT"
rm -f "$OUT.body"

n=$(( $(wc -l < "$OUT") - 1 ))
bad=$(awk -F'\t' 'NR>1 && $3=="CORRUPT"' "$OUT" | wc -l)
dup=$(( n - $(tail -n +2 "$OUT" | cut -f2 | sort -u | wc -l) ))

echo
printf '  files hashed      %s\n' "$n"
printf '  gzip CORRUPT      %s   (must be 0)\n' "$bad"
printf '  duplicate md5     %s   (non-zero = two files have identical content)\n' "$dup"
echo
if [ "$bad" -eq 0 ]; then
  echo "OK -> $OUT"
  echo "Now paste columns 1 and 2 into the 'MD5 Checksums' tab of the metadata"
  echo "spreadsheet: raw files in the RAW FILES block, processed in the other."
else
  echo "CORRUPT FILES FOUND - do not upload until fixed:" >&2
  awk -F'\t' 'NR>1 && $3=="CORRUPT" {print "   "$1}' "$OUT" >&2
  exit 1
fi
