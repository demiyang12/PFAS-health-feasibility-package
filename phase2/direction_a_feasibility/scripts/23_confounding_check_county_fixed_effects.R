# =====================================================================
# 23_confounding_check_county_fixed_effects.R
# Quick diagnostic (not a new lettered A3 sub-pilot): the healthcare-access
# confounding test (script 22) came back null -- uninsured rate predicts
# cholesterol strongly but barely correlates with PFAS exposure, so it
# cannot explain the persistent negative PFAS-cholesterol sign or the
# residual spatial autocorrelation (Moran's I ~0.28, unmoved across every
# exposure version tested in A3a/A3b/A3c).
#
# This tests a DIFFERENT candidate mechanism: does the unexplained spatial
# structure operate at COUNTY granularity? Two reasons this matters:
#   1. CDC PLACES's ZCTA estimates are model-based small-area estimates;
#      if the underlying model borrows statistical strength across
#      geography nested within county/state, neighboring ZCTAs in the same
#      county could show correlated "residual" patterns as an artifact of
#      the ESTIMATION method, not a real geographic process.
#   2. Real but unmeasured regional confounders (diet, local healthcare
#      systems, clinical practice patterns) often vary at roughly county
#      scale, not fine ZCTA-to-ZCTA scale.
# If adding a county fixed effect collapses most of the residual spatial
# autocorrelation, that points at (1) or (2) above rather than at anything
# finer-grained or anything related to exposure assignment -- which the
# three A3 exposure interventions have already shown is not the driver.
# =====================================================================
if (!exists("DA_PATHS")) source(if (file.exists("phase2/direction_a_feasibility/scripts/00_setup.R"))
  "phase2/direction_a_feasibility/scripts/00_setup.R" else "00_setup.R")
suppressPackageStartupMessages({library(sf)})
have <- function(p) requireNamespace(p, quietly = TRUE)

base <- readRDS(file.path(PATHS$processed, "texas_zcta_analytical.rds"))
chol <- readRDS(file.path(DA_PATHS$processed, "a1_cholesterol_zcta.rds"))
d_all <- dplyr::left_join(base, chol, by = "zcta")
d <- d_all[d_all$analytic_primary == 1 & !is.na(d_all$highchol_pct), ]
d <- sf::st_transform(d, 5070); d <- d[!sf::st_is_empty(d), ]
D <- sf::st_drop_geometry(d)
e <- "pfas_hi_log"

n_county <- length(unique(D$county_fips))
cat(sprintf("\nA1 sample: n = %d ZCTAs across %d distinct counties (median %.1f ZCTAs/county, %d counties with only 1 ZCTA)\n",
            nrow(D), n_county, nrow(D) / n_county,
            sum(table(D$county_fips) == 1)))

scale_keep <- function(x) as.numeric(scale(x))
Ds <- D; Ds[P1_COV] <- lapply(Ds[P1_COV], scale_keep)
Ds$county_fips <- factor(D$county_fips)

fit_report <- function(fm, data, label) {
  m <- lm(fm, data = data)
  V <- if (have("sandwich")) sandwich::vcovHC(m, type = "HC1") else vcov(m)
  se <- sqrt(diag(V))[e]; b <- coef(m)[e]
  list(model = m, row = data.frame(model = label, pfas_beta = b, pfas_se_hc1 = se,
       pfas_std_beta = b * sd(data[[e]]) / sd(data$highchol_pct),
       pfas_p = 2 * pnorm(-abs(b / se)), r2 = summary(m)$r.squared,
       adj_r2 = summary(m)$adj.r.squared, n = nobs(m), n_params = length(coef(m))))
}

r_base   <- fit_report(reformulate(c(e, P1_COV), "highchol_pct"), Ds, "A1 adjusted (no county FE)")
r_county <- fit_report(reformulate(c(e, P1_COV, "county_fips"), "highchol_pct"), Ds, "A1 adjusted + county fixed effects")

reg <- rbind(r_base$row, r_county$row)
reg[, 2:7] <- lapply(reg[, 2:7], function(x) suppressWarnings(signif(as.numeric(x), 4)))
write.csv(reg, file.path(DA_PATHS$outputs, "confounding_check_county_fe_regression.csv"), row.names = FALSE)
cat("\n===== does a county fixed effect change the PFAS coefficient? =====\n"); print(reg, row.names = FALSE)
cat(sprintf("\nPFAS std beta: %.4f (no county FE) -> %.4f (+ county FE), %.1f%% change\n",
            r_base$row$pfas_std_beta, r_county$row$pfas_std_beta,
            100 * (r_county$row$pfas_std_beta - r_base$row$pfas_std_beta) / abs(r_base$row$pfas_std_beta)))

