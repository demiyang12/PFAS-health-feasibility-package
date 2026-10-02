# =====================================================================
# 19_a3c_compare_exposure_surfaces.R
# A3c -- three-way comparison of Phase 1 baseline, A3a (equal-split
# population-weighted), and A3c (TWDB real-polygon spatial overlay)
# exposure surfaces, BEFORE touching any health outcome.
# =====================================================================
if (!exists("DA_PATHS")) source(if (file.exists("phase2/direction_a_feasibility/scripts/00_setup.R"))
  "phase2/direction_a_feasibility/scripts/00_setup.R" else "00_setup.R")
suppressPackageStartupMessages({library(sf); library(ggplot2)})
old_ggsave <- ggplot2::ggsave; ggsave <- function(...) old_ggsave(..., bg = "white")

a3a <- sf::st_drop_geometry(readRDS(file.path(DA_PATHS$processed, "a3a_zcta_exposure_compare.rds")))
a3c <- readRDS(file.path(DA_PATHS$processed, "a3c_zcta_exposure_hybrid.rds"))
d <- a3c[a3c$analytic_primary == 1, ]   # same primary sample as A1/Phase 1/A3a
D <- sf::st_drop_geometry(d)
D <- merge(D, a3a[, c("zcta", "pfas_hazard_index_popwt")], by = "zcta", all.x = TRUE)
msg("A3c comparison sample: n = %d (same primary ZCTA sample as A1/Phase 1/A3a)", nrow(D))
cat(sprintf("ZCTAs in this sample with >=1 TWDB-polygon-based edge: %d (%.1f%%); pure ZIP-fallback: %d\n",
            sum(D$pct_edges_from_polygon > 0, na.rm = TRUE),
            100 * mean(D$pct_edges_from_polygon > 0, na.rm = TRUE),
            sum(D$pct_edges_from_polygon == 0 | is.na(D$pct_edges_from_polygon))))

## ---- distributions, all three surfaces --------------------------------
desc <- data.frame(
  exposure = c("pfas_hazard_index_phase1 (baseline)", "pfas_hazard_index_popwt (A3a equal-split)",
               "pfas_hazard_index_hybrid (A3c TWDB polygon)"),
  n      = c(sum(is.finite(D$pfas_hazard_index_phase1)), sum(is.finite(D$pfas_hazard_index_popwt)), sum(is.finite(D$pfas_hazard_index_hybrid))),
  mean   = c(mean(D$pfas_hazard_index_phase1), mean(D$pfas_hazard_index_popwt, na.rm=TRUE), mean(D$pfas_hazard_index_hybrid, na.rm=TRUE)),
  median = c(median(D$pfas_hazard_index_phase1), median(D$pfas_hazard_index_popwt, na.rm=TRUE), median(D$pfas_hazard_index_hybrid, na.rm=TRUE)),
  iqr    = c(IQR(D$pfas_hazard_index_phase1), IQR(D$pfas_hazard_index_popwt, na.rm=TRUE), IQR(D$pfas_hazard_index_hybrid, na.rm=TRUE)),
  max    = c(max(D$pfas_hazard_index_phase1), max(D$pfas_hazard_index_popwt, na.rm=TRUE), max(D$pfas_hazard_index_hybrid, na.rm=TRUE)))
desc[, 3:6] <- lapply(desc[, 3:6], round, 4)
write.csv(desc, file.path(DA_PATHS$outputs, "a3c_exposure_distributions.csv"), row.names = FALSE)
cat("\n===== A3c -- exposure-surface distributions (3-way) =====\n"); print(desc, row.names = FALSE)

## ---- pairwise agreement -------------------------------------------------
pw <- function(x, y) c(pearson = round(cor(x, y, use="complete.obs"), 3),
                        spearman = round(cor(x, y, method="spearman", use="complete.obs"), 3))
