# =====================================================================
# build_report.R
# Assemble the self-contained Phase 2 scoping report from the hand-curated
# inventories/decision framework in phase2/docs/. Same design system as the
# Phase 1 report (scripts/13_build_report.R) for visual continuity.
#
# Run from the project root:  Rscript phase2/scripts/build_report.R
#   output: phase2/docs/phase2_report.html   (canonical, self-contained)
#           docs/phase2_report.html          (identical copy, served live by
#                                             the same GitHub Pages config
#                                             that already serves docs/)
# =====================================================================
ROOT <- getwd()
P2   <- file.path(ROOT, "phase2")
if (!dir.exists(file.path(P2, "docs")))
  stop("Run this from the project root: Rscript phase2/scripts/build_report.R")

msg <- function(...) cat(sprintf("[%s] %s\n", format(Sys.time(), "%H:%M:%S"), sprintf(...)))

if (!requireNamespace("commonmark", quietly = TRUE))
  install.packages("commonmark", repos = "https://cloud.r-project.org", quiet = TRUE)

# ---- helpers (identical to scripts/13_build_report.R for consistency) ----
esc <- function(x) { x <- as.character(x)
  x <- gsub("&", "&amp;", x, fixed = TRUE); x <- gsub("<", "&lt;", x, fixed = TRUE)
  gsub(">", "&gt;", x, fixed = TRUE) }

rd <- function(f) tryCatch(read.csv(file.path(P2, "docs", f), check.names = FALSE, stringsAsFactors = FALSE),
                            error = function(e) data.frame())

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

# repo info for absolute GitHub links -- same detection as the Phase 1 builder
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
GH_OWNER <- strsplit(repo_slug, "/")[[1]][1]
GH_REPO  <- strsplit(repo_slug, "/")[[1]][2]
GH       <- paste0("https://github.com/", repo_slug)
GH_PAGES <- paste0("https://", GH_OWNER, ".github.io/", GH_REPO, "/")

dl <- function(path, label = NULL) {
  is_dir <- !grepl("\\.", basename(path))
  if (is.null(label)) label <- if (is_dir) paste0(path, "/") else basename(path)
  if (path %in% c("docs/feasibility_report.html", "docs/phase2_report.html")) {
    target <- if (path == "docs/phase2_report.html") paste0(GH_PAGES, "phase2_report.html") else GH_PAGES
    return(paste0('<a href="', target, '" target="_blank" rel="noopener">', esc(label),
                  '</a> <span class="path">', esc(target), '</span>'))
  }
  if (grepl("^(data|phase2/data)/(raw|interim|processed)/", path))
    return(paste0('<code>', esc(path), '</code> <span class="path">git-ignored</span>'))
  href <- paste0(GH, if (is_dir) "/tree/" else "/blob/", repo_branch, "/", path)
  a <- paste0('<a href="', href, '" target="_blank" rel="noopener">', esc(label), '</a>')
  if (is_dir) a else paste0(a, ' <span class="path">', esc(path), '</span>')
}

# ---- tier classification shared by both inventories -----------------
classify_tier <- function(x) {
  x <- trimws(x)
  ifelse(grepl("^RETAIN-SECONDARY", x), "RETAIN-SECONDARY",
  ifelse(grepl("^RETAIN", x), "RETAIN",
  ifelse(grepl("^DEFER", x), "DEFER",
  ifelse(grepl("^EXCLUDE", x), "EXCLUDE", "OTHER"))))
}
tier_chip <- function(tier) {
  cls <- switch(tier, "RETAIN" = "ok", "RETAIN-SECONDARY" = "warnb", "DEFER" = "neutral",
                "EXCLUDE" = "neutral", "warnb")
  paste0('<span class="verdict ', cls, '">', esc(tier), '</span>')
}
tier_lead <- function(tier) switch(tier,
  "RETAIN" = "Retain &mdash; primary / near-term",
  "RETAIN-SECONDARY" = "Retain-secondary &mdash; triangulation / illustrative",
  "DEFER" = "Defer &mdash; real but not ready, or geographically mismatched",
  "EXCLUDE" = "Excluded &mdash; checked and found unusable at this stage", tier)

