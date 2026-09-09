# Methodological Memo — PFAS Drinking-Water Exposure and Obesity-Related Health Outcomes

**Feasibility Phase 1 · Geographic testbed: Texas · Unit: ZIP Code Tabulation Area (ZCTA, 2020)**
**Prepared:** 2026-09-07 · **Analyst:** Yuqing · All code in `scripts/`, all numbers reproducible via `Rscript scripts/run_all.R`

---

## 0. One-paragraph summary

The integration pipeline EPA UCMR 5 → public water systems → ZIP/ZCTA → CDC PLACES → ACS
**works end to end and yields 1,223 Texas ZCTAs** with complete PFAS-exposure, health-outcome
and socioeconomic data, covering **95.7 % of the state's ZCTA population**. That is a workable
sample for spatial modelling. However, three substantive findings shape what should come next:
(1) the ZIP-to-ZCTA link is an approximation and a water system's "ZIP codes served" is not a
service-area boundary; (2) in Texas, PFAS drinking-water exposure and chronic-disease burden
are **spatially clustered but in different places**, and the raw ecological association is
*negative* and driven by urbanicity/socioeconomic status; (3) after covariate adjustment the
PFAS–outcome association is negligible (|standardised β| < 0.08, partial R² < 0.005).
Propensity-score methods are feasible but fragile, and naïve GWR is unstable at the bandwidth
the data select. **Recommendation: keep Texas as a validated methods testbed and expand the
same workflow regionally/nationally to obtain adequate exposure contrast and spatial support.**

---

## 1. What data are available

| Component | Source / version | Scale | Texas coverage |
|---|---|---|---|
| PFAS exposure | **EPA UCMR 5** occurrence data, 2023-08 posting (retrieved 2026-09-07) | Public Water System (PWS) & sampling point | **1,154 PWS**, 217,942 PFAS analyte-results, 29 PFAS compounds |
| PWS characteristics | **EPA SDWIS** (Envirofacts REST API) | PWS | 1,154 / 1,154 matched (100 %); population-served present for all |
| Health outcomes | **CDC PLACES 2025 release**, ZCTA file (`qnzd-25i4`); BRFSS 2023 model-based crude prevalence | ZCTA5 | 1,935 of 1,989 Texas ZCTAs have obesity + diabetes + hypertension estimates |
| Socioeconomic context | **ACS 2019–2023 5-year**, table-based Summary File (11 tables, ZCTA rows) | ZCTA5 | ~1,950 Texas ZCTAs with the core covariate set |
| Geography | Census 2020 ZCTA cartographic boundaries; 2020 ZCTA↔county relationship file; 2022 county/state boundaries | ZCTA5 / county | 1,989 Texas ZCTAs |

All inputs are **public and key-free**. The Census Data API now requires a key, so ACS is
pulled from the *table-based Summary File* instead of `tidycensus` — slightly more code, zero
credentials, fully reproducible. Full details, URLs and access methods: `docs/data_inventory.csv`.

**PFAS detections in Texas (systems with ≥ 1 detection):** PFBA 553, PFPeA 426, PFHxA 374,
PFBS 284, PFHxS 152, PFOS 98, PFOA 40, 6:2 FTS 53, PFHpA 39; PFNA 3; **HFPO-DA (GenX) 0**.
106 Texas systems detected PFOA and/or PFOS at least once. Nationally, 34.9 % of UCMR 5
systems had a PFAS detection.

**Six alternative exposure measures** are constructed at PWS level and aggregated to ZCTA
(`scripts/02`, `scripts/07`): (1) any PFAS detected; (2) number of PFAS compounds detected;
(3) concentration of individual major compounds (PFOA, PFOS, PFHxS, PFNA, …); (4) summed
PFAS concentration (ND = 0, plus an ND = MRL/2 sensitivity version); (5) an EPA-2024
**Hazard Index** mixture metric (PFHxS, HFPO-DA, PFNA, PFBS); (6) detection frequency. No
single definition is fixed yet — this is a menu to be narrowed during the modelling phase.

---

## 2. How the datasets link

