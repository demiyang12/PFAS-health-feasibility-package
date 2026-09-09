# =====================================================================
# 12_models.R  --  Deliverable E (part 3) + feasibility checks for PSM & GWR
#   input : data/processed/texas_zcta_lisa.rds  (falls back to _analytical)
#   output: outputs/ols_models.csv          (baseline regressions + diagnostics)
#           outputs/spatial_models.csv      (SAR / SEM / SLX comparison)
#           outputs/psm_feasibility.csv     (overlap + balance diagnostics)
#           outputs/gwr_feasibility.csv     (non-stationarity diagnostics)
#           figures/fig_psm_overlap.png
#           figures/fig_gwr_pfas_coef.png   (if GWR run succeeds)
# ---------------------------------------------------------------------
# These are ECOLOGICAL, cross-sectional associations. No causal claim.
# =====================================================================
if (!exists("PATHS")) source(if (file.exists("scripts/00_setup.R")) "scripts/00_setup.R" else "00_setup.R")
suppressPackageStartupMessages({library(sf); library(ggplot2)})
old_ggsave <- ggplot2::ggsave; ggsave <- function(...) old_ggsave(..., bg = "white")
have <- function(p) requireNamespace(p, quietly = TRUE)

f <- file.path(PATHS$processed, "texas_zcta_lisa.rds")
if (!file.exists(f)) f <- file.path(PATHS$processed, "texas_zcta_analytical.rds")
d <- readRDS(f) |> sf::st_transform(5070) |> dplyr::filter(analytic_primary == 1)
d <- d[!sf::st_is_empty(d), ]
D <- sf::st_drop_geometry(d)
msg("modelling sample: n = %d", nrow(D))

COV <- c("median_hh_income","poverty_rate","pct_bachelors_plus","unemployment_rate",
         "pct_hispanic","pct_nh_black","pct_65_plus","pct_renter_occ","log_pop_density")
OUT <- c("obesity_pct","diabetes_pct","bphigh_pct")
EXP <- c("pfas_any_detect","pfas_hi_log","pfas_sum_log","pfas_n_detected_popwt")

## ================================================================
## 1. BASELINE OLS  + diagnostics
## ================================================================
scale_keep <- function(x) as.numeric(scale(x))
Ds <- D
Ds[COV] <- lapply(Ds[COV], scale_keep)

ols_rows <- list()
for (o in OUT) for (e in EXP) {
  fm <- reformulate(c(e, COV), response = o)
  m  <- lm(fm, data = Ds)
  ct <- summary(m)$coefficients
  # heteroskedasticity-consistent SE
  V  <- if (have("sandwich")) sandwich::vcovHC(m, type = "HC1") else vcov(m)
  se <- sqrt(diag(V))[e]; b <- coef(m)[e]
  vif <- if (have("car")) tryCatch(max(car::vif(m)), error = function(x) NA) else NA
  ols_rows[[paste(o, e)]] <- data.frame(
    outcome = o, exposure = e, beta = b, se_hc1 = se,
    std_beta = b * sd(Ds[[e]], na.rm = TRUE) / sd(Ds[[o]], na.rm = TRUE),
    t = b / se, p_value = 2 * pnorm(-abs(b / se)),
    partial_r2 = summary(m)$r.squared -
      summary(lm(reformulate(COV, response = o), data = Ds))$r.squared,
    adj_r2 = summary(m)$adj.r.squared, max_vif = vif, n = nobs(m))
}
ols <- do.call(rbind, ols_rows); rownames(ols) <- NULL
ols[, 3:10] <- lapply(ols[, 3:10], function(x) signif(x, 4))
write.csv(ols, file.path(PATHS$outputs, "ols_models.csv"), row.names = FALSE)
cat("\n===== BASELINE OLS: PFAS coefficient by outcome x exposure def =====\n")
print(ols[, c("outcome","exposure","beta","se_hc1","std_beta","p_value","partial_r2","max_vif")])

