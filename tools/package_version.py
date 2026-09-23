"""Internal version reading/preparation/publishing for package.sh (Python standard library only).

The release version lives in package.json and nothing here ever increments it. Prepare applies it
to the packaging workspace; the checkout is updated only after every archive gate passes.
package.sh holds the per-checkout lock across both operations.
"""
from datetime import date
from pathlib import Path
import json
import os
import re
import shutil
import sys
import tempfile

MANIFEST = "package.json"
FILES = ("plugin.cfg", "core/go_ui.gd", "CHANGELOG.md")
SEMVER = r"(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)"
# 🛑 The READMEs ship inside the ZIP and open the store page's repository. Theirs is the one version a
#    reader sees first, and it had stood at 1.0.1 while 1.0.2 and 1.0.3 shipped (found 2026-09-23) —
#    packaging cannot fix that sentence for them, because what is new in a release is written by a person.
READMES = ("README.md", "README.ko.md")
STATED_VERSION = re.compile(r"\*\*(?:Version|버전) (\d+\.\d+\.\d+)\.?\*\*")


def read_version(addon):
    path = addon / MANIFEST
    try:
        manifest = json.loads(path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        raise ValueError(f'{MANIFEST} is missing — create it with {{"version": "1.2.3"}}')
    except json.JSONDecodeError as error:
        raise ValueError(f"{MANIFEST} is not valid JSON: {error}")
    version = manifest.get("version") if isinstance(manifest, dict) else None
    if not isinstance(version, str):
        raise ValueError(f'{MANIFEST} needs a "version" string (for example: "1.2.3")')
    if not re.fullmatch(SEMVER, version):
        raise ValueError(f"the version in {MANIFEST} must be in major.minor.patch form "
                         f"(for example: 1.2.3), not {version!r}")
    return version


def prepare(stage, version):
    if not re.fullmatch(SEMVER, version):
        raise ValueError(f"the version must be in major.minor.patch form (for example: 1.2.3), not {version!r}")
    package = stage / "addons/gohud"
    plugin = (package / FILES[0]).read_text(encoding="utf-8")
    code = (package / FILES[1]).read_text(encoding="utf-8")
    changelog = (package / FILES[2]).read_text(encoding="utf-8")
    versions = re.findall(r'^version="([^"]*)"$', plugin, re.M)
    code_versions = re.findall(r'^const VERSION := "([^"]*)"$', code, re.M)
    if len(versions) != 1:
        raise ValueError("plugin.cfg must have exactly one version= line")
    if len(code_versions) != 1:
        raise ValueError("core/go_ui.gd must have exactly one const VERSION line")
    for readme in READMES:
        stated = STATED_VERSION.findall((package / readme).read_text(encoding="utf-8"))
        if len(stated) != 1:
            raise ValueError(f"{readme} must say the version once, as **Version 1.2.3.** "
                             f"(found {len(stated)} such lines)")
        if stated[0] != version:
            raise ValueError(f"{readme} announces version {stated[0]}, but this release is {version} — "
                             f"write what is new in it and correct that line, then package again")
    notes = []
    previous = sorted(set(versions + code_versions))
    if previous == [version]:
        notes.append(f"plugin.cfg · GoUi.VERSION: already {version}")
    else:
        notes.append(f"plugin.cfg · GoUi.VERSION: {' / '.join(previous)} → {version}")

    unreleased = re.compile(r"^## \[Unreleased\][^\n]*", re.M)
    if len(unreleased.findall(changelog)) > 1:
        raise ValueError("CHANGELOG.md has more than one Unreleased entry")
    if re.search(rf"^## \[{re.escape(version)}\](?:\s|$)", changelog, re.M):
        # Packaging the same version again — the release entry is already written.
        notes.append(f"CHANGELOG.md: [{version}] already recorded — unchanged")
        pending = re.search(r"^## \[Unreleased\][^\n]*\n(.*?)(?=^## |\Z)", changelog, re.M | re.S)
        if pending and pending.group(1).strip():
            notes.append(f"⚠️  Unreleased notes stay under Unreleased, yet their code is in this ZIP — "
                         f"raise the version in {MANIFEST} to release them")
    else:
        heading = f"## [{version}] - {date.today().isoformat()}"
        if unreleased.search(changelog):
            changelog = unreleased.sub("## [Unreleased]\n\n" + heading, changelog, count=1)
        else:
            first_release = re.search(r"^## ", changelog, re.M)
            offset = first_release.start() if first_release else len(changelog)
            changelog = (changelog[:offset].rstrip() + "\n\n## [Unreleased]\n\n"
                         + heading + "\n\n" + changelog[offset:])
        notes.append(f"CHANGELOG.md: Unreleased notes moved into [{version}]")

    for relative in FILES:
        backup = stage / "originals" / relative
        backup.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(package / relative, backup)
    (stage / "originals" / MANIFEST).write_text(version, encoding="utf-8")
    plugin = re.sub(r'^version="[^"]*"$', f'version="{version}"', plugin, count=1, flags=re.M)
    code = re.sub(r'^const VERSION := "[^"]*"$', f'const VERSION := "{version}"', code, count=1, flags=re.M)
    for relative, content in zip(FILES, (plugin, code, changelog)):
        (package / relative).write_text(content, encoding="utf-8")
    print("\n".join(notes))


def atomic_write(path, content):
    mode = path.stat().st_mode & 0o777
    fd, temporary = tempfile.mkstemp(prefix=".gohud-version-", suffix=".tmp", dir=path.parent)
    temporary = Path(temporary)
    try:
        with os.fdopen(fd, "wb") as stream:
            stream.write(content)
        temporary.chmod(mode)
        os.replace(temporary, path)
    finally:
        temporary.unlink(missing_ok=True)


def publish(addon, stage, destination):
    originals = {relative: (stage / "originals" / relative).read_bytes() for relative in FILES}
    for relative, content in originals.items():
        if (addon / relative).read_bytes() != content:
            raise ValueError(f"{relative} changed while packaging. Keeping the change and stopping")
    packaged = (stage / "originals" / MANIFEST).read_text(encoding="utf-8")
    if read_version(addon) != packaged:
        raise ValueError(f"{MANIFEST} changed while packaging. Keeping the change and stopping")
    replacing = destination.exists()
    # Copy to the destination filesystem before publishing (also works with --out
    # on another volume). Any copy failure occurs before the source files change.
    fd, temporary = tempfile.mkstemp(prefix=".gohud-package-", suffix=".tmp", dir=destination.parent)
    os.close(fd)
    temporary = Path(temporary)
    updated = []
    try:
        shutil.copyfile(stage / "package.zip", temporary)
        temporary.chmod(0o644)
        for relative in FILES:
            content = (stage / "addons/gohud" / relative).read_bytes()
            if content == originals[relative]:
                continue  # leave untouched files alone, mtime included
            updated.append(relative)
            atomic_write(addon / relative, content)
        # Same version, same file name — the new ZIP replaces the previous one in one step.
        os.replace(temporary, destination)
    except BaseException:
        for relative in reversed(updated):
            atomic_write(addon / relative, originals[relative])
        raise
    finally:
        temporary.unlink(missing_ok=True)
    if replacing:
        print("replaced the existing ZIP of the same version")


if __name__ == "__main__":
    try:
        if len(sys.argv) == 3 and sys.argv[1] == "read":
            print(read_version(Path(sys.argv[2])))
        elif len(sys.argv) == 4 and sys.argv[1] == "prepare":
            prepare(Path(sys.argv[2]), sys.argv[3])
        elif len(sys.argv) == 5 and sys.argv[1] == "publish":
            publish(*(Path(arg) for arg in sys.argv[2:]))
        else:
            raise ValueError("run this through package.sh")
    except (ValueError, OSError) as error:
        sys.exit(f"🛑 {error}")
