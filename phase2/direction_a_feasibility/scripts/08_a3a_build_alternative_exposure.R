# =====================================================================
# 08_a3a_build_alternative_exposure.R
# A3a.3 -- rebuild ZCTA PFAS exposure under the equal-split population
# weighting identified in 07_a3a_assignment_inventory.R, alongside (never
# overwriting) the Phase 1 baseline.
#
# Baseline edge weight (Phase 1, scripts/07_assemble_zcta_dataset.R):
#   w_phase1 = population_served_count            (full PWS population,
#              counted again in every ZIP/ZCTA that PWS reports serving)
# Alternative edge weight (this script):
#   w_popwt  = population_served_count / n_zips_reported_by_that_pws
#              (each PWS's population is split evenly across the ZIP
#               codes it reports serving -- an assumption, not a
#               measurement, but a different and reproducible one)
#
# Same PFAS metrics as Phase 1 (Hazard Index primary; detection frequency
# and number-detected retained as sensitivity). No new chemical weighting.
# =====================================================================
if (!exists("DA_PATHS")) source(if (file.exists("phase2/direction_a_feasibility/scripts/00_setup.R"))
  "phase2/direction_a_feasibility/scripts/00_setup.R" else "00_setup.R")
library(data.table)

exp  <- as.data.table(readRDS(file.path(PATHS$processed, "ucmr5_pws_exposure.rds")))
pwsc <- as.data.table(readRDS(file.path(PATHS$processed, "pws_tx_characteristics.rds")))
xw   <- as.data.table(readRDS(file.path(PATHS$processed, "zip_zcta_xwalk.rds")))

tx <- merge(exp[substr(pwsid, 1, 2) == "TX"],
            pwsc[, .(pwsid, population_served_count)], by = "pwsid", all.x = TRUE)
tx[, w_phase1 := pmax(population_served_count, 1, na.rm = TRUE)]

## how many ZIPs does each TX PWS report serving? (the UCMR5 ZIP list,
## same source Phase 1 uses for the ZIP->ZCTA crosswalk)
n_zip_per_pws <- xw[substr(pwsid, 1, 2) == "TX", .(n_zips_reported = uniqueN(zip)), by = pwsid]
cat("\n===== A3a.3 -- how many ZIPs does one PWS claim to serve? (TX UCMR5 systems) =====\n")
print(summary(n_zip_per_pws$n_zips_reported))
cat(sprintf("systems reporting >=10 ZIPs: %d  (these are the ones most affected by the baseline's full-weight-per-ZIP mechanism)\n",
            sum(n_zip_per_pws$n_zips_reported >= 10)))
write.csv(n_zip_per_pws[order(-n_zips_reported)][1:15], file.path(DA_PATHS$outputs, "a3a_most_multi_zip_pws.csv"), row.names = FALSE)

edges <- xw[substr(pwsid, 1, 2) == "TX" & !is.na(zcta), .(pwsid, zcta)]
edges <- unique(edges)
edges <- merge(edges, tx, by = "pwsid")
edges <- merge(edges, n_zip_per_pws, by = "pwsid", all.x = TRUE)
edges[, w_popwt := w_phase1 / pmax(n_zips_reported, 1)]

agg_alt <- edges[, .(
  n_pws_serving     = uniqueN(pwsid),
  pfas_hazard_index_popwt = wmean(pfas_hazard_index, w_popwt),
  pfas_n_detected_popwt2  = wmean(pfas_n_detected, w_popwt),
  pfas_detect_freq_popwt2 = wmean(pfas_detect_freq, w_popwt),
  pfas_any_detect_popwt2  = wmean(pfas_any_detect, w_popwt)
), by = zcta]
agg_alt[, pfas_hi_popwt := log1p(pfas_hazard_index_popwt)]

base <- readRDS(file.path(PATHS$processed, "texas_zcta_analytical.rds"))
d <- dplyr::left_join(base, as.data.frame(agg_alt), by = "zcta")
# keep Phase 1's field under an explicit, non-overwritten alias for comparison
d$pfas_hi_phase1 <- d$pfas_hi_log
d$pfas_hazard_index_phase1 <- d$pfas_hazard_index

msg("A3a alternative exposure built for %d ZCTAs (Phase 1 had exposure for %d)",
    sum(!is.na(d$pfas_hi_popwt)), sum(d$pfas_exposure_available == 1))

da_save(d, "a3a_zcta_exposure_compare")
msg("08_a3a_build_alternative_exposure.R done")
