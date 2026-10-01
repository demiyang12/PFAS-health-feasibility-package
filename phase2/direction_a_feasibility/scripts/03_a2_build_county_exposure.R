# =====================================================================
# 03_a2_build_county_exposure.R
# A2.2 / A2.3 -- aggregate Phase 1's ZCTA-level PFAS exposure up to Texas
# counties using an AUTHORITATIVE, population-weighted crosswalk (NOT an
# unweighted mean of ZCTA values, and not pretending area-weighting is the
# same thing as population-weighting).
#
# Primary weighting source : Geocorr 2022 (Missouri Census Data Center),
#   ZCTA -> county correspondence weighted by 2020 Census population.
#   See phase2/direction_a_feasibility/docs/a2_feasibility_summary.md for
#   how this was obtained (a scriptable SAS/CGI broker call, documented in
#   scripts/download_raw_a.sh) and why it was preferred over the HUD-USPS
#   crosswalk (which requires an API key -- breaks this project's
#   keyless-public-data convention).
# Sensitivity weighting    : the Census 2020 ZCTA<->county relationship
#   file Phase 1 already uses (data/raw/geo/zcta_county_rel_2020.txt),
#   which is AREA-based (AREALAND_PART), not population-based.
# =====================================================================
if (!exists("DA_PATHS")) source(if (file.exists("phase2/direction_a_feasibility/scripts/00_setup.R"))
  "phase2/direction_a_feasibility/scripts/00_setup.R" else "00_setup.R")
suppressPackageStartupMessages({library(sf); library(ggplot2)})
old_ggsave <- ggplot2::ggsave; ggsave <- function(...) old_ggsave(..., bg = "white")

## ---- 1. Phase 1's ZCTA-level exposure (ALL Texas ZCTAs, not just the
##         primary analytic sample -- a county can be built from ZCTAs
##         that individually fell short of Phase 1's population>=500 or
##         ACS-completeness screens, as long as they have PFAS data) ----
zcta_all <- sf::st_drop_geometry(readRDS(file.path(PATHS$processed, "texas_zcta_analytical.rds")))
# a small, pre-specified subset of Phase 1's own covariate set (P1_COV),
# aggregated the SAME population-weighted way as exposure -- not a new
# ACS pull, and not chosen by which ones make a later coefficient significant
COUNTY_COV_SRC <- c("median_hh_income", "poverty_rate", "pct_bachelors_plus", "pct_hispanic", "pct_nh_black", "pop_density_km2")
zcta_exp <- zcta_all[, c("zcta", "pfas_exposure_available", "pfas_hazard_index", "pfas_any_detect",
                         "pfas_n_detected_popwt", "pfas_sum_ugL", "pfas_detect_freq",
                         "any_mcl_exceedance", "acs_pop_total", COUNTY_COV_SRC)]
msg("Phase 1 TX ZCTA universe: %d; with PFAS exposure available: %d",
    nrow(zcta_exp), sum(zcta_exp$pfas_exposure_available == 1, na.rm = TRUE))

## ---- 2. PRIMARY crosswalk: Geocorr population-weighted allocation ----
gc <- data.table::fread(file.path(DA_PATHS$raw, "geo", "geocorr2022_zcta_county_tx_pop.csv"),
                        skip = 2, colClasses = "character",
                        col.names = c("zcta", "county", "county_name", "zip_name", "pop20", "afact"))
gc[, zcta := trimws(zcta)]
gc <- gc[zcta != ""]                      # drop "[not in a ZCTA]" residual-population rows
gc[, pop20 := as.numeric(pop20)]
gc[, afact := as.numeric(afact)]
gc[, zcta := zip5(zcta)]
msg("Geocorr TX zcta-county rows: %d | distinct ZCTA: %d | distinct county: %d | zcta split across >1 county: %d",
    nrow(gc), data.table::uniqueN(gc$zcta), data.table::uniqueN(gc$county),
    sum(table(gc$zcta) > 1))

gcx <- merge(gc, zcta_exp, by = "zcta", all.x = TRUE)