```
UCMR5_All.txt (PWSID, analyte, result)
      │  aggregate 2–4 sample events per PWS
      ▼
PWS-level PFAS exposure (10,312 US / 1,154 TX systems)
      │  UCMR5_ZIPCodes.txt: PWSID → ZIP served      (many-to-many)
      ▼
ZIP codes  ──exact 5-digit match──▶  2020 Census ZCTA        (95.2 % of TX ZIPs match)
      │  a ZCTA can be reached by several PWS → population-served-weighted aggregation
      ▼
Texas ZCTA  ──join──▶  CDC PLACES outcomes  ──join──▶  ACS covariates  +  geometry
      ▼
texas_zcta_analytical  (1,989 rows; 1,223 in the primary analytic sample)
```

The join keys are clean: PWSID links UCMR 5 ↔ SDWIS ↔ the ZIP file with no fuzzy matching;
ZCTA5 links the ZIP crosswalk ↔ PLACES ↔ ACS ↔ boundaries exactly. The **only** approximate
step is ZIP → ZCTA (Section 3).

**PFAS → ZCTA aggregation rule.** For ZCTA *z*, take every Texas UCMR 5 PWS whose
served-ZIP list contains a ZIP equal to *z*; aggregate their PWS-level measures weighted by
SDWIS `population_served_count`. Binary measures use "any serving system" (OR) and a
population-weighted share; continuous measures use the population-weighted mean.

---

## 3. Major data-quality and geographic-linkage limitations

1. **"ZIP codes served" ≠ service area.** UCMR 5 lists the ZIP codes a system reports serving.
   This is an unordered list, not a polygon and not population-weighted. A large system
   (e.g. a metro utility) may list dozens of ZIPs; the monitoring result is a single
   entry-point or distribution value that is then attributed to *all* of them equally.

2. **ZIP ↔ ZCTA is approximate.** 95.2 % of Texas PWS ZIP codes match a 2020 ZCTA of the
   same code (`outputs/linkage_zip_zcta_notes.csv`). The ~5 % that do not are mostly
   PO-box / single-building "point" ZIPs. ZCTAs are also not nested in ZIPs: boundaries
   differ, and 689 of 1,989 Texas ZCTAs straddle a county line.

3. **Many-to-many PWS ↔ ZCTA.** In the primary sample 670 ZCTAs are served by exactly one
   UCMR 5 system and 553 by more than one (up to 19). Where multiple systems serve a ZCTA
   their results are blended; where one system serves many ZCTAs that result is copied across
   them, inducing **spatial autocorrelation by construction** — relevant when interpreting
   Moran's I on the exposure surface.

4. **Population-served is a system total, not the ZCTA share.** SDWIS does not publish how
   many people a system serves *inside a given ZCTA*, so the weight is the system's overall
   size. This is a reasonable relative weight but not an exposure headcount.

5. **UCMR 5 is a partial census of systems.** It covers all large systems (> 10,000 people)
   plus a nationally representative sample of small systems. Small-system coverage in any
   one state is therefore incomplete and **non-random with respect to size** — rural Texas
   is under-represented among monitored ZCTAs (visible as grey gaps in `figures/map_1`).

6. **PLACES outcomes are modelled, not measured.** They are BRFSS-based small-area estimates
   (multilevel regression + poststratification). ZCTA files carry **crude** prevalence only
   and the CDC explicitly warns against using them for program/policy evaluation. The
   95 % CI width is retained as a per-ZCTA precision flag (`*_ci_width`).

7. **Ecological + cross-sectional.** UCMR 5 sampling (2023–2025), BRFSS (2023) and ACS
   (2019–2023) are contemporaneous but the design cannot separate compositional from
   contextual effects, and PFAS in tap water today is a poor proxy for the multi-decade,
   multi-route exposure that matters biologically. Drinking water is one route; diet and
   consumer products are not captured at all.

8. **Non-detects.** 96 % of Texas PFAS results are below the MRL. The primary rule is
   ND = 0; an ND = MRL/2 sensitivity variable is provided. Formal left-censored methods
   (e.g. Kaplan–Meier / MLE, or Tobit at the ZCTA stage) are deferred to the modelling phase.

---

## 4. Does Texas provide a sufficient sample for spatial modelling?

**Sample size: yes.** The integration funnel (`outputs/linkage_summary.csv`):

