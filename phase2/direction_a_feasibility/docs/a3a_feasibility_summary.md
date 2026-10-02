# A3a Feasibility Summary — Improved UCMR5 Geographic Assignment

**Pipeline:** `scripts/07_a3a_assignment_inventory.R` through `10_a3a_cholesterol_analysis.R`.
**Comparison:** Phase 1 baseline (`pfas_hi_phase1`: full PWS population weight per served ZIP)
vs. an equal-split population-weighted alternative (`pfas_hi_popwt`: each PWS's population
divided evenly across the ZIP codes it reports serving) — the minimum viable, genuinely
different, fully reproducible comparison identified in `a3a_assignment_methods_inventory.csv`.
A statewide, authoritative PWS service-area polygon dataset (Texas Water Development Board's
Texas Water Service Boundary Viewer) was confirmed to exist but not pulled within this
pilot's time budget — flagged as the highest-value follow-up.

---

## A3a.6 — interpretation

**1. How different is the improved exposure surface from Phase 1?**
Barely different. Pearson r = 0.979, Spearman ρ = 0.997 between the two ZCTA-level Hazard
Index surfaces (`outputs/a3a_exposure_agreement.csv`). 97.1% of ZCTAs land in the exact same
exposure quartile under both methods; the remaining 2.9% move by only one quartile; **none
move by two or three**. Top-decile and top-quartile hotspots overlap at 96.7% and 94.1%
respectively (`outputs/a3a_hotspot_agreement.csv`).

**2. Which communities change the most?**
A small, identifiable set — the 15 ZCTAs with the largest disagreement
(`outputs/a3a_top_disagreement_zcta.csv`) are consistently served by the PWS that report the
most distinct ZIP codes (some as many as 102, vs. a median of 1 across all Texas UCMR5
systems — `outputs/a3a_most_multi_zip_pws.csv`). This is exactly the mechanism the
alternative was designed to test, and it shows up only where that mechanism actually applies:
large, multi-ZIP utilities, which are rare.

**3. Does the PFAS–cholesterol association materially change?**
No. Pearson/Spearman correlation with cholesterol: −0.227/−0.450 (baseline) vs.
−0.214/−0.447 (alternative). Adjusted standardized β: −0.095 (baseline) vs. −0.090
(alternative), both p < 10⁻⁷ (`outputs/a3a_regression_comparison.csv`).

**4. Does residual spatial autocorrelation decrease?**
No, and it does not increase either: Moran's I = 0.278 (baseline, adjusted model) vs. 0.280
(alternative) — statistically indistinguishable (`outputs/a3a_spatial_residual_check.csv`).

**5. Does better assignment improve interpretability?**
Not meaningfully for this specific refinement — the result is simply the same result, now
shown to be robust to one specific assumption.

**6. Or is the health result largely unchanged despite better assignment?**
Unchanged. Every quantity re-computed under the alternative assignment matches the A1
baseline to within normal estimation noise.

**7. Is PWS→community allocation truly a dominant source of uncertainty, or was Phase 1 more robust to this assumption than expected?**
**Phase 1 was more robust to *this particular* assumption than expected.** The reason is
visible in the data: three-quarters of Texas UCMR5 systems report serving exactly one ZIP
code, so the two weighting schemes are mathematically identical for them; only 26 systems
(serving ≥10 ZIP codes each) can differ at all, and they are too few, and too similar on
average, to move the aggregate ZCTA-level picture. **This finding should not be
over-generalized to "the exposure-assignment problem is resolved."** It specifically answers
one narrow question (how to split a multi-ZIP utility's weight across the ZIPs it claims) and
leaves the deeper, structurally different question untouched: whether the UCMR5 "ZIP codes
served" list bears any resemblance to the system's *actual* geographic service area at all —
which is precisely what a real service-area polygon (the TWDB dataset identified but not
pulled here) would test, and why it remains the recommended next check before concluding the
exposure-assignment problem is closed.
