# =====================================================================
# 00_setup.R
# PFAS drinking-water exposure x obesity-related health outcomes
# Feasibility package -- shared configuration, paths, helpers
# =====================================================================
# This script is sourced by every other script. It does NOT download or
# modify anything. Raw data live in data/raw/ and are treated as read-only.
# =====================================================================

## ---- 0. options ----------------------------------------------------
options(stringsAsFactors = FALSE, scipen = 999, timeout = 600)
set.seed(20260907)

## ---- 1. project paths --------------------------------------------
# Resolve the project root regardless of where R is launched from.
# Strategy: walk up from the working directory until we find data/raw.
if (!exists(".PROJ_ROOT")) {
  .cand <- normalizePath(getwd())
  for (i in 1:5) {
    if (dir.exists(file.path(.cand, "data", "raw")) ||
        dir.exists(file.path(.cand, "scripts"))) break
    .cand <- normalizePath(file.path(.cand, ".."))
  }
  if (basename(.cand) == "scripts") .cand <- normalizePath(file.path(.cand, ".."))
  .PROJ_ROOT <- .cand
}

PATHS <- list(
  root       = .PROJ_ROOT,
  raw        = file.path(.PROJ_ROOT, "data", "raw"),
  raw_ucmr5  = file.path(.PROJ_ROOT, "data", "raw", "ucmr5"),
  raw_places = file.path(.PROJ_ROOT, "data", "raw", "places"),
  raw_acs    = file.path(.PROJ_ROOT, "data", "raw", "acs"),
  raw_geo    = file.path(.PROJ_ROOT, "data", "raw", "geo"),
  processed  = file.path(.PROJ_ROOT, "data", "processed"),
  outputs    = file.path(.PROJ_ROOT, "outputs"),
  figures    = file.path(.PROJ_ROOT, "figures"),
  docs       = file.path(.PROJ_ROOT, "docs")
)
for (p in PATHS[c("processed", "outputs", "figures", "docs")]) {
  if (!dir.exists(p)) dir.create(p, recursive = TRUE)
}

## ---- 2. analysis configuration ----------------------------------
CFG <- list(
  # Geographic scope for the primary feasibility assessment
  study_state_fips   = "48",           # Texas
  study_state_abbr   = "TX",
  bexar_county_fips  = "48029",        # Bexar County / San Antonio

  # Data vintages (documented in the memo)
  ucmr5_release      = "2023-08 occurrence data (EPA, retrieved 2026-09-07)",
  places_release     = "PLACES 2025 release, ZCTA (BRFSS 2023; data.cdc.gov qnzd-25i4)",
  acs_release        = "ACS 2019-2023 5-year, table-based Summary File",

  # PFAS handling
  non_detect_primary = 0,              # substitute 0 for < MRL in primary analysis
  non_detect_sens    = "half_mrl",     # sensitivity: MRL/2

  # UCMR5 units are micrograms/L (ug/L == ppb). EPA final MCLs (2024), ug/L:
  epa_mcl_ugL = c(PFOA = 0.004, PFOS = 0.004, PFHxS = 0.010,
                  `HFPO-DA` = 0.010, PFNA = 0.010),
  # Hazard Index components (unitless HI, EPA 2024): conc / health-based value
  epa_hi_hbv_ugL = c(PFHxS = 0.010, `HFPO-DA` = 0.010, PFNA = 0.010, PFBS = 2.0),

  # PFAS analytes in UCMR5 (exclude lithium, which is not PFAS)
  non_pfas_analytes  = c("lithium")
)

## ---- 3. helper functions ---------------------------------------
`%||%` <- function(a, b) if (is.null(a) || length(a) == 0 || (length(a) == 1 && is.na(a))) b else a

msg <- function(...) cat(sprintf("[%s] %s\n", format(Sys.time(), "%H:%M:%S"), sprintf(...)))

# Normalise a ZIP / ZCTA code to 5-digit zero-padded character
zip5 <- function(x) {
  x <- gsub("[^0-9]", "", as.character(x))
  x <- ifelse(nchar(x) >= 5, substr(x, 1, 5), formatC(as.integer(x), width = 5, flag = "0"))
  ifelse(x %in% c("00000", "0000NA", "NA") | is.na(x), NA_character_, x)
}

# Save a data frame to processed/ as RDS (always), GeoPackage (if sf) and CSV
# (only for tables under 150k rows -- keeps the package small; the .rds is the
# canonical, fully reproducible copy).
save_processed <- function(x, name, csv_max = 150000L) {
  rds <- file.path(PATHS$processed, paste0(name, ".rds"))
  csv <- file.path(PATHS$processed, paste0(name, ".csv"))
  saveRDS(x, rds)
  flat <- if (inherits(x, "sf")) sf::st_drop_geometry(x) else x
  wrote_csv <- nrow(flat) <= csv_max
  if (wrote_csv) utils::write.csv(flat, csv, row.names = FALSE, na = "")
  if (inherits(x, "sf")) {
    sf::st_write(x, file.path(PATHS$processed, paste0(name, ".gpkg")),
                 delete_dsn = TRUE, quiet = TRUE)
    msg("saved %s (%d rows) -> .rds/.gpkg%s", name, nrow(x), if (wrote_csv) "/.csv" else " (csv skipped: large)")
  } else {
    msg("saved %s (%d rows) -> .rds%s", name, nrow(x), if (wrote_csv) "/.csv" else " (csv skipped: large)")
  }
  invisible(x)
}

# Weighted mean that tolerates all-NA / zero-weight
wmean <- function(x, w, na.rm = TRUE) {
  ok <- is.finite(x) & is.finite(w) & w > 0
  if (!any(ok)) return(NA_real_)
  sum(x[ok] * w[ok]) / sum(w[ok])
}

# Spatial weights for a (possibly spatially sparse / gappy) ZCTA sample.
# The primary analytic sample is restricted to ZCTAs served by a UCMR5
# system, so queen contiguity fragments into many sub-graphs; k-nearest-
# neighbour weights on centroids are used as the primary specification,
# with row standardisation.  type = "queen" available for sensitivity.
build_listw <- function(sf_obj, type = c("knn", "queen"), k = 6) {
  type <- match.arg(type)
  stopifnot(requireNamespace("spdep", quietly = TRUE))
  ctr <- suppressWarnings(sf::st_centroid(sf::st_geometry(sf_obj)))
  if (type == "knn") {
    nb <- spdep::knn2nb(spdep::knearneigh(ctr, k = k), sym = TRUE)
  } else {
    nb <- spdep::poly2nb(sf_obj, queen = TRUE)
    empt <- which(spdep::card(nb) == 0)
    if (length(empt)) {
      k1 <- spdep::knn2nb(spdep::knearneigh(ctr, k = 1))
      for (i in empt) nb[[i]] <- k1[[i]]
    }
  }
  spdep::nb2listw(nb, style = "W", zero.policy = TRUE)
}

## ---- 4. package loading ---------------------------------------
.need <- c("data.table", "dplyr", "tidyr", "stringr", "readr", "purrr",
           "sf", "ggplot2")
.opt  <- c("spdep", "spatialreg", "MatchIt", "spgwr", "GWmodel",
           "janitor", "viridis", "patchwork", "classInt", "knitr")
suppressPackageStartupMessages({
  for (p in .need) {
    if (!requireNamespace(p, quietly = TRUE)) stop("Required package missing: ", p)
    library(p, character.only = TRUE)
  }
  for (p in .opt) if (requireNamespace(p, quietly = TRUE)) library(p, character.only = TRUE)
})
sf::sf_use_s2(TRUE)

msg("setup complete -- project root: %s", PATHS$root)
