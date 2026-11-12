#!/bin/zsh
# Packs Settling In.app into a disk image people drag to install: the app on
# the left, an Applications shortcut on the right, and a background with an
# arrow between them.
#
#   scripts/make-dmg.sh "path/to/Settling In.app" out.dmg
#
# Doesn't sign or notarize; scripts/notarize.sh does that afterwards.
# Fetches dmgbuild into vendor/dmgbuild the first time.
set -euo pipefail
cd "$(dirname "$0")/.."

APP=${1:?usage: make-dmg.sh "path/to/Settling In.app" out.dmg}
DMG=${2:?usage: make-dmg.sh "path/to/Settling In.app" out.dmg}
[[ -d "$APP" ]] || { echo "No app at $APP" >&2; exit 1; }

DMGBUILD_VERSION=1.6.5
TOOL=vendor/dmgbuild
if [[ "$(cat $TOOL/VERSION 2>/dev/null)" != "$DMGBUILD_VERSION" ]]; then
    echo "Fetching dmgbuild $DMGBUILD_VERSION" >&2
    rm -rf "$TOOL"
    python3 -m venv "$TOOL"
    "$TOOL/bin/pip" install -q --disable-pip-version-check "dmgbuild==$DMGBUILD_VERSION"
    echo "$DMGBUILD_VERSION" > "$TOOL/VERSION"
fi

ART=$(mktemp -d)
trap 'rm -rf "$ART"' EXIT
swift scripts/dmg-background.swift "$ART"

rm -f "$DMG"
"$TOOL/bin/dmgbuild" -s scripts/dmg-settings.py \
    -D app="$APP" -D background="$ART/background.png" \
    "Settling In" "$DMG" >&2
echo "$DMG"
