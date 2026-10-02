# Direction A Updated Feasibility Memo — A1 + A2 + A3a + A3b + A3c + A4 Combined

**Branch:** `Direction-A-feasibility-test` (off `phase-2-feasibility-assessment`)
**Status:** Six completed feasibility pilots. **No GWR/MGWR/PSM/Bayesian/ML/causal/mediation
methods were used, and the original A1/A2 memo, Phase 1 outputs, and the Phase 2 decision
matrix have not been edited** — this memo supersedes [`direction_a_feasibility_memo.md`](direction_a_feasibility_memo.md)
as the current combined verdict; that file is kept as-is for the A1/A2-only record.

> **Interpretation guard-rail (unchanged from the A1/A2 memo).** UCMR5 remains a
> community-level drinking-water exposure proxy, not an individual dose. CDC PLACES outcomes
> are modelled ecological prevalence estimates, not clinical measurements. All associations in
> all six pilots are **ecological, cross-sectional, and non-causal.** Statistical significance
> is not treated as validity; effect stability, exposure contrast, and spatial structure were
> weighted more heavily than p-values throughout.

---

## 1. What A3 added

A1 and A2 (summarized in [`direction_a_feasibility_memo.md`](direction_a_feasibility_memo.md))
asked whether a different **outcome** or **geography** produces a more defensible
exposure–health pairing. Both pilots left one thing unresolved: residual spatial
autocorrelation in the cholesterol model (Moran's I ≈ 0.28, p ≈ 0) that A1 explicitly
attributed to the unimproved PWS→ZIP→ZCTA exposure assignment. A3 tested that attribution
three ways, **without touching the outcome, covariates, sample, or spatial weights**:

- **A3a** — does a different *weighting rule* applied to the same self-reported ZIP-code list
  change the exposure surface or the result? [`a3a_feasibility_summary.md`](a3a_feasibility_summary.md).
- **A3b** — does independent source-pressure data (TRI reported release, Superfund NPL,
  NPDES) explain UCMR5's spatial pattern or change the result? [`a3b_feasibility_summary.md`](a3b_feasibility_summary.md).
- **A3c** — does replacing the self-reported ZIP-code list itself with a *real, mapped*
  service-area polygon (TWDB) change the exposure surface or the result — the structurally
  different question A3a identified but could not test? [`a3c_feasibility_summary.md`](a3c_feasibility_summary.md).

## 2. A3a in one paragraph

Switching from Phase 1's full-population-weight assignment to an equal-split
population-weighted alternative barely moves anything: Pearson r = 0.979 / Spearman ρ = 0.997
between the two exposure surfaces, 97.1% of ZCTAs stay in the same quartile, and 94.1% of
top-quartile hotspots are retained. The cholesterol association is essentially unchanged
(adjusted std β −0.095 → −0.090, both p < 2×10⁻⁷), and residual spatial autocorrelation does
not move (Moran's I 0.278 → 0.280). The reason is structural: three of four Texas UCMR5
systems report serving exactly one ZIP code, so the two weighting schemes are mathematically
identical for them.

## 3. A3b in one paragraph

Adding real Texas TRI (PFAS-specific reporting), Superfund NPL, and NPDES data — kept strictly
separate from the UCMR5 measurement throughout, never combined into a composite score — shows
a similar pattern from a different angle. Source-pressure variables correlate negligibly with
UCMR5's spatial exposure pattern (Pearson −0.006 to 0.032). The cholesterol association is
unchanged across every staged model (std β −0.093 to −0.097, all p < 1×10⁻⁶), and residual
spatial autocorrelation barely moves (0.278 → 0.269). The one genuinely new finding is a 2×2
hotspot comparison: 420 of 1,223 ZCTAs (34%) show UCMR5 and source-pressure evidence pointing
in **different** directions, concentrated near major metro areas — useful for flagging specific
places for follow-up, not for correcting the exposure measure.

## 4. A3c in one paragraph

A3c pulled the real dataset A3a could only identify: TWDB's Water Service Boundary Viewer, a
public, keyless, scriptable ArcGIS layer of 4,621 mapped PWS service-area polygons statewide
(the data-quality investigation, including a correction to an initial over-confident read of
an ambiguous `Source` field, is in `docs/a3c_twdb_feasibility_note.md`). After excluding 8
systems with implausible population-density-to-area ratios, 1,120 of 1,154 Texas UCMR5 systems
were reassigned to ZCTAs by real spatial overlay with their mapped polygon (the remaining 34
keep Phase 1's ZIP-based method, documented not silent). This **moves the exposure surface
substantially more than A3a did** — Spearman ρ = 0.937 vs. Phase 1 (vs. A3a's 0.997), only
85.1% of ZCTAs stay in the same quartile, 88.9% of top-quartile hotspots are retained, and 11
ZCTAs lose exposure entirely because their self-reported "served ZIP" does not spatially
overlap the utility's own mapped boundary at all. Despite this substantially larger change,
the cholesterol association is essentially unchanged (adjusted std β = −0.095, p = 4.2×10⁻⁸,
compared to A1's −0.095), including when combined with A3b's source-pressure variables in the
same model (−0.094 to −0.098 across five staged models) — the specific combination this round
of work was asked to test. Residual spatial autocorrelation remains at 0.282 alone and 0.272
combined with source context — statistically indistinguishable from A1 (0.278), A3a (0.280),
and A3b (0.269).

## 5. Combined comparison table

*(Full machine-readable version: [`../outputs/a1_a3a_a3b_a3c_comparison_table.csv`](../outputs/a1_a3a_a3b_a3c_comparison_table.csv);
A1 vs. A2 comparison unchanged — see [`../outputs/a1_a2_comparison_table.csv`](../outputs/a1_a2_comparison_table.csv))*

| Criterion | A1 (baseline) | A3a (reweight same list) | A3b (+ source context) | A3c (real polygon geography) |
|---|---|---|---|---|
| Changes the exposure's INPUT geography? | — | No (same ZIP list, new weights) | No (parallel variables only) | **Yes** (real mapped polygons) |
| Exposure agreement with A1 (Spearman) | — | 0.997 | n/a | **0.937** |
| Top-quartile hotspot retained | — | 94.1% | n/a | 88.9% |
| Adjusted PFAS std β (cholesterol) | −0.095 (p=3.4×10⁻⁸) | −0.090 | −0.093 to −0.097 | −0.094 to −0.098 (incl. + A3b context) |
| Residual Moran's I (adjusted) | 0.278 | 0.280 | 0.269 | 0.272 |
| Resolved A1's open spatial-autocorrelation question? | — | No | No | **No — despite the largest exposure change tested** |

## 6. Confounding diagnostics — why the residual spatial structure persisted

Three independent exposure-side interventions (A3a reweighting, A3b source context, A3c real
polygon geography) all left the cholesterol association and its residual spatial
autocorrelation essentially unmoved. This motivated testing specific confounding mechanisms
directly, documented in full in
[`confounding_diagnostics_summary.md`](confounding_diagnostics_summary.md).

**Test 1 — healthcare access (ruled out).** ACS table B27001 (health insurance coverage),
never previously pulled in this project, was added as a direct proxy for screening/diagnosis
rates (PLACES's `highchol_pct` measures self-reported "ever told by a doctor," so lower
screening access could mechanically suppress measured prevalence). Uninsured rate strongly
predicts cholesterol prevalence on its own (std β = 0.769, p = 3.7×10⁻⁹) but is essentially
uncorrelated with PFAS exposure (Pearson r = −0.041) — it fails the basic requirement for a
confounder (correlated with both exposure and outcome) and moves the PFAS coefficient by only
1.4%.

**Test 2 — county-level structure (confirmed, and decisive).** Adding a county term — tested
both as a fixed effect and, to avoid overfitting the 63 single-ZCTA counties in this sample, as
a random intercept (`lme4`) — collapsed residual spatial autocorrelation by 80–89% (Moran's I:
0.278 → 0.032–0.055) and the headline PFAS coefficient by 46–62% (std β: −0.095 → −0.036 to
−0.052). A **within-between (Mundlak) decomposition** then separated the PFAS effect into its
two components explicitly, rather than discarding the between-county part:

| Component | Standardized β | 95% CI | Interpretation |
|---|---|---|---|
| **Within-county** (comparing ZCTAs inside the same county) | −0.017 | −0.042 to +0.008 | A precise null — the interval is narrow, not merely wide/underpowered |
| **Between-county** (comparing whole counties to each other) | −0.077 | −0.126 to −0.028 | Real, and accounts for most of the original −0.095 |

A formal test confirms these two components are statistically distinguishable (χ² = 4.56,
p = 0.033) — this is not a power artifact. **The original association is now understood to be
almost entirely a between-county phenomenon.** Comparing ZCTAs within the same county — holding
constant whatever makes that county distinctive (water utility characteristics, regional
clinical practice, diet, or how CDC PLACES's small-area model treats that county) — there is no
detectable PFAS–cholesterol relationship. This also explains in hindsight why A3a, A3b, and A3c
all failed to move the residual spatial autocorrelation: all three operate at ZCTA granularity,
and the unexplained structure lives almost entirely one level up, at county granularity, which
no ZCTA-level exposure refinement could ever reach.

What remained unresolved at this point was *why* county matters this much: whether CDC
PLACES's small-area estimation model itself borrows statistical strength across geography
nested within county (a measurement artifact), or a real but unmeasured county-level
confounder (regional diet, healthcare-system quality, clinical practice patterns). Two further
checks resolved this (full detail in
[`confounding_diagnostics_summary.md`](confounding_diagnostics_summary.md)): (a) CDC's own
official PLACES methodology documentation confirms the model includes explicit
**state- and county-level random effects**, applied at the census-block level before
aggregation to ZCTA — a structural, by-construction source of within-county similarity in the
outcome itself; and (b) **A4**, below, tests this empirically.

## 7. A4 — does the county effect survive a non-PLACES outcome?

A4 reused the identical PFAS exposure data and covariates from the county-level diagnostics in
§6, but replaced PLACES's modelled cholesterol prevalence with CDC WONDER's
death-certificate-based **Ischaemic Heart Disease mortality** (ICD-10 I20-I25, Texas counties,
2020–2024) — the natural downstream cardiovascular endpoint of elevated cholesterol, sourced
from a database with no survey, no small-area model, and no county random effect. (CDC
WONDER's documented API explicitly forbids sub-national geography in scripted queries per NCHS
confidentiality policy; county-level data required the interactive web form, a
human-reproducible but not programmatically re-runnable step, recorded in full in
[`a4_feasibility_summary.md`](a4_feasibility_summary.md).) A negative binomial regression with
a population offset (Poisson dispersion = 18.2, confirming overdispersion) found:

> **IRR = 0.998 (95% CI 0.964–1.034, p = 0.911)** — a precisely estimated null — compared to
> PLACES's between-county std β = −0.077 (95% CI −0.126 to −0.028, p = 0.002).

Switching only the outcome source — same exposure, same covariates, same counties — made the
previously robust, significant between-county association **disappear entirely**, with a
narrow confidence interval centered on no effect rather than a wide, inconclusive one. This is
strong corroborating evidence that the PLACES-based between-county pattern is substantially a
product of PLACES's own estimation methodology rather than a real PFAS–cardiometabolic
relationship in this dataset. (A supporting robustness check also confirmed the between-county
PLACES effect is not an artifact of a few outlier counties — removing the top 3–8
highest-exposure counties, which cluster in the Permian Basin oil/gas region, left it materially
unchanged — so the PLACES-side finding was real and robust on its own terms; it simply does not
replicate with an independent outcome.)

## 8. Final conclusion

> ### THE ROBUST-LOOKING PFAS–CHOLESTEROL ASSOCIATION IS LARGELY A PLACES-METHODOLOGY-DRIVEN, BETWEEN-COUNTY PATTERN; IT DOES NOT REPLICATE WITH AN INDEPENDENT MORTALITY OUTCOME, AND WITHIN COUNTIES THERE IS NO DETECTABLE RELATIONSHIP

A3a, A3b, and A3c established that the ZCTA-level PFAS–cholesterol association is **robust to
how exposure is measured** — three genuinely different exposure/context interventions,
increasing in substantiveness, left it essentially unchanged. The confounding diagnostics (§6)
showed why: the association was never primarily a ZCTA-level, fine-grained dose–response
relationship. It was a **between-county** pattern — and A4 now shows that pattern is largely
tied to the specific outcome source (CDC PLACES) used to measure it, not to PFAS. Three
converging pieces of evidence — PLACES's own documented use of county random effects, the
clean disappearance of the effect with CDC WONDER mortality data, and a within-county estimate
that was already a precise null before A4 — point the same direction.

This substantially revises the feasibility picture for Direction A as a ZCTA-level (or
county-level) ecological design using these specific public data sources. Of the three
components the original −0.095 association could have reflected — a true within-county
dose–response, a true between-county pattern, or a PLACES measurement artifact — the evidence
now most favors the third: within-county, the association is a precise null (95% CI −0.042 to
+0.008); between-county, the association is statistically real in the PLACES data and
robust to outlier counties, but **does not reproduce** when the same exposure and counties are
tested against an independently sourced, non-PLACES mortality outcome.

**Combined with A2** (which independently showed that coarsening geography and outcome to the
county/LBW pairing makes things worse via dilution, suppression, and temporal mismatch), the
overall Direction A picture is now: **neither the within-county nor the between-county
component of the headline PFAS–cholesterol finding survives rigorous, independent scrutiny.**
This is a materially less favorable verdict than any point earlier in this branch, and it
changes the shape of Phase 2's original recommendation a final time: the open question is no
longer about exposure assignment (tested and settled across A3a/A3b/A3c — it does not matter)
nor really about "what explains Texas county differences" (A4 suggests much of that was a
measurement artifact, not a substantive puzzle) — it is whether this specific exposure–outcome
pairing, built from these specific public datasets, is capable of supporting a defensible
Direction A study at all. Based on everything tested in this branch, the honest answer is
**not without a different data source, outcome, or design** (see next steps).

## 9. What this means for the next analysis step

Consistent with the task scope, no advanced model is proposed here.

1. **Do not pursue further ZCTA- or county-level exposure-assignment refinement** on this
   outcome pairing — five independent tests (A3a, A3b, A3c, the county diagnostics, and A4) now
   converge on the same conclusion: exposure measurement is not the limiting factor, and the
   apparent association does not survive a change of outcome source.
2. **If Direction A is to proceed, PLACES-based outcomes should be treated with real caution**
   for any area-level environmental-exposure study in this size range, given CDC's own
   confirmation of county-level random effects in its estimation model. A non-PLACES outcome
   (vital statistics, as in A4; or a different administrative health-records source) is
   preferable to another PLACES measure.
3. The most literature-consistent remaining path, raised but not yet tested in this branch, is
   narrowing from a statewide ecological design to a **hotspot/matched-comparison design**
   centered on known concentrated PFAS sources (e.g., AFFF-associated military/airport sites,
   or the Permian Basin oil/gas counties identified in §6) against demographically similar
   non-industrial counties — closer in spirit to the point-source studies (e.g., the C8 Science
   Panel) where ecological PFAS health effects have actually been detected historically.
4. The 420 ZCTAs where UCMR5 and source-pressure evidence disagree
   (`outputs/a3b_hotspot_overlap.csv`) and the 1,120/34 eligibility split from A3c
   (`outputs/a3c_eligibility_funnel.csv`) remain concrete, reusable artifacts for qualitative
   follow-up or case-study selection, independent of whether a full Direction A study proceeds.
5. TWDB's own verification workflow is incomplete for 99.98% of statewide records as of this
   pull (`docs/a3c_twdb_feasibility_note.md`); given §6–8, this is now a low-priority follow-up
   — exposure-assignment precision has been tested from multiple angles and is not the
   constraint.
6. A2's specific county/LBW/2019 pairing remains **not currently well supported**, unchanged by
   anything in A3/A4 (these only re-tested the A1/ZCTA cholesterol pairing, per task scope).

No scripts beyond what is in this branch should be built toward a "final" Direction A model
until the research team has reviewed all six pilots and the Phase 2 decision log is updated
accordingly (see [`phase2/docs/decision_log.md`](../../docs/decision_log.md), which this branch does
not edit).