agree <- rbind(
  data.frame(comparison = "Phase1 vs A3a (equal-split)", t(pw(D$pfas_hazard_index_phase1, D$pfas_hazard_index_popwt))),
  data.frame(comparison = "Phase1 vs A3c (TWDB polygon)", t(pw(D$pfas_hazard_index_phase1, D$pfas_hazard_index_hybrid))),
  data.frame(comparison = "A3a vs A3c",                   t(pw(D$pfas_hazard_index_popwt, D$pfas_hazard_index_hybrid))))
write.csv(agree, file.path(DA_PATHS$outputs, "a3c_exposure_agreement.csv"), row.names = FALSE)
cat("\n--- pairwise Pearson/Spearman agreement ---\n"); print(agree, row.names = FALSE)

D$q_phase1 <- dplyr::ntile(D$pfas_hazard_index_phase1, 4)
D$q_hybrid <- dplyr::ntile(D$pfas_hazard_index_hybrid, 4)
D$quartile_move <- abs(D$q_phase1 - D$q_hybrid)
move_tab <- data.frame(quartiles_moved = c("0","1","2","3"),
                       n = sapply(0:3, function(k) sum(D$quartile_move == k, na.rm=TRUE)),
                       pct = sapply(0:3, function(k) round(100*mean(D$quartile_move == k, na.rm=TRUE), 1)))
write.csv(move_tab, file.path(DA_PATHS$outputs, "a3c_quartile_movement.csv"), row.names = FALSE)
cat("\n--- Phase1 vs A3c quartile movement ---\n"); print(move_tab, row.names = FALSE)

top10_phase1 <- D$zcta[D$pfas_hazard_index_phase1 >= quantile(D$pfas_hazard_index_phase1, .9)]
top10_hybrid <- D$zcta[D$pfas_hazard_index_hybrid >= quantile(D$pfas_hazard_index_hybrid, .9, na.rm=TRUE)]
topq_phase1  <- D$zcta[D$q_phase1 == 4]
topq_hybrid  <- D$zcta[D$q_hybrid == 4]
hotspot <- data.frame(
  definition = c("Top decile (>=P90)", "Top quartile (Q4)"),
  n_phase1 = c(length(top10_phase1), length(topq_phase1)),
  n_hybrid = c(length(top10_hybrid), length(topq_hybrid)),
  n_overlap = c(length(intersect(top10_phase1, top10_hybrid)), length(intersect(topq_phase1, topq_hybrid))),
  pct_of_phase1_retained = c(round(100*length(intersect(top10_phase1, top10_hybrid))/length(top10_phase1), 1),
                              round(100*length(intersect(topq_phase1, topq_hybrid))/length(topq_phase1), 1)))
write.csv(hotspot, file.path(DA_PATHS$outputs, "a3c_hotspot_agreement.csv"), row.names = FALSE)
cat("\n--- hotspot overlap (Phase1 vs A3c) ---\n"); print(hotspot, row.names = FALSE)

D$abs_diff <- D$pfas_hazard_index_hybrid - D$pfas_hazard_index_phase1
top_disagree <- D[order(-abs(D$abs_diff)), c("zcta", "n_pws_serving_hybrid", "pct_edges_from_polygon",
                                              "pfas_hazard_index_phase1", "pfas_hazard_index_hybrid", "abs_diff")][1:15, ]
write.csv(top_disagree, file.path(DA_PATHS$outputs, "a3c_top_disagreement_zcta.csv"), row.names = FALSE)
cat("\n--- 15 ZCTAs with the largest Phase1-vs-A3c disagreement ---\n"); print(top_disagree, row.names = FALSE)

## ---- maps ---------------------------------------------------------------
d_proj <- sf::st_transform(d, 5070)
d_proj$abs_diff <- D$abs_diff[match(d_proj$zcta, D$zcta)]
d_proj$quartile_move <- D$quartile_move[match(d_proj$zcta, D$zcta)]
d_proj$pct_edges_from_polygon <- D$pct_edges_from_polygon[match(d_proj$zcta, D$zcta)]
tx_state <- sf::st_read(file.path(PATHS$raw_geo, "cb_2022_us_state_500k.shp"), quiet = TRUE)
tx_state <- tx_state[tx_state$STUSPS == "TX", ] |> sf::st_transform(5070)
cap <- function(x, p = .98) pmin(x, quantile(x, p, na.rm = TRUE))

