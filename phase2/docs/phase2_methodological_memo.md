# Phase 2 Methodological Memo — Exposure & Outcome Scoping

**Project:** PFAS Drinking-Water Exposure and Obesity-Related Health Outcomes
**Status:** Phase 2 scoping and feasibility assessment. No new regression model has been
run. Phase 1 (Texas, ZCTA-level, UCMR 5 + CDC PLACES + ACS) is preserved unchanged as a
frozen, reproducible record — see [`../README.md`](../README.md) and
[`../docs/methodological_memo.md`](../docs/methodological_memo.md).

> **Interpretation guard-rail (carried over from Phase 1, and stricter here).**
> Everything catalogued below is either (a) a **measured environmental exposure proxy**
> (drinking water, groundwater, tapwater) or (b) a **source-pressure indicator**
> (a facility's existence, type, or self-reported releases — not a measured
> concentration). These are not interchangeable, and neither is an individual exposure
> or dose. All associations remain **ecological and cross-sectional**. No causal claim
> is made or implied anywhere in this memo.

---

## 0. One-paragraph summary

Phase 1's own diagnosis was that **exposure characterization, not model sophistication or
sample size, is the binding constraint** on this project. This scoping
pass evaluated 17 candidate exposure datasets and 12 candidate health outcomes against
that diagnosis. The clearest finding: **the single most valuable, lowest-risk next step
is not a new dataset at all — it is testing how sensitive the Phase 1 result is to the
PWS→ZIP→ZCTA assignment rule that Phase 1 itself flagged as the main limitation**
(Direction C). A parallel, complementary step is to bring in facility-level
**source-pressure** data — EPA TRI, the EPA National PFAS Analytic Tools bundle, and the
EPA Clean Watersheds Needs Survey are all clean, fast, statewide pulls — to explain the
spatial pattern Phase 1 already documented (Direction B). Expanding the **outcome** list
is attractive only where it is nearly free: three additional CDC PLACES measures
(high cholesterol, coronary heart disease, stroke) reuse the exact ZCTA table, join, and
covariates Phase 1 already built, at zero new linkage cost. **Birth outcomes — the
collaborators' other suggested outcome — are not a drop-in extension**: the best public
data (Texas DSHS vital statistics) exist only at county resolution, one full aggregation
level coarser than the ZCTA design this entire project is built around, and would require
a parallel pipeline rather than reusing this one.

---

## 1. Which exposure datasets appear strongest

Full detail, sourcing, and access notes: [`exposure_data_inventory.csv`](exposure_data_inventory.csv)
(17 candidates evaluated).

**Retain as primary / near-term:**

- **EPA TRI (Toxics Release Inventory) — PFAS chemicals.** Facility-level, self-reported
  air/water/land release quantities for up to ~200 PFAS chemicals (expanding under NDAA
  mandates through reporting year 2024). Exact addressable facility coordinates — a
  clean spatial join to ZCTA, no crosswalk ambiguity. This is a **source-pressure**
  measure (release quantity), not an ambient concentration.
- **EPA National PFAS Analytic Tools / ECHO National PFAS Datasets.** A pre-built EPA
  aggregator bundling 12 categories (UCMR, state drinking water, CDR, Water Quality
  Portal, NPDES/DMR, Superfund, federal sites including DoD, industry sectors, RCRA
  transfers, TRI, AFFF spill reports, GHGRP) with a documented public metadata PDF and a
  bulk-download page. Likely the single most efficient starting point for Direction B —
  worth a direct data pull before assembling the other sources piecemeal.
- **EPA Clean Watersheds Needs Survey (CWNS) + National Sewershed Dataset.** ~17,000
  POTWs nationally with clean point/polygon geometry, state-filterable, updated
  periodically since 1984. Operationalizes the "wastewater/biosolids" pathway named in
  the reply-email direction, though it identifies *where infrastructure exists*, not
  *whether PFAS is present* — needs pairing with TRI or DMR data for actual evidence.

