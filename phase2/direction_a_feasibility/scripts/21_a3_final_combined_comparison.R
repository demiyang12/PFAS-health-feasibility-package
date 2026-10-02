# =====================================================================
# 21_a3_final_combined_comparison.R
# Final A1 vs A3a vs A3b vs A3c comparison table -- all four use the
# identical cholesterol outcome / covariates / sample (+-11 ZCTA for A3c,
# documented) / spatial weights; only the exposure representation (or
# added source context) differs per column. Supersedes
# 16_a3_combined_comparison.R (kept as the A1/A3a/A3b-only record).
# =====================================================================
if (!exists("DA_PATHS")) source(if (file.exists("phase2/direction_a_feasibility/scripts/00_setup.R"))
  "phase2/direction_a_feasibility/scripts/00_setup.R" else "00_setup.R")

rd <- function(f) tryCatch(read.csv(file.path(DA_PATHS$outputs, f), stringsAsFactors = FALSE), error = function(e) data.frame())
a3a_reg   <- rd("a3a_regression_comparison.csv")
a3a_spat  <- rd("a3a_spatial_residual_check.csv")
a3a_agree <- rd("a3a_hotspot_agreement.csv")
a3b_reg   <- rd("a3b_regression_comparison.csv")
a3b_spat  <- rd("a3b_spatial_residual_check.csv")
a3b_overlap <- rd("a3b_hotspot_overlap.csv")
a3c_reg   <- rd("a3c_regression_comparison.csv")
a3c_spat  <- rd("a3c_spatial_residual_check.csv")
a3c_agree <- rd("a3c_hotspot_agreement.csv")
a3c_agreement <- rd("a3c_exposure_agreement.csv")
a3c_elig  <- rd("a3c_eligibility_funnel.csv")

pick <- function(df, filters, col) {
  ok <- Reduce(`&`, Map(function(k, v) df[[k]] == v, names(filters), filters))
  x <- df[[col]][ok]
  if (!length(x)) NA else x[1]
}

a1_adj_beta  <- pick(a3a_reg, list(exposure = "A1 baseline", model = "adjusted"), "std_beta")
a1_adj_p     <- pick(a3a_reg, list(exposure = "A1 baseline", model = "adjusted"), "p_value")
a1_moran     <- rd("a1_spatial_residual_check.csv")
a1_moran_val <- pick(a1_moran, list(model = "A1-1 adjusted"), "morans_i")
a3a_hotspot_pct <- pick(a3a_agree, list(definition = "Top quartile (Q4)"), "pct_of_phase1_retained")
a3c_hotspot_pct <- pick(a3c_agree, list(definition = "Top quartile (Q4)"), "pct_of_phase1_retained")
a3c_spearman <- pick(a3c_agreement, list(comparison = "Phase1 vs A3c (TWDB polygon)"), "spearman")

b_betas_str <- if (nrow(a3b_reg)) sprintf("%.3f to %.3f across %d staged models", min(a3b_reg$pfas_std_beta), max(a3b_reg$pfas_std_beta), nrow(a3b_reg)) else NA
c_adj_only  <- a3c_reg$pfas_std_beta[a3c_reg$model != "A3c crude"]
c_betas_str <- if (length(c_adj_only)) sprintf("%.3f to %.3f across %d staged models", min(c_adj_only), max(c_adj_only), length(c_adj_only)) else NA

comp <- data.frame(
  criterion = c(
    "Exposure definition",
    "Nature of the change vs. Phase 1",
    "Exposure agreement with Phase 1 (Spearman)",
    "Top-quartile hotspot retained vs. Phase 1",
    "Adjusted PFAS std. beta range (cholesterol)",
    "Residual Moran's I (adjusted, richest model)",
    "Did this resolve A1's open spatial-autocorrelation question?",
    "Distinctive finding"
  ),
  A1 = c(
    "UCMR5 HI, Phase 1 PWS->ZIP->ZCTA (full population weight per served ZIP)",
    "baseline",
    "-- (baseline)",
    "-- (baseline)",
    sprintf("%.3f (p=%.2g)", a1_adj_beta, a1_adj_p),
    sprintf("%.3f", a1_moran_val),
    "-- (this is the open question)",
    "Strongest, most coherent PFAS-health pairing found in Phase 1 + this branch"
  ),
  A3a = c(
    "Same UCMR5 HI, equal-split population-weighted PWS->ZCTA (still uses the self-reported ZIP list)",
    "Different WEIGHTING RULE applied to the SAME self-reported ZIP-code list",
    "0.997 (barely moves)",
    sprintf("%.1f%%", a3a_hotspot_pct),
    sprintf("%.3f", pick(a3a_reg, list(exposure="A3a alternative", model="adjusted"), "std_beta")),
    sprintf("%.3f", pick(a3a_spat, list(exposure="A3a alternative", model="adjusted"), "morans_i")),
    "No",
    "3/4 of TX systems report exactly 1 ZIP code -- the two weighting rules are mathematically identical for them"
  ),
  A3b = c(
    "Same UCMR5 HI (unchanged) + separate TRI/NPL/NPDES source-pressure indicators, never combined into one score",
    "Added PARALLEL CONTEXT variables; exposure assignment itself untouched",
    "n/a (not an exposure-surface change)",
    "n/a",
    sprintf("%s", b_betas_str),
    sprintf("%.3f", a3b_spat$morans_i[nrow(a3b_spat)]),
    "No",
    "420 of 1,223 ZCTAs (34%) show UCMR5 and source-pressure evidence disagreeing -- useful for case selection"
  ),
  A3c = c(
    "Same UCMR5 HI, reassigned via REAL TWDB-mapped service-area polygons (spatial overlay), 1,120/1,154 systems eligible; 34 fall back to Phase 1's method",
    "Different, structurally new INPUT GEOGRAPHY -- a mapped polygon, not a self-reported ZIP list",
    sprintf("%.3f (moves MORE than A3a)", a3c_spearman),
    sprintf("%.1f%%", a3c_hotspot_pct),
    sprintf("%s", c_betas_str),
    sprintf("%.3f", a3c_spat$morans_i[nrow(a3c_spat)]),
    "No -- despite moving the exposure surface substantially more than A3a",
    "The most substantive exposure change tested, AND the most convergent result: real geography moves WHERE the hotspots are but not the cholesterol finding or its residual spatial structure"
  )
)
write.csv(comp, file.path(DA_PATHS$outputs, "a1_a3a_a3b_a3c_comparison_table.csv"), row.names = FALSE)
cat("\n===== FINAL A1 / A3a / A3b / A3c comparison =====\n")
for (i in seq_len(nrow(comp))) cat(sprintf("\n-- %s --\nA1:  %s\nA3a: %s\nA3b: %s\nA3c: %s\n",
                                           comp$criterion[i], comp$A1[i], comp$A3a[i], comp$A3b[i], comp$A3c[i]))

msg("21_a3_final_combined_comparison.R done")
