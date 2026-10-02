# =====================================================================
# 18_a3c_build_hybrid_exposure.R
# A3c -- the real follow-through on A3a's deferred question: rebuild ZCTA
# PFAS exposure using TWDB's actual mapped service-area polygons (where
# usable) instead of the self-reported "ZIP codes served" list that both
# Phase 1 and A3a relied on. This is a structurally different input, not
# just a different weighting rule within the same ZIP-code list (see
# docs/a3c_twdb_feasibility_note.md for why that distinction matters).
#
# Eligibility funnel for using a PWS's real TWDB polygon (documented, not
# silent -- every excluded system falls back to Phase 1's original
# ZIP-based assignment, so total ZCTA coverage is unchanged):
#   1,154  Texas UCMR5 PWS (Phase 1's universe)
#   -> 1,130  have a TWDB polygon record at all (match by PWSId)
#   -> 1,128  of those also have a usable Area (>0) and a usable
#             SDWIS population_served_count (>0), so an implied density
#             can be computed
#   -> 1,120  of those pass a population-density plausibility check
#             (>= 10 people / sq mi -- excludes 8 systems whose TWDB
#             polygon is almost certainly a legal/CCN-scale boundary far
#             larger than the system's actual built-out service area,
#             e.g. "MILLERSVIEW DOOLE WSC" at 3.15 people/sq mi over
#             1,267 sq mi)
# The remaining 34 systems (24 unmatched + 2 missing area/population +
# 8 implausible-density) use Phase 1's original ZIP-based full-weight
# assignment, unchanged -- a documented hybrid, not a silent gap.
#
# For the 1,120 eligible systems: weight = that PWS's reported population
# (SDWIS population_served_count) x (area of PWS polygon inside this ZCTA
# / total area of PWS polygon) -- i.e. population distributed in
# proportion to how much of the PWS's REAL mapped footprint falls in each
# ZCTA. This is "method 3 (area-weighted)" from
# docs/a3a_assignment_methods_inventory.csv, explicitly marked
# "NOT OPERATIONALIZABLE for this step" at the time because no PWS polygon
# existed -- it does now, for these 1,120 systems.
#
# Documented limitation: this weights by polygon AREA, not by population
# actually living in each ZCTA-slice of that polygon (no sub-ZCTA
# population raster is used anywhere in this project) -- same category of
# simplification as A3b's "geometric centroid, not population-weighted"
# choice. It is still a genuine improvement over a ZIP-code list, because
# the polygon itself is a mapped geographic object instead of an
# administrative billing list.
# =====================================================================
if (!exists("DA_PATHS")) source(if (file.exists("phase2/direction_a_feasibility/scripts/00_setup.R"))
  "phase2/direction_a_feasibility/scripts/00_setup.R" else "00_setup.R")
suppressPackageStartupMessages({library(sf); library(data.table)})

exp   <- as.data.table(readRDS(file.path(PATHS$processed, "ucmr5_pws_exposure.rds")))
pwsc  <- as.data.table(readRDS(file.path(PATHS$processed, "pws_tx_characteristics.rds")))
xw    <- as.data.table(readRDS(file.path(PATHS$processed, "zip_zcta_xwalk.rds")))
twdb  <- readRDS(file.path(DA_PATHS$processed, "a3c_twdb_service_areas.rds"))
base  <- readRDS(file.path(PATHS$processed, "texas_zcta_analytical.rds"))

tx <- merge(exp[substr(pwsid, 1, 2) == "TX"],
            pwsc[, .(pwsid, population_served_count)], by = "pwsid", all.x = TRUE)
tx[, w_phase1 := pmax(population_served_count, 1, na.rm = TRUE)]

## ---- A3c.1 -- re-derive the eligibility funnel (self-contained, not
## dependent on any prior interactive session) -----------------------
twdb_dt <- as.data.table(sf::st_drop_geometry(twdb))
elig <- merge(tx[, .(pwsid, population_served_count)], twdb_dt[, .(pwsid = PWSId, Area, Source, STATUS)],
              by = "pwsid", all.x = TRUE)
elig[, matched := !is.na(Area)]
elig[, density := population_served_count / Area]
elig[, usable_density := matched & is.finite(density) & population_served_count > 0 & Area > 0]
elig[, plausible := usable_density & density >= 10]
good_pws <- elig[plausible == TRUE, pwsid]

cat("\n===== A3c.1 -- eligibility funnel for using the real TWDB polygon =====\n")
cat(sprintf("Phase 1 Texas UCMR5 PWS:                    %d\n", nrow(elig)))
cat(sprintf("  matched to a TWDB polygon:                %d\n", sum(elig$matched)))
cat(sprintf("  + usable area & population (density calc): %d\n", sum(elig$usable_density, na.rm = TRUE)))
cat(sprintf("  + density >= 10 people/sq mi (ELIGIBLE):   %d\n", length(good_pws)))
cat(sprintf("  -> falls back to Phase 1 ZIP-based method: %d\n", nrow(elig) - length(good_pws)))
write.csv(elig, file.path(DA_PATHS$outputs, "a3c_eligibility_funnel.csv"), row.names = FALSE)

