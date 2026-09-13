"""Compare generated theme contents in isolation, including already modified files.

Run: python3 tools/check_generated.py
This check never rewrites the checkout and does not require a Git repository.
"""
import hashlib
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

ADDON = Path(__file__).resolve().parent.parent


def snapshot(root):
    files = list((root / "assets").rglob("*.svg"))
    files += list((root / "themes").rglob("*.tres"))
    files += [root / "tools/skin_dials.json"]
    return {str(p.relative_to(root)): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in files if p.is_file()}


def main():
    before = snapshot(ADDON)
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
        after = snapshot(copy)
    changed = sorted(p for p in before.keys() | after.keys() if before.get(p) != after.get(p))
    if changed:
        print("🛑 생성물이 소스와 다르다 — python3 tools/make_theme.py 를 실행한다")
        for path in changed:
            print("  " + path)
        return 1
    print("✅ 테마 생성물 %d개가 소스와 일치" % len(before))
    return 0


if __name__ == "__main__":
    sys.exit(main())
