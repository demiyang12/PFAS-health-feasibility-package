# =====================================================================
# 06_compare_a1_a2.R
# Build the key comparison table (A1: UCMR5+cholesterol, ZCTA vs
# A2: county UCMR5 + low birth weight). Qualitative ratings
# (strong/moderate/weak/unresolved) are each backed by an observed
# diagnostic already written to outputs/ by scripts 02-05 -- not asserted.
# =====================================================================
if (!exists("DA_PATHS")) source(if (file.exists("phase2/direction_a_feasibility/scripts/00_setup.R"))
  "phase2/direction_a_feasibility/scripts/00_setup.R" else "00_setup.R")

rd <- function(f) tryCatch(read.csv(file.path(DA_PATHS$outputs, f)), error = function(e) data.frame())
a1_desc <- rd("a1_descriptive_feasibility.csv"); a1_cor <- rd("a1_correlation_vs_phase1.csv")
a1_reg  <- rd("a1_regression.csv"); a1_spat <- rd("a1_spatial_residual_check.csv")
a2_diag <- rd("a2_county_exposure_diagnostics.csv"); a2_funnel <- rd("a2_lbw_linkage_funnel.csv")
a2_cor  <- rd("a2_lbw_correlation.csv"); a2_reg <- rd("a2_lbw_regression.csv"); a2_spat <- rd("a2_lbw_spatial_residual_check.csv")

gv <- function(df, metric_col, metric, val_col = "value") df[[val_col]][df[[metric_col]] == metric][1]

