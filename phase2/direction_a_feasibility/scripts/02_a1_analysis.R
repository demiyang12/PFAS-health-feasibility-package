# =====================================================================
# 02_a1_analysis.R
# A1 -- UCMR5 PFAS (Phase 1, unchanged) + CDC high cholesterol, ZCTA level
#   A1.2 exposure (reuse Phase 1 definitions)  A1.3 descriptive feasibility
#   A1.4 correlation vs Phase 1 outcomes       A1.5 crude/adjusted regression
#   A1.6 spatial residual check                A1.7 interpretation numbers
# No GWR / MGWR / PSM / Bayesian / ML. Ecological, cross-sectional; no
# causal claim.
# =====================================================================
if (!exists("DA_PATHS")) source(if (file.exists("phase2/direction_a_feasibility/scripts/00_setup.R"))
  "phase2/direction_a_feasibility/scripts/00_setup.R" else "00_setup.R")
suppressPackageStartupMessages({library(sf); library(ggplot2)})
old_ggsave <- ggplot2::ggsave; ggsave <- function(...) old_ggsave(..., bg = "white")
have <- function(p) requireNamespace(p, quietly = TRUE)

## ---- A1.2: exposure = Phase 1's existing ZCTA table, unmodified -----
base <- readRDS(file.path(PATHS$processed, "texas_zcta_analytical.rds"))
chol <- readRDS(file.path(DA_PATHS$processed, "a1_cholesterol_zcta.rds"))
d_all <- dplyr::left_join(base, chol, by = "zcta")

d <- d_all[d_all$analytic_primary == 1 & !is.na(d_all$highchol_pct), ]
d <- sf::st_transform(d, 5070)
d <- d[!sf::st_is_empty(d), ]
D <- sf::st_drop_geometry(d)
msg("A1 primary sample: n = %d (Phase 1 primary sample was %d ZCTAs)", nrow(D), sum(base$analytic_primary == 1))

## ---- A1.3: descriptive feasibility checks ---------------------------
feas <- data.frame(metric = character(), value = character())
addf <- function(m, v) feas <<- rbind(feas, data.frame(metric = m, value = as.character(v)))
addf("ZCTAs: Phase 1 primary sample (PFAS+health+ACS+pop>=500)", sum(base$analytic_primary == 1))
addf("ZCTAs: also with a cholesterol estimate (A1 primary sample)", nrow(D))
addf("Cholesterol: mean / sd (%)", sprintf("%.1f / %.1f", mean(D$highchol_pct), sd(D$highchol_pct)))
addf("Cholesterol: min / median / max (%)", sprintf("%.1f / %.1f / %.1f", min(D$highchol_pct), median(D$highchol_pct), max(D$highchol_pct)))
addf("PFAS Hazard Index: mean / median / max", sprintf("%.3f / %.3f / %.3f", mean(D$pfas_hazard_index), median(D$pfas_hazard_index), max(D$pfas_hazard_index)))
addf("PFAS: % ZCTA with any detection", round(100 * mean(D$pfas_any_detect), 1))
addf("PFAS: % ZCTA non-detect-dominated (0 compounds detected)", round(100 * mean(D$pfas_n_detected_popwt == 0, na.rm = TRUE), 1))
addf("PFAS: % ZCTA with an MCL/HI exceedance", round(100 * mean(D$any_mcl_exceedance), 1))
addf("Effective exposure contrast: Hazard Index IQR (P75-P25)", round(IQR(D$pfas_hazard_index), 4))
addf("Effective exposure contrast: Hazard Index P90/P10 (P10 floored at 0.001)", round(quantile(D$pfas_hazard_index, .9) / max(quantile(D$pfas_hazard_index, .1), 0.001), 1))
addf("Missingness: cholesterol among Phase 1 primary sample (%)",
     round(100 * mean(is.na(d_all$highchol_pct[d_all$analytic_primary == 1])), 2))
