# Methodological Note — Spatial Bayesian Confounding-Sensitivity Analysis (proposed Phase 2/3)

**Project:** PFAS Drinking-Water Exposure and Obesity-Related Health Outcomes
**Geographic unit:** ZIP Code Tabulation Area (ZCTA, 2020)
**Status:** *Proposed* Phase 2/3 methodological extension. Not a completed causal
analysis. Everything in Phase 1 remains ecological, cross-sectional and exploratory.

---

## 0. Summary

Phase 1 leaves a specific analytic question: the adjusted PFAS–health associations in
Texas are small and mostly **negative**, and the sign for obesity **reverses** when
spatial dependence is modelled explicitly. The proposed extension is a **Bayesian
hierarchical spatial model used as a confounding-sensitivity analysis** — a structured
way to see how the PFAS coefficient moves as measured-confounder, spatial-confounder and
uncertainty assumptions are layered in.

Three things must be stated before, not after, the modelling:

1. **This is not automatically a causal model.** A Bayesian spatial regression becomes a
   causal estimate only under a pre-specified causal structure (DAG), no-unmeasured-
   confounding, positivity and consistency — assumptions this ecological design can
   *probe* but cannot *satisfy*.
2. **Identification here is weak.** The PFAS exposure surface is as spatially smooth as
   the health outcomes (Global Moran's I ≈ 0.69–0.81 for PFAS vs 0.55–0.58 for the
   outcomes). An exposure that smooth is nearly collinear with any flexible spatial
   random effect, so the PFAS effect `τ` is only identified by the *spatially
   unstructured* part of exposure — which, with 96 % non-detects and a PWS→ZIP→ZCTA
   copy-allocation, is largely noise and construction artefact. `τ` will lean heavily
   on the smoothness prior.
3. **Data work comes first.** Improving the exposure geography (population/area-weighted
   PWS→ZCTA crosswalk; service-area GIS where available) and expanding beyond Texas for
   exposure contrast are higher-priority prerequisites than model sophistication.

Given (1)–(3), the honest label for this work is a **spatial confounding-sensitivity
analysis**, not a "Spatial Bayesian Causal Model". It is worth doing, framed that way.

---

## 1. The motivating puzzle

For obesity, with `A = log(1 + Hazard Index)` (`outputs/spatial_models.csv`,
`outputs/ols_models.csv`):

| Model | PFAS coefficient (obesity) | note |
|---|---|---|
| Adjusted OLS | **−0.62** | p ≈ 0.14, standardised β ≈ −0.018 — **already ~null** |
| Spatial error (SEM, λ ≈ 0.79) | **+0.59** | sign reversal |
| Spatial lag (SAR, ρ ≈ 0.41) | +0.30 raw β; **total impact +0.51** | compare *total impacts*, not raw β |

The sign reversal is **not** consistent across outcomes:

| Outcome | Adjusted OLS β | SEM β | SAR total impact |
|---|---|---|---|
| Obesity | −0.62 (~null) | +0.59 | +0.51 |
| Diabetes | −1.13 | −0.79 | −0.73 |
| Hypertension | −2.89 | −2.16 | −2.40 |

Two consequences for the design:

- **Obesity is a weak target.** Its OLS association is statistically indistinguishable
  from zero; a "sign flip" of a null coefficient is not informative on its own.
- **Diabetes and hypertension are the real puzzle.** Their negative associations are
  larger and **survive** the spatial models. The confounding-sensitivity analysis
  should be built around these two.

The correct conclusion from Phase 1 is *not* "a spatial model shows the true effect is
positive". It is "the estimate is sensitive to how spatial dependence is modelled, and
that sensitivity has to be investigated explicitly."

---

## 2. Why the identification is fragile (read before Section 4)

`spdep`/Phase 1 Global Moran's I, k = 6 nearest-neighbour weights
(`outputs/morans_i_global.csv`):

| Layer | Moran's I |
|---|---|
| PFAS detection frequency | 0.81 |
| PFAS # compounds detected | 0.74 |
| PFAS Hazard Index | 0.69 |
| Hypertension / Diabetes / Obesity | 0.56 / 0.55 / 0.58 |
| Median household income | 0.48 |
| SES-vulnerability index | 0.14 |

The exposure is **more spatially autocorrelated than the outcomes and than most
covariates**. In the joint model of Section 4, the PFAS term and the outcome's spatial
random effect `U^Y` compete for the same smooth spatial variation. `τ` is then
identified only by:

- exposure variation that is **not** spatially smooth (the `ε^A` term), and
- the **parametric smoothness assumption** on `U^Y` (how much wiggliness the spatial
  prior allows).