**Retain as secondary / triangulation:**

- **USGS PFAS National Tapwater Reconnaissance** (716 US sites, 2016–2022, actually
  measured, 34 analytes) and **EPA Water Quality Portal** (aggregated surface/groundwater
  monitoring) — both real measured data, both far too geographically sparse in Texas
  alone to serve as a primary layer, but useful as an independent check on whether
  UCMR5-based exposure agrees with other measurements where they happen to overlap.
- **EPA NPDES/DMR PFAS discharge monitoring**, **EPA Superfund NPL Texas sites**, and the
  **Northeastern PFAS Project Lab Known + Presumptive Contamination Site Tracker**
  (~2,200 known + ~79,891 presumptive sites nationally, 2025 update) — all real and
  relevant, but each has a specific access or scope caveat (sparse/recent PFAS DMR
  coverage; PFAS-relevance not a clean queryable field on NPL sites yet; bulk
  downloadability of the Presumptive Contamination dataset not yet confirmed).
- **DoD PFAS installation investigations** — narratively the most compelling Texas
  evidence found in this pass. Groundwater concentrations at Texas military
  installations run **orders of magnitude above** anything in the Phase 1 UCMR5
  drinking-water dataset (e.g., Joint Base San Antonio–Lackland groundwater reported at
  roughly 680,000 ppt, versus Phase 1's set of only 19 Texas ZCTAs with any MCL
  exceedance at all). This is a concrete, well-sourced illustration of exactly why a
  drinking-water-only proxy under-represents exposure intensity near known source zones
  — but the data exist mainly as narrative PDF reports (GAO, OSD, base fact sheets), not
  a structured download, so using it well means manual extraction, not a quick pull.

**Excluded for now (checked and found unusable at this stage), or not yet checked:**

- **Private well testing**, **soil/sediment PFAS**, and **ambient air PFAS monitoring**
  — no systematic public Texas dataset exists for any of these three; they are not
  omissions, they were checked and found absent or reducible to data already listed
  above (TRI's air-release field; the sparse USGS reconnaissance's private-well points).
- **TCEQ's own PFAS compliance monitoring** does not exist yet as a dataset distinct from
  UCMR5 — Texas compliance monitoring under EPA's 2024 rule does not begin until April
  2027. Nothing to add here before then.
- **Landfill inventory (EPA LMOP/FRS)** — named by the research team but **not yet
  verified in this pass**; flagged in the inventory as a specific follow-up item rather
  than assumed usable.

---

## 2. Which health outcomes appear strongest

Full detail: [`outcome_data_inventory.csv`](outcome_data_inventory.csv) (12 candidates
evaluated).

**Retain — effectively free:** Three additional CDC PLACES measures — **high
cholesterol** (adults ever screened), **coronary heart disease**, and **stroke** — live
in the exact same ZCTA-level PLACES file, join, and covariate set Phase 1 already
integrates. Adding them costs nothing beyond re-running the existing pipeline with three
extra columns. High cholesterol in particular is a direct, low-cost answer to the
advisor's own suggestion to look at "more direct health indicators."

**Confirmed excluded (do not assume otherwise):** As instructed, this was checked rather
than assumed — **CDC PLACES contains no birth, pregnancy, or infant outcome of any kind.**
It is structurally incapable of this: PLACES is built entirely from BRFSS, an adult
telephone survey. Chronic kidney disease, formerly in PLACES, was **discontinued in the
2024 release** and is excluded to avoid mixing data vintages.

**Deferred — real data, wrong geography:** Low birth weight, preterm birth, and (least
confirmed) small-for-gestational-age are available for Texas through the **Texas DSHS**
Center for Health Statistics (Vital Statistics Annual Reports, Texas Health Data
dashboards) — a better source than the national CDC WONDER Natality query, which
suppresses any county under roughly 100,000 population into an "Unidentified Counties"
category. But even the Texas DSHS source is published at **county of maternal
residence**, not ZCTA. That is one full aggregation level coarser than the geography
this entire project is built around, and it would discard most of the spatial detail
Phase 1 was designed to exploit. Small-for-gestational-age is additionally **not
confirmed to exist as a public aggregate table at all** — it is derivable from birth
weight and gestational age, which typically means it lives only in restricted-use
birth-certificate microdata, not an open download.

