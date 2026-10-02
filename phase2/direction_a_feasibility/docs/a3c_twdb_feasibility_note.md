# A3c Feasibility Note — TWDB Service-Area Polygon Dataset

**Script:** `scripts/17_a3c_download_twdb_service_areas.R`.
**Source:** Texas Water Development Board, Water Service Boundary Viewer
(`https://www3.twdb.texas.gov/apps/waterserviceboundaries`), backed by a public,
keyless ArcGIS Server FeatureServer found by inspecting the app's own network
traffic: `https://services2.twdb.texas.gov/server/rest/services/PWS/Public_Water_Service_Areas_Grid/FeatureServer/0`.
All 4,621 statewide polygons downloaded (paginated 1,000/request — the server
enforces a transfer limit below its advertised `maxRecordCount`).

## What was found

**Nominal match rate is excellent. Verification status is poor. The meaning
of the `Source` field is NOT confirmed — see correction below.**

Of Phase 1's 1,154 Texas UCMR5 PWS, 1,130 (97.9%) have a record in this layer
(`outputs/a3c_twdb_match_rate.csv`). This part is a directly observed,
unambiguous fact: the layer's own `STATUS` field, read live from the server,
shows **4,620 of 4,621 statewide records are "Not Started"; only 1 is
"Updated."** TWDB's own Overview page confirms what this tracks: an annual
Water User Survey (WUS) process that prompts each utility to review and
verify its boundary; `STATUS` is that review cycle's progress. As of this
pull, essentially the entire state has not completed a review cycle.

Breaking the 1,130 matched PWS down by the `Source` field recorded on each
polygon:

| Source category | n | % of matched PWS |
|---|---|---|
| `Source == "System"` | 848 | 75.0% |
| `PWS`, `Upload`, CCN, district, city, or CAD-sourced | 267 | 23.6% |
| Other/unclear | 15 | 1.3% |

**Correction — do not over-read the `Source` field.** An earlier version of
this note characterized `Source == "System"` as meaning "algorithmic
placeholder, not credible." That characterization is **not supported by
direct evidence** and was walked back after reading TWDB's public User Guide
(`TWSBV_UserGuide_Public.pdf`, p.15): its own example screenshot of the
internal review grid shows records — including PWS `TX1520067`, the same ID
present in our downloaded data — with `Source == "System"` but `Status ==
"Approved"`, a named human reviewer, a real timestamp, and a logged
`Area Change (%)`. This indicates `Source` most likely records how a
polygon's geometry was *originally drafted* (e.g., system-generated as a
starting point for review), which is tracked **separately** from whether it
has since been *reviewed and approved* — the two are not the same thing, and
`Source == "System"` alone cannot be read as "unreliable." No TWDB
documentation found so far (Overview, Disclaimer, User Guide) gives an
explicit data-dictionary definition of `Source` codes; this remains open.

**What can be stated with confidence:** as of this data pull, 99.98% of
statewide records have not completed TWDB's own verification workflow
(`STATUS == "Not Started"`). What cannot currently be stated with confidence:
that `Source == "System"` by itself implies unreliable or placeholder
geometry — that specific claim lacks documentation and has a direct
counterexample in TWDB's own published materials.

A secondary data-quality note, independent of the above: 233 of 4,621
polygons (5%) fail `st_is_valid()` and would need `st_make_valid()` before any
area/distance calculation.

## Why this matters for Direction A

The whole premise of pursuing this dataset (per `a3a_assignment_methods_inventory.csv`,
method 5) was that it would be **strictly better evidence than any
population-weighting heuristic** tested in A3a, because it is a real,
surveyed geographic boundary rather than a self-reported administrative ZIP
list. The one thing confirmed here is that this premise cannot yet be taken
on faith for the state as a whole: TWDB's own tracking says 99.98% of records
have not completed a verification cycle. Whether any individual
`STATUS == "Not Started"` polygon is nonetheless geometrically accurate is,
honestly, unknown without either (a) a TWDB data dictionary defining what
"Not Started" geometry actually is before review, or (b) spot-checking
specific polygons against independent imagery/known service footprints.

## Recommendation (not yet acted on — awaiting direction)

Three honest ways to proceed, in order of rigor:

1. **Ask TWDB directly** (`WSBViewer@twdb.texas.gov`, listed on the Overview
   page) what a "Not Started" polygon represents before review — e.g.,
   whether it defaults to a CCN/district/city boundary, a buffer around a
   facility point, or something else — and what `Source` codes formally mean.
   This would resolve the open question directly rather than by inference.
2. **Spot-check a sample** of matched PWS polygons against independent
   evidence (satellite imagery, known town/subdivision extent) to get an
   empirical read on whether `STATUS == "Not Started"` geometry looks
   plausible or clearly wrong, before deciding whether to use it at all.
3. **Treat unresolved verification status as a standing caveat, not a
   disqualifier**: rebuild the exposure surface using all 1,130 matched
   polygons, but report results with residual Moran's I and the A3a-style
   agreement statistics as before, explicitly flagging that 99.98% of the
   underlying boundaries are not yet TWDB-verified — the same spirit as
   using UCMR5 itself, a real but imperfect public dataset, throughout this
   project.

No exposure surface has been rebuilt and no regression has been rerun on this
data yet — this note stops at the verification step, consistent with this
project's practice of checking data quality before building on it.
