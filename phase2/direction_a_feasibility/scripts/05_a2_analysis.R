# =====================================================================
# 05_a2_analysis.R
# A2.5 (link) / A2.6 (descriptive spatial) / A2.7 (simple regression) for
# A2-LBW. A2-PTB is NOT run -- no county-level public dataset was found
# or pulled (see 04_a2_read_birth_outcomes.R header); this is documented,
# not silently skipped.
# No GWR / MGWR / PSM / Bayesian / ML. Ecological; no causal claim.
# =====================================================================
if (!exists("DA_PATHS")) source(if (file.exists("phase2/direction_a_feasibility/scripts/00_setup.R"))
  "phase2/direction_a_feasibility/scripts/00_setup.R" else "00_setup.R")
suppressPackageStartupMessages({library(sf); library(ggplot2)})
old_ggsave <- ggplot2::ggsave; ggsave <- function(...) old_ggsave(..., bg = "white")
have <- function(p) requireNamespace(p, quietly = TRUE)

county_exp <- readRDS(file.path(DA_PATHS$processed, "a2_county_exposure.rds"))
lbw19 <- readRDS(file.path(DA_PATHS$processed, "a2_lbw_county_2019.rds"))

## ---- A2.5: link + funnel ---------------------------------------------
m <- dplyr::left_join(county_exp, lbw19, by = "county")
m$has_pfas <- !is.na(m$pfas_hazard_index_popwt) & m$coverage_pct > 0
m$has_lbw  <- !is.na(m$lbw_pct) & !m$suppressed_pct
COUNTY_COV <- c("median_hh_income", "poverty_rate", "pct_bachelors_plus", "pct_hispanic", "pct_nh_black")
m$log_pop_density_cty <- log(pmax(m$pop_density_km2, 1e-3))
m$has_cov  <- stats::complete.cases(m[, COUNTY_COV])

funnel <- data.frame(step = c(
  "Texas counties (total)",
  "  ... with usable county-level PFAS exposure (pop-weighted, coverage > 0)",
  "  ... also with a non-suppressed 2019 LBW rate",
  "  ... also with complete county-level covariates  [A2-LBW ANALYTIC SAMPLE]"
), n = c(nrow(m), sum(m$has_pfas), sum(m$has_pfas & m$has_lbw), sum(m$has_pfas & m$has_lbw & m$has_cov)))
write.csv(funnel, file.path(DA_PATHS$outputs, "a2_lbw_linkage_funnel.csv"), row.names = FALSE)
cat("\n===== A2.5 -- A2-LBW linkage funnel =====\n"); print(funnel, row.names = FALSE)

## is missingness/suppression related to exposure? (are high-exposure
## counties disproportionately missing the outcome?)
miss_check <- data.frame(
  group = c("LBW rate usable", "LBW rate suppressed/missing"),
  n = c(sum(m$has_pfas & m$has_lbw), sum(m$has_pfas & !m$has_lbw)),
  mean_county_HI = c(mean(m$pfas_hazard_index_popwt[m$has_pfas & m$has_lbw], na.rm = TRUE),
                      mean(m$pfas_hazard_index_popwt[m$has_pfas & !m$has_lbw], na.rm = TRUE)),
  mean_pop_density = c(mean(m$pop_density_km2[m$has_pfas & m$has_lbw], na.rm = TRUE),
                        mean(m$pop_density_km2[m$has_pfas & !m$has_lbw], na.rm = TRUE)))
write.csv(miss_check, file.path(DA_PATHS$outputs, "a2_lbw_missingness_check.csv"), row.names = FALSE)
cat("\n--- Is outcome suppression related to exposure or urbanicity? ---\n"); print(miss_check, row.names = FALSE)

d <- m[m$has_pfas & m$has_lbw & m$has_cov, ]
msg("A2-LBW analytic sample: n = %d counties", nrow(d))

## ---- A2.6: descriptive + correlation ----------------------------------
desc <- data.frame(
  variable = c("lbw_pct", "pfas_hazard_index_popwt", "pfas_hi_log", COUNTY_COV),
  n = sapply(c("lbw_pct", "pfas_hazard_index_popwt", "pfas_hi_log", COUNTY_COV), function(v) sum(is.finite(d[[v]]))),
  mean = sapply(c("lbw_pct", "pfas_hazard_index_popwt", "pfas_hi_log", COUNTY_COV), function(v) mean(d[[v]], na.rm = TRUE)),
  sd   = sapply(c("lbw_pct", "pfas_hazard_index_popwt", "pfas_hi_log", COUNTY_COV), function(v) sd(d[[v]], na.rm = TRUE)),
  median = sapply(c("lbw_pct", "pfas_hazard_index_popwt", "pfas_hi_log", COUNTY_COV), function(v) median(d[[v]], na.rm = TRUE)))
desc[, 3:5] <- lapply(desc[, 3:5], round, 3)
write.csv(desc, file.path(DA_PATHS$outputs, "a2_lbw_descriptives.csv"), row.names = FALSE)

cor_a2 <- data.frame(
  outcome = "lbw_pct",
  pearson = round(cor(d$pfas_hazard_index_popwt, d$lbw_pct, use = "complete.obs"), 3),
  spearman = round(cor(d$pfas_hazard_index_popwt, d$lbw_pct, method = "spearman", use = "complete.obs"), 3))
write.csv(cor_a2, file.path(DA_PATHS$outputs, "a2_lbw_correlation.csv"), row.names = FALSE)
cat("\n===== A2.6 -- correlation: county PFAS HI x LBW rate =====\n"); print(cor_a2, row.names = FALSE)