| Step | N |
|---|---|
| UCMR 5 public water systems in Texas | 1,154 |
| … with ≥ 1 PFAS detection | 622 |
| … with an EPA MCL / Hazard-Index exceedance | 19 |
| Distinct ZIP codes served | 1,436 |
| … matched to a 2020 ZCTA | 1,322 |
| Distinct Texas ZCTAs reached by ≥ 1 system | 1,321 |
| … also with complete PLACES outcomes | 1,304 |
| … also with complete ACS covariates | 1,264 |
| … also population ≥ 500 → **primary analytic sample** | **1,223** |

1,223 ZCTAs (95.7 % of Texas ZCTA population; 28.4 M residents) is comfortably enough for
global and spatial regression.

**Spatial support: partial.** Because the sample is restricted to monitored ZCTAs, it is
spatially **gappy** — queen-contiguity weights fragment into ~28 disconnected sub-graphs.
The pipeline therefore uses **k = 6 nearest-neighbour weights** as the primary spatial
specification (queen contiguity retained for sensitivity). Global Moran's I
(`outputs/morans_i_global.csv`, k = 6 NN):

| Layer | Moran's I | p |
|---|---|---|
| PFAS Hazard Index | 0.69 | ≈ 0 |
| PFAS detection frequency | 0.81 | ≈ 0 |
| Obesity | 0.50 | ≈ 0 |
| Diabetes | 0.55 | ≈ 0 |
| Hypertension | 0.56 | ≈ 0 |
| SES-vulnerability index | 0.14 | 4×10⁻²³ |

Everything is strongly clustered, so **non-spatial regression is not defensible**: the naïve
OLS for obesity has residual Moran's I = 0.49 (p ≈ 10⁻²⁵²).

**But exposure and outcomes cluster in different places.** LISA (`outputs/lisa_summary.csv`):
105 ZCTAs are PFAS "High-High" hot-spots; 165 are obesity hot-spots, 160 diabetes, 201
hypertension. The **overlap of a PFAS hot-spot with a disease hot-spot is 3 ZCTAs for obesity
and 0 for diabetes and hypertension**, and there are **no** ZCTAs that are simultaneously
High-High on PFAS, a disease and SES vulnerability. PFAS hot-spots sit in the DFW metroplex,
Midland–Odessa and parts of the Houston/Austin/San Antonio corridors; disease hot-spots sit
in rural East and South Texas and low-income urban cores.

**Bexar County / San Antonio:** 68 ZCTAs enter the primary sample, but only ~4 of the ~26
UCMR 5 systems linked to Bexar had any PFAS detection and none had an MCL/HI exceedance.
Bexar is usable as a descriptive case study but **too small and too low-contrast for a
stand-alone spatial model.**

---

## 5. Is propensity-score analysis feasible?

**Conditionally.** Defining "higher exposure" as the top quartile of the ZCTA Hazard Index
gives 306 treated vs 917 control ZCTAs (`outputs/psm_feasibility.csv`).

- **Overlap / common support:** ~81 % of ZCTAs fall in the shared propensity range; the
  treated propensity range (0.045–0.719) sits inside the control range (0.002–0.736). Usable
  but not generous.
- **Baseline imbalance is large:** max |SMD| = 0.87 (driven by surface-water reliance,
  population density, % over 65, mobile-home share) — treated and control ZCTAs are
  systematically different kinds of places.
- **IPW does not fix it:** max |SMD| after weighting is still 0.47 (target < 0.1).
- **1:1 caliper matching does balance observed covariates** (mean |SMD| = 0.04) but discards
  ~2 % of treated units and, more importantly, cannot address unobserved confounders
  (industrial history, water-utility investment, healthcare access).

So PSM is worth doing as a **robustness/triangulation** analysis, not as the primary design.
The exposure "treatment" is itself partly a function of *water-system type* (surface vs
ground water), which is a mediator, not a pre-treatment covariate — the exposure-group
definition needs care. **The honest conclusion is that observable-confounding adjustment is
possible but the residual-confounding risk in this ecological setting is high.**

---

## 6. Is GWR / MGWR feasible?