write.csv(feas, file.path(DA_PATHS$outputs, "a1_descriptive_feasibility.csv"), row.names = FALSE)
cat("\n===== A1.3 -- descriptive feasibility =====\n"); print(feas, row.names = FALSE)

## ---- maps -------------------------------------------------------------
tx_state <- sf::st_read(file.path(PATHS$raw_geo, "cb_2022_us_state_500k.shp"), quiet = TRUE)
tx_state <- tx_state[tx_state$STUSPS == "TX", ] |> sf::st_transform(5070)

ggsave(file.path(DA_PATHS$figures, "a1_map_pfas_hazard_index.png"),
  ggplot() + geom_sf(data = d, aes(fill = pmin(pfas_hazard_index, quantile(pfas_hazard_index, .98))), colour = NA) +
    geom_sf(data = tx_state, fill = NA, colour = "grey40", linewidth = .3) +
    scale_fill_viridis_c(option = "plasma", name = "Hazard\nIndex", trans = "sqrt") +
    labs(title = "A1 sample -- PFAS Hazard Index", subtitle = sprintf("n = %d ZCTA", nrow(d))) +
    theme_void(base_size = 12), width = 7.5, height = 7, dpi = 200)

ggsave(file.path(DA_PATHS$figures, "a1_map_cholesterol.png"),
  ggplot() + geom_sf(data = d, aes(fill = highchol_pct), colour = NA) +
    geom_sf(data = tx_state, fill = NA, colour = "grey40", linewidth = .3) +
    scale_fill_viridis_c(option = "magma", name = "% high\ncholesterol") +
    labs(title = "A1 sample -- high cholesterol prevalence", subtitle = "CDC PLACES 2025 release (BRFSS 2023)") +
    theme_void(base_size = 12), width = 7.5, height = 7, dpi = 200)

ggsave(file.path(DA_PATHS$figures, "a1_scatter_pfas_cholesterol.png"),
  ggplot(D, aes(pfas_hazard_index, highchol_pct)) +
    geom_point(alpha = .35, size = .9) + geom_smooth(method = "lm", colour = "#b2182b") +
    labs(x = "EPA PFAS Hazard Index (ZCTA, population-weighted)", y = "High cholesterol prevalence (%)",
         title = "PFAS mixture exposure vs high cholesterol, Texas ZCTAs",
         subtitle = sprintf("n = %d; unadjusted", nrow(D))) + theme_minimal(base_size = 12),
  width = 6, height = 4.5, dpi = 200)

## ---- A1.4: correlation, vs Phase 1's existing outcomes --------------
cor_a1 <- data.frame(
  outcome = "highchol_pct",
  pearson = round(cor(D$pfas_hazard_index, D$highchol_pct, use = "complete.obs"), 3),
  spearman = round(cor(D$pfas_hazard_index, D$highchol_pct, method = "spearman", use = "complete.obs"), 3),
  partial_ses_adj = round({
    m <- lm(reformulate(c("pfas_hazard_index", P1_COV), response = "highchol_pct"), data = D)
    s <- summary(m)$coefficients
    s["pfas_hazard_index", "Estimate"] / sd(D$highchol_pct) * sd(D$pfas_hazard_index)
  }, 3))
p1_corr <- tryCatch(read.csv(file.path(PATHS$outputs, "correlations_pfas_outcomes.csv")),
                     error = function(e) data.frame())
p1_corr_hi <- p1_corr[p1_corr$exposure == "pfas_hazard_index", c("outcome", "pearson", "spearman", "partial_ses_adj")]
cor_compare <- rbind(p1_corr_hi, cor_a1)
write.csv(cor_compare, file.path(DA_PATHS$outputs, "a1_correlation_vs_phase1.csv"), row.names = FALSE)
cat("\n===== A1.4 -- correlation: PFAS Hazard Index x outcome (A1 cholesterol vs Phase 1 outcomes) =====\n")
print(cor_compare, row.names = FALSE)

