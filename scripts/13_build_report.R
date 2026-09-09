# =====================================================================
# 13_build_report.R
# Assemble the one-page HTML feasibility report from the CSV outputs and
# PNG figures produced by scripts 08-12.
#   output: docs/feasibility_report.html            (self-contained, base64 images)
#           docs/feasibility_report_artifact.html   (body only, for Claude Artifact)
# =====================================================================
if (!exists("PATHS")) source(if (file.exists("scripts/00_setup.R")) "scripts/00_setup.R" else "00_setup.R")
if (!requireNamespace("base64enc", quietly = TRUE))
  install.packages("base64enc", repos = "https://cloud.r-project.org", quiet = TRUE)
library(base64enc)

b64 <- function(f) {
  p <- file.path(PATHS$figures, f)
  if (!file.exists(p)) return("")
  paste0("data:image/png;base64,", base64enc::base64encode(p))
}
rd <- function(f) tryCatch(read.csv(file.path(PATHS$outputs, f), check.names = FALSE),
                           error = function(e) data.frame())
esc <- function(x) { x <- as.character(x)
  x <- gsub("&", "&amp;", x, fixed = TRUE); x <- gsub("<", "&lt;", x, fixed = TRUE)
  gsub(">", "&gt;", x, fixed = TRUE) }
tbl <- function(df) {
  if (is.null(df) || !nrow(df)) return("<p><em>(table not available)</em></p>")
  num <- sapply(df, is.numeric)
  df[num] <- lapply(df[num], function(x) formatC(x, format = "g", digits = 4))
  h <- paste0("<tr>", paste0("<th>", esc(names(df)), "</th>", collapse = ""), "</tr>")
  b <- vapply(seq_len(nrow(df)), function(i)
    paste0("<tr>", paste0("<td>", esc(unlist(df[i, ])), "</td>", collapse = ""), "</tr>"),
    character(1))
  paste0("<table>", h, paste(b, collapse = ""), "</table>")
}
figt <- function(f, cap) paste0('<figure><img src="', b64(f), '" alt="', esc(cap),
                                '"><figcaption>', cap, '</figcaption></figure>')

# render a Markdown file to an HTML fragment (used to fold the full
# methodological memo into the single-file report)
md_to_html <- function(path) {
  if (!file.exists(path)) return("<p><em>(memo not found)</em></p>")
  txt <- readChar(path, file.info(path)$size, useBytes = TRUE)
  Encoding(txt) <- "UTF-8"
  html <- if (requireNamespace("commonmark", quietly = TRUE))
    commonmark::markdown_html(txt, extensions = TRUE, smart = TRUE)
  else if (requireNamespace("markdown", quietly = TRUE))
    markdown::mark_html(text = txt, template = FALSE)
  else paste0("<pre>", esc(txt), "</pre>")
  Encoding(html) <- "UTF-8"
  html
}

# deliverable link: clickable when the html is opened from inside the package
# (docs/feasibility_report.html), informative path label otherwise
dl <- function(path, label = NULL) {
  is_dir <- !grepl("\\.", basename(path))
  if (is.null(label)) label <- if (is_dir) paste0(path, "/") else basename(path)
  a <- paste0('<a href="../', esc(path), '">', esc(label), '</a>')
  if (is_dir) a else paste0(a, ' <span class="path">', esc(path), '</span>')
}

## ---- numbers ------------------------------------------
d <- as.data.frame(sf::st_drop_geometry(readRDS(file.path(PATHS$processed, "texas_zcta_analytical.rds"))))
p <- d[d$analytic_primary == 1, ]
n_prim  <- nrow(p)
pop_cov <- round(100 * sum(p$acs_pop_total, na.rm = TRUE) / sum(d$acs_pop_total, na.rm = TRUE), 1)
linkx   <- rd("linkage_summary_extra.csv")
match_rate <- linkx$value[linkx$metric == "ZIP->ZCTA exact match rate (TX, %)"]

L <- list(
  link  = rd("linkage_summary.csv"), bex = rd("linkage_summary_bexar.csv"),
  linkx = linkx, desc = rd("descriptives_primary.csv"),
  corr  = rd("correlations_pfas_outcomes.csv"), moran = rd("morans_i_global.csv"),
  lisa  = rd("lisa_summary.csv"), ols = rd("ols_models.csv"),
  spat  = rd("spatial_models.csv"), psm = rd("psm_feasibility.csv"),
  gwr   = rd("gwr_feasibility.csv"), svi = rd("pfas_by_svi_tertile.csv"))

FONTS <- paste0('<link rel="preconnect" href="https://fonts.googleapis.com">',
  '<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>',
  '<link rel="stylesheet" href="https://fonts.googleapis.com/css2?',
  'family=Newsreader:opsz,wght@6..72,420;6..72,560&',
  'family=IBM+Plex+Sans:wght@400;500;600&family=IBM+Plex+Mono:wght@400;500&display=swap">')

CSS <- '
/* --- tokens: light (bare :root = the default, un-stamped state) --- */
:root{
  --bg:#f6f7f8; --surface:#ffffff; --ink:#17212b; --ink-soft:#51606c;
  --rule:#dde2e6; --rule-soft:#e9edf0;
  --accent:#0d6b6b; --accent-ink:#0a4f4f;
  --band:#eef1f2;
  --warn-bg:#fbf3e6; --warn-line:#e6cfa6; --warn-ink:#7a4d05;
  --crit-bg:#fbe9e9; --crit-ink:#9a2222;
  --ok-bg:#e4f1ec; --ok-ink:#0c5f4e;
  --shadow:0 1px 2px rgba(20,30,40,.05),0 8px 24px rgba(20,30,40,.05);
}
/* --- tokens: dark (OS dark, unless an explicit light choice overrides) --- */
@media (prefers-color-scheme:dark){
  :root:not([data-theme="light"]){
    --bg:#12171c; --surface:#1a2128; --ink:#e6ebef; --ink-soft:#9aa7b1;
    --rule:#2b343d; --rule-soft:#242c34;
    --accent:#5bc6bd; --accent-ink:#8ad6cd;
    --band:#20272e;
    --warn-bg:#2c2413; --warn-line:#5a4a26; --warn-ink:#e2bd7d;
    --crit-bg:#301a1a; --crit-ink:#f0a6a6;
    --ok-bg:#16302a; --ok-ink:#7fd8c5;
    --shadow:0 1px 2px rgba(0,0,0,.3),0 10px 30px rgba(0,0,0,.35);
  }
}
:root[data-theme="dark"]{
  --bg:#12171c; --surface:#1a2128; --ink:#e6ebef; --ink-soft:#9aa7b1;
  --rule:#2b343d; --rule-soft:#242c34;
  --accent:#5bc6bd; --accent-ink:#8ad6cd;
  --band:#20272e;
  --warn-bg:#2c2413; --warn-line:#5a4a26; --warn-ink:#e2bd7d;
  --crit-bg:#301a1a; --crit-ink:#f0a6a6;
  --ok-bg:#16302a; --ok-ink:#7fd8c5;
  --shadow:0 1px 2px rgba(0,0,0,.3),0 10px 30px rgba(0,0,0,.35);
}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--ink);
  font-family:"IBM Plex Sans",-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Helvetica,Arial,sans-serif;
  font-size:15px;line-height:1.62;-webkit-font-smoothing:antialiased}
