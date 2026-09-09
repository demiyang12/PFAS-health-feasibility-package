# =====================================================================
# 06_read_acs.R
# Parse ACS 2019-2023 5-year table-based Summary File extracts (ZCTA rows
# only) into a compact set of conceptually-motivated covariates.
#   inputs : data/raw/acs/acs_b*_zcta.psv
#   output : data/processed/acs_zcta_covariates
# ---------------------------------------------------------------------
# Variable selection rationale (deliverable F): each covariate is a
# plausible common cause of BOTH community PFAS exposure AND obesity /
# diabetes / hypertension prevalence -- i.e. a confounder for the
# ecological association, not merely "available".
#   income / poverty / education / unemployment : socioeconomic position;
#       drives diet, health-care access, and where industrial / military /
#       airport PFAS sources and under-resourced water utilities are sited.
#   race / ethnicity composition : environmental-justice exposure gradient
#       + documented disparities in the three outcomes.
#   age structure : direct driver of diabetes / hypertension prevalence.
#   population density / mobile-home share : urban-rural gradient; rural
#       systems are smaller and monitored differently, rural obesity higher.
#   housing value / rent / tenure : asset-based SES + infrastructure vintage.
# =====================================================================
if (!exists("PATHS")) source(if (file.exists("scripts/00_setup.R")) "scripts/00_setup.R" else "00_setup.R")

read_acs <- function(tbl, cols) {
  f <- file.path(PATHS$raw_acs, sprintf("acs_%s_zcta.psv", tolower(tbl)))
  d <- data.table::fread(f, sep = "|", colClasses = "character", showProgress = FALSE)
  d[, zcta := sub("^860Z200US", "", GEO_ID)]
  keep <- c("zcta", intersect(cols, names(d)))
  d <- d[, ..keep]
  num <- setdiff(keep, "zcta")
  d[, (num) := lapply(.SD, function(x) {
    x <- suppressWarnings(as.numeric(x))
    x[x <= -666666666] <- NA_real_          # ACS jam / suppression sentinels
    x
  }), .SDcols = num]
  d[]
}
pc <- function(num, den) ifelse(is.finite(num) & is.finite(den) & den > 0, 100 * num / den, NA_real_)

## ---- pull each table --------------------------------------
b01003 <- read_acs("b01003", "B01003_E001")
b19013 <- read_acs("b19013", "B19013_E001")
b17001 <- read_acs("b17001", c("B17001_E001", "B17001_E002"))
b15003 <- read_acs("b15003", sprintf("B15003_E%03d", 1:25))
b23025 <- read_acs("b23025", c("B23025_E003", "B23025_E005"))
b03002 <- read_acs("b03002", sprintf("B03002_E%03d", c(1, 3, 4, 6, 12)))
b01001 <- read_acs("b01001", sprintf("B01001_E%03d", 1:49))
b25003 <- read_acs("b25003", c("B25003_E001", "B25003_E003"))
b25077 <- read_acs("b25077", "B25077_E001")
b25064 <- read_acs("b25064", "B25064_E001")
b25024 <- read_acs("b25024", c("B25024_E001", "B25024_E010"))

acs <- Reduce(function(a, b) merge(a, b, by = "zcta", all = TRUE),
              list(b01003, b19013, b17001, b15003, b23025, b03002,
                   b01001, b25003, b25077, b25064, b25024))

## ---- derive covariates -----------------------------------
u18_m <- sprintf("B01001_E%03d", 3:6)      # male  <5,5-9,10-14,15-17
u18_f <- sprintf("B01001_E%03d", 27:30)    # female <5,5-9,10-14,15-17
p65_m <- sprintf("B01001_E%03d", 20:25)    # male  65-66 ... 85+
p65_f <- sprintf("B01001_E%03d", 44:49)    # female 65-66 ... 85+

out <- acs[, .(
  zcta,
  acs_pop_total       = B01003_E001,
  median_hh_income    = B19013_E001,
  poverty_rate        = pc(B17001_E002, B17001_E001),
  pct_bachelors_plus  = pc(B15003_E022 + B15003_E023 + B15003_E024 + B15003_E025, B15003_E001),
  pct_less_than_hs    = pc(rowSums(.SD[, sprintf("B15003_E%03d", 2:16), with = FALSE], na.rm = TRUE), B15003_E001),
  unemployment_rate   = pc(B23025_E005, B23025_E003),
  pct_nh_white        = pc(B03002_E003, B03002_E001),
  pct_nh_black        = pc(B03002_E004, B03002_E001),
  pct_hispanic        = pc(B03002_E012, B03002_E001),
  pct_minority        = 100 - pc(B03002_E003, B03002_E001),
  pct_under_18        = pc(rowSums(.SD[, c(u18_m, u18_f), with = FALSE], na.rm = TRUE), B01001_E001),
  pct_65_plus         = pc(rowSums(.SD[, c(p65_m, p65_f), with = FALSE], na.rm = TRUE), B01001_E001),
  pct_renter_occ      = pc(B25003_E003, B25003_E001),
  median_home_value   = B25077_E001,
  median_gross_rent   = B25064_E001,
  pct_mobile_home     = pc(B25024_E010, B25024_E001)
)]

out[, acs_covar_complete := as.integer(
  is.finite(median_hh_income) & is.finite(poverty_rate) &
  is.finite(pct_bachelors_plus) & is.finite(unemployment_rate) &
  is.finite(pct_hispanic) & is.finite(pct_65_plus))]

msg("ACS covariates: %d ZCTA; complete on core set: %d; median HH income present: %d",
    nrow(out), sum(out$acs_covar_complete), sum(is.finite(out$median_hh_income)))

save_processed(as.data.frame(out), "acs_zcta_covariates")
msg("06_read_acs.R done")
