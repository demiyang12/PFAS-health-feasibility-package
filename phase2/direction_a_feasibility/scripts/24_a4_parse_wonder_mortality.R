# =====================================================================
# 24_a4_parse_wonder_mortality.R
# A4 -- parse the CDC WONDER county-level Ischaemic Heart Disease (ICD-10
# I20-I25) mortality pull for Texas, 2020-2024.
#
# WHY THIS OUTCOME, WHY THIS SOURCE: the confounding diagnostics (scripts
# 22-23, docs/confounding_diagnostics_summary.md) found that CDC PLACES's
# own small-area estimation model explicitly includes county-level random
# effects (confirmed from CDC's own methodology page), meaning the
# "between-county" pattern found there could be partly a measurement
# artifact of how PLACES computes ZCTA estimates, not a real signal. A4
# tests the same underlying question (does PFAS exposure relate to a
# cardiovascular outcome at the county level) using a DIFFERENT outcome
# source with a structurally different estimation method: CDC WONDER's
# Multiple Cause of Death database, built directly from death certificate
# counts -- no survey, no small-area model, no county random effect.
#
# WHY NOT SCRIPTED: CDC WONDER's own documented API
# (https://wonder.cdc.gov/wonder/help/wonder-api.html) states that, per
# National Vital Statistics System confidentiality policy, sub-national
# geography (State, County, Region) CANNOT be queried via the keyless
# API -- only national totals. County-level data is only available via
# the interactive web request form. The raw text below was retrieved from
# that form (database D157, https://wonder.cdc.gov/mcd-icd10-expanded.html)
# with the exact, documented query criteria recorded in the raw file's
# header -- a human-reproducible, not programmatically re-runnable, pull.
#
# Suppression: CDC WONDER suppresses any county-year cell with <=9 deaths.
# 12 of 254 Texas counties are suppressed for I20-I25, 2020-2024 combined.
# These are EXCLUDED from analysis, never imputed as zero (same policy as
# A2's handling of suppressed DSHS birth-outcome counties).
# =====================================================================
if (!exists("DA_PATHS")) source(if (file.exists("phase2/direction_a_feasibility/scripts/00_setup.R"))
  "phase2/direction_a_feasibility/scripts/00_setup.R" else "00_setup.R")
library(data.table)

raw_file <- file.path(DA_PATHS$raw, "a4_wonder", "wonder_ihd_county_tx_2020_2024_raw.txt")
lines <- readLines(raw_file, encoding = "UTF-8")

## data rows look like: "Anderson County, TX (48001)\t307\t291,519\t105.3 (93.5 - 117.1)"
## or suppressed:        "Borden County, TX (48033)\tSuppressed\t3,037\tSuppressed"
data_lines <- grep("^[A-Za-z].*County, TX \\(48[0-9]{3}\\)\t", lines, value = TRUE)
msg("Found %d county data rows in the raw WONDER text", length(data_lines))

parse_row <- function(ln) {
  parts <- strsplit(ln, "\t")[[1]]
  county_name <- sub(" \\(48[0-9]{3}\\)$", "", parts[1])
  fips <- as.integer(regmatches(parts[1], regexpr("48[0-9]{3}", parts[1])))
  suppressed <- parts[2] == "Suppressed"
  deaths <- if (suppressed) NA_integer_ else as.integer(gsub(",", "", parts[2]))
  population <- as.integer(gsub(",", "", parts[3]))
  crude_rate <- if (suppressed) NA_real_ else as.numeric(sub(" .*", "", parts[4]))
  data.table(county = fips, county_name_wonder = county_name, deaths = deaths,
             population = population, crude_rate = crude_rate, suppressed = suppressed)
}
ihd <- rbindlist(lapply(data_lines, parse_row))
stopifnot(nrow(ihd) == 254)

cat(sprintf("\n===== A4 -- CDC WONDER Ischaemic Heart Disease mortality, TX counties, 2020-2024 =====\n"))
cat(sprintf("Counties: %d | Suppressed (<=9 deaths over 5 years): %d (%.1f%%)\n",
            nrow(ihd), sum(ihd$suppressed), 100 * mean(ihd$suppressed)))
cat(sprintf("Total deaths (non-suppressed counties): %s | Total population (person-years): %s\n",
            format(sum(ihd$deaths, na.rm = TRUE), big.mark = ","), format(sum(ihd$population), big.mark = ",")))
cat("\nCrude rate per 100,000 (person-year basis, non-suppressed counties):\n")
print(summary(ihd$crude_rate))

write.csv(ihd, file.path(DA_PATHS$outputs, "a4_wonder_ihd_county_parsed.csv"), row.names = FALSE)
saveRDS(ihd, file.path(DA_PATHS$processed, "a4_wonder_ihd_county.rds"))
msg("24_a4_parse_wonder_mortality.R done")