With 96 % of PFAS results below the reporting limit and the exposure surface partly
built by copying one PWS value across many ZIP/ZCTAs, the non-smooth exposure variation
is thin and partly artefactual. **Practical implication:** report `τ` with an explicit
identification-diagnostic panel —

- prior-sensitivity analysis on the spatial precision / smoothness hyperparameter;
- comparison of the estimated spatial scale of `A` vs `U^Y` (if similar, `τ` is not
  separately identified);
- a `Spatial+` / spectral-adjustment check (Dupont et al. 2022; Guan et al. 2023);
- restricted spatial regression (Reich, Hodges & Zadnik 2006; Hodges & Reich 2010) as a
  contrast — adding a spatial random effect can *inflate variance and bias* the
  coefficient of a spatially structured covariate.

If these diagnostics show `τ` is prior-driven, the result is reported as
"non-identified with the current exposure data", which is itself a useful finding.

---

## 3. Why propensity-score matching is not the primary design

Keep PSM / generalized propensity score (GPS) as **triangulation**, for three reasons
(Phase 1 `outputs/psm_feasibility.csv`, `outputs/psm_balance_table.csv`):

1. **PFAS exposure is continuous.** A top-quartile "high vs low" split discards
   information and makes the result depend on an arbitrary threshold. A continuous
   treatment / GPS or dose-response formulation is more appropriate.
2. **PSM balances only measured covariates.** Historical industrial activity, water-
   utility investment, historical segregation, healthcare access, food environment and
   legacy environmental burden are largely unobserved.
3. **Many of those confounders are spatially structured.** Standard PSM does not model
   latent spatial dependence; neighbouring ZCTAs share infrastructure and history.

Phase 1 already shows PSM is *feasible but fragile* here: max |SMD| 0.87 unadjusted,
≈ 0.47 after IPW, ~0.04 only after 1:1 caliper matching (which discards units and still
cannot touch unobserved confounders).

---

## 4. Proposed framework — estimand first

### 4.1 Exposure

