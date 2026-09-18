#!/bin/bash
# 🧪 **Every gohud check** in one go. After a change, this is the only thing you need to run.
#
#   bash addons/gohud/tools/check_all.sh
#   GOHUD_PROJECT=/path/to/project bash .../check_all.sh     # pick the project to verify against
#   GODOT_46=/path/to/Godot4.6 bash .../check_all.sh          # unit tests on both engines
#
# Why they are bundled
#   The checks come in three kinds — because **each can see a different range**.
#     ① unit tests (Godot)      widget behavior · contrast of colors the skin builds at runtime
#     ② contrast check (Python) color pairs in the theme .tres and text on plates per button state
#     ③ site check (Python)     links, images and glossary of www (English at the root, ko/ in Korean)
#   Remembering to run them separately always drops one. So there is a single entry point.
#
# 🛑 4.6 compatibility cannot be verified with 4.7. Give `GODOT_46` and the unit tests run on **both engines**.
set -uo pipefail

ADDON="$(cd "$(dirname "$0")/.." && pwd)"
FAILED=0

step() { printf "\n\033[1m── %s\033[0m\n" "$1"; }

step "① unit tests"
bash "$ADDON/tools/run_tests.sh" || FAILED=1

step "①-a unit tests — later widgets"
# 🔑 Later arrivals such as the snackbar, spinner, badge and table live in a separate file
#    (`gohud_test.gd` is already over 2000 lines). **Two entry points means forgetting one** — so they are called side by side here.
GOHUD_TEST_SCRIPT="res://addons/gohud/tests/gohud_extra_test.gd" \
  bash "$ADDON/tools/run_tests.sh" || FAILED=1

step "①-t unit tests — the five templates the skill ships"
# 🛑 `skills/gohud/assets/templates/` is **code people copy into their own project and use as-is**,
#    yet until 2026-09-16 no check opened any of those five (the docs said "headless-tested").
#    A duplicated function name was left behind while editing a template, and this check caught it.
GOHUD_TEST_SCRIPT="res://addons/gohud/tests/gohud_templates_test.gd" \
  bash "$ADDON/tools/run_tests.sh" || FAILED=1

# 🛑 **Running one screen size leaves code that only runs on other sizes entirely unverified.** The
#    form width cap was such a case (on a phone the cap is "none"), as was the HUD moving sideways — so the same tests run again at different sizes.
for VIEWPORT in 844x390 768x1024 1280x800; do
  step "①-$VIEWPORT unit tests — another screen"
  GOHUD_VIEWPORT="$VIEWPORT" bash "$ADDON/tools/run_tests.sh" | tail -2 || FAILED=1
done

if [ -n "${GODOT_46:-}" ]; then
  if [ -x "$GODOT_46" ]; then
    step "①-b unit tests — Godot 4.6"
    # 🛑 4.6 needs **a project folder of its own**, because the `.godot` cache differs per version.
    GODOT_BIN="$GODOT_46" GOHUD_PROJECT="${GOHUD_PROJECT_46:-${GOHUD_PROJECT:-}}" \
      bash "$ADDON/tools/run_tests.sh" || FAILED=1
  else
    echo "🛑 GODOT_46 is not an executable — $GODOT_46" >&2
    FAILED=1
  fi
fi

step "①-c do the workflows parse?"
# 🛑 **CI cannot tell you about the job it failed to start.** A syntax error in the workflow YAML
#    means the job is never created: failure in `0s` with no log — no way to tell which check
#    failed, which cost three days (2026-09-16: one line whose `run:` value started with a quote).
#    So parse it **locally** first. Without PyYAML this is skipped quietly (an optional dependency).
if python3 -c "import yaml" 2>/dev/null; then
  for wf in "$ADDON"/.github/workflows/*.yml; do
    python3 -c "import yaml,sys; yaml.safe_load(open(sys.argv[1]))" "$wf" \
      || { echo "🛑 workflow YAML error: $wf" >&2; FAILED=1; }
  done
  echo "✅ $(ls "$ADDON"/.github/workflows/*.yml 2>/dev/null | wc -l | tr -d ' ') workflows parsed"
else
  echo "⏭ skipped, no PyYAML (pip install pyyaml)"
fi

step "② theme contrast"
python3 "$ADDON/tools/check_contrast.py" --quiet || FAILED=1

step "③ website"
python3 "$ADDON/tools/check_site.py" || FAILED=1

step "①-n is any class_name declared more than once?"
# 🛑 A collision raises **no error** — Godot picks one, and even if it picks the old copy that copy
#    works on its own. Even the unit tests look at whichever class was picked, so they pass. Only a check stops it.
python3 "$ADDON/tools/check_classes.py" || FAILED=1

step "③-a do the gohud APIs the docs point at exist?"
# 🛑 Without a check, nobody reads the prose — while documenting new widgets on 2026-09-16,
#    **nine calls written from memory without opening the code were wrong**, and two of them were code that fails to parse when copied.
python3 "$ADDON/tools/check_docs_api.py" || FAILED=1

step "④ do the generated theme files match the source?"
# 🛑 Edit a palette and forget to run `make_theme.py` and the `.tres` stays stale — invisibly.
python3 "$ADDON/tools/check_generated.py" || FAILED=1

step "④-a do the game icon files match their table?"
python3 "$ADDON/tools/make_game_icons.py" --check || FAILED=1

step "④-c theme scaffolding"
# 🛑 The promise of "more themes to come" — does one file produce a theme that passes the contrast check? It is fast, so always run it.
bash "$ADDON/tools/check_scaffold.sh" || FAILED=1

step "⑤ packaging from the package.json version — checked on a temporary copy"
python3 "$ADDON/tools/check_package.py" || FAILED=1

# 🛑 **What the checks actually catch** cannot be told from how many there are. It is slow (a full
#    run per mutation), so it is off by default — turn it on in a round where checks were added or widget logic touched.
if [ -n "${GOHUD_CHECK_MUTATIONS:-}" ]; then
  step "④-b how much the checks catch (mutation)"
  GOHUD_PROJECT="${GOHUD_PROJECT:-}" bash "$ADDON/tools/check_mutations.sh" | tail -4 \
    || FAILED=1
fi

# 📸 Demo screenshots are slow (30 of them) and need a window, so they are off by default. Turn them on in a round where widget looks changed and **look at them**.
if [ -n "${GOHUD_CHECK_DEMO_SHOTS:-}" ]; then
  step "④-d demo screenshots"
  bash "$ADDON/tools/demo_shots.sh" "${GOHUD_DEMO_SHOTS_DIR:-/tmp/gohud_demo_shots}" 2>&1 | tail -1 || FAILED=1
fi

# 📸 Site screenshots — table widths, tooltips and horizontal scrolling at phone width cannot be seen by reading HTML. Turn it on in a round where the site changed.
if [ -n "${GOHUD_CHECK_SITE_SHOTS:-}" ]; then
  step "④-e site screenshots"
  bash "$ADDON/tools/site_shots.sh" "${GOHUD_SITE_SHOTS_DIR:-/tmp/gohud_site_shots}" 2>&1 | tail -1 || FAILED=1
fi

# The packaging check always runs above. The old GOHUD_CHECK_PACKAGE setting is no longer needed.

printf "\n"
if [ "$FAILED" -eq 0 ]; then echo "✅ all passed"; else echo "🛑 some checks failed"; fi
exit "$FAILED"
