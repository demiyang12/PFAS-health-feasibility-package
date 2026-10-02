# =====================================================================
# 12_a3b_download_source_data.R
# A3b.1 -- real, Texas-specific pulls for the top-priority source-pressure
# datasets (EPA National PFAS Analytic Tools' own underlying sources were
# not bulk-downloadable within this pilot's time budget -- see
# docs/a3a_assignment... no, see the inventory below -- the clean,
# machine-readable EPA "EF_*" GIS exports and the Envirofacts TRI REST API
# were used instead, consistent with "don't spend excessive time before
# clean sources are exhausted").
#
# 1. EPA TRI facility locations (all TX TRI facilities, for context)      [category C candidate / backbone]
# 2. EPA TRI PFAS-specific reporting records (facility x chemical x year) [category B: reported release]
# 3. EPA Superfund NPL sites, Texas                                       [category C: site classification]
# 4. EPA NPDES-permitted facilities, Texas (wastewater/discharge pathway, [category C: pathway indicator]
#    used in place of CWNS -- CWNS's 2022 data-download tool is an
#    interactive APEX app with no scripted bulk-CSV URL found this pass;
#    NPDES covers the same "wastewater facility" pathway and IS a clean,
#    direct, keyless CSV -- this substitution is documented, not silent)
# =====================================================================
if (!exists("DA_PATHS")) source(if (file.exists("phase2/direction_a_feasibility/scripts/00_setup.R"))
  "phase2/direction_a_feasibility/scripts/00_setup.R" else "00_setup.R")
library(data.table)
suppressPackageStartupMessages(library(bit64))  # without this, fread's integer64-typed doc_ctrl_num
                                                 # (re-read from the cached CSV) prints as garbage via
                                                 # paste0() -- raw double bit-pattern, not the real ID
RAWB <- file.path(DA_PATHS$raw, "a3b_source"); dir.create(RAWB, showWarnings = FALSE, recursive = TRUE)

## ---- 1. Superfund NPL (EF_NPL.csv) -----------------------------------
npl <- fread("https://dmap-data-commons-oms.s3.amazonaws.com/EF/GIS/EF_NPL.csv", showProgress = FALSE)
npl_tx <- npl[state_code == "TX"]
fwrite(npl_tx, file.path(RAWB, "ef_npl_tx.csv"))
msg("Superfund NPL: %d sites nationally, %d in Texas", nrow(npl), nrow(npl_tx))

## ---- 2. TRI facility locations (EF_TRI.csv) --------------------------
tri_loc <- fread("https://dmap-data-commons-oms.s3.amazonaws.com/EF/GIS/EF_TRI.csv", showProgress = FALSE)
tri_loc_tx <- tri_loc[state_code == "TX"]
fwrite(tri_loc_tx, file.path(RAWB, "ef_tri_facilities_tx.csv"))
msg("TRI facility locations: %d nationally, %d in Texas", nrow(tri_loc), nrow(tri_loc_tx))

## ---- 3. NPDES-permitted facilities, Texas only (EF_NPDES.csv is ~235MB
##         nationally; filtered immediately, national file not retained) --
npdes_tmp <- tempfile(fileext = ".csv")
utils::download.file("https://dmap-data-commons-oms.s3.amazonaws.com/EF/GIS/EF_NPDES.csv", npdes_tmp, quiet = TRUE)
npdes <- fread(npdes_tmp, showProgress = FALSE)
npdes_tx <- npdes[state_code == "TX"]
fwrite(npdes_tx, file.path(RAWB, "ef_npdes_tx.csv"))
unlink(npdes_tmp)
msg("NPDES-permitted facilities: %d nationally, %d in Texas", nrow(npdes), nrow(npdes_tx))

## ---- 4. TRI PFAS-specific reporting records (Envirofacts REST) -------
## tri_chem_info has a documented pfas_ind flag (verified live, not assumed)
ef_get <- function(path) {
  u <- paste0("https://data.epa.gov/efservice/", path, "/JSON")
  r <- tryCatch(jsonlite::fromJSON(u, flatten = TRUE), error = function(e) NULL)
  if (is.null(r) || !is.data.frame(r) || !nrow(r)) return(NULL)
  r
}
pfas_chem <- ef_get("tri_chem_info/pfas_ind/1")
msg("TRI chemicals flagged PFAS (pfas_ind=1): %d", nrow(pfas_chem))
write.csv(pfas_chem[, c("tri_chem_id", "chem_name", "cas_registry_number")],
          file.path(DA_PATHS$docs, "a3b_tri_pfas_chemical_list.csv"), row.names = FALSE)

