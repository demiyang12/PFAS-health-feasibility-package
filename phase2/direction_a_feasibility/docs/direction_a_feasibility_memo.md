# Direction A Feasibility Memo — Combined A1 + A2 Findings

**Branch:** `Direction-A-feasibility-test` (off `phase-2-feasibility-assessment`)
**Status:** Two completed feasibility pilots. **No final epidemiologic model has been run,
no GWR/MGWR/PSM/Bayesian/ML methods were used, and the original Phase 2 decision matrix
has not been edited** — this memo adds empirical evidence to that decision, it does not
retroactively change it.

> **Interpretation guard-rail.** UCMR 5 remains a community-level drinking-water exposure
> proxy, not an individual dose. CDC PLACES outcomes are modelled ecological prevalence
> estimates, not clinical measurements. Birth outcomes here are aggregate vital-statistics
> rates, not individual records. All associations in both pilots are **ecological,
> cross-sectional, and non-causal.** Statistical significance is not treated as validity
> anywhere in this memo; effect stability, exposure contrast, and spatial structure were
> weighted more heavily than p-values throughout.

---

## 1. What was tested

Phase 2's scoping assessment left Direction A (a focused exposure–health study) untested
beyond Phase 1's original three outcomes. This branch ran two small, real pilots on actual
public data to find out whether changing the **outcome** (A1) or the **geography** (A2)
produces a materially more defensible exposure–health pairing than Phase 1 already found —
*before* investing in a full study.

- **A1** — Phase 1's unchanged UCMR5/ZCTA exposure + CDC PLACES **high cholesterol** (new
  outcome, same geography). Full results: [`a1_feasibility_summary.md`](a1_feasibility_summary.md).
- **A2** — UCMR5 exposure rebuilt at **county** level (population-weighted) + Texas DSHS
  **low birth weight** (new outcome, new geography). Preterm birth was identified but not
  completed (see below). Full results: [`a2_feasibility_summary.md`](a2_feasibility_summary.md).

---

## 2. A1 in one paragraph

Cholesterol is the single most coherent PFAS–health pairing found across Phase 1 and this
pilot combined: its unadjusted correlation with the Hazard Index (Spearman −0.45) matches
Phase 1's strongest outcome (hypertension), its adjusted association is the **largest and
most significant of all four outcomes tested** (std β = −0.095, p = 3.4×10⁻⁸), and its sign
is stable from crude through adjusted. A genuine data-quality finding came out of verifying
rather than assuming the source: the Phase 2 inventory's claim that this measure used BRFSS
2021 **was wrong for the release actually in use** — the live pull confirms BRFSS 2023,
contemporaneous with everything else in Phase 1. None of this touches the exposure side:
residual spatial autocorrelation after adjustment is just as large as Phase 1's (Moran's I =
0.28, p ≈ 0), because the exposure variable — and its PWS→ZIP→ZCTA assignment — is byte-for-byte
identical to Phase 1's.

## 3. A2 in one paragraph

A2 is feasible to *build* — a real, population-weighted county exposure surface and a real,
verified Texas DSHS birth-outcome source were both constructed end-to-end on public data —
but it is not currently *informative*. Three independent problems compound: county
aggregation compresses exposure contrast until the **median county's population-weighted
Hazard Index is exactly zero**; the birth-outcome source is usable for only 119 of 254
counties (47%), with suppression concentrated in rural counties, not at random; and the most
recent available birth data (2019) **predates** UCMR5 monitoring (2023–2025) by at least four
years, with no way to narrow that gap from either side. The one nominally "significant"
adjusted result (crude β flips sign after adjustment) does not survive a births-weighted
sensitivity check — the signature of a fragile, not a real, association. Preterm birth could
not be linked to a usable public county source within this pilot's scope and was not run.

## 4. Key comparison table

*(Full machine-readable version: [`../outputs/a1_a2_comparison_table.csv`](../outputs/a1_a2_comparison_table.csv))*

