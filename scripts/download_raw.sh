#!/usr/bin/env bash
# =====================================================================
# download_raw.sh
# Retrieve every public raw input for the PFAS x obesity-health feasibility
# package.  Raw files land in data/raw/ and are treated as READ-ONLY
# afterwards -- all cleaning happens in the R scripts.
#
# Usage:   bash scripts/download_raw.sh
# Re-run:  safe; existing files are overwritten with a fresh copy.
# Requires: curl, unzip, awk  (no API keys).
# Retrieved for this package on: 2026-09-07
# =====================================================================
set -euo pipefail
cd "$(dirname "$0")/.."
RAW="data/raw"
mkdir -p "$RAW"/{ucmr5,places,acs,geo}

echo "== 1. EPA UCMR 5 occurrence data =="
curl -sL -o "$RAW/ucmr5/ucmr5-occurrence-data.zip" \
  "https://www.epa.gov/system/files/other-files/2023-08/ucmr5-occurrence-data.zip"
unzip -o "$RAW/ucmr5/ucmr5-occurrence-data.zip" -d "$RAW/ucmr5" >/dev/null
#  -> UCMR5_All.txt, UCMR5_ZIPCodes.txt, UCMR5_AddtlDataElem.txt, + PDFs

echo "== 2. CDC PLACES 2025 release, ZCTA (Socrata: qnzd-25i4) =="
curl -sL -o "$RAW/places/places_zcta_3measures.csv" \
  "https://data.cdc.gov/resource/qnzd-25i4.csv?\$limit=300000&\$where=measureid%20in('OBESITY','DIABETES','BPHIGH')&\$select=year,locationname,locationid,measureid,short_question_text,data_value,low_confidence_limit,high_confidence_limit,totalpopulation,totalpop18plus,data_value_type"

echo "== 3. ACS 2019-2023 5-year, table-based Summary File (ZCTA rows only) =="
ACSB="https://www2.census.gov/programs-surveys/acs/summary_file/2023/table-based-SF/data/5YRData"
for t in b01001 b01003 b03002 b15003 b17001 b19013 b23025 b25003 b25024 b25077 b25064; do
  curl -sL "$ACSB/acsdt5y2023-$t.dat" \
    | awk -F'|' 'NR==1 || $1 ~ /^860Z200US/' > "$RAW/acs/acs_${t}_zcta.psv"
done
curl -sL -o "$RAW/acs/ACS20235YR_Table_Shells.txt" \
  "https://www2.census.gov/programs-surveys/acs/summary_file/2023/table-based-SF/documentation/ACS20235YR_Table_Shells.txt"

echo "== 4. Census geography =="
curl -sL -o "$RAW/geo/cb_2020_us_zcta520_500k.zip" \
  "https://www2.census.gov/geo/tiger/GENZ2020/shp/cb_2020_us_zcta520_500k.zip"
curl -sL -o "$RAW/geo/cb_2022_us_county_500k.zip" \
  "https://www2.census.gov/geo/tiger/GENZ2022/shp/cb_2022_us_county_500k.zip"
curl -sL -o "$RAW/geo/cb_2022_us_state_500k.zip" \
  "https://www2.census.gov/geo/tiger/GENZ2022/shp/cb_2022_us_state_500k.zip"
for z in "$RAW"/geo/*.zip; do unzip -o "$z" -d "$RAW/geo" >/dev/null; done
curl -sL -o "$RAW/geo/zcta_county_rel_2020.txt" \
  "https://www2.census.gov/geo/docs/maps-data/data/rel2020/zcta520/tab20_zcta520_county20_natl.txt"

echo "== 5. EPA SDWIS system characteristics (Envirofacts REST, Texas) =="
for tbl in WATER_SYSTEM GEOGRAPHIC_AREA; do
  lc=$(echo "$tbl" | cut -c1-2 | tr 'A-Z' 'a-z')
  [ "$tbl" = "WATER_SYSTEM" ] && pre="ws" || pre="ga"
  curl -sL -o "$RAW/geo/${pre}_tx_0.csv" \
    "https://data.epa.gov/efservice/$tbl/PWSID/BEGINNING/TX/ROWS/0:9999/CSV"
  curl -sL -o "$RAW/geo/${pre}_tx_1.csv" \
    "https://data.epa.gov/efservice/$tbl/PWSID/BEGINNING/TX/ROWS/10000:19999/CSV"
done

echo "== 6. verify against the pinned manifest =="
# CHECKSUMS.sha256 records the exact bytes used for this analysis. A mismatch
# means EPA/CDC/Census reposted a file -- not necessarily an error, but note it
# in docs/methodological_memo.md before rerunning. Non-fatal here.
if [ -f "$RAW/CHECKSUMS.sha256" ]; then
  ( cd "$RAW" && shasum -a 256 -c CHECKSUMS.sha256 ) || \
    echo "!! checksum mismatch: an upstream file changed since 2026-09-07 -- review before use"
else
  echo "(no CHECKSUMS.sha256 yet; to pin this download run:"
  echo "   cd $RAW && find . -type f ! -name .DS_Store ! -name CHECKSUMS.sha256 ! -name README.md | sort | xargs shasum -a 256 | sed 's|  ./|  |' > CHECKSUMS.sha256 )"
fi

echo "== done.  Raw inputs in $RAW/ =="
