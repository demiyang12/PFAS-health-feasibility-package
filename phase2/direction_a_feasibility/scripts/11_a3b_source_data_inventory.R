# =====================================================================
# 11_a3b_source_data_inventory.R
# A3b.1 -- verify each source-pressure dataset with REAL Texas record
# counts (run AFTER 12_a3b_download_source_data.R). Replaces the Phase 2
# scoping inventory's "not yet extracted" placeholders with real numbers.
# =====================================================================
if (!exists("DA_PATHS")) source(if (file.exists("phase2/direction_a_feasibility/scripts/00_setup.R"))
  "phase2/direction_a_feasibility/scripts/00_setup.R" else "00_setup.R")
library(data.table)
RAWB <- file.path(DA_PATHS$raw, "a3b_source")

npl_tx    <- fread(file.path(RAWB, "ef_npl_tx.csv"))
tri_loc   <- fread(file.path(RAWB, "ef_tri_facilities_tx.csv"))
npdes_tx  <- fread(file.path(RAWB, "ef_npdes_tx.csv"))
tri_forms_nat <- fread(file.path(RAWB, "tri_pfas_reporting_form_national.csv"))
tri_forms_tx  <- fread(file.path(RAWB, "tri_pfas_reporting_form_tx.csv"))
tri_rel_nat   <- fread(file.path(RAWB, "tri_pfas_release_qty_national.csv"))

inv <- data.frame(
  source = c(
    "EPA TRI -- PFAS-specific reporting (facility x chemical x year)",
    "EPA TRI -- all facility locations (context / linkage backbone)",
    "EPA Superfund National Priorities List (NPL)",
    "EPA NPDES-permitted facilities (used in place of CWNS)"
  ),
  category = c("B: reported PFAS release", "n/a (location backbone only, not PFAS-specific)",
               "C: site classification (not PFAS-specific without manual screening)",
               "C: pathway indicator (not PFAS-specific)"),
  texas_record_count = c(
    sprintf("%d reporting-form records at %d distinct TX facilities", nrow(tri_forms_tx), uniqueN(tri_forms_tx$tri_facility_id)),
    nrow(tri_loc), nrow(npl_tx), nrow(npdes_tx)),
  national_record_count = c(sprintf("%d records, %d distinct facilities", nrow(tri_forms_nat), uniqueN(tri_forms_nat$tri_facility_id)),
                            "see EF_TRI.csv (EPA national TRI facility registry, live count varies slightly by pull date)",
                            "see EF_NPL.csv (EPA national Superfund NPL, live count varies slightly by pull date)",
                            "see EF_NPDES.csv (EPA national NPDES permits, ~1M+, TX-filtered immediately on download, national file not retained)"),
  years = c(paste(sort(unique(tri_forms_tx$reporting_year)), collapse = ", "), "current snapshot", "current snapshot (site status, not a reporting year)", "current snapshot"),
  pfas_specific = c("YES -- tri_chem_id restricted to the 196 chemicals flagged pfas_ind=1 in tri_chem_info",
                    "NO", "NO (NPL does not carry a queryable PFAS flag; would need per-site Record-of-Decision screening, not done here)",
                    "NO"),
  spatial_geometry = c("point (via TX facility location file)", "point (lat/lon)", "point (lat/lon)", "point (lat/lon)"),
  measured_release_or_pathway = c("Reported release quantity (lb), where available -- see tri_release_qty; many small releases are range-coded (not an exact pound figure), documented not estimated away",
                                  "n/a", "Site classification (contamination presence, not PFAS-specific or a concentration)",
                                  "Facility presence = discharge pathway, not a measurement"),
  duplicate_facilities_across_datasets = "Not cross-matched in this pass (would need FRS registry_id reconciliation across TRI/NPDES/NPL; registry_id IS present in all 3 EF_* files and could support this in a follow-up)",
  major_missingness = c("Many Texas TRI facilities report chemicals OTHER than PFAS and never appear here (correctly -- absence means 'did not report a PFAS chemical', not missing data)",
                        "A handful of facilities have lat/lon = 0 or NA in the raw TRI_FACILITY table; EF_TRI.csv's dmap_latitude/longitude fields look more complete and were used preferentially (documented in script 13)",
                        "None observed", "None observed"),
  usability = c("RETAIN -- the only true 'reported PFAS release' layer available", "RETAIN -- needed as the join backbone for the PFAS-specific records",
                "RETAIN AS CONTEXT -- cannot be treated as PFAS-specific without manual Record-of-Decision screening (not done here); used as a generic contamination-site proximity indicator only",
                "RETAIN AS CONTEXT -- a discharge-pathway indicator, not a CWNS substitute for infrastructure need; the substitution is documented, not silent")
)
write.csv(inv, file.path(DA_PATHS$docs, "a3b_source_inventory_verified.csv"), row.names = FALSE)
cat("\n===== A3b.1 -- verified Texas source-pressure inventory =====\n")
for (i in seq_len(nrow(inv))) cat(sprintf("\n[%s]\n  TX records: %s\n  category: %s | PFAS-specific: %s\n  usability: %s\n",
                                           inv$source[i], inv$texas_record_count[i], inv$category[i], inv$pfas_specific[i], inv$usability[i]))

counts <- data.frame(
  dataset = c("TRI PFAS reporting (TX facilities)", "TRI all facilities (TX)", "Superfund NPL (TX)", "NPDES permitted facilities (TX)"),
  n = c(uniqueN(tri_forms_tx$tri_facility_id), nrow(tri_loc), nrow(npl_tx), nrow(npdes_tx)))
write.csv(counts, file.path(DA_PATHS$outputs, "a3b_source_counts_texas.csv"), row.names = FALSE)

msg("11_a3b_source_data_inventory.R done")