## ---- the main event: does residual spatial autocorrelation collapse? ---
spat <- data.frame(model = character(), morans_i = numeric(), p_value = character())
if (have("spdep")) {
  lw <- build_listw(d, "knn", k = 6)
  for (mm in list(list("No county FE", r_base$model), list("+ county fixed effects", r_county$model))) {
    mt <- spdep::lm.morantest(mm[[2]], lw, zero.policy = TRUE)
    spat <- rbind(spat, data.frame(model = mm[[1]], morans_i = round(mt$estimate[1], 4),
                                    p_value = format(mt$p.value, digits = 3, scientific = TRUE)))
  }
}
write.csv(spat, file.path(DA_PATHS$outputs, "confounding_check_county_fe_spatial.csv"), row.names = FALSE)
cat("\n===== residual Moran's I: before vs. after absorbing county-level means =====\n"); print(spat, row.names = FALSE)
if (nrow(spat) == 2) {
  pct_drop <- 100 * (spat$morans_i[1] - spat$morans_i[2]) / spat$morans_i[1]
  cat(sprintf("\nResidual Moran's I changed by %.1f%% after adding county fixed effects.\n", pct_drop))
  cat(if (pct_drop > 50) "LARGE drop -- spatial structure is substantially a county-level phenomenon.\n"
      else if (pct_drop > 15) "MODERATE drop -- county-level factors explain some, not most, of the spatial structure.\n"
      else "SMALL/NO drop -- the spatial structure operates at a finer grain than county, or is not county-driven.\n")
}

## ---- robustness check: county FIXED effects can overfit (63 of 197
## counties in this sample have only 1 ZCTA, so their fixed effect perfectly
## absorbs that single observation) -- repeat with county as a RANDOM
## effect (partial pooling via lme4), which handles small counties properly
## and avoids degenerate singleton fits ---------------------------------
if (have("lme4")) {
  m_re <- lme4::lmer(reformulate(c(e, P1_COV, "(1|county_fips)"), "highchol_pct"), data = Ds, REML = TRUE)
  b_re <- lme4::fixef(m_re)[e]; se_re <- sqrt(diag(vcov(m_re)))[e]
  std_beta_re <- b_re * sd(Ds[[e]]) / sd(Ds$highchol_pct)
  vc <- as.data.frame(lme4::VarCorr(m_re))
  icc <- 100 * vc$vcov[1] / (vc$vcov[1] + vc$vcov[2])
  cat(sprintf("\n===== robustness: county RANDOM effect (partial pooling, avoids singleton-county overfit) =====\n"))
  cat(sprintf("PFAS std beta = %.4f (t = %.3f) -- vs. %.4f with no county adjustment, %.1f%% change\n",
              std_beta_re, b_re / se_re, r_base$row$pfas_std_beta,
              100 * (std_beta_re - r_base$row$pfas_std_beta) / abs(r_base$row$pfas_std_beta)))
  cat(sprintf("ICC (share of residual variance at the county level): %.1f%%\n", icc))
  re_row <- data.frame(model = "A1 adjusted, county RANDOM effect (lme4)",
                        pfas_beta = round(b_re, 4), pfas_se_hc1 = round(se_re, 4),
                        pfas_std_beta = round(std_beta_re, 4), pfas_p = NA, r2 = NA, adj_r2 = NA,
                        n = nobs(m_re), n_params = NA, icc_pct = round(icc, 1))
  write.csv(re_row, file.path(DA_PATHS$outputs, "confounding_check_county_re_regression.csv"), row.names = FALSE)
  if (have("spdep")) {
    mt_re <- spdep::moran.test(residuals(m_re), lw, zero.policy = TRUE)
    cat(sprintf("Residual Moran's I (county random effect): %.4f (p = %.3g) -- vs. 0.2781 with no adjustment\n",
                mt_re$estimate[1], mt_re$p.value))
    spat <- rbind(spat, data.frame(model = "+ county random effect (lme4)", morans_i = round(mt_re$estimate[1], 4),
                                    p_value = format(mt_re$p.value, digits = 3, scientific = TRUE)))
    write.csv(spat, file.path(DA_PATHS$outputs, "confounding_check_county_fe_spatial.csv"), row.names = FALSE)
  }
}