## ---- A1.5: crude + adjusted regression (same formulas as scripts/12_models.R)
scale_keep <- function(x) as.numeric(scale(x))
Ds <- D; Ds[P1_COV] <- lapply(Ds[P1_COV], scale_keep)
e <- P1_EXP_PRIMARY  # "pfas_hi_log"

fit_report <- function(fm, data, label) {
  m <- lm(fm, data = data)
  V <- if (have("sandwich")) sandwich::vcovHC(m, type = "HC1") else vcov(m)
  se <- sqrt(diag(V))[e]; b <- coef(m)[e]
  list(model = m,
       row = data.frame(model = label, beta = b, se_hc1 = se, std_beta = b * sd(data[[e]]) / sd(data$highchol_pct),
                         t = b / se, p_value = 2 * pnorm(-abs(b / se)),
                         r2 = summary(m)$r.squared, adj_r2 = summary(m)$adj.r.squared, n = nobs(m)))
}
m0 <- fit_report(reformulate(e, "highchol_pct"), Ds, "A1-0 crude")
m1 <- fit_report(reformulate(c(e, P1_COV), "highchol_pct"), Ds, "A1-1 adjusted")
reg <- rbind(m0$row, m1$row)
reg$partial_r2_over_covariates_only <- c(NA, m1$row$r2 - summary(lm(reformulate(P1_COV, "highchol_pct"), data = Ds))$r.squared)
reg[, 2:9] <- lapply(reg[, 2:9], function(x) signif(x, 4))
write.csv(reg, file.path(DA_PATHS$outputs, "a1_regression.csv"), row.names = FALSE)
cat("\n===== A1.5 -- crude vs adjusted regression (exposure = log(1+Hazard Index)) =====\n")
print(reg, row.names = FALSE)

# Phase 1's own obesity/diabetes/bphigh rows at the same exposure, for direct comparison
p1_ols <- tryCatch(read.csv(file.path(PATHS$outputs, "ols_models.csv")), error = function(e) data.frame())
p1_ols_hi <- p1_ols[p1_ols$exposure == e, c("outcome", "beta", "se_hc1", "std_beta", "p_value", "partial_r2")]
write.csv(p1_ols_hi, file.path(DA_PATHS$outputs, "a1_phase1_adjusted_for_comparison.csv"), row.names = FALSE)
cat("\n--- Phase 1 adjusted models at the same exposure (for comparison) ---\n"); print(p1_ols_hi, row.names = FALSE)

# residual diagnostics (crude + adjusted)
resid_diag <- data.frame(
  model = c("A1-0 crude", "A1-1 adjusted"),
  shapiro_p = sapply(list(m0$model, m1$model), function(m) tryCatch(shapiro.test(sample(resid(m), min(5000, length(resid(m)))))$p.value, error = function(e) NA)),
  max_vif = c(NA, if (have("car")) tryCatch(max(car::vif(m1$model)), error = function(e) NA) else NA)
)
write.csv(resid_diag, file.path(DA_PATHS$outputs, "a1_residual_diagnostics.csv"), row.names = FALSE)

## ---- A1.6: spatial residual check (Moran's I only -- no SAR/SEM) ----
spat <- data.frame(model = character(), morans_i = numeric(), p_value = numeric())
if (have("spdep")) {
  lw <- build_listw(d, "knn", k = 6)
  for (mm in list(list("A1-0 crude", m0$model), list("A1-1 adjusted", m1$model))) {
    mt <- spdep::lm.morantest(mm[[2]], lw, zero.policy = TRUE)
    spat <- rbind(spat, data.frame(model = mm[[1]], morans_i = round(mt$estimate[1], 3),
                                    p_value = format(mt$p.value, digits = 3, scientific = TRUE)))
  }
}
write.csv(spat, file.path(DA_PATHS$outputs, "a1_spatial_residual_check.csv"), row.names = FALSE)
cat("\n===== A1.6 -- residual Moran's I (k=6 NN weights, same convention as Phase 1) =====\n")
print(spat, row.names = FALSE)

da_save(d, "a1_zcta_analytic")
msg("02_a1_analysis.R done")
