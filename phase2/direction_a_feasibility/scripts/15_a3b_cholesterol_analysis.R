# =====================================================================
# 15_a3b_cholesterol_analysis.R
# A3b.5 -- staged cholesterol models, one source family added at a time.
# Baseline (= A1) -> B1 (TRI source pressure) -> B2 (wastewater/NPDES
# pathway) -> B3 (PFAS-site proximity/Superfund) -> combined, only if
# collinearity and sample size allow.
# No composite PFAS score (A3b.6). No causal claim.
# =====================================================================
if (!exists("DA_PATHS")) source(if (file.exists("phase2/direction_a_feasibility/scripts/00_setup.R"))
  "phase2/direction_a_feasibility/scripts/00_setup.R" else "00_setup.R")
suppressPackageStartupMessages({library(sf)})
have <- function(p) requireNamespace(p, quietly = TRUE)

ind  <- readRDS(file.path(DA_PATHS$processed, "a3b_zcta_source_indicators.rds"))
base <- readRDS(file.path(PATHS$processed, "texas_zcta_analytical.rds"))
chol <- readRDS(file.path(DA_PATHS$processed, "a1_cholesterol_zcta.rds"))
d_all <- dplyr::left_join(dplyr::left_join(base, ind, by = "zcta"), chol, by = "zcta")
d <- d_all[d_all$analytic_primary == 1 & !is.na(d_all$highchol_pct), ]
d <- sf::st_transform(d, 5070); d <- d[!sf::st_is_empty(d), ]
D <- sf::st_drop_geometry(d)
msg("A3b cholesterol sample: n = %d (identical to A1's sample)", nrow(D))

scale_keep <- function(x) as.numeric(scale(ifelse(is.finite(x), x, 0)))
Ds <- D
Ds[P1_COV] <- lapply(Ds[P1_COV], scale_keep)
Ds$log_pfas_tri_20km   <- scale_keep(log1p(D$n_pfas_tri_within_20km))
Ds$log_tri_release_20km<- scale_keep(log1p(D$pfas_tri_release_lb_within_20km))
Ds$log_npdes_10km      <- scale_keep(log1p(D$n_npdes_within_10km))
Ds$npl_10km            <- D$npl_within_10km
e <- "pfas_hi_log"

fit <- function(fm, data, label) {
  m <- lm(fm, data = data)
  V <- if (have("sandwich")) sandwich::vcovHC(m, type = "HC1") else vcov(m)
  se <- sqrt(diag(V))[e]; b <- coef(m)[e]
  data.frame(model = label, pfas_beta = b, pfas_se_hc1 = se,
             pfas_std_beta = b * sd(data[[e]]) / sd(data$highchol_pct),
             pfas_p = 2 * pnorm(-abs(b / se)), r2 = summary(m)$r.squared,
             adj_r2 = summary(m)$adj.r.squared, max_vif = if (have("car")) tryCatch(max(car::vif(m)), error = function(e) NA) else NA,
             n = nobs(m))
}

m_base <- fit(reformulate(c(e, P1_COV), "highchol_pct"), Ds, "Baseline (A1): UCMR5 + covariates")
m_b1   <- fit(reformulate(c(e, P1_COV, "log_pfas_tri_20km", "log_tri_release_20km"), "highchol_pct"), Ds, "B1: + TRI source pressure")
m_b2   <- fit(reformulate(c(e, P1_COV, "log_npdes_10km"), "highchol_pct"), Ds, "B2: + wastewater/NPDES pathway")
m_b3   <- fit(reformulate(c(e, P1_COV, "npl_10km"), "highchol_pct"), Ds, "B3: + PFAS/Superfund site proximity")

## collinearity check before attempting a combined model
src_all <- c("log_pfas_tri_20km", "log_tri_release_20km", "log_npdes_10km", "npl_10km")
vif_combined <- NA
if (have("car")) {
  m_try <- lm(reformulate(c(e, P1_COV, src_all), "highchol_pct"), data = Ds)
  vif_combined <- tryCatch(max(car::vif(m_try)), error = function(e) NA)
}
combined_ok <- is.finite(vif_combined) && vif_combined < 10
m_combined <- if (combined_ok) fit(reformulate(c(e, P1_COV, src_all), "highchol_pct"), Ds, "Combined (all source families)") else NULL

reg <- rbind(m_base, m_b1, m_b2, m_b3)
if (!is.null(m_combined)) reg <- rbind(reg, m_combined)
reg[, 2:9] <- lapply(reg[, 2:9], function(x) suppressWarnings(signif(as.numeric(x), 4)))
write.csv(reg, file.path(DA_PATHS$outputs, "a3b_regression_comparison.csv"), row.names = FALSE)
cat("\n===== A3b.5 -- staged cholesterol models =====\n"); print(reg, row.names = FALSE)
cat(sprintf("\nCombined model attempted: %s (max VIF among source terms = %s)\n",
            combined_ok, ifelse(is.finite(vif_combined), round(vif_combined, 2), "NA")))

## residual Moran's I for baseline vs. the richest well-behaved model
richest <- if (!is.null(m_combined)) reformulate(c(e, P1_COV, src_all), "highchol_pct") else reformulate(c(e, P1_COV, "log_pfas_tri_20km"), "highchol_pct")
spat <- data.frame(model = character(), morans_i = numeric(), p_value = character())
if (have("spdep")) {
  lw <- build_listw(d, "knn", k = 6)
  for (mm in list(list("Baseline (A1)", lm(reformulate(c(e, P1_COV), "highchol_pct"), data = Ds)),
                  list(if (!is.null(m_combined)) "Combined" else "B1 (richest attempted)", lm(richest, data = Ds)))) {
    mt <- spdep::lm.morantest(mm[[2]], lw, zero.policy = TRUE)
    spat <- rbind(spat, data.frame(model = mm[[1]], morans_i = round(mt$estimate[1], 3), p_value = format(mt$p.value, digits = 3, scientific = TRUE)))
  }
}
write.csv(spat, file.path(DA_PATHS$outputs, "a3b_spatial_residual_check.csv"), row.names = FALSE)
cat("\n===== residual Moran's I =====\n"); print(spat, row.names = FALSE)

msg("15_a3b_cholesterol_analysis.R done")