**GWR runs; naïve GWR is not trustworthy here.** With n = 1,223 and a median
nearest-neighbour spacing of 8.3 km, `spgwr::gwr` selects an adaptive bandwidth of ~1.2 % of
N (≈ 14 neighbours). At that bandwidth (`outputs/gwr_feasibility.csv`):

- model fit improves sharply (GWR AICc 4,240 vs OLS AIC 5,409) — there *is* spatial
  non-stationarity;
- but the local PFAS→obesity coefficient ranges from **−176 to +251** (IQR 7.2), i.e. the
  coefficient surface is dominated by local collinearity and small-sample noise, not signal.

This is a classic small-bandwidth over-fit. The appropriate response is **MGWR** (each
covariate gets its own bandwidth, so the slow-varying SES surface is not forced to the same
scale as noise) together with a **fixed minimum bandwidth**, and comparison against the
spatial-lag / spatial-error models, which already fit well:
spatial-error λ = 0.4–0.8, and they cut AIC by 200–650 points versus OLS
(`outputs/spatial_models.csv`). **Recommend: spatial-error/lag models as the workhorse; MGWR
as the heterogeneity probe; drop global GWR.**

---

## 7. Recommendations for the next phase

1. **Geography.** Keep Texas as the *validated pipeline*, but **expand to a multi-state region
   (EPA Region 6, or the South) or nationally** before modelling in earnest. A single state
   gives too little exposure contrast (19 ZCTAs with an MCL/HI exceedance) and too gappy a
   spatial field. The scripts are already state-agnostic — change `CFG$study_state_*` and
   the ACS/PLACES pulls are national.
2. **Exposure definition.** Carry forward **three** measures into modelling —
   `pfas_any_detect` (robust, interpretable), `pfas_hazard_index` (regulatory, mixture) and
   `pfas_n_detected` — and report all three in every model rather than choosing one. Rescale
   concentration variables per IQR. Add a proper left-censored treatment of non-detects.
3. **Linkage.** Upgrade ZIP → ZCTA from exact-match to a crosswalk with areal/population
   weights (HUD USPS crosswalk or UDS Mapper), and where a system's boundary is available
   (state PWS service-area GIS, EPA's forthcoming service-area layer) use it. Quantify the
   sensitivity of results to the linkage method.
4. **Confounding.** Pre-register the covariate set as a DAG (income, education, race/
   ethnicity, age structure, urbanicity, housing vintage) and keep water-system type as an
   exposure *descriptor*, not a confounder. Add contextual layers that plausibly drive both
   exposure and monitoring: proximity to airports / military bases / industrial NPDES sites.
5. **Models.** OLS (3 exposure defs × 3 outcomes) → spatial-error/lag → MGWR for
   heterogeneity → PSM as triangulation. Report residual spatial autocorrelation for every
   model.
6. **Framing.** The Texas result — strong spatial structure, near-zero adjusted association,
   spatial separation of exposure and disease — is itself a publishable methodological point
   about **why ecological PFAS–obesity studies are hard** and why a follow-up individual-level
   biological-sample study is necessary. Phase 1 is the foundation for that.
7. **Open methodological questions still to resolve.**
   (a) final geographic scope (Texas vs Region 6 vs national);
   (b) whether to model prevalence directly or logit-transformed with CI-width weights;
   (c) how to define the PFAS "treatment" for PSM given that source-water type is entangled
   with exposure;
   (d) whether MNP context layers should be scaffolded into the pipeline now for later use.

---

### Files behind this memo

`outputs/`: `linkage_summary*.csv`, `descriptives_primary.csv`, `correlations_pfas_outcomes.csv`,
`correlation_matrix_full.csv`, `pfas_by_svi_tertile.csv`, `morans_i_global.csv`,
`lisa_summary.csv`, `ols_models.csv`, `spatial_models.csv`, `psm_feasibility.csv`,
`psm_balance_table.csv`, `gwr_feasibility.csv`, `run_all_log.txt`.
`figures/`: `map_1`–`map_7`, `map_lisa_*`, `fig_corr_heatmap`, `fig_pfas_outcome_scatter`,
`fig_psm_overlap`, `fig_gwr_pfas_coef`.
`data/processed/texas_zcta_analytical.gpkg` — the integrated dataset.
