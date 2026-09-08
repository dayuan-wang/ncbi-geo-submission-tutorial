#!/bin/bash
# ---------------------------------------------------------------------------
# Upload a staged GEO submission over FTP with lftp, then verify byte for byte.
#
# THE ONE FLAG THAT MATTERS:  mirror -R -L
#   -L (--dereference) makes lftp upload what each symlink POINTS AT.
#   Without it lftp recreates the links, and what lands on GEO's server is a
#   short path string, not your data. Measured with lftp 4.9.2: a 25-byte file
#   arrives as 25 bytes with -L, and as a 33-byte symlink without it.
#   lftp exits 0 either way.
#   GEO also states plainly: "Do not submit symbolic links."
#
# CREDENTIALS are read from ~/.geoftp_creds, which must be mode 600 and define
# GEOUSER and GEOPASS. Never put a password on the command line: `lftp -u u,p`
# is visible in `ps` to every other user on a shared machine and lands in your
# shell history.
#
#   umask 077
#   cat > ~/.geoftp_creds <<'CREDS'
#   GEOUSER=geoftp
#   GEOPASS=paste_from_the_GEO_page
#   CREDS
#   chmod 600 ~/.geoftp_creds
#
# Usage:  ./03-ftp-upload.sh <flat_folder> <upload_space> <subfolder>
#   e.g.  ./03-ftp-upload.sh ./geo_submission_flat uploads/yourname_abcd1234 RNAseq
# ---------------------------------------------------------------------------
set -uo pipefail

FLAT=${1:?usage: $0 <flat_folder> <upload_space> <subfolder>}
SPACE=${2:?}                 # uploads/yourname_abcd1234  (read it off the GEO page)
SUBDIR=${3:?}                # a meaningful name: RNAseq, ChIPseq, scRNAseq...
HOST=ftp-private.ncbi.nlm.nih.gov
MANIFEST=${MANIFEST:-./staged_files.tsv}
CREDS=$HOME/.geoftp_creds

[ -f "$CREDS" ] || { echo "FATAL: $CREDS missing. See the header of this script." >&2; exit 1; }
perm=$(stat -c %a "$CREDS" 2>/dev/null || stat -f %A "$CREDS")
[ "$perm" = "600" ] || { echo "FATAL: $CREDS is mode $perm. Run: chmod 600 $CREDS" >&2; exit 1; }
. "$CREDS"
: "${GEOUSER:?GEOUSER not set in $CREDS}"; : "${GEOPASS:?GEOPASS not set in $CREDS}"
export GEOPASS

# lftp prints ftp://user:password@host in several messages. Filter every line.
redact() { python3 -c '
import sys, os
p = os.environ.get("GEOPASS","")
for line in sys.stdin: sys.stdout.write(line.replace(p,"<redacted>") if p else line)
'; }

echo "== pre-flight =="
n=$(find "$FLAT" -maxdepth 1 \( -type l -o -type f \) | wc -l)
d=$(find "$FLAT" -maxdepth 1 -xtype l | wc -l)
s=$(find "$FLAT" -mindepth 1 -type d | wc -l)
m=$(find "$FLAT" -maxdepth 1 \( -iname '*.xls*' -o -iname '*.csv' \) | wc -l)
printf '  files %s   dangling %s   subdirs %s   spreadsheets %s\n' "$n" "$d" "$s" "$m"
[ "$d" -eq 0 ] || { echo "  FAIL: dangling symlinks" >&2; exit 1; }
[ "$s" -eq 0 ] || { echo "  FAIL: subdirectories - GEO wants a flat folder" >&2; exit 1; }
[ "$m" -eq 0 ] || { echo "  FAIL: metadata spreadsheet staged - GEO forbids it by FTP" >&2; exit 1; }

echo
echo "== transfer =="
# NOTE: cd into the upload space FIRST. Its ROOT refuses directory listing by
# design ("550 /: Permission denied"), so mkdir -p on an absolute path fails.
lftp "$HOST" <<LFTP 2>&1 | redact
user $GEOUSER $GEOPASS
set ftp:ssl-allow no
set ftp:passive-mode on
set net:max-retries 10
set net:reconnect-interval-base 15
set net:timeout 120
set xfer:clobber on
cd $SPACE
mkdir -f $SUBDIR
cd $SUBDIR
lcd $FLAT
mirror -R -L --parallel=4 --verbose .
bye
LFTP
rc=${PIPESTATUS[0]}
echo "lftp exit code $rc"

echo
echo "== verify: exit code 0 and a correct file count are NOT enough =="
remote=$(mktemp); local=$(mktemp); trap 'rm -f "$remote" "$local"' EXIT
lftp "$HOST" <<LFTP 2>/dev/null | awk 'NF==2 {print $2"\t"$1}' | sort > "$remote"
user $GEOUSER $GEOPASS
set ftp:ssl-allow no
cd $SPACE/$SUBDIR
cls -s --block-size=1
bye
LFTP

if [ -f "$MANIFEST" ]; then
  tail -n +2 "$MANIFEST" | awk -F'\t' '{print $1"\t"$4}' | sort > "$local"
else
  find "$FLAT" -maxdepth 1 \( -type l -o -type f \) -exec bash -c \
    'printf "%s\t%s\n" "$(basename "$1")" "$(stat -Lc %s "$1" 2>/dev/null || stat -f %z "$1")"' _ {} \; | sort > "$local"
fi

printf '  remote files %s   local files %s\n' "$(wc -l < "$remote")" "$(wc -l < "$local")"
if diff -q "$local" "$remote" >/dev/null; then
  echo "  ALL FILES MATCH BYTE FOR BYTE"
  echo
  echo "Next: upload the metadata spreadsheet at"
  echo "  https://submit.ncbi.nlm.nih.gov/geo/submission/meta/"
  echo "Do NOT upload it by FTP."
else
  echo "  MISMATCH:" >&2; diff "$local" "$remote" | head -40 >&2
  echo "  Re-run this script - mirror re-sends only what is wrong." >&2
  exit 1
fi
