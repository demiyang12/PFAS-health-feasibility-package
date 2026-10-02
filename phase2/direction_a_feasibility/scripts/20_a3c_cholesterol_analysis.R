# =====================================================================
# 20_a3c_cholesterol_analysis.R
# A3c -- re-run the EXACT A1 cholesterol pilot (same outcome, same
# covariates, same sample, same spatial weights) using the TWDB
# real-polygon hybrid exposure instead of the Phase 1 baseline, AND
# (per explicit request) combine this improved exposure with A3b's
# source-pressure location variables (TRI/NPDES/NPL) in the SAME model --
# a test neither A3a nor A3b ran alone: does better geography + source
# context TOGETHER do more than either improvement did separately?
# Still no composite PFAS score (A3b.6): UCMR5 exposure and source
# variables remain separate regression terms throughout.
# =====================================================================
if (!exists("DA_PATHS")) source(if (file.exists("phase2/direction_a_feasibility/scripts/00_setup.R"))
  "phase2/direction_a_feasibility/scripts/00_setup.R" else "00_setup.R")
suppressPackageStartupMessages({library(sf)})
have <- function(p) requireNamespace(p, quietly = TRUE)

exp_c <- readRDS(file.path(DA_PATHS$processed, "a3c_zcta_exposure_hybrid.rds"))
chol  <- readRDS(file.path(DA_PATHS$processed, "a1_cholesterol_zcta.rds"))
src   <- readRDS(file.path(DA_PATHS$processed, "a3b_zcta_source_indicators.rds"))
d_all <- dplyr::left_join(dplyr::left_join(exp_c, chol, by = "zcta"), src, by = "zcta")
d <- d_all[d_all$analytic_primary == 1 & !is.na(d_all$highchol_pct) & !is.na(d_all$pfas_hi_hybrid), ]
d <- sf::st_transform(d, 5070); d <- d[!sf::st_is_empty(d), ]
D <- sf::st_drop_geometry(d)
msg("A3c cholesterol sample: n = %d (A1's n=1223 minus %d ZCTAs with no TWDB-reachable exposure)",
    nrow(D), sum(exp_c$analytic_primary == 1 & is.na(exp_c$pfas_hi_hybrid), na.rm = TRUE))

scale_keep <- function(x) as.numeric(scale(ifelse(is.finite(x), x, 0)))
Ds <- D; Ds[P1_COV] <- lapply(Ds[P1_COV], scale_keep)
Ds$log_pfas_tri_20km    <- scale_keep(log1p(D$n_pfas_tri_within_20km))
Ds$log_tri_release_20km <- scale_keep(log1p(D$pfas_tri_release_lb_within_20km))
Ds$log_npdes_10km       <- scale_keep(log1p(D$n_npdes_within_10km))
Ds$npl_10km             <- D$npl_within_10km

## ---- A3c correlation (matches A1/A3a convention) -----------------------
cor_tab <- data.frame(
  exposure = "pfas_hazard_index_hybrid (A3c TWDB polygon)",
  pearson  = round(cor(D$pfas_hazard_index_hybrid, D$highchol_pct), 3),
  spearman = round(cor(D$pfas_hazard_index_hybrid, D$highchol_pct, method = "spearman"), 3))
write.csv(cor_tab, file.path(DA_PATHS$outputs, "a3c_correlation_comparison.csv"), row.names = FALSE)
cat("\n===== A3c -- correlation: TWDB-polygon exposure x cholesterol =====\n"); print(cor_tab, row.names = FALSE)

