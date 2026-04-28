#!/usr/bin/env bash
# Refresh the prompt cookbooks bundled with this skill.
#
# Pulls the latest README.md from the upstream YouMind-OpenLab awesome repos
# and writes them into references/. Run at the start of every skill
# invocation so the cookbook content is current.
#
# Network failures are NOT fatal — the existing local copy is preserved and a
# warning is printed, so the skill can still operate against stale data.
#
# Usage:
#   bash scripts/refresh_references.sh           # refresh both cookbooks
#   bash scripts/refresh_references.sh --quiet   # only print on failure

set -uo pipefail

quiet=0
case "${1:-}" in
  --quiet) quiet=1 ;;
  --help|-h)
    sed -n '2,13p' "$0"
    exit 0
    ;;
  "") ;;
  *)
    echo "Unknown argument: $1" >&2
    exit 2
    ;;
esac

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REFERENCES_DIR="$(cd "$SCRIPT_DIR/.." && pwd)/references"
mkdir -p "$REFERENCES_DIR"

# repo path => target filename
declare -a sources=(
  "YouMind-OpenLab/awesome-gpt-image-2|awesome-gpt-image-2.md"
  "YouMind-OpenLab/awesome-nano-banana-pro-prompts|awesome-nano-banana-pro-prompts.md"
)

failures=0
for entry in "${sources[@]}"; do
  repo="${entry%%|*}"
  fname="${entry##*|}"
  url="https://raw.githubusercontent.com/${repo}/main/README.md"
  target="$REFERENCES_DIR/$fname"

  # Download to a tempfile first so a partial response never overwrites the
  # existing copy.
  tmp="$(mktemp -t "${fname}.XXXXXX")"
  if curl -sfL --max-time 30 -o "$tmp" "$url"; then
    if [ -s "$tmp" ]; then
      mv "$tmp" "$target"
      if [ "$quiet" -eq 0 ]; then
        bytes=$(wc -c < "$target" | tr -d ' ')
        lines=$(wc -l < "$target" | tr -d ' ')
        printf 'refreshed %s  (%s lines, %s bytes)\n' "$fname" "$lines" "$bytes"
      fi
    else
      rm -f "$tmp"
      echo "warning: $url returned empty body, kept previous local copy" >&2
      failures=$((failures + 1))
    fi
  else
    rm -f "$tmp"
    if [ -f "$target" ]; then
      echo "warning: failed to fetch $url, kept previous local copy at $target" >&2
    else
      echo "error: failed to fetch $url and no local copy exists at $target" >&2
    fi
    failures=$((failures + 1))
  fi
done

# Exit 0 even on partial failure — the skill can still run against the local
# copy. Only return non-zero if no cookbook is available at all.
if [ "$failures" -eq "${#sources[@]}" ]; then
  # All refresh attempts failed; check whether any local copy exists.
  any_local=0
  for entry in "${sources[@]}"; do
    fname="${entry##*|}"
    [ -f "$REFERENCES_DIR/$fname" ] && any_local=1
  done
  if [ "$any_local" -eq 0 ]; then
    exit 1
  fi
fi
exit 0