## map
cty_sf <- sf::st_read(file.path(PATHS$raw_geo, "cb_2022_us_county_500k.shp"), quiet = TRUE)
cty_sf <- cty_sf[cty_sf$STATEFP == "48", ] |> sf::st_transform(5070)
tx_state <- sf::st_read(file.path(PATHS$raw_geo, "cb_2022_us_state_500k.shp"), quiet = TRUE)
tx_state <- tx_state[tx_state$STUSPS == "TX", ] |> sf::st_transform(5070)
m_sf <- dplyr::left_join(cty_sf, m, by = c("GEOID" = "county"))
n_no_lbw <- sum(!m$has_lbw)
ggsave(file.path(DA_PATHS$figures, "a2_map_lbw_rate.png"),
  ggplot() + geom_sf(data = m_sf, aes(fill = lbw_pct), colour = "white", linewidth = .15) +
    geom_sf(data = tx_state, fill = NA, colour = "grey30", linewidth = .4) +
    scale_fill_viridis_c(option = "viridis", name = "LBW %", na.value = "grey85") +
    labs(title = "A2 -- low birth weight rate by Texas county (2019)",
         subtitle = sprintf("grey = suppressed or no usable rate (%d of 254 counties)", n_no_lbw)) +
    theme_void(base_size = 12), width = 7.5, height = 7, dpi = 200)

## ---- A2.7: crude + adjusted regression --------------------------------
scale_keep <- function(x) as.numeric(scale(x))
Ds <- d; Ds[COUNTY_COV] <- lapply(Ds[COUNTY_COV], scale_keep); Ds$log_pop_density_cty <- scale_keep(Ds$log_pop_density_cty)
e <- "pfas_hi_log"
cov_cty <- c(COUNTY_COV, "log_pop_density_cty")

fit_report <- function(fm, data, label, w = NULL) {
  if (!is.null(w)) data$.wt_tmp <- w  # named column in `data` -- lm()'s weights= is looked up
  mod <- if (is.null(w)) lm(fm, data = data) else lm(fm, data = data, weights = .wt_tmp)
  V <- if (have("sandwich")) sandwich::vcovHC(mod, type = "HC1") else vcov(mod)
  se <- sqrt(diag(V))[e]; b <- coef(mod)[e]
  list(model = mod, row = data.frame(model = label, beta = b, se_hc1 = se,
       std_beta = b * sd(data[[e]]) / sd(data$lbw_pct), t = b / se, p_value = 2 * pnorm(-abs(b / se)),
       r2 = summary(mod)$r.squared, adj_r2 = summary(mod)$adj.r.squared, n = nobs(mod)))
}
m0 <- fit_report(reformulate(e, "lbw_pct"), Ds, "A2-LBW-0 crude")
m1 <- fit_report(reformulate(c(e, cov_cty), "lbw_pct"), Ds, "A2-LBW-1 adjusted")
m2 <- fit_report(reformulate(c(e, cov_cty), "lbw_pct"), Ds, "A2-LBW-2 adjusted, births-weighted", w = Ds$total_births_derived)
reg <- rbind(m0$row, m1$row, m2$row)
reg$partial_r2_over_covariates_only <- c(NA, m1$row$r2 - summary(lm(reformulate(cov_cty, "lbw_pct"), data = Ds))$r.squared, NA)
reg[, 2:9] <- lapply(reg[, 2:9], function(x) signif(x, 4))
write.csv(reg, file.path(DA_PATHS$outputs, "a2_lbw_regression.csv"), row.names = FALSE)
cat("\n===== A2.7 -- crude vs adjusted regression (county LBW rate ~ log(1+county HI)) =====\n")
print(reg, row.names = FALSE)

## residual Moran's I (k=6 NN on county centroids, same convention as Phase 1)
spat <- data.frame(model = character(), morans_i = numeric(), p_value = character())
if (have("spdep")) {
  d_sf <- m_sf[match(d$county, m_sf$GEOID), ]
  lw <- build_listw(d_sf, "knn", k = 6)
  for (mm in list(list("A2-LBW-0 crude", m0$model), list("A2-LBW-1 adjusted", m1$model))) {
    mt <- spdep::lm.morantest(mm[[2]], lw, zero.policy = TRUE)
    spat <- rbind(spat, data.frame(model = mm[[1]], morans_i = round(mt$estimate[1], 3),
                                    p_value = format(mt$p.value, digits = 3, scientific = TRUE)))
  }
}
write.csv(spat, file.path(DA_PATHS$outputs, "a2_lbw_spatial_residual_check.csv"), row.names = FALSE)
cat(sprintf("\n===== residual Moran's I, A2-LBW (n = %d counties; much smaller/sparser than the ZCTA check) =====\n", nrow(d)))
print(spat, row.names = FALSE)

## ---- A2-PTB: explicitly not run ---------------------------------------
ptb_note <- data.frame(
  status = "NOT RUN",
  reason = "No Texas DSHS county-level static table found for preterm birth; CDC WONDER D149 API mechanism identified but a working query was not completed within this pilot's scope (see 04_a2_read_birth_outcomes.R).",
  what_would_be_needed = "Either (a) resolve the exact WONDER D149 measure/value codes for gestational age <37 weeks and complete a scripted POST query, grouped by Texas county, or (b) a direct TX DSHS source for preterm birth by county (not found in this pass)."
)
write.csv(ptb_note, file.path(DA_PATHS$outputs, "a2_ptb_status.csv"), row.names = FALSE)
cat("\n===== A2-PTB =====\n"); print(ptb_note, row.names = FALSE)

msg("05_a2_analysis.R done")
