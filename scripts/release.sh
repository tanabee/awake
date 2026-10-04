#!/usr/bin/env bash
# Release a new version of awake and update the Homebrew tap.
#
# Usage:
#   scripts/release.sh            # uses AWAKE_VERSION from bin/awake
#   scripts/release.sh 0.3.0      # must match AWAKE_VERSION in bin/awake
#
# Steps:
#   1. Verify the working tree is clean and AWAKE_VERSION matches.
#   2. Push main, create tag vX.Y.Z, push the tag.
#   3. Compute the sha256 of the GitHub tag tarball.
#   4. Update url/sha256 in the tap formula, commit, push.
#
# Env:
#   AWAKE_TAP_DIR   Local clone of tanabee/homebrew-tap (default: ../homebrew-tap).

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TAP_DIR="${AWAKE_TAP_DIR:-$REPO_DIR/../homebrew-tap}"
FORMULA="$TAP_DIR/Formula/awake.rb"
REPO_URL="https://github.com/tanabee/awake"

die() { echo "release: $*" >&2; exit 1; }

cd "$REPO_DIR"

script_version="$(sed -n 's/^AWAKE_VERSION="\(.*\)"$/\1/p' bin/awake)"
[[ -n "$script_version" ]] || die "AWAKE_VERSION not found in bin/awake"

VERSION="${1:-$script_version}"
[[ "$VERSION" == "$script_version" ]] || die "version $VERSION does not match AWAKE_VERSION=$script_version in bin/awake"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "version must look like X.Y.Z"
TAG="v$VERSION"

[[ -z "$(git status --porcelain)" ]] || die "working tree is not clean"
[[ "$(git rev-parse --abbrev-ref HEAD)" == "main" ]] || die "not on main"
git rev-parse -q --verify "refs/tags/$TAG" >/dev/null && die "tag $TAG already exists"

[[ -f "$FORMULA" ]] || die "formula not found: $FORMULA (set AWAKE_TAP_DIR)"
[[ -z "$(git -C "$TAP_DIR" status --porcelain)" ]] || die "tap working tree is not clean: $TAP_DIR"

echo "==> Releasing awake $TAG"

echo "==> Pushing main"
git push origin main

echo "==> Tagging $TAG"
git tag -a "$TAG" -m "$TAG"
git push origin "$TAG"

echo "==> Fetching tarball sha256"
tarball="$REPO_URL/archive/refs/tags/$TAG.tar.gz"
sha=""
for _ in 1 2 3 4 5; do
  sha="$(curl -fsSL "$tarball" | shasum -a 256 | cut -d' ' -f1)" && [[ -n "$sha" ]] && break
  sleep 3
done
[[ -n "$sha" ]] || die "could not download $tarball"
echo "    $sha"

echo "==> Updating formula"
sed -i '' \
  -e "s|archive/refs/tags/v[0-9.]*\.tar\.gz|archive/refs/tags/$TAG.tar.gz|" \
  -e "s|sha256 \".*\"|sha256 \"$sha\"|" \
  "$FORMULA"
git -C "$TAP_DIR" --no-pager diff --stat
git -C "$TAP_DIR" commit -qam "awake $VERSION"
git -C "$TAP_DIR" push

echo ""
echo "Released awake $TAG."
echo "Verify with:"
echo "  brew update && brew upgrade awake && awake --version"
