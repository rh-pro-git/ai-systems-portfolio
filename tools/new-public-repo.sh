#!/usr/bin/env bash
# Scaffold a new public project repository to the portfolio standard: fresh git
# history, the fail-closed publish hooks, the professional identity, and a base
# .gitignore. Code is added afterwards by hand (never by copying a .git dir).
#
#   tools/new-public-repo.sh <path> [project-name]
set -euo pipefail

[[ $# -ge 1 ]] || { echo "usage: $(basename "$0") <path> [project-name]" >&2; exit 2; }
target="$1"
name="${2:-$(basename "$target")}"
portfolio="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"

[[ -e "$target/.git" ]] && { echo "refusing: $target is already a git repository" >&2; exit 1; }
mkdir -p "$target"
git -C "$target" init -q -b main

mkdir -p "$target/.githooks"
cp "$portfolio/.githooks/pre-commit" "$portfolio/.githooks/pre-push" "$target/.githooks/"
chmod +x "$target"/.githooks/*
git -C "$target" config core.hooksPath .githooks

# The professional identity is whatever the portfolio repo itself commits as.
git -C "$target" config user.name "$(git -C "$portfolio" config user.name)"
git -C "$target" config user.email "$(git -C "$portfolio" config user.email)"

[[ -f "$target/.gitignore" ]] || cat > "$target/.gitignore" <<'GI'
.venv/
__pycache__/
*.pyc
data/
.env
*.local.md
*.local.*
dist/
.pytest_cache/
.ruff_cache/
GI

cat <<EOF
scaffolded $name at $target
  hooks:    core.hooksPath=.githooks (pre-commit + pre-push, fail-closed)
  identity: $(git -C "$target" config user.name) <$(git -C "$target" config user.email)>
next:
  1. build the project to STANDARDS.md
  2. tools/publish-check.sh $target
  3. create the GitHub repo under the professional account, then:
     git -C $target remote add origin github-portfolio:<account>/$name.git
     git -C $target push -u origin main
EOF
