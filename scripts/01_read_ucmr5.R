# =====================================================================
# 01_read_ucmr5.R
# Read raw UCMR5 occurrence data -> tidy analyte-level table
#   inputs : data/raw/ucmr5/UCMR5_All.txt
#            data/raw/ucmr5/UCMR5_ZIPCodes.txt
#            data/raw/ucmr5/UCMR5_AddtlDataElem.txt
#   outputs: data/processed/ucmr5_results_long        (all US, analyte-level)
#            data/processed/ucmr5_pws_zip             (PWS -> ZIP served)
#            data/processed/ucmr5_pfas_flags          (PWS-level PFAS occurrence flag)
# =====================================================================
if (!exists("PATHS")) source(if (file.exists("scripts/00_setup.R")) "scripts/00_setup.R" else "00_setup.R")

## ---- 1. read the main occurrence file ---------------------------
msg("reading UCMR5_All.txt ...")
raw <- data.table::fread(
  file.path(PATHS$raw_ucmr5, "UCMR5_All.txt"),
  sep = "\t", quote = "", colClasses = "character", showProgress = FALSE,
  encoding = "Latin-1"
)
data.table::setnames(raw, make.names(names(raw)))
msg("  %s rows, %d PWS, %d analytes", format(nrow(raw), big.mark = ","),
    data.table::uniqueN(raw$PWSID), data.table::uniqueN(raw$Contaminant))

## ---- 2. clean / type columns ----------------------------------
res <- raw[, .(
  pwsid        = PWSID,
  pws_name     = PWSName,
  size         = Size,                       # S = serves <=10k ; L = serves >10k
  facility_id  = FacilityID,
  facility_water_type = FacilityWaterType,   # GW / SW / GU / MX
  sample_point_id     = SamplePointID,
  sample_point_type   = SamplePointType,
  collection_date = as.Date(CollectionDate, format = "%m/%d/%Y"),
  sample_id    = SampleID,
  analyte      = Contaminant,
  mrl          = suppressWarnings(as.numeric(MRL)),
  units        = "ug/L",
  method_id    = MethodID,
  sign         = AnalyticalResultsSign,      # "<" = non-detect ; "=" = detection
  value_raw    = suppressWarnings(as.numeric(AnalyticalResultValue)),
  sample_event = SampleEventCode,
  epa_region   = Region,
  state        = State                       # USPS abbr, or numeric code for tribal
)]

# detection flag + concentration under the primary ND rule (ND -> 0)
res[, detect := sign == "="]
res[, conc_nd0    := data.table::fifelse(detect, value_raw, 0)]
res[, conc_ndhalf := data.table::fifelse(detect, value_raw, mrl / 2)]

# restrict to PFAS analytes (drop lithium)
res_pfas <- res[!tolower(analyte) %in% CFG$non_pfas_analytes]
msg("  PFAS analyte rows: %s across %d compounds",
    format(nrow(res_pfas), big.mark = ","), data.table::uniqueN(res_pfas$analyte))

save_processed(as.data.frame(res_pfas), "ucmr5_results_long")

## ---- 3. PWS -> ZIP served -------------------------------------
zip <- data.table::fread(
  file.path(PATHS$raw_ucmr5, "UCMR5_ZIPCodes.txt"),
  sep = "\t", colClasses = "character", showProgress = FALSE
)
data.table::setnames(zip, c("pwsid", "zipcode"))
zip[, zipcode := zip5(zipcode)]
zip <- unique(zip[!is.na(zipcode)])
msg("  UCMR5 ZIP file: %d PWS, %d PWS-ZIP pairs, %d distinct ZIPs",
    data.table::uniqueN(zip$pwsid), nrow(zip), data.table::uniqueN(zip$zipcode))
save_processed(as.data.frame(zip), "ucmr5_pws_zip")

## ---- 4. additional data elements: PFAS occurrence / sources ----
add <- data.table::fread(
  file.path(PATHS$raw_ucmr5, "UCMR5_AddtlDataElem.txt"),
  sep = "\t", colClasses = "character", showProgress = FALSE
)
data.table::setnames(add, make.names(tolower(names(add))))
pfas_elem <- add[additionaldataelement %in%
                   c("PFASOccurrence", "PotentialPFASSources", "PFASTreatment")]
pfas_wide <- data.table::dcast(
  pfas_elem, pwsid ~ additionaldataelement,
  value.var = "response",
  fun.aggregate = function(x) paste(sort(unique(x[x != ""])), collapse = "; ")
)
data.table::setnames(pfas_wide, tolower(names(pfas_wide)))
save_processed(as.data.frame(pfas_wide), "ucmr5_pfas_flags")

msg("01_read_ucmr5.R done")
