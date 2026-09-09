# =====================================================================
# 02_build_pfas_exposure.R
# Construct alternative PFAS exposure measures at the Public Water System
# (PWS) level from the tidy UCMR5 analyte table.
#   input  : data/processed/ucmr5_results_long.rds
#   outputs: data/processed/ucmr5_pws_analyte   (PWS x compound summary)
#            data/processed/ucmr5_pws_exposure  (PWS-level exposure measures)
# ---------------------------------------------------------------------
# Six families of exposure measures are produced (per the feasibility brief);
# no single definition is privileged here.
#   1. any PFAS detected               -> pfas_any_detect
#   2. number of PFAS compounds detected-> pfas_n_detected
#   3. concentration of major compounds -> pfoa_ugL, pfos_ugL, pfhxs_ugL, ...
#   4. sum of measured concentrations   -> pfas_sum_ugL (ND=0) / _ndhalf
#   5. overall mixture / exposure index -> pfas_hazard_index (EPA 2024 HI)
#   6. detection-frequency measure      -> pfas_detect_freq
# =====================================================================
if (!exists("PATHS")) source(if (file.exists("scripts/00_setup.R")) "scripts/00_setup.R" else "00_setup.R")

res <- as.data.table(readRDS(file.path(PATHS$processed, "ucmr5_results_long.rds")))

## ---- 1. PWS x compound summary --------------------------------
# Aggregate the 2-4 sample events (and multiple sample points) per PWS.
pws_analyte <- res[, .(
  n_results     = .N,
  n_detects     = sum(detect, na.rm = TRUE),
  ever_detect   = as.integer(any(detect, na.rm = TRUE)),
  mrl_ugL       = stats::median(mrl, na.rm = TRUE),
  mean_conc_nd0    = mean(conc_nd0,    na.rm = TRUE),   # ND -> 0
  mean_conc_ndhalf = mean(conc_ndhalf, na.rm = TRUE),   # ND -> MRL/2
  max_conc_ugL     = max(conc_nd0,     na.rm = TRUE)
), by = .(pwsid, size, analyte)]
pws_analyte[!is.finite(max_conc_ugL), max_conc_ugL := 0]
save_processed(as.data.frame(pws_analyte), "ucmr5_pws_analyte")

## ---- 2. selected major compounds -----------------------------
major <- c(PFOA = "PFOA", PFOS = "PFOS", PFHxS = "PFHxS", PFNA = "PFNA",
           `HFPO-DA` = "HFPO-DA", PFBS = "PFBS", PFHxA = "PFHxA", PFBA = "PFBA")
conc_wide <- dcast(pws_analyte[analyte %in% major],
                   pwsid ~ analyte, value.var = "mean_conc_nd0")
setnames(conc_wide, old = setdiff(names(conc_wide), "pwsid"),
         new = paste0("conc_", tolower(gsub("[^A-Za-z0-9]", "", setdiff(names(conc_wide), "pwsid"))), "_ugL"))

maxconc_wide <- dcast(pws_analyte[analyte %in% major],
                      pwsid ~ analyte, value.var = "max_conc_ugL")
setnames(maxconc_wide, old = setdiff(names(maxconc_wide), "pwsid"),
         new = paste0("maxconc_", tolower(gsub("[^A-Za-z0-9]", "", setdiff(names(maxconc_wide), "pwsid"))), "_ugL"))

## ---- 3. PWS-level exposure measures --------------------------
exp <- pws_analyte[, {
  det_comp <- unique(analyte[ever_detect == 1])
  hi_comp  <- names(CFG$epa_hi_hbv_ugL)
  hi <- sum(vapply(hi_comp, function(cc) {
    v <- mean_conc_nd0[analyte == cc]; if (length(v) == 0 || !is.finite(v)) 0 else v / CFG$epa_hi_hbv_ugL[[cc]]
  }, numeric(1)))
  pfoa <- mean_conc_nd0[analyte == "PFOA"]; pfoa <- if (length(pfoa)) pfoa else 0
  pfos <- mean_conc_nd0[analyte == "PFOS"]; pfos <- if (length(pfos)) pfos else 0
  .(
    size                = size[1],
    n_analytes_measured = uniqueN(analyte),
    n_results_total     = sum(n_results),
    n_detect_results    = sum(n_detects),
    # (1) any PFAS detected
    pfas_any_detect     = as.integer(any(ever_detect == 1)),
    # (2) number of PFAS compounds detected
    pfas_n_detected     = length(det_comp),
    pfas_compounds_detected = paste(sort(det_comp), collapse = "; "),
    # (4) sum of mean concentrations
    pfas_sum_ugL        = sum(mean_conc_nd0,    na.rm = TRUE),
    pfas_sum_ndhalf_ugL = sum(mean_conc_ndhalf, na.rm = TRUE),
    pfas_max_single_ugL = max(max_conc_ugL,     na.rm = TRUE),
    # (5) EPA 2024 Hazard Index (PFHxS, HFPO-DA, PFNA, PFBS)
    pfas_hazard_index   = hi,
    # (6) detection frequency across all analyte-results
    pfas_detect_freq    = sum(n_detects) / sum(n_results),
    # MCL-style exceedance flags (individual MCLs: PFOA & PFOS = 0.004 ug/L; HI = 1)
    pfoa_ge_mcl         = as.integer(pfoa >= CFG$epa_mcl_ugL[["PFOA"]]),
    pfos_ge_mcl         = as.integer(pfos >= CFG$epa_mcl_ugL[["PFOS"]]),
    hi_ge_1             = as.integer(hi >= 1),
    any_mcl_exceedance  = as.integer(pfoa >= CFG$epa_mcl_ugL[["PFOA"]] |
                                     pfos >= CFG$epa_mcl_ugL[["PFOS"]] | hi >= 1)
  )
}, by = pwsid]

exp <- exp |>
  merge(conc_wide,    by = "pwsid", all.x = TRUE) |>
  merge(maxconc_wide, by = "pwsid", all.x = TRUE)
num <- names(exp)[grepl("^conc_|^maxconc_", names(exp))]
exp[, (num) := lapply(.SD, function(x) data.table::fifelse(is.na(x), 0, x)), .SDcols = num]

msg("PWS exposure table: %d systems; %d (%.1f%%) with any PFAS detection; %d with an MCL/HI exceedance",
    nrow(exp), sum(exp$pfas_any_detect), 100 * mean(exp$pfas_any_detect),
    sum(exp$any_mcl_exceedance))

save_processed(as.data.frame(exp), "ucmr5_pws_exposure")
msg("02_build_pfas_exposure.R done")
