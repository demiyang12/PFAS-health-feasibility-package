# A2 Feasibility Summary — County-level UCMR5 PFAS + Birth Outcomes

**Pipeline:** `scripts/03_a2_build_county_exposure.R`, `04_a2_read_birth_outcomes.R`,
`05_a2_analysis.R`. Ecological, cross-sectional; no causal claim. This is a feasibility
pilot, not an epidemiologic conclusion.

---

## A2.1 — birth-outcome source, verified before any analysis

| Field | Finding |
|---|---|
| Source | Texas DSHS Center for Health Statistics, **Vital Statistics Annual Report, Table 10** |
| Exact title | "Low Birth Weight (<2500 grams) Infants by Region, County of Residence, and Race/Ethnicity" |
| Geography | County of **maternal residence** (matches the task's specification) |
| Numerator | Infants born at <2,500 g (standard clinical LBW cutoff) |
| Denominator | Not published directly — **derived** here as `round(count / (rate/100))`; documented, not assumed exact |
| Suppression | `*` = suppressed count, `-` = suppressed/not-computed rate. **Both symbols are distinct from a published zero** — a true small/zero count and a privacy-suppressed count are **not distinguishable** from each other in this table |
| Counties represented | All 254 (the static Annual Report table lists every county; only the interactive dashboard version drops zero-count rows) |
| Most recent available year | **2019** (checked 2026-10-01; 2020–2023 not yet posted as a static table) |
| Preterm birth by county | **Not found** in this report series. CDC WONDER (database D149, "Natality 2016-2024 expanded") was identified as a documented, programmatic backup — `POST request_xml` to `https://wonder.cdc.gov/controller/datarequest/D149`, grouping `B_1=D149.V21-level2` for county of residence — but completing a working query (resolving the exact gestational-age-category codes) was **not finished within this pilot's scope**. A2-PTB is therefore **not run with real data**; this is a documented access barrier, not a silent substitution. |

Full detail: `docs/a2_birth_outcome_metadata.csv`.

## A2.2 — county exposure construction

Population-weighted aggregation used **Geocorr 2022** (Missouri Census Data Center), a
keyless, scriptable ZCTA↔county correspondence weighted by 2020 Census population
(`scripts/download_raw_a.sh` documents the exact, reproducible two-step CGI-broker call).
The HUD-USPS crosswalk was considered and rejected because it requires an API key, breaking
this project's keyless-public-data convention. An **area-weighted** sensitivity version was
also built from the same Census ZCTA↔county relationship file Phase 1 already uses.
Formula: `county exposure = Σ(ZCTA exposure × intersection population) / Σ(intersection population)`,
summed over every (ZCTA, county) pair touching that county (677 of 1,989 Texas ZCTAs span
more than one county and are split correctly by population share, not double-counted or
arbitrarily assigned to one county).

## A2.3 — county exposure diagnostics (answers question 1)

**1. Can UCMR5 exposure be represented at county level without destroying most of the exposure contrast?**
Partially. 230 of 254 Texas counties (95.8% of the state's population) have *some*
population-weighted PFAS exposure data. But the Hazard Index interquartile range **compresses
to about 61% of its ZCTA-level value**, and — more strikingly — the **county-level median
Hazard Index is exactly 0**: more than half of Texas counties net out to essentially zero
population-weighted exposure once every ZCTA in the county is blended together. Reassuringly,
Phase 1's top-quartile-exposure ZCTAs do **not** get diluted out of the highest-exposure
county tercile (100% of them land in a "high" county) — the compression mainly erases
contrast in the *middle and lower* part of the distribution, not at the top. Population- and
area-weighted versions agree closely in aggregate (Spearman ρ = 0.997) even though they are
conceptually different — a useful but secondary finding. Full detail:
`outputs/a2_county_exposure_diagnostics.csv`.

## A2.5 — linkage funnel (answers question 2)

**2. How many Texas counties remain usable after exposure linkage and birth-data suppression?**

| Step | n |
|---|---|
| Texas counties (total) | 254 |
| ... with usable county-level PFAS exposure | 230 |
| ... also with a non-suppressed 2019 LBW rate | 119 |
| ... also with complete county-level covariates [**final sample**] | 119 |

Fewer than half of Texas counties (47%) survive to the final analytic sample — and not at
random: counties with a usable LBW rate have a mean population density of 260/km², versus
10/km² for suppressed counties (`outputs/a2_lbw_missingness_check.csv`). **Suppression is
concentrated in rural counties**, a structural pattern, not noise. Mean exposure (Hazard
Index) is similar between usable and suppressed counties (0.057 vs 0.068), so the missingness
does not appear to be strongly exposure-selective — but it is strongly urbanicity-selective.

## A2.4 — temporal compatibility (answers question 3)

**3. Are the exposure and outcome time windows reasonably compatible?**
**No.** The most recent available county LBW data is from **2019**; UCMR5 monitoring runs
**2023–2025**. Exposure measurement *post-dates* the birth outcomes by at least four years.
Critically, **no amount of restricting the UCMR5 window helps**: UCMR5 has no data before
2023, so any "temporally sensible" restriction can only make the gap to 2019 births larger,
never smaller. Per the task's explicit instruction for this situation, this is stated plainly
as a major, unresolved limitation rather than worked around with a constructed exposure
window that would not be defensible.

## A2.6 / A2.7 — descriptive, correlation, and regression (answers questions 4–6)

**4. Do LBW or preterm birth show any coherent ecological spatial relationship with county PFAS?**
For LBW: essentially no. Unadjusted Pearson r = 0.008, Spearman ρ = −0.148
(`outputs/a2_lbw_correlation.csv`) — both far weaker than any ZCTA-level result in A1 or
Phase 1. Preterm birth was not run (see A2.1).

**5. Are crude and adjusted coefficients reasonably stable?**
**No — this is the central negative finding of A2.** The crude standardized β is −0.008
(p = 0.87, indistinguishable from zero). After adjustment it **flips sign** to +0.089
(p = 0.018, nominally "significant") — but that result does **not** survive a basic
births-weighted sensitivity re-specification (β = +0.045, p = 0.18;
`outputs/a2_lbw_regression.csv`). A coefficient that changes sign between a crude and an
adjusted model, and then loses significance under a reasonable alternative weighting, is the
textbook signature of a fragile, model-dependent estimate — not evidence of a real
association, per the task's own explicit caution against treating p < 0.05 as validity.

**6. Does county aggregation introduce so much information loss that the design becomes weak?**
Yes, on top of everything above: residual Moran's I is 0.029 (crude, p = 0.20) and −0.065
(adjusted, p = 0.81) — **no detectable residual spatial structure at all** at n = 119
counties, in sharp contrast to the strong, highly significant spatial structure Phase 1 and
A1 both find at ZCTA level (`outputs/a2_lbw_spatial_residual_check.csv`). This is consistent
with a sample that is both too small and too coarse to resolve spatial pattern, not with an
absence of true spatial process.

**7. Would a full Direction A birth-outcome study require a different exposure dataset or restricted individual-level birth data?**
Yes to both. A defensible birth-outcome study would need either (a) a finer-grained,
more current, less-suppressed birth-outcome source — realistically, restricted-use TX DSHS
or NCHS birth-certificate microdata with ZCTA-level geocoding under a data-use agreement, not
the public county aggregate used here — or (b) acceptance of county-level analysis with all
three limitations documented above (dilution, suppression, temporal mismatch) explicitly
carried forward, which this pilot does not consider defensible as a primary design.

---

## Bottom line for A2

**A2-LBW is feasible to *construct* (the pipeline runs end-to-end on real, verified public
data) but not currently *informative*.** Three independent problems — exposure dilution from
county aggregation, non-random outcome suppression concentrated in rural counties, and an
unresolvable temporal mismatch (exposure after outcome) — each individually weaken this
specific pairing, and none of Phase 1's or A1's spatial-structure or association-stability
results replicate at this geography. **A2-PTB was not run** (no usable public data source
completed). See `direction_a_feasibility_memo.md` for how this combines with A1 into an
overall Direction A recommendation.
