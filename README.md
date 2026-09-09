# PFAS Drinking-Water Exposure and Obesity-Related Health Outcomes — Feasibility Package (Texas)

**Phase:** Data feasibility and integration (Phase 1).
**Question:** How is community-level environmental PFAS exposure (EPA UCMR 5 drinking-water
monitoring) associated with obesity, diabetes and hypertension prevalence (CDC PLACES), and
does that relationship vary across communities and geography once socioeconomic context
(ACS) is accounted for?
**Unit of analysis:** ZIP Code Tabulation Area (ZCTA), 2020 vintage. Primary geography: Texas.

> **Interpretation guard-rail.** UCMR 5 measures PFAS in *public drinking-water systems*.
> Everything here is a **community-level environmental exposure proxy**, never an individual
> exposure or dose. All associations are **ecological and cross-sectional**. No causal claim
> is made or implied.

---

## How to reproduce

```bash
# 1. get the raw public data (no API keys needed; ~605 MB download)
bash scripts/download_raw.sh
bash scripts/verify_raw.sh          # optional: check bytes vs data/raw/CHECKSUMS.sha256

# 2. run the whole pipeline (~1 minute on a laptop)
Rscript scripts/run_all.R
```

Outputs land in `outputs/` (tables), `figures/` (maps + plots) and
`data/processed/` (the integrated datasets). `data/raw/` is never modified.

---

## Data availability

**Raw and processed data are not stored in git** (see `.gitignore`):

* `data/raw/` — ~605 MB of public downloads; `ucmr5/UCMR5_All.txt` alone is
  303 MB, above GitHub's 100 MB per-file limit. Rebuild with
  `bash scripts/download_raw.sh` (every file has a documented source URL) and
  verify byte-for-byte with `bash scripts/verify_raw.sh` against the pinned
  `data/raw/CHECKSUMS.sha256`. Provenance: `data/raw/README.md`.
* `data/processed/` — regenerated in ~40 s by `Rscript scripts/run_all.R`.

What *is* in git: all scripts, `outputs/` (result tables), `figures/`, and
`docs/` (data inventory, data dictionary, methodological memo, the HTML report).
A fresh clone reproduces every result from public sources.

**Frozen snapshot of the exact inputs** (EPA/CDC/Census occasionally repost
files): _[add archive link here once uploaded — e.g. a Zenodo DOI or a GitHub
Release asset; see "Publishing" below]_.

### R dependencies

Required: `data.table`, `dplyr`, `tidyr`, `stringr`, `readr`, `purrr`, `sf`, `ggplot2`.
Used if present: `spdep`, `spatialreg`, `MatchIt`, `spgwr`, `GWmodel`, `janitor`,
`viridis`, `patchwork`, `classInt`, `car`, `sandwich`.

```r
install.packages(c("data.table","dplyr","tidyr","stringr","readr","purrr","sf","ggplot2",
                   "spdep","spatialreg","MatchIt","spgwr","GWmodel","car","sandwich",
                   "janitor","viridis","patchwork","classInt"))
```

---

## Folder layout

```
PFAS-health-feasibility package/
├── README.md                    <- this file
├── data/
│   ├── raw/                     <- untouched public downloads (see data/raw/<src>/)
│   │   ├── ucmr5/               EPA UCMR 5 occurrence data
│   │   ├── places/              CDC PLACES ZCTA extract
│   │   ├── acs/                 ACS 2019-2023 table-based SF (ZCTA rows)
│   │   └── geo/                 Census boundaries + SDWIS system data
│   └── processed/               <- built by scripts; the analytical datasets
├── scripts/
│   ├── download_raw.sh          step 0: fetch all raw inputs
│   ├── 00_setup.R               paths, config, helper functions (sourced by all)
│   ├── 01_read_ucmr5.R          UCMR5 -> tidy analyte table + ZIP list
│   ├── 02_build_pfas_exposure.R 6 alternative PWS-level PFAS exposure measures
│   ├── 03_geography.R           ZCTA backbone + ZIP->ZCTA crosswalk + diagnostics
│   ├── 04_read_sdwis.R          population served, county, source type per PWS
│   ├── 05_read_places.R         PLACES -> wide (obesity/diabetes/hypertension)
│   ├── 06_read_acs.R            ACS -> conceptually chosen covariates
│   ├── 07_assemble_zcta_dataset.R  integrate everything -> Texas ZCTA dataset
│   ├── 08_linkage_summary.R     Deliverable C (linkage funnel)
│   ├── 09_descriptives.R        Deliverable E part 1 (descriptives + correlations)
│   ├── 10_maps.R                Deliverable D (maps)
│   ├── 11_spatial_autocorr.R    Deliverable E part 2 (Moran's I, LISA)
│   ├── 12_models.R              baseline OLS, spatial regression, PSM & GWR feasibility
│   ├── 13_build_report.R        assemble the self-contained HTML phase record
│   └── run_all.R                runs 01-13 in order
├── outputs/                     CSV tables + run log
├── figures/                     PNG maps and plots
└── docs/
    ├── data_inventory.csv       Deliverable A
    ├── data_dictionary.csv      original -> final variable mapping
    ├── methodological_memo.md   Deliverable F (plain-text source)
    ├── methodological_note_spatial_bayesian.md  proposed Phase 2/3 modelling
    │                            framework (spatial Bayesian confounding-sensitivity
    │                            analysis); summarised in report §H
    └── feasibility_report.html  SELF-CONTAINED complete Phase-1 record: what data exist
                                 and how they were obtained, the 14-script pipeline, every
                                 Phase-1 decision, deliverables A-F, all figures embedded,
                                 the full memo folded in, links to every file in the
                                 package, and a phase log for later phases
```