Primary: `A_i = log(1 + HI_i)`, `HI_i` = ZCTA EPA-2024 PFAS Hazard Index.
Sensitivity: summed PFAS, detection frequency, # compounds detected, individual
compounds. **Caveat:** with 96 % non-detects the concentration-based measures (HI, sum,
individual compounds) carry little information and depend on the non-detect imputation;
the **detection-based** measures (any detection, # compounds, detection frequency) are
the better-supported exposures and should be reported alongside HI, not after it.

### 4.2 Outcomes

`obesity_pct`, `diabetes_pct`, `bphigh_pct`, modelled **separately**. These are CDC
PLACES model-based crude prevalences *with* known standard errors. Model the outcome
measurement error explicitly — e.g. a logit-normal observation layer with the PLACES
95 % CI width (`*_ci_width`) as the known per-ZCTA SE — rather than treating the point
estimate as truth.

### 4.3 Measured confounders

From a **pre-specified causal DAG**, not from p-values or fit: median household income,
poverty, education, unemployment, race/ethnicity composition, median age and % 65+,
population density, mobile-home share, housing tenure, median rent, median home value.
Water-system source type (ground vs surface) is an **exposure descriptor / mediator**,
not a pre-treatment confounder — do not adjust for it in the primary model.

### 4.4 Causal estimand

A **community-level** dose-response function

```
m(a) = E[ Y(a) ]           (expected ZCTA prevalence under community exposure level a)
Δ(a1, a0) = E[ Y(a1) − Y(a0) ]
```

estimated by g-computation / standardisation over the covariate distribution, i.e.
`m(a) = E_X[ E(Y | A = a, X, U) ]`. This requires a **flexible term in `A`** (penalised
spline or Gaussian process), otherwise `Δ(a1,a0) = τ (a1 − a0)` is trivial and the
"dose-response" language is unearned.

Two points on interpretation:

- `m(a)` is an **ecological / community-level** effect — the effect of changing a
  community's drinking-water PFAS, not an individual's serum-PFAS → BMI effect. It is
  subject to ecological bias and is *not* a substitute for the planned individual-level
  biomarker study.
- Contrast **policy-relevant exposure levels** (e.g. HI = 0 vs HI = 1; or the 10th vs
  90th percentile) rather than an arbitrary quartile boundary.

---

## 5. The joint spatial exposure–outcome model (Model 3)

For ZCTA `i`:

```
A_i = α0 + X_i α + U^A_i + ε^A_i
Y_i = β0 + f(A_i) + X_i β + U^Y_i + ε^Y_i
```

with a **correlated** pair of latent spatial fields, `Cor(U^A_i, U^Y_i) ≠ 0`, so the
model can represent unmeasured geographically structured factors that drive **both**
exposure and outcome (Thaden & Kneib 2018, "structural equation models for spatial
confounding"). Areal unit → a **BYM2 / CAR** prior is the natural start; the Phase 1
k = 6 neighbour graph is a sensitivity specification, and the neighbourhood definition
should be reconsidered for the causal model (island/point ZCTAs, the ~28 contiguity
sub-graphs).

**Known practical difficulties — plan for them:**

- **The cross-correlation is often weakly identified.** Bivariate/multivariate CAR
  (MCAR; Gelfand & Vounatsou 2003) cross-dependence parameters are frequently
  near-flat in the posterior and sensitive to parameterisation. Report its prior
  sensitivity; do not over-interpret a "significant" shared spatial component.
- **Feedback between the two equations.** In a fully joint fit the `Y` model informs the
  latent structure of `A`. Consider a **Bayesian cut** (or a two-stage fit) so the
  outcome does not contaminate the exposure model.
- **Section 2 applies here in full:** if `A` and `U^Y` occupy the same spatial scale,
  `τ`/`f(A)` is not separately identified.

Software: `R-INLA` (BYM2, `bym2` + copied/shared components), `CARBayes`, `nimble`,
`brms` (`car()` term), `spBayes`.

---

## 6. Spatial confounding adjustment — SEM vs SAR

- **Compare total impacts, not raw coefficients.** A spatial-lag (SAR) β is a "direct
  effect"; the total effect runs through `(I − ρW)^{-1}`. For obesity the SAR total
  impact is **+0.51** (`sar_total_impact_pfas`), not the raw +0.30.
- **Prefer the spatial-error (SEM) form for a causal reading.** SAR implies a genuine
  outcome-to-neighbour-outcome spillover (one ZCTA's obesity *causing* a neighbour's) —
  not mechanistically plausible for these outcomes. A spatially structured *error* — i.e.
  unmeasured spatially correlated confounding — is the more defensible story, and points
  to SEM / restricted spatial regression / `Spatial+` rather than SAR.
- **Report residual spatial autocorrelation for every model** (Phase 1: naïve OLS
  residual Moran's I ≈ 0.49 for obesity — non-spatial regression is indefensible).

---

## 7. Model sequence

| Model | Specification | Purpose |
|---|---|---|
| **M0** | `Y = β0 + β1 A + ε` | document the crude ecological association |
| **M1** | `+ X β` (DAG-specified confounders) | how much of M0 is measured-confounder difference |
| **M2** | conventional spatial (SEM; SAR with total impacts for contrast) | sensitivity of the PFAS coefficient and residual dependence to explicit spatial structure |
| **M3** | Bayesian joint spatial exposure–outcome model, correlated `U^A`,`U^Y`, outcome measurement-error layer, flexible `f(A)` | PFAS effect after measured + latent spatial confounding, with full posterior uncertainty — **the confounding-sensitivity step** |
| **M4** *(optional)* | spatially varying `τ_i = τ(s_i)` | does the community-level effect differ across the study region? — a causal analogue of MGWR, but **even more weakly identified** than global `τ` |

The informative output is the **trajectory** `τ̂(M0) → τ̂(M1) → τ̂(M2) → τ̂(M3)`, per
outcome, with its uncertainty — not any single number.

---

## 8. Interpreting the trajectory

| Pattern | Reading | Caution |
|---|---|---|
| **A. Negative → 0** | inverse association largely explained by measured + spatially structured confounding | check it is not just variance inflation from the spatial random effect |
| **B. Negative → sign flip** | *possible* negative spatial confounding | a sign flip is **also a classic artefact** of spatial-confounding bias / weak identification (Hodges & Reich) — treat as a red flag, not a finding, until the Section 2 diagnostics pass |
| **C. Negative, stable** | spatial confounding alone does not explain it | shift attention to exposure measurement error, monitoring selection, temporal/ecological mismatch, alternative exposure definitions |

The goal is **not** to move the PFAS coefficient toward any particular value, but to
understand *why* it does or does not change as stronger assumptions are imposed.

---

## 9. What this framework can and cannot do

**Can help with:** measured-confounder adjustment; latent *spatial* confounding;
spatial autocorrelation; continuous exposure and a dose-response estimand; posterior
uncertainty (including PLACES outcome error and, if data allow, exposure error);
spatially varying effects; hierarchical / left-censored non-detects; sensitivity to
spatial structure.

**Cannot solve:** unmeasured **non-spatial** confounding; a wrong DAG; exposure
misclassification from PWS→ZCTA allocation; incomplete monitoring of small/rural
systems; ecological bias; the temporal mismatch between recent tap-water PFAS and
long-term disease; the absence of individual exposure histories; interference across
water systems / neighbouring areas.

It is an improvement in **design and uncertainty modelling**, not a route to a
guaranteed causal conclusion.

---

## 10. Sensitivity and robustness analyses

1. **Alternative PFAS definitions** — detection-based (any, #, frequency) *and*
   concentration-based (HI, sum, individual); report together.
2. **Non-detect handling** — ND = 0; ND = MRL/2; left-censored likelihood (Tobit at the
   ZCTA stage / MLE).
3. **Spatial structure** — queen contiguity; k = 6 and other k; BYM2 vs CAR vs no
   spatial term; alternative neighbourhood handling for islands/sub-graphs.
4. **Geographic scope** — Texas; EPA Region 6; the South; national.
5. **Formal unmeasured-confounding sensitivity** *(new — the most informative check for
   a causal claim)*:
   - E-value (VanderWeele & Ding 2017) for each `τ̂`;
   - Bayesian bias analysis — priors on the strength of an unmeasured (spatial and
     non-spatial) confounder's association with `A` and `Y`, propagated to `τ`.
6. **Negative controls** *(new)*:
   - negative-control outcome(s) sharing the confounding structure but not plausibly
     caused by drinking-water PFAS;
   - negative-control exposure(s) (e.g. a co-monitored contaminant with a different
     source pathway).
7. **Cross-method agreement** — OLS, SEM/SAR, GPS/weighting, MGWR (exploratory
   heterogeneity benchmark), joint Bayesian model. Convergent results across methods are
   stronger evidence than any single model.

---

## 11. Exposure measurement error is the binding constraint

The PWS→ZIP→ZCTA step produces **shared, spatially structured (Berkson-type) error**: a
single PWS measurement is copied to every ZCTA that system serves, and a ZCTA served by
several systems gets a blend. This:

- induces spatial autocorrelation in the exposure surface **by construction**
  (relevant when interpreting the exposure's Moran's I);
- is **not** classical measurement error, so it does not simply attenuate `τ` — it can
  bias in either direction and distorts the spatial random effect.

Modelling it explicitly (a measurement-error layer for `A`) needs **external validation
data** — actual PWS service-area boundaries, a population/area-weighted ZIP↔ZCTA
crosswalk (HUD USPS, UDS Mapper), or EPA's forthcoming service-area layer. Until that
exists, the measurement-error model is not identified, and improving the crosswalk is
the single highest-value next step.

---

## 12. Role in the project

Recommended analytical hierarchy for the next phase:

```
causal DAG
  → continuous PFAS exposure + non-detect model
  → improved PWS→ZCTA exposure geography            ← highest-value prerequisite
  → Bayesian spatial exposure model (U^A)
  → Bayesian spatial outcome model (U^Y), outcome measurement-error layer
  → posterior community-level dose-response estimand + identification diagnostics
  → optional spatial effect heterogeneity (M4)
```

- The Phase 1 **feasibility work is retained, not replaced**: the sample-sufficiency
  verdict, the PSM feasibility result and the GWR/MGWR verdict all stand and feed
  directly into this sequence (SEM = M2; PSM/GPS and MGWR = triangulation).
- This framework is the **confounding-sensitivity layer**, not a causal deliverable.
- Even executed perfectly on multi-state data, the output is a **community-level,
  weakly-causal** estimate that motivates — and does not substitute for — the
  individual-level biomarker study.

---

## 13. Decisions required before implementation

- primary PFAS exposure definition (and the fixed sensitivity set);
- the causal estimand and the two contrast levels;
- the causal DAG and the final measured-confounder adjustment set;
- whether Texas alone provides sufficient exposure contrast (Phase 1 suggests not:
  19 exceedance ZCTAs);
- non-detect model (ND = 0 / MRL/2 / left-censored);
- spatial neighbourhood and prior (BYM2 / CAR / k-NN; island handling);
- whether an exposure measurement-error model is identifiable yet (depends on getting a
  weighted crosswalk or service-area GIS);
- which sensitivity analyses (Section 10) are pre-registered as primary.

Until these are settled, all analyses remain **ecological, cross-sectional and
exploratory, with no causal claim**.

---

### Selected references

Reich, Hodges & Zadnik (2006) *Biometrics*; Hodges & Reich (2010) *Am. Statistician*;
Paciorek (2010) *Statist. Sci.*; Gelfand & Vounatsou (2003) *Biostatistics* (MCAR);
Thaden & Kneib (2018) *JASA*; Papadogeorgou, Choirat & Zigler (2019) *Biostatistics*;
Dupont, Wood & Augustin (2022) *Biometrics* (`Spatial+`); Guan, Page, Reich, Ventrucci
& Yang (2023) (spectral adjustment); VanderWeele & Ding (2017) *Ann. Intern. Med.*
(E-value); Riebler et al. (2016) *SMMR* (BYM2).
