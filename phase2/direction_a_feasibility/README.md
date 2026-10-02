# Direction A Feasibility Test

**Branch:** `Direction-A-feasibility-test` (off `phase-2-feasibility-assessment`)
**Status:** Six completed pilots (A1, A2, A3a, A3b, A3c, A4) plus a confounding-diagnostics
chain. Additive only — Phase 1 (`../../`), the original Phase 2 scoping deliverables
(`../docs/`), and the completed A1/A2 pilots are untouched by the A3/A4 additions in this folder.

**Start here:** [`docs/a3_direction_a_updated_memo.md`](docs/a3_direction_a_updated_memo.md)
— the current combined verdict across all six pilots. The original A1/A2-only verdict is
preserved at [`docs/direction_a_feasibility_memo.md`](docs/direction_a_feasibility_memo.md).
Individual pilot write-ups:
[`docs/a1_feasibility_summary.md`](docs/a1_feasibility_summary.md),
[`docs/a2_feasibility_summary.md`](docs/a2_feasibility_summary.md),
[`docs/a3a_feasibility_summary.md`](docs/a3a_feasibility_summary.md),
[`docs/a3b_feasibility_summary.md`](docs/a3b_feasibility_summary.md),
[`docs/a3c_feasibility_summary.md`](docs/a3c_feasibility_summary.md) (with the data-quality
investigation in [`docs/a3c_twdb_feasibility_note.md`](docs/a3c_twdb_feasibility_note.md)), the
[`docs/confounding_diagnostics_summary.md`](docs/confounding_diagnostics_summary.md) chain
(healthcare access, county-level structure, CDC PLACES methodology), and
[`docs/a4_feasibility_summary.md`](docs/a4_feasibility_summary.md).

A full narrative HTML covering all pilots is at
[`docs/direction_a_report.html`](docs/direction_a_report.html).

## What this branch tested

- **A1** — Phase 1's UCMR5/ZCTA PFAS exposure (unchanged) + CDC PLACES **high cholesterol**.
- **A2** — UCMR5 exposure rebuilt at **county** level (population-weighted) + Texas DSHS
  **low birth weight** (2019). Preterm birth was investigated but not completed — see
  `docs/a2_feasibility_summary.md`.
- **A3a** — sensitivity of A1's result to the PWS→ZCTA geographic-assignment *weighting rule*:
  rebuilds exposure under an equal-split population-weighted alternative applied to the SAME
  self-reported ZIP-code list, compares the two exposure surfaces, then reruns A1's exact
  cholesterol regression — see `docs/a3a_feasibility_summary.md`.
- **A3b** — whether independent source-pressure data (TRI reported PFAS release, Superfund
  NPL, NPDES) explains UCMR5's spatial pattern or changes A1's result. Measured concentration,
  reported release, and source/pathway indicators were kept strictly separate throughout — no
  composite PFAS score was created — see `docs/a3b_feasibility_summary.md`.
- **A3c** — the deeper question A3a identified but could not test: does replacing the
  self-reported ZIP-code list itself with a **real, mapped TWDB service-area polygon** change
  the exposure surface or the result? Also combines this improved exposure with A3b's
  source-pressure variables in one model — see `docs/a3c_feasibility_summary.md`.
- **Confounding diagnostics** — after A3a/A3b/A3c left the cholesterol association and its
  residual spatial autocorrelation unchanged, two confounding mechanisms were tested directly:
  healthcare access (ruled out — predicts the outcome but not the exposure) and county-level
  structure (confirmed — a within/between decomposition found the headline association is
  largely a between-county pattern, and CDC's own PLACES methodology documentation confirms the
  model includes county-level random effects) — see `docs/confounding_diagnostics_summary.md`.
- **A4** — does the between-county pattern survive a non-PLACES outcome? Reuses the identical
  PFAS exposure/covariates against CDC WONDER's death-certificate-based Ischaemic Heart Disease
  mortality (no survey, no small-area model). The effect disappears entirely (precise null) —
  see `docs/a4_feasibility_summary.md`.

No pilot is a final epidemiologic model: crude + one adjusted regression per outcome, a
residual Moran's I check, and descriptive maps/correlations only. No GWR/MGWR/PSM/Bayesian/ML/
causal/mediation methods were used, consistent with the task scope for this branch.

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

# A3a -- alternative geographic assignment
Rscript phase2/direction_a_feasibility/scripts/07_a3a_assignment_inventory.R
Rscript phase2/direction_a_feasibility/scripts/08_a3a_build_alternative_exposure.R
Rscript phase2/direction_a_feasibility/scripts/09_a3a_compare_exposure_surfaces.R
Rscript phase2/direction_a_feasibility/scripts/10_a3a_cholesterol_analysis.R

