# Confounding Diagnostics — Healthcare Access & County-Level Structure

**Scripts:** `scripts/22_confounding_check_healthcare_access.R`,
`scripts/23_confounding_check_county_fixed_effects.R`.
**Why:** across all four Phase 1 outcomes, PFAS exposure is negatively
associated with prevalence (both crude and adjusted) — opposite the
direction individual-level PFAS toxicology predicts for metabolic/lipid
outcomes. Combined with three independent exposure-side interventions
(A3a/A3b/A3c) all leaving the association and its residual spatial
autocorrelation essentially unchanged, this motivated testing specific
confounding mechanisms directly rather than continuing to refine exposure
assignment.

## Test 1 — healthcare access / screening rate (null result)

A ZCTA's health-insurance coverage rate is a plausible shared driver: CDC
PLACES's `highchol_pct` measures self-reported "ever told by a doctor,"
so lower screening access could mechanically suppress measured prevalence
regardless of true PFAS effects. No existing covariate measures this
directly (`svi_index` and `urban_flag` are built from variables already in
`P1_COV`, so they add no independent information). ACS table B27001 (Health
Insurance Coverage Status by Sex by Age) — never previously pulled in this
project — was downloaded via the same keyless bulk-file method Phase 1 used
for its other ACS tables, and ZCTA uninsured rate was computed and tested.

**Result: null.** Uninsured rate strongly predicts cholesterol prevalence on
its own (std β = 0.769, p = 3.7×10⁻⁹) — plausibly because PLACES's own
small-area model uses correlated inputs — but it is essentially uncorrelated
with PFAS exposure itself (Pearson r = −0.041). A variable must be
correlated with **both** the exposure and the outcome to confound their
association; this one only satisfies the second condition. Adding it to the
model moves the PFAS standardized β by only 1.4% (−0.0950 → −0.0937,
`outputs/confounding_check_healthcare_access.csv`). **This specific
confounding channel is ruled out.**

## Test 2 — does the unexplained pattern operate at county granularity? (strong positive result)

This tests a different, more consequential hypothesis: that the persistent
residual spatial autocorrelation (and part of the PFAS–cholesterol
association itself) reflects differences **between whole counties** —
either real regional confounders (diet, clinical practice patterns,
healthcare systems) or an artifact of how CDC PLACES's small-area model
pools statistical strength across geography — rather than anything about
PFAS exposure measurement, which A3a/A3b/A3c already showed does not move
the needle.

**Method:** the identical A1 sample (n=1,223 ZCTAs across 197 Texas
counties) and covariate set, with a county term added two ways: (1) a
fixed effect (`factor(county_fips)`, 207 total parameters — a check
reported for transparency, but 63 of the 197 counties have only one ZCTA
in this sample, so their fixed effect perfectly absorbs that single
observation, a known overfitting risk flagged by an HC1 near-singularity
warning); (2) a random intercept (`lme4::lmer(... + (1|county_fips))`,
partial pooling, the statistically appropriate way to handle the many
small counties) as a robustness check.

**Result: a large, robust effect, confirmed two ways.**

| | No county adjustment | + county fixed effect | + county random effect |
|---|---|---|---|
| PFAS standardized β | −0.0950 (p=3.4×10⁻⁸) | −0.0357 (p=0.079) | −0.0517 (t=−2.84) |
| Change from baseline | — | **−62.4%** | **−45.5%** |
| Residual Moran's I | 0.2781 | 0.0318 | 0.0547 |
| Change from baseline | — | **−88.6%** | **−80.3%** |

Both methods agree on the direction and rough magnitude: roughly **half of
the originally observed PFAS–cholesterol association, and the large
majority (80–89%) of the residual spatial autocorrelation that survived
every exposure-side test in this branch, is attributable to differences
between counties, not to anything finer-grained.** The random-effects
model's own variance decomposition confirms this independently: 25.7% of
the residual variance in cholesterol prevalence (after PFAS + covariates)
sits at the county level (ICC), not the ZCTA level.
(`outputs/confounding_check_county_fe_regression.csv`,
`outputs/confounding_check_county_re_regression.csv`,
`outputs/confounding_check_county_fe_spatial.csv`)

