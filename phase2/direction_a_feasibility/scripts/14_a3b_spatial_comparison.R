# =====================================================================
# 14_a3b_spatial_comparison.R
# A3b.4 -- BEFORE touching cholesterol: does source-pressure data explain
# UCMR5's spatial exposure pattern? And how do UCMR5 hotspots compare to
# source-pressure hotspots (2x2 classification)?
# =====================================================================
if (!exists("DA_PATHS")) source(if (file.exists("phase2/direction_a_feasibility/scripts/00_setup.R"))
  "phase2/direction_a_feasibility/scripts/00_setup.R" else "00_setup.R")
suppressPackageStartupMessages({library(sf); library(ggplot2)})
old_ggsave <- ggplot2::ggsave; ggsave <- function(...) old_ggsave(..., bg = "white")

base <- readRDS(file.path(PATHS$processed, "texas_zcta_analytical.rds"))
ind  <- readRDS(file.path(DA_PATHS$processed, "a3b_zcta_source_indicators.rds"))
d_all <- dplyr::left_join(base, ind, by = "zcta")
d <- d_all[d_all$analytic_primary == 1, ]
D <- sf::st_drop_geometry(d)
msg("A3b spatial-comparison sample: n = %d (Phase 1 primary sample)", nrow(D))

## ---- does UCMR5 exposure correlate with source pressure? --------------
src_vars <- c("n_pfas_tri_within_10km", "n_pfas_tri_within_20km", "pfas_tri_release_lb_within_20km",
             "npl_within_10km", "n_npdes_within_10km")
cor_tab <- do.call(rbind, lapply(src_vars, function(v) data.frame(
  source_variable = v,
  pearson = round(cor(D$pfas_hazard_index, D[[v]], use = "complete.obs"), 3),
  spearman = round(cor(D$pfas_hazard_index, D[[v]], method = "spearman", use = "complete.obs"), 3))))
write.csv(cor_tab, file.path(DA_PATHS$outputs, "a3b_exposure_source_correlations.csv"), row.names = FALSE)
cat("\n===== A3b.4 -- does UCMR5 exposure correlate with source pressure? =====\n"); print(cor_tab, row.names = FALSE)

## exposure by source-presence category
D$any_pfas_tri_20km <- D$n_pfas_tri_within_20km > 0
by_src <- do.call(rbind, lapply(split(D, D$any_pfas_tri_20km), function(g) data.frame(
  has_pfas_tri_within_20km = g$any_pfas_tri_20km[1], n = nrow(g),
  mean_hazard_index = round(mean(g$pfas_hazard_index), 4), pct_any_detect = round(100 * mean(g$pfas_any_detect), 1))))
write.csv(by_src, file.path(DA_PATHS$outputs, "a3b_exposure_by_source_presence.csv"), row.names = FALSE)
cat("\n--- UCMR5 exposure by PFAS-TRI-facility presence within 20km ---\n"); print(by_src, row.names = FALSE)

## ---- 2x2 hotspot classification: UCMR5 vs source pressure -------------
q75_exp <- quantile(D$pfas_hazard_index, .75, na.rm = TRUE)
# a simple combined source-pressure score for classification ONLY (not a
# composite exposure metric -- see A3b.6: never mixed into a PFAS score)
D$src_pressure_rank <- rank(D$n_pfas_tri_within_20km + D$npl_within_10km * 5 + scale(D$n_npdes_within_10km)[,1], na.last = "keep")
q75_src <- quantile(D$src_pressure_rank, .75, na.rm = TRUE)
D$class_2x2 <- with(D, ifelse(pfas_hazard_index >= q75_exp & src_pressure_rank >= q75_src, "high UCMR5 + high source pressure",
                       ifelse(pfas_hazard_index >= q75_exp & src_pressure_rank <  q75_src, "high UCMR5 + low source pressure",
                       ifelse(pfas_hazard_index <  q75_exp & src_pressure_rank >= q75_src, "low UCMR5 + high source pressure",
                                                              "low UCMR5 + low source pressure"))))
tab_2x2 <- as.data.frame(table(D$class_2x2)); names(tab_2x2) <- c("classification", "n")
write.csv(tab_2x2, file.path(DA_PATHS$outputs, "a3b_hotspot_overlap.csv"), row.names = FALSE)
cat("\n--- 2x2 classification: UCMR5 exposure vs source-pressure rank (both top-quartile cut) ---\n"); print(tab_2x2, row.names = FALSE)
cat("\nNote: 'high UCMR5 + low source pressure' and 'low UCMR5 + high source pressure' are the\n",
    "scientifically interesting disagreement cells -- places where the two kinds of evidence\n",
    "point in different directions.\n")

## maps
d_proj <- sf::st_transform(d, 5070)
tx_state <- sf::st_read(file.path(PATHS$raw_geo, "cb_2022_us_state_500k.shp"), quiet = TRUE)
tx_state <- tx_state[tx_state$STUSPS == "TX", ] |> sf::st_transform(5070)
d_proj$class_2x2 <- D$class_2x2[match(d_proj$zcta, D$zcta)]
ggsave(file.path(DA_PATHS$figures, "a3b_map_hotspot_overlap.png"),
  ggplot() + geom_sf(data = d_proj, aes(fill = class_2x2), colour = NA) +
    geom_sf(data = tx_state, fill = NA, colour = "grey40", linewidth = .3) +
    scale_fill_manual(values = c("high UCMR5 + high source pressure" = "#7f0000",
                                  "high UCMR5 + low source pressure"  = "#2166ac",
                                  "low UCMR5 + high source pressure"  = "#f46d43",
                                  "low UCMR5 + low source pressure"   = "grey90"), name = NULL) +
    labs(title = "A3b -- UCMR5 exposure vs. source-pressure, 2x2 classification") +
    theme_void(base_size = 12) + theme(legend.position = "bottom", legend.direction = "vertical"),
  width = 7.5, height = 7.2, dpi = 200)

ggsave(file.path(DA_PATHS$figures, "a3b_map_pfas_tri_facilities.png"),
  ggplot() + geom_sf(data = d_proj, aes(fill = n_pfas_tri_within_20km), colour = NA) +
    geom_sf(data = tx_state, fill = NA, colour = "grey40", linewidth = .3) +
    scale_fill_viridis_c(option = "inferno", name = "PFAS-TRI\nfacilities\n(20km)") +
    labs(title = "A3b -- PFAS-reporting TRI facilities within 20km, by ZCTA") + theme_void(base_size = 12),
  width = 7, height = 6.6, dpi = 200)

da_save(D, "a3b_spatial_comparison_sample")
msg("14_a3b_spatial_comparison.R done")