## ---- A3c baseline regression (A3c exposure alone, vs A1/A3a) -----------
fit <- function(fm, data, label, evar = "pfas_hi_hybrid") {
  m <- lm(fm, data = data)
  V <- if (have("sandwich")) sandwich::vcovHC(m, type = "HC1") else vcov(m)
  se <- sqrt(diag(V))[evar]; b <- coef(m)[evar]
  data.frame(model = label, pfas_beta = b, pfas_se_hc1 = se,
             pfas_std_beta = b * sd(data[[evar]]) / sd(data$highchol_pct),
             pfas_p = 2 * pnorm(-abs(b / se)), r2 = summary(m)$r.squared,
             adj_r2 = summary(m)$adj.r.squared,
             max_vif = if (have("car")) tryCatch(max(car::vif(m)), error = function(e) NA) else NA,
             n = nobs(m))
}
m_crude <- fit(reformulate("pfas_hi_hybrid", "highchol_pct"), Ds, "A3c crude")
m_base  <- fit(reformulate(c("pfas_hi_hybrid", P1_COV), "highchol_pct"), Ds, "A3c adjusted (TWDB polygon alone)")

## ---- A3c + A3b source context, staged (mirrors 15_a3b_cholesterol_analysis.R) ----
m_b1 <- fit(reformulate(c("pfas_hi_hybrid", P1_COV, "log_pfas_tri_20km", "log_tri_release_20km"), "highchol_pct"), Ds, "A3c + B1: TRI source pressure")
m_b2 <- fit(reformulate(c("pfas_hi_hybrid", P1_COV, "log_npdes_10km"), "highchol_pct"), Ds, "A3c + B2: wastewater/NPDES pathway")
m_b3 <- fit(reformulate(c("pfas_hi_hybrid", P1_COV, "npl_10km"), "highchol_pct"), Ds, "A3c + B3: PFAS/Superfund site proximity")

src_all <- c("log_pfas_tri_20km", "log_tri_release_20km", "log_npdes_10km", "npl_10km")
vif_combined <- NA
if (have("car")) {
  m_try <- lm(reformulate(c("pfas_hi_hybrid", P1_COV, src_all), "highchol_pct"), data = Ds)
  vif_combined <- tryCatch(max(car::vif(m_try)), error = function(e) NA)
}
combined_ok <- is.finite(vif_combined) && vif_combined < 10
m_combined <- if (combined_ok) fit(reformulate(c("pfas_hi_hybrid", P1_COV, src_all), "highchol_pct"), Ds, "A3c + combined (geography + all source families)") else NULL

reg <- rbind(m_crude, m_base, m_b1, m_b2, m_b3)
if (!is.null(m_combined)) reg <- rbind(reg, m_combined)
reg[, 2:9] <- lapply(reg[, 2:9], function(x) suppressWarnings(signif(as.numeric(x), 4)))
write.csv(reg, file.path(DA_PATHS$outputs, "a3c_regression_comparison.csv"), row.names = FALSE)
cat("\n===== A3c -- TWDB-polygon exposure, alone and combined with A3b source context =====\n"); print(reg, row.names = FALSE)
cat(sprintf("\nCombined model attempted: %s (max VIF among source terms = %s)\n",
            combined_ok, ifelse(is.finite(vif_combined), round(vif_combined, 2), "NA")))

## ---- residual Moran's I: A3c alone vs. A3c + combined source context ---
spat <- data.frame(model = character(), morans_i = numeric(), p_value = character())
if (have("spdep")) {
  lw <- build_listw(d, "knn", k = 6)
  models <- list(list("A3c adjusted (TWDB polygon alone)", lm(reformulate(c("pfas_hi_hybrid", P1_COV), "highchol_pct"), data = Ds)))
  if (!is.null(m_combined)) models[[2]] <- list("A3c + combined (geography + source)", lm(reformulate(c("pfas_hi_hybrid", P1_COV, src_all), "highchol_pct"), data = Ds))
  for (mm in models) {
    mt <- spdep::lm.morantest(mm[[2]], lw, zero.policy = TRUE)
    spat <- rbind(spat, data.frame(model = mm[[1]], morans_i = round(mt$estimate[1], 3), p_value = format(mt$p.value, digits = 3, scientific = TRUE)))
  }
}
write.csv(spat, file.path(DA_PATHS$outputs, "a3c_spatial_residual_check.csv"), row.names = FALSE)
cat("\n===== A3c -- residual Moran's I =====\n"); print(spat, row.names = FALSE)

msg("20_a3c_cholesterol_analysis.R done")