**Explicitly out of scope:** Biomarkers (serum PFAS, individual lipid panels, A1c, blood
pressure readings) are exactly the advisor's "more direct" suggestion, but by definition
they are **individual-level, not community-level public data** — this is the planned
Phase 4 individual-level biomarker study, not a Phase 2 public-data task. Noted here so
the connection to the advisor's question is on record, not silently dropped.

---

## 3. Which of Directions A / B / C currently looks most promising

Full scoring and rationale: [`decision_matrix.csv`](decision_matrix.csv).

**Recommended primary direction: C — exposure-assignment methodology.**
It uses only data already in hand (Phase 1's UCMR5/SDWIS/ZIP-ZCTA crosswalk), requires no
new external dataset to be acquired or vetted under time pressure, and directly
operationalizes the project's own stated lesson: *"improve exposure characterization
before increasing model complexity."* Whichever way a sensitivity comparison of
assignment rules (exact ZIP match vs. a population/area-weighted crosswalk vs. one or
two manually-digitized service areas as case studies) comes out, the result is a clean,
quantified, exportable methodological finding — useful to the field even independent of
what it says about obesity, diabetes, or hypertension specifically.

**Recommended secondary / parallel direction: B — exposure geography / source
attribution**, scoped narrowly to the three cleanest datasets found (TRI, CWNS,
Superfund). This both stands alone as a "what explains the spatial pattern" narrative
and directly feeds Direction C: better source-pressure data makes the assignment-rule
sensitivity tests more informative.

**Direction A — new outcome, same design — recommended only in its low-cost form**: add
the three free PLACES measures as supporting evidence across a wider outcome set, and
explicitly **defer** the birth-outcome variant past the APHA meeting given the
county/ZCTA mismatch documented above. Pursuing birth outcomes now would mean building a
second, parallel, county-level pipeline under time pressure — a substantially different
and larger undertaking than "adding an outcome."

This recommendation should **not** be read as final — it is the scoping-stage judgment
call the decision matrix was built to support, and it is explicitly open to revision once
the follow-up checks in Section 4 are done. See [`decision_log.md`](decision_log.md) for
the running record of this and future decisions.

---

## 4. What additional evidence is needed before the final decision

1. **Confirm the EPA National PFAS Analytic Tools bulk-download contents for Texas** —
   this single check could substantially shorten the work needed for Direction B.
2. **Pull TRI, CWNS, and Superfund NPL for Texas specifically** and get real facility
   counts (the inventory currently says "not yet extracted" for all three).
3. **Verify EPA LMOP/landfill data** — named by the research team, not yet checked at
   all in this pass.
4. **Confirm Texas DSHS's small-cell suppression threshold** for birth outcomes, to know
   how many TX counties would actually be usable if a county-level companion analysis is
   pursued later.
5. **Confirm whether the Presumptive Contamination Site Tracker's underlying data is
   bulk-downloadable** or requires a direct request to the Northeastern research team.
6. **Decide the Direction C comparison set** explicitly before writing code: which
   assignment alternatives (population-weighted crosswalk, HUD USPS crosswalk, UDS
   Mapper, manually-digitized case-study service areas) are in scope for the APHA
   timeline versus deferred.
7. **Pre-register the spatial questions** from the original scoping brief (hotspot
   agreement across exposure representations, uncertainty mapping, sampling
   prioritization) as the analysis plan for whichever direction is chosen, before writing
   model code — consistent with Phase 1's practice of documenting decisions before
   running them.

Until these are resolved, Phase 2 remains in the scoping stage: **no health-regression
model has been run, and none should be, until a single primary direction and its
exposure/outcome pairing are confirmed.**
