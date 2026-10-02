# =====================================================================
# 09_a3a_compare_exposure_surfaces.R
# A3a.4 -- compare the Phase 1 baseline and equal-split-population-weighted
# exposure surfaces BEFORE looking at any health outcome.
# =====================================================================
if (!exists("DA_PATHS")) source(if (file.exists("phase2/direction_a_feasibility/scripts/00_setup.R"))
  "phase2/direction_a_feasibility/scripts/00_setup.R" else "00_setup.R")
suppressPackageStartupMessages({library(sf); library(ggplot2)})
old_ggsave <- ggplot2::ggsave; ggsave <- function(...) old_ggsave(..., bg = "white")

d_all <- readRDS(file.path(DA_PATHS$processed, "a3a_zcta_exposure_compare.rds"))
d <- d_all[d_all$analytic_primary == 1, ]   # same primary sample as A1/Phase 1
D <- sf::st_drop_geometry(d)
msg("A3a comparison sample: n = %d (same primary ZCTA sample as A1/Phase 1)", nrow(D))

## ---- distributions ----------------------------------------------------
desc <- data.frame(
  exposure = c("pfas_hazard_index_phase1 (baseline)", "pfas_hazard_index_popwt (equal-split alt.)"),
  n = c(sum(is.finite(D$pfas_hazard_index_phase1)), sum(is.finite(D$pfas_hazard_index_popwt))),
  mean = c(mean(D$pfas_hazard_index_phase1), mean(D$pfas_hazard_index_popwt)),
  median = c(median(D$pfas_hazard_index_phase1), median(D$pfas_hazard_index_popwt)),
  iqr = c(IQR(D$pfas_hazard_index_phase1), IQR(D$pfas_hazard_index_popwt)),
  max = c(max(D$pfas_hazard_index_phase1), max(D$pfas_hazard_index_popwt)),
  pct_nondetect = c(mean(D$pfas_hazard_index_phase1 == 0), mean(D$pfas_hazard_index_popwt == 0)))
desc[, 3:7] <- lapply(desc[, 3:7], round, 4)
write.csv(desc, file.path(DA_PATHS$outputs, "a3a_exposure_distributions.csv"), row.names = FALSE)
cat("\n===== A3a.4 -- exposure-surface distributions =====\n"); print(desc, row.names = FALSE)

## ---- agreement between surfaces ---------------------------------------
agree <- data.frame(
  metric = c("Pearson correlation", "Spearman rank correlation"),
  value = c(round(cor(D$pfas_hazard_index_phase1, D$pfas_hazard_index_popwt), 3),
            round(cor(D$pfas_hazard_index_phase1, D$pfas_hazard_index_popwt, method = "spearman"), 3)))

D$q_phase1 <- dplyr::ntile(D$pfas_hazard_index_phase1, 4)
D$q_popwt  <- dplyr::ntile(D$pfas_hazard_index_popwt, 4)
D$quartile_move <- abs(D$q_phase1 - D$q_popwt)
move_tab <- data.frame(quartiles_moved = c("0", "1", "2", "3"),
                       n = sapply(0:3, function(k) sum(D$quartile_move == k)),
                       pct = sapply(0:3, function(k) round(100 * mean(D$quartile_move == k), 1)))
write.csv(move_tab, file.path(DA_PATHS$outputs, "a3a_exposure_agreement.csv"), row.names = FALSE)
cat("\n--- Pearson/Spearman agreement ---\n"); print(agree, row.names = FALSE)
cat("\n--- quartile movement (0 = same quartile under both methods) ---\n"); print(move_tab, row.names = FALSE)

## hotspot overlap: top decile / top quartile under each method
top10_phase1 <- D$zcta[D$pfas_hazard_index_phase1 >= quantile(D$pfas_hazard_index_phase1, .9)]
top10_popwt  <- D$zcta[D$pfas_hazard_index_popwt  >= quantile(D$pfas_hazard_index_popwt, .9)]
topq_phase1  <- D$zcta[D$q_phase1 == 4]
topq_popwt   <- D$zcta[D$q_popwt == 4]
hotspot <- data.frame(
  definition = c("Top decile (>=P90)", "Top quartile (Q4)"),
  n_phase1 = c(length(top10_phase1), length(topq_phase1)),
  n_popwt  = c(length(top10_popwt), length(topq_popwt)),
  n_overlap = c(length(intersect(top10_phase1, top10_popwt)), length(intersect(topq_phase1, topq_popwt))),
  pct_of_phase1_retained = c(round(100 * length(intersect(top10_phase1, top10_popwt)) / length(top10_phase1), 1),
                              round(100 * length(intersect(topq_phase1, topq_popwt)) / length(topq_phase1), 1)))
write.csv(hotspot, file.path(DA_PATHS$outputs, "a3a_hotspot_agreement.csv"), row.names = FALSE)
cat("\n--- hotspot overlap ---\n"); print(hotspot, row.names = FALSE)

