#!/usr/bin/env bash
# Allowlist import: copy ONE named file (optionally a line range) from a
# working tree into this repo, then scan the copy. On any hit the copy is
# deleted and only the filename is reported — never the matched content.
# This is the only sanctioned path for code to enter the portfolio.
set -euo pipefail

usage() {
  echo "usage: $(basename "$0") <source-file> <dest-path-in-repo> [start-line end-line]" >&2
  exit 2
}

[[ $# -eq 2 || $# -eq 4 ]] || usage
src="$1"
dest_rel="$2"

repo_root="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
dest="$repo_root/$dest_rel"
DENYLIST="${PORTFOLIO_DENYLIST:-$HOME/.config/portfolio-denylist.txt}"

[[ -f "$src" ]] || { echo "no such source file: $src" >&2; exit 1; }
[[ -r "$DENYLIST" ]] || { echo "deny-list not readable at $DENYLIST" >&2; exit 1; }

DL="$(mktemp)"
trap 'rm -f "$DL"' EXIT
grep -v '^[[:space:]]*$' "$DENYLIST" > "$DL"

mkdir -p "$(dirname "$dest")"
if [[ $# -eq 4 ]]; then
  sed -n "${3},${4}p" "$src" > "$dest"
else
  cp "$src" "$dest"
fi

ok=1
if ! gitleaks dir "$dest" --no-banner --redact >/dev/null 2>&1; then
  echo "REJECTED (gitleaks): secret-shaped content in the excerpt" >&2
  ok=0
fi
if grep -qiFf "$DL" "$dest"; then
  echo "REJECTED (deny-list): identifying string in the excerpt" >&2
  ok=0
fi

if [[ "$ok" -ne 1 ]]; then
  rm -f "$dest"
  echo "import refused; nothing was written to the repo: $dest_rel" >&2
  exit 1
fi

echo "imported: $dest_rel (review by hand before staging)"
