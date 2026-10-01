# =====================================================================
# 04_a2_read_birth_outcomes.R
# A2.1 -- verify and read Texas county-level birth outcomes BEFORE any
# exposure linkage, per the task's explicit instruction not to assume.
#
# LOW BIRTH WEIGHT: Texas DSHS Center for Health Statistics, Vital
#   Statistics Annual Report, Table 10 ("Low Birth Weight (<2500 grams)
#   Infants by Region, County of Residence, and Race/Ethnicity"). Verified
#   directly downloadable (.xlsx) for years 2017-2019 -- see
#   scripts/download_raw_a.sh. 2019 is the most recent year DSHS has
#   posted as a static Annual-Report table (checked 2026-10-01).
#
# PRETERM BIRTH: NO county-level static table was found in the same
#   report series (only a state-level trend exists in the Healthy Texas
#   Mothers and Babies Data Book, a PDF). CDC WONDER Natality (D149,
#   2016-2024 expanded) was identified as the documented programmatic
#   backup (POST request_xml to https://wonder.cdc.gov/controller/
#   datarequest/D149, grouping B_1=D149.V21-level2 for county of
#   residence) but a working query was NOT completed within this pilot's
#   time budget -- the measure-code mapping for "gestational age < 37
#   weeks" was not fully resolved. This is documented as a genuine access
#   barrier, not silently worked around; A2-PTB is NOT run with real data
#   in this pilot. See docs/a2_feasibility_summary.md.
# =====================================================================
if (!exists("DA_PATHS")) source(if (file.exists("phase2/direction_a_feasibility/scripts/00_setup.R"))
  "phase2/direction_a_feasibility/scripts/00_setup.R" else "00_setup.R")
if (!requireNamespace("readxl", quietly = TRUE))
  install.packages("readxl", repos = "https://cloud.r-project.org", quiet = TRUE)

## ---- Texas county name -> FIPS (from the same Census file Phase 1 uses) ----
cty_sf <- sf::st_read(file.path(PATHS$raw_geo, "cb_2022_us_county_500k.shp"), quiet = TRUE)
cty_tx <- as.data.frame(sf::st_drop_geometry(cty_sf[cty_sf$STATEFP == "48", c("GEOID", "NAME")]))
cty_tx$NAME_UP <- toupper(cty_tx$NAME)
stopifnot(nrow(cty_tx) == 254)

read_table10 <- function(year) {
  f <- file.path(DA_PATHS$raw, "tx_dshs", sprintf("%d-table-10.xlsx", year))
  x <- readxl::read_excel(f, sheet = 1, col_names = FALSE)
  names(x)[1:3] <- c("area", "lbw_count_raw", "lbw_pct_raw")
  # county rows are the ALL-CAPS rows that exactly match a real TX county
  # name (this drops the TEXAS / REGION 01-11 / URBAN / RURAL / BORDER
  # summary rows, which are not counties)
  x <- x[toupper(trimws(x$area)) %in% cty_tx$NAME_UP, ]
  x$county_name <- toupper(trimws(x$area))
  x$county <- cty_tx$GEOID[match(x$county_name, cty_tx$NAME_UP)]
  x$suppressed_count <- x$lbw_count_raw %in% c("*", "-", NA)
  x$suppressed_pct    <- x$lbw_pct_raw %in% c("*", "-", NA)
  x$lbw_count <- suppressWarnings(as.numeric(x$lbw_count_raw))
  x$lbw_pct   <- suppressWarnings(as.numeric(x$lbw_pct_raw))
  x$total_births_derived <- round(x$lbw_count / (x$lbw_pct / 100))
  x$year <- year
  x[, c("year", "county", "county_name", "lbw_count", "lbw_pct", "total_births_derived",
        "suppressed_count", "suppressed_pct")]
}

lbw_all <- do.call(rbind, lapply(c(2019, 2018, 2017), read_table10))
lbw19 <- lbw_all[lbw_all$year == 2019, ]

## ---- A2.1 verification record -----------------------------------------
meta <- data.frame(
  field = c(
    "source", "exact_table_title", "geography", "numerator_definition",
    "denominator", "rate_definition", "small_cell_suppression_symbols",
    "zero_distinguishable_from_suppressed", "counties_represented_2019",
    "counties_suppressed_count_2019", "counties_suppressed_pct_2019",
    "most_recent_available_year_(static_table)", "preterm_birth_county_table_available"
  ),
  value = c(
    "Texas DSHS Center for Health Statistics, Vital Statistics Annual Report (Table 10)",
    "Low Birth Weight (<2500 grams) Infants by Region, County of Residence, and Race/Ethnicity",
    "County of maternal residence",
    "Infants born at <2,500 grams (DSHS definition, matches the standard clinical LBW cutoff)",
    "Not published directly; DERIVED here as round(count / (rate/100)) -- documented, not assumed exact",
    "Percent of all resident live births in the county that were low birth weight",
    "'*' for a suppressed count, '-' for a suppressed/not-computed rate (both observed in the raw file; NOT the same thing as a published zero)",
    "NO -- a county with a true small or zero count and a county with a privacy-suppressed count are not distinguishable from each other in this published table",
    nrow(lbw19), sum(lbw19$suppressed_count), sum(lbw19$suppressed_pct),
    "2019 (checked 2026-10-01; 2020-2023 not yet posted as a static Annual Report table)",
    "NO -- not found in this report series; see script header for the CDC WONDER D149 backup attempt (not completed)"
  )
)
write.csv(meta, file.path(DA_PATHS$docs, "a2_birth_outcome_metadata.csv"), row.names = FALSE)
cat("\n===== A2.1 -- Texas birth-outcome source, VERIFIED =====\n"); print(meta, row.names = FALSE)

write.csv(lbw_all, file.path(DA_PATHS$outputs, "a2_lbw_county_2017_2019.csv"), row.names = FALSE)
da_save(lbw19, "a2_lbw_county_2019")

cat(sprintf("\n2019: %d/%d TX counties with a non-suppressed LBW RATE (usable for analysis)\n",
            sum(!lbw19$suppressed_pct), nrow(lbw19)))
msg("04_a2_read_birth_outcomes.R done -- LBW 2017-2019 read; PTB documented as unavailable (not pulled)")