# A3b -- source-pressure context (downloads real TX data; the release-quantity
# step queries ~150 EPA Envirofacts documents sequentially and can take ~10-20
# minutes; it checkpoints to disk so an interrupted run resumes instead of
# restarting -- see the comments in the script)
Rscript phase2/direction_a_feasibility/scripts/12_a3b_download_source_data.R
Rscript phase2/direction_a_feasibility/scripts/11_a3b_source_data_inventory.R
Rscript phase2/direction_a_feasibility/scripts/13_a3b_build_source_indicators.R
Rscript phase2/direction_a_feasibility/scripts/14_a3b_spatial_comparison.R
Rscript phase2/direction_a_feasibility/scripts/15_a3b_cholesterol_analysis.R
Rscript phase2/direction_a_feasibility/scripts/16_a3_combined_comparison.R

# A3c -- real TWDB service-area polygons (spatial overlay) + combined with A3b context
Rscript phase2/direction_a_feasibility/scripts/17_a3c_download_twdb_service_areas.R
Rscript phase2/direction_a_feasibility/scripts/18_a3c_build_hybrid_exposure.R
Rscript phase2/direction_a_feasibility/scripts/19_a3c_compare_exposure_surfaces.R
Rscript phase2/direction_a_feasibility/scripts/20_a3c_cholesterol_analysis.R
Rscript phase2/direction_a_feasibility/scripts/21_a3_final_combined_comparison.R

# Confounding diagnostics -- downloads one new ACS table (health insurance)
Rscript phase2/direction_a_feasibility/scripts/22_confounding_check_healthcare_access.R
Rscript phase2/direction_a_feasibility/scripts/23_confounding_check_county_fixed_effects.R

# A4 -- CDC WONDER county mortality (NOTE: the raw pull itself is NOT scriptable --
# CDC WONDER's API explicitly forbids sub-national geography per NCHS policy; the raw
# text file was retrieved via the interactive web form, documented in the file itself
# and in docs/a4_feasibility_summary.md. These two scripts parse/analyze that file.)
Rscript phase2/direction_a_feasibility/scripts/24_a4_parse_wonder_mortality.R
Rscript phase2/direction_a_feasibility/scripts/25_a4_mortality_analysis.R

