# =====================================================================
# 11_spatial_autocorr.R  --  Deliverable E (part 2): spatial autocorrelation
#   input : data/processed/texas_zcta_analytical.rds
#   output: outputs/morans_i_global.csv
#           outputs/lisa_summary.csv
#           data/processed/texas_zcta_lisa.(rds/csv)
#           figures/map_lisa_*.png
# =====================================================================
if (!exists("PATHS")) source(if (file.exists("scripts/00_setup.R")) "scripts/00_setup.R" else "00_setup.R")
stopifnot(requireNamespace("spdep", quietly = TRUE))
suppressPackageStartupMessages({library(spdep); library(sf); library(ggplot2)})
old_ggsave <- ggplot2::ggsave; ggsave <- function(...) old_ggsave(..., bg = "white")

d <- readRDS(file.path(PATHS$processed, "texas_zcta_analytical.rds")) |>
  st_transform(5070) |> dplyr::filter(analytic_primary == 1)
d <- d[!st_is_empty(d), ]
msg("spatial weights on n = %d ZCTA polygons", nrow(d))

## ---- neighbours ------------------------------------------
# Primary: k = 6 nearest-neighbour weights (robust to the spatially gappy
# UCMR5-linked sample). Sensitivity: queen contiguity.
lw    <- build_listw(d, "knn", k = 6)
lw_q  <- build_listw(d, "queen")
msg("  spatial weights: k=6 NN (primary); queen contiguity (sensitivity)")

## ---- global Moran's I ----------------------------------
tv <- c(obesity_pct = "Obesity", diabetes_pct = "Diabetes", bphigh_pct = "Hypertension",
        pfas_hazard_index = "PFAS Hazard Index", pfas_sum_ugL = "Sum PFAS",
        pfas_n_detected_popwt = "N PFAS detected", pfas_detect_freq = "PFAS detection freq",
        svi_index = "SES-vulnerability index", median_hh_income = "Median HH income",
        pct_hispanic = "% Hispanic")
gi <- do.call(rbind, lapply(names(tv), function(v) {
  x <- as.numeric(d[[v]]); x[!is.finite(x)] <- mean(x, na.rm = TRUE)
  mt  <- moran.test(x, lw,   zero.policy = TRUE, randomisation = TRUE)
  mtq <- moran.test(x, lw_q, zero.policy = TRUE, randomisation = TRUE)
  data.frame(variable = v, label = tv[[v]],
             morans_I_knn6 = unname(mt$estimate[1]),
             z_knn6 = unname((mt$estimate[1] - mt$estimate[2]) / sqrt(mt$estimate[3])),
             p_knn6 = mt$p.value,
             morans_I_queen = unname(mtq$estimate[1]),
             p_queen = mtq$p.value, row.names = NULL)
}))
gi[, c("morans_I_knn6","z_knn6","morans_I_queen")] <-
  lapply(gi[, c("morans_I_knn6","z_knn6","morans_I_queen")], function(x) signif(x, 4))
gi$p_knn6  <- formatC(gi$p_knn6,  format = "e", digits = 2)
gi$p_queen <- formatC(gi$p_queen, format = "e", digits = 2)
write.csv(gi, file.path(PATHS$outputs, "morans_i_global.csv"), row.names = FALSE)
cat("\n===== GLOBAL MORAN'S I (Texas primary sample) =====\n")
print(gi[, c("label","morans_I_knn6","z_knn6","p_knn6","morans_I_queen")])

## ---- residual autocorrelation from a naive OLS ---------
f_ols <- obesity_pct ~ pfas_hazard_index + median_hh_income + poverty_rate +
  pct_bachelors_plus + unemployment_rate + pct_hispanic + pct_nh_black +
  pct_65_plus + log_pop_density
m_ols <- lm(f_ols, data = st_drop_geometry(d))
lm_moran <- lm.morantest(m_ols, lw, zero.policy = TRUE)
cat(sprintf("\nOLS(obesity) residual Moran's I = %.3f  (p = %.3g)\n",
            lm_moran$estimate[1], lm_moran$p.value))

