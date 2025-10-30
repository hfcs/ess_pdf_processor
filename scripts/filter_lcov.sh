#!/usr/bin/env bash
set -euo pipefail
# Usage: scripts/filter_lcov.sh [INPUT_LCOV] [OUTPUT_LCOV]
#
# Removes DA (line coverage) entries for a specific file and range of lines
# so those lines will not be counted in downstream HTML reports.

INPUT=${1:-coverage/lcov.info}
OUTPUT=${2:-coverage/lcov.filtered.info}

TARGET_PATH="lib/parser/text_parser.dart"
START_LINE=83
END_LINE=107

if [ ! -f "$INPUT" ]; then
  echo "Input LCOV file not found: $INPUT" >&2
  exit 1
fi

awk -v target="$TARGET_PATH" -v start=$START_LINE -v end=$END_LINE '
  /^SF:/ { sf = substr($0,4); print; next }
  /^DA:/ {
    if (index(sf, target)) {
      split($0, a, /[:,]/)
      ln = a[2] + 0
      if (ln >= start && ln <= end) next
    }
    print; next
  }
  { print }
' "$INPUT" > "$OUTPUT"

echo "Wrote filtered LCOV to $OUTPUT (removed $TARGET_PATH lines $START_LINE-$END_LINE)."
