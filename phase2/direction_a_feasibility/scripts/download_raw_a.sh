#!/usr/bin/env bash
# =====================================================================
# download_raw_a.sh -- Direction A feasibility pilot raw inputs
# Everything here is public and key-free. Run from the project root:
#   bash phase2/direction_a_feasibility/scripts/download_raw_a.sh
# Re-run: safe; existing files are overwritten with a fresh copy.
# Retrieved for this pilot on: 2026-10-01
# =====================================================================
set -euo pipefail
cd "$(dirname "$0")/../../.."   # -> project root
RAW="phase2/direction_a_feasibility/data/raw"
mkdir -p "$RAW"/{places,geo,tx_dshs}

echo "== A1. CDC PLACES 2025 release, ZCTA -- HIGH CHOLESTEROL (Socrata: qnzd-25i4) =="
# Pulled separately from the 3 Phase-1 measures (obesity/diabetes/bphigh) because
# this pilot needs to VERIFY (not assume) the measure's vintage/BRFSS year --
# see docs/a1_feasibility_summary.md for what the 'year' field actually showed.
curl -sL -o "$RAW/places/places_zcta_highchol.csv" \
  "https://data.cdc.gov/resource/qnzd-25i4.csv?\$limit=50000&\$where=measureid='HIGHCHOL'&\$select=year,locationname,locationid,measureid,short_question_text,measure,data_value,low_confidence_limit,high_confidence_limit,totalpopulation,totalpop18plus,data_value_type,datavaluetypeid,categoryid"

echo "== A2. Geocorr 2022 (Missouri Census Data Center) -- TX ZCTA-to-county, =="
echo "==     population-weighted (2020 Census) allocation factors            =="
# Geocorr is a classic SAS/CGI broker: submit the same parameters the web form
# would, scrape the generated-report link from the HTML response, then fetch it.
# No login / API key. The job id in the file name changes on every run; that is
# expected -- the CONTENT (TX ZCTA<->county population allocation) does not.
GEOCORR_QS="_PROGRAM=apps.geocorr2022.sas&_SERVICE=MCDC_long&_debug=0&state=Tx48&g1_=zcta&g2_=county&wtvar=pop20&nozerob=1&fileout=1&filefmt=csv&lstfmt=html&title=&counties=&metros=&places=&oropt=&latitude=&longitude=&distance=&kiloms=0&locname="
RESP="$(curl -sL "https://mcdc.missouri.edu/cgi-bin/broker?${GEOCORR_QS}")"
CSV_PATH="$(echo "$RESP" | grep -oE '/temp/geocorr2022_[0-9]+\.csv' | head -1 | tr -d ' ')"
if [ -z "$CSV_PATH" ]; then
  echo "!! Geocorr did not return a report link this run -- check for a form/parameter change" >&2
  echo "$RESP" | grep -i "ERROR" | head -5 >&2 || true
else
  curl -sL "https://mcdc.missouri.edu${CSV_PATH}" -o "$RAW/geo/geocorr2022_zcta_county_tx_pop.csv"
  echo "   saved -> $RAW/geo/geocorr2022_zcta_county_tx_pop.csv ($(wc -l < "$RAW/geo/geocorr2022_zcta_county_tx_pop.csv") lines)"
fi

echo "== A2. Texas DSHS Vital Statistics Annual Report -- Table 10            =="
echo "==     Low Birth Weight by Region/County of Residence, 2017-2019       =="
# These are the most recent years DSHS has posted as static Annual-Report
# tables (checked 2026-10-01; the interactive healthdata.dshs.texas.gov
# dashboard may have more recent data but is not a scriptable download --
# see docs/a2_feasibility_summary.md). No county-level PRETERM BIRTH table
# is published in this series; see the same memo for what was checked.
for y in 2019 2018 2017; do
  curl -sL -o "$RAW/tx_dshs/${y}-table-10.xlsx" \
    "https://www.dshs.texas.gov/sites/default/files/stateepi-chs/vs/docs/Annual%20Reports/${y}/Residence/${y}-table-10.xlsx"
done

echo "== done. Raw inputs in $RAW/ =="
