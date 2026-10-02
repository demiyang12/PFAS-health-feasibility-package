# =====================================================================
# 16_a3_combined_comparison.R
# Final A1 vs A3a vs A3b comparison table, all using the identical
# cholesterol outcome / covariates / sample / spatial weights -- only the
# exposure representation (or added source context) differs per column.
# =====================================================================
if (!exists("DA_PATHS")) source(if (file.exists("phase2/direction_a_feasibility/scripts/00_setup.R"))
  "phase2/direction_a_feasibility/scripts/00_setup.R" else "00_setup.R")

rd <- function(f) tryCatch(read.csv(file.path(DA_PATHS$outputs, f), stringsAsFactors = FALSE), error = function(e) data.frame())
a1_spat     <- rd("a1_spatial_residual_check.csv")
a3a_reg     <- rd("a3a_regression_comparison.csv")
a3a_spat    <- rd("a3a_spatial_residual_check.csv")
a3a_agree   <- rd("a3a_hotspot_agreement.csv")
a3a_cor     <- rd("a3a_correlation_comparison.csv")
a3b_reg     <- rd("a3b_regression_comparison.csv")
a3b_spat    <- rd("a3b_spatial_residual_check.csv")
a3b_overlap <- rd("a3b_hotspot_overlap.csv")

# exact two-key lookups (never rely on row position / first-match)
pick <- function(df, filters, col) {
  ok <- Reduce(`&`, Map(function(k, v) df[[k]] == v, names(filters), filters))
  x <- df[[col]][ok]
  if (!length(x)) NA else x[1]
}

a1_adj_beta  <- pick(a3a_reg, list(exposure = "A1 baseline", model = "adjusted"), "std_beta")
a1_adj_p     <- pick(a3a_reg, list(exposure = "A1 baseline", model = "adjusted"), "p_value")
a3a_adj_beta <- pick(a3a_reg, list(exposure = "A3a alternative", model = "adjusted"), "std_beta")
a3a_adj_p    <- pick(a3a_reg, list(exposure = "A3a alternative", model = "adjusted"), "p_value")
a1_moran     <- pick(a1_spat, list(model = "A1-1 adjusted"), "morans_i")
a3a_moran    <- pick(a3a_spat, list(exposure = "A3a alternative", model = "adjusted"), "morans_i")
a3a_spearman <- pick(a3a_cor, list(exposure = "pfas_hazard_index_popwt (A3a alternative)"), "spearman")
a1_spearman  <- pick(a3a_cor, list(exposure = "pfas_hazard_index_phase1 (A1 baseline)"), "spearman")
a3a_hotspot_pct <- pick(a3a_agree, list(definition = "Top quartile (Q4)"), "pct_of_phase1_retained")

overlap_str <- if (nrow(a3b_overlap)) paste(sprintf("%s=%d", a3b_overlap$classification, a3b_overlap$n), collapse = "; ") else "see a3b_hotspot_overlap.csv"
b_betas_str <- if (nrow(a3b_reg)) paste(sprintf("%s: %.3f (p=%.3g)", a3b_reg$model, a3b_reg$pfas_std_beta, a3b_reg$pfas_p), collapse = " | ") else "see a3b_regression_comparison.csv"
a3b_moran_combined <- if (nrow(a3b_spat) >= 2) a3b_spat$morans_i[nrow(a3b_spat)] else NA
a3b_moran_base     <- if (nrow(a3b_spat) >= 1) a3b_spat$morans_i[1] else NA

comp <- data.frame(
  criterion = c("Exposure definition", "Geographic assignment quality", "Exposure contrast (ZCTA HI IQR)",
                "ZCTA coverage (primary sample)", "Correlation with cholesterol (Spearman)",
                "Adjusted PFAS std. beta (p-value)", "Crude -> adjusted stability", "Residual Moran's I (adjusted)",
                "Hotspot agreement with A1 baseline", "Interpretability", "Main limitation"),
  A1 = c(
    "UCMR5 Hazard Index, Phase 1 PWS->ZIP->ZCTA assignment (full-population weight per served ZIP)",
    "Baseline -- documented limitation (many-to-many PWS<->ZCTA; ZIP-served != service area)",
    "0.0127 (baseline)", "1,223 ZCTA",
    sprintf("%.3f", a1_spearman),
    sprintf("%.3f (p=%.3g)", a1_adj_beta, a1_adj_p),
    "Attenuates 63% crude->adjusted, sign stable",
    sprintf("%.3f", a1_moran),
    "n/a (this is the baseline)",
    "Clear, matches Phase 1's own pattern",
    "Same PWS->ZIP->ZCTA assignment Phase 1 already flagged"
  ),
  A3a = c(
    "Same UCMR5 Hazard Index, equal-split population-weighted PWS->ZCTA assignment",
    "Tested alternative; a real statewide PWS service-area dataset (TWDB) was found but not used this pass",
    "0.0170 (equal-split alt.)", "1,223 ZCTA (unchanged)",
    sprintf("%.3f", a3a_spearman),
    sprintf("%.3f (p=%.3g)", a3a_adj_beta, a3a_adj_p),
    "Attenuates similarly, sign stable",
    sprintf("%.3f", a3a_moran),
    sprintf("%.1f%% of A1's top-quartile ZCTAs retained", a3a_hotspot_pct),
    "Unchanged from A1 -- this assignment refinement did not matter",
    "Tests only ONE assignment refinement; the deeper service-area question (TWDB) remains open"
  ),
  A3b = c(
    "Same UCMR5 Hazard Index (unchanged) + separate TRI/NPL/NPDES source-pressure indicators, never combined into one score",
    "n/a -- does not change exposure assignment; adds parallel source-pressure context",
    "n/a (source variables are counts/distances/releases, not a PFAS concentration)",
    "1,223 ZCTA (unchanged)",
    "n/a by design -- source variables are compared to UCMR5 exposure, not substituted for cholesterol's exposure term",
    b_betas_str,
    "UCMR5 coefficient stable across all source-adjusted models (see exact values at left)",
    sprintf("baseline %.3f -> richest source-adjusted model %.3f", a3b_moran_base, a3b_moran_combined),
    overlap_str,
    "Explains WHERE pressure is high; does not replace UCMR5 as the exposure measure",
    "Source-pressure variables are not PFAS concentration measurements -- kept strictly separate (A3b.2)"
  )
)
write.csv(comp, file.path(DA_PATHS$outputs, "a1_a3a_a3b_comparison_table.csv"), row.names = FALSE)
cat("\n===== Final A1 / A3a / A3b comparison =====\n")
for (i in seq_len(nrow(comp))) cat(sprintf("\n-- %s --\nA1:  %s\nA3a: %s\nA3b: %s\n", comp$criterion[i], comp$A1[i], comp$A3a[i], comp$A3b[i]))

msg("16_a3_combined_comparison.R done")