---

## Key processed datasets (`data/processed/`)

| file | rows | what it is |
|---|---|---|
| `ucmr5_results_long.(rds/csv)` | ~1.9 M | one row per PFAS analyte result, all US |
| `ucmr5_pws_exposure.(rds/csv)` | 10,312 | PWS-level PFAS exposure measures, all US |
| `zip_zcta_xwalk.(rds/csv)` | 31,429 | every UCMR5 PWS-ZIP pair with ZCTA match status |
| `places_zcta_wide.(rds/csv)` | 29,983 | PLACES obesity/diabetes/hypertension per ZCTA |
| `acs_zcta_covariates.(rds/csv)` | 33,772 | ACS covariates per ZCTA |
| **`texas_zcta_analytical.(gpkg/rds/csv)`** | **1,989** | **the integrated Texas ZCTA dataset (with geometry)** |
| `texas_zcta_lisa.(gpkg/rds/csv)` | 1,223 | primary sample + LISA cluster labels |
| `bexar_zcta_analytical.(gpkg/rds/csv)` | 70 | Bexar County / San Antonio subset |

Analytic-sample flags in `texas_zcta_analytical`: `pfas_exposure_available`,
`places_complete`, `acs_covar_complete`, `analytic_full`, **`analytic_primary`**
(n = 1,223 — PFAS linked + health + ACS + population ≥ 500).

---

## Headline feasibility findings (see the memo for detail)

1. **The pipeline works.** 1,154 Texas UCMR5 systems → 1,436 ZIP codes → 95.2 % match to
   ZCTAs → **1,223 Texas ZCTAs with complete PFAS + health + socioeconomic data.** That is
   an adequate sample for spatial statistical modelling.
2. **ZIP → ZCTA linkage is approximate**, and a PWS "ZIP codes served" list is not a service
   area. The many-to-many PWS ↔ ZCTA relation is the main data-quality limitation.
3. **PFAS exposure and disease burden are spatially separated in Texas.** Both are strongly
   spatially clustered (Moran's I ≈ 0.6–0.8), but PFAS hot-spots overlap obesity/diabetes/
   hypertension hot-spots in only a handful of ZCTAs.
4. **The unadjusted ecological association is negative** (more PFAS → *less* obesity/diabetes/
   hypertension) and is explained mostly by urbanicity and socioeconomic status. After
   adjustment the association is negligible (|standardised β| < 0.08, partial R² < 0.005).
5. **PSM is feasible but fragile** (large baseline imbalance, ~81 % common support,
   weighting does not fully balance). **GWR is feasible in principle but naïve GWR is
   unstable** here (bandwidth ≈ 14 neighbours, local coefficients from −176 to +251) — MGWR
   with constrained bandwidths is the right next step, not global GWR.
6. **Recommendation:** treat Texas as a validated methods testbed; expand the identical
   pipeline to the South-Central region or nationally to get the exposure contrast and
   spatial support that a single state cannot provide.
7. **Next-phase modelling** (`docs/methodological_note_spatial_bayesian.md`, report §H):
   a Bayesian hierarchical spatial model used as a **confounding-sensitivity analysis**
   (M0→M3 coefficient trajectory per outcome, focus on diabetes and hypertension), with
   explicit identification diagnostics and E-value / negative-control checks. Not a
   guaranteed causal estimate — the PFAS surface is so spatially autocorrelated
   (Moran's I 0.69–0.81) that the effect is only weakly identified, and improving the
   PWS→ZCTA exposure crosswalk outranks model sophistication.

---

## Publishing this repo

The repo is designed to push to GitHub cleanly (~16 MB) because `data/raw/` and
`data/processed/` are git-ignored. A collaborator clones it and runs
`download_raw.sh` + `run_all.R` to rebuild everything.

If you also want a **frozen, citable copy of the exact raw inputs** (recommended
for a paper — EPA/CDC/Census sometimes repost files):

* **Zenodo** — best for academic work: 50 GB per record, mints a DOI, and has a
  built-in GitHub integration (flip the switch, then publish a GitHub *Release*
  and Zenodo archives it automatically). Zip `data/raw/` (~430 MB compressed),
  upload, then paste the DOI into the "Frozen snapshot" line above.
* **GitHub Release asset** — attach `data_raw.zip` to a Release (2 GB per-file
  limit; not part of the git history, so it never bloats a clone).
  `gh release create v1.0-phase1 data_raw.zip -t "Phase 1 raw data snapshot"`.
* **Institutional / OSF / Dryad / Figshare** — also fine; link it from the README.

Do **not** use Git LFS for this: the free tier is 1 GB storage + 1 GB/month
bandwidth, which the 303 MB `UCMR5_All.txt` exhausts almost immediately.
