#!/bin/bash
# The gohud release ZIP — builds the file uploaded to the Godot Asset Store (store.godotengine.org).
#
#   bash addons/gohud/tools/package.sh                           # patch +1 → builds/<version>/gohud-<version>.zip
#   bash addons/gohud/tools/package.sh --increase-minor-version  # minor +1, patch = 0
#   bash addons/gohud/tools/package.sh --out DIR                 # change where it is written (the version is still bumped)
# Needs Python 3. Only on success are plugin.cfg, GoUi.VERSION and CHANGELOG.md updated together.
#
# Paths inside the ZIP are always `addons/gohud/...` — unpacking it at the **project root** installs it as-is.
#
# 🛑 Keeping `addons/` at the top level is a requirement, not a preference.
#    Godot's asset installer strips the common top-level folder of a ZIP, leaving only `addons/`:
#        skip_toplevel = p_autoskip_toplevel && toplevel_prefix != "addons/";
#        (godot/editor/asset_library/editor_asset_installer.cpp)
#    So a top level of `gohud/` gets stripped by the editor and
#    core/, widgets/ and icons/ scatter across someone else's project root.
#
# 🛑 Gates — if any one trips, no ZIP is built
#   ① the version in plugin.cfg and GoUi.VERSION are the same
#   ② LICENSE, README.md, THIRD_PARTY_NOTICES.md and CHANGELOG.md exist
#   ③ a new version entry is created and the Unreleased notes moved into it — stop if that version already exists
#   ④ no code, scene or resource points at a `res://` **outside** the addon — that breaks in someone else's project
#   ⑤ no secrets inside the ZIP (.env, API keys)
#   ⑥ every entry in the ZIP is under `addons/gohud/`
#   ⑦ no symlinks in the ZIP — they become broken links where it is installed
#   ⑧ the files the store requires (LICENSE, plugin.cfg) are in the ZIP
#   ⑨ every res:// a scene or resource points at really is in the ZIP — otherwise the scene will not open where it is installed
#   ⑩ no project.godot in the ZIP — one makes the installing editor warn
set -eu

ADDON="$(cd "$(dirname "$0")/.." && pwd)"
FULL=0
OUT=""
INCREASE="patch"
while [ $# -gt 0 ]; do
  case "$1" in
    --full) FULL=1 ;;                       # include tools/ as well (internal distribution — never for the store)
    --increase-minor-version) INCREASE="minor" ;;
    --out)
      [ $# -ge 2 ] && [ -n "$2" ] && [[ "$2" != --* ]] || { echo "--out needs a destination folder" >&2; exit 2; }
      shift; OUT="$1" ;;
    -h|--help) sed -n '2,8p' "$0"; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
  shift
done

fail() { echo "🛑 $*" >&2; exit 1; }

