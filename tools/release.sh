#!/bin/bash
# One release, in the order a release has to happen.
#
#   bash addons/gohud/tools/release.sh             # every check → the ZIP for the version in package.json → verify that ZIP
#   bash addons/gohud/tools/release.sh --export    # also take the verification as far as a Web export
#   bash addons/gohud/tools/release.sh --out DIR   # --out and --full are passed to package.sh
#
# The version is whatever package.json says. Raise it there first; this never raises it.
#
# 🛑 Why this exists
#   The steps were three commands, and the one that is easy to skip is the last — installing the built ZIP
#   into an empty project. On 2026-09-23 the checks stood red in three places and the README inside the ZIP
#   still announced 1.0.1, two releases old, because nothing tied the steps to each other.
#
# 🛑 What it does not do: commit, tag, or upload anything. The closing lines say what is left for a person.
set -eu

ADDON="$(cd "$(dirname "$0")/.." && pwd)"
EXPORT=0
PACKAGE_ARGS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --export) EXPORT=1 ;;
    --full) PACKAGE_ARGS+=("$1") ;;
    --out)
      [ $# -ge 2 ] || { echo "--out needs a destination folder" >&2; exit 2; }
      PACKAGE_ARGS+=("$1" "$2"); shift ;;
    -h|--help) sed -n '2,9p' "$0"; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
  shift
done

step() { printf '\n\033[1m── %s\033[0m\n' "$*"; }

step "① every check — a red check is a release that does not happen"
bash "$ADDON/tools/check_all.sh"

step "② the ZIP for the version in package.json"
PACKAGED="$(bash "$ADDON/tools/package.sh" ${PACKAGE_ARGS+"${PACKAGE_ARGS[@]}"} | tee /dev/stderr)"
ZIP="$(printf '%s\n' "$PACKAGED" | sed -n 's/^✅ //p' | tail -1)"
[ -f "$ZIP" ] || { echo "🛑 could not tell which ZIP was built" >&2; exit 1; }
VERSION="$(printf '%s\n' "$PACKAGED" | sed -n 's/^ *version \([0-9.]*\) .*/\1/p' | tail -1)"

step "③ the ZIP itself, installed into an empty project"
# 🛑 Not the checkout — **the file that goes to the store.** Dependencies on the host project's autoloads,
#    theme or translations only show up where none of them exist.
VERIFY=(--zip "$ZIP" --with-runtime)
[ "$EXPORT" -eq 0 ] || VERIFY+=(--export)
bash "$ADDON/tools/new_project_check.sh" "${VERIFY[@]}"

cat <<REPORT

✅ gohud $VERSION is ready to publish
   $ZIP

Left for a person — none of it is done here:
   1. git add -A && git commit    # plugin.cfg · core/go_ui.gd · CHANGELOG.md carry the version
   2. git tag v$VERSION && git push origin main --tags
   3. Upload the ZIP at https://store.godotengine.org/ (the listing text is .review/DESCRIPTION.md)
REPORT
