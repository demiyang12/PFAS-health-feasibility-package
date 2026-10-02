# =====================================================================
# 22_confounding_check_healthcare_access.R
# Quick diagnostic (not a new lettered A3 sub-pilot): across ALL FOUR
# Phase 1 health outcomes, the PFAS Hazard Index is NEGATIVELY correlated
# with prevalence, both crude and adjusted -- opposite the direction
# individual-level PFAS toxicology would predict for cholesterol/metabolic
# outcomes. PLACES outcomes are self-reported/diagnosed prevalence
# (highchol_pct = "ever told by a doctor"), so a community's screening/
# healthcare-access rate is a plausible shared confounder: less screening
# -> fewer people "told" they have high cholesterol -> lower measured
# prevalence, regardless of true PFAS effect.
#
# None of Phase 1's existing covariates (P1_COV) directly measure
# healthcare access -- svi_index and urban_flag are built FROM variables
# already in P1_COV (log_pop_density, income, poverty, education), so they
# would not add independent information. This script pulls the one ACS
# table never used in this project -- B27001, Health Insurance Coverage
# Status by Sex by Age -- via the exact same keyless bulk-file method
# Phase 1 used for its other ACS tables (scripts/06_read_acs.R /
# scripts/download_raw.sh), computes ZCTA-level uninsured rate as a direct
# healthcare-access proxy, and tests whether adding it changes the sign or
# magnitude of the PFAS-cholesterol association.
# =====================================================================
if (!exists("DA_PATHS")) source(if (file.exists("phase2/direction_a_feasibility/scripts/00_setup.R"))
  "phase2/direction_a_feasibility/scripts/00_setup.R" else "00_setup.R")
suppressPackageStartupMessages({library(sf); library(data.table)})
have <- function(p) requireNamespace(p, quietly = TRUE)

## ---- build ZCTA uninsured rate from the raw B27001 pull ----------------
raw <- fread(file.path(DA_PATHS$raw, "acs", "acs_b27001_zcta.psv"), sep = "|", colClasses = "character", showProgress = FALSE)
raw[, zcta := sub("^860Z200US", "", GEO_ID)]
no_cov_cols <- sprintf("B27001_E%03d", c(5,8,11,14,17,20,23,26,29, 33,36,39,42,45,48,51,54,57))
num_cols <- c("B27001_E001", no_cov_cols)
raw[, (num_cols) := lapply(.SD, function(x) { x <- suppressWarnings(as.numeric(x)); x[x <= -666666666] <- NA_real_; x }), .SDcols = num_cols]
raw[, n_uninsured := rowSums(.SD, na.rm = TRUE), .SDcols = no_cov_cols]
raw[, pct_uninsured := ifelse(is.finite(B27001_E001) & B27001_E001 > 0, 100 * n_uninsured / B27001_E001, NA_real_)]
ins <- raw[, .(zcta, pct_uninsured, insurance_pop_total = B27001_E001)]
msg("ACS B27001 (health insurance): %d ZCTA rows, %d with a usable uninsured rate", nrow(ins), sum(is.finite(ins$pct_uninsured)))
cat("\n===== uninsured-rate distribution, all TX ZCTAs =====\n"); print(summary(ins$pct_uninsured))

## ---- rebuild the EXACT A1 cholesterol sample, + the new variable -------
base <- readRDS(file.path(PATHS$processed, "texas_zcta_analytical.rds"))
chol <- readRDS(file.path(DA_PATHS$processed, "a1_cholesterol_zcta.rds"))
d_all <- dplyr::left_join(dplyr::left_join(base, chol, by = "zcta"), ins, by = "zcta")
d <- d_all[d_all$analytic_primary == 1 & !is.na(d_all$highchol_pct), ]
d <- sf::st_transform(d, 5070); d <- d[!sf::st_is_empty(d), ]
D <- sf::st_drop_geometry(d)
msg("A1 sample with a usable uninsured rate: %d / %d", sum(is.finite(D$pct_uninsured)), nrow(D))
D <- D[is.finite(D$pct_uninsured), ]

scale_keep <- function(x) as.numeric(scale(x))
Ds <- D
Ds[P1_COV] <- lapply(Ds[P1_COV], scale_keep)
Ds$pct_uninsured_z <- scale_keep(D$pct_uninsured)
e <- "pfas_hi_log"

cat(sprintf("\nCorrelation, PFAS exposure vs. uninsured rate: Pearson r = %.3f, Spearman rho = %.3f\n",
            cor(D[[e]], D$pct_uninsured), cor(D[[e]], D$pct_uninsured, method = "spearman")))
cat(sprintf("Correlation, uninsured rate vs. highchol_pct (crude): Pearson r = %.3f\n",
            cor(D$pct_uninsured, D$highchol_pct)))

fit <- function(fm, data, label) {
  m <- lm(fm, data = data)
  V <- if (have("sandwich")) sandwich::vcovHC(m, type = "HC1") else vcov(m)
  se <- sqrt(diag(V))[e]; b <- coef(m)[e]
  data.frame(model = label, pfas_beta = b, pfas_se_hc1 = se,
             pfas_std_beta = b * sd(data[[e]]) / sd(data$highchol_pct),
             pfas_p = 2 * pnorm(-abs(b / se)), r2 = summary(m)$r.squared,
             uninsured_beta = if ("pct_uninsured_z" %in% names(coef(m))) coef(m)["pct_uninsured_z"] else NA,
             uninsured_p = if ("pct_uninsured_z" %in% names(coef(m))) 2 * pnorm(-abs(coef(m)["pct_uninsured_z"] / sqrt(diag(V))["pct_uninsured_z"])) else NA,
             n = nobs(m))
}
m_base <- fit(reformulate(c(e, P1_COV), "highchol_pct"), Ds, "A1 adjusted (same sample, P1_COV only)")
m_plus <- fit(reformulate(c(e, P1_COV, "pct_uninsured_z"), "highchol_pct"), Ds, "A1 adjusted + uninsured rate")

reg <- rbind(m_base, m_plus)
reg[, 2:9] <- lapply(reg[, 2:9], function(x) suppressWarnings(signif(as.numeric(x), 4)))
write.csv(reg, file.path(DA_PATHS$outputs, "confounding_check_healthcare_access.csv"), row.names = FALSE)
cat("\n===== does controlling for healthcare access (uninsured rate) change the PFAS coefficient? =====\n")
print(reg, row.names = FALSE)

cat(sprintf("\nPFAS std beta: %.4f (no uninsured control) -> %.4f (+ uninsured control), %.1f%% change\n",
            m_base$pfas_std_beta, m_plus$pfas_std_beta,
            100 * (m_plus$pfas_std_beta - m_base$pfas_std_beta) / abs(m_base$pfas_std_beta)))
cat(sprintf("Uninsured rate's OWN standardized beta on highchol_pct: %.4f (p=%.3g) -- %s\n",
            m_plus$uninsured_beta, m_plus$uninsured_p,
            ifelse(m_plus$uninsured_p < 0.05, "significant predictor", "not significant at p<0.05")))

msg("22_confounding_check_healthcare_access.R done")