ggsave(file.path(DA_PATHS$figures, "a3c_map_1_hybrid_exposure.png"),
  ggplot() + geom_sf(data = d_proj, aes(fill = cap(pfas_hazard_index_hybrid)), colour = NA) +
    geom_sf(data = tx_state, fill = NA, colour = "grey40", linewidth = .3) +
    scale_fill_viridis_c(option = "plasma", trans = "sqrt", name = "HI", na.value = "grey90") +
    labs(title = "A3c -- 1. TWDB real-polygon spatial-overlay exposure") + theme_void(base_size = 12),
  width = 7, height = 6.6, dpi = 200)

ggsave(file.path(DA_PATHS$figures, "a3c_map_2_absolute_difference.png"),
  ggplot() + geom_sf(data = d_proj, aes(fill = abs_diff), colour = NA) +
    geom_sf(data = tx_state, fill = NA, colour = "grey40", linewidth = .3) +
    scale_fill_gradient2(low = "#2166ac", mid = "grey95", high = "#b2182b", midpoint = 0, name = "A3c - base", na.value="grey90") +
    labs(title = "A3c -- 2. absolute difference (TWDB polygon minus Phase 1 baseline)") + theme_void(base_size = 12),
  width = 7, height = 6.6, dpi = 200)

ggsave(file.path(DA_PATHS$figures, "a3c_map_3_quartile_movement.png"),
  ggplot() + geom_sf(data = d_proj, aes(fill = factor(quartile_move)), colour = NA) +
    geom_sf(data = tx_state, fill = NA, colour = "grey40", linewidth = .3) +
    scale_fill_manual(values = c("0"="grey90","1"="#fdbb84","2"="#e34a33","3"="#7f0000"), name = "quartiles moved", na.value="grey95") +
    labs(title = "A3c -- 3. exposure-quartile movement, Phase 1 vs TWDB polygon") + theme_void(base_size = 12),
  width = 7, height = 6.6, dpi = 200)

D$hotspot_class <- ifelse(D$zcta %in% topq_phase1 & D$zcta %in% topq_hybrid, "high-high (agree)",
                   ifelse(D$zcta %in% topq_phase1 & !(D$zcta %in% topq_hybrid), "high under baseline only",
                   ifelse(!(D$zcta %in% topq_phase1) & D$zcta %in% topq_hybrid, "high under A3c only", "low-low (agree)")))
d_proj$hotspot_class <- D$hotspot_class[match(d_proj$zcta, D$zcta)]
ggsave(file.path(DA_PATHS$figures, "a3c_map_4_hotspot_disagreement.png"),
  ggplot() + geom_sf(data = d_proj, aes(fill = hotspot_class), colour = NA) +
    geom_sf(data = tx_state, fill = NA, colour = "grey40", linewidth = .3) +
    scale_fill_manual(values = c("high-high (agree)"="#7f0000", "high under baseline only"="#2166ac",
                                  "high under A3c only"="#f46d43", "low-low (agree)"="grey92"), name = NULL, na.value="white") +
    labs(title = "A3c -- 4. top-quartile hotspot disagreement, baseline vs. TWDB polygon") + theme_void(base_size = 12),
  width = 7.5, height = 6.8, dpi = 200)

ggsave(file.path(DA_PATHS$figures, "a3c_map_5_pct_edges_from_polygon.png"),
  ggplot() + geom_sf(data = d_proj, aes(fill = pct_edges_from_polygon), colour = NA) +
    geom_sf(data = tx_state, fill = NA, colour = "grey40", linewidth = .3) +
    scale_fill_viridis_c(option = "viridis", name = "% edges from\nreal TWDB polygon\n(vs. ZIP fallback)", na.value = "grey90") +
    labs(title = "A3c -- 5. where the real-polygon method applies vs. the ZIP-code fallback") + theme_void(base_size = 12),
  width = 7.5, height = 6.6, dpi = 200)

da_save(D, "a3c_comparison_sample")
msg("19_a3c_compare_exposure_surfaces.R done")
