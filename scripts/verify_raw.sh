#!/usr/bin/env bash
# =====================================================================
# verify_raw.sh
# Check every file in data/raw/ against data/raw/CHECKSUMS.sha256, the
# manifest of the exact public inputs used for this analysis.
#
# Usage:  bash scripts/verify_raw.sh
# Exit 0 = all files present and byte-identical; non-zero = mismatch.
# =====================================================================
set -euo pipefail
cd "$(dirname "$0")/../data/raw"

if [ ! -f CHECKSUMS.sha256 ]; then
  echo "CHECKSUMS.sha256 not found in data/raw/" >&2
  exit 2
fi

if command -v shasum >/dev/null 2>&1; then
  shasum -a 256 -c CHECKSUMS.sha256
elif command -v sha256sum >/dev/null 2>&1; then
  sha256sum -c CHECKSUMS.sha256
else
  echo "need shasum or sha256sum" >&2
  exit 2
fi

echo "== data/raw verified against CHECKSUMS.sha256 =="