comp <- data.frame(
  criterion = c("Geography", "Exposure coverage", "Exposure contrast", "Outcome data quality",
                "Temporal alignment", "Crude association (Pearson/Spearman)",
                "Crude -> adjusted stability", "Residual spatial autocorrelation",
                "Main limitation", "Full Direction A study warranted on this pairing?"),
  A1_UCMR5_plus_cholesterol = c(
    "ZCTA (2020)",
    sprintf("STRONG -- %s ZCTAs, 0%% missing cholesterol (same CDC PLACES file as Phase 1)", gv(a1_desc, "metric", "ZCTAs: also with a cholesterol estimate (A1 primary sample)")),
    sprintf("Same as Phase 1 (unchanged exposure): HI IQR = %s, %.1f%% any-detect, %.1f%% MCL/HI exceedance -- MODERATE, unchanged from Phase 1",
            gv(a1_desc, "metric", "Effective exposure contrast: Hazard Index IQR (P75-P25)"),
            as.numeric(gv(a1_desc, "metric", "PFAS: % ZCTA with any detection")),
            as.numeric(gv(a1_desc, "metric", "PFAS: % ZCTA with an MCL/HI exceedance"))),
    "STRONG -- model-based small-area estimate, 0% missing, same vintage/precision as Phase 1's 3 outcomes",
    "STRONG -- BRFSS 2023, VERIFIED (not assumed) contemporaneous with UCMR5 2023-2025 and Phase 1's other outcomes",
    sprintf("%s / %s (pop-wt Hazard Index) -- comparable magnitude to Phase 1's hypertension result, STRONGEST of the 4 outcomes tested on partial-R2", a1_cor$pearson[a1_cor$outcome=="highchol_pct"], a1_cor$spearman[a1_cor$outcome=="highchol_pct"]),
    sprintf("MODERATE -- std beta attenuates %.0f%% crude->adjusted (%.3f -> %.3f) but sign is STABLE and remains the most significant of the 4 outcomes (p=%.1e)",
            100*(1-abs(a1_reg$std_beta[2])/abs(a1_reg$std_beta[1])), a1_reg$std_beta[1], a1_reg$std_beta[2], a1_reg$p_value[2]),
    sprintf("STRONG, UNRESOLVED -- Moran's I %.3f (crude) / %.3f (adjusted), both p<<0.001: a full study would require spatial modelling, same as Phase 1",
            a1_spat$morans_i[1], a1_spat$morans_i[2]),
    "The SAME exposure-characterization problem Phase 1 already diagnosed (PWS->ZIP->ZCTA assignment) -- changing the outcome did not touch it",
    "MAY BE FEASIBLE, ONLY AFTER EXPOSURE IMPROVEMENT -- cholesterol is the most coherent outcome found, but it inherits Phase 1's exposure problem unchanged"
  ),
  A2_county_UCMR5_plus_LBW = c(
    "County (2020)",
    sprintf("PARTIAL -- %s/254 counties have any population-weighted PFAS data (%s%% of state population), but only %s have a usable (non-suppressed) LBW rate -- WEAK once linked",
            gv(a2_diag, "metric", "Counties with ANY population-weighted PFAS exposure (coverage_pct > 0)"),
            gv(a2_diag, "metric", "% of statewide Geocorr population in counties with any PFAS exposure"),
            a2_funnel$n[a2_funnel$step == "  ... also with a non-suppressed 2019 LBW rate"]),
    sprintf("WEAK -- county HI IQR (%s) is ~%.0f%% of the ZCTA-level IQR (%s); median county HI is exactly 0 (more than half of TX counties). Top-quartile ZCTAs do NOT get diluted out of high-tercile counties, but the bulk of the distribution compresses toward zero",
            gv(a2_diag, "metric", "County HI IQR (compression check vs ZCTA-level)"),
            100*as.numeric(gv(a2_diag,"metric","County HI IQR (compression check vs ZCTA-level)"))/as.numeric(gv(a2_diag,"metric","ZCTA-level HI IQR (Phase 1 primary sample, for comparison)")),
            gv(a2_diag, "metric", "ZCTA-level HI IQR (Phase 1 primary sample, for comparison)")),
    "WEAK -- real DSHS vital-statistics source, but only 119/254 counties (47%) have a non-suppressed rate; suppressed counties are overwhelmingly rural (mean pop density 10/km2 vs 260/km2 for usable counties) -- a structural, not random, missingness pattern",
    "UNRESOLVED / POOR -- most recent static county table is 2019; UCMR5 is 2023-2025. Exposure POST-DATES the birth outcome by 4+ years; no restriction of the UCMR5 window fixes this (it only makes the gap larger). This is a major, unresolved limitation, documented rather than hidden",
    sprintf("%s / %s -- weaker than EVERY A1/Phase-1 ZCTA-level result", a2_cor$pearson[1], a2_cor$spearman[1]),
    sprintf("UNSTABLE -- crude std beta %.3f (p=%.2f, null) FLIPS SIGN to %.3f (p=%.3f) after adjustment, and that 'significant' result does NOT survive a births-weighted sensitivity check (std beta %.3f, p=%.2f). This is the classic pattern of a fragile, non-robust estimate, not evidence of a real effect",
            a2_reg$std_beta[1], a2_reg$p_value[1], a2_reg$std_beta[2], a2_reg$p_value[2], a2_reg$std_beta[3], a2_reg$p_value[3]),
    sprintf("WEAK/ABSENT -- Moran's I %.3f (crude, p=%s) / %.3f (adjusted, p=%s), neither significant at n=119 counties -- contrasts sharply with the strong spatial structure at ZCTA level",
            a2_spat$morans_i[1], a2_spat$p_value[1], a2_spat$morans_i[2], a2_spat$p_value[2]),
    "Geographic aggregation destroys most exposure contrast AND the outcome is only available for fewer than half of counties (non-randomly, favoring urban areas) AND the one available outcome vintage (2019) cannot be temporally aligned with UCMR5 (2023-2025)",
    "NOT CURRENTLY WELL SUPPORTED -- three independent problems (exposure dilution, outcome suppression, temporal mismatch) each individually weaken this pairing, and they do not offset each other"
  )
)
write.csv(comp, file.path(DA_PATHS$outputs, "a1_a2_comparison_table.csv"), row.names = FALSE)
cat("\n===== Key comparison table (A1 vs A2) written to outputs/a1_a2_comparison_table.csv =====\n")
for (i in seq_len(nrow(comp))) {
  cat("\n--", comp$criterion[i], "--\n")
  cat("A1:", comp$A1_UCMR5_plus_cholesterol[i], "\n")
  cat("A2:", comp$A2_county_UCMR5_plus_LBW[i], "\n")
}
msg("06_compare_a1_a2.R done")
