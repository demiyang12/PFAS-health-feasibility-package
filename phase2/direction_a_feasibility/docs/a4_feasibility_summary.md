# A4 Feasibility Summary — CDC WONDER Mortality (Non-PLACES Outcome)

**Scripts:** `scripts/24_a4_parse_wonder_mortality.R`, `scripts/25_a4_mortality_analysis.R`.
**Why:** the confounding diagnostics (`confounding_diagnostics_summary.md`) found a large,
statistically robust "between-county" PFAS–cholesterol association (std β = −0.077, 95% CI
−0.126 to −0.028), but also found that CDC PLACES's own small-area estimation model explicitly
includes county-level random effects (confirmed from CDC's official methodology page) — meaning
that association could be partly or wholly a measurement artifact of how PLACES computes its
ZCTA estimates, not a real signal. A4 tests the same underlying question — does PFAS exposure
relate to a cardiovascular outcome at the county level — using a structurally different outcome
source with no small-area smoothing: CDC WONDER's Multiple Cause of Death database, built
directly from death-certificate counts.

## Data source and a real access constraint

CDC WONDER's own documented API
(`https://wonder.cdc.gov/wonder/help/wonder-api.html`) states that, per National Vital
Statistics System confidentiality policy, **sub-national geography cannot be queried via the
keyless API — only national totals are accessible by API.** County-level mortality is only
available through the interactive web request form. The data below were retrieved from that
form (database D157, `https://wonder.cdc.gov/mcd-icd10-expanded.html`) with documented query
criteria (Texas; ICD-10 I20-I25, Ischaemic Heart Disease; years 2020-2024; grouped by county;
suppressed and zero rows shown) — a human-reproducible, not programmatically re-runnable, pull,
consistent with this project's practice of being explicit about which steps require interactive
access (the same situation encountered with TWDB in A3c, though here no hidden bulk endpoint
exists — this restriction is an explicit confidentiality policy, not a technical gap).

**Why this outcome:** Ischaemic Heart Disease is the most direct, literature-motivated
downstream endpoint of elevated cholesterol (atherosclerosis → ischaemic heart disease), making
it a natural "harder," non-self-reported analogue to PLACES's `highchol_pct`.

**Coverage:** all 254 Texas counties queried; 12 (4.7%) suppressed (≤9 deaths over the 5-year
window) and excluded from analysis, never imputed as zero — a far better suppression profile
than A2's DSHS birth-outcome pull (53% suppressed), because 5-year cumulative death counts are
much larger numbers than annual birth counts in small counties.

## Method

County-level negative binomial regression (Poisson dispersion statistic = 18.2, confirming
substantial overdispersion and that Poisson alone would understate uncertainty) of IHD deaths
with `log(population)` as an offset — the standard approach for rare-event count mortality
data, not an OLS regression on the crude rate. Reuses A2's existing population-weighted county
PFAS exposure (`pfas_hi_log`) and covariate set (income, poverty, education, Hispanic share,
Black share, population density) exactly — only the outcome source changes.

## Result — a clean, precise null

| | PLACES cholesterol, between-county effect (script 23) | CDC WONDER IHD mortality (A4) |
|---|---|---|
| Effect | std β = −0.077 | IRR = 0.998 |
| 95% CI | −0.126 to −0.028 | 0.964 to 1.034 |
| p-value | 0.002 | **0.911** |

A 1-SD increase in PFAS exposure is associated with a statistically indistinguishable-from-zero
0.2% change in IHD mortality (95% CI: a 3.6% decrease to a 3.4% increase). The confidence
interval is narrow and centered on no effect — **this is a precisely estimated null, not an
underpowered one** (same lesson as the within-county Mundlak result in script 23: a narrow CI
around zero is informative, not merely "not significant").

A secondary note: simple pairwise correlation (Pearson r = −0.059, Spearman ρ = −0.304) showed
more apparent signal than the properly specified count-regression model — a reminder, consistent
with earlier findings in this branch, that simple correlations on zero-heavy, skewed exposure
distributions can overstate apparent relationships that a correctly specified model does not
support.

## What this means

Switching the outcome from PLACES's modelled cholesterol prevalence to CDC WONDER's
death-certificate-based cardiovascular mortality — using the **identical** PFAS exposure data
and covariate set — makes the previously robust, significant "between-county" association
**disappear entirely**. This is strong corroborating evidence for the hypothesis raised in the
confounding diagnostics: a substantial share, quite possibly nearly all, of the PLACES-based
between-county PFAS–cholesterol association reflects how PLACES's small-area model assigns
county-level random effects to its estimates, not a real relationship between community
drinking-water PFAS levels and cardiovascular health in Texas.

**This does not prove PFAS has no cardiovascular effect** — IHD mortality is a different,
further-downstream endpoint than cholesterol itself, with its own sources of noise (competing
causes of death, diagnostic/coding variation in cause-of-death attribution, a 5-year window that
may not capture a lagged effect). But it removes the single most statistically compelling
piece of evidence this entire branch (A1 through the confounding diagnostics) had produced for
a real PFAS–cardiometabolic relationship in this dataset, and it does so with a non-PLACES,
non-modelled, independently sourced outcome — exactly the kind of test that should move the
needle if the original finding were an artifact, and did.

**Main limitation:** CDC WONDER's sub-national data access restriction means this specific pull
cannot be scripted/automated for future reproduction — any re-run requires repeating the
documented interactive web-form steps. A single downstream cause (IHD) was tested; a different
cardiovascular or metabolic cause of death might, in principle, behave differently, though
there is no specific reason from this analysis to expect so.
