# A3b Feasibility Summary — Source-Pressure Context (TRI / NPL / NPDES)

**Pipeline:** `scripts/11_a3b_source_data_inventory.R` through `15_a3b_cholesterol_analysis.R`.
**Real Texas data pulled** (`scripts/12_a3b_download_source_data.R`): 152 TRI PFAS-specific
reporting-form records at 15 distinct Texas facilities (2020–2024 reporting years, 196
chemicals screened via `tri_chem_info`'s `pfas_ind` flag), 1,452 associated release-quantity
line items, 56 Superfund NPL sites, and 129,682 NPDES-permitted facilities (used in place of
CWNS — CWNS's 2022 data-download tool is an interactive-only APEX app with no scripted bulk
URL found; this substitution is documented, not silent — see
`docs/a3b_source_inventory_verified.csv`).

**Category separation maintained throughout** (per A3b.6 — never combined into a composite
score):
- **Category A — measured PFAS concentration:** UCMR5 Hazard Index, unchanged from A1/Phase 1.
- **Category B — reported PFAS release:** TRI PFAS-specific reporting (facility × chemical ×
  year), release quantities in lb.
- **Category C — source/pathway indicators (not PFAS-specific):** Superfund NPL proximity,
  NPDES facility density.

---

## A3b.7 — interpretation

**1. Does source-pressure data explain UCMR5's spatial exposure pattern?**
No. Correlations between the UCMR5 Hazard Index and every source-pressure variable are
negligible: Pearson r ranges −0.006 to 0.032, Spearman ρ 0.077 to 0.377
(`outputs/a3b_exposure_source_correlations.csv`). The strongest relationship — NPDES facility
density (Spearman 0.377) — is almost certainly an urbanization proxy (more permitted
facilities where there is more people/industry generally) rather than a PFAS-specific pathway
signal, since NPDES carries no PFAS flag.

A more specific, counter-intuitive pattern: ZCTAs with a PFAS-reporting TRI facility within
20km have a **lower** mean Hazard Index (0.0497) than those without (0.0669), but a much
**higher** any-detect rate (98.5% vs. 75.4%) (`outputs/a3b_exposure_by_source_presence.csv`).
A nearby PFAS-TRI facility predicts whether PFAS is detected at all, not how concentrated it
is — consistent with the Hazard Index being driven by a small number of specific
high-contributing sources that do not map cleanly onto the 15-facility TRI-reporting list.

**2. Does source-pressure data help interpret the cholesterol association?**
Only as context, not as an explanation. The UCMR5 standardized β is essentially unchanged
across every staged model — baseline −0.095, +TRI −0.097, +NPDES −0.095, +NPL −0.093,
combined −0.095, all p < 1e-6 (`outputs/a3b_regression_comparison.csv`). A combined model was
feasible (max VIF 6.91 < 10) and changed nothing. None of the source-pressure variables
confound, mediate, or suppress the UCMR5–cholesterol relationship in this sample.

**3. Did residual spatial autocorrelation decrease once source-pressure context was added?**
Barely: Moran's I 0.278 (baseline) → 0.269 (combined, richest model)
(`outputs/a3b_spatial_residual_check.csv`) — both still highly significant (p < 1e-78). The
spatial structure in the cholesterol residuals is not explained by TRI/NPL/NPDES proximity; it
reflects something else — unmeasured spatial confounding, remaining exposure-assignment error,
or genuinely spatially clustered health determinants.

**4. What does the 2×2 hotspot overlap show?**
Of 1,223 ZCTAs: 96 are high-UCMR5 + high-source-pressure (mutually reinforcing); 707 are
low + low (also reinforcing); 210 are high-UCMR5 + low-source-pressure and another 210 are
low-UCMR5 + high-source-pressure — i.e., **420 ZCTAs (34%) show disagreement** between the two
kinds of evidence (`outputs/a3b_hotspot_overlap.csv`, `figures/a3b_map_hotspot_overlap.png`).
These disagreement cells cluster near major metro areas (Dallas–Fort Worth, Houston, San
Antonio), where industrial/TRI presence and drinking-water PFAS detection do not necessarily
coincide at the ZCTA level. This is exactly the kind of case where source-pressure data adds
genuinely new information that UCMR5 alone would miss — useful for flagging specific places for
follow-up — even though it does not change the regression result.

**5. Was a composite PFAS score created?**
No. Measured concentration (UCMR5 HI), reported release (TRI lb), and pathway indicators (NPL,
NPDES) were kept as separate variables throughout the inventory, indicator-building, spatial
comparison, and regression steps. The 2×2 classification's `src_pressure_rank` is explicitly a
rank used only to split source variables into high/low for the 4-way table — it was never used
as, or substituted for, an exposure variable in any model.

---

## Bottom line

Source-pressure data (TRI/NPL/NPDES) does **not** explain UCMR5's spatial exposure pattern,
does **not** change the PFAS–cholesterol association, and does **not** meaningfully reduce
residual spatial autocorrelation. Its demonstrated value is as independent, corroborating-or-
disconfirming context at specific locations — the 420 ZCTAs where the two evidence types
disagree — useful for case selection or qualitative follow-up, not as a substitute or
correction for the UCMR5 exposure measure.

**Main limitation:** Texas TRI PFAS reporting is extremely sparse — only 15 facilities
statewide reported any of the 196 TRI-tracked PFAS chemicals across 2020–2024. This limits
this analysis's power to detect a true TRI–UCMR5 relationship even if one existed; the
near-zero correlation should be read as "no relationship detectable with 15 reporting
facilities," not as definitive proof that industrial PFAS sources are irrelevant to drinking-
water exposure. NPDES was used as a documented substitute for CWNS and is a generic
discharge-pathway indicator, not a PFAS-specific or wastewater-infrastructure-need measure.