## ---- A3c.2 -- spatial overlay for the eligible PWS -------------------
zcta_poly <- base[, "zcta"] |> sf::st_transform(5070)
twdb_elig <- twdb[twdb$PWSId %in% good_pws, c("PWSId", "Area")]
n_invalid <- sum(!sf::st_is_valid(twdb_elig))
msg("Repairing %d invalid geometries among the %d eligible PWS polygons (st_make_valid)", n_invalid, nrow(twdb_elig))
twdb_elig <- sf::st_make_valid(twdb_elig) |> sf::st_transform(5070)
twdb_elig$pws_area_m2 <- as.numeric(sf::st_area(twdb_elig))

msg("Intersecting %d eligible PWS polygons with %d ZCTA polygons...", nrow(twdb_elig), nrow(zcta_poly))
ix <- sf::st_intersection(twdb_elig, zcta_poly)
ix$overlap_m2 <- as.numeric(sf::st_area(ix))
ix_dt <- as.data.table(sf::st_drop_geometry(ix))
ix_dt <- ix_dt[overlap_m2 > 0]
ix_dt[, frac_of_pws := overlap_m2 / pws_area_m2]
msg("Spatial overlay produced %d PWS-ZCTA edges for the %d eligible systems", nrow(ix_dt), uniqueN(ix_dt$PWSId))

edges_spatial <- merge(ix_dt[, .(pwsid = PWSId, zcta, frac_of_pws)], tx, by = "pwsid")
edges_spatial[, w_twdb := w_phase1 * frac_of_pws]
edges_spatial[, method := "twdb_polygon"]

## ---- A3c.3 -- fallback edges for the remaining systems (Phase 1's
## original ZIP-based assignment, unchanged) ----------------------------
fallback_pws <- setdiff(tx$pwsid, good_pws)
edges_fallback <- xw[substr(pwsid, 1, 2) == "TX" & pwsid %in% fallback_pws & !is.na(zcta), .(pwsid, zcta)]
edges_fallback <- unique(edges_fallback)
edges_fallback <- merge(edges_fallback, tx, by = "pwsid")
edges_fallback[, w_twdb := w_phase1]
edges_fallback[, method := "zip_fallback"]
msg("%d fallback systems contribute %d ZIP-based edges (Phase 1 method, unchanged)",
    length(fallback_pws), nrow(edges_fallback))

edges_hybrid <- rbind(edges_spatial[, .(pwsid, zcta, w_twdb, method, pfas_hazard_index, pfas_n_detected, pfas_detect_freq, pfas_any_detect)],
                      edges_fallback[, .(pwsid, zcta, w_twdb, method, pfas_hazard_index, pfas_n_detected, pfas_detect_freq, pfas_any_detect)])
write.csv(edges_hybrid[, .(n_edges = .N, n_pws = uniqueN(pwsid), n_zcta = uniqueN(zcta)), by = method],
          file.path(DA_PATHS$outputs, "a3c_edge_method_summary.csv"), row.names = FALSE)

## ---- A3c.4 -- aggregate to ZCTA (same wmean() convention as A3a) -----
agg_hybrid <- edges_hybrid[, .(
  n_pws_serving_hybrid     = uniqueN(pwsid),
  pct_edges_from_polygon   = round(100 * mean(method == "twdb_polygon"), 1),
  pfas_hazard_index_hybrid = wmean(pfas_hazard_index, w_twdb),
  pfas_n_detected_hybrid   = wmean(pfas_n_detected, w_twdb),
  pfas_detect_freq_hybrid  = wmean(pfas_detect_freq, w_twdb),
  pfas_any_detect_hybrid   = wmean(pfas_any_detect, w_twdb)
), by = zcta]
agg_hybrid[, pfas_hi_hybrid := log1p(pfas_hazard_index_hybrid)]

d <- dplyr::left_join(base, as.data.frame(agg_hybrid), by = "zcta")
d$pfas_hi_phase1 <- d$pfas_hi_log
d$pfas_hazard_index_phase1 <- d$pfas_hazard_index

msg("A3c hybrid exposure built for %d ZCTAs (Phase 1 had exposure for %d)",
    sum(!is.na(d$pfas_hi_hybrid)), sum(d$pfas_exposure_available == 1))

da_save(d, "a3c_zcta_exposure_hybrid")
msg("18_a3c_build_hybrid_exposure.R done")
