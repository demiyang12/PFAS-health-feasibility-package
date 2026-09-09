# `data/raw/` — public source data (not stored in git)

These files are **not** committed to the repository (~605 MB total, and
`ucmr5/UCMR5_All.txt` alone is 303 MB, above GitHub's 100 MB per-file limit).
They are also **read-only inputs** — nothing in the pipeline modifies them.

## How to get them

```bash
bash scripts/download_raw.sh      # fetches everything below; no API keys
bash scripts/verify_raw.sh        # checks every file against CHECKSUMS.sha256
```

`download_raw.sh` is self-contained: every file has a documented source URL
and it can be re-run at any time. Retrieved for this package on **2026-09-07**.

## What lands here

| Sub-folder | Source | Files |
|---|---|---|
| `ucmr5/` | EPA UCMR 5 occurrence data (2023-08 posting), `ucmr5-occurrence-data.zip` | `UCMR5_All.txt`, `UCMR5_ZIPCodes.txt`, `UCMR5_AddtlDataElem.txt`, 2 PDFs |
| `places/` | CDC PLACES 2025 release, ZCTA (Socrata `qnzd-25i4`) | `places_zcta_3measures.csv` |
| `acs/` | US Census ACS 2019–2023 5-year, table-based Summary File (ZCTA rows only) | `acs_b0*/b1*/b2*_zcta.psv`, `ACS20235YR_Table_Shells.txt` |
| `geo/` | Census cartographic boundaries (GENZ2020 ZCTA, GENZ2022 county/state), 2020 ZCTA↔county relationship file, EPA SDWIS/Envirofacts (TX) | shapefiles, `zcta_county_rel_2020.txt`, `ws_tx_*.csv`, `ga_tx_*.csv` |

## Reproducibility note

EPA and CDC occasionally repost these datasets. `CHECKSUMS.sha256` pins the
exact bytes used for this analysis. If `verify_raw.sh` reports a mismatch, the
upstream file has changed — record the new checksum and note the change in
`docs/methodological_memo.md` before rerunning.

For a frozen citable copy of these exact inputs, see the archive link in the
top-level `README.md` (§ Data availability).
