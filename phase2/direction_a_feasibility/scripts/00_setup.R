# =====================================================================
# 00_setup.R  -- Direction A feasibility pilot (A1 + A2)
#
# Sources the ROOT Phase 1 setup (PATHS, CFG, helpers, packages) so this
# pilot reuses the exact same exposure definitions, covariate names, and
# spatial-weights convention as Phase 1 -- nothing here redefines them.
# Adds pilot-local paths under phase2/direction_a_feasibility/.
# =====================================================================
if (!exists(".PROJ_ROOT")) {
  .cand <- normalizePath(getwd())
  for (i in 1:6) {
    if (dir.exists(file.path(.cand, "scripts")) && dir.exists(file.path(.cand, "phase2"))) break
    .cand <- normalizePath(file.path(.cand, ".."))
  }
  .PROJ_ROOT <- .cand
}
source(file.path(.PROJ_ROOT, "scripts", "00_setup.R"))  # -> PATHS, CFG, msg(), zip5(), save_processed(), wmean(), build_listw()

DA <- file.path(PATHS$root, "phase2", "direction_a_feasibility")
DA_PATHS <- list(
  root      = DA,
  raw       = file.path(DA, "data", "raw"),
  interim   = file.path(DA, "data", "interim"),
  processed = file.path(DA, "data", "processed"),
  outputs   = file.path(DA, "outputs"),
  figures   = file.path(DA, "figures"),
  docs      = file.path(DA, "docs")
)
for (p in DA_PATHS[c("interim", "processed", "outputs", "figures", "docs")])
  if (!dir.exists(p)) dir.create(p, recursive = TRUE)

# save a data frame / sf object under this pilot's own data/processed/
da_save <- function(x, name, csv_max = 150000L) {
  rds <- file.path(DA_PATHS$processed, paste0(name, ".rds"))
  csv <- file.path(DA_PATHS$processed, paste0(name, ".csv"))
  saveRDS(x, rds)
  flat <- if (inherits(x, "sf")) sf::st_drop_geometry(x) else x
  if (nrow(flat) <= csv_max) utils::write.csv(flat, csv, row.names = FALSE, na = "")
  if (inherits(x, "sf"))
    sf::st_write(x, file.path(DA_PATHS$processed, paste0(name, ".gpkg")), delete_dsn = TRUE, quiet = TRUE)
  msg("[direction_a] saved %s (%d rows)", name, nrow(x))
  invisible(x)
}

# Phase 1's exact exposure / covariate / outcome vocabulary -- reused as-is
# (see scripts/12_models.R and scripts/09_descriptives.R). Do not redefine.
P1_COV <- c("median_hh_income", "poverty_rate", "pct_bachelors_plus", "unemployment_rate",
            "pct_hispanic", "pct_nh_black", "pct_65_plus", "pct_renter_occ", "log_pop_density")
P1_EXP_PRIMARY <- "pfas_hi_log"   # log(1 + EPA Hazard Index) -- Phase 1's primary spatial-model exposure
P1_EXP_ALL     <- c("pfas_any_detect", "pfas_hi_log", "pfas_sum_log", "pfas_n_detected_popwt")
P1_OUT         <- c("obesity_pct", "diabetes_pct", "bphigh_pct")

msg("[direction_a] setup complete -- pilot root: %s", DA)
