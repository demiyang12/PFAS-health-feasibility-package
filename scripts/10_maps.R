# =====================================================================
# 10_maps.R  --  Deliverable D: preliminary maps
#   input : data/processed/texas_zcta_analytical.rds
#           data/raw/geo/cb_2022_us_state_500k.shp
#           data/raw/geo/cb_2022_us_county_500k.shp
#   output: figures/map_*.png  (PFAS, obesity, diabetes, hypertension,
#           SES-vulnerability, PFAS-vs-burden bivariate, Bexar inset)
# =====================================================================
if (!exists("PATHS")) source(if (file.exists("scripts/00_setup.R")) "scripts/00_setup.R" else "00_setup.R")
suppressPackageStartupMessages({library(ggplot2); library(sf)})

d <- readRDS(file.path(PATHS$processed, "texas_zcta_analytical.rds")) |> st_transform(5070)
d_p <- dplyr::filter(d, analytic_primary == 1)

state  <- st_read(file.path(PATHS$raw_geo, "cb_2022_us_state_500k.shp"), quiet = TRUE)
county <- st_read(file.path(PATHS$raw_geo, "cb_2022_us_county_500k.shp"), quiet = TRUE)
names(state) <- tolower(names(state)); names(county) <- tolower(names(county))
tx_state  <- state[state$stusps == "TX", ]  |> st_transform(5070)
tx_county <- county[county$statefp == "48", ] |> st_transform(5070)
bexar     <- tx_county[tx_county$geoid == CFG$bexar_county_fips, ]

base_theme <- theme_void(base_size = 12) +
  theme(legend.position = "right", plot.title = element_text(face = "bold"),
        plot.margin = margin(10, 10, 10, 10),
        plot.background = element_rect(fill = "white", colour = NA),
        panel.background = element_rect(fill = "white", colour = NA))
old_ggsave <- ggplot2::ggsave
ggsave <- function(...) old_ggsave(..., bg = "white")

qmap <- function(fill, title, subtitle, pal = "viridis", dir = 1, trans = "identity",
                 labs_unit = NULL, data = d_p) {
  ggplot() +
    geom_sf(data = tx_county, fill = "grey92", colour = "white", linewidth = .15) +
    geom_sf(data = data, aes(fill = .data[[fill]]), colour = NA) +
    geom_sf(data = tx_county, fill = NA, colour = "white", linewidth = .12) +
    geom_sf(data = tx_state, fill = NA, colour = "grey30", linewidth = .4) +
    { if (pal == "viridis")
        scale_fill_viridis_c(option = "C", direction = dir, trans = trans, name = labs_unit,
                             na.value = "grey85")
      else
        scale_fill_gradient2(low = "#2166ac", mid = "grey95", high = "#b2182b",
                             midpoint = 0, name = labs_unit, na.value = "grey85") } +
    labs(title = title, subtitle = subtitle) + base_theme
}

ggsave(file.path(PATHS$figures, "map_1_pfas_hazard_index.png"),
       qmap("pfas_hazard_index", "1. PFAS exposure -- EPA Hazard Index",
            "Texas ZCTA, UCMR5 2023-24, population-weighted across serving PWS",
            labs_unit = "Hazard\nIndex", trans = "sqrt"),
       width = 8.5, height = 8, dpi = 200)

# detection status as categorical
d_p$detect_cat <- factor(ifelse(d_p$any_mcl_exceedance == 1, "MCL / HI exceedance",
                         ifelse(d_p$pfas_any_detect == 1, "PFAS detected", "No PFAS detected")),
                         levels = c("No PFAS detected", "PFAS detected", "MCL / HI exceedance"))
ggsave(file.path(PATHS$figures, "map_1b_pfas_detection_status.png"),
  ggplot() +
    geom_sf(data = tx_county, fill = "grey92", colour = "white", linewidth = .15) +
    geom_sf(data = d_p, aes(fill = detect_cat), colour = NA) +
    geom_sf(data = tx_state, fill = NA, colour = "grey30", linewidth = .4) +
    scale_fill_manual(values = c("No PFAS detected" = "#d9e6f2",
                                 "PFAS detected" = "#f4a582",
                                 "MCL / HI exceedance" = "#b2182b"), name = NULL) +
    labs(title = "1b. PFAS detection status by ZCTA",
         subtitle = "Texas primary analytic sample (n = 1,223 ZCTA)") + base_theme,
  width = 8.5, height = 8, dpi = 200)