## where does assignment matter most? (largest absolute / rank disagreement)
D$abs_diff <- D$pfas_hazard_index_popwt - D$pfas_hazard_index_phase1
top_disagree <- D[order(-abs(D$abs_diff)), c("zcta", "n_pws_serving.x", "pfas_hazard_index_phase1", "pfas_hazard_index_popwt", "abs_diff")][1:15, ]
names(top_disagree)[2] <- "n_pws_serving"
write.csv(top_disagree, file.path(DA_PATHS$outputs, "a3a_top_disagreement_zcta.csv"), row.names = FALSE)
cat("\n--- 15 ZCTAs with the largest assignment-method disagreement ---\n"); print(top_disagree, row.names = FALSE)

## ---- maps ---------------------------------------------------------------
d_proj <- sf::st_transform(d, 5070)
d_proj$abs_diff <- D$abs_diff[match(d_proj$zcta, D$zcta)]
d_proj$quartile_move <- D$quartile_move[match(d_proj$zcta, D$zcta)]
tx_state <- sf::st_read(file.path(PATHS$raw_geo, "cb_2022_us_state_500k.shp"), quiet = TRUE)
tx_state <- tx_state[tx_state$STUSPS == "TX", ] |> sf::st_transform(5070)
cap <- function(x, p = .98) pmin(x, quantile(x, p, na.rm = TRUE))

ggsave(file.path(DA_PATHS$figures, "a3a_map_1_phase1_exposure.png"),
  ggplot() + geom_sf(data = d_proj, aes(fill = cap(pfas_hazard_index_phase1)), colour = NA) +
    geom_sf(data = tx_state, fill = NA, colour = "grey40", linewidth = .3) +
    scale_fill_viridis_c(option = "plasma", trans = "sqrt", name = "HI") +
    labs(title = "A3a -- 1. Phase 1 baseline exposure") + theme_void(base_size = 12),
  width = 7, height = 6.6, dpi = 200)

ggsave(file.path(DA_PATHS$figures, "a3a_map_2_popwt_exposure.png"),
  ggplot() + geom_sf(data = d_proj, aes(fill = cap(pfas_hazard_index_popwt)), colour = NA) +
    geom_sf(data = tx_state, fill = NA, colour = "grey40", linewidth = .3) +
    scale_fill_viridis_c(option = "plasma", trans = "sqrt", name = "HI") +
    labs(title = "A3a -- 2. equal-split population-weighted exposure") + theme_void(base_size = 12),
  width = 7, height = 6.6, dpi = 200)

ggsave(file.path(DA_PATHS$figures, "a3a_map_3_absolute_difference.png"),
  ggplot() + geom_sf(data = d_proj, aes(fill = abs_diff), colour = NA) +
    geom_sf(data = tx_state, fill = NA, colour = "grey40", linewidth = .3) +
    scale_fill_gradient2(low = "#2166ac", mid = "grey95", high = "#b2182b", midpoint = 0, name = "alt - base") +
    labs(title = "A3a -- 3. absolute difference (alt. minus baseline)") + theme_void(base_size = 12),
  width = 7, height = 6.6, dpi = 200)

ggsave(file.path(DA_PATHS$figures, "a3a_map_4_quartile_movement.png"),
  ggplot() + geom_sf(data = d_proj, aes(fill = factor(quartile_move)), colour = NA) +
    geom_sf(data = tx_state, fill = NA, colour = "grey40", linewidth = .3) +
    scale_fill_manual(values = c("0"="grey90","1"="#fdbb84","2"="#e34a33","3"="#7f0000"), name = "quartiles moved") +
    labs(title = "A3a -- 4. exposure-quartile movement under the alternative assignment") + theme_void(base_size = 12),
  width = 7, height = 6.6, dpi = 200)

D$hotspot_class <- ifelse(D$zcta %in% topq_phase1 & D$zcta %in% topq_popwt, "high-high (agree)",
                   ifelse(D$zcta %in% topq_phase1 & !(D$zcta %in% topq_popwt), "high under baseline only",
                   ifelse(!(D$zcta %in% topq_phase1) & D$zcta %in% topq_popwt, "high under alt. only", "low-low (agree)")))
d_proj$hotspot_class <- D$hotspot_class[match(d_proj$zcta, D$zcta)]
ggsave(file.path(DA_PATHS$figures, "a3a_map_5_hotspot_disagreement.png"),
  ggplot() + geom_sf(data = d_proj, aes(fill = hotspot_class), colour = NA) +
    geom_sf(data = tx_state, fill = NA, colour = "grey40", linewidth = .3) +
    scale_fill_manual(values = c("high-high (agree)"="#7f0000", "high under baseline only"="#2166ac",
                                  "high under alt. only"="#f46d43", "low-low (agree)"="grey92"), name = NULL) +
    labs(title = "A3a -- 5. top-quartile hotspot disagreement, baseline vs. alternative") + theme_void(base_size = 12),
  width = 7.5, height = 6.8, dpi = 200)

da_save(D, "a3a_comparison_sample")
msg("09_a3a_compare_exposure_surfaces.R done")
