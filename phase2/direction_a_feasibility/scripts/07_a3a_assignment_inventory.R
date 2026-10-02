# =====================================================================
# 07_a3a_assignment_inventory.R
# A3a.1/A3a.2 -- which alternative PWS-to-community assignment methods are
# REALLY available, publicly, reproducibly? Checked against real sources
# before choosing a minimum viable comparison (not ten methods tested just
# because they exist).
# =====================================================================
if (!exists("DA_PATHS")) source(if (file.exists("phase2/direction_a_feasibility/scripts/00_setup.R"))
  "phase2/direction_a_feasibility/scripts/00_setup.R" else "00_setup.R")

inv <- data.frame(
  method = c(
    "1. Phase 1 baseline (exact ZIP=ZCTA; full-population weight per serving PWS)",
    "2. Population-weighted, equal-split-per-ZIP",
    "3. Area-weighted (ZCTA polygon area)",
    "4. HUD-USPS ZIP-county/tract crosswalk",
    "5. PWS service-area polygons (statewide)",
    "6. PWS service-area polygons (case study)"
  ),
  status = c(
    "RETAINED as baseline",
    "RETAINED as the primary alternative",
    "NOT OPERATIONALIZABLE for this step",
    "EXCLUDED",
    "FOUND REAL, NOT USED THIS PASS",
    "NOT ATTEMPTED (superseded by finding #5)"
  ),
  rationale = c(
    "Already built in Phase 1 (scripts/07_assemble_zcta_dataset.R): each ZCTA's exposure is a population-weighted mean across every PWS whose reported ZIP list includes that ZCTA, with weight = that PWS's TOTAL population served (SDWIS population_served_count), regardless of how many ZIPs/ZCTAs the PWS reports serving.",
    "Directly tests the mechanism above: a PWS serving many ZIP codes (e.g. one Texas system reports 102 distinct served ZIPs) contributes its FULL population to every one of them under the baseline method, which can over-weight large multi-ZIP utilities in any single ZCTA. The alternative instead weights each PWS-ZCTA edge by population_served_count / n_zips_reported_by_that_pws -- an equal-split assumption, not a measured one, but a genuinely different and fully reproducible one computable from data already on hand (no new download).",
    "A PWS is a utility, not a polygon -- it has no natural 'area' to weight by in the way a ZCTA-to-county relationship file does. Area-weighting would require a service-area polygon per PWS (see method 5/6), which is exactly what is not yet available. Noted here rather than forcing an arbitrary area proxy.",
    "Requires an API key to download (see phase2/docs/exposure_data_inventory.csv and the A2 crosswalk decision) -- excluded to keep this project's keyless-public-data convention, as documented for A2's county crosswalk choice.",
    "The Texas Water Development Board's Texas Water Service Boundary Viewer (https://www3.twdb.texas.gov/apps/waterserviceboundaries) is described by TWDB as 'the first complete map of the 4,500+ PWS in the state' -- i.e. a REAL, authoritative, statewide retail water-service-area boundary layer, viewable/downloadable as shapefile/CSV per the TWDB user guide. No scripted bulk-download URL (as opposed to an interactive map export) was found within this pilot's time budget. This is flagged as the single highest-value follow-up for a future phase -- a genuine service-area polygon per PWS would be strictly better evidence than any population-weighting heuristic used here.",
    "Not pursued because method 5 shows a statewide solution plausibly exists and is worth pursuing directly rather than reconstructing 1-3 systems by hand as a stopgap."
  )
)
write.csv(inv, file.path(DA_PATHS$docs, "a3a_assignment_methods_inventory.csv"), row.names = FALSE)
cat("\n===== A3a.1/A3a.2 -- assignment-method inventory =====\n")
for (i in seq_len(nrow(inv))) cat(sprintf("\n%s\n  status: %s\n  %s\n", inv$method[i], inv$status[i], inv$rationale[i]))

msg("07_a3a_assignment_inventory.R done -- minimum viable comparison: baseline vs. equal-split population weighting")