## Test 3 — is the between-county effect driven by a handful of outlier counties?

The between-county PFAS variable (simple mean of `pfas_hi_log` across each
county's ZCTAs) is itself heavily zero-inflated: 124 of 197 counties (62.9%)
have exactly zero mean exposure, mirroring the dilution problem A2 found
for population-weighted county exposure (54.5% zero across all 254
counties). The between-county coefficient is therefore better understood
as a comparison between a "some PFAS detected" group of 73 counties and a
"zero detected" group of 124, not a smooth dose–response. Removing the top
3 or top 8 highest-mean-exposure counties left the coefficient materially
unchanged (std β: −0.077 → −0.072 → −0.098; still significant each time;
`outputs` from the interactive session), so this is **not an outlier-driven
artifact** — it is a real, if coarse, group-level contrast. Notably, the
highest-exposure counties (Jones, Taylor, Martin, Ector, Midland, Howard,
Callahan, Calhoun) cluster in the **Permian Basin oil/gas region** of West
Texas — a specific industrial geography that plausibly differs from the
rest of the state on many dimensions besides PFAS.

## Test 4 — CDC PLACES's own methodology confirms the county-random-effect mechanism

CDC's official PLACES methodology page
(`https://www.cdc.gov/places/methodology/index.html`) states directly:
PLACES uses "a multilevel regression and poststratification (MRP) method,"
where the logistic regression model for every measure includes
"**State- and county-level random effects**," applied at the census-block
level and then aggregated up to ZCTA. This means every census block within
a given county's predicted probability is anchored to that **same**
county-level random-effect term before being aggregated into ZCTA
estimates — a structural, by-construction source of within-county
similarity (and between-county difference) in the outcome variable itself,
independent of any real disease pattern. This directly confirms — not just
the theorized possibility, but the actual documented model structure —
that part of the "county effect" found in Tests 2–3 is attributable to
PLACES's own estimation procedure.

## Test 5 — A4: does the county effect survive a non-PLACES outcome? (decisive)

See [`a4_feasibility_summary.md`](a4_feasibility_summary.md) for full detail.
Using the exact same PFAS exposure data and covariates, but switching the
outcome to CDC WONDER's death-certificate-based Ischaemic Heart Disease
mortality (no survey, no MRP model, no county random effect), the
between-county association **disappears entirely**: IRR = 0.998 (95% CI
0.964–1.034, p = 0.911), compared to PLACES's std β = −0.077 (95% CI
−0.126 to −0.028, p = 0.002). The confidence interval is narrow and
centered on 1.0 — a precisely estimated null, not an underpowered one.

## What this means

1. **The healthcare-access confounding channel is ruled out specifically** —
   it predicts the outcome but not the exposure, so it cannot explain the
   pattern.
2. **The unexplained structure is substantially a county-level phenomenon**,
   which retroactively explains why three independent, genuinely different
   ZCTA-level exposure interventions (A3a's reweighting, A3b's source
   context, A3c's real-polygon reassignment) all left the residual spatial
   autocorrelation essentially unchanged: **none of them operate at the
   scale where the unexplained variation actually lives.** A ZCTA-level fix
   was never going to address a county-level pattern.
3. **The between-county effect is a real, robust statistical pattern in the
   PLACES data** (not an outlier artifact, Test 3) **but CDC PLACES's own
   methodology guarantees part of that pattern is structural** (Test 4),
   **and the pattern does not replicate with an independent, non-PLACES
   outcome** (Test 5/A4). Taken together, these three findings point toward
   the PLACES-methodology-artifact explanation as the dominant one, though
   Test 5 cannot fully rule out that IHD mortality is simply a noisier or
   differently-lagged endpoint than cholesterol.

**Bottom line for Direction A:** the case for further ZCTA-level exposure
refinement was already weak after A3a/A3b/A3c; this diagnostic chain goes
further and substantially weakens the case for the underlying
PFAS–cholesterol association itself, at least as measured through CDC
PLACES. The within-county signal (std β ≈ −0.05, Test 2) remains the most
defensible fragment of the original finding, but it is now understood
against a backdrop where the much larger between-county component — most
of what made the original −0.095 look so decisive — does not survive a
change of outcome source.
