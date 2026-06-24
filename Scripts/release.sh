#!/bin/bash
set -euo pipefail

# Scroll Elevator — Release
# Validates git state, builds + notarizes a DMG, tags the release, creates a
# GitHub release with the DMG + changelog notes, and opens the release folder
# for the Gumroad upload.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

source version.env

GITHUB_REPO="${GITHUB_REPO:-NSEvent/scroll-elevator}"
GUMROAD_URL="${GUMROAD_URL:-https://thekevintang.gumroad.com/l/scroll-elevator}"
TAG="v${MARKETING_VERSION}"

echo "=== Scroll Elevator Release ${MARKETING_VERSION} (${BUILD_NUMBER}) ==="

command -v gh >/dev/null 2>&1 || { echo "Error: GitHub CLI (gh) is required (brew install gh)."; exit 1; }
command -v xcrun >/dev/null 2>&1 || { echo "Error: Xcode command line tools are required."; exit 1; }

# Validate git state
if [[ -n "$(git status --porcelain)" ]]; then
    echo "Error: working tree is not clean. Commit or stash first."
    git status --short
    exit 1
fi

BRANCH="$(git rev-parse --abbrev-ref HEAD)"
if [[ "$BRANCH" != "main" ]]; then
    read -p "Not on main (on $BRANCH). Continue? [y/N] " -n 1 -r; echo
    [[ $REPLY =~ ^[Yy]$ ]] || exit 1
fi

if git rev-parse "$TAG" >/dev/null 2>&1; then
    echo "Error: tag $TAG already exists. Bump version.env first."
    exit 1
fi

echo ""
echo "  Version: ${MARKETING_VERSION}    Build: ${BUILD_NUMBER}    Tag: ${TAG}    Branch: ${BRANCH}"
read -p "Proceed with release? [y/N] " -n 1 -r; echo
[[ $REPLY =~ ^[Yy]$ ]] || exit 1

# Build, sign, notarize, package
"$SCRIPT_DIR/sign-and-notarize.sh"

APP_DMG="$PROJECT_ROOT/release/ScrollElevator-${MARKETING_VERSION}.dmg"
[[ -f "$APP_DMG" ]] || { echo "Error: release artifact not found at $APP_DMG"; exit 1; }

# Tag and push
echo ""
echo "=== Tagging ${TAG} ==="
git tag -a "$TAG" -m "Release ${MARKETING_VERSION}"
git push origin "$TAG"

# Changelog notes: lines under "## <version>" up to the next "## " heading.
RELEASE_NOTES="$(awk -v ver="$MARKETING_VERSION" '
    $0 ~ "^## " ver " " {found=1; next}
    found && /^## / {exit}
    found {print}
' CHANGELOG.md)"
[[ -n "$RELEASE_NOTES" ]] || RELEASE_NOTES="Release ${MARKETING_VERSION}"

echo ""
echo "=== Creating GitHub Release ==="
gh release create "$TAG" \
    --repo "$GITHUB_REPO" \
    --title "Scroll Elevator ${MARKETING_VERSION}" \
    --notes "${RELEASE_NOTES}

---

**[Get Scroll Elevator on Gumroad](${GUMROAD_URL})**" \
    "$APP_DMG"

echo ""
echo "=== Release Complete ==="
echo "Tag:    $TAG"
echo "Release: https://github.com/${GITHUB_REPO}/releases/tag/$TAG"
echo ""
echo "Next: upload $(basename "$APP_DMG") to Gumroad (${GUMROAD_URL})."
open "$PROJECT_ROOT/release"
