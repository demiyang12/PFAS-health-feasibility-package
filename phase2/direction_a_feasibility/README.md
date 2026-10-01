# Direction A Feasibility Test

**Branch:** `Direction-A-feasibility-test` (off `phase-2-feasibility-assessment`)
**Status:** Two completed pilots (A1, A2). Additive only — Phase 1 (`../../`) and the
original Phase 2 scoping deliverables (`../docs/`) are untouched by anything in this folder.

**Start here:** [`docs/direction_a_feasibility_memo.md`](docs/direction_a_feasibility_memo.md)
— the combined verdict. Individual pilot write-ups:
[`docs/a1_feasibility_summary.md`](docs/a1_feasibility_summary.md) and
[`docs/a2_feasibility_summary.md`](docs/a2_feasibility_summary.md).

## What this branch tested

- **A1** — Phase 1's UCMR5/ZCTA PFAS exposure (unchanged) + CDC PLACES **high cholesterol**.
- **A2** — UCMR5 exposure rebuilt at **county** level (population-weighted) + Texas DSHS
  **low birth weight** (2019). Preterm birth was investigated but not completed — see
  `docs/a2_feasibility_summary.md`.

Neither pilot is a final epidemiologic model: crude + one adjusted regression per outcome,
a residual Moran's I check, and descriptive maps/correlations only. No GWR/MGWR/PSM/Bayesian/
ML methods were used, consistent with the task scope for this branch.

## How to reproduce

```bash
# from the project root
bash phase2/direction_a_feasibility/scripts/download_raw_a.sh   # 3 keyless public pulls
Rscript phase2/direction_a_feasibility/scripts/01_a1_read_cholesterol.R
Rscript phase2/direction_a_feasibility/scripts/02_a1_analysis.R
Rscript phase2/direction_a_feasibility/scripts/03_a2_build_county_exposure.R
Rscript phase2/direction_a_feasibility/scripts/04_a2_read_birth_outcomes.R
Rscript phase2/direction_a_feasibility/scripts/05_a2_analysis.R
Rscript phase2/direction_a_feasibility/scripts/06_compare_a1_a2.R
```

Requires the root Phase 1 pipeline to have been run at least once already
(`Rscript scripts/run_all.R` from the project root) — these scripts reuse Phase 1's
processed ZCTA dataset (`data/processed/texas_zcta_analytical.rds`) directly rather than
rebuilding it.

## Folder layout

```
direction_a_feasibility/
├── README.md                              <- this file
├── data/
│   ├── raw/        places/      CDC PLACES high-cholesterol ZCTA pull
│   │               geo/         Geocorr 2022 TX ZCTA<->county population crosswalk
│   │               tx_dshs/     TX DSHS Vital Statistics Annual Report Table 10 (2017-2019)
│   ├── interim/    (unused so far)
│   └── processed/  RDS/CSV/GPKG analytic tables built by the scripts below
│                   (all three data/ subfolders are git-ignored, same policy as the
│                   rest of this project -- see the root .gitignore)
├── scripts/
│   ├── 00_setup.R                     sources the ROOT Phase 1 setup; adds pilot paths
│   ├── download_raw_a.sh              the 3 external pulls, documented + reproducible
│   ├── 01_a1_read_cholesterol.R       A1.1 -- verify PLACES cholesterol metadata
│   ├── 02_a1_analysis.R               A1.2-A1.6 -- descriptives, maps, correlation, regression, Moran's I
│   ├── 03_a2_build_county_exposure.R  A2.2-A2.3 -- population-weighted county PFAS exposure + covariates
│   ├── 04_a2_read_birth_outcomes.R    A2.1 -- verify + read TX DSHS LBW; document PTB as not pulled
│   ├── 05_a2_analysis.R               A2.5-A2.7 -- linkage funnel, descriptives, regression, Moran's I
│   └── 06_compare_a1_a2.R             builds outputs/a1_a2_comparison_table.csv
├── outputs/        ~20 CSV tables (diagnostics, regressions, the funnel, the comparison table)
├── figures/        8 PNG maps/plots
└── docs/
    ├── a1_places_metadata.csv         verified (not assumed) PLACES cholesterol metadata
    ├── a2_birth_outcome_metadata.csv  verified TX DSHS source details
    ├── a1_feasibility_summary.md      answers to the A1.7 interpretation questions
    ├── a2_feasibility_summary.md      answers to the A2.8 interpretation questions
    └── direction_a_feasibility_memo.md  combined verdict + key comparison table
```

## What was deliberately NOT done (per the task scope for this branch)

- No search across many outcomes to find a significant one — cholesterol and LBW/preterm
  birth were the pre-specified candidates.
- No GWR, MGWR, PSM, Bayesian, or machine-learning methods.
- No composite multi-source PFAS exposure score, and TRI/Superfund/AFFF site data were not
  touched or treated as individual exposure.
- No causal claims.
- Suppressed birth-outcome cells were **excluded**, never imputed as zero.
- County and ZCTA outcomes were never mixed in the same regression.
- Phase 1 and the original Phase 2 decision matrix were not modified.
