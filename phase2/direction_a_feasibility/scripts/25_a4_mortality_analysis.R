# =====================================================================
# 25_a4_mortality_analysis.R
# A4 -- does PFAS exposure relate to county-level Ischaemic Heart Disease
# mortality (CDC WONDER, death-certificate based, no small-area smoothing)
# the way it appeared to relate to PLACES's modelled cholesterol prevalence
# at the county level (the "between-county" effect found in script 23)?
#
# Design: county-level Poisson/negative-binomial regression of IHD deaths
# (2020-2024 combined) with log(population) as an offset -- the standard
# approach for rare-event count mortality data, NOT an OLS regression on
# the crude rate. Reuses A2's existing population-weighted county PFAS
# exposure and covariates (outputs/a2_county_exposure_table.csv) --
# same exposure data, same covariate set, only the OUTCOME source changes.
# Suppressed counties (12/254) are excluded, never imputed as zero.
# =====================================================================
if (!exists("DA_PATHS")) source(if (file.exists("phase2/direction_a_feasibility/scripts/00_setup.R"))
  "phase2/direction_a_feasibility/scripts/00_setup.R" else "00_setup.R")
have <- function(p) requireNamespace(p, quietly = TRUE)

ihd <- as.data.frame(readRDS(file.path(DA_PATHS$processed, "a4_wonder_ihd_county.rds")))
exp <- read.csv(file.path(DA_PATHS$outputs, "a2_county_exposure_table.csv"))
D <- merge(ihd, exp, by = "county")
msg("Merged: %d counties (expect 254)", nrow(D))
D_full <- D
D <- D[!D$suppressed, ]
msg("After excluding %d suppressed counties: n = %d for analysis", sum(D_full$suppressed), nrow(D))

cov <- c("median_hh_income", "poverty_rate", "pct_bachelors_plus", "pct_hispanic", "pct_nh_black", "pop_density_km2")
D <- D[stats::complete.cases(D[, c("pfas_hi_log", cov, "deaths", "population")]), ]
msg("After requiring complete covariates: n = %d", nrow(D))

scale_keep <- function(x) as.numeric(scale(x))
Ds <- D
Ds[cov] <- lapply(Ds[cov], scale_keep)
Ds$pfas_hi_log_z <- scale_keep(D$pfas_hi_log)

## ---- simple correlation, for direct comparison to the PLACES-based
## between-county finding (std beta -0.077 there) -----------------------
cat(sprintf("\n===== A4 -- crude rate vs. PFAS exposure, correlation =====\n"))
cat(sprintf("Pearson r = %.3f, Spearman rho = %.3f (n=%d)\n",
            cor(D$crude_rate, D$pfas_hi_log), cor(D$crude_rate, D$pfas_hi_log, method = "spearman"), nrow(D)))

## ---- Poisson / negative binomial regression with population offset ---
fm <- deaths ~ pfas_hi_log_z + median_hh_income + poverty_rate + pct_bachelors_plus +
               pct_hispanic + pct_nh_black + pop_density_km2 + offset(log(population))
m_pois <- glm(fm, data = Ds, family = poisson())
disp <- sum(residuals(m_pois, type = "pearson")^2) / m_pois$df.residual
cat(sprintf("\nPoisson dispersion statistic: %.2f (>1 indicates overdispersion; use neg. binomial if so)\n", disp))

m_final <- m_pois; model_used <- "Poisson"
if (disp > 1.5 && have("MASS")) {
  m_nb <- MASS::glm.nb(fm, data = Ds)
  m_final <- m_nb; model_used <- "Negative Binomial"
}
cat(sprintf("\n===== A4 -- %s regression: IHD deaths ~ PFAS exposure + covariates, offset=log(population) =====\n", model_used))
s <- summary(m_final)
print(s$coefficients["pfas_hi_log_z", , drop = FALSE])

b <- s$coefficients["pfas_hi_log_z", "Estimate"]
se <- s$coefficients["pfas_hi_log_z", "Std. Error"]
irr <- exp(b); irr_lo <- exp(b - 1.96 * se); irr_hi <- exp(b + 1.96 * se)
cat(sprintf("\nIncidence Rate Ratio per 1-SD increase in PFAS exposure: %.4f (95%% CI: %.4f - %.4f)\n", irr, irr_lo, irr_hi))
cat(sprintf("i.e. a 1-SD higher PFAS exposure is associated with a %.1f%% %s in IHD mortality rate (95%% CI %.1f%% to %.1f%%)\n",
            100 * abs(irr - 1), ifelse(irr < 1, "DECREASE", "INCREASE"),
            100 * (irr_lo - 1), 100 * (irr_hi - 1)))

out <- data.frame(model = sprintf("A4: IHD mortality (%s, offset=log(pop))", model_used),
                   pfas_log_irr = round(irr, 4), irr_ci_lo = round(irr_lo, 4), irr_ci_hi = round(irr_hi, 4),
                   z_value = round(b / se, 3), p_value = signif(s$coefficients["pfas_hi_log_z", 4], 4),
                   n_counties = nrow(Ds), n_suppressed_excluded = sum(D_full$suppressed))
write.csv(out, file.path(DA_PATHS$outputs, "a4_ihd_mortality_regression.csv"), row.names = FALSE)
cat("\n"); print(out, row.names = FALSE)

## ---- comparison to the PLACES-based between-county finding ------------
cat("\n===== Comparison: PLACES-based (between-county, script 23) vs. WONDER-based (A4) =====\n")
cat("PLACES cholesterol, between-county std beta: -0.077 (95% CI -0.126 to -0.028), p=0.002 -- SIGNIFICANT\n")
cat(sprintf("WONDER IHD mortality, PFAS IRR: %.4f (95%% CI %.4f-%.4f), p=%.3g -- %s\n",
            irr, irr_lo, irr_hi, s$coefficients["pfas_hi_log_z", 4],
            ifelse(s$coefficients["pfas_hi_log_z", 4] < 0.05, "SIGNIFICANT" , "NOT significant")))

msg("25_a4_mortality_analysis.R done")
