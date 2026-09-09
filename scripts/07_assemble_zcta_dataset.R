# =====================================================================
# 07_assemble_zcta_dataset.R
# Integrate PFAS exposure + health outcomes + ACS covariates + geography
# into one Texas ZCTA-level analytical dataset.
#
#   EPA UCMR5 PFAS  -> PWS  -> ZIP served -> ZCTA -> CDC PLACES -> ACS
#
#   inputs : data/processed/{ucmr5_pws_exposure, pws_tx_characteristics,
#            zip_zcta_xwalk, places_zcta_wide, acs_zcta_covariates,
#            zcta_geo_tx}.rds
#   outputs: data/processed/texas_zcta_analytical      (sf + csv)
#            data/processed/texas_zcta_pfas_only       (PFAS aggregation audit)
#            data/processed/bexar_zcta_analytical
# ---------------------------------------------------------------------
# PFAS -> ZCTA aggregation (documented in memo):
#   A ZCTA can be served by several PWS; a PWS serves several ZIPs/ZCTAs.
#   For ZCTA z we take every Texas UCMR5 PWS whose served-ZIP list contains
#   a ZIP equal to z, and aggregate their PWS-level measures weighted by
#   SDWIS population_served_count.  The weight is the *system* population,
#   not the population of z served by that system (not published), so the
#   ZCTA value is a population-informed average of the systems reaching z,
#   not a measured residential exposure.
# =====================================================================
if (!exists("PATHS")) source(if (file.exists("scripts/00_setup.R")) "scripts/00_setup.R" else "00_setup.R")

exp   <- as.data.table(readRDS(file.path(PATHS$processed, "ucmr5_pws_exposure.rds")))
pwsc  <- as.data.table(readRDS(file.path(PATHS$processed, "pws_tx_characteristics.rds")))
xw    <- as.data.table(readRDS(file.path(PATHS$processed, "zip_zcta_xwalk.rds")))
places<- as.data.table(readRDS(file.path(PATHS$processed, "places_zcta_wide.rds")))
acs   <- as.data.table(readRDS(file.path(PATHS$processed, "acs_zcta_covariates.rds")))
geo   <- readRDS(file.path(PATHS$processed, "zcta_geo_tx.rds"))

## ---- 1. PWS-level frame for Texas -------------------------
tx <- merge(exp[substr(pwsid, 1, 2) == "TX"],
            pwsc[, .(pwsid, population_served_count, pws_type_code,
                     gw_sw_code, owner_type_code, county_served_sdwis)],
            by = "pwsid", all.x = TRUE)
tx[, w := pmax(population_served_count, 1, na.rm = TRUE)]
msg("Texas UCMR5 PWS: %d | with >=1 PFAS detection: %d | MCL/HI exceedance: %d",
    nrow(tx), sum(tx$pfas_any_detect), sum(tx$any_mcl_exceedance))

## ---- 2. PWS x ZCTA edges ----------------------------------
edges <- xw[substr(pwsid, 1, 2) == "TX" & !is.na(zcta), .(pwsid, zcta)]
edges <- unique(edges)
edges <- merge(edges, tx, by = "pwsid")
msg("PWS-ZCTA edges: %d | distinct ZCTA reached: %d | distinct PWS with a ZCTA: %d",
    nrow(edges), data.table::uniqueN(edges$zcta), data.table::uniqueN(edges$pwsid))

## ---- 3. aggregate PFAS exposure to ZCTA -------------------
agg <- edges[, .(
  n_pws_serving          = uniqueN(pwsid),
  pws_pop_served_sum     = sum(population_served_count, na.rm = TRUE),
  pws_pop_served_max     = max(population_served_count, na.rm = TRUE),
  frac_pws_surface_water = mean(gw_sw_code == "SW", na.rm = TRUE),

  # (1) any PFAS detected among serving systems
  pfas_any_detect        = as.integer(any(pfas_any_detect == 1)),
  pfas_detect_popwt      = wmean(pfas_any_detect, w),
  # (2) number of PFAS compounds detected
  pfas_n_detected_max    = max(pfas_n_detected, na.rm = TRUE),
  pfas_n_detected_popwt  = wmean(pfas_n_detected, w),
  # (3) selected major compounds (population-weighted mean of PWS means)
  pfoa_ugL   = wmean(conc_pfoa_ugL,  w),
  pfos_ugL   = wmean(conc_pfos_ugL,  w),
  pfhxs_ugL  = wmean(conc_pfhxs_ugL, w),
  pfna_ugL   = wmean(conc_pfna_ugL,  w),
  genx_ugL   = wmean(conc_hfpoda_ugL, w),
  pfbs_ugL   = wmean(conc_pfbs_ugL,  w),
  # (4) sum of measured PFAS concentrations
  pfas_sum_ugL        = wmean(pfas_sum_ugL,        w),
  pfas_sum_ndhalf_ugL = wmean(pfas_sum_ndhalf_ugL, w),
  pfas_max_single_ugL = max(pfas_max_single_ugL, na.rm = TRUE),
  # (5) EPA 2024 Hazard Index mixture metric
  pfas_hazard_index      = wmean(pfas_hazard_index, w),
  pfas_hazard_index_max  = max(pfas_hazard_index, na.rm = TRUE),
  # (6) detection-frequency measure
  pfas_detect_freq       = wmean(pfas_detect_freq, w),
  # regulatory exceedance
  any_mcl_exceedance     = as.integer(any(any_mcl_exceedance == 1)),
  mcl_exceedance_popwt   = wmean(any_mcl_exceedance, w)
), by = zcta]
agg[!is.finite(pfas_max_single_ugL),    pfas_max_single_ugL := 0]
agg[!is.finite(pfas_hazard_index_max),  pfas_hazard_index_max := 0]
agg[, pfas_exposure_available := 1L]
save_processed(as.data.frame(agg), "texas_zcta_pfas_only")

