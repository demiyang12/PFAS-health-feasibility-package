# =====================================================================
# run_all.R  --  reproduce the entire feasibility pipeline
#
#   1. bash scripts/download_raw.sh      (once, to fetch raw public data)
#   2. Rscript scripts/run_all.R         (this file)
#
# Each numbered script reads only from data/raw/ and data/processed/ and
# writes to data/processed/, outputs/ and figures/.  Raw data are never
# modified.
# =====================================================================
t0 <- Sys.time()
root <- if (file.exists("scripts/00_setup.R")) "." else ".."
source(file.path(root, "scripts", "00_setup.R"))

# tee console output to outputs/run_all_log.txt
.logcon <- file(file.path(PATHS$outputs, "run_all_log.txt"), open = "wt")
sink(.logcon, split = TRUE); sink(.logcon, type = "message")
on.exit({sink(type = "message"); sink(); close(.logcon)}, add = TRUE)

steps <- c(
  "01_read_ucmr5.R",
  "02_build_pfas_exposure.R",
  "03_geography.R",
  "04_read_sdwis.R",
  "05_read_places.R",
  "06_read_acs.R",
  "07_assemble_zcta_dataset.R",
  "08_linkage_summary.R",
  "09_descriptives.R",
  "10_maps.R",
  "11_spatial_autocorr.R",
  "12_models.R",
  "13_build_report.R"
)

for (s in steps) {
  msg("======== running %s ========", s)
  source(file.path(PATHS$root, "scripts", s), local = new.env())
}

msg("ALL DONE in %.1f min.  See outputs/ , figures/ , docs/",
    as.numeric(difftime(Sys.time(), t0, units = "mins")))