.wrap{max-width:1060px;margin:0 auto;padding:52px 24px 96px}
h1{font-family:"Newsreader",Georgia,"Times New Roman",serif;font-weight:560;
  font-size:32px;line-height:1.18;letter-spacing:-.01em;margin:0 0 10px;text-wrap:balance}
h2{font-family:"Newsreader",Georgia,serif;font-weight:560;font-size:22px;letter-spacing:-.005em;
  margin:52px 0 14px;padding-top:16px;border-top:1px solid var(--rule);text-wrap:balance}
h3{font-family:"IBM Plex Mono","SF Mono",ui-monospace,Menlo,monospace;font-weight:500;
  font-size:12px;margin:26px 0 8px;color:var(--accent-ink);text-transform:uppercase;letter-spacing:.09em}
p{margin:10px 0;max-width:74ch}
.sub{color:var(--ink-soft);margin:0 0 26px;font-size:14px;max-width:none}
.kpis{display:grid;grid-template-columns:repeat(auto-fit,minmax(158px,1fr));gap:1px;
  background:var(--rule);border:1px solid var(--rule);border-radius:12px;overflow:hidden;margin:26px 0}
.kpi{background:var(--surface);padding:16px 16px 14px}
.kpi .n{font-family:"Newsreader",Georgia,serif;font-size:26px;font-weight:560;color:var(--accent-ink);
  font-variant-numeric:tabular-nums;line-height:1}
.kpi .l{font-size:11.5px;color:var(--ink-soft);margin-top:6px;line-height:1.4}
table{border-collapse:collapse;width:100%;margin:14px 0;font-size:12.5px;
  font-variant-numeric:tabular-nums;background:var(--surface);
  border:1px solid var(--rule);border-radius:10px;overflow:hidden}
th,td{border-bottom:1px solid var(--rule-soft);border-right:1px solid var(--rule-soft);
  padding:7px 10px;text-align:left;vertical-align:top}
tr td:last-child,tr th:last-child{border-right:0}
tbody tr:last-child td{border-bottom:0}
th{background:var(--band);font-weight:600;font-size:11.5px;letter-spacing:.02em;
  color:var(--ink-soft);text-transform:uppercase}
figure{margin:20px 0;background:var(--surface);border:1px solid var(--rule);
  border-radius:12px;padding:12px;box-shadow:var(--shadow)}
