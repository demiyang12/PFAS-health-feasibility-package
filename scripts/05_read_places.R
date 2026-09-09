# =====================================================================
# 05_read_places.R
# CDC PLACES 2025 release, ZCTA level -> wide table of the 3 outcomes.
#   input  : data/raw/places/places_zcta_3measures.csv
#   output : data/processed/places_zcta_wide
# ---------------------------------------------------------------------
# PLACES estimates are MODEL-BASED small-area estimates (multilevel
# regression + poststratification on BRFSS 2023), NOT direct measurements.
#   OBESITY  : "Obesity among adults"        (BMI >= 30 kg/m2, adults 18+)
#   DIABETES : "Diagnosed diabetes among adults 18+"
#   BPHIGH   : "High blood pressure among adults 18+"
# data_value_type = "Crude prevalence" (%). ZCTA files carry crude only.
# =====================================================================
if (!exists("PATHS")) source(if (file.exists("scripts/00_setup.R")) "scripts/00_setup.R" else "00_setup.R")

pl <- data.table::fread(file.path(PATHS$raw_places, "places_zcta_3measures.csv"),
                        colClasses = "character", showProgress = FALSE)
pl[, zcta := zip5(locationname)]
pl[, value := as.numeric(data_value)]
pl[, lcl := as.numeric(low_confidence_limit)]
pl[, ucl := as.numeric(high_confidence_limit)]
pl[, ci_width := ucl - lcl]
pl[, totalpop := as.numeric(totalpopulation)]
pl[, pop18 := as.numeric(totalpop18plus)]

msg("PLACES rows: %s | measures: %s | ZCTAs: %d | brfss year(s): %s",
    format(nrow(pl), big.mark = ","),
    paste(sort(unique(pl$measureid)), collapse = ", "),
    data.table::uniqueN(pl$zcta), paste(sort(unique(pl$year)), collapse = "/"))

wide <- data.table::dcast(pl, zcta + totalpop + pop18 ~ measureid,
                          value.var = c("value", "ci_width"))
data.table::setnames(wide,
  old = c("value_OBESITY","value_DIABETES","value_BPHIGH",
          "ci_width_OBESITY","ci_width_DIABETES","ci_width_BPHIGH"),
  new = c("obesity_pct","diabetes_pct","bphigh_pct",
          "obesity_ci_width","diabetes_ci_width","bphigh_ci_width"),
  skip_absent = TRUE)

wide[, places_complete := as.integer(
  is.finite(obesity_pct) & is.finite(diabetes_pct) & is.finite(bphigh_pct))]

msg("PLACES wide: %d ZCTA; complete on all 3 outcomes: %d",
    nrow(wide), sum(wide$places_complete))

save_processed(as.data.frame(wide), "places_zcta_wide")
msg("05_read_places.R done")