## population-weighted county aggregation, using Geocorr's intersection
## population (pop20) as the weight -- this is the population actually
## living in that (ZCTA x county) slice, not the whole-ZCTA population.
popwt_agg <- function(sub) {
  ok <- !is.na(sub$pfas_hazard_index)
  cov_vals <- setNames(lapply(COUNTY_COV_SRC, function(v) wmean(sub[[v]], sub$pop20)), COUNTY_COV_SRC)
  c(list(
    county = sub$county[1], county_name = sub$county_name[1],
    total_pop20 = sum(sub$pop20, na.rm = TRUE),
    pop20_with_pfas = sum(sub$pop20[ok], na.rm = TRUE),
    n_zcta_total = data.table::uniqueN(sub$zcta),
    n_zcta_with_pfas = data.table::uniqueN(sub$zcta[ok]),
    pfas_hazard_index_popwt = if (any(ok)) wmean(sub$pfas_hazard_index[ok], sub$pop20[ok]) else NA_real_,
    pfas_any_detect_popwt   = if (any(ok)) wmean(sub$pfas_any_detect[ok], sub$pop20[ok]) else NA_real_,
    pfas_n_detected_popwt   = if (any(ok)) wmean(sub$pfas_n_detected_popwt[ok], sub$pop20[ok]) else NA_real_,
    pfas_sum_ugL_popwt      = if (any(ok)) wmean(sub$pfas_sum_ugL[ok], sub$pop20[ok]) else NA_real_,
    any_mcl_exceedance_share= if (any(ok)) wmean(sub$any_mcl_exceedance[ok], sub$pop20[ok]) else NA_real_
  ), cov_vals) |> as.data.frame()
}
county_pop <- do.call(rbind, lapply(split(gcx, gcx$county), popwt_agg))
county_pop$coverage_pct <- round(100 * county_pop$pop20_with_pfas / county_pop$total_pop20, 1)
county_pop$pfas_hi_log  <- log1p(county_pop$pfas_hazard_index_popwt)

## ---- 3. SENSITIVITY crosswalk: area-weighted (Phase 1's existing file) ----
rel <- data.table::fread(file.path(PATHS$raw_geo, "zcta_county_rel_2020.txt"),
                         sep = "|", colClasses = "character", showProgress = FALSE)
rel <- rel[GEOID_ZCTA5_20 != ""]
rel[, area_part := as.numeric(AREALAND_PART)]
relx <- merge(rel[, .(zcta = GEOID_ZCTA5_20, county = GEOID_COUNTY_20, area_part)],
              zcta_exp, by = "zcta", all.x = TRUE)
area_agg <- function(sub) {
  ok <- !is.na(sub$pfas_hazard_index)
  if (!any(ok)) return(NA_real_)
  wmean(sub$pfas_hazard_index[ok], sub$area_part[ok])
}
county_area <- do.call(rbind, lapply(split(relx, relx$county), function(s)
  data.frame(county = s$county[1], pfas_hazard_index_areawt = area_agg(s))))

county <- merge(county_pop, county_area, by = "county", all.x = TRUE)
county$pop_vs_area_diff <- round(county$pfas_hazard_index_popwt - county$pfas_hazard_index_areawt, 3)

## ---- 4. diagnostics (A2.3) -------------------------------------------
tx_counties_total <- 254
feas <- data.frame(metric = character(), value = character())
addf <- function(m, v) feas <<- rbind(feas, data.frame(metric = m, value = as.character(v)))
addf("Texas counties (total)", tx_counties_total)
addf("Texas counties appearing in the Geocorr ZCTA-county file", nrow(county))
addf("Counties with ANY population-weighted PFAS exposure (coverage_pct > 0)", sum(county$coverage_pct > 0, na.rm = TRUE))
addf("Counties with NO usable PFAS exposure (coverage_pct == 0 or NA)", sum(is.na(county$coverage_pct) | county$coverage_pct == 0))
addf("Median population coverage (%) among counties with any exposure data", round(median(county$coverage_pct[county$coverage_pct > 0], na.rm = TRUE), 1))
addf("Counties with population coverage >= 80%", sum(county$coverage_pct >= 80, na.rm = TRUE))
addf("% of statewide Geocorr population in counties with any PFAS exposure",
     round(100 * sum(county$pop20_with_pfas, na.rm = TRUE) / sum(county$total_pop20, na.rm = TRUE), 1))
addf("Counties with >=1 ZCTA-level PFAS detection (popwt share > 0)", sum(county$pfas_any_detect_popwt > 0, na.rm = TRUE))
addf("County Hazard Index (pop-wt): min / median / max",
     sprintf("%.3f / %.3f / %.3f", min(county$pfas_hazard_index_popwt, na.rm = TRUE),
             median(county$pfas_hazard_index_popwt, na.rm = TRUE), max(county$pfas_hazard_index_popwt, na.rm = TRUE)))
addf("County HI IQR (compression check vs ZCTA-level)", round(IQR(county$pfas_hazard_index_popwt, na.rm = TRUE), 4))
addf("ZCTA-level HI IQR (Phase 1 primary sample, for comparison)",
     round(IQR(zcta_all$pfas_hazard_index[zcta_all$analytic_primary == 1], na.rm = TRUE), 4))