# a compact grouped table: one mini-table per tier, in a fixed tier order
grouped_table <- function(df, tier_col, cols, col_labels) {
  tiers <- c("RETAIN", "RETAIN-SECONDARY", "DEFER", "EXCLUDE")
  out <- c()
  for (t in tiers) {
    sub <- df[classify_tier(df[[tier_col]]) == t, , drop = FALSE]
    if (!nrow(sub)) next
    out <- c(out, paste0('<h3>', tier_chip(t), ' &nbsp;', tier_lead(t),
                          ' <span class="path">(', nrow(sub), ')</span></h3>'))
    hdr <- paste0("<tr>", paste0("<th>", esc(col_labels), "</th>", collapse = ""), "</tr>")
    body <- vapply(seq_len(nrow(sub)), function(i)
      paste0("<tr>", paste0("<td>", esc(sub[i, cols]), "</td>", collapse = ""), "</tr>"),
      character(1))
    out <- c(out, paste0('<table>', hdr, paste(body, collapse = ""), '</table>'))
  }
  paste(out, collapse = "\n")
}

# ---- read the Phase 2 artifacts --------------------------------------
exp_df <- rd("exposure_data_inventory.csv")
out_df <- rd("outcome_data_inventory.csv")
dm_df  <- rd("decision_matrix.csv")

exp_tier <- classify_tier(exp_df$retain_decision)
out_tier <- classify_tier(out_df$retain_decision)

n_exp <- nrow(exp_df); n_out <- nrow(out_df)
n_exp_retain <- sum(exp_tier == "RETAIN"); n_exp_sec <- sum(exp_tier == "RETAIN-SECONDARY")
n_out_retain <- sum(out_tier == "RETAIN"); n_out_sec <- sum(out_tier == "RETAIN-SECONDARY")

overall <- dm_df[dm_df$criterion == "OVERALL RECOMMENDATION", ]
primary_dir <- overall$direction[overall$score == "PRIMARY"]
if (!length(primary_dir)) primary_dir <- "C"

# ---- decision-matrix pivot: criterion x {A,B,C} ----------------------
crit_df <- dm_df[dm_df$criterion != "OVERALL RECOMMENDATION", ]
criteria <- unique(crit_df$criterion)
matrix_rows <- vapply(criteria, function(cr) {
  sub <- crit_df[crit_df$criterion == cr, ]
  cell <- function(d) {
    r <- sub[sub$direction == d, ]
    if (!nrow(r)) return("<td>&mdash;</td>")
    paste0('<td><strong>', esc(r$score[1]), '</strong><br><span class="path" style="white-space:normal">',
           esc(r$rationale[1]), '</span></td>')
  }
  paste0("<tr><td><strong>", esc(cr), "</strong></td>", cell("A"), cell("B"), cell("C"), "</tr>")
}, character(1))
matrix_html <- paste0(
  '<table><tr><th>Criterion</th><th>A &middot; Focused exposure&ndash;health study</th>',
  '<th>B &middot; Exposure geography / source attribution</th>',
  '<th>C &middot; Exposure-assignment methodology</th></tr>',
  paste(matrix_rows, collapse = ""), '</table>')

overall_card <- function(d, title) {
  r <- overall[overall$direction == d, ]
  primary <- identical(r$score[1], "PRIMARY")
  cls <- if (primary) 'style="border:1px solid var(--accent);box-shadow:var(--shadow)"' else ""
  paste0('<div class="grid2-item" ', cls, '>',
         '<h3>', d, ' <span class="verdict ', if (primary) "ok" else "warnb", '">', esc(r$score[1]), '</span></h3>',
         '<p style="margin-top:2px"><strong>', esc(title), '</strong></p>',
         '<p style="font-size:13px;color:var(--ink-soft)">', esc(r$rationale[1]), '</p></div>')
}

# ---- CSS / FONTS (verbatim from scripts/13_build_report.R, same design system) ----
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
.grid2{display:grid;grid-template-columns:1fr 1fr 1fr;gap:18px;align-items:start}
@media(max-width:860px){.grid2{grid-template-columns:1fr}}
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
.memo pre{background:var(--band);padding:12px 14px;border-radius:8px;overflow-x:auto;
  font-size:12px;line-height:1.5}
.memo table{font-size:12px;margin:12px 0}
.memo hr{border:0;border-top:1px solid var(--rule);margin:22px 0}
.memo code{font-size:11.5px}
'

## ---- assemble body -----------------------------------------------
Pbody <- c()
add <- function(...) Pbody <<- c(Pbody, paste0(...))

