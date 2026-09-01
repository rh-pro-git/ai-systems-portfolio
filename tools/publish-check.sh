#!/usr/bin/env bash
# Pre-publication gate for any repository headed for the professional account.
# Fail-closed: every check must pass. Run before the first push and every release.
#
#   tools/publish-check.sh <repo-path>
set -euo pipefail

[[ $# -eq 1 ]] || { echo "usage: $(basename "$0") <repo-path>" >&2; exit 2; }
repo="$(cd "$1" && pwd)"
DENYLIST="${PORTFOLIO_DENYLIST:-$HOME/.config/portfolio-denylist.txt}"
status=0

pass() { echo "  ok    $*"; }
fail() { echo "  FAIL  $*" >&2; status=1; }

echo "publish-check: $repo"

[[ -d "$repo/.git" ]] || { fail "not a git repository"; exit 1; }
[[ "$(git -C "$repo" config core.hooksPath || true)" == ".githooks" ]] && pass "hooks wired" || fail "core.hooksPath is not .githooks"
[[ -x "$repo/.githooks/pre-commit" && -x "$repo/.githooks/pre-push" ]] && pass "hook scripts present" || fail "hook scripts missing"

email="$(git -C "$repo" config user.email || true)"
name="$(git -C "$repo" config user.name || true)"
[[ -n "$email" && -n "$name" ]] && pass "identity set" || fail "git identity unset"

[[ -r "$DENYLIST" ]] || { fail "deny-list unreadable at $DENYLIST"; exit 1; }
DL="$(mktemp)"; trap 'rm -f "$DL"' EXIT
grep -v '^[[:space:]]*$' "$DENYLIST" > "$DL"
if printf '%s\n%s\n' "$email" "$name" | grep -qiFf "$DL"; then fail "identity matches deny-list"; fi

if git -C "$repo" rev-parse HEAD >/dev/null 2>&1; then
  command -v gitleaks >/dev/null || { fail "gitleaks not installed"; exit 1; }
  if gitleaks git --no-banner --redact "$repo" >/dev/null 2>&1; then pass "gitleaks: history clean"; else fail "gitleaks found secret-shaped content in history"; fi
  hits="$(git -C "$repo" grep -l -i -F -f "$DL" HEAD -- 2>/dev/null || true)"
  [[ -z "$hits" ]] && pass "deny-list: tracked files clean" || fail "deny-listed identifier in: $(echo "$hits" | tr '\n' ' ')"
  # Infrastructure-shaped strings that a deny-list of names would not catch.
  shapes='\.ts\.net|192\.168\.[0-9]+\.[0-9]+|10\.[0-9]+\.[0-9]+\.[0-9]+|/home/[a-z][a-z0-9_-]*/|/Users/[A-Za-z][A-Za-z0-9_-]*/|tail[0-9a-f]{6}'
  shape_hits="$(git -C "$repo" grep -l -E -e "$shapes" HEAD -- 2>/dev/null || true)"
  [[ -z "$shape_hits" ]] && pass "no infrastructure-shaped strings" || fail "infrastructure-shaped string in: $(echo "$shape_hits" | tr '\n' ' ')"
else
  echo "  --    no commits yet: history checks skipped"
fi

# Working tree too, so an uncommitted file cannot slip through the next commit unnoticed.
tree_hits="$(grep -rIl -i -F -f "$DL" "$repo" --exclude-dir=.git --exclude-dir=.venv --exclude-dir=node_modules 2>/dev/null || true)"
[[ -z "$tree_hits" ]] && pass "deny-list: working tree clean" || fail "deny-listed identifier in working tree: $(echo "$tree_hits" | tr '\n' ' ')"

for f in README.md LICENSE; do [[ -f "$repo/$f" ]] && pass "$f present" || fail "$f missing"; done

[[ $status -eq 0 ]] && echo "publish-check: PASS" || echo "publish-check: FAIL" >&2
exit $status