## ================================================================
## 2. SPATIAL REGRESSION  (obesity, HI-log exposure)
## ================================================================
spatial_out <- data.frame()
if (have("spdep") && have("spatialreg")) {
  library(spdep); library(spatialreg)
  lw <- build_listw(d, "knn", k = 6)   # primary weights (see 00_setup.R)

  for (o in OUT) {
    fm <- reformulate(c("pfas_hi_log", COV), response = o)
    m_ols <- lm(fm, data = Ds)
    lm_tests <- lm.RStests(m_ols, lw, test = "all", zero.policy = TRUE)
    sem <- errorsarlm(fm, data = Ds, listw = lw, zero.policy = TRUE)
    sar <- lagsarlm(fm,  data = Ds, listw = lw, zero.policy = TRUE)
    res_moran <- lm.morantest(m_ols, lw, zero.policy = TRUE)$estimate[1]
    # SAR total impact of PFAS ~ beta / (1 - rho)  (scalar approximation)
    sar_tot <- as.numeric(coef(sar)["pfas_hi_log"] / (1 - sar$rho))
    spatial_out <- rbind(spatial_out, data.frame(
      outcome = o,
      ols_beta_pfas   = signif(coef(m_ols)["pfas_hi_log"], 4),
      ols_resid_moranI= signif(res_moran, 3),
      lm_err_p = signif(lm_tests$RSerr$p.value %||% NA, 3),
      lm_lag_p = signif(lm_tests$RSlag$p.value %||% NA, 3),
      sem_beta_pfas = signif(coef(sem)["pfas_hi_log"], 4),
      sem_lambda    = signif(sem$lambda, 3),
      sar_beta_pfas = signif(coef(sar)["pfas_hi_log"], 4),
      sar_rho       = signif(sar$rho, 3),
      sar_total_impact_pfas = signif(sar_tot, 4),
      aic_ols = signif(AIC(m_ols), 6), aic_sem = signif(AIC(sem), 6), aic_sar = signif(AIC(sar), 6)))
  }
  write.csv(spatial_out, file.path(PATHS$outputs, "spatial_models.csv"), row.names = FALSE)
  cat("\n===== SPATIAL REGRESSION (exposure = log(1+Hazard Index)) =====\n"); print(spatial_out)
}

## ================================================================
## 3. PROPENSITY-SCORE FEASIBILITY
##    treatment = ZCTA served by a system in the top exposure tier
## ================================================================
D$treat <- as.integer(D$pfas_hazard_index >
                      quantile(D$pfas_hazard_index, 0.75, na.rm = TRUE))
ps_cov <- c("median_hh_income","poverty_rate","pct_bachelors_plus","unemployment_rate",
            "pct_hispanic","pct_nh_black","pct_nh_white","pct_65_plus","pct_under_18",
            "pct_renter_occ","pct_mobile_home","log_pop_density","urban_flag",
            "frac_pws_surface_water")
psd <- D[stats::complete.cases(D[, c("treat", ps_cov)]), ]
ps_fit <- glm(reformulate(ps_cov, "treat"), data = psd, family = binomial)
psd$ps <- predict(ps_fit, type = "response")

ov <- function(g) c(min = min(psd$ps[psd$treat == g]), max = max(psd$ps[psd$treat == g]))
cs_lo <- max(min(psd$ps[psd$treat == 1]), min(psd$ps[psd$treat == 0]))
cs_hi <- min(max(psd$ps[psd$treat == 1]), max(psd$ps[psd$treat == 0]))
in_cs <- mean(psd$ps >= cs_lo & psd$ps <= cs_hi)

smd <- function(v, w = NULL) {
  x1 <- psd[[v]][psd$treat == 1]; x0 <- psd[[v]][psd$treat == 0]
  if (is.null(w)) { (mean(x1) - mean(x0)) / sqrt((var(x1) + var(x0)) / 2) }
  else {
    w1 <- w[psd$treat == 1]; w0 <- w[psd$treat == 0]
    m1 <- weighted.mean(x1, w1); m0 <- weighted.mean(x0, w0)
    (m1 - m0) / sqrt((var(x1) + var(x0)) / 2)
  }
}
psd$ipw <- ifelse(psd$treat == 1, 1 / psd$ps, 1 / (1 - psd$ps))
bal <- data.frame(covariate = ps_cov,
                  smd_unadjusted = sapply(ps_cov, smd),
                  smd_ipw       = sapply(ps_cov, smd, w = psd$ipw))

matched_smd <- NA; att_obesity <- NA
if (have("MatchIt")) {
  mi <- try(MatchIt::matchit(reformulate(ps_cov, "treat"), data = psd,
                             method = "nearest", caliper = 0.2, ratio = 1), silent = TRUE)
  if (!inherits(mi, "try-error")) {
    md <- MatchIt::match.data(mi)
    matched_smd <- mean(abs(sapply(ps_cov, function(v) {
      x1 <- md[[v]][md$treat == 1]; x0 <- md[[v]][md$treat == 0]
      (mean(x1) - mean(x0)) / sqrt((var(psd[[v]][psd$treat==1]) + var(psd[[v]][psd$treat==0]))/2)
    })))
    att_obesity <- coef(lm(obesity_pct ~ treat, data = md, weights = md$weights))["treat"]
  }
}

psm_feas <- data.frame(
  metric = c("N treated (top-quartile HI)", "N control", "N covariates in PS model",
             "PS range treated", "PS range control",
             "Common-support overlap coefficient (share in shared PS range)",
             "Max |SMD| unadjusted", "Max |SMD| after IPW",
             "Mean |SMD| after 1:1 caliper matching",
             "N matched pairs (caliper 0.2)",
             "ATT on obesity after matching (pp; descriptive only)"),
  value = c(sum(psd$treat == 1), sum(psd$treat == 0), length(ps_cov),
            sprintf("%.3f-%.3f", ov(1)[1], ov(1)[2]),
            sprintf("%.3f-%.3f", ov(0)[1], ov(0)[2]),
            round(in_cs, 3),
            round(max(abs(bal$smd_unadjusted)), 3),
            round(max(abs(bal$smd_ipw)), 3),
            round(matched_smd, 3),
            if (have("MatchIt") && !inherits(mi, "try-error")) sum(md$treat == 1) else NA,
            round(att_obesity, 3)))
