#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <directory_with_sh_files>"
    exit 1
fi

ROOT_DIR="$1"
OUTPUT_FILE="modules_summary.csv"

# CSV header
printf 'file,description,module_wait\n' > "$OUTPUT_FILE"

csv_escape() {
  # Escape double quotes for CSV and wrap in quotes
  local s=${1//\"/\"\"}
  printf '"%s"' "$s"
}

# Traverse all .sh files under the provided directory
find "$ROOT_DIR" -type f -name '*.sh' -print0 | while IFS= read -r -d '' file; do
  # Extract Description block (first "# Description:" and following comment lines)
  description=$(
    awk '
      /^#[[:space:]]*[Dd]escription:/ {
          found = 1
          line = $0
          sub(/^#[[:space:]]*[Dd]escription:[[:space:]]*/, "", line)
          desc = line
          next
      }
      found && /^#[[:space:]]/ {
          line = $0
          sub(/^#[[:space:]]*/, "", line)
          if (desc != "") desc = desc " "
          desc = desc line
          next
      }
      found {
          # Stop at first non-comment line after description block
          exit
      }
      END {
          if (desc != "") print desc
      }
    ' "$file"
  )

  # Extract all module_wait "X" occurrences and join them with "; "
  module_waits=$(
    awk '
      match($0, /module_wait[[:space:]]*"([^"]*)"/, m) {
          arr[++n] = m[1]
      }
      END {
          for (i = 1; i <= n; i++) {
              if (i > 1) printf "; "
              printf "%s", arr[i]
          }
      }
    ' "$file"
  )

  description=${description:-}
  module_waits=${module_waits:-}

  {
    csv_escape "$file"
    printf ','
    csv_escape "$description"
    printf ','
    csv_escape "$module_waits"
    printf '\n'
  } >> "$OUTPUT_FILE"
done

echo "Done. Results saved to: $OUTPUT_FILE"