figure img{width:100%;height:auto;border-radius:6px;display:block;background:#fff}
figcaption{font-size:12px;color:var(--ink-soft);margin-top:9px;line-height:1.5}
.grid2{display:grid;grid-template-columns:1fr 1fr;gap:18px;align-items:start}
@media(max-width:860px){.grid2{grid-template-columns:1fr}}
.callout{background:var(--warn-bg);border:1px solid var(--warn-line);
  border-left:3px solid var(--warn-ink);padding:14px 18px;border-radius:10px;
  margin:18px 0;font-size:13.5px;color:var(--ink)}
.callout strong{color:var(--warn-ink)}
.verdict{display:inline-block;font-family:"IBM Plex Mono",monospace;font-size:10.5px;
  font-weight:500;padding:3px 9px;border-radius:5px;margin-left:7px;vertical-align:2px;
  text-transform:uppercase;letter-spacing:.06em}
.ok{background:var(--ok-bg);color:var(--ok-ink)}
.warnb{background:var(--warn-bg);color:var(--warn-ink)}
.no{background:var(--crit-bg);color:var(--crit-ink)}
code{font-family:"IBM Plex Mono",ui-monospace,Menlo,monospace;background:var(--band);
  padding:1.5px 5px;border-radius:4px;font-size:12px}
ul,ol{margin:10px 0;padding-left:22px;max-width:74ch}li{margin:5px 0}
.foot{color:var(--ink-soft);font-size:12px;margin-top:56px;border-top:1px solid var(--rule);
  padding-top:16px;line-height:1.7}
a{color:var(--accent-ink);text-decoration:none;border-bottom:1px solid var(--rule)}
a:hover{border-bottom-color:var(--accent)}
.decisions{background:var(--ok-bg);border:1px solid var(--rule);border-left:3px solid var(--ok-ink);
  padding:16px 20px 6px;border-radius:10px;margin:20px 0;font-size:13.5px}
.decisions strong.hd{color:var(--ok-ink);display:block;margin-bottom:4px}
.decisions ol{max-width:none;padding-left:20px}
.chain{font-family:"IBM Plex Mono",monospace;font-size:12px;background:var(--band);
  border:1px solid var(--rule);border-radius:8px;padding:12px 14px;margin:14px 0;
  overflow-x:auto;white-space:nowrap;color:var(--ink)}
.manifest td:first-child{white-space:normal;min-width:150px}
.manifest code{font-size:11px;white-space:nowrap}
.manifest .path{color:var(--ink-soft);font-size:11px}
.plan{opacity:.7}
.tag{display:inline-block;font-family:"IBM Plex Mono",monospace;font-size:10px;font-weight:500;
  padding:2px 7px;border-radius:4px;text-transform:uppercase;letter-spacing:.05em;vertical-align:1px}
.tag.done{background:var(--ok-bg);color:var(--ok-ink)}
.tag.next{background:var(--warn-bg);color:var(--warn-ink)}
.tag.later{background:var(--band);color:var(--ink-soft)}
/* --- folded-in methodological memo (rendered from the .md) --- */
.memo{background:var(--surface);border:1px solid var(--rule);border-radius:12px;
  padding:26px 30px;margin-top:16px;box-shadow:var(--shadow)}
.memo h1{font-size:20px;margin:0 0 6px}
.memo h2{font-size:16px;margin:26px 0 8px;padding-top:14px;border-top:1px solid var(--rule-soft)}
.memo h2:first-of-type{border-top:0;padding-top:0}
.memo h3{font-family:"Newsreader",Georgia,serif;text-transform:none;letter-spacing:0;
  font-size:14px;font-weight:560;color:var(--ink);margin:16px 0 6px}
.memo p,.memo li{font-size:13.5px}
.memo blockquote{margin:14px 0;padding:10px 16px;border-left:3px solid var(--accent);
  background:var(--band);border-radius:0 8px 8px 0;color:var(--ink)}
.memo blockquote p{margin:4px 0}
.memo pre{background:var(--band);padding:12px 14px;border-radius:8px;overflow-x:auto;
  font-size:12px;line-height:1.5}
.memo table{font-size:12px;margin:12px 0}
.memo hr{border:0;border-top:1px solid var(--rule);margin:22px 0}
.memo code{font-size:11.5px}
'

## ---- assemble body in parts --------------------------
P <- c()
add <- function(...) P <<- c(P, paste0(...))

add('<div class="wrap">')
add('<h1>PFAS Drinking-Water Exposure &amp; Obesity-Related Health Outcomes<br>Feasibility Package &mdash; Texas</h1>')
add('<p class="sub">Phase 1: data feasibility &amp; integration &nbsp;|&nbsp; unit = ZIP Code Tabulation Area (ZCTA, 2020) &nbsp;|&nbsp; built ',
    format(Sys.Date()), ' &nbsp;|&nbsp; reproduce with <code>Rscript scripts/run_all.R</code></p>')
add('<p class="sub">This document is the complete record of Phase&nbsp;1: what data exist and how they were ',
    'obtained (&sect;A&ndash;B), how they were integrated (&sect;C&ndash;D), what the exploratory analysis shows ',
    '(&sect;E&ndash;F), the feasibility verdicts and every judgement call made along the way (&sect;B, &sect;G), ',
    'the proposed next-phase modelling framework (&sect;H), the full methodological memo (&sect;I), ',
    'and links to every file in the package (below). Later phases are appended to the phase log at the end.</p>')

add('<div class="callout"><strong>Interpretation guard-rail.</strong> UCMR&nbsp;5 measures PFAS in ',
    '<em>public drinking-water systems</em>. Every measure here is a <strong>community-level ',
    'environmental exposure proxy</strong>, not an individual exposure or dose. All associations are ',
    '<strong>ecological and cross-sectional</strong>; no causal claim is made.</div>')

add('<div class="kpis">',
    '<div class="kpi"><div class="n">1,154</div><div class="l">Texas UCMR&nbsp;5 public water systems</div></div>',
    '<div class="kpi"><div class="n">622</div><div class="l">TX systems with &ge;1 PFAS detection</div></div>',
    '<div class="kpi"><div class="n">', match_rate, '%</div><div class="l">ZIP&rarr;ZCTA exact-match rate</div></div>',
    '<div class="kpi"><div class="n">', format(n_prim, big.mark = ","), '</div><div class="l">ZCTAs in primary analytic sample</div></div>',
    '<div class="kpi"><div class="n">', pop_cov, '%</div><div class="l">of TX ZCTA population covered</div></div>',
    '<div class="kpi"><div class="n">19</div><div class="l">ZCTAs with an EPA MCL / HI exceedance</div></div>',
    '</div>')

add('<h2>Deliverables in this package</h2>',
    '<p>Links resolve when this file is opened from inside the package folder ',
    '(<code>docs/feasibility_report.html</code>); the grey path is shown either way. ',
    'Everything below is also reproducible from raw data with ',
    '<code>bash scripts/download_raw.sh &amp;&amp; Rscript scripts/run_all.R</code>.</p>',
    '<table class="manifest"><tr><th>Deliverable (email &sect;12)</th><th>File(s)</th></tr>',
    '<tr><td><strong>A.</strong> Data inventory</td><td>', dl("docs/data_inventory.csv"), '</td></tr>',
    '<tr><td><strong>B.</strong> Integrated Texas dataset</td><td>',
      dl("data/processed/texas_zcta_analytical.gpkg"), '<br>',
      '<span class="path">data/processed/texas_zcta_analytical.{csv,rds} &middot; bexar_zcta_analytical.{gpkg,csv,rds}</span></td></tr>',
    '<tr><td><strong>C.</strong> Data-linkage summary</td><td>',
      dl("outputs/linkage_summary.csv"), '<br>',
      '<span class="path">outputs/linkage_summary_bexar.csv &middot; linkage_summary_extra.csv &middot; linkage_zip_zcta_notes.csv</span></td></tr>',
    '<tr><td><strong>D.</strong> Preliminary figures (17 PNG, 200&nbsp;dpi)</td><td>',
      dl("figures", "figures/"), '<br><span class="path">map_1&hellip;map_7, map_1b, 5&times; map_lisa_*, fig_pfas_outcome_scatter, fig_psm_overlap, fig_gwr_pfas_coef, fig_corr_heatmap</span></td></tr>',
    '<tr><td><strong>E.</strong> Preliminary analysis (12 tables)</td><td>',
      dl("outputs", "outputs/"), '<br><span class="path">descriptives_primary &middot; correlations_pfas_outcomes &middot; correlation_matrix_full &middot; morans_i_global &middot; lisa_summary &middot; ols_models &middot; spatial_models &middot; psm_feasibility &middot; psm_balance_table &middot; gwr_feasibility &middot; pfas_by_svi_tertile</span></td></tr>',
    '<tr><td><strong>F.</strong> Methodological memo (2&ndash;3 pp)</td><td>',
      dl("docs/methodological_memo.md"), ' &mdash; also embedded verbatim in &sect;I below</td></tr>',
    '<tr><td>Proposed Phase 2/3 modelling note</td><td>',
      dl("docs/methodological_note_spatial_bayesian.md"), ' &mdash; summarised in &sect;H</td></tr>',
    '<tr><td>Data dictionary</td><td>', dl("docs/data_dictionary.csv"), '</td></tr>',
    '<tr><td>Reproducibility</td><td>', dl("README.md"), '<br>',
      '<span class="path">scripts/download_raw.sh &middot; scripts/run_all.R &middot; scripts/00_setup.R &hellip; 13_build_report.R</span></td></tr>',
    '<tr><td>This report</td><td>', dl("docs/feasibility_report.html"), '</td></tr>',
    '</table>')

add('<h2>A &middot; Data inventory</h2>',
    '<p>Five public sources, all key-free. Full detail incl. URLs in <code>docs/data_inventory.csv</code>.</p>',
    '<table><tr><th>Dataset</th><th>Provider</th><th>Version used</th><th>Scale</th><th>Role</th></tr>',
    '<tr><td>UCMR&nbsp;5 occurrence data</td><td>US EPA</td><td>2023-08 posting</td><td>Public Water System</td><td>PFAS exposure (29 compounds)</td></tr>',
    '<tr><td>SDWIS / SDWA</td><td>US EPA (Envirofacts)</td><td>retrieved 2026-09-07</td><td>PWS</td><td>Population served, county, source type</td></tr>',
    '<tr><td>PLACES ZCTA</td><td>CDC</td><td>2025 release (BRFSS 2023)</td><td>ZCTA5</td><td>Obesity, diabetes, hypertension prevalence</td></tr>',
    '<tr><td>ACS 5-year (table-based SF)</td><td>US Census</td><td>2019&ndash;2023</td><td>ZCTA5</td><td>Socioeconomic / demographic covariates</td></tr>',
    '<tr><td>Boundaries + ZCTA&harr;county relationship</td><td>US Census</td><td>2020 / 2022</td><td>ZCTA5, county</td><td>Geography, mapping, state assignment</td></tr>',
    '</table>')

add('<h2>B &middot; How this package was built</h2>')
add('<h3>Pipeline</h3>',
    '<p>Fourteen R scripts, one entry point (<code>Rscript scripts/run_all.R</code>, ~40&nbsp;s). ',
    'Raw downloads in <code>data/raw/</code> are never modified; every analytical file is rebuilt from them.</p>',
    '<div class="chain">raw public data &nbsp;&rarr;&nbsp; 01 read UCMR&thinsp;5 &nbsp;&rarr;&nbsp; 02 PFAS exposure (PWS level) ',
    '&nbsp;&rarr;&nbsp; 03 geography / ZIP&rarr;ZCTA &nbsp;&rarr;&nbsp; 04 SDWIS &nbsp;&rarr;&nbsp; 05 PLACES &nbsp;&rarr;&nbsp; 06 ACS ',
    '&nbsp;&rarr;&nbsp; 07 assemble ZCTA dataset &nbsp;&rarr;&nbsp; 08&ndash;12 linkage / descriptives / maps / spatial / models &nbsp;&rarr;&nbsp; 13 this report</div>')

add('<h3>Data acquisition &mdash; what each source actually looks like</h3>',
    '<table><tr><th>Source</th><th>How it was fetched</th><th>Key facts established before use</th></tr>',
    '<tr><td>EPA UCMR&nbsp;5 occurrence</td><td>Direct ZIP download; <code>UCMR5_All.txt</code> (319&nbsp;MB)</td>',
      '<td>~1.99&nbsp;M analyte results; 10,313 PWS nationally; 29 PFAS compounds + lithium; ',
      '<code>&lt;</code> sign = non-detect, <code>=</code> = detection; units &micro;g/L; lithium dropped (not a PFAS)</td></tr>',
    '<tr><td>UCMR&nbsp;5 ZIP list</td><td>Same ZIP; <code>UCMR5_ZIPCodes.txt</code></td>',
      '<td>PWSID&rarr;ZIP is one-to-many; this is a list of &ldquo;ZIP codes served&rdquo;, <em>not</em> a service-area boundary and <em>not</em> population-weighted</td></tr>',
    '<tr><td>CDC PLACES</td><td>Socrata API, resource <code>qnzd-25i4</code></td>',
      '<td>Current release is <strong>2025</strong> (BRFSS 2023, ACS 2019&ndash;2023, 2020 Census denominators); ZCTA level; crude prevalence only (no age-adjusted); model-based small-area estimates with CIs</td></tr>',
    '<tr><td>US Census ACS 5-year</td><td>Table-based Summary File (<code>.dat</code>, pipe-delimited); ZCTA rows filtered by <code>GEO_ID</code> prefix <code>860Z200US</code>. No API key.</td>',
      '<td>11 tables chosen (age, race/ethnicity, education, poverty, income, employment, 4 housing); aligned to <strong>ACS 2019&ndash;2023</strong> to match PLACES; suppression sentinels (&le;&minus;666666666) set to NA</td></tr>',
    '<tr><td>EPA SDWIS / SDWA</td><td>Envirofacts REST (<code>WATER_SYSTEM</code> + <code>GEOGRAPHIC_AREA</code>, TX), paged CSV</td>',
      '<td>UCMR&nbsp;5 carries no population-served / county / source-type &mdash; taken from here: <code>population_served_count</code>, <code>gw_sw_code</code>, <code>owner_type_code</code>, <code>county_served</code>; 1,154 TX UCMR&nbsp;5 systems, 100% matched</td></tr>',
    '<tr><td>Census geography</td><td>Cartographic boundaries: ZCTA GENZ2020, county/state GENZ2022; 2020 ZCTA&harr;county relationship file</td>',
      '<td>No 2022 ZCTA boundary file exists &rarr; 2020 vintage used; each ZCTA assigned to the state/county holding its largest land-area block; 689 of 1,989 TX ZCTAs straddle a county line</td></tr>',
    '</table>')

add('<h3>Scripts</h3>',
    '<table><tr><th>Script</th><th>Does</th><th>Notable method choice</th></tr>',
    '<tr><td>00_setup</td><td>Paths, config (state, non-detect rule, EPA HI thresholds), helper fns</td><td>Central config &mdash; change <code>STATE</code> and rerun to move geography</td></tr>',
    '<tr><td>01_read_ucmr5</td><td>319&nbsp;MB file &rarr; tidy analyte long table; PWS&ndash;ZIP; added data elements</td><td>29 PFAS only; non-detects kept as both 0 and MRL/2</td></tr>',
    '<tr><td>02_build_pfas_exposure</td><td>2&ndash;4 sampling batches &rarr; one PWS-level exposure row</td><td>Six alternative exposure measures (see below)</td></tr>',
    '<tr><td>03_geography</td><td>ZCTA polygons; ZCTA&rarr;state/county; ZIP&rarr;ZCTA crosswalk; match diagnostics</td><td>Exact 5-digit ZIP=ZCTA match (95.2% in TX); limitation logged to <code>linkage_zip_zcta_notes.csv</code></td></tr>',
    '<tr><td>04_read_sdwis</td><td>SDWIS &rarr; per-system population served, source, county</td><td>&mdash;</td></tr>',
    '<tr><td>05_read_places</td><td>PLACES long &rarr; wide (3 outcomes + CI widths)</td><td>CI width retained as an estimate-precision flag</td></tr>',
    '<tr><td>06_read_acs</td><td>11 ACS tables &rarr; derived covariates</td><td>Suppression sentinels &rarr; NA; conceptual (not exhaustive) variable set</td></tr>',
    '<tr><td>07_assemble_zcta_dataset</td><td>UCMR5&rarr;PWS&rarr;ZIP&rarr;ZCTA&rarr;PLACES&rarr;ACS integration</td><td>PFAS&rarr;ZCTA aggregated <strong>population-weighted</strong> across serving systems; binary measures via &ldquo;any serving system&rdquo;; SVI index built here</td></tr>',
    '<tr><td>08_linkage_summary</td><td>TX + Bexar integration funnel</td><td>Deliverable C</td></tr>',
    '<tr><td>09_descriptives</td><td>Descriptives; unadjusted &amp; SES-adjusted partial correlations; exposure by SVI tertile</td><td>&mdash;</td></tr>',
    '<tr><td>10_maps</td><td>8 choropleths + diagnostic plots</td><td>Albers equal-area; sqrt colour scale for zero-inflated PFAS; rank tertiles for bivariate map</td></tr>',
    '<tr><td>11_spatial_autocorr</td><td>Global Moran&rsquo;s I (10 vars); OLS residual Moran; LISA (5 layers); hot-spot overlap</td><td><strong>k&thinsp;=&thinsp;6 nearest-neighbour weights</strong> as primary &mdash; queen contiguity fragments on the monitored-only sample</td></tr>',
    '<tr><td>12_models</td><td>OLS (3 outcomes &times; 4 exposures; HC1 SE, VIF, partial R&sup2;); spatial SEM/SAR; PSM feasibility; GWR feasibility</td><td>No causal claims; PSM and GWR run only to test feasibility</td></tr>',
    '<tr><td>13_build_report</td><td>CSV tables + PNG figures + memo &rarr; this self-contained HTML</td><td>Images base64-embedded; memo rendered from the <code>.md</code></td></tr>',
    '</table>')

add('<h3>Variables constructed</h3>',
    '<p><strong>PFAS exposure &mdash; six measures carried, none fixed yet:</strong> ',
    '(1) any PFAS detected; (2) number of PFAS compounds detected; (3) individual compound concentrations ',
    '(PFOA, PFOS, PFHxS, PFNA, PFBS&hellip;); (4) summed concentration (non-detect = 0, plus a MRL/2 version); ',
    '(5) <strong>EPA-2024 Hazard Index</strong> &mdash; &Sigma;(concentration &divide; health-based value) for PFHxS, GenX, PFNA, PFBS &mdash; the primary mixture metric; ',
    '(6) detection frequency. Plus a regulatory <code>any_mcl_exceedance</code> flag (PFOA or PFOS mean &ge; 4&nbsp;ng/L, or HI &ge; 1). ',
    'In Texas GenX is detected in 0 systems, so the Hazard Index is driven by PFHxS and PFBS.</p>',
    '<p><strong>Outcomes:</strong> <code>obesity_pct</code>, <code>diabetes_pct</code>, <code>bphigh_pct</code> &mdash; ',
    'CDC PLACES model-based crude adult prevalence, <em>not</em> measured.</p>',
    '<p><strong>Covariates</strong> were chosen as plausible common causes of <em>both</em> PFAS exposure and ',
    'obesity-related outcomes, not by availability: median household income, poverty rate, % bachelor&rsquo;s+, ',
    'unemployment, % non-Hispanic white / Black / Hispanic, median age &amp; % 65+, population density, ',
    '% mobile homes, median rent &amp; home value, % renter-occupied. ',
    'The <code>svi_index</code> is the mean of six z-scores (income sign-reversed); higher = more vulnerable.</p>')

add('<div class="decisions"><strong class="hd">Decisions made in Phase 1 (provisional, open to revision)</strong>',
    '<ol>',
    '<li><strong>Geographic unit = ZCTA</strong>, linked by exact 5-digit ZIP = ZCTA (95.2% match in TX). ',
    'A water system&rsquo;s &ldquo;ZIP codes served&rdquo; is treated as an approximate spatial allocation, not a service area.</li>',
    '<li><strong>Non-detects = 0</strong> in the main analysis; an <code>_ndhalf</code> (MRL/2) version of every ',
    'concentration measure is carried for sensitivity.</li>',
    '<li><strong>PFAS &rarr; ZCTA aggregation is population-weighted</strong> across all systems serving the ZCTA, ',
    'using each system&rsquo;s <em>total</em> SDWIS population served (SDWIS does not publish the population served <em>within</em> a given ZCTA).</li>',
    '<li><strong>Mixture metric = EPA-2024 Hazard Index.</strong> Note GenX = 0 detections in TX, so the index ',
    'reflects PFHxS + PFBS mostly.</li>',
    '<li><strong>ACS aligned to 2019&ndash;2023</strong> to match the PLACES 2025 release input years.</li>',
    '<li><strong>Spatial weights = k&thinsp;=&thinsp;6 nearest neighbours</strong> (not queen contiguity), because the ',
    'analytic sample is only the monitored ZCTAs and contiguity fragments into ~28 sub-graphs. Queen weights are run as a sensitivity check.</li>',
    '<li><strong>No single exposure definition chosen.</strong> All six measures are carried into every downstream step, to be narrowed in the modelling phase.</li>',
    '</ol></div>')

add('<h2>C &middot; Integrated Texas dataset</h2>',
    '<p>Chain: <code>UCMR5 PFAS &rarr; PWS &rarr; ZIP served &rarr; ZCTA &rarr; PLACES &rarr; ACS</code>. ',
    'The integrated file is <code>data/processed/texas_zcta_analytical.gpkg</code> (1,989 Texas ZCTAs; ',
    format(n_prim, big.mark = ","), ' in the primary analytic sample with PFAS + health + ACS + population &ge;500). ',
    'Six alternative PFAS exposure measures are carried &mdash; any detection; number of compounds detected; ',
    'individual compound concentrations; summed concentration; EPA-2024 Hazard Index; detection frequency ',
    '&mdash; no single definition is fixed yet.</p>')

add('<h2>D &middot; Data-linkage summary</h2>',
    '<div class="grid2"><div><h3>Texas funnel</h3>', tbl(L$link[, c("step", "n")]), '</div>',
    '<div><h3>Bexar County / San Antonio</h3>', tbl(L$bex[, c("step", "n")]),
    '<h3>Linkage facts</h3>', tbl(L$linkx), '</div></div>')
add('<div class="callout"><strong>Main limitation.</strong> A water system&rsquo;s &ldquo;ZIP codes served&rdquo; ',
    'list is not a service-area boundary and is not population-weighted; ZIP&rarr;ZCTA is an approximation ',
    '(', match_rate, '% exact match); the PWS&harr;ZCTA relation is many-to-many (670 primary-sample ZCTAs ',
    'served by one system, 553 by more, up to 19). Exposure is an <em>approximate spatial allocation</em>, ',
    'not a measured residential concentration.</div>')

add('<h2>E &middot; Preliminary maps</h2>')
add(figt("map_1_pfas_hazard_index.png", "1. PFAS exposure &mdash; EPA Hazard Index (population-weighted, ZCTA)"))
add(figt("map_1b_pfas_detection_status.png", "1b. PFAS detection status: none / detected / MCL&ndash;HI exceedance"))
add('<div class="grid2">',
    figt("map_2_obesity.png", "2. Obesity prevalence (CDC PLACES 2025)"),
    figt("map_3_diabetes.png", "3. Diagnosed diabetes prevalence"), '</div>')
add('<div class="grid2">',
    figt("map_4_hypertension.png", "4. High blood pressure prevalence"),
    figt("map_5_ses_vulnerability.png", "5. Socioeconomic-vulnerability index (ACS 2019&ndash;2023)"), '</div>')
add(figt("map_6_pfas_vs_burden_bivariate.png",
         "6. Bivariate &mdash; PFAS Hazard Index (x) vs mean chronic-disease burden (y), tertiles"))
add('<div class="grid2">',
    figt("fig_pfas_outcome_scatter.png", "PFAS Hazard Index vs prevalence, unadjusted (n = 1,223 ZCTA)"),
    figt("map_7_bexar_pfas.png", "7. Bexar County / San Antonio &mdash; PFAS Hazard Index by ZCTA"), '</div>')

add('<h2>F &middot; Preliminary analysis</h2>')
add('<h3>Descriptive statistics (primary sample, n = ', format(n_prim, big.mark = ","), ')</h3>',
    tbl(L$desc[, c("label", "n", "mean", "sd", "median", "min", "max", "pct_missing")]))
add('<h3>PFAS exposure &times; outcome correlations</h3>',
    '<p>Unadjusted correlations are <strong>negative</strong> for all three outcomes; after adjusting for ',
    'income, education, race/ethnicity, age and population density the partial associations collapse toward zero.</p>',
    tbl(L$corr))
add('<h3>PFAS exposure &amp; outcomes by socioeconomic-vulnerability tertile</h3>',
    '<p>PFAS exposure is <em>not</em> strongly patterned by socioeconomic vulnerability in Texas &mdash; ',
    'detection rate and Hazard Index are similar (slightly higher) in the least-vulnerable tertile.</p>',
    tbl(L$svi))
add('<h3>Spatial autocorrelation &mdash; Global Moran&rsquo;s I (k = 6 nearest-neighbour weights)</h3>',
    tbl(L$moran),
    '<p>Na&iuml;ve OLS for obesity has residual Moran&rsquo;s I &asymp; 0.49 (p &asymp; 10<sup>&minus;252</sup>) ',
    '&mdash; non-spatial regression is not defensible.</p>')
add('<h3>LISA cluster counts</h3>', tbl(L$lisa),
    '<p><strong>PFAS hot-spots and disease hot-spots barely overlap:</strong> of 105 PFAS &ldquo;High-High&rdquo; ',
    'ZCTAs, 3 coincide with an obesity hot-spot and 0 with a diabetes or hypertension hot-spot. No ZCTA is ',
    'simultaneously High-High on PFAS, a disease, and SES vulnerability.</p>',
    '<div class="grid2">',
    figt("map_lisa_pfas_hazard_index.png", "LISA clusters &mdash; PFAS Hazard Index"),
    figt("map_lisa_obesity_pct.png", "LISA clusters &mdash; obesity"), '</div>')
add('<h3>Baseline ecological regressions (HC1 SE; covariate-adjusted)</h3>',
    tbl(L$ols[, c("outcome", "exposure", "beta", "se_hc1", "std_beta", "p_value", "partial_r2")]),
    '<p>Where &ldquo;significant&rdquo; (diabetes, hypertension) the standardised effect is tiny ',
    '(|&beta;| &lt; 0.08 SD) and negative; PFAS adds &lt; 0.5% to explained variance. Max VIF &asymp; 5.6.</p>')
add('<h3>Spatial regression (exposure = log(1 + Hazard Index))</h3>', tbl(L$spat))

add('<h2>G &middot; Feasibility verdicts at a glance</h2>')
add('<h3>Texas sample for spatial modelling <span class="verdict ok">FEASIBLE (size)</span>',
    '<span class="verdict warnb">GAPPY (support)</span></h3><ul>',
    '<li>', format(n_prim, big.mark = ","), ' ZCTAs / ', pop_cov, '% of state ZCTA population &mdash; ample for global and spatial regression.</li>',
    '<li>Sample limited to monitored ZCTAs &rarr; queen contiguity fragments (~28 sub-graphs); pipeline uses k = 6 nearest-neighbour weights as primary.</li>',
    '<li>Only 19 ZCTAs with a regulatory exceedance, and PFAS / disease clusters are spatially separated &rarr; limited exposure contrast within one state.</li></ul>')
add('<h3>Propensity-score analysis <span class="verdict warnb">FEASIBLE BUT FRAGILE</span></h3>', tbl(L$psm),
    figt("fig_psm_overlap.png",
         "Propensity-score overlap: usable common support (~81%) but treated and control ZCTAs are systematically different places; IPW leaves max |SMD| &asymp; 0.47."))
add('<h3>GWR / MGWR <span class="verdict warnb">MGWR ONLY</span> <span class="verdict no">not global GWR</span></h3>',
    tbl(L$gwr),
    figt("fig_gwr_pfas_coef.png",
         "Local GWR coefficient for log(1+Hazard Index)&rarr;obesity. The selected bandwidth (~14 neighbours) over-fits: local slopes span &minus;176 to +251. Use spatial-error/lag models as the workhorse and MGWR as the heterogeneity probe."))

# ---- H: proposed next-phase modelling framework ---------------------
add('<h2>H &middot; Proposed next-phase modelling framework</h2>',
    '<p class="sub">Summary of <code>docs/methodological_note_spatial_bayesian.md</code>. ',
    'The Phase&nbsp;1 feasibility verdicts in &sect;G stand and feed straight into this &mdash; nothing here replaces them.</p>')

add('<h3>What it is</h3>',
    '<p>A <strong>Bayesian hierarchical spatial model used as a confounding-sensitivity analysis</strong> &mdash; ',
    'a structured way to watch the PFAS coefficient move as measured-confounder, spatial-confounder and uncertainty ',
    'assumptions are layered in. A Bayesian spatial regression is <em>not</em> automatically a causal model: a causal ',
    'reading needs a pre-specified DAG and identification assumptions this ecological design can probe but not satisfy. ',
    'Honest label: <strong>spatial confounding-sensitivity analysis</strong>, not &ldquo;Spatial Bayesian Causal Model&rdquo;.</p>')

add('<h3>The motivating puzzle</h3>',
    '<p>PFAS coefficient for <strong>obesity</strong>, exposure = log(1&nbsp;+&nbsp;Hazard&nbsp;Index) ',
    '(<code>outputs/spatial_models.csv</code>):</p>',
    '<table><tr><th>Model</th><th>PFAS coefficient</th><th>Note</th></tr>',
    '<tr><td>Adjusted OLS</td><td>&minus;0.62</td><td>p &asymp; 0.14, std &beta; &asymp; &minus;0.018 &mdash; <strong>already ~null</strong></td></tr>',
    '<tr><td>Spatial error (&lambda; &asymp; 0.79)</td><td>+0.59</td><td>sign reversal</td></tr>',
    '<tr><td>Spatial lag (&rho; &asymp; 0.41)</td><td>+0.30 raw / <strong>+0.51 total impact</strong></td><td>compare total impacts, not raw &beta;</td></tr>',
    '</table>',
    '<p>The reversal is <strong>not</strong> consistent: diabetes (OLS &minus;1.13 &rarr; SEM &minus;0.79) and ',
    'hypertension (&minus;2.89 &rarr; &minus;2.16) stay negative through the spatial models. So <strong>obesity is a ',
    'weak target</strong> (its association is ~zero to begin with) and <strong>diabetes and hypertension are the real ',
    'puzzle</strong> &mdash; the sensitivity analysis should be built around them. This is not evidence the &ldquo;true&rdquo; ',
    'effect is positive; it is evidence the estimate is sensitive to spatial specification.</p>')

add('<div class="callout"><strong>Identification is fragile &mdash; state this before, not after, the modelling.</strong> ',
    'The PFAS surface is <em>more</em> spatially autocorrelated than the outcomes (Global Moran&rsquo;s I 0.69&ndash;0.81 ',
    'for PFAS vs 0.55&ndash;0.58 for obesity/diabetes/hypertension). An exposure that smooth is nearly collinear with any ',
    'flexible spatial random effect, so the PFAS effect is identified only by the <em>spatially unstructured</em> part of ',
    'exposure &mdash; which, with 96% non-detects and a PWS&rarr;ZIP&rarr;ZCTA copy-allocation, is largely noise and ',
    'construction artefact. The coefficient will lean on the smoothness prior. Every estimate must ship with an ',
    'identification-diagnostic panel (prior sensitivity; spatial-scale comparison of exposure vs the random effect; ',
    '<code>Spatial+</code>/spectral and restricted-spatial-regression contrasts).</div>')

add('<h3>Model sequence (extends &sect;F&ndash;G, does not replace it)</h3>',
    '<table><tr><th>Model</th><th>Specification</th><th>Purpose</th></tr>',
    '<tr><td>M0</td><td><em>Y</em> = &beta;<sub>0</sub> + &beta;<sub>1</sub> <em>A</em></td><td>crude ecological association</td></tr>',
    '<tr><td>M1</td><td>+ DAG-specified confounders <em>X&beta;</em></td><td>how much of M0 is measured-confounder difference</td></tr>',
    '<tr><td>M2</td><td>conventional spatial &mdash; SEM (primary), SAR total impacts for contrast</td>',
      '<td>sensitivity of the coefficient &amp; residual dependence to spatial structure <span class="verdict ok">done in Phase 1</span></td></tr>',
    '<tr><td>M3</td><td>Bayesian joint spatial exposure&ndash;outcome model: correlated latent fields <em>U<sup>A</sup></em>, ',
      '<em>U<sup>Y</sup></em>; PLACES measurement-error layer; flexible <em>f(A)</em>; BYM2/CAR prior</td>',
      '<td><strong>the confounding-sensitivity step</strong> &mdash; PFAS effect after measured + latent spatial confounding, full posterior</td></tr>',
    '<tr><td>M4 <em>(optional)</em></td><td>spatially varying effect &tau;(s)</td>',
      '<td>does the community-level effect differ across the region? Causal analogue of MGWR, <em>even more weakly identified</em> than the global effect</td></tr>',
    '</table>',
    '<p>The informative output is the <strong>trajectory</strong> of the coefficient across M0&rarr;M3 per outcome, with its uncertainty &mdash; not any single number.</p>')

add('<h3>Estimand</h3>',
    '<p>A <strong>community-level</strong> dose-response <em>m(a)</em> = E[<em>Y(a)</em>] via g-computation over the ',
    'covariate distribution, contrasting <strong>policy-relevant</strong> exposure levels (e.g. HI&nbsp;=&nbsp;0 vs&nbsp;1, ',
    'or the 10th vs 90th percentile) rather than an arbitrary quartile. It needs a flexible term in <em>A</em> ',
    '(spline / Gaussian process), otherwise the &ldquo;dose-response&rdquo; is just a constant slope. This is the effect ',
    'of changing a <em>community&rsquo;s water</em> &mdash; subject to ecological bias, and not a substitute for the ',
    'planned individual-level biomarker study.</p>')

add('<h3>Reading the trajectory</h3>',
    '<table><tr><th>Pattern</th><th>Reading</th><th>Caution</th></tr>',
    '<tr><td>Negative &rarr; 0</td><td>inverse association explained by measured + spatial confounding</td>',
      '<td>check it is not just variance inflation from the spatial term</td></tr>',
    '<tr><td>Negative &rarr; sign flip</td><td><em>possible</em> negative spatial confounding</td>',
      '<td>a sign flip is also a classic artefact of spatial-confounding bias / weak identification &mdash; red flag, not a finding, until the diagnostics pass</td></tr>',
    '<tr><td>Negative, stable</td><td>spatial confounding alone does not explain it</td>',
      '<td>shift focus to exposure measurement error, monitoring selection, temporal / ecological mismatch</td></tr>',
    '</table>',
    '<p>The goal is <strong>not</strong> to push the coefficient toward any value, but to understand why it does or does not move.</p>')

add('<h3>What it can and cannot do</h3>',
    '<p><strong>Can help:</strong> measured-confounder adjustment; latent <em>spatial</em> confounding; spatial ',
    'autocorrelation; continuous exposure + dose-response; posterior uncertainty (incl. PLACES outcome error); ',
    'spatially varying effects; left-censored non-detects.</p>',
    '<p><strong>Cannot solve:</strong> unmeasured <em>non-spatial</em> confounding; a wrong DAG; exposure ',
    'misclassification from PWS&rarr;ZCTA allocation; incomplete rural monitoring; ecological bias; the temporal mismatch ',
    'between recent tap-water PFAS and long-term disease; missing individual exposure histories; interference across systems.</p>',
    '<p>Two checks this note adds as <strong>primary</strong>, not optional: a <strong>formal unmeasured-confounding ',
    'sensitivity analysis</strong> (E-value; Bayesian bias priors) and <strong>negative-control outcomes / exposures</strong>.</p>')

add('<div class="callout"><strong>Binding constraint &mdash; and the highest-value next step.</strong> ',
    'The PWS&rarr;ZIP&rarr;ZCTA step is <strong>shared, spatially structured (Berkson-type) measurement error</strong>: ',
    'one PWS value copied to many ZCTAs. It induces spatial autocorrelation in the exposure by construction and can bias ',
    'the effect in either direction. Modelling it explicitly needs <strong>external validation data</strong> &mdash; a ',
    'population/area-weighted ZIP&harr;ZCTA crosswalk (HUD USPS / UDS Mapper) or PWS service-area GIS. Until that exists, ',
    'improving the crosswalk outranks model sophistication.</div>')

add('<p>Full write-up &mdash; model equations, software (<code>R-INLA</code>, <code>CARBayes</code>, <code>brms</code>), ',
    'sensitivity plan and references: ', dl("docs/methodological_note_spatial_bayesian.md"), '.</p>')

add('<h2>I &middot; Full methodological memo</h2>',
    '<p class="sub">The complete Phase&nbsp;1 write-up (identical to <code>docs/methodological_memo.md</code>): ',
    'data availability, linkage method, all data-quality limitations, sample-sufficiency assessment, ',
    'PSM and GWR feasibility, and recommendations for the next phase.</p>',
    '<div class="memo">', md_to_html(file.path(PATHS$docs, "methodological_memo.md")), '</div>')

add('<h2>Phase log &amp; upcoming deliverables</h2>',
    '<p>This report is updated at the end of each phase; new outputs are linked here as they are produced.</p>',
    '<table class="manifest"><tr><th>Phase</th><th>Scope</th><th>Deliverables</th></tr>',
    '<tr><td><span class="tag done">done</span> 1</td>',
      '<td>Data feasibility &amp; integration &mdash; Texas testbed; can EPA PFAS be linked to CDC PLACES + ACS at ZCTA scale, and is the sample sufficient for spatial modelling?</td>',
      '<td>This package: ', dl("docs/feasibility_report.html", "report"), ', ',
      dl("docs/methodological_memo.md", "memo"), ', ', dl("data/processed/texas_zcta_analytical.gpkg", "integrated dataset"),
      ', ', dl("outputs", "12 analysis tables"), ', ', dl("figures", "17 figures"), '</td></tr>',
    '<tr class="plan"><td><span class="tag next">next</span> 2</td>',
      '<td>Finalise scope &amp; exposure definitions, then extend the identical pipeline beyond Texas ',
      '(EPA Region&nbsp;6 / the South / national) for exposure contrast and spatial support; ',
      'population/area-weighted ZIP&rarr;ZCTA crosswalk; pre-specified covariate DAG; left-censored non-detect handling.</td>',
      '<td><span class="path">to come: multi-state integrated dataset; revised linkage sensitivity; updated feasibility verdicts</span></td></tr>',
    '<tr class="plan"><td><span class="tag next">next</span> 3</td>',
      '<td>Spatial Bayesian confounding-sensitivity analysis (&sect;H): causal DAG &rarr; M0&ndash;M3 coefficient trajectory ',
      'per outcome (focus: diabetes, hypertension) &rarr; identification diagnostics &rarr; E-value / negative-control ',
      'sensitivity; PSM/GPS and MGWR as triangulation; residual autocorrelation reported for every model.</td>',
      '<td>framework: ', dl("docs/methodological_note_spatial_bayesian.md", "modelling note"), '<br>',
      '<span class="path">to come: M0&ndash;M3 trajectory tables; posterior dose-response; local-effect maps; vulnerability-overlap typology</span></td></tr>',
    '<tr class="plan"><td><span class="tag later">later</span> 4</td>',
      '<td>Individual-level study: link survey + biological samples (serum PFAS/MNPs, BMI, A1c, blood pressure, diet) to the community-exposure framework built here.</td>',
      '<td><span class="path">separate protocol</span></td></tr>',
    '</table>')

add('<p class="foot">Phase&nbsp;1 feasibility record &mdash; built ', format(Sys.Date()),
    ' from public data only (EPA UCMR&nbsp;5 &amp; SDWIS, CDC PLACES, US Census ACS &amp; TIGER). ',
    'Rebuild from scratch: <code>bash scripts/download_raw.sh</code> then <code>Rscript scripts/run_all.R</code>. ',
    'Raw downloads in <code>data/raw/</code> are never modified. This HTML is self-contained &mdash; every ',
    'figure and the full memo are embedded; the deliverable links resolve against the package folder. ',
    'Ecological, cross-sectional analysis &mdash; no causal claim.</p>')
add('</div>')

BODY <- paste(P, collapse = "\n")
TITLE <- "<title>PFAS &amp; Health Feasibility, Texas</title>"

wr_utf8 <- function(text, path)
  writeBin(charToRaw(enc2utf8(text)), path)

wr_utf8(paste0('<!doctype html><html lang="en"><head><meta charset="utf-8">',
  '<meta name="viewport" content="width=device-width,initial-scale=1">', TITLE, FONTS,
  '<style>', CSS, '</style></head><body>', BODY, '</body></html>'),
  file.path(PATHS$docs, "feasibility_report.html"))

# body-only variant (no doctype/html/head/body) for publishing as a Claude Artifact;
# written next to the standalone file only when BUILD_ARTIFACT_HTML=1
if (nzchar(Sys.getenv("BUILD_ARTIFACT_HTML"))) {
  wr_utf8(paste0(TITLE, FONTS, '<style>', CSS, '</style>', BODY),
          file.path(PATHS$docs, "feasibility_report_artifact.html"))
}

msg("13_build_report.R done -- docs/feasibility_report.html (%.1f MB)",
    file.size(file.path(PATHS$docs, "feasibility_report.html")) / 1e6)