add('<div class="wrap">')
add('<h1>PFAS Exposure &amp; Outcome Scoping<br>Phase 2 Feasibility Assessment</h1>')
add('<p class="sub">Status: scoping only &mdash; no new health-regression model has been run ',
    '&nbsp;|&nbsp; unit of analysis for Phase 1 remains ZCTA; nothing here changes it ',
    '&nbsp;|&nbsp; built ', format(Sys.Date()), '</p>')
add('<p class="sub">This is the systematic answer to one question: given Phase 1&rsquo;s own finding that ',
    '<strong>exposure characterization &mdash; not sample size or model complexity &mdash; is the binding ',
    'constraint</strong>, what would actually improve it? It inventories ', n_exp, ' candidate PFAS exposure/',
    'source-pressure datasets and ', n_out, ' candidate health outcomes, scores three possible research ',
    'directions against them, and recommends one. Phase 1 (', dl("docs/feasibility_report.html", "full report"),
    ') is preserved unchanged throughout.</p>')

add('<div class="callout"><strong>Interpretation guard-rail.</strong> Every exposure dataset below is either ',
    'a <strong>measured environmental concentration</strong> (drinking water, groundwater, tapwater) or a ',
    '<strong>source-pressure indicator</strong> (a facility&rsquo;s existence, type, or self-reported release ',
    'volume &mdash; not a measured concentration). These are not interchangeable, and neither is an individual ',
    'exposure or dose. All associations remain <strong>ecological and cross-sectional</strong>; no causal claim ',
    'is made anywhere in this report.</div>')

add('<div class="kpis">',
    '<div class="kpi"><div class="n">', n_exp, '</div><div class="l">candidate exposure / source-pressure datasets reviewed</div></div>',
    '<div class="kpi"><div class="n">', n_out, '</div><div class="l">candidate health outcomes reviewed</div></div>',
    '<div class="kpi"><div class="n">', n_exp_retain, '+', n_exp_sec, '</div><div class="l">exposure datasets retained (primary + secondary)</div></div>',
    '<div class="kpi"><div class="n">3</div><div class="l">zero-cost CDC PLACES outcome additions found (cholesterol, CHD, stroke)</div></div>',
    '<div class="kpi"><div class="n">0</div><div class="l">new regression models run this phase</div></div>',
    '<div class="kpi"><div class="n">', esc(primary_dir), '</div><div class="l">recommended primary Phase 2 direction</div></div>',
    '</div>')

add('<h2>Deliverables in this package</h2>',
    '<p>Links point to the GitHub repository, same as the Phase 1 report.</p>',
    '<table class="manifest"><tr><th>Deliverable</th><th>File</th></tr>',
    '<tr><td>Exposure data inventory (', n_exp, ' datasets)</td><td>', dl("phase2/docs/exposure_data_inventory.csv"), '</td></tr>',
    '<tr><td>Outcome data inventory (', n_out, ' outcomes)</td><td>', dl("phase2/docs/outcome_data_inventory.csv"), '</td></tr>',
    '<tr><td>Decision matrix (Directions A/B/C)</td><td>', dl("phase2/docs/decision_matrix.csv"), '</td></tr>',
    '<tr><td>Decision log</td><td>', dl("phase2/docs/decision_log.md"), '</td></tr>',
    '<tr><td>Full Phase 2 memo</td><td>', dl("phase2/docs/phase2_methodological_memo.md"), ' &mdash; also embedded verbatim in &sect;E below</td></tr>',
    '<tr><td>Phase 2 folder README</td><td>', dl("phase2/README.md"), '</td></tr>',
    '<tr><td>Phase 1 report (for context)</td><td>', dl("docs/feasibility_report.html", "live Phase 1 report"), '</td></tr>',
    '<tr><td>This report</td><td>', dl("docs/phase2_report.html", "live Phase 2 report"), '</td></tr>',
    '</table>')

add('<h2>A &middot; Why Phase 2 scopes before modelling</h2>',
    '<p>Phase 1 built a full Texas ZCTA-level pipeline (EPA UCMR&nbsp;5 &rarr; SDWIS &rarr; ZIP/ZCTA &rarr; ',
    'CDC PLACES &rarr; ACS) and concluded that <strong>the main limitation is not sample size &mdash; it is ',
    'exposure characterization and geographic assignment</strong> (the many-to-many PWS&harr;ZCTA relationship; ',
    'PFAS and disease hot-spots occupy largely different geographies; associations attenuate after adjustment ',
    'and are sensitive to spatial model specification). Rather than pairing that same drinking-water-only ',
    'exposure proxy with a new outcome and a new regression, Phase 2 asks two prior questions: can broader, ',
    'spatially explicit environmental and source data meaningfully improve exposure characterization, and does ',
    'the health outcome even need to stay the same? This report is the systematic answer.</p>')

