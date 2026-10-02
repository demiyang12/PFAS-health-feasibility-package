# A3c Feasibility Summary — Real TWDB Service-Area Polygons

**Pipeline:** `scripts/17_a3c_download_twdb_service_areas.R` through
`21_a3_final_combined_comparison.R`.
**What this tests:** A3a's deferred question — not "how should population be
split across a self-reported ZIP list" (A3a's question) but "does the
self-reported ZIP list itself resemble where the utility's real, mapped
service area is at all." The Texas Water Development Board's Water Service
Boundary Viewer, confirmed in A3a's inventory to exist but not pulled at the
time, is a real, public, keyless, scriptable ArcGIS FeatureServer (see
`docs/a3c_twdb_feasibility_note.md` for the full data-quality investigation,
including a correction to an earlier over-confident read of the data).

## What was built

A **hybrid** ZCTA exposure surface, not a wholesale replacement:
- **1,120 of 1,154** Texas UCMR5 PWS (97% after excluding 8 systems with an
  implausible population-density-vs-polygon-area ratio — see the note above)
  are reassigned to ZCTAs by **real spatial overlay**: each PWS's reported
  population is distributed across ZCTAs in proportion to how much of its
  *actual mapped service-area polygon* falls in each one
  (`outputs/a3c_eligibility_funnel.csv`, `outputs/a3c_edge_method_summary.csv`).
- The remaining **34 systems** (24 with no TWDB match, 2 with unusable
  area/population data, 8 density outliers) keep Phase 1's original
  ZIP-code-list assignment, unchanged — so no system is silently dropped.
- 152 of the 1,120 eligible polygons needed `st_make_valid()` before the
  spatial overlay (self-intersecting rings — a routine GIS data-quality
  fix, not a methodological choice).
- Documented limitation: population is distributed by polygon **area**, not
  by where people actually live within that area (no sub-ZCTA population
  raster is used anywhere in this project — the same simplification as
  A3b's "geometric centroid, not population-weighted" choice).

## A3c.1 — how different is this from Phase 1, and from A3a?

**Substantially more than A3a.** Where A3a's equal-split reweighting barely
moved anything (Spearman ρ = 0.997 vs. Phase 1), A3c's real-polygon
reassignment moves meaningfully more: **Pearson r = 0.944, Spearman ρ = 0.937**
(`outputs/a3c_exposure_agreement.csv`). Only 85.1% of ZCTAs stay in the same
exposure quartile (vs. A3a's 97.1%); 88.9% of top-quartile hotspots are
retained (vs. A3a's 94.1%) (`outputs/a3c_quartile_movement.csv`,
`outputs/a3c_hotspot_agreement.csv`). This is exactly the pattern expected:
A3a only changed a *weighting rule* applied to the same input list; A3c
changes the *input geography itself*. 99.3% of ZCTAs in the primary sample
have at least one edge from a real TWDB polygon (`figures/a3c_map_5_pct_edges_from_polygon.png`
shows where). A secondary, genuinely new finding: 11 ZCTAs that had exposure
under Phase 1's ZIP-list method lose it entirely under real-polygon overlay —
their self-reported "served ZIP" does not spatially intersect that PWS's own
mapped boundary at all (`outputs/a3c_top_disagreement_zcta.csv` and the
eligibility/edge tables document which ones).

## A3c.2 — does the cholesterol association survive a real geographic change?

**Yes, essentially unchanged**, despite the exposure surface itself moving
far more than it did under A3a. Correlation with cholesterol: Pearson −0.214 /
Spearman −0.441 (`outputs/a3c_correlation_comparison.csv`) — close to A1's
−0.227 / −0.450. Adjusted standardized β = **−0.095** (p = 4.2×10⁻⁸)
(`outputs/a3c_regression_comparison.csv`), compared to A1's −0.095 and A3a's
−0.090. Adding A3b's source-pressure variables on top of this improved
exposure — the explicit combination this round of work was asked to test —
moves the coefficient only within −0.094 to −0.098 across all five staged
models, all p < 1×10⁻⁶, combined-model VIF = 6.9 (< 10, retained).

## A3c.3 — does the combined "better geography + source context" model resolve the residual spatial autocorrelation?

**No.** Moran's I = 0.282 for A3c alone, 0.272 for A3c + all source families
combined (`outputs/a3c_spatial_residual_check.csv`) — both still highly
significant (p < 1×10⁻⁸⁰), and statistically indistinguishable from A1's
0.278, A3a's 0.280, and A3b's 0.269. Three independent, genuinely different
exposure-side interventions — a different weighting rule (A3a), independent
source-pressure context (A3b), and now a structurally different input
geography (A3c) — have all left this specific number essentially unmoved.

## A3c.4 — what does this mean, given A3c moved the exposure surface more than A3a did?

This is the most informative result of the three A3 sub-pilots, precisely
*because* A3c is the most substantive exposure change tested. If the
cholesterol association or the residual spatial autocorrelation had been
sensitive to exposure-assignment quality, A3c — which actually reshuffles
11% of ZCTAs by quartile and drops 11 ZCTAs entirely — was the most likely
of the three tests to reveal it. It did not. That raises confidence that the
UCMR5–cholesterol association is not primarily an artifact of exposure
assignment noise, **and** it more strongly localizes the unresolved residual
spatial autocorrelation to something other than PWS→ZCTA assignment
granularity or missing industrial-source context — most plausibly
unmeasured spatially-clustered confounders, or genuine spatial structure in
the health outcome itself, neither of which any exposure-side fix tested in
A3a/A3b/A3c could address.

## Bottom line

Real, mapped geographic service-area data — not just a different weighting
assumption — was obtained and used. It changes *where* the exposure hotspots
are (meaningfully) but not *whether* PFAS exposure is associated with
cholesterol, nor *how much* unexplained spatial structure remains in that
association. Combined with A3a and A3b, this closes the three
exposure/context-side follow-ups identified after A1 and A2, and shifts the
open question from "is the exposure assignment good enough" toward "what
else explains the residual spatial pattern" — a different, and for Direction
A's feasibility case arguably more reassuring, kind of open question.

**Main limitation:** the TWDB layer's own review-status field shows 99.98%
of statewide records have not completed TWDB's verification workflow (see
`docs/a3c_twdb_feasibility_note.md`); the density-plausibility check used
here is a reasonable but indirect proxy for geometric accuracy, not a
substitute for TWDB's own eventual verification. The 34 fallback systems and
11 exposure-losing ZCTAs are fully documented, not silently dropped.
