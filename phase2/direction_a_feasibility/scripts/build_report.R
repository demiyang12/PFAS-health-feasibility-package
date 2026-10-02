# =====================================================================
# build_report.R
# Assemble the self-contained Direction A narrative report from everything
# built across A1, A2, A3a, A3b, and A3c. Same design system as the Phase 1
# and Phase 2 reports (scripts/13_build_report.R, phase2/scripts/build_report.R)
# for visual continuity.
#
# Run from the project root:  Rscript phase2/direction_a_feasibility/scripts/build_report.R
#   output: phase2/direction_a_feasibility/docs/direction_a_report.html
#           (self-contained, base64 images; kept inside this branch's own
#           docs/ folder -- not copied into the root docs/, which is Phase 1's
#           deployed GitHub Pages content and is left untouched)
# =====================================================================
if (!exists("DA_PATHS")) source(if (file.exists("phase2/direction_a_feasibility/scripts/00_setup.R"))
  "phase2/direction_a_feasibility/scripts/00_setup.R" else "00_setup.R")
if (!requireNamespace("base64enc", quietly = TRUE))
  install.packages("base64enc", repos = "https://cloud.r-project.org", quiet = TRUE)
if (!requireNamespace("commonmark", quietly = TRUE))
  install.packages("commonmark", repos = "https://cloud.r-project.org", quiet = TRUE)
library(base64enc)

# ---- helpers (identical to the Phase 1 / Phase 2 report builders) -------
b64 <- function(f) {
  p <- file.path(DA_PATHS$figures, f)
  if (!file.exists(p)) return("")
  paste0("data:image/png;base64,", base64enc::base64encode(p))
}
rd <- function(f) tryCatch(read.csv(file.path(DA_PATHS$outputs, f), check.names = FALSE, stringsAsFactors = FALSE),
                           error = function(e) data.frame())
esc <- function(x) { x <- as.character(x)
  x <- gsub("&", "&amp;", x, fixed = TRUE); x <- gsub("<", "&lt;", x, fixed = TRUE)
  gsub(">", "&gt;", x, fixed = TRUE) }
