# =====================================================================
# 17_a3c_download_twdb_service_areas.R
# A3c -- follow-up on A3a method #5 ("PWS service-area polygons (statewide)",
# FOUND REAL / NOT USED THIS PASS -- see docs/a3a_assignment_methods_inventory.csv).
#
# The Texas Water Service Boundary Viewer (https://www3.twdb.texas.gov/apps/
# waterserviceboundaries) turned out to be backed by a real, public, keyless
# ArcGIS Server FeatureServer -- found by inspecting the app's own network
# traffic (its UI also has a built-in "Download > Shapefile" button, which is
# what actually surfaces the underlying REST endpoint in the browser console):
#   https://services2.twdb.texas.gov/server/rest/services/PWS/
#     Public_Water_Service_Areas_Grid/FeatureServer/0
# Layer "SERVICEAREAS": polygon geometry, 4,621 features statewide, fields
# PWSCode/PWSId/pwsName/STATUS/Source/SubmitDateTime/Area/surveyNo/surveyYear.
# maxRecordCount = 10000, so all 4,621 features fit in a single query -- no
# pagination needed. This is a genuine surveyed/mapped service-area boundary
# per PWS, NOT the self-reported "ZIP codes served" administrative list that
# Phase 1 (and A3a) used -- a structurally different, finer-grained input to
# the exposure-assignment question (see docs/a3_direction_a_updated_memo.md).
# =====================================================================
if (!exists("DA_PATHS")) source(if (file.exists("phase2/direction_a_feasibility/scripts/00_setup.R"))
  "phase2/direction_a_feasibility/scripts/00_setup.R" else "00_setup.R")
suppressPackageStartupMessages({library(sf); library(data.table)})

RAWC <- file.path(DA_PATHS$raw, "a3c_twdb"); dir.create(RAWC, showWarnings = FALSE, recursive = TRUE)
BASE <- "https://services2.twdb.texas.gov/server/rest/services/PWS/Public_Water_Service_Areas_Grid/FeatureServer/0/query"

n_total <- jsonlite::fromJSON(paste0(BASE, "?where=1%3D1&returnCountOnly=true&f=json"))$count
msg("TWDB service-area layer reports %d features statewide", n_total)

## the server silently caps each response well below its advertised
## maxRecordCount=10000 (returns exceededTransferLimit=true) -- paginate in
## batches of 1000 via resultOffset/resultRecordCount, the standard ArcGIS
## REST pattern, and bind the pages together
page_size <- 1000
offsets <- seq(0, n_total - 1, by = page_size)
pages <- list()
for (off in offsets) {
  url <- sprintf("%s?where=1%%3D1&outFields=*&outSR=4326&resultOffset=%d&resultRecordCount=%d&f=geojson",
                 BASE, off, page_size)
  pages[[length(pages) + 1]] <- sf::st_read(url, quiet = TRUE)
  msg("  ... fetched features %d-%d", off + 1, min(off + page_size, n_total))
}
svc <- do.call(rbind, pages)
msg("Downloaded %d service-area polygons, %d columns", nrow(svc), ncol(svc))
sf::st_write(svc, file.path(RAWC, "twdb_service_areas_tx.gpkg"), delete_dsn = TRUE, quiet = TRUE)
fwrite(sf::st_drop_geometry(svc), file.path(RAWC, "twdb_service_areas_tx_attributes.csv"))

## ---- A3c.1 -- basic verification before any linkage work ------------
cat("\n===== A3c.1 -- TWDB service-area layer verification =====\n")
cat(sprintf("Rows: %d | Distinct PWSId: %d | Duplicated PWSId rows: %d\n",
            nrow(svc), uniqueN(svc$PWSId), sum(duplicated(svc$PWSId))))
cat("STATUS field distribution:\n"); print(table(svc$STATUS, useNA = "ifany"))
cat("\nsurveyYear distribution:\n"); print(table(svc$surveyYear, useNA = "ifany"))
cat(sprintf("\nGeometry validity: %d valid / %d invalid (of %d)\n",
            sum(sf::st_is_valid(svc)), sum(!sf::st_is_valid(svc)), nrow(svc)))

## ---- A3c.2 -- match rate against Phase 1's UCMR5 Texas PWS list -----
p1_pws <- readRDS(file.path(PATHS$processed, "pws_tx_characteristics.rds"))
match_tab <- data.frame(
  phase1_tx_pws               = uniqueN(p1_pws$pwsid),
  twdb_distinct_pws            = uniqueN(svc$PWSId),
  phase1_pws_with_twdb_polygon = sum(unique(p1_pws$pwsid) %in% svc$PWSId),
  pct_phase1_pws_matched       = round(100 * mean(unique(p1_pws$pwsid) %in% svc$PWSId), 1)
)
write.csv(match_tab, file.path(DA_PATHS$outputs, "a3c_twdb_match_rate.csv"), row.names = FALSE)
cat("\n===== A3c.2 -- match rate against Phase 1's Texas UCMR5 PWS list =====\n")
print(match_tab, row.names = FALSE)

da_save(svc, "a3c_twdb_service_areas")
msg("17_a3c_download_twdb_service_areas.R done -- raw files in %s", RAWC)
