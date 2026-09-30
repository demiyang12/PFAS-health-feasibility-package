# Phase 2 — Exposure & Outcome Scoping

**Status: scoping and feasibility assessment. No new health-regression model has been run.**

Phase 1 (`../README.md`, `../docs/`) is a frozen, reproducible record and is **not**
modified by anything in this folder. Phase 2 is entirely additive.

**Live report:** https://demiyang12.github.io/PFAS-health-feasibility-package/phase2_report.html
(same content as [`docs/phase2_report.html`](docs/phase2_report.html); a copy also lives
at the repo's `docs/phase2_report.html` so the existing Pages config serves it with no
extra setup — see the root README's "Live report" section).

---

## Why Phase 2 exists

Phase 1's own conclusion, after building a full Texas ZCTA-level pipeline linking EPA
UCMR 5 drinking-water PFAS monitoring to CDC PLACES health outcomes and ACS covariates,
was:

> The main limitation is not sample size. The main limitation is exposure
> characterization and geographic assignment.

Phase 2 takes that conclusion seriously instead of immediately adding a more complex
statistical model to the same drinking-water-only exposure proxy. It asks, systematically
and before writing any new analysis code:

1. Can broader, spatially explicit PFAS environmental and source-related data improve
   community-level exposure characterization enough to support a narrower, more
   defensible research question?
2. Should the health outcome even stay the same (obesity/diabetes/hypertension), or do
   other candidates fit the available exposure data and biology better?

See [`docs/phase2_methodological_memo.md`](docs/phase2_methodological_memo.md) for the
full write-up, [`docs/exposure_data_inventory.csv`](docs/exposure_data_inventory.csv) and
[`docs/outcome_data_inventory.csv`](docs/outcome_data_inventory.csv) for the systematic
inventories behind it, and [`docs/decision_matrix.csv`](docs/decision_matrix.csv) /
[`docs/decision_log.md`](docs/decision_log.md) for how the recommended direction was
chosen.

---

## Folder layout

```
phase2/
├── README.md                       <- this file
├── data/
│   ├── raw/                        <- not stored in git; nothing pulled yet (scoping stage)
│   ├── interim/                    <- not stored in git
│   └── processed/                  <- not stored in git
├── docs/
│   ├── exposure_data_inventory.csv    17 candidate PFAS exposure/source-pressure datasets,
│   │                                  systematically evaluated (access, geography, years,
│   │                                  measured vs. modeled, linkage quality, limitations)
│   ├── outcome_data_inventory.csv     12 candidate health outcomes, evaluated the same way
│   ├── decision_matrix.csv            Directions A/B/C scored against a common criteria set
│   ├── decision_log.md                dated, append-only record of decisions made and why
│   ├── phase2_methodological_memo.md  the synthesis: what's strongest, what's excluded,
│   │                                   which direction is recommended, what's still needed
│   └── phase2_report.html             SELF-CONTAINED report built from everything above
│                                       (same design system as ../docs/feasibility_report.html)
├── scripts/
│   └── build_report.R                 builds docs/phase2_report.html (+ a copy in the
│                                       root docs/ for GitHub Pages) from the CSVs/memo
│                                       above; run from the project root. Data-pulling
│                                       scripts (01_exposure_inventory.R etc.) come once a
│                                       direction is confirmed - see "Current status" below
├── outputs/                        <- empty for now
└── figures/                        <- empty for now
```

Data policy mirrors the root project: `phase2/data/raw|interim|processed/` are
git-ignored (see the root `.gitignore`). Everything reproducible lives in `scripts/` once
written; `docs/`, `outputs/`, and `figures/` are tracked in git.

---

## Current status

This is the **first Phase 2 task**: inventory and scoping only, per the research team's
explicit instruction not to begin a final health-regression model yet. No download or
analysis code has been written, because no primary exposure/outcome pairing has been
confirmed yet — the only script so far builds the report from the hand-curated
inventories, it does not pull or process any new data. The recommended next step
(Direction C: exposure-assignment sensitivity, using data already in `data/` from
Phase 1) is in [`docs/phase2_methodological_memo.md`](docs/phase2_methodological_memo.md)
§3, with the specific follow-up checks needed before committing to it in §4.

Planned script numbering (not yet written): `00_setup.R`, `01_exposure_inventory.R`,
`02_outcome_inventory.R`, `03_spatial_coverage_assessment.R`, continuing from there once a
direction is confirmed. `build_report.R` will keep re-running at the end of that sequence
once it exists, the same way `13_build_report.R` closes out the root pipeline.

## Reproducibility

```bash
# from the project root, after editing any of the docs/*.csv or *.md files above
Rscript phase2/scripts/build_report.R
```

Regenerates `docs/phase2_report.html` and its copy in the root `docs/`. There is no
`download_raw.sh` equivalent yet — see "Current status" above for why.
