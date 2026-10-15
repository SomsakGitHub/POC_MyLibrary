#!/bin/bash
set -euo pipefail

# Publishes the MyLibrary binary Swift package to GitHub Releases.
#
# The XCFramework ZIPs are uploaded as release assets. A dedicated release
# branch holds a binary-only Package.swift (root of the tag) whose
# binaryTargets point at those assets, so consumers can add the package with a
# normal git URL and a semantic version:
#
#   .package(url: "https://github.com/<owner>/<repo>.git", from: "<version>")

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${1:?Usage: publish-binary-release.sh VERSION [OUTPUT_DIR]}"

if [[ -f "$ROOT/.github.env" ]]; then
  set -a
  # Local-only settings file; excluded from Git.
  source "$ROOT/.github.env"
  set +a
fi

if [[ -z "${GITHUB_REPO:-}" ]]; then
  ORIGIN="$(git -C "$ROOT" remote get-url origin)"
  GITHUB_REPO="$(echo "$ORIGIN" | sed -E 's#(git@|https://)github.com[:/]##; s#\.git$##')"
fi
: "${GITHUB_REPO:?Set GITHUB_REPO, for example owner/repo}"
RELEASE_BRANCH="${RELEASE_BRANCH:-release}"
TAG_PREFIX="${TAG_PREFIX:-v}"
TAG="${TAG_PREFIX}${VERSION}"

command -v gh >/dev/null || { echo "The GitHub CLI (gh) is required: https://cli.github.com" >&2; exit 1; }
gh auth status >/dev/null 2>&1 || { echo "Not authenticated. Run 'gh auth login' first." >&2; exit 1; }

OUTPUT="${2:-$ROOT/Distribution/output/$VERSION}"
CORE_ZIP="MyLibrarySDKCoreBinary-$VERSION.zip"
FEATURE_ZIP="MyLibrarySDKFeatureBinary-$VERSION.zip"
ASSET_BASE="https://github.com/$GITHUB_REPO/releases/download/$TAG"

if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "VERSION must be semantic (MAJOR.MINOR.PATCH), got: $VERSION" >&2
  exit 1
fi

"$ROOT/scripts/build-binary-release.sh" "$VERSION" "$OUTPUT"

# Render the binary-only manifest with GitHub release asset URLs.
PACKAGE_DIR="$OUTPUT/package"
mkdir -p "$PACKAGE_DIR"
python3 - "$ROOT/Distribution/Package.swift.template" "$PACKAGE_DIR/Package.swift" \
  "$ASSET_BASE/$CORE_ZIP" "$(cat "$OUTPUT/MyLibrarySDKCoreBinary-$VERSION.sha256")" \
  "$ASSET_BASE/$FEATURE_ZIP" "$(cat "$OUTPUT/MyLibrarySDKFeatureBinary-$VERSION.sha256")" <<'PY'
from pathlib import Path
import sys

template, destination, core_url, core_checksum, feature_url, feature_checksum = sys.argv[1:]
content = Path(template).read_text()
for placeholder, value in {
    "@@CORE_URL@@": core_url,
    "@@CORE_CHECKSUM@@": core_checksum,
    "@@FEATURE_URL@@": feature_url,
    "@@FEATURE_CHECKSUM@@": feature_checksum,
}.items():
    content = content.replace(placeholder, value)
if "@@" in content:
    raise SystemExit("Unresolved placeholder in binary Package.swift")
Path(destination).write_text(content)
PY

# Commit the manifest to the release branch without touching the working tree.
if ! git -C "$ROOT" config user.email >/dev/null 2>&1; then
  # CI runners may not have a Git identity configured for commit-tree.
  export GIT_AUTHOR_NAME="MyLibrary Release"
  export GIT_AUTHOR_EMAIL="release@users.noreply.github.com"
  export GIT_COMMITTER_NAME="MyLibrary Release"
  export GIT_COMMITTER_EMAIL="release@users.noreply.github.com"
fi
git -C "$ROOT" fetch origin "$RELEASE_BRANCH" >/dev/null 2>&1 || true
blob="$(git -C "$ROOT" hash-object -w "$PACKAGE_DIR/Package.swift")"
tree="$(printf '100644 blob %s\tPackage.swift\n' "$blob" | git -C "$ROOT" mktree)"
parent_sha=""
if git -C "$ROOT" rev-parse --verify -q "refs/remotes/origin/$RELEASE_BRANCH" >/dev/null; then
  parent_sha="$(git -C "$ROOT" rev-parse "refs/remotes/origin/$RELEASE_BRANCH")"
elif git -C "$ROOT" rev-parse --verify -q "refs/heads/$RELEASE_BRANCH" >/dev/null; then
  parent_sha="$(git -C "$ROOT" rev-parse "refs/heads/$RELEASE_BRANCH")"
fi
if [[ -n "$parent_sha" ]]; then
  commit="$(git -C "$ROOT" commit-tree "$tree" -p "$parent_sha" -m "Release $VERSION")"
else
  commit="$(git -C "$ROOT" commit-tree "$tree" -m "Release $VERSION")"
fi
git -C "$ROOT" update-ref "refs/heads/$RELEASE_BRANCH" "$commit"
git -C "$ROOT" tag -f "$TAG" "$commit"

git -C "$ROOT" push --force origin "refs/heads/$RELEASE_BRANCH:refs/heads/$RELEASE_BRANCH"
# Tags are immutable: a version that already exists must not be republished.
git -C "$ROOT" push origin "refs/tags/$TAG"

# Create the release and upload the archives. Reuse the release if it exists.
if gh release view "$TAG" --repo "$GITHUB_REPO" >/dev/null 2>&1; then
  gh release upload "$TAG" \
    --repo "$GITHUB_REPO" --clobber \
    "$OUTPUT/$CORE_ZIP" "$OUTPUT/$FEATURE_ZIP" \
    "$OUTPUT/MyLibrarySDKCoreBinary-$VERSION.sha256" \
    "$OUTPUT/MyLibrarySDKFeatureBinary-$VERSION.sha256"
else
  gh release create "$TAG" \
    --repo "$GITHUB_REPO" \
    --title "$TAG" \
    --notes "MyLibrary $VERSION binary release." \
    "$OUTPUT/$CORE_ZIP" "$OUTPUT/$FEATURE_ZIP" \
    "$OUTPUT/MyLibrarySDKCoreBinary-$VERSION.sha256" \
    "$OUTPUT/MyLibrarySDKFeatureBinary-$VERSION.sha256"
fi

echo "Published MyLibrary $VERSION"
echo "Repository : https://github.com/$GITHUB_REPO"
echo "Release    : https://github.com/$GITHUB_REPO/releases/tag/$TAG"