write.csv(psm_feas, file.path(PATHS$outputs, "psm_feasibility.csv"), row.names = FALSE)
bal$smd_unadjusted <- round(bal$smd_unadjusted, 3)
bal$smd_ipw <- round(bal$smd_ipw, 3)
write.csv(bal, file.path(PATHS$outputs, "psm_balance_table.csv"), row.names = FALSE)
cat("\n===== PROPENSITY-SCORE FEASIBILITY =====\n"); print(psm_feas, row.names = FALSE)

png(file.path(PATHS$figures, "fig_psm_overlap.png"), width = 1500, height = 1000, res = 200)
print(ggplot(psd, aes(ps, fill = factor(treat))) +
        geom_density(alpha = .5) +
        scale_fill_manual(values = c("0"="#2166ac","1"="#b2182b"),
                          labels = c("Lower exposure","Top-quartile HI"), name = NULL) +
        labs(x = "Estimated propensity for higher PFAS exposure", y = "Density",
             title = "Propensity-score overlap / common support",
             subtitle = sprintf("Texas ZCTA primary sample (n = %d)", nrow(psd))) +
        theme_minimal(base_size = 12))
dev.off()

## ================================================================
## 4. GWR FEASIBILITY  (obesity ~ PFAS HI-log + covariates)
## ================================================================
gwr_feas <- data.frame(metric = character(), value = character())
addg <- function(m, v) gwr_feas <<- rbind(gwr_feas, data.frame(metric = m, value = as.character(v)))
addg("N observations", nrow(d))
addg("Median nearest-neighbour distance (km)",
     round(median(unlist(nbdists(knn2nb(knearneigh(sf::st_centroid(sf::st_geometry(d)), 1)),
                                 sf::st_centroid(sf::st_geometry(d))))) / 1000, 1))
if (have("spgwr")) {
  library(spgwr)
  sp <- as(d[, c(OUT, "pfas_hi_log", COV)], "Spatial")
  fm <- reformulate(c("pfas_hi_log", COV), response = "obesity_pct")
  bw <- try(gwr.sel(fm, data = sp, adapt = TRUE, verbose = FALSE), silent = TRUE)
  if (!inherits(bw, "try-error")) {
    g <- gwr(fm, data = sp, adapt = bw, hatmatrix = TRUE, se.fit = TRUE)
    sdf <- as.data.frame(g$SDF)
    b <- sdf[["pfas_hi_log"]]
    m_ols <- lm(fm, data = as.data.frame(sp))
    addg("Adaptive bandwidth (fraction of N)", signif(bw, 3))
    addg("GWR AICc", signif(g$results$AICh, 6))
    addg("OLS AIC", signif(AIC(m_ols), 6))
    addg("Global (OLS) PFAS coefficient", signif(coef(m_ols)["pfas_hi_log"], 3))
    addg("GWR PFAS coef: min / median / max",
         sprintf("%.3f / %.3f / %.3f", min(b), median(b), max(b)))
    addg("GWR PFAS coef IQR", signif(IQR(b), 3))
    addg("Share of ZCTA with positive local PFAS coef", round(mean(b > 0), 2))
    mc <- try(LMZ.F3GWR.test(g), silent = TRUE)     # non-stationarity test
    if (!inherits(mc, "try-error"))
      addg("Non-stationarity test p (PFAS term)",
           signif(mc[["pfas_hi_log", "Pr(>)"]] %||% NA, 3))
    d$gwr_pfas_coef <- b
    tx_state <- sf::st_read(file.path(PATHS$raw_geo, "cb_2022_us_state_500k.shp"), quiet = TRUE)
    tx_state <- tx_state[tx_state$STUSPS == "TX", ] |> sf::st_transform(5070)
    ggsave(file.path(PATHS$figures, "fig_gwr_pfas_coef.png"),
      ggplot() + geom_sf(data = d, aes(fill = gwr_pfas_coef), colour = NA) +
        geom_sf(data = tx_state, fill = NA, colour = "grey30", linewidth = .4) +
        scale_fill_gradient2(low = "#2166ac", mid = "grey95", high = "#b2182b",
                             midpoint = 0, name = "local beta") +
        labs(title = "GWR local coefficient: log(1+PFAS Hazard Index) -> obesity",
             subtitle = "Geographically weighted regression, adaptive bandwidth (Texas)") +
        theme_void(base_size = 12), width = 8.5, height = 8, dpi = 200)
    save_processed(d, "texas_zcta_gwr")
  } else addg("GWR bandwidth selection", "failed to converge")
} else addg("spgwr package", "not installed")
write.csv(gwr_feas, file.path(PATHS$outputs, "gwr_feasibility.csv"), row.names = FALSE)
cat("\n===== GWR FEASIBILITY =====\n"); print(gwr_feas, row.names = FALSE)

msg("12_models.R done")
