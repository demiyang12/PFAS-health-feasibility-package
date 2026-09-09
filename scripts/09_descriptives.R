# =====================================================================
# 09_descriptives.R  --  Deliverable E (part 1): descriptive statistics
#                        and correlations
#   input : data/processed/texas_zcta_analytical.rds
#   output: outputs/descriptives_primary.csv
#           outputs/correlations_pfas_outcomes.csv
#           outputs/correlation_matrix_full.csv
#           outputs/pfas_by_svi_tertile.csv
#           figures/fig_corr_heatmap.png
#           figures/fig_pfas_outcome_scatter.png
# =====================================================================
if (!exists("PATHS")) source(if (file.exists("scripts/00_setup.R")) "scripts/00_setup.R" else "00_setup.R")
suppressPackageStartupMessages({library(ggplot2)})
old_ggsave <- ggplot2::ggsave; ggsave <- function(...) old_ggsave(..., bg = "white")

d0 <- as.data.frame(sf::st_drop_geometry(readRDS(file.path(PATHS$processed, "texas_zcta_analytical.rds"))))
d  <- d0[d0$analytic_primary == 1, ]
msg("descriptives on primary analytic sample: n = %d", nrow(d))

vars <- c(
  obesity_pct = "Obesity prevalence (%)",
  diabetes_pct = "Diabetes prevalence (%)",
  bphigh_pct = "High blood pressure prevalence (%)",
  pfas_any_detect = "Any PFAS detected (0/1)",
  pfas_n_detected_popwt = "N PFAS compounds detected (pop-wt)",
  pfoa_ugL = "PFOA (ug/L)", pfos_ugL = "PFOS (ug/L)",
  pfhxs_ugL = "PFHxS (ug/L)", pfna_ugL = "PFNA (ug/L)",
  pfas_sum_ugL = "Sum PFAS (ug/L, ND=0)",
  pfas_hazard_index = "EPA Hazard Index",
  pfas_detect_freq = "PFAS detection frequency",
  any_mcl_exceedance = "MCL/HI exceedance (0/1)",
  median_hh_income = "Median household income ($)",
  poverty_rate = "Poverty rate (%)",
  pct_bachelors_plus = "Bachelor's degree or higher (%)",
  pct_less_than_hs = "Less than high school (%)",
  unemployment_rate = "Unemployment rate (%)",
  pct_hispanic = "Hispanic (%)", pct_nh_black = "Non-Hispanic Black (%)",
  pct_nh_white = "Non-Hispanic White (%)", pct_minority = "Minority (%)",
  pct_under_18 = "Under 18 (%)", pct_65_plus = "65 and older (%)",
  pct_renter_occ = "Renter-occupied (%)", pct_mobile_home = "Mobile homes (%)",
  median_home_value = "Median home value ($)", median_gross_rent = "Median gross rent ($)",
  pop_density_km2 = "Population density (/km2)", svi_index = "SES-vulnerability index (z)"
)

desc <- do.call(rbind, lapply(names(vars), function(v) {
  x <- suppressWarnings(as.numeric(d[[v]]))
  data.frame(
    variable = v, label = vars[[v]],
    n = sum(is.finite(x)),
    mean = mean(x, na.rm = TRUE), sd = sd(x, na.rm = TRUE),
    min = min(x, na.rm = TRUE),
    p25 = quantile(x, .25, na.rm = TRUE), median = median(x, na.rm = TRUE),
    p75 = quantile(x, .75, na.rm = TRUE), max = max(x, na.rm = TRUE),
    pct_missing = round(100 * mean(!is.finite(x)), 1),
    row.names = NULL)
}))
desc[, 4:11] <- lapply(desc[, 4:11], function(x) round(x, 3))
write.csv(desc, file.path(PATHS$outputs, "descriptives_primary.csv"), row.names = FALSE)

## ---- correlations: exposure x outcomes ------------------
exp_vars <- c("pfas_any_detect","pfas_n_detected_popwt","pfoa_ugL","pfos_ugL",
              "pfas_sum_ugL","pfas_hazard_index","pfas_detect_freq","any_mcl_exceedance")