add('<h2>B &middot; Exposure data inventory</h2>',
    '<p>', n_exp, ' candidate datasets, grouped by disposition. Full 23-field detail (access method, spatial ',
    'unit, PFAS compounds, detection limits, sampling design, linkage unit, and more) in ',
    dl("phase2/docs/exposure_data_inventory.csv", "the full CSV"), '.</p>',
    grouped_table(exp_df, "retain_decision",
      c("dataset_name", "exposure_pathway", "texas_coverage", "major_limitations"),
      c("Dataset", "Pathway", "Texas coverage", "Key limitation / reason")))

add('<h2>C &middot; Health outcome inventory</h2>',
    '<p>', n_out, ' candidate outcomes, grouped the same way. Full detail (source, geographic/temporal ',
    'resolution, confidentiality/suppression rules, biological relevance) in ',
    dl("phase2/docs/outcome_data_inventory.csv", "the full CSV"), '.</p>',
    grouped_table(out_df, "retain_decision",
      c("outcome", "source_dataset", "geographic_resolution", "limitations"),
      c("Outcome", "Source", "Geographic resolution", "Key limitation / reason")))

add('<h2>D &middot; Decision framework &mdash; Directions A / B / C</h2>',
    '<p>Three candidate Phase 2 research directions scored against the same 11 criteria. Full scoring: ',
    dl("phase2/docs/decision_matrix.csv", "decision_matrix.csv"), '.</p>',
    '<div class="grid2">',
    overall_card("A", "Focused exposure-health study"),
    overall_card("B", "Exposure geography / source attribution"),
    overall_card("C", "Exposure-assignment methodology"),
    '</div>',
    '<h3>Full scoring matrix</h3>', matrix_html)

add('<h2>E &middot; Full Phase 2 methodological memo</h2>',
    '<p class="sub">The complete write-up (identical to <code>phase2/docs/phase2_methodological_memo.md</code>): ',
    'which exposure datasets and outcomes are strongest, what is excluded and why, the recommended direction, ',
    'and the specific evidence still needed before it is final.</p>',
    '<div class="memo">', md_to_html(file.path(P2, "docs", "phase2_methodological_memo.md")), '</div>')

add('<h2>F &middot; Decision log</h2>',
    '<p class="sub">Dated, append-only record of decisions made and why &mdash; see ',
    dl("phase2/docs/decision_log.md"), ' for future entries.</p>',
    '<div class="memo">', md_to_html(file.path(P2, "docs", "decision_log.md")), '</div>')

add('<p class="foot">Phase&nbsp;2 scoping record &mdash; built ', format(Sys.Date()),
    '. No raw data was downloaded and no analysis script has been written yet for Phase 2; every fact above ',
    'was checked against a public source (see the CSVs for URLs) rather than assumed. Phase 1 in ',
    '<code>data/</code>, <code>scripts/</code>, <code>outputs/</code>, <code>figures/</code> and <code>docs/</code> ',
    'is unmodified. This HTML is self-contained; the deliverable links point to the GitHub repository.</p>')
add('</div>')

BODY  <- paste(Pbody, collapse = "\n")
TITLE <- "<title>PFAS Phase 2 &mdash; Exposure &amp; Outcome Scoping</title>"

FULL_HTML <- paste0('<!doctype html><html lang="en"><head><meta charset="utf-8">',
  '<meta name="viewport" content="width=device-width,initial-scale=1">', TITLE, FONTS,
  '<style>', CSS, '</style></head><body>', BODY, '</body></html>')

wr_utf8(FULL_HTML, file.path(P2, "docs", "phase2_report.html"))
# identical copy inside the existing Pages root (docs/) so it is reachable at
# https://<owner>.github.io/<repo>/phase2_report.html with zero extra Pages config
if (dir.exists(file.path(ROOT, "docs")))
  wr_utf8(FULL_HTML, file.path(ROOT, "docs", "phase2_report.html"))

msg("build_report.R done -- phase2/docs/phase2_report.html + docs/phase2_report.html (%.2f MB each)",
    file.size(file.path(P2, "docs", "phase2_report.html")) / 1e6)
