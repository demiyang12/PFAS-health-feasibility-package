# =====================================================================
# 03_geography.R
# Build the ZCTA geographic backbone and the ZIP -> ZCTA crosswalk.
#   inputs : data/raw/geo/cb_2020_us_zcta520_500k.shp
#            data/raw/geo/cb_2022_us_state_500k.shp
#            data/raw/geo/zcta_county_rel_2020.txt
#            data/processed/ucmr5_pws_zip.rds
#   outputs: data/processed/zcta_geo_us_attributes.csv  (all US ZCTA attributes)
#            data/processed/zcta_geo_tx         (sf: Texas ZCTA only)
#            data/processed/zip_zcta_xwalk      (UCMR5 ZIP -> ZCTA, with status)
#            outputs/linkage_zip_zcta_notes.csv (diagnostics for the memo)
# ---------------------------------------------------------------------
# METHOD NOTE (documented in the memo, deliverable F):
#   * UCMR5 reports the ZIP codes *served* by each PWS.  A ZIP code is a mail
#     delivery construct, not a polygon, and the ZIP codes served list is
#     neither a service-area boundary nor population-weighted.
#   * We link ZIP -> ZCTA by exact 5-digit match to the 2020 Census ZCTA
#     universe.  ~98% of populated US ZIP codes coincide with a ZCTA of the
#     same code; PO-box / point ZIPs and a few split ZIPs do not.
#   * The resulting PWS <-> ZCTA relation is many-to-many and is an
#     *approximate* spatial allocation, not a measured service area.
# =====================================================================
if (!exists("PATHS")) source(if (file.exists("scripts/00_setup.R")) "scripts/00_setup.R" else "00_setup.R")

## ---- 1. ZCTA polygons ---------------------------------------
msg("reading ZCTA cartographic boundaries ...")
zcta <- sf::st_read(file.path(PATHS$raw_geo, "cb_2020_us_zcta520_500k.shp"), quiet = TRUE)
names(zcta) <- tolower(names(zcta))
zcta <- zcta |>
  dplyr::transmute(
    zcta      = as.character(geoid20 %||% zcta5ce20),
    aland_m2  = as.numeric(aland20),
    awater_m2 = as.numeric(awater20)
  ) |>
  sf::st_transform(4269)  # NAD83

## ---- 2. ZCTA -> state via largest land-area county part ------
rel <- data.table::fread(file.path(PATHS$raw_geo, "zcta_county_rel_2020.txt"),
                         sep = "|", colClasses = "character", showProgress = FALSE)
rel <- rel[GEOID_ZCTA5_20 != ""]
rel[, part := as.numeric(AREALAND_PART)]
rel[, state_fips := substr(GEOID_COUNTY_20, 1, 3)]
rel[, state_fips := substr(GEOID_COUNTY_20, 1, 2)]
zcta_state <- rel[order(-part), .(
  state_fips  = state_fips[1],
  county_fips = GEOID_COUNTY_20[1],
  county_name = NAMELSAD_COUNTY_20[1],
  n_counties  = data.table::uniqueN(GEOID_COUNTY_20)
), by = .(zcta = GEOID_ZCTA5_20)]

zcta <- dplyr::left_join(zcta, as.data.frame(zcta_state), by = "zcta")

# National ZCTA geometry is a large intermediate used only to derive the
# Texas subset below; persist the attribute table for reference but not the
# 60+ MB geometry (re-created from the raw shapefile on any re-run / expansion).
utils::write.csv(sf::st_drop_geometry(zcta),
                 file.path(PATHS$processed, "zcta_geo_us_attributes.csv"),
                 row.names = FALSE, na = "")

## ---- 3. Texas ZCTA subset ----------------------------------
zcta_tx <- dplyr::filter(zcta, state_fips == CFG$study_state_fips)
msg("Texas ZCTA universe: %d polygons (%.0f had parts in >1 county)",
    nrow(zcta_tx), sum(zcta_tx$n_counties > 1, na.rm = TRUE))
save_processed(zcta_tx, "zcta_geo_tx")

## ---- 4. ZIP -> ZCTA crosswalk for UCMR5 systems -------------
valid_zcta <- unique(zcta$zcta)
pws_zip <- as.data.table(readRDS(file.path(PATHS$processed, "ucmr5_pws_zip.rds")))

xwalk <- pws_zip[, .(pwsid, zip = zipcode)]
xwalk[, zcta := data.table::fifelse(zip %in% valid_zcta, zip, NA_character_)]
xwalk[, match_status := data.table::fifelse(!is.na(zcta), "exact_zip_eq_zcta", "no_zcta_match")]
xwalk <- dplyr::left_join(xwalk, as.data.frame(zcta_state)[, c("zcta", "state_fips")], by = "zcta")

# diagnostics
diag <- xwalk[, .(
  n_pws_zip_pairs      = .N,
  n_matched            = sum(match_status == "exact_zip_eq_zcta"),
  pct_matched          = round(100 * mean(match_status == "exact_zip_eq_zcta"), 1),
  n_distinct_zip       = data.table::uniqueN(zip),
  n_distinct_zcta      = data.table::uniqueN(zcta[!is.na(zcta)])
)]
diag_tx <- xwalk[substr(pwsid,1,2) == "TX", .(
  scope = "Texas PWS",
  n_pws_zip_pairs = .N,
  n_matched       = sum(match_status == "exact_zip_eq_zcta"),
  pct_matched     = round(100 * mean(match_status == "exact_zip_eq_zcta"), 1),
  n_distinct_zip  = data.table::uniqueN(zip),
  n_distinct_zcta = data.table::uniqueN(zcta[!is.na(zcta)])
)]
diag[, scope := "All US PWS"]
diag_out <- rbind(diag_tx, diag, fill = TRUE)
data.table::fwrite(diag_out, file.path(PATHS$outputs, "linkage_zip_zcta_notes.csv"))
print(diag_out)

save_processed(as.data.frame(xwalk), "zip_zcta_xwalk")
msg("03_geography.R done")