ggsave(file.path(PATHS$figures, "map_2_obesity.png"),
       qmap("obesity_pct", "2. Obesity prevalence", "CDC PLACES 2025 release (BRFSS 2023), adults 18+",
            labs_unit = "%"), width = 8.5, height = 8, dpi = 200)
ggsave(file.path(PATHS$figures, "map_3_diabetes.png"),
       qmap("diabetes_pct", "3. Diagnosed diabetes prevalence", "CDC PLACES 2025 release, adults 18+",
            labs_unit = "%"), width = 8.5, height = 8, dpi = 200)
ggsave(file.path(PATHS$figures, "map_4_hypertension.png"),
       qmap("bphigh_pct", "4. High blood pressure prevalence", "CDC PLACES 2025 release, adults 18+",
            labs_unit = "%"), width = 8.5, height = 8, dpi = 200)
ggsave(file.path(PATHS$figures, "map_5_ses_vulnerability.png"),
       qmap("svi_index", "5. Socioeconomic-vulnerability index",
            "ACS 2019-2023; mean z-score of poverty, low education, unemployment, minority %, low income, renters",
            pal = "div", labs_unit = "z"),
       width = 8.5, height = 8, dpi = 200)

## ---- 6. bivariate: PFAS exposure x chronic-disease burden ----
# Rank-based tertiles: robust to the zero-inflated PFAS distribution.
q3 <- function(x) {
  r <- rank(x, ties.method = "average", na.last = "keep")
  factor(ifelse(r <= sum(!is.na(x)) / 3, 1L,
         ifelse(r <= 2 * sum(!is.na(x)) / 3, 2L, 3L)), levels = 1:3)
}
d_p$burden <- rowMeans(cbind(scale(d_p$obesity_pct), scale(d_p$diabetes_pct), scale(d_p$bphigh_pct)))
d_p$bx <- q3(d_p$pfas_hazard_index); d_p$by <- q3(d_p$burden)
bipal <- c("1-1"="#e8e8e8","2-1"="#b0d5df","3-1"="#64acbe",
           "1-2"="#e4acac","2-2"="#ad9ea5","3-2"="#627f8c",
           "1-3"="#c85a5a","2-3"="#985356","3-3"="#574249")
d_p$bikey <- paste(d_p$bx, d_p$by, sep = "-")
ggsave(file.path(PATHS$figures, "map_6_pfas_vs_burden_bivariate.png"),
  ggplot() +
    geom_sf(data = tx_county, fill = "grey92", colour = "white", linewidth = .15) +
    geom_sf(data = d_p[!is.na(d_p$bikey), ], aes(fill = bikey), colour = NA) +
    geom_sf(data = tx_state, fill = NA, colour = "grey30", linewidth = .4) +
    scale_fill_manual(values = bipal, name = "PFAS (x) /\nburden (y) tertile") +
    labs(title = "6. Overlap of PFAS exposure and chronic-disease burden",
         subtitle = "Dark red = high PFAS Hazard Index AND high obesity/diabetes/hypertension burden") +
    base_theme,
  width = 9, height = 8, dpi = 200)

## ---- 7. Bexar County detail ----
bx <- dplyr::filter(d, in_bexar == 1)
ggsave(file.path(PATHS$figures, "map_7_bexar_pfas.png"),
  ggplot() +
    geom_sf(data = bexar, fill = "grey92", colour = "grey40") +
    geom_sf(data = bx, aes(fill = pfas_hazard_index), colour = "white", linewidth = .2) +
    scale_fill_viridis_c(option = "C", trans = "sqrt", name = "Hazard\nIndex", na.value = "grey85") +
    labs(title = "7. Bexar County (San Antonio) -- PFAS Hazard Index by ZCTA",
         subtitle = sprintf("%d ZCTA in Bexar; %d in primary analytic sample",
                            nrow(bx), sum(bx$analytic_primary == 1, na.rm = TRUE))) +
    base_theme,
  width = 8, height = 7, dpi = 200)

msg("10_maps.R done -- %d PNG files in figures/",
    length(list.files(PATHS$figures, pattern = "^map_.*png$")))
