# Submitting data to NCBI GEO

A step-by-step guide to depositing high-throughput sequencing data in the NCBI
Gene Expression Omnibus, from files on a cluster to an accession number.

### **[Read the guide →](https://dayuan-wang.github.io/ncbi-geo-submission-tutorial/)**

---

GEO's own documentation is authoritative and worth reading alongside this guide.
This one covers what the steps involve in practice: getting an upload space,
what counts as raw and processed data, arranging files into the flat folder GEO
requires, the metadata spreadsheet, checksums, the FTP transfer, and the
web-side submission.

It is aimed at people preparing their first GEO submission for RNA-seq,
scRNA-seq, ChIP-seq or a similar sequencing assay, working from a Linux cluster
or a Mac. Microarray and spatial platforms use different templates and are not
covered.

## Accuracy

GEO revises its documentation without notice. Where this guide and GEO's site
disagree, GEO is correct. The numeric limits quoted here — 100 GiB per file,
5 TiB per subfolder, 1,000 samples per spreadsheet — are worth re-checking, as
the SRA Data Submission Standards were announced as taking effect at the end of
2026.

## Screenshots

The screenshots have account-identifying regions blacked out. If you save or
screenshot GEO's FTP instructions page while logged in, the resulting file
contains your live FTP password and your personal upload space name, so treat
those files accordingly.

## Contributing

Corrections are welcome, particularly where GEO has changed something. Open an
issue or a pull request.

## License

[CC BY 4.0](LICENSE).

Maintained by [Dayuan Wang](https://dayuan-wang.github.io/).
