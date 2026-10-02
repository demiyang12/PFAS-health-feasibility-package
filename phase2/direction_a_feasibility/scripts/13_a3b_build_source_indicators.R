# =====================================================================
# 13_a3b_build_source_indicators.R
# A3b.3 -- simple, transparent ZCTA-level source-pressure indicators from
# the real Texas data pulled in 12_a3b_download_source_data.R.
#
# Distance method: ZCTA GEOMETRIC centroid (polygon centroid), not a
# population-weighted centroid -- documented choice, made for simplicity;
# a population-weighted centroid would need sub-ZCTA population surfaces
# not otherwise used in this project. Projected to EPSG:5070 (Albers,
# meters) for accurate distance calculations, matching the CRS used
# throughout this project for mapping.
# =====================================================================
if (!exists("DA_PATHS")) source(if (file.exists("phase2/direction_a_feasibility/scripts/00_setup.R"))
  "phase2/direction_a_feasibility/scripts/00_setup.R" else "00_setup.R")
suppressPackageStartupMessages({library(sf); library(data.table)})
RAWB <- file.path(DA_PATHS$raw, "a3b_source")

base <- readRDS(file.path(PATHS$processed, "texas_zcta_analytical.rds")) |> sf::st_transform(5070)
cent <- sf::st_centroid(sf::st_geometry(base))

to_pts <- function(df, lon = "longitude", lat = "latitude") {
  df <- df[is.finite(df[[lon]]) & is.finite(df[[lat]]) & df[[lon]] != 0 & df[[lat]] != 0, ]
  sf::st_as_sf(df, coords = c(lon, lat), crs = 4326) |> sf::st_transform(5070)
}

## ---- source 1: TRI facilities that reported a PFAS chemical ----------
tri_forms_tx <- fread(file.path(RAWB, "tri_pfas_reporting_form_tx.csv"))
tri_rel_nat  <- fread(file.path(RAWB, "tri_pfas_release_qty_national.csv"))
tri_loc      <- fread(file.path(RAWB, "ef_tri_facilities_tx.csv"))
pfas_fac <- unique(tri_forms_tx$tri_facility_id)
pfas_loc <- tri_loc[pgm_sys_id %in% pfas_fac]
# prefer dmap_lat/lon (EF's own re-geocode) when present, else the primary lat/lon
pfas_loc[, lon_use := fifelse(is.finite(dmap_longitude) & dmap_longitude != 0, dmap_longitude, longitude)]
pfas_loc[, lat_use := fifelse(is.finite(dmap_latitude)  & dmap_latitude  != 0, dmap_latitude,  latitude)]
pfas_rel_by_fac <- merge(tri_forms_tx, tri_rel_nat, by = "doc_ctrl_num", all.x = TRUE)[
  , .(release_lb = sum(total_release, na.rm = TRUE), n_range_coded_only = sum(is.na(total_release))), by = tri_facility_id]
pfas_loc <- merge(pfas_loc, pfas_rel_by_fac, by.x = "pgm_sys_id", by.y = "tri_facility_id", all.x = TRUE)
msg("TX TRI facilities that reported >=1 PFAS chemical, with usable coordinates: %d", sum(is.finite(pfas_loc$lon_use) & pfas_loc$lon_use != 0))
pfas_pts <- to_pts(pfas_loc, "lon_use", "lat_use")

## ---- source 2: Superfund NPL ------------------------------------------
npl_pts <- to_pts(fread(file.path(RAWB, "ef_npl_tx.csv")))

## ---- source 3: NPDES-permitted facilities -----------------------------
npdes_pts <- to_pts(fread(file.path(RAWB, "ef_npdes_tx.csv")))

## ---- distance / count helpers -----------------------------------------
nearest_km <- function(pts) {
  if (!nrow(pts)) return(rep(NA_real_, length(cent)))
  as.numeric(apply(sf::st_distance(cent, pts), 1, min)) / 1000
}
count_within <- function(pts, km) {
  if (!nrow(pts)) return(rep(0L, length(cent)))
  dm <- sf::st_distance(cent, pts)
  # apply() strips the "units" class from each row (meters), so compare as plain numeric
  apply(dm, 1, function(r) sum(as.numeric(r) <= km * 1000))
}
sum_within <- function(pts, valcol, km) {
  if (!nrow(pts)) return(rep(0, length(cent)))
  dm <- sf::st_distance(cent, pts)
  v <- pts[[valcol]]; v[is.na(v)] <- 0
  apply(dm, 1, function(r) sum(v[as.numeric(r) <= km * 1000]))
}

ind <- data.frame(zcta = base$zcta)
ind$dist_km_nearest_pfas_tri        <- nearest_km(pfas_pts)
ind$n_pfas_tri_within_5km           <- count_within(pfas_pts, 5)
ind$n_pfas_tri_within_10km          <- count_within(pfas_pts, 10)
ind$n_pfas_tri_within_20km          <- count_within(pfas_pts, 20)
ind$pfas_tri_release_lb_within_10km <- sum_within(pfas_pts, "release_lb", 10)
ind$pfas_tri_release_lb_within_20km <- sum_within(pfas_pts, "release_lb", 20)

ind$dist_km_nearest_npl   <- nearest_km(npl_pts)
ind$npl_within_10km       <- as.integer(count_within(npl_pts, 10) > 0)

ind$n_npdes_within_10km   <- count_within(npdes_pts, 10)

write.csv(ind, file.path(DA_PATHS$outputs, "a3b_zcta_source_indicators.csv"), row.names = FALSE)
cat("\n===== A3b.3 -- ZCTA source-pressure indicator coverage =====\n")
cat(sprintf("ZCTAs with a PFAS-TRI facility within 20km: %d / %d\n", sum(ind$n_pfas_tri_within_20km > 0), nrow(ind)))
cat(sprintf("ZCTAs with an NPL site within 10km: %d / %d\n", sum(ind$npl_within_10km), nrow(ind)))
cat(sprintf("ZCTAs with an NPDES facility within 10km: %d / %d\n", sum(ind$n_npdes_within_10km > 0), nrow(ind)))
print(summary(ind[, -1]))

da_save(ind, "a3b_zcta_source_indicators")
msg("13_a3b_build_source_indicators.R done")
