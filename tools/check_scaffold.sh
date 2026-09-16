#!/bin/bash
# 🎨 **Can a theme be added with one file?** — scaffold → generate → contrast check → revert, in one go.
#
#   bash addons/gohud/tools/check_scaffold.sh
#
# Why it is needed
#   This is the promise made to the request "more themes are coming" (2026-09-13): one line of
#   `new_theme.py` creates the palette JSON and the preset, `make_theme.py` builds the rest, and the
#   result **passes the readability check as it stands**. Break any of the four and whoever adds a theme is stuck at step one.
#
# Everything is created and removed on a temporary copy, so no editor or other task ever reads the temporary preset.
set -uo pipefail
ADDON="$(cd "$(dirname "$0")/.." && pwd)"
if [ -z "${GOHUD_SCAFFOLD_ISOLATED:-}" ]; then
  WORK="$(mktemp -d)"
  trap 'rm -rf "$WORK"' EXIT
  for folder in core themes assets tools; do
    rsync -a "$ADDON/$folder/" "$WORK/$folder/" || exit 1
  done
  GOHUD_SCAFFOLD_ISOLATED=1 bash "$WORK/tools/check_scaffold.sh"
  exit $?
fi
ID="zz_scaffold_probe"
cleanup() { python3 "$ADDON/tools/new_theme.py" --remove "$ID" > /dev/null 2>&1; }
trap cleanup EXIT
FAILED=0

# 🛑 The dial table is generated — edit an `@export` default in a skin script without rerunning the generator and it goes stale.
BEFORE_TABLE="$(cat "$ADDON/tools/skin_dials.json")"
python3 -c "import sys; sys.path.insert(0, '$ADDON/tools'); import make_theme; make_theme.write_skin_dials_table()"
[ "$BEFORE_TABLE" = "$(cat "$ADDON/tools/skin_dials.json")" ] \
  && echo "   the dial table matches the skin scripts" || { echo "🛑 the dial table was stale — it has just been rebuilt, so commit it"; FAILED=1; }
DIAL_COUNT=$(python3 -c "import json;t=json.load(open('$ADDON/tools/skin_dials.json'));print(sum(len(v) for v in t.values() if isinstance(v, dict)))")
[ "$DIAL_COUNT" -ge 20 ] && echo "   parsed $DIAL_COUNT dials" || { echo "🛑 only $DIAL_COUNT dials parsed — the parser is broken"; FAILED=1; }

python3 "$ADDON/tools/new_theme.py" "$ID" --from scifi_light --title "Probe" > /dev/null || { echo "🛑 scaffolding failed"; exit 1; }
[ -f "$ADDON/themes/palettes/$ID.json" ] && [ -f "$ADDON/themes/presets/$ID.tres" ] \
  && echo "   palette JSON and preset resource created" || { echo "🛑 the files were not created"; FAILED=1; }

# **Actually change** the palette — to see that overriding works, not just inheriting.
python3 - "$ADDON/themes/palettes/$ID.json" <<'PY'
import json, sys
p = sys.argv[1]; spec = json.load(open(p, encoding="utf-8"))
spec["palette"]["accent"] = "#C77DFF"
spec["shape"]["radius"] = 4
spec["skin"]["dials"]["slot_border_lit"] = 3     # skin numbers change from the JSON too
json.dump(spec, open(p, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
PY
python3 "$ADDON/tools/make_theme.py" "$ID" > /tmp/gohud_scaffold.log 2>&1 || { echo "🛑 generation failed:"; tail -5 /tmp/gohud_scaffold.log; FAILED=1; }
grep -q "gohud_$ID.tres" /tmp/gohud_scaffold.log && echo "   theme .tres generated" || FAILED=1
grep -q '^GoHud/constants/radius = 4$' "$ADDON/themes/gohud_$ID.tres" \
  && echo "   the shape radius=4 reached the tokens" || { echo "🛑 the shape override never reached the tokens"; FAILED=1; }
# 🛑 Do not look for the written color verbatim — the generator **pushes** it until it is readable, so the file holds an adjusted value.
#    Check instead whether it "differs from the accent of the parent theme".
if [ "$(grep '^GoHud/colors/accent = ' "$ADDON/themes/gohud_$ID.tres")" != "$(grep '^GoHud/colors/accent = ' "$ADDON/themes/gohud_scifi_light.tres")" ]; then
  echo "   the palette accent came through (after adjustment)"
else
  echo "🛑 the palette override had no effect"; FAILED=1
fi
[ -d "$ADDON/assets/$ID" ] && echo "   control artwork folder created" || { echo "🛑 the artwork folder is missing"; FAILED=1; }
grep -q '^slot_border_lit = 3$' "$ADDON/themes/skins/gohud_skin_$ID.tres" 2>/dev/null \
  && echo "   the skin dials reached the skin resource" || { echo "🛑 the skin dials never reached the resource"; FAILED=1; }
grep -q 'gohud_skin_'"$ID"'.tres' "$ADDON/themes/presets/$ID.tres" \
  && echo "   the preset points at its own skin resource" || { echo "🛑 the preset does not point at a skin"; FAILED=1; }

# A new theme must **pass the readability check as it stands** — inherited values go through adjustment, so passing is the norm.
if python3 "$ADDON/tools/check_contrast.py" --quiet > "$ADDON/contrast.log" 2>&1; then
  echo "   the new theme passes the contrast check"
else
  tail -12 "$ADDON/contrast.log"
  echo "🛑 the new theme trips the contrast check"; FAILED=1
fi

# A JSON preset can itself be a parent; preserve its fonts, icons, shape and skin dials.
python3 - "$ADDON" <<'PY_CHECK' || FAILED=1
from pathlib import Path
import json, subprocess, sys
root = Path(sys.argv[1])
def run(*args, ok=True):
    result = subprocess.run([sys.executable, str(root / 'tools' / args[0]), *args[1:]], capture_output=True, text=True)
    assert (result.returncode == 0) == ok, result.stdout + result.stderr
    return result
ident = 'zz_medieval_probe'
run('new_theme.py', ident, '--from', 'medieval_dark')
p = root / 'themes/palettes' / (ident + '.json')
spec = json.loads(p.read_text())
assert spec['shape']['kind'] == 'medieval' and spec['skin']['base'] == 'medieval'
assert spec['icons'].endswith('gohud_icons_medieval.tres')
# Sparse overrides must retain all other inherited values.
spec['skin'] = {'dials': {'slot_rivets': 0}}
spec['shape'] = {'ornament_scale': 0.75}
p.write_text(json.dumps(spec))
run('make_theme.py', ident)
theme = (root / 'themes' / ('gohud_' + ident + '.tres')).read_text()
skin = (root / 'themes/skins' / ('gohud_skin_' + ident + '.tres')).read_text()
preset = (root / 'themes/presets' / (ident + '.tres')).read_text()
assert 'Cinzel.ttf' in theme and 'ornament_scale = 0.75' in theme
assert 'slot_rivets = 0' in skin and 'slot_tint_lit = 0.14' in skin
assert 'gohud_icons_medieval.tres' in preset
run('check_contrast.py', '--quiet')
spec['from'] = ident
p.write_text(json.dumps(spec))
cycle = run('make_theme.py', ident, ok=False)
assert 'inheritance cycle' in cycle.stdout + cycle.stderr
run('new_theme.py', '--remove', ident)
print('   Medieval parent: fonts, icons, sparse dials, contrast and cycle detection passed')
PY_CHECK

if [ "$FAILED" -eq 0 ]; then echo "✅ theme scaffolding — one file makes a theme"; else echo "🛑 scaffolding is broken"; fi
exit "$FAILED"
