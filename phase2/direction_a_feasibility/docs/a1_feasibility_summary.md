# A1 Feasibility Summary — UCMR5 PFAS + CDC High Cholesterol (ZCTA)

**Pipeline:** `scripts/01_a1_read_cholesterol.R`, `02_a1_analysis.R`.
**Sample:** n = 1,223 Texas ZCTAs — identical to Phase 1's primary analytic sample; cholesterol
has 0% missingness in that sample, so swapping the outcome cost no sample size at all.
**Exposure:** Phase 1's exposure, completely unchanged (`pfas_hazard_index`, `pfas_hi_log` =
log(1+Hazard Index) as primary).

This is a feasibility pilot, not an epidemiologic conclusion. Ecological, cross-sectional;
no causal claim.

---

## A1.1 — verified, not assumed

The Phase 2 scoping inventory stated the PLACES high-cholesterol measure was BRFSS 2021.
**That assumption did not survive a check against the actual downloaded data.** The live
pull (`docs/a1_places_metadata.csv`) shows the 2025 PLACES release uses **BRFSS 2023** for
cholesterol — the same year as obesity, diabetes, and hypertension. The mechanism: cholesterol
is a BRFSS *Rotating Core* question asked only in odd years (2021, 2023, …); the 2025 PLACES
release uses whichever odd-year wave was most recently available, which is 2023, not 2021.
**This removes what would otherwise have been a temporal-mismatch concern for A1.**

---

## A1.7 — interpretation

**1. Is cholesterol spatially and statistically more aligned with PFAS than the Phase 1 outcomes?**
Yes, on every measure computed. Unadjusted Spearman correlation with the Hazard Index is
−0.450 — in the same range as hypertension (Phase 1's strongest outcome, −0.465) and well
beyond obesity (−0.245) and diabetes (−0.344). After SES adjustment, cholesterol's partial
correlation (−0.086) and adjusted standardized β (−0.095, p = 3.4×10⁻⁸) are **larger in
magnitude and more significant than all three Phase 1 outcomes** (`outputs/a1_correlation_vs_phase1.csv`,
`outputs/a1_phase1_adjusted_for_comparison.csv`).

**2. Does socioeconomic adjustment strongly attenuate the association?**
Yes — the standardized β falls from −0.260 (crude) to −0.095 (adjusted), a 63% reduction
(`outputs/a1_regression.csv`). This is the same qualitative pattern Phase 1 found for every
outcome: a sizeable crude ecological association that is mostly, but not entirely, explained
by income/education/race-ethnicity/age/density.

**3. Is the coefficient direction reasonably stable?**
Yes. Unlike the Phase 1 obesity result (which flipped sign between OLS and the spatial-error
model), cholesterol's association is **negative at every step** — crude, adjusted, and (see
below) does not reverse under the residual spatial check.

**4. Does substantial residual spatial autocorrelation remain?**
Yes, and it is large. Residual Moran's I = 0.427 (crude model) and 0.278 (adjusted model),
both with p-values effectively zero (`outputs/a1_spatial_residual_check.csv`). A full study
on this pairing would need spatial modelling (spatial-error at minimum), exactly as Phase 1
concluded for obesity/diabetes/hypertension.

**5. Does the temporal mismatch between PLACES cholesterol and UCMR5 undermine interpretation?**
No longer a distinguishing concern — see A1.1 above. (The general ecological/cross-sectional
caveats that apply to all of Phase 1's outcomes still apply equally here.)

**6. Does A1 provide evidence that changing the OUTCOME solves the Phase 1 problem?**
**No.** Cholesterol is a materially *better-behaved* outcome than obesity/diabetes/hypertension
on every metric tested, but the residual spatial autocorrelation it leaves behind is just as
large, and the underlying exposure variable is byte-for-byte the same PWS→ZIP→ZCTA-derived
Hazard Index Phase 1 already flagged as its core limitation. A stronger, more stable,
more significant outcome-side result does not change what the exposure variable actually
measures or how it was geographically assigned.

**7. Does the same exposure-characterization problem remain dominant?**
Yes. The outcome swap improved the *outcome* side of the model; it did nothing to the
*exposure* side, which is where Phase 1 located the binding constraint.

---

## Bottom line for A1

Cholesterol is the single most coherent ZCTA-level PFAS–health pairing found across Phase 1
and this pilot combined. That is a genuine, useful finding (and a direct, verified answer to
the advisor's original question). It is **not**, on its own, evidence that Direction A is
ready for a full study — the exposure side still needs the improvement Phase 2 already
prioritized (Direction C). See `direction_a_feasibility_memo.md` for how this combines with A2.
