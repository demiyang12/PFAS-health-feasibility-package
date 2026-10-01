# =====================================================================
# 01_a1_read_cholesterol.R
# A1.1 -- CDC PLACES high-cholesterol measure: read + VERIFY metadata
#   input  : phase2/direction_a_feasibility/data/raw/places/places_zcta_highchol.csv
#   output : phase2/direction_a_feasibility/data/processed/a1_cholesterol_zcta
#            phase2/direction_a_feasibility/docs/a1_places_metadata.csv
# ---------------------------------------------------------------------
# Phase 2's scoping inventory (phase2/docs/outcome_data_inventory.csv) stated
# the cholesterol measure's BRFSS vintage from a general web search, not from
# the source file itself. This script checks that claim against the actual
# downloaded data rather than repeating the assumption.
# =====================================================================
if (!exists("DA_PATHS")) source(if (file.exists("phase2/direction_a_feasibility/scripts/00_setup.R"))
  "phase2/direction_a_feasibility/scripts/00_setup.R" else "00_setup.R")

f <- file.path(DA_PATHS$raw, "places", "places_zcta_highchol.csv")
pl <- data.table::fread(f, colClasses = "character", showProgress = FALSE)

## ---- A1.1: verify, don't assume -------------------------------------
meta <- data.frame(
  field = c(
    "exact_places_measure_name", "measureid", "short_question_text",
    "data_value_type", "datavaluetypeid", "category",
    "underlying_brfss_year(s)_found_in_source", "n_rows_(us_zcta)",
    "n_distinct_zcta", "n_missing_data_value", "geographic_unit",
    "temporal_mismatch_vs_ucmr5_2023-2025"
  ),
  value = c(
    unique(pl$measure), unique(pl$measureid), unique(pl$short_question_text),
    unique(pl$data_value_type), unique(pl$datavaluetypeid), unique(pl$categoryid),
    paste(sort(unique(pl$year)), collapse = ", "), nrow(pl),
    data.table::uniqueN(pl$locationname), sum(pl$data_value == "" | is.na(pl$data_value)),
    "ZCTA (ZIP Code Tabulation Area)",
    NA  # filled in below once we know the year
  )
)
yr <- sort(unique(pl$year))
meta$value[meta$field == "temporal_mismatch_vs_ucmr5_2023-2025"] <- if (all(yr >= 2023)) {
  sprintf("NONE OF NOTE -- source confirms BRFSS %s, contemporaneous with UCMR5 2023-2025 and with the Phase 1 obesity/diabetes/bphigh measures (also BRFSS %s). CORRECTS the Phase 2 scoping inventory's assumption of BRFSS 2021 (that assumption was accurate for the 2024 PLACES release but not for the 2025 release actually used here -- cholesterol is a BRFSS odd-year Rotating-Core question, and the 2025 release uses the most recent available wave, 2023).",
          paste(yr, collapse = "/"), paste(yr, collapse = "/"))
} else {
  sprintf("BRFSS %s vs UCMR5 2023-2025 -- a %s-year gap, inherited from the same limitation already documented for Phase 1's other PLACES outcomes.", paste(yr, collapse = "/"), 2023 - as.integer(min(yr)))
}
write.csv(meta, file.path(DA_PATHS$docs, "a1_places_metadata.csv"), row.names = FALSE)
cat("\n===== A1.1 -- PLACES high-cholesterol measure, VERIFIED metadata =====\n")
print(meta, row.names = FALSE)

## ---- clean to a ZCTA-level table, same conventions as scripts/05_read_places.R
pl[, zcta := zip5(locationname)]
pl[, highchol_pct := as.numeric(data_value)]
pl[, highchol_lcl := as.numeric(low_confidence_limit)]
pl[, highchol_ucl := as.numeric(high_confidence_limit)]
pl[, highchol_ci_width := highchol_ucl - highchol_lcl]

out <- as.data.frame(pl[, .(zcta, highchol_pct, highchol_ci_width)])
da_save(out, "a1_cholesterol_zcta")
msg("01_a1_read_cholesterol.R done -- %d ZCTAs, %d missing", nrow(out), sum(is.na(out$highchol_pct)))
