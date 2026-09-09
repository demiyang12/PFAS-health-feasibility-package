# =====================================================================
# 04_read_sdwis.R
# Attach SDWIS/SDWA system characteristics to the UCMR5 PWS list.
# UCMR5 itself does not carry population-served or county, so we pull it
# from EPA SDWIS (downloaded via Envirofacts in scripts/download_raw.sh).
#   inputs : data/raw/geo/ws_tx_*.csv           (SDWIS WATER_SYSTEM, TX)
#            data/raw/geo/ga_tx_*.csv           (SDWIS GEOGRAPHIC_AREA, TX)
#            data/processed/ucmr5_pws_exposure.rds
#   output : data/processed/pws_tx_characteristics
# =====================================================================
if (!exists("PATHS")) source(if (file.exists("scripts/00_setup.R")) "scripts/00_setup.R" else "00_setup.R")

## ---- 1. WATER_SYSTEM ---------------------------------------
ws <- data.table::rbindlist(lapply(
  list.files(PATHS$raw_geo, pattern = "^ws_tx_\\d\\.csv$", full.names = TRUE),
  data.table::fread, colClasses = "character", showProgress = FALSE), fill = TRUE)
ws <- unique(ws, by = "pwsid")
ws_c <- ws[, .(
  pwsid,
  pws_name_sdwis   = pws_name,
  pws_type_code,                                   # CWS / NTNCWS / TNCWS
  pws_activity_code,                               # A = active
  gw_sw_code,                                      # GW / SW
  owner_type_code,                                 # F/L/M/N/P/S  (public/private/tribal)
  primary_source_code,
  population_served_count = as.numeric(population_served_count),
  service_connections_count = as.numeric(service_connections_count),
  is_wholesaler_ind,
  is_school_or_daycare_ind,
  city_name,
  system_zip = zip5(zip_code),
  state_code
)]
msg("SDWIS WATER_SYSTEM (TX): %d systems", nrow(ws_c))

## ---- 2. GEOGRAPHIC_AREA -> county served -------------------
ga <- data.table::rbindlist(lapply(
  list.files(PATHS$raw_geo, pattern = "^ga_tx_\\d\\.csv$", full.names = TRUE),
  data.table::fread, colClasses = "character", showProgress = FALSE), fill = TRUE)
ga_cty <- ga[area_type_code == "CN" & county_served != "",
             .(county_served_sdwis = paste(sort(unique(county_served)), collapse = "; ")),
             by = pwsid]
ga_city <- ga[area_type_code == "CT" & city_served != "",
              .(city_served_sdwis = paste(sort(unique(city_served)), collapse = "; ")),
              by = pwsid]
ga_zip <- ga[area_type_code == "ZC" & zip_code_served != "",
             .(zip_served_sdwis = paste(sort(unique(zip5(zip_code_served))), collapse = "; ")),
             by = pwsid]

## ---- 3. join, restricted to UCMR5 Texas systems ------------
exp <- as.data.table(readRDS(file.path(PATHS$processed, "ucmr5_pws_exposure.rds")))
tx_pws <- exp[substr(pwsid, 1, 2) == "TX", .(pwsid)]

pws_tx <- tx_pws |>
  merge(ws_c,    by = "pwsid", all.x = TRUE) |>
  merge(ga_cty,  by = "pwsid", all.x = TRUE) |>
  merge(ga_city, by = "pwsid", all.x = TRUE) |>
  merge(ga_zip,  by = "pwsid", all.x = TRUE)

msg("UCMR5 Texas PWS with SDWIS match: %d / %d (%.1f%%); population-served present for %d",
    sum(!is.na(pws_tx$population_served_count)), nrow(pws_tx),
    100 * mean(!is.na(pws_tx$population_served_count)),
    sum(!is.na(pws_tx$population_served_count)))
msg("  system type: %s",
    paste(names(table(pws_tx$pws_type_code)), table(pws_tx$pws_type_code), sep = "=", collapse = "  "))

save_processed(as.data.frame(pws_tx), "pws_tx_characteristics")
msg("04_read_sdwis.R done")
