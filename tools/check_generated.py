"""Compare generated theme contents in isolation, including already modified files.

Run: python3 tools/check_generated.py
This check never rewrites the checkout and does not require a Git repository.

🛑 A `.tres` is compared by **what it says**, not byte for byte (`tools/tres_canonical.py`). Opening a theme
   in the Godot editor and saving it rewrites the same theme with uids, `10.0` for `10` and engine defaults
   dropped; byte comparison called that a failure and the check stood red through two releases
   (measured 2026-09-23). SVGs and `skin_dials.json` are still compared byte for byte.
"""
import hashlib
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

sys.path.insert(0, str(Path(__file__).resolve().parent))
import tres_canonical

ADDON = Path(__file__).resolve().parent.parent


def snapshot(root):
    files = list((root / "assets").rglob("*.svg"))
    files += [root / "tools/skin_dials.json"]
    return {str(p.relative_to(root)): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in files if p.is_file()}


def themes(root):
    return {str(p.relative_to(root)): p.read_text(encoding="utf-8")
            for p in sorted((root / "themes").rglob("*.tres"))}


def self_check():
    """🛑 A comparison that ignores too much passes everything. Two spellings of one resource must compare
    equal, and a changed value must not."""
    editor = ('[gd_resource type="Theme" format=3 uid="uid://abc"]\n\n'
              '[sub_resource type="StyleBoxFlat" id="StyleBoxFlat_1"]\n'
              'bg_color = Color(0.1, 0.2, 0.3, 1)\ncontent_margin_top = 10.0\n\n'
              '[resource]\nPanel/styles/panel = SubResource("StyleBoxFlat_1")\n')
    generator = ('[gd_resource type="Theme" load_steps=2 format=3]\n\n'
                 '[sub_resource type="StyleBoxFlat" id="flat_panel"]\n'
                 'content_margin_top = 10\ncorner_detail = 8\nbg_color = Color(0.1, 0.2, 0.3, 1)\n\n'
                 '[resource]\nPanel/styles/panel = SubResource("flat_panel")\n')
    problems = []
    if tres_canonical.differences(editor, generator):
        problems.append("the same theme in two spellings is reported as different")
    if not tres_canonical.differences(editor, generator.replace("0.2", "0.9")):
        problems.append("a changed colour is not reported")
    if not tres_canonical.differences(editor, generator.replace("corner_detail = 8", "corner_detail = 2")):
        problems.append("a changed corner detail is not reported")
    for problem in problems:
        print("🛑 the .tres comparison itself is broken — " + problem)
    return 1 if problems else 0


def main():
    if self_check():
        return 1
    before, before_themes = snapshot(ADDON), themes(ADDON)
    with tempfile.TemporaryDirectory(prefix="gohud-generated-") as temp:
        copy = Path(temp)
        for folder in ("core", "themes", "assets", "tools"):
            shutil.copytree(ADDON / folder, copy / folder,
                            ignore=shutil.ignore_patterns("__pycache__", "*.import"))
        result = subprocess.run([sys.executable, str(copy / "tools/make_theme.py")],
                                capture_output=True, text=True)
        if result.returncode:
            print(result.stdout + result.stderr, file=sys.stderr)
            return 1
        after, after_themes = snapshot(copy), themes(copy)
    changed = sorted(p for p in before.keys() | after.keys() if before.get(p) != after.get(p))
    for path in sorted(before_themes.keys() | after_themes.keys()):
        if path not in before_themes or path not in after_themes:
            changed.append(path)
            continue
        lines = tres_canonical.differences(before_themes[path], after_themes[path])
        if lines:
            changed.append(path)
            changed.extend(lines)
    if changed:
        print("🛑 the generated files differ from the source — run python3 tools/make_theme.py")
        for path in changed:
            print("  " + path)
        return 1
    print("✅ %d generated theme files match the source" % (len(before) + len(before_themes)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