addf("Pop-weighted vs area-weighted county HI: median absolute difference", round(median(abs(county$pop_vs_area_diff), na.rm = TRUE), 4))
addf("Pop-weighted vs area-weighted county HI: Spearman rank correlation",
     round(cor(county$pfas_hazard_index_popwt, county$pfas_hazard_index_areawt, method = "spearman", use = "complete.obs"), 3))

# how many of Phase 1's top-quartile ("high-exposure") ZCTAs end up in a
# low/mid-tercile county once aggregated -- the core dilution question
q75 <- quantile(zcta_all$pfas_hazard_index[zcta_all$analytic_primary == 1], .75, na.rm = TRUE)
hi_zcta <- zcta_all$zcta[zcta_all$analytic_primary == 1 & zcta_all$pfas_hazard_index >= q75]
# one row per ZCTA: its DOMINANT county (largest population share) -- avoids
# double-counting a ZCTA that straddles >1 county
gcx_dom <- gcx[order(gcx$zcta, -gcx$pop20), ]
gcx_dom <- gcx_dom[!duplicated(gcx_dom$zcta), ]
hi_zcta_county <- gcx_dom$county[gcx_dom$zcta %in% hi_zcta]
county$hi_tercile <- NA_character_
has_hi <- !is.na(county$pfas_hazard_index_popwt)
county$hi_tercile[has_hi] <- c("low", "mid", "high")[
  dplyr::ntile(county$pfas_hazard_index_popwt[has_hi], 3)]
dilution <- table(county$hi_tercile[match(hi_zcta_county, county$county)], useNA = "ifany")
addf("Phase-1 top-quartile-HI ZCTAs: county they land in, by county HI tercile",
     paste(sprintf("%s=%d", names(dilution), dilution), collapse = ", "))

write.csv(feas, file.path(DA_PATHS$outputs, "a2_county_exposure_diagnostics.csv"), row.names = FALSE)
write.csv(county, file.path(DA_PATHS$outputs, "a2_county_exposure_table.csv"), row.names = FALSE)
cat("\n===== A2.3 -- county PFAS exposure construction diagnostics =====\n"); print(feas, row.names = FALSE)

## ---- 5. map + ZCTA-vs-county distribution comparison -----------------
cty_sf <- sf::st_read(file.path(PATHS$raw_geo, "cb_2022_us_county_500k.shp"), quiet = TRUE)
cty_sf <- cty_sf[cty_sf$STATEFP == "48", ] |> sf::st_transform(5070)
cty_map <- dplyr::left_join(cty_sf, county, by = c("GEOID" = "county"))
tx_state <- sf::st_read(file.path(PATHS$raw_geo, "cb_2022_us_state_500k.shp"), quiet = TRUE)
tx_state <- tx_state[tx_state$STUSPS == "TX", ] |> sf::st_transform(5070)

ggsave(file.path(DA_PATHS$figures, "a2_map_county_pfas_hazard_index.png"),
  ggplot() + geom_sf(data = cty_map, aes(fill = pfas_hazard_index_popwt), colour = "white", linewidth = .15) +
    geom_sf(data = tx_state, fill = NA, colour = "grey30", linewidth = .4) +
    scale_fill_viridis_c(option = "plasma", name = "County HI\n(pop-wt)", trans = "sqrt", na.value = "grey90") +
    labs(title = "A2 -- county-level PFAS Hazard Index (population-weighted)",
         subtitle = sprintf("%d of %d TX counties have usable PFAS exposure data", sum(county$coverage_pct > 0, na.rm = TRUE), tx_counties_total)) +
    theme_void(base_size = 12), width = 7.5, height = 7, dpi = 200)

png(file.path(DA_PATHS$figures, "a2_zcta_vs_county_distribution.png"), width = 1400, height = 1000, res = 180)
plot(density(zcta_all$pfas_hazard_index[zcta_all$analytic_primary == 1 & zcta_all$pfas_hazard_index > 0]),
     main = "PFAS Hazard Index: ZCTA-level (Phase 1) vs county-level (A2) distribution",
     xlab = "Hazard Index (> 0 only, for visibility)", col = "#b2182b", lwd = 2, xlim = c(0, 2))
lines(density(county$pfas_hazard_index_popwt[county$pfas_hazard_index_popwt > 0], na.rm = TRUE), col = "#2166ac", lwd = 2)
legend("topright", c("ZCTA-level (Phase 1)", "County-level (A2, pop-weighted)"), col = c("#b2182b", "#2166ac"), lwd = 2)
dev.off()

da_save(county, "a2_county_exposure")
msg("03_a2_build_county_exposure.R done -- %d counties built", nrow(county))