## ---- within-between (Mundlak) decomposition ---------------------------
## County random effects remove ALL between-county variation along with any
## bias -- but PFAS exposure itself is ~61-67% between-county variance (a
## separate check, not re-run here), so a blanket county adjustment risks
## discarding real signal along with confounding. Decompose PFAS exposure
## into its county mean ("between") and each ZCTA's deviation from that
## mean ("within"), and estimate both simultaneously rather than discarding
## either -- the standard remedy for this ambiguity.
if (have("lme4") && have("car")) {
  cty_mean <- ave(D[[e]], D$county_fips)
  Ds$pfas_between <- as.numeric(scale(cty_mean))
  Ds$pfas_within  <- as.numeric(scale(D[[e]] - cty_mean))
  m_mundlak <- lme4::lmer(reformulate(c("pfas_within", "pfas_between", P1_COV, "(1|county_fips)"), "highchol_pct"),
                           data = Ds, REML = TRUE)
  sdy <- sd(Ds$highchol_pct)
  mk <- function(term) {
    b <- lme4::fixef(m_mundlak)[term]; se <- sqrt(diag(vcov(m_mundlak)))[term]
    data.frame(component = term, std_beta = round(b / sdy, 4),
               ci_lo = round((b - 1.96 * se) / sdy, 4), ci_hi = round((b + 1.96 * se) / sdy, 4),
               t_value = round(b / se, 3))
  }
  mundlak_tab <- rbind(mk("pfas_within"), mk("pfas_between"))
  ct <- car::linearHypothesis(m_mundlak, "pfas_within = pfas_between")
  mundlak_tab$within_vs_between_chisq <- c(round(ct$Chisq[2], 3), NA)
  mundlak_tab$within_vs_between_p <- c(round(ct$`Pr(>Chisq)`[2], 4), NA)
  write.csv(mundlak_tab, file.path(DA_PATHS$outputs, "confounding_check_mundlak_decomposition.csv"), row.names = FALSE)
  cat("\n===== within-between (Mundlak) decomposition =====\n"); print(mundlak_tab, row.names = FALSE)

  ## ---- robustness: is the between-county effect driven by a handful of
  ## outlier high-exposure counties? (62.9% of counties have zero mean
  ## exposure, so this is effectively a has-PFAS vs. no-PFAS group
  ## comparison -- check it isn't just the top few counties) -------------
  run_between <- function(data_subset, label) {
    cm <- tapply(data_subset[[e]], data_subset$county_fips, mean); cmf <- cm[data_subset$county_fips]
    dd <- data_subset; dd[P1_COV] <- lapply(dd[P1_COV], scale_keep)
    dd$pfas_between <- as.numeric(scale(cmf)); dd$county_fips <- factor(dd$county_fips)
    m <- lme4::lmer(reformulate(c("pfas_between", P1_COV, "(1|county_fips)"), "highchol_pct"), data = dd, REML = TRUE)
    b <- lme4::fixef(m)["pfas_between"]; se <- sqrt(diag(vcov(m)))["pfas_between"]
    data.frame(subset = label, n_counties = length(unique(dd$county_fips)),
               std_beta = round(b / sd(dd$highchol_pct), 4), t_value = round(b / se, 3))
  }
  cty_mean_by_county <- tapply(D[[e]], D$county_fips, mean)   # named by county_fips, unlike ave()'s row-aligned output
  top_fips <- function(k) names(sort(cty_mean_by_county[cty_mean_by_county > 0], decreasing = TRUE)[1:k])
  robust_tab <- rbind(
    run_between(D, "All counties"),
    run_between(D[!D$county_fips %in% top_fips(3), ], "Excl. top 3 highest-exposure counties"),
    run_between(D[!D$county_fips %in% top_fips(8), ], "Excl. top 8 highest-exposure counties"))
  write.csv(robust_tab, file.path(DA_PATHS$outputs, "confounding_check_outlier_robustness.csv"), row.names = FALSE)
  cat("\n===== is the between-county effect driven by outlier counties? =====\n"); print(robust_tab, row.names = FALSE)
}

msg("23_confounding_check_county_fixed_effects.R done")