tbl <- function(df, max_rows = NULL) {
  if (is.null(df) || !nrow(df)) return("<p><em>(table not available)</em></p>")
  if (!is.null(max_rows) && nrow(df) > max_rows) df <- df[seq_len(max_rows), ]
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
md_to_html <- function(path) {
  if (!file.exists(path)) return("<p><em>(file not found)</em></p>")
  txt <- readChar(path, file.info(path)$size, useBytes = TRUE)
  Encoding(txt) <- "UTF-8"
  html <- if (requireNamespace("commonmark", quietly = TRUE))
    commonmark::markdown_html(txt, extensions = TRUE, smart = TRUE)
  else paste0("<pre>", esc(txt), "</pre>")
  Encoding(html) <- "UTF-8"
  html
}
wr_utf8 <- function(text, path) writeBin(charToRaw(enc2utf8(text)), path)

repo_slug <- tryCatch({
  u <- system("git config --get remote.origin.url", intern = TRUE, ignore.stderr = TRUE)
  m <- regmatches(u, regexec("github\\.com[:/]+([^/]+)/([^/]+?)(\\.git)?$", u))[[1]]
  if (length(m) >= 3) paste0(m[2], "/", m[3]) else NA_character_
}, error = function(e) NA_character_)
if (!length(repo_slug) || is.na(repo_slug) || !nzchar(repo_slug))
  repo_slug <- "demiyang12/PFAS-health-feasibility-package"
repo_branch <- tryCatch({
  b <- system("git rev-parse --abbrev-ref HEAD", intern = TRUE, ignore.stderr = TRUE)
  if (length(b) == 1 && nzchar(b) && b != "HEAD") b else "main"
}, error = function(e) "main")
GH <- paste0("https://github.com/", repo_slug)

dl <- function(path, label = NULL) {
  is_dir <- !grepl("\\.", basename(path))
  if (is.null(label)) label <- if (is_dir) paste0(path, "/") else basename(path)
  if (grepl("^phase2/direction_a_feasibility/data/(raw|interim|processed)/", path))
    return(paste0('<code>', esc(path), '</code> <span class="path">git-ignored</span>'))
  href <- paste0(GH, if (is_dir) "/tree/" else "/blob/", repo_branch, "/", path)
  a <- paste0('<a href="', href, '" target="_blank" rel="noopener">', esc(label), '</a>')
  if (is_dir) a else paste0(a, ' <span class="path">', esc(path), '</span>')
}

# ---- pull the key numbers used in the KPI strip --------------------------
a1_reg <- rd("a1_regression.csv")
a1_adj_beta <- a1_reg$std_beta[a1_reg$model == "A1-1 adjusted"]
a1_adj_p    <- a1_reg$p_value[a1_reg$model == "A1-1 adjusted"]
comp4 <- rd("a1_a3a_a3b_a3c_comparison_table.csv")
elig  <- rd("a3c_eligibility_funnel.csv")
n_elig <- sum(elig$plausible, na.rm = TRUE)
conf_hc  <- rd("confounding_check_healthcare_access.csv")
conf_fe  <- rd("confounding_check_county_fe_regression.csv")
conf_re  <- rd("confounding_check_county_re_regression.csv")
conf_sp  <- rd("confounding_check_county_fe_spatial.csv")
a4_reg   <- rd("a4_ihd_mortality_regression.csv")

# ---- CSS / FONTS (verbatim from the Phase 1 / Phase 2 report builders) ----
FONTS <- paste0('<link rel="preconnect" href="https://fonts.googleapis.com">',
  '<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>',
  '<link rel="stylesheet" href="https://fonts.googleapis.com/css2?',
  'family=Newsreader:opsz,wght@6..72,420;6..72,560&',
  'family=IBM+Plex+Sans:wght@400;500;600&family=IBM+Plex+Mono:wght@400;500&display=swap">')

CSS <- '
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
.grid2{display:grid;grid-template-columns:1fr 1fr;gap:18px;align-items:start}
.grid3{display:grid;grid-template-columns:1fr 1fr 1fr;gap:18px;align-items:start}
@media(max-width:860px){.grid2,.grid3{grid-template-columns:1fr}}
.grid2-item{background:var(--surface);border:1px solid var(--rule);border-radius:12px;
  padding:16px 18px;box-shadow:var(--shadow)}
.callout{background:var(--warn-bg);border:1px solid var(--warn-line);
  border-left:3px solid var(--warn-ink);padding:14px 18px;border-radius:10px;
  margin:18px 0;font-size:13.5px;color:var(--ink)}
.callout strong{color:var(--warn-ink)}
.verdict{display:inline-block;font-family:"IBM Plex Mono",monospace;font-size:10.5px;
  font-weight:500;padding:3px 9px;border-radius:5px;margin-left:0;vertical-align:2px;
  text-transform:uppercase;letter-spacing:.06em}
.ok{background:var(--ok-bg);color:var(--ok-ink)}
.warnb{background:var(--warn-bg);color:var(--warn-ink)}
.no{background:var(--crit-bg);color:var(--crit-ink)}
.neutral{background:var(--band);color:var(--ink-soft)}
code{font-family:"IBM Plex Mono",ui-monospace,Menlo,monospace;background:var(--band);
  padding:1.5px 5px;border-radius:4px;font-size:12px}
ul,ol{margin:10px 0;padding-left:22px;max-width:74ch}li{margin:5px 0}
figure{margin:14px 0;background:var(--surface);border:1px solid var(--rule);border-radius:12px;
  padding:10px;box-shadow:var(--shadow)}
figure img{width:100%;border-radius:6px;display:block}
figcaption{font-size:12px;color:var(--ink-soft);padding:8px 4px 2px}
.figrow{display:grid;grid-template-columns:1fr 1fr;gap:14px}
@media(max-width:860px){.figrow{grid-template-columns:1fr}}
.foot{color:var(--ink-soft);font-size:12px;margin-top:56px;border-top:1px solid var(--rule);
  padding-top:16px;line-height:1.7}
a{color:var(--accent-ink);text-decoration:none;border-bottom:1px solid var(--rule)}
a:hover{border-bottom-color:var(--accent)}
.manifest td:first-child{white-space:normal;min-width:150px}
.manifest code{font-size:11px;white-space:nowrap}
.manifest .path{color:var(--ink-soft);font-size:11px}
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
.memo table{font-size:12px;margin:12px 0}
.memo hr{border:0;border-top:1px solid var(--rule);margin:22px 0}
.memo code{font-size:11.5px}
.toc{display:flex;flex-wrap:wrap;gap:8px;margin:18px 0}
.toc a{border:1px solid var(--rule);border-radius:999px;padding:6px 14px;font-size:12.5px;
  background:var(--surface)}
.toc a:hover{border-color:var(--accent)}
'

## ---- assemble body -----------------------------------------------
Pbody <- c()
add <- function(...) Pbody <<- c(Pbody, paste0(...))

add('<div class="wrap">')
add('<h1>PFAS &amp; Cholesterol in Texas<br>Direction A Feasibility &mdash; The Full Story (A1&ndash;A4)</h1>')
add('<p class="sub">Branch: <code>Direction-A-feasibility-test</code> &nbsp;|&nbsp; ',
    'six completed feasibility pilots &nbsp;|&nbsp; no final epidemiologic model, no GWR/MGWR/PSM/',
    'Bayesian/ML/causal/mediation methods used anywhere &nbsp;|&nbsp; built ', format(Sys.Date()), '</p>')
add('<p class="sub">Phase 1 found that a focused ZCTA-level UCMR5&ndash;health pairing is feasible but ',
    'exposure-assignment-limited. This branch asks, in six increasingly specific steps, whether that ',
    'limitation is really the problem: a <strong>better outcome</strong> (A1), a <strong>better geography</strong> ',
    '(A2), a <strong>better weighting rule</strong> (A3a), <strong>more context</strong> (A3b), a ',
    '<strong>genuinely better input geography</strong> (A3c), and finally &mdash; after none of those changed ',
    'the answer &mdash; a direct test of <strong>whether the finding itself is an artifact</strong> of the ',
    'specific outcome dataset used (confounding diagnostics &amp; A4). The headline result reverses over the ',
    'course of this report: a seemingly robust association turns out to be largely a measurement artifact.</p>')

add('<div class="callout"><strong>Interpretation guard-rail.</strong> UCMR5 remains a community-level ',
    'drinking-water exposure proxy, not an individual dose. CDC PLACES outcomes are modelled ecological ',
    'prevalence estimates, not clinical measurements. All associations throughout this report are ',
    '<strong>ecological, cross-sectional, and non-causal.</strong> Statistical significance is not treated ',
    'as validity anywhere; effect stability, exposure contrast, and spatial structure are weighted more ',
    'heavily than p-values.</div>')

add('<div class="kpis">',
    '<div class="kpi"><div class="n">6</div><div class="l">feasibility pilots (A1, A2, A3a, A3b, A3c, A4)</div></div>',
    '<div class="kpi"><div class="n">', sprintf("%.3f", a1_adj_beta), '</div><div class="l">A1 adjusted std. &beta; (cholesterol) &mdash; the headline finding that started this branch</div></div>',
    '<div class="kpi"><div class="n">&minus;0.090 to &minus;0.098</div><div class="l">range of the SAME coefficient across every A3a/A3b/A3c exposure variant &mdash; robust to exposure measurement</div></div>',
    '<div class="kpi"><div class="n">&minus;0.017</div><div class="l">within-county std. &beta; (95% CI &minus;0.042 to +0.008) &mdash; a precise null once county is held constant</div></div>',
    '<div class="kpi"><div class="n">county R.E.</div><div class="l">CDC PLACES&rsquo;s own methodology confirms state/county random effects in its estimation model</div></div>',
    '<div class="kpi"><div class="n">IRR 0.998</div><div class="l">A4: CDC WONDER mortality, same exposure &amp; counties, p=0.91 &mdash; the effect disappears</div></div>',
    '</div>')

add('<div class="toc">',
    '<a href="#deliverables">Deliverables</a><a href="#a1">A1 &middot; Cholesterol</a>',
    '<a href="#a2">A2 &middot; County/LBW</a><a href="#a3a">A3a &middot; Reweighting</a>',
    '<a href="#a3b">A3b &middot; Source context</a><a href="#a3c">A3c &middot; Real geography</a>',
    '<a href="#final">A1&ndash;A3c comparison</a><a href="#confound">Confounding diagnostics</a>',
    '<a href="#a4">A4 &middot; Non-PLACES outcome</a><a href="#memo">Full memo</a>', '</div>')

add('<h2 id="deliverables">Deliverables in this package</h2>',
    '<table class="manifest"><tr><th>Deliverable</th><th>File</th></tr>',
    '<tr><td>This branch&rsquo;s README (full reproduce instructions)</td><td>', dl("phase2/direction_a_feasibility/README.md"), '</td></tr>',
    '<tr><td>Final combined verdict (A1&ndash;A3c)</td><td>', dl("phase2/direction_a_feasibility/docs/a3_direction_a_updated_memo.md"), '</td></tr>',
    '<tr><td>Original A1/A2-only verdict</td><td>', dl("phase2/direction_a_feasibility/docs/direction_a_feasibility_memo.md"), '</td></tr>',
    '<tr><td>A1 summary</td><td>', dl("phase2/direction_a_feasibility/docs/a1_feasibility_summary.md"), '</td></tr>',
    '<tr><td>A2 summary</td><td>', dl("phase2/direction_a_feasibility/docs/a2_feasibility_summary.md"), '</td></tr>',
    '<tr><td>A3a summary</td><td>', dl("phase2/direction_a_feasibility/docs/a3a_feasibility_summary.md"), '</td></tr>',
    '<tr><td>A3b summary</td><td>', dl("phase2/direction_a_feasibility/docs/a3b_feasibility_summary.md"), '</td></tr>',
    '<tr><td>A3c summary</td><td>', dl("phase2/direction_a_feasibility/docs/a3c_feasibility_summary.md"), '</td></tr>',
    '<tr><td>A3c TWDB data-quality note (incl. a correction)</td><td>', dl("phase2/direction_a_feasibility/docs/a3c_twdb_feasibility_note.md"), '</td></tr>',
    '<tr><td>Confounding diagnostics (healthcare access, county structure, PLACES methodology)</td><td>', dl("phase2/direction_a_feasibility/docs/confounding_diagnostics_summary.md"), '</td></tr>',
    '<tr><td>A4 summary (CDC WONDER mortality)</td><td>', dl("phase2/direction_a_feasibility/docs/a4_feasibility_summary.md"), '</td></tr>',
    '<tr><td>All scripts</td><td>', dl("phase2/direction_a_feasibility/scripts"), '</td></tr>',
    '<tr><td>All output tables</td><td>', dl("phase2/direction_a_feasibility/outputs"), '</td></tr>',
    '<tr><td>All figures</td><td>', dl("phase2/direction_a_feasibility/figures"), '</td></tr>',
    '</table>')

## ---- A1 ------------------------------------------------------------------
add('<h2 id="a1">A1 &middot; Does a different outcome do better than Phase 1&rsquo;s three?</h2>',
    '<p>Phase 1&rsquo;s unchanged UCMR5/ZCTA exposure, paired with CDC PLACES <strong>high cholesterol</strong> ',
    '&mdash; a candidate flagged in Phase 2 scoping but never modelled. Full write-up: ',
    dl("phase2/direction_a_feasibility/docs/a1_feasibility_summary.md"), '.</p>',
    '<p>Cholesterol turns out to be the single most coherent PFAS&ndash;health pairing found across Phase 1 ',
    'and this branch combined: adjusted standardized &beta; = ', sprintf("%.3f", a1_adj_beta),
    ' (p = ', formatC(a1_adj_p, format="e", digits=1), '), the largest and most significant of all four ',
    'outcomes tested, stable in sign from crude through adjusted. A real data-quality finding came from ',
    'verifying rather than assuming the source: the Phase 2 inventory&rsquo;s assumption of BRFSS 2021 was ',
    'wrong for the release actually in use &mdash; the live pull confirmed BRFSS 2023, contemporaneous with ',
    'the rest of Phase 1. What A1 could not resolve: residual spatial autocorrelation after adjustment is ',
    'just as large as Phase 1&rsquo;s own (Moran&rsquo;s I &asymp; 0.28), because the exposure variable and ',
    'its PWS&rarr;ZIP&rarr;ZCTA assignment are byte-for-byte identical to Phase 1&rsquo;s. This is the open ',
    'question the rest of A3 exists to test.</p>',
    '<div class="figrow">', figt("a1_map_pfas_hazard_index.png", "PFAS Hazard Index, Phase 1 baseline (ZCTA)"),
    figt("a1_map_cholesterol.png", "CDC PLACES high-cholesterol prevalence (ZCTA)"), '</div>',
    figt("a1_scatter_pfas_cholesterol.png", "PFAS Hazard Index vs. cholesterol prevalence, unadjusted"),
    '<h3>Regression</h3>', tbl(a1_reg))

## ---- A2 ------------------------------------------------------------------
a2_reg <- rd("a2_lbw_regression.csv")
add('<h2 id="a2">A2 &middot; Does a different geography do better?</h2>',
    '<p>UCMR5 exposure rebuilt at <strong>county</strong> level (population-weighted via a Geocorr crosswalk) ',
    '+ Texas DSHS <strong>low birth weight</strong> (2019). Full write-up: ',
    dl("phase2/direction_a_feasibility/docs/a2_feasibility_summary.md"), '.</p>',
    '<p>A2 is feasible to <em>build</em> but not currently <em>informative</em>: three compounding problems. ',
    'County aggregation compresses exposure contrast until the median county&rsquo;s population-weighted ',
    'Hazard Index is exactly zero. The birth-outcome source is usable for only 119 of 254 counties (47%), with ',
    'suppression concentrated in rural counties, not at random. The most recent available birth data (2019) ',
    'predates UCMR5 monitoring (2023&ndash;2025) by at least four years. The one nominally significant ',
    'adjusted result (sign flips crude&rarr;adjusted) does not survive a births-weighted sensitivity check. ',
    'Preterm birth could not be linked to a usable public county source and was not run.</p>',
    '<div class="figrow">', figt("a2_map_county_pfas_hazard_index.png", "Population-weighted county PFAS Hazard Index"),
    figt("a2_map_lbw_rate.png", "Texas DSHS low-birth-weight rate by county, 2017&ndash;2019"), '</div>',
    figt("a2_zcta_vs_county_distribution.png", "Exposure-contrast compression: ZCTA vs. county-level distribution"),
    '<h3>Regression</h3>', tbl(a2_reg),
    '<h3>A1 vs A2</h3>', tbl(rd("a1_a2_comparison_table.csv")))

## ---- A3a ------------------------------------------------------------------
a3a_reg <- rd("a3a_regression_comparison.csv")
add('<h2 id="a3a">A3a &middot; Does a different WEIGHTING RULE change A1&rsquo;s result?</h2>',
    '<p>Phase 1 counts a PWS&rsquo;s <em>full</em> population in every ZIP it reports serving. A3a instead ',
    '<em>splits</em> that population evenly across those ZIPs &mdash; a different assumption, not a measurement, ',
    'but the minimum viable, fully reproducible alternative identified from data already on hand. Full ',
    'write-up: ', dl("phase2/direction_a_feasibility/docs/a3a_feasibility_summary.md"), '.</p>',
    '<p>Barely different: Pearson r = 0.979 / Spearman &rho; = 0.997 between the two exposure surfaces; 97.1% ',
    'of ZCTAs land in the same quartile; 94.1% of top-quartile hotspots overlap. The cholesterol association ',
    'and its residual spatial autocorrelation are both essentially unchanged. The reason is structural: three ',
    'of four Texas UCMR5 systems report serving exactly one ZIP code, so the two weighting schemes are ',
    'mathematically identical for them. This result pointed toward a deeper, untested question (does the ',
    '&ldquo;ZIP codes served&rdquo; list resemble the real service area at all) &mdash; which A3c goes on to test.</p>',
    '<div class="figrow">', figt("a3a_map_1_phase1_exposure.png", "1. Phase 1 baseline exposure"),
    figt("a3a_map_2_popwt_exposure.png", "2. Equal-split population-weighted exposure"), '</div>',
    '<div class="figrow">', figt("a3a_map_3_absolute_difference.png", "3. Absolute difference (alt. minus baseline)"),
    figt("a3a_map_4_quartile_movement.png", "4. Exposure-quartile movement"), '</div>',
    figt("a3a_map_5_hotspot_disagreement.png", "5. Top-quartile hotspot disagreement"),
    '<h3>Regression: baseline vs. alternative</h3>', tbl(a3a_reg))

## ---- A3b ------------------------------------------------------------------
a3b_reg <- rd("a3b_regression_comparison.csv")
add('<h2 id="a3b">A3b &middot; Does independent SOURCE-PRESSURE context explain the pattern?</h2>',
    '<p>Real Texas TRI (PFAS-specific reporting), Superfund NPL, and NPDES data, kept strictly separate from ',
    'the UCMR5 measurement throughout &mdash; measured concentration, reported release, and source/pathway ',
    'indicators are never combined into a composite score. Full write-up: ',
    dl("phase2/direction_a_feasibility/docs/a3b_feasibility_summary.md"), '.</p>',
    '<p>Source-pressure variables correlate negligibly with UCMR5&rsquo;s spatial pattern (Pearson &minus;0.006 ',
    'to 0.032). A counter-intuitive, genuine finding: ZCTAs with a PFAS-TRI facility within 20km have a ',
    '<em>lower</em> mean Hazard Index but a much <em>higher</em> any-detect rate &mdash; a nearby facility ',
    'predicts whether PFAS is detected at all, not how concentrated it is. The cholesterol association is ',
    'unchanged across every staged model. The one new, usable finding: 420 of 1,223 ZCTAs (34%) show UCMR5 ',
    'and source-pressure evidence pointing in different directions, concentrated near major metro areas &mdash; ',
    'useful for flagging specific places for follow-up, not for correcting the exposure measure.</p>',
    '<div class="figrow">', figt("a3b_map_hotspot_overlap.png", "UCMR5 exposure vs. source-pressure, 2x2 classification"),
    figt("a3b_map_pfas_tri_facilities.png", "PFAS-reporting TRI facilities within 20km, by ZCTA"), '</div>',
    '<h3>Staged regression: baseline &rarr; + each source family &rarr; combined</h3>', tbl(a3b_reg))

## ---- A3c ------------------------------------------------------------------
a3c_reg <- rd("a3c_regression_comparison.csv")
add('<h2 id="a3c">A3c &middot; Does REAL MAPPED GEOGRAPHY change the result &mdash; and combined with A3b?</h2>',
    '<p>The question A3a identified but could not test: not a different weighting rule, but a structurally ',
    'different <strong>input</strong>. The Texas Water Development Board&rsquo;s Water Service Boundary ',
    'Viewer turned out to be a real, public, keyless, scriptable ArcGIS layer of 4,621 mapped PWS ',
    'service-area polygons statewide. A full data-quality investigation &mdash; including a correction to an ',
    'initial, over-confident read of an ambiguous field &mdash; is in ',
    dl("phase2/direction_a_feasibility/docs/a3c_twdb_feasibility_note.md"), '; the analysis write-up is ',
    dl("phase2/direction_a_feasibility/docs/a3c_feasibility_summary.md"), '.</p>',
    '<p>After excluding 8 systems with an implausible population-density-to-area ratio, <strong>', n_elig,
    ' of 1,154</strong> Texas UCMR5 systems were reassigned to ZCTAs by real spatial overlay with their mapped ',
    'polygon; the remaining 34 keep Phase 1&rsquo;s original ZIP-based method, documented not silent. This ',
    'moves the exposure surface <strong>substantially more</strong> than A3a did &mdash; Spearman &rho; = ',
    '0.937 vs. Phase 1 (vs. A3a&rsquo;s 0.997), only 85.1% of ZCTAs keep their quartile, and 11 ZCTAs lose ',
    'exposure entirely because their self-reported &ldquo;served ZIP&rdquo; does not spatially overlap the ',
    'utility&rsquo;s own mapped boundary at all. Despite this being the most substantive exposure change ',
    'tested across A3a/A3b/A3c, the cholesterol association barely moves (adjusted std &beta; = ',
    sprintf("%.3f", a3c_reg$pfas_std_beta[a3c_reg$model == "A3c adjusted (TWDB polygon alone)"]),
    ') &mdash; including when combined with A3b&rsquo;s source-pressure variables in the SAME model, the ',
    'explicit combination this round of work was asked to test. Residual spatial autocorrelation remains in ',
    'the same 0.27&ndash;0.28 band as every other version tested.</p>',
    '<div class="figrow">', figt("a3c_map_1_hybrid_exposure.png", "1. TWDB real-polygon spatial-overlay exposure"),
    figt("a3c_map_2_absolute_difference.png", "2. Absolute difference (TWDB polygon minus baseline)"), '</div>',
    '<div class="figrow">', figt("a3c_map_3_quartile_movement.png", "3. Exposure-quartile movement"),
    figt("a3c_map_4_hotspot_disagreement.png", "4. Top-quartile hotspot disagreement"), '</div>',
    figt("a3c_map_5_pct_edges_from_polygon.png", "5. Where the real-polygon method applies vs. the ZIP fallback"),
    '<h3>Regression: TWDB-polygon exposure, alone and combined with A3b source context</h3>', tbl(a3c_reg),
    '<h3>Eligibility funnel (why 34 systems fall back to Phase 1&rsquo;s method)</h3>',
    '<p class="sub">Full table: ', dl("phase2/direction_a_feasibility/outputs/a3c_eligibility_funnel.csv"), '</p>')

## ---- final comparison ------------------------------------------------------------------
add('<h2 id="final">A1&ndash;A3c comparison &mdash; exposure measurement is not the limiting factor</h2>',
    '<p>Full machine-readable version: ', dl("phase2/direction_a_feasibility/outputs/a1_a3a_a3b_a3c_comparison_table.csv"), '.</p>',
    tbl(comp4),
    '<p class="sub">Three independent, increasingly substantive exposure/context interventions all leave the ',
    'cholesterol association and its residual spatial autocorrelation essentially unchanged. The natural next ',
    'question is not "which exposure method is best" &mdash; it clearly does not matter &mdash; but ',
    '<em>why</em> the association and its unexplained spatial structure are so stubbornly unmoved. That ',
    'question is what the confounding diagnostics below were designed to answer.</p>')

## ---- confounding diagnostics ------------------------------------------------------------------
add('<h2 id="confound">Confounding diagnostics &mdash; why nothing above moved the needle</h2>',
    '<p>Full write-up: ', dl("phase2/direction_a_feasibility/docs/confounding_diagnostics_summary.md"), '. ',
    'Across all four Phase 1 outcomes (not just cholesterol), PFAS exposure is <strong>negatively</strong> ',
    'associated with prevalence &mdash; opposite the direction individual-level PFAS toxicology predicts for ',
    'metabolic/lipid outcomes. Two confounding mechanisms were tested directly.</p>',
    '<h3>Test 1 &mdash; healthcare access (ruled out)</h3>',
    '<p>A ZCTA&rsquo;s uninsured rate (ACS table B27001, pulled fresh for this test) strongly predicts ',
    'cholesterol prevalence on its own (std &beta; = ', sprintf("%.3f", conf_hc$uninsured_beta[2]),
    ', p = ', formatC(conf_hc$uninsured_p[2], format="e", digits=1), ') but is essentially uncorrelated with ',
    'PFAS exposure itself (Pearson r = &minus;0.041) &mdash; it fails the basic requirement for a confounder. ',
    'Adding it moves the PFAS coefficient by only 1.4%.</p>',
    '<h3>Test 2 &mdash; county-level structure (confirmed, and decisive)</h3>',
    '<p>Adding a county term &mdash; as a fixed effect and, to avoid overfitting 63 single-ZCTA counties, as a ',
    'random intercept &mdash; collapsed residual Moran&rsquo;s I by 80&ndash;89% and the headline PFAS ',
    'coefficient by 46&ndash;62%:</p>',
    tbl(rbind(conf_fe[,c("model","pfas_std_beta","pfas_p","n")], setNames(conf_re[,c("model","pfas_std_beta","pfas_p","n")], c("model","pfas_std_beta","pfas_p","n")))),
    '<p>A <strong>within-between (Mundlak) decomposition</strong> then split the PFAS effect into its two ',
    'components explicitly, rather than discarding the between-county part:</p>',
    tbl(rd("confounding_check_mundlak_decomposition.csv")[,c("component","std_beta","ci_lo","ci_hi","t_value")]),
    '<p>A formal test confirms these two components are statistically distinguishable (&chi;&sup2; = 4.56, ',
    'p = 0.033) &mdash; not a power artifact. The within-county estimate is a <strong>precise null</strong> ',
    '(the interval is narrow, not merely wide); the between-county estimate accounts for most of the original ',
    '&minus;0.095. A robustness check confirms this is not driven by a few outlier counties (removing the top ',
    '3&ndash;8 highest-exposure counties leaves it materially unchanged):</p>',
    tbl(rd("confounding_check_outlier_robustness.csv")),
    '<p class="sub">The highest-exposure counties (Jones, Taylor, Martin, Ector, Midland, Howard, Callahan, ',
    'Calhoun) cluster in the <strong>Permian Basin oil/gas region</strong> of West Texas &mdash; a specific ',
    'industrial geography that plausibly differs from the rest of the state on many dimensions besides PFAS.</p>',
    '<h3>Test 3 &mdash; what CDC PLACES&rsquo;s own methodology says</h3>',
    '<p>CDC&rsquo;s official PLACES methodology page states the model used to generate every measure includes ',
    '&ldquo;<strong>State- and county-level random effects</strong>,&rdquo; applied at the census-block level ',
    'before aggregation to ZCTA. Every block within a county inherits that <em>same</em> county-level term ',
    'before being rolled up into ZCTA estimates &mdash; a structural, by-construction source of within-county ',
    'similarity in the outcome variable itself, independent of any real disease pattern. This directly confirms ',
    'part of the mechanism tested in Test 2.</p>')

## ---- A4 ------------------------------------------------------------------
add('<h2 id="a4">A4 &mdash; does the effect survive a NON-PLACES outcome?</h2>',
    '<p>The decisive test: reuse the identical PFAS exposure data and covariates from Test 2, but replace ',
    'PLACES&rsquo;s modelled cholesterol prevalence with CDC WONDER&rsquo;s death-certificate-based ',
    '<strong>Ischaemic Heart Disease mortality</strong> (ICD-10 I20-I25, Texas counties, 2020&ndash;2024) &mdash; ',
    'the natural downstream cardiovascular endpoint of elevated cholesterol, from a database with no survey, ',
    'no small-area model, and no county random effect. Full write-up: ',
    dl("phase2/direction_a_feasibility/docs/a4_feasibility_summary.md"), '.</p>',
    '<p class="sub"><strong>A real access constraint:</strong> CDC WONDER&rsquo;s documented API explicitly ',
    'forbids sub-national geography in scripted queries, per NCHS confidentiality policy (only national totals ',
    'are accessible to keyless API calls). County-level data required the interactive web request form &mdash; ',
    'a human-reproducible, not programmatically re-runnable, step, with every query parameter documented in the ',
    'raw data file itself.</p>',
    '<p>All 254 Texas counties were queried; 12 (4.7%) were suppressed (&le;9 deaths over 5 years) and ',
    'excluded, never imputed as zero. A negative binomial regression with a population offset (Poisson ',
    'dispersion = 18.2, confirming substantial overdispersion) found:</p>',
    tbl(a4_reg),
    '<p>A 1-SD increase in PFAS exposure is associated with a statistically indistinguishable-from-zero change ',
    'in IHD mortality. <strong>The confidence interval is narrow and centered on no effect</strong> &mdash; the ',
    'same signature as the within-county null in Test 2, not an underpowered result. Compared side by side:</p>',
    '<table><tr><th></th><th>PLACES cholesterol (between-county)</th><th>CDC WONDER IHD mortality (A4)</th></tr>',
    '<tr><td>Effect</td><td>std &beta; = &minus;0.077</td><td>IRR = ', sprintf("%.3f", a4_reg$pfas_log_irr), '</td></tr>',
    '<tr><td>95% CI</td><td>&minus;0.126 to &minus;0.028</td><td>', sprintf("%.3f", a4_reg$irr_ci_lo), ' to ', sprintf("%.3f", a4_reg$irr_ci_hi), '</td></tr>',
    '<tr><td>p-value</td><td>0.002</td><td><strong>', sprintf("%.3f", a4_reg$p_value), '</strong></td></tr></table>',
    '<p>Switching only the outcome source &mdash; same exposure, same covariates, same counties &mdash; made ',
    'the previously robust, significant between-county association <strong>disappear entirely</strong>. This is ',
    'strong corroborating evidence that the PLACES-based pattern is substantially a product of PLACES&rsquo;s ',
    'own estimation methodology rather than a real PFAS&ndash;cardiometabolic relationship in this dataset.</p>')

## ---- full memo ------------------------------------------------------------------
add('<h2 id="memo">Full combined memo</h2>',
    '<p class="sub">The complete write-up (identical to <code>docs/a3_direction_a_updated_memo.md</code>): ',
    'every pilot in one paragraph each, the final verdict, and what it means for the next analysis step.</p>',
    '<div class="memo">', md_to_html(file.path(DA_PATHS$docs, "a3_direction_a_updated_memo.md")), '</div>')

add('<p class="foot">Direction A feasibility record &mdash; built ', format(Sys.Date()),
    '. Every figure and table above was generated by the scripts in ', dl("phase2/direction_a_feasibility/scripts"),
    ' from real public-data pulls (EPA UCMR5/Envirofacts, CDC PLACES, Texas DSHS, TWDB ArcGIS services, ACS, ',
    'CDC WONDER) &mdash; no number in this report was estimated or assumed. All pulls are keyless and scripted ',
    'except CDC WONDER county-level mortality (A4), which NCHS confidentiality policy restricts to interactive ',
    'web access only (documented in the raw data file and <code>a4_feasibility_summary.md</code>). Phase 1, the ',
    'Phase 2 scoping deliverables, and the completed A1/A2 pilot files are unmodified by anything in this report ',
    'or this branch. This HTML is self-contained (images are base64-embedded); the deliverable links point to ',
    'the GitHub repository.</p>')
add('</div>')

BODY  <- paste(Pbody, collapse = "\n")
TITLE <- "<title>Direction A &mdash; PFAS &amp; Cholesterol Feasibility (A1&ndash;A4)</title>"

FULL_HTML <- paste0('<!doctype html><html lang="en"><head><meta charset="utf-8">',
  '<meta name="viewport" content="width=device-width,initial-scale=1">', TITLE, FONTS,
  '<style>', CSS, '</style></head><body>', BODY, '</body></html>')

wr_utf8(FULL_HTML, file.path(DA_PATHS$docs, "direction_a_report.html"))
msg("build_report.R done -- %s (%.2f MB)",
    file.path(DA_PATHS$docs, "direction_a_report.html"),
    file.size(file.path(DA_PATHS$docs, "direction_a_report.html")) / 1e6)