## ---- Local Moran / LISA for key layers -----------------
lisa_vars <- c("pfas_hazard_index", "obesity_pct", "diabetes_pct", "bphigh_pct", "svi_index")
lab_map   <- c(pfas_hazard_index = "PFAS Hazard Index", obesity_pct = "Obesity",
               diabetes_pct = "Diabetes", bphigh_pct = "Hypertension", svi_index = "SES vulnerability")
lisa_tab <- list()
for (v in lisa_vars) {
  x <- as.numeric(d[[v]]); x[!is.finite(x)] <- mean(x, na.rm = TRUE)
  lm_i <- localmoran(x, lw, zero.policy = TRUE)
  xs <- scale(x); ws <- lag.listw(lw, xs, zero.policy = TRUE)
  p  <- lm_i[, ncol(lm_i)]
  clus <- rep("Not significant", length(x))
  clus[p < .05 & xs > 0 & ws > 0] <- "High-High"
  clus[p < .05 & xs < 0 & ws < 0] <- "Low-Low"
  clus[p < .05 & xs > 0 & ws < 0] <- "High-Low"
  clus[p < .05 & xs < 0 & ws > 0] <- "Low-High"
  d[[paste0("lisa_", v)]] <- factor(clus,
      levels = c("High-High","Low-Low","High-Low","Low-High","Not significant"))
  lisa_tab[[v]] <- as.data.frame(table(cluster = d[[paste0("lisa_", v)]]))
  lisa_tab[[v]]$variable <- lab_map[[v]]
}
lisa_summary <- do.call(rbind, lisa_tab)[, c("variable","cluster","Freq")]
write.csv(lisa_summary, file.path(PATHS$outputs, "lisa_summary.csv"), row.names = FALSE)
cat("\n===== LISA CLUSTER COUNTS =====\n"); print(lisa_summary, row.names = FALSE)

## ---- co-location: PFAS High-High AND outcome High-High --
d$pfas_hot <- d$lisa_pfas_hazard_index == "High-High"
for (o in c("obesity_pct","diabetes_pct","bphigh_pct")) {
  hh <- d[[paste0("lisa_", o)]] == "High-High"
  cat(sprintf("PFAS hot-spot & %s hot-spot overlap: %d ZCTA\n", lab_map[[o]], sum(d$pfas_hot & hh)))
}
d$triple_burden <- as.integer(d$pfas_hot &
  (d$lisa_obesity_pct == "High-High" | d$lisa_diabetes_pct == "High-High" | d$lisa_bphigh_pct == "High-High") &
  d$lisa_svi_index == "High-High")
cat(sprintf("Triple-burden ZCTA (PFAS + >=1 disease + SES vulnerability, all High-High): %d\n",
            sum(d$triple_burden, na.rm = TRUE)))

## ---- LISA maps ----------------------------------------
lisa_cols <- c("High-High"="#b2182b","Low-Low"="#2166ac","High-Low"="#ef8a62",
               "Low-High"="#67a9cf","Not significant"="grey88")
tx_state <- st_read(file.path(PATHS$raw_geo,"cb_2022_us_state_500k.shp"), quiet = TRUE)
tx_state <- tx_state[tx_state$STUSPS == "TX", ] |> st_transform(5070)
for (v in lisa_vars) {
  p <- ggplot() +
    geom_sf(data = d, aes(fill = .data[[paste0("lisa_", v)]]), colour = NA) +
    geom_sf(data = tx_state, fill = NA, colour = "grey30", linewidth = .4) +
    scale_fill_manual(values = lisa_cols, name = NULL, drop = FALSE) +
    labs(title = sprintf("LISA cluster map -- %s", lab_map[[v]]),
         subtitle = "Local Moran's I, queen contiguity, p < 0.05 (Texas primary sample)") +
    theme_void(base_size = 12) + theme(plot.title = element_text(face = "bold"))
  ggsave(file.path(PATHS$figures, sprintf("map_lisa_%s.png", v)), p, width = 8.5, height = 8, dpi = 200)
}

save_processed(d, "texas_zcta_lisa")
msg("11_spatial_autocorr.R done")