## ---- 4. join everything onto the Texas ZCTA universe -----
d <- merge(as.data.table(sf::st_drop_geometry(geo)), agg,   by = "zcta", all.x = TRUE)
d <- merge(d, places[, .(zcta, places_pop = totalpop, obesity_pct, diabetes_pct,
                         bphigh_pct, obesity_ci_width, diabetes_ci_width,
                         bphigh_ci_width, places_complete)], by = "zcta", all.x = TRUE)
d <- merge(d, acs, by = "zcta", all.x = TRUE)

d[is.na(pfas_exposure_available), pfas_exposure_available := 0L]
d[is.na(places_complete),         places_complete := 0L]
d[is.na(acs_covar_complete),      acs_covar_complete := 0L]

## ---- 5. derived context variables ------------------------
d[, pop_density_km2 := ifelse(is.finite(acs_pop_total) & aland_m2 > 0,
                              acs_pop_total / (aland_m2 / 1e6), NA_real_)]
d[, urban_flag := as.integer(pop_density_km2 >= 400)]     # ~1,000 /sq mi
d[, log_pop_density := log1p(pop_density_km2)]

# socioeconomic-vulnerability index: mean of z-scores (within Texas ZCTA
# universe with ACS data); higher = more vulnerable
zsc <- function(x) as.numeric(scale(x))
svi_ok <- d$acs_covar_complete == 1
d[, svi_index := NA_real_]
d[svi_ok, svi_index := rowMeans(cbind(
  zsc(poverty_rate[svi_ok]),
  zsc(pct_less_than_hs[svi_ok]),
  zsc(unemployment_rate[svi_ok]),
  zsc(pct_minority[svi_ok]),
  -zsc(median_hh_income[svi_ok]),
  zsc(pct_renter_occ[svi_ok])
), na.rm = TRUE)]

## ---- 6. analytic-sample flags ---------------------------
d[, health_complete := places_complete]
d[, analytic_full := as.integer(pfas_exposure_available == 1 &
                                health_complete == 1 & acs_covar_complete == 1)]
# a minimum-population screen for estimate stability
d[, pop_screen_ok := as.integer(is.finite(acs_pop_total) & acs_pop_total >= 500)]
d[, analytic_primary := as.integer(analytic_full == 1 & pop_screen_ok == 1)]

d[, in_bexar := as.integer(county_fips == CFG$bexar_county_fips)]

## ---- 7. transformations for modelling -------------------
d[, pfas_sum_log        := log1p(pfas_sum_ugL)]
d[, pfas_hi_log         := log1p(pfas_hazard_index)]
d[, pfoa_log            := log1p(pfoa_ugL)]
d[, pfos_log            := log1p(pfos_ugL)]
d[, pfas_detected_hi_lo := as.integer(pfas_hazard_index >
                                      stats::median(pfas_hazard_index[analytic_primary == 1], na.rm = TRUE))]

## ---- 8. write sf + csv ---------------------------------
d_sf <- dplyr::left_join(geo["zcta"], as.data.frame(d), by = "zcta") |>
  sf::st_transform(4269)

msg("---- Texas ZCTA integration funnel ----")
msg("  TX ZCTA universe ................. %d", nrow(d))
msg("  with PFAS exposure linked ....... %d", sum(d$pfas_exposure_available))
msg("  + PLACES health complete ........ %d", sum(d$pfas_exposure_available & d$health_complete))
msg("  + ACS covariates complete ....... %d", sum(d$analytic_full))
msg("  + population screen (>=500) ...... %d  <- primary analytic sample", sum(d$analytic_primary))
msg("  Bexar County ZCTA in primary .... %d", sum(d$analytic_primary == 1 & d$in_bexar == 1, na.rm = TRUE))

save_processed(d_sf, "texas_zcta_analytical")
save_processed(dplyr::filter(d_sf, in_bexar == 1), "bexar_zcta_analytical")
msg("07_assemble_zcta_dataset.R done")
