#!/usr/bin/env bash
# Cut a CalVer release: stamp CHANGELOG, bump _meta.lua, commit, tag.
# Usage: ./scripts/release.sh [VERSION]   (VERSION defaults to today: YYYY.MM.DD)
#   DRY_RUN=1 ./scripts/release.sh [VERSION]   prints planned changes, mutates nothing
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
META="src/_meta.lua"
CHANGELOG="CHANGELOG.md"

# 1. Resolve VERSION. Default = today; if a same-day tag exists, append .N.
VERSION="${1:-$(date +%Y.%m.%d)}"
if [ -z "${1:-}" ]; then
  base="$VERSION"; n=1
  while git rev-parse -q --verify "refs/tags/v$VERSION" >/dev/null 2>&1; do
    VERSION="$base.$n"; n=$((n + 1))
  done
fi
TAG="v$VERSION"
echo "Preparing release $TAG"

# 2. [Unreleased] must have content.
unreleased="$(awk '/^## \[Unreleased\]/{f=1;next} /^## \[/{f=0} f' "$CHANGELOG")"
if ! printf '%s' "$unreleased" | grep -q '[^[:space:]]'; then
  echo "ERROR: CHANGELOG [Unreleased] is empty — add notes before releasing." >&2
  exit 1
fi

# 3. Compute the new CHANGELOG and _meta.lua (into temp files).
TODAY="$(date +%Y-%m-%d)"
cl_tmp="$(mktemp)"; meta_tmp="$(mktemp)"
trap 'rm -f "$cl_tmp" "$meta_tmp"' EXIT

awk -v ver="$VERSION" -v date="$TODAY" '
  /^## \[Unreleased\]/ { print "## [Unreleased]"; print ""; print "## [" ver "] - " date; next }
  { print }
' "$CHANGELOG" > "$cl_tmp"

sed -E "s/(version[[:space:]]*=[[:space:]]*\")[^\"]*(\")/\1$VERSION\2/" "$META" > "$meta_tmp"

# 4. DRY_RUN: show diffs, change nothing.
if [ -n "${DRY_RUN:-}" ]; then
  echo "=== DRY RUN: $CHANGELOG diff ==="; diff -u "$CHANGELOG" "$cl_tmp" || true
  echo "=== DRY RUN: $META diff ==="; diff -u "$META" "$meta_tmp" || true
  echo "=== Would create tag: $TAG ==="
  exit 0
fi

# 5. Guardrails for a real release.
[ "$(git rev-parse --abbrev-ref HEAD)" = "main" ] || { echo "ERROR: not on main." >&2; exit 1; }
git diff --quiet && git diff --cached --quiet || { echo "ERROR: working tree not clean." >&2; exit 1; }
git rev-parse -q --verify "refs/tags/$TAG" >/dev/null 2>&1 && { echo "ERROR: tag $TAG already exists." >&2; exit 1; }

# 6. Apply, commit, tag (no push — pushing the tag triggers release.yml).
cp "$cl_tmp" "$CHANGELOG"
cp "$meta_tmp" "$META"
git add "$CHANGELOG" "$META"
git commit -m "release: $TAG"
git tag "$TAG"
echo "Done. Review, then push: git push origin main $TAG"