Rscript phase2/direction_a_feasibility/scripts/build_report.R   # -> docs/direction_a_report.html
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
│   │               a3b_source/  EPA TRI/NPL/NPDES raw pulls (script 12)
│   │               a3c_twdb/    TWDB service-area polygons, statewide (script 17)
│   │               acs/         ACS B27001 health insurance coverage (script 22)
│   │               a4_wonder/   CDC WONDER county IHD mortality, raw text (interactive pull)
│   ├── interim/    (unused so far)
│   └── processed/  RDS/CSV/GPKG analytic tables built by the scripts below
│                   (all data/ subfolders are git-ignored, same policy as the
│                   rest of this project -- see the root .gitignore)
├── scripts/
│   ├── 00_setup.R                        sources the ROOT Phase 1 setup; adds pilot paths
│   ├── download_raw_a.sh                 the 3 external A1/A2 pulls, documented + reproducible
│   ├── 01_a1_read_cholesterol.R          A1.1 -- verify PLACES cholesterol metadata
│   ├── 02_a1_analysis.R                  A1.2-A1.6 -- descriptives, maps, correlation, regression, Moran's I
│   ├── 03_a2_build_county_exposure.R     A2.2-A2.3 -- population-weighted county PFAS exposure + covariates
│   ├── 04_a2_read_birth_outcomes.R       A2.1 -- verify + read TX DSHS LBW; document PTB as not pulled
│   ├── 05_a2_analysis.R                  A2.5-A2.7 -- linkage funnel, descriptives, regression, Moran's I
│   ├── 06_compare_a1_a2.R                builds outputs/a1_a2_comparison_table.csv
│   ├── 07_a3a_assignment_inventory.R     A3a.1 -- inventory of realistic alternative assignment methods
│   ├── 08_a3a_build_alternative_exposure.R  builds the equal-split population-weighted exposure surface
│   ├── 09_a3a_compare_exposure_surfaces.R   A3a -- agreement/quartile-movement/hotspot comparison + 5 maps
│   ├── 10_a3a_cholesterol_analysis.R     reruns A1's exact regression with the alternative exposure
│   ├── 11_a3b_source_data_inventory.R    A3b.1 -- verified TX record counts (run AFTER script 12)
│   ├── 12_a3b_download_source_data.R     real TX pulls: TRI PFAS reporting, NPL, NPDES (checkpointed)
│   ├── 13_a3b_build_source_indicators.R  A3b.3 -- ZCTA-level distance/count/sum source indicators
│   ├── 14_a3b_spatial_comparison.R       A3b.4 -- UCMR5 vs. source-pressure correlation + 2x2 hotspot map
│   ├── 15_a3b_cholesterol_analysis.R     A3b.5 -- staged cholesterol models, one source family at a time
│   ├── 16_a3_combined_comparison.R       A1 vs. A3a vs. A3b comparison table (superseded by script 21)
│   ├── 17_a3c_download_twdb_service_areas.R  real TWDB service-area polygons, statewide (paginated ArcGIS REST pull)
│   ├── 18_a3c_build_hybrid_exposure.R    spatial overlay for 1,120 eligible PWS + Phase-1 fallback for 34
│   ├── 19_a3c_compare_exposure_surfaces.R   3-way (Phase1/A3a/A3c) agreement/hotspot comparison + 5 maps
│   ├── 20_a3c_cholesterol_analysis.R     reruns A1's regression with A3c exposure, alone and + A3b context
│   ├── 21_a3_final_combined_comparison.R final A1 vs. A3a vs. A3b vs. A3c comparison table
│   ├── 22_confounding_check_healthcare_access.R  tests uninsured rate as a confounder (ruled out)
│   ├── 23_confounding_check_county_fixed_effects.R  county FE/RE + within-between decomposition
│   ├── 24_a4_parse_wonder_mortality.R    parses the CDC WONDER county IHD mortality pull
│   ├── 25_a4_mortality_analysis.R        negative-binomial regression vs. the PLACES-based finding
│   └── build_report.R                    builds docs/direction_a_report.html (the full narrative)
├── outputs/        53 CSV tables (diagnostics, regressions, the funnel, the comparison tables)
├── figures/        18 PNG maps/plots
└── docs/
    ├── a1_places_metadata.csv                verified (not assumed) PLACES cholesterol metadata
    ├── a2_birth_outcome_metadata.csv         verified TX DSHS source details
    ├── a3a_assignment_methods_inventory.csv  A3a.1 -- candidate assignment methods, decisions + rationale
    ├── a3b_source_inventory_verified.csv     A3b.1 -- verified TX source-pressure dataset inventory
    ├── a3b_tri_pfas_chemical_list.csv        the 196 TRI chemicals flagged pfas_ind=1
    ├── a3c_twdb_feasibility_note.md          TWDB data-quality investigation (incl. a correction)
    ├── a1_feasibility_summary.md             answers to the A1.7 interpretation questions
    ├── a2_feasibility_summary.md             answers to the A2.8 interpretation questions
    ├── a3a_feasibility_summary.md            answers to the A3a.6 interpretation questions
    ├── a3b_feasibility_summary.md            answers to the A3b.7 interpretation questions
    ├── a3c_feasibility_summary.md            answers to the A3c interpretation questions
    ├── confounding_diagnostics_summary.md    healthcare access / county structure / PLACES methodology
    ├── a4_feasibility_summary.md             CDC WONDER mortality vs. the PLACES-based finding
    ├── direction_a_feasibility_memo.md       original combined verdict (A1 + A2 only; preserved as-is)
    ├── a3_direction_a_updated_memo.md        current combined verdict (A1-A4) -- start here
    └── direction_a_report.html               full narrative HTML built from everything above
```

## What was deliberately NOT done (per the task scope for this branch)

- No search across many outcomes to find a significant one — cholesterol and LBW/preterm
  birth were the pre-specified candidates; A4's Ischaemic Heart Disease was chosen as the
  single most literature-motivated downstream endpoint of elevated cholesterol, not selected
  by trying several causes of death and reporting the one that moved.
- No GWR, MGWR, PSM, Bayesian, machine-learning, causal, or mediation methods.
- No composite multi-source PFAS exposure score. A3b kept measured concentration (UCMR5),
  reported release (TRI), and source/pathway indicators (NPL, NPDES) as strictly separate
  variables throughout — never summed or combined into a single index.
- No causal claims.
- Suppressed birth-outcome cells (A2) and suppressed county-level mortality cells (A4, 12 of
  254 Texas counties) were **excluded**, never imputed as zero.
- County and ZCTA outcomes were never mixed in the same regression.
- A3a, A3b, and A3c changed only the exposure representation or added parallel context — the
  cholesterol outcome, covariates, analytic sample (±11 ZCTA for A3c, documented), and spatial
  weights are byte-for-byte identical to A1's throughout, so any difference in the result is
  attributable to the exposure/context change alone.
- A3c's 34 systems without a usable TWDB polygon were not dropped — they fall back to Phase 1's
  original ZIP-based assignment, documented in `outputs/a3c_eligibility_funnel.csv`.
- Phase 1, the original Phase 2 decision matrix, and the completed A1/A2 pilot files/docs
  were not modified.