out_vars <- c("obesity_pct","diabetes_pct","bphigh_pct")
cc <- expand.grid(exposure = exp_vars, outcome = out_vars, stringsAsFactors = FALSE)
cc$pearson  <- mapply(function(e, o) cor(d[[e]], d[[o]], use = "complete.obs"), cc$exposure, cc$outcome)
cc$spearman <- mapply(function(e, o) cor(d[[e]], d[[o]], method = "spearman", use = "complete.obs"), cc$exposure, cc$outcome)
cc$partial_ses_adj <- mapply(function(e, o) {
  m <- lm(reformulate(c(e, "median_hh_income","poverty_rate","pct_bachelors_plus",
                        "unemployment_rate","pct_hispanic","pct_nh_black","pct_65_plus",
                        "log_pop_density"), response = o), data = d)
  s <- summary(m)$coefficients
  if (e %in% rownames(s)) s[e, "Estimate"] / sd(d[[o]]) * sd(d[[e]]) else NA
}, cc$exposure, cc$outcome)
cc[, 3:5] <- lapply(cc[, 3:5], round, 3)
write.csv(cc, file.path(PATHS$outputs, "correlations_pfas_outcomes.csv"), row.names = FALSE)
cat("\n--- PFAS exposure x outcome correlations (primary sample) ---\n"); print(cc)

## ---- full correlation matrix ---------------------------
mat_vars <- c(out_vars, "pfas_sum_ugL","pfas_hazard_index","pfas_n_detected_popwt",
              "median_hh_income","poverty_rate","pct_bachelors_plus","unemployment_rate",
              "pct_hispanic","pct_nh_black","pct_65_plus","pct_renter_occ",
              "pop_density_km2","svi_index")
M <- cor(d[, mat_vars], use = "pairwise.complete.obs")
write.csv(round(M, 3), file.path(PATHS$outputs, "correlation_matrix_full.csv"))

## ---- PFAS by SES-vulnerability tertile -----------------
d$svi_tertile <- cut(d$svi_index, quantile(d$svi_index, c(0, 1/3, 2/3, 1), na.rm = TRUE),
                     labels = c("Low vuln.", "Mid vuln.", "High vuln."), include.lowest = TRUE)
by_svi <- do.call(rbind, lapply(split(d, d$svi_tertile), function(g) data.frame(
  svi_tertile = g$svi_tertile[1], n = nrow(g),
  pct_any_detect = round(100 * mean(g$pfas_any_detect), 1),
  mean_pfas_sum_ugL = round(mean(g$pfas_sum_ugL, na.rm = TRUE), 4),
  mean_hazard_index = round(mean(g$pfas_hazard_index, na.rm = TRUE), 3),
  pct_mcl_exceed = round(100 * mean(g$any_mcl_exceedance), 1),
  mean_obesity = round(mean(g$obesity_pct), 1),
  mean_diabetes = round(mean(g$diabetes_pct), 1),
  mean_bphigh = round(mean(g$bphigh_pct), 1))))
write.csv(by_svi, file.path(PATHS$outputs, "pfas_by_svi_tertile.csv"), row.names = FALSE)
cat("\n--- PFAS exposure & outcomes by SES-vulnerability tertile ---\n"); print(by_svi)

## ---- figures ------------------------------------------
png(file.path(PATHS$figures, "fig_corr_heatmap.png"), width = 1900, height = 1700, res = 200)
op <- par(mar = c(11, 11, 2, 2))
image(seq_len(ncol(M)), seq_len(nrow(M)), t(M[nrow(M):1, ]), axes = FALSE,
      col = colorRampPalette(c("#2166ac","white","#b2182b"))(41), zlim = c(-1, 1),
      xlab = "", ylab = "", main = "Pearson correlation -- Texas ZCTA primary sample")
axis(1, seq_len(ncol(M)), colnames(M), las = 2, cex.axis = .8)
axis(2, seq_len(nrow(M)), rev(rownames(M)), las = 2, cex.axis = .8)
for (i in seq_len(nrow(M))) for (j in seq_len(ncol(M)))
  text(j, nrow(M) - i + 1, sprintf("%.2f", M[i, j]), cex = .6)
par(op); dev.off()

long <- do.call(rbind, lapply(out_vars, function(o) data.frame(
  outcome = vars[[o]], y = d[[o]], x = d$pfas_hazard_index)))
p <- ggplot(long, aes(x, y)) +
  geom_point(alpha = .35, size = .8) +
  geom_smooth(method = "lm", se = TRUE, colour = "#b2182b") +
  facet_wrap(~outcome, scales = "free_y") +
  labs(x = "EPA PFAS Hazard Index (ZCTA, population-weighted)", y = "Prevalence (%)",
       title = "PFAS mixture exposure vs chronic-disease prevalence, Texas ZCTAs",
       subtitle = sprintf("n = %d ZCTA; unadjusted", nrow(d))) +
  theme_minimal(base_size = 12)
ggsave(file.path(PATHS$figures, "fig_pfas_outcome_scatter.png"), p, width = 11, height = 4.2, dpi = 200)

msg("09_descriptives.R done")
