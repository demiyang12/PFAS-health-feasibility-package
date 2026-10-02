# =====================================================================
# 10_a3a_cholesterol_analysis.R
# A3a.5 -- re-run the EXACT A1 cholesterol pilot (same outcome, same
# covariates, same sample, same spatial weights) using the alternative
# (equal-split population-weighted) exposure surface instead of the
# Phase 1 baseline, and compare the two side by side.
# =====================================================================
if (!exists("DA_PATHS")) source(if (file.exists("phase2/direction_a_feasibility/scripts/00_setup.R"))
  "phase2/direction_a_feasibility/scripts/00_setup.R" else "00_setup.R")
suppressPackageStartupMessages({library(sf)})
have <- function(p) requireNamespace(p, quietly = TRUE)

exp_cmp <- readRDS(file.path(DA_PATHS$processed, "a3a_zcta_exposure_compare.rds"))
chol    <- readRDS(file.path(DA_PATHS$processed, "a1_cholesterol_zcta.rds"))
d_all   <- dplyr::left_join(exp_cmp, chol, by = "zcta")
d <- d_all[d_all$analytic_primary == 1 & !is.na(d_all$highchol_pct), ]
d <- sf::st_transform(d, 5070); d <- d[!sf::st_is_empty(d), ]
D <- sf::st_drop_geometry(d)
msg("A3a cholesterol sample: n = %d (identical to A1's sample)", nrow(D))

scale_keep <- function(x) as.numeric(scale(x))
Ds <- D; Ds[P1_COV] <- lapply(Ds[P1_COV], scale_keep)

run_one <- function(evar, label) {
  fit_report <- function(fm, data, lbl) {
    m <- lm(fm, data = data)
    V <- if (have("sandwich")) sandwich::vcovHC(m, type = "HC1") else vcov(m)
    se <- sqrt(diag(V))[evar]; b <- coef(m)[evar]
    list(model = m, row = data.frame(exposure = label, model = lbl, beta = b, se_hc1 = se,
         std_beta = b * sd(data[[evar]]) / sd(data$highchol_pct), t = b / se,
         p_value = 2 * pnorm(-abs(b / se)), r2 = summary(m)$r.squared, n = nobs(m)))
  }
  m0 <- fit_report(reformulate(evar, "highchol_pct"), Ds, "crude")
  m1 <- fit_report(reformulate(c(evar, P1_COV), "highchol_pct"), Ds, "adjusted")
  reg <- rbind(m0$row, m1$row)
  spat <- data.frame(exposure = character(), model = character(), morans_i = numeric(), p_value = character())
  if (have("spdep")) {
    lw <- build_listw(d, "knn", k = 6)
    for (mm in list(list("crude", m0$model), list("adjusted", m1$model))) {
      mt <- spdep::lm.morantest(mm[[2]], lw, zero.policy = TRUE)
      spat <- rbind(spat, data.frame(exposure = label, model = mm[[1]], morans_i = round(mt$estimate[1], 3),
                                      p_value = format(mt$p.value, digits = 3, scientific = TRUE)))
    }
  }
  list(reg = reg, spat = spat)
}

# use the raw (non-log) Hazard Index for correlation (matches A1's cor table),
# the log(1+HI) form for regression (matches A1/Phase 1's modelling convention)
cor_tab <- data.frame(
  exposure = c("pfas_hazard_index_phase1 (A1 baseline)", "pfas_hazard_index_popwt (A3a alternative)"),
  pearson  = c(round(cor(D$pfas_hazard_index_phase1, D$highchol_pct), 3), round(cor(D$pfas_hazard_index_popwt, D$highchol_pct), 3)),
  spearman = c(round(cor(D$pfas_hazard_index_phase1, D$highchol_pct, method = "spearman"), 3),
               round(cor(D$pfas_hazard_index_popwt, D$highchol_pct, method = "spearman"), 3)))
write.csv(cor_tab, file.path(DA_PATHS$outputs, "a3a_correlation_comparison.csv"), row.names = FALSE)
cat("\n===== A3a.5 -- correlation: exposure version x cholesterol =====\n"); print(cor_tab, row.names = FALSE)

r1 <- run_one("pfas_hi_phase1", "A1 baseline")
r2 <- run_one("pfas_hi_popwt",  "A3a alternative")
reg_all <- rbind(r1$reg, r2$reg)
reg_all[, 3:9] <- lapply(reg_all[, 3:9], function(x) suppressWarnings(signif(as.numeric(x), 4)))
write.csv(reg_all, file.path(DA_PATHS$outputs, "a3a_regression_comparison.csv"), row.names = FALSE)
cat("\n===== A3a.5 -- regression: baseline vs. alternative exposure =====\n"); print(reg_all, row.names = FALSE)

spat_all <- rbind(r1$spat, r2$spat)
write.csv(spat_all, file.path(DA_PATHS$outputs, "a3a_spatial_residual_check.csv"), row.names = FALSE)
cat("\n===== A3a.5 -- residual Moran's I: baseline vs. alternative =====\n"); print(spat_all, row.names = FALSE)

msg("10_a3a_cholesterol_analysis.R done")