forms_cache <- file.path(RAWB, "tri_pfas_reporting_form_national.csv")
if (file.exists(forms_cache)) {
  msg("Reusing cached %s from an earlier run of this script", forms_cache)
  tri_pfas_forms <- fread(forms_cache)
} else {
  msg("Querying TRI reporting_form for each of %d PFAS chemicals (~5s/chemical typical; ~15-20 min total, mostly network wait, not stuck -- most chemicals return 0 rows)...", nrow(pfas_chem))
  forms <- list()
  for (i in seq_len(nrow(pfas_chem))) {
    cid <- pfas_chem$tri_chem_id[i]
    r <- ef_get(paste0("tri_reporting_form/tri_chem_id/", cid))
    if (!is.null(r)) { r$tri_chem_id <- cid; forms[[cid]] <- r }
    if (i %% 20 == 0) {
      msg("  ... %d/%d chemicals checked, %d with any reports so far", i, nrow(pfas_chem), length(forms))
      # incremental checkpoint -- never lose this slow loop's progress to an interruption
      if (length(forms)) fwrite(rbindlist(forms, fill = TRUE), forms_cache)
    }
  }
  tri_pfas_forms <- if (length(forms)) rbindlist(forms, fill = TRUE) else data.table()
  fwrite(tri_pfas_forms, forms_cache)
}
msg("TRI PFAS reporting_form records found nationally: %d (facilities x chemical x year)", nrow(tri_pfas_forms))

## restrict to Texas facilities BEFORE the slower per-document release-qty
## lookups (A3b only needs Texas indicators, so no reason to look up
## release quantities for the other ~45 states' records)
tx_fac_ids <- tri_loc_tx$pgm_sys_id
tri_pfas_tx <- tri_pfas_forms[tri_facility_id %in% tx_fac_ids]
msg("TRI PFAS reporting_form records at a TEXAS facility: %d (facilities: %d)",
    nrow(tri_pfas_tx), uniqueN(tri_pfas_tx$tri_facility_id))
fwrite(tri_pfas_tx, file.path(RAWB, "tri_pfas_reporting_form_tx.csv"))

## release quantities for the TEXAS records only (doc_ctrl_num -> tri_release_qty)
rel_cache <- file.path(RAWB, "tri_pfas_release_qty_national.csv")  # name kept for script 13 compatibility; TX-scoped in practice
rel_progress <- file.path(RAWB, ".tri_release_qty_progress.rds")
if (file.exists(rel_cache) && !file.exists(rel_progress)) {
  msg("Reusing cached %s from an earlier completed run", rel_cache)
  tri_pfas_releases <- fread(rel_cache)
} else {
  prog <- if (file.exists(rel_progress)) readRDS(rel_progress) else list(attempted = character(0), rel_list = list())
  rel_list <- prog$rel_list
  if (nrow(tri_pfas_tx)) {
    docs <- unique(as.character(tri_pfas_tx$doc_ctrl_num))
    docs_remaining <- setdiff(docs, prog$attempted)
    msg("Looking up release quantities for %d Texas PFAS-reporting documents (%d already attempted, %d remaining)...",
        length(docs), length(docs) - length(docs_remaining), length(docs_remaining))
    for (i in seq_along(docs_remaining)) {
      r <- ef_get(paste0("tri_release_qty/doc_ctrl_num/", docs_remaining[i]))
      if (!is.null(r)) rel_list[[docs_remaining[i]]] <- r
      prog$attempted <- c(prog$attempted, docs_remaining[i])
      if (i %% 10 == 0) {
        msg("  ... %d/%d remaining documents checked", i, length(docs_remaining))
        prog$rel_list <- rel_list
        saveRDS(prog, rel_progress)  # incremental checkpoint -- never lose this slow loop's progress
      }
    }
    prog$rel_list <- rel_list
    saveRDS(prog, rel_progress)
  }
  tri_pfas_releases <- if (length(rel_list)) rbindlist(rel_list, fill = TRUE) else data.table()
  fwrite(tri_pfas_releases, rel_cache)
  unlink(rel_progress)
}
msg("TRI PFAS (Texas) release-quantity line items found: %d", nrow(tri_pfas_releases))

msg("12_a3b_download_source_data.R done -- raw files in %s", RAWB)
