# Submitting sequencing data to NCBI GEO

A practical, command-line walkthrough of a GEO deposit — everything between
*"my FASTQ files are on a cluster"* and *"GEO emailed me an accession"*.

### 📖 **[Read the tutorial →](https://dayuan-wang.github.io/ncbi-geo-submission-tutorial/)**

---

Written after depositing a 479.5 GB, 173-file single-cell submission. GEO's own
documentation is accurate but terse, and it does not warn you about the three
mistakes that matter most — because in each case your tooling reports success
and the data is wrong:

| Mistake | What you see | What actually happened |
|---|---|---|
| Forgetting `-L` on `lftp mirror -R` | exit 0, correct file count | GEO received the symlinks — a few hundred bytes of path text instead of your reads |
| Running two upload jobs at once | exit 0, correct file count | files in flight in both jobs are truncated |
| Checking only file *count* after upload | "all 173 files are there" | count says nothing about size |

## What's here

```
index.html    the tutorial (published with GitHub Pages)
images/       redacted screenshots of the GEO submission pages
scripts/
  01-stage-flat-folder.sh    symlink everything into one flat folder, then verify
  02-md5-checksums.sh        md5 + gzip -t, writes a table you paste into the spreadsheet
  02b-md5-checksums.slurm    the same, as a cluster job, for large submissions
  03-ftp-upload.sh           upload with lftp and verify byte for byte
```

The scripts are generic — edit the config block at the top of each. They are
written to fail loudly rather than proceed on bad input.

## Scope

Aimed at high-throughput **sequencing** submissions (RNA-seq, scRNA-seq,
ChIP-seq and friends) uploaded from a Linux cluster or a Mac over the command
line. Microarray and Xenium submissions use different templates and are not
covered.

## Accuracy

GEO pages were read on **2026-09-08** — `seq.html` last modified 2026-08-24,
`submissionftp.html` 2026-09-02. GEO changes these without notice. **Their site
is authoritative**; this is a guide to what the steps actually involve. Numeric
limits quoted here (100 GiB per file, 5 TiB per subfolder, 1,000 samples per
spreadsheet) are especially worth re-checking — the SRA Data Submission
Standards were announced as taking effect at the end of 2026.

The incognito-window recommendation is operator experience, not GEO
documentation. You will not find it on their site.

## A note on credentials

Nothing in this repository contains an FTP password, a personal upload space
name, or an email address, and nothing should.

If you save or screenshot GEO's FTP instructions page while logged in, **that
file contains your live FTP password** and your personal upload space. GEO's own
warning, printed directly beneath the password:

> Do not share these log-in credentials. Do not include these log-in credentials
> on a public page. These credentials are changed regularly, as per our security
> policies.

The screenshots in `images/` have those regions blacked out. Redaction boxes were
placed from OCR-located coordinates, not by eye, and each image was checked
afterwards.

## Contributing

Corrections welcome, especially where GEO has changed something. Open an issue or
a pull request.

## License

[CC BY 4.0](LICENSE) — use it, adapt it, credit it.
