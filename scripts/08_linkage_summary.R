# =====================================================================
# 08_linkage_summary.R  --  Deliverable C: data-linkage summary
#   input : data/processed/{texas_zcta_analytical, ucmr5_pws_exposure,
#           pws_tx_characteristics, zip_zcta_xwalk}.rds
#   output: outputs/linkage_summary.csv
#           outputs/linkage_summary_bexar.csv
# =====================================================================
if (!exists("PATHS")) source(if (file.exists("scripts/00_setup.R")) "scripts/00_setup.R" else "00_setup.R")

exp  <- as.data.table(readRDS(file.path(PATHS$processed, "ucmr5_pws_exposure.rds")))
xw   <- as.data.table(readRDS(file.path(PATHS$processed, "zip_zcta_xwalk.rds")))
d    <- as.data.table(sf::st_drop_geometry(readRDS(file.path(PATHS$processed, "texas_zcta_analytical.rds"))))

tx_exp <- exp[substr(pwsid, 1, 2) == "TX"]
tx_xw  <- xw[substr(pwsid, 1, 2) == "TX"]

funnel <- function(dd, xww, label) {
  data.table(
    step = c(
      "UCMR5 public water systems in Texas",
      "  ... with at least one PFAS detection",
      "  ... with an EPA MCL / Hazard-Index exceedance",
      "Distinct ZIP codes served by these systems",
      "  ... ZIP codes matched to a 2020 Census ZCTA",
      "Distinct Texas ZCTAs reached by >=1 UCMR5 system",
      "  ... also with complete CDC PLACES outcomes",
      "  ... also with complete ACS covariates",
      "  ... also passing population screen (>=500)  [PRIMARY SAMPLE]"
    ),
    n = c(
      nrow(tx_exp),
      sum(tx_exp$pfas_any_detect),
      sum(tx_exp$any_mcl_exceedance),
      data.table::uniqueN(xww$zip),
      data.table::uniqueN(xww$zip[!is.na(xww$zcta)]),
      sum(dd$pfas_exposure_available == 1),
      sum(dd$pfas_exposure_available == 1 & dd$health_complete == 1),
      sum(dd$analytic_full == 1),
      sum(dd$analytic_primary == 1)
    ),
    scope = label
  )
}

all_tx <- funnel(d, tx_xw, "Texas")
bexar  <- {
  db <- d[in_bexar == 1]
  bx_pws <- unique(merge(tx_xw[!is.na(zcta)], db[, .(zcta)], by = "zcta")$pwsid)
  bx_exp <- tx_exp[pwsid %in% bx_pws]
  bx_xw  <- tx_xw[pwsid %in% bx_pws]
  dt <- funnel(db, bx_xw, "Bexar County / San Antonio")
  dt$n[1] <- length(bx_pws)
  dt$n[2] <- sum(bx_exp$pfas_any_detect)
  dt$n[3] <- sum(bx_exp$any_mcl_exceedance)
  dt
}

data.table::fwrite(all_tx, file.path(PATHS$outputs, "linkage_summary.csv"))
data.table::fwrite(bexar,  file.path(PATHS$outputs, "linkage_summary_bexar.csv"))

# extra descriptive linkage facts
extra <- data.table(
  metric = c("PWS-ZIP pairs (TX)", "ZIP->ZCTA exact match rate (TX, %)",
             "TX ZCTAs served by exactly 1 UCMR5 PWS",
             "TX ZCTAs served by >1 UCMR5 PWS",
             "Max UCMR5 PWS serving a single TX ZCTA",
             "TX ZCTA universe (2020)",
             "Mean ZIP codes served per TX PWS",
             "TX ZCTAs spanning >1 county"),
  value = c(nrow(tx_xw),
            round(100 * mean(!is.na(tx_xw$zcta)), 1),
            sum(d$n_pws_serving == 1, na.rm = TRUE),
            sum(d$n_pws_serving > 1, na.rm = TRUE),
            max(d$n_pws_serving, na.rm = TRUE),
            nrow(d),
            round(nrow(tx_xw) / data.table::uniqueN(tx_xw$pwsid), 1),
            sum(d$n_counties > 1, na.rm = TRUE))
)
data.table::fwrite(extra, file.path(PATHS$outputs, "linkage_summary_extra.csv"))

cat("\n===== DELIVERABLE C: TEXAS DATA-LINKAGE SUMMARY =====\n")
print(all_tx[, .(step, n)], nrow = 20)
cat("\n----- Bexar County -----\n"); print(bexar[, .(step, n)], nrow = 20)
cat("\n----- Additional linkage facts -----\n"); print(extra)
msg("08_linkage_summary.R done")