| Criterion | A1: UCMR5 + cholesterol (ZCTA) | A2: county UCMR5 + LBW |
|---|---|---|
| Geography | ZCTA | County |
| Exposure coverage | **Strong** — 1,223 ZCTAs, 0% missing | **Partial→weak** — 230/254 counties have data, only 119 link to a usable outcome |
| Exposure contrast | **Moderate** (unchanged from Phase 1) | **Weak** — IQR compresses to ~61% of ZCTA level; median county HI = 0 |
| Outcome data quality | **Strong** — same PLACES file, 0% missing | **Weak** — real source, but 53% of counties suppressed, non-randomly (rural) |
| Temporal alignment | **Strong** — BRFSS 2023 ≈ UCMR5 2023-2025 (verified) | **Poor, unresolved** — 2019 outcome vs. 2023-2025 exposure; gap cannot be closed |
| Crude association | r=−0.227 / ρ=−0.45 (strongest of 4 outcomes) | r=0.008 / ρ=−0.148 (weakest of any pairing tested) |
| Adjusted stability | **Moderate** — attenuates 63%, sign stable, most significant result found | **Unstable** — sign flips crude→adjusted; "significant" result fails a weighting sensitivity check |
| Residual spatial autocorrelation | **Strong, unresolved** — Moran's I 0.28–0.43, p≈0 (needs spatial modelling) | **Weak/absent** — Moran's I ≈ 0, not significant (n too small/coarse) |
| Main limitation | Same exposure-assignment problem Phase 1 already diagnosed | Dilution + suppression + temporal mismatch, simultaneously |
| New infrastructure required | None (reused Phase 1 outputs directly) | A new, scriptable population-weighted crosswalk (built and validated here) |
| Full Direction A study warranted on this pairing? | **Only after exposure improvement** | **Not currently** |

## 5. Evaluation against the full criteria set

| Criterion | A1 | A2 |
|---|---|---|
| Exposure data quality | Unchanged Phase 1 quality/limitations | Real but degraded by aggregation |
| Exposure contrast | Moderate | Weak |
| Geographic compatibility | Exact match to Phase 1 | Compatible in principle, degraded in practice |
| Temporal compatibility | Strong (verified) | Poor, unresolved |
| Health-outcome quality | Strong | Weak (suppression) |
| Missingness / suppression | None | Severe, non-random |
| Sample size / spatial support | n=1,223, strong spatial support | n=119, weak spatial support |
| Crude→adjusted stability | Stable, moderate attenuation | Unstable, sign reversal |
| Residual spatial autocorrelation | Strong, unresolved | Absent (likely a power/scale artifact, not a true absence of spatial process) |
| Interpretability | Clear, consistent with Phase 1 | Confounded by three compounding limitations |
| New infrastructure required | None | A new crosswalk + a new outcome source |
| Scientific value relative to Phase 1 | Confirms and sharpens Phase 1's pattern | Demonstrates *why* coarsening geography is the wrong direction |

## 6. Final conclusion

> ### DIRECTION A MAY BE FEASIBLE, BUT ONLY AFTER EXPOSURE IMPROVEMENT

This is the overall verdict for Direction A, and it is carried almost entirely by A1.
Cholesterol is a real, verified, more-coherent outcome — worth retaining as a low-cost
addition alongside obesity/diabetes/hypertension in any future ZCTA-level model — but it
inherits Phase 1's exposure-assignment problem unchanged, visible in residual spatial
autocorrelation just as large as Phase 1's own. **A2's specific pairing (county UCMR5 + 2019
LBW) is independently assessed as `DIRECTION A IS NOT CURRENTLY WELL SUPPORTED`** for that
pairing specifically: three compounding, largely unfixable-with-current-data limitations
(dilution, suppression, temporal mismatch) make it unsuitable as a primary design. This does
not rule out all county-level work, only this specific outcome/geography/vintage
combination.

**The two pilots reinforce, rather than compete with, Phase 2's original scoping
recommendation.** A1 shows that even the best available outcome still rides on the
unresolved exposure problem. A2 shows that trying to escape that problem by *coarsening*
geography (ZCTA → county) makes things worse — less contrast, more missing data, worse
temporal alignment — rather than better. Phase 2's recommended Direction C (improving how
PWS monitoring is assigned to residential geography, at the *same or finer* resolution, not
coarser) remains the right prerequisite before a full Direction A study on any outcome.

## 7. What this means for the next analysis step

Consistent with the task scope, no advanced model is proposed here. If Direction A is
revisited after Direction C's exposure-assignment work improves the underlying exposure
variable, the recommended next step is:

1. Re-run A1 (cholesterol, plus coronary heart disease and stroke as the other two low-cost
   PLACES additions identified in the Phase 2 scoping inventory) using whatever improved
   exposure assignment Direction C produces, and check whether residual spatial
   autocorrelation shrinks.
2. Do **not** pursue A2's specific county/LBW/2019 pairing further without either (a) a
   finer-grained, more current birth-outcome source (realistically restricted-use
   microdata under a data-use agreement) or (b) a different outcome with better county-level
   public availability.
3. Resolve the CDC WONDER D149 query (documented but incomplete in `04_a2_read_birth_outcomes.R`)
   as a separate, small follow-up task if preterm birth remains of interest, independent of
   whether Direction A as a whole proceeds.

No scripts beyond what is in this branch should be built toward a "final" Direction A model
until the research team has reviewed these two pilots and the Phase 2 decision log is updated
accordingly (see [`../docs/decision_log.md`](../docs/decision_log.md), which this branch does
not edit).