# Serialize: two runs on the same checkout must not produce the same next version.
mkdir -p "$ADDON/builds"
LOCK="$ADDON/builds/.package-lock"
mkdir "$LOCK" 2>/dev/null || fail "another packaging run is in progress ($LOCK)"
STAGE=""
cleanup() {
  [ -z "$STAGE" ] || rm -rf "$STAGE"
  rmdir "$LOCK"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# ── ① version ───────────────────────────────────────────────────────────
VERSION="$(sed -n 's/^version="\(.*\)"$/\1/p' "$ADDON/plugin.cfg")"
[ -n "$VERSION" ] || fail "could not read version from plugin.cfg"
CODE_VERSION="$(sed -n 's/^const VERSION := "\(.*\)"$/\1/p' "$ADDON/core/go_ui.gd")"
[ "$VERSION" = "$CODE_VERSION" ] || fail "version mismatch — plugin.cfg=$VERSION · GoUi.VERSION=$CODE_VERSION"

# ── ② documents ─────────────────────────────────────────────────────────
for doc in LICENSE README.md THIRD_PARTY_NOTICES.md CHANGELOG.md; do
  [ -f "$ADDON/$doc" ] || fail "$doc is missing"
done

# ── ④ references outside the addon ──────────────────────────────────────
# Comment lines (`#`) are usage examples, so they are excluded. `tests/` and `tools/` hold
# `res://addons/gohud` as a plain string and would false-alarm — and neither ships in the release.
# `examples/demo/` is a separate project with its own project.godot, so its `res://` points at the demo root.
# `examples/usage/` is a project that installs and uses a copy of the addon, and is excluded from the release.
# `skills/` is the AI agent skill (a Claude Code plugin) — its templates use the host project's `res://ui/…` as an example. It does not ship either.
LEAKS="$(grep -rnE 'res://' "$ADDON" --include='*.gd' --include='*.tscn' --include='*.tres' --include='*.cfg' \
  | grep -vE '/(tests|tools|skills)/|/examples/(demo|usage)/' \
  | grep -vE '^[^:]+:[0-9]+:[[:space:]]*#' \
  | grep -oE '^[^:]+:[0-9]+:|res://[A-Za-z0-9_./%-]+' \
  | awk 'index($0, "res://") == 1 { if (index($0, "res://addons/gohud") != 1) print prev $0; next } { prev = $0 }' || true)"
[ -z "$LEAKS" ] || { echo "$LEAKS" >&2; fail "there is a res:// reference pointing outside the addon"; }

# ── staging ─────────────────────────────────────────────────────────────
STAGE="$(mktemp -d)"
mkdir -p "$STAGE/addons/gohud"

# 🛑 `builds/` is not a dot folder, so Godot imports it — block the scan with a `.gdignore`.
[ -f "$ADDON/builds/.gdignore" ] || {
  mkdir -p "$ADDON/builds"
  printf '# A store of release ZIPs — nothing here for Godot to scan.\n' > "$ADDON/builds/.gdignore"
}

# Exclusion list — things with no reason to be in an installation.
#   🛑 `.env`     holds the store API key. It must never get out, whatever happens.
#   🛑 `.git*`    .git, .gitignore, .gitattributes, .github — repository housekeeping.
#                 (`.gdignore` starts with `.gd` and does not match this pattern — it is needed after installation, so it stays.)
#   🛑 `.claude`  agent working configuration.
#   🛑 `.cowork`  output of the cowork 5-AI analysis. Internal notes of a personal tool — they must not ship.
#   🛑 `.review`  store submission promo images. Including them makes the ZIP 20x bigger.
#   🛑 `www`      the GitHub Pages site (836KB). Not needed to use the addon.
#   🛑 `docs`     site editing and deployment notes, plus work records. Not needed to use the addon.
#   🛑 `tests`    for checks only. The user does not need them.
#   🛑 `.godot`   the import cache. Not valid in someone else's project.
#   🛑 `examples/demo/addons` is a **symlink** to the addon root — it becomes a broken link where it is installed.
set -- \
  --exclude='.env' \
  --exclude='.git*' \
  --exclude='.claude' \
  --exclude='.cowork' \
  --exclude='/.claude-plugin/' \
  --exclude='/skills/' \
  --exclude='.review' \
  --exclude='.playwright-mcp' \
  --exclude='docs' \
  --exclude='/www/' \
  --exclude='review' \
  --exclude='.godot' \
  --exclude='.dist' \
  --exclude='builds' \
  --exclude='.DS_Store' \
  --exclude='tests' \
  --exclude='tests/_*' \
  --exclude='*.tmp' \
  --exclude='*.zip' \
  --exclude='*.py[co]' \
  --exclude='__pycache__' \
  --exclude='/examples/usage/' \
  --exclude='examples/demo/addons'
# 🛑 `docs/` is **the website** — it is published to GitHub Pages, not shipped with the asset.
#    Including it ① adds hundreds of KB of screenshots to the asset size and ② makes its command
#    examples (`res://…/tests/…`) point at a `tests/` absent from the store ZIP, **tripping the broken-reference gate** (measured 2026-09-13).
if [ "$FULL" -eq 0 ]; then set -- "$@" --exclude='tools' --exclude='docs'; fi

rsync -a --no-links "$@" "$ADDON/" "$STAGE/addons/gohud/"

# The version and changelog are prepared on the copy. The original is updated only once every ZIP check passes.
PREVIOUS_VERSION="$VERSION"
VERSION="$(python3 "$ADDON/tools/package_version.py" prepare "$STAGE" "$INCREASE")"
DIST="${OUT:-$ADDON/builds/$VERSION}"
mkdir -p "$DIST"
DIST="$(cd "$DIST" && pwd)"
DESTINATION="$DIST/gohud-$VERSION.zip"
[ ! -e "$DESTINATION" ] || fail "a ZIP of the same version already exists: $DESTINATION"
ZIP="$STAGE/package.zip"

# 🛑 A nested project.godot makes the installing editor warn:
#      WARNING: Detected another project.godot at res://addons/gohud/examples/demo
#    The file is needed to open the demo as its own project, so instead of dropping it we rename it to sleep.
#    `bash examples/demo/run.sh` wakes it again.
DEMO="$STAGE/addons/gohud/examples/demo"
[ ! -f "$DEMO/project.godot" ] || mv "$DEMO/project.godot" "$DEMO/project.godot.demo"

# ── ⑨ broken references ─────────────────────────────────────────────────
# 🛑 Move a file and forget to fix a scene's reference, and whoever installs it sees:
#      Error loading: gallery.tscn — Load failed due to missing dependencies
#    Gate ④ only looks at references pointing **outside** the addon. This one catches references
#    **inside** the addon that point at a file which is not actually in the ZIP.
BROKEN="$(grep -rhoE 'res://addons/gohud/[A-Za-z0-9_./%-]+' "$STAGE" 2>/dev/null | sort -u \
  | while read -r ref; do [ -e "$STAGE/addons/gohud/${ref#res://addons/gohud/}" ] || echo "  $ref"; done)"
[ -z "$BROKEN" ] || { echo "$BROKEN" >&2; fail "there is a res:// reference to a file that is not in the ZIP"; }

# ── ⑤ secrets ───────────────────────────────────────────────────────────
SECRETS="$(find "$STAGE" \( -name '.env' -o -name '.env.*' -o -name '*.pem' -o -name '*.key' -o -name '*.p8' \) -print || true)"
[ -z "$SECRETS" ] || { echo "$SECRETS" >&2; fail "a secret file made it into staging"; }
KEYS="$(grep -rlE 'GD_STORE_|AKIA[0-9A-Z]{16}|-----BEGIN [A-Z ]*PRIVATE KEY-----' "$STAGE" || true)"
[ -z "$KEYS" ] || { echo "$KEYS" >&2; fail "a string that looks like an API key or private key got in"; }

# ── ⑦ symlinks ──────────────────────────────────────────────────────────
LINKS="$(find "$STAGE" -type l -print || true)"
[ -z "$LINKS" ] || { echo "$LINKS" >&2; fail "a symlink got in"; }

# ── zip it ──────────────────────────────────────────────────────────────
( cd "$STAGE" && zip -qrX "$ZIP" addons )

# ── ⑥ paths ─────────────────────────────────────────────────────────────
BAD="$(unzip -Z1 "$ZIP" | grep -v '^addons/gohud/' | grep -v '^addons/$' || true)"
[ -z "$BAD" ] || fail "the ZIP has entries outside addons/gohud/: $BAD"

# ── ⑩ nested project ────────────────────────────────────────────────────
NESTED="$(unzip -Z1 "$ZIP" | grep -E '/project\.godot$' || true)"
[ -z "$NESTED" ] || { echo "$NESTED" >&2; fail "the ZIP contains a project.godot — the installing editor will warn"; }

# ── ⑧ files the store requires ──────────────────────────────────────────
# The store upload form: "Assets must be uploaded as .zip and must contain a license file."
for need in addons/gohud/LICENSE addons/gohud/plugin.cfg addons/gohud/README.md; do
  unzip -Z1 "$ZIP" | grep -qx "$need" || fail "the ZIP has no $need"
done

COUNT="$(unzip -Z1 "$ZIP" | grep -vc '/$')"
SIZE="$(du -h "$ZIP" | cut -f1 | tr -d ' ')"
python3 "$ADDON/tools/package_version.py" publish "$ADDON" "$STAGE" "$DESTINATION"
echo "✅ $DESTINATION"
echo "   version bumped automatically: $PREVIOUS_VERSION → $VERSION"
echo "   version $VERSION · $COUNT files · $SIZE · $([ "$FULL" -eq 1 ] && echo 'full (tools included)' || echo 'for the store')"
