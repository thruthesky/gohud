"""Internal version preparation/publishing for package.sh (Python standard library only).

Prepare changes in the packaging workspace; update the checkout only after every
archive gate passes. package.sh holds the per-checkout lock across both operations.
"""
from datetime import date
from pathlib import Path
import os
import re
import shutil
import sys
import tempfile

FILES = ("plugin.cfg", "core/go_ui.gd", "CHANGELOG.md")
SEMVER = r"(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)"


def prepare(stage, increase):
    package = stage / "addons/gohud"
    plugin = (package / FILES[0]).read_text(encoding="utf-8")
    code = (package / FILES[1]).read_text(encoding="utf-8")
    changelog = (package / FILES[2]).read_text(encoding="utf-8")
    versions = re.findall(r'^version="([^"]+)"$', plugin, re.M)
    code_versions = re.findall(r'^const VERSION := "([^"]+)"$', code, re.M)
    if len(versions) != 1 or versions != code_versions:
        raise ValueError("plugin.cfg and GoUi.VERSION must be one and the same version")
    match = re.fullmatch(SEMVER, versions[0])
    if not match:
        raise ValueError("the version must be in major.minor.patch form (for example: 1.2.3)")
    major, minor, patch = map(int, match.groups())
    if increase == "minor":
        minor, patch = minor + 1, 0
    else:
        patch += 1
    version = f"{major}.{minor}.{patch}"
    if re.search(rf"^## \[{re.escape(version)}\](?:\s|$)", changelog, re.M):
        raise ValueError(f"CHANGELOG.md already has [{version}]")
    heading = f"## [{version}] - {date.today().isoformat()}"
    unreleased = re.compile(r"^## \[Unreleased\][^\n]*", re.M)
    if len(unreleased.findall(changelog)) > 1:
        raise ValueError("CHANGELOG.md has more than one Unreleased entry")
    if unreleased.search(changelog):
        changelog = unreleased.sub("## [Unreleased]\n\n" + heading, changelog, count=1)
    else:
        first_release = re.search(r"^## ", changelog, re.M)
        offset = first_release.start() if first_release else len(changelog)
        changelog = (changelog[:offset].rstrip() + "\n\n## [Unreleased]\n\n"
                     + heading + "\n\n" + changelog[offset:])
    for relative in FILES:
        backup = stage / "originals" / relative
        backup.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(package / relative, backup)
    plugin = re.sub(r'^version="[^"]+"$', f'version="{version}"', plugin, count=1, flags=re.M)
    code = re.sub(r'^const VERSION := "[^"]+"$', f'const VERSION := "{version}"', code, count=1, flags=re.M)
    for relative, content in zip(FILES, (plugin, code, changelog)):
        (package / relative).write_text(content, encoding="utf-8")
    print(version)


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
    if destination.exists():
        raise ValueError(f"a ZIP of the same version already exists: {destination}")
    # Copy to the destination filesystem before publishing (also works with --out
    # on another volume). Any copy failure occurs before the source version changes.
    fd, temporary = tempfile.mkstemp(prefix=".gohud-package-", suffix=".tmp", dir=destination.parent)
    os.close(fd)
    temporary = Path(temporary)
    updated = []
    try:
        shutil.copyfile(stage / "package.zip", temporary)
        temporary.chmod(0o644)
        for relative in FILES:
            updated.append(relative)
            atomic_write(addon / relative, (stage / "addons/gohud" / relative).read_bytes())
        os.replace(temporary, destination)
    except BaseException:
        for relative in reversed(updated):
            atomic_write(addon / relative, originals[relative])
        raise
    finally:
        temporary.unlink(missing_ok=True)


if __name__ == "__main__":
    try:
        if len(sys.argv) == 4 and sys.argv[1] == "prepare" and sys.argv[3] in ("patch", "minor"):
            prepare(Path(sys.argv[2]), sys.argv[3])
        elif len(sys.argv) == 5 and sys.argv[1] == "publish":
            publish(*(Path(arg) for arg in sys.argv[2:]))
        else:
            raise ValueError("run this through package.sh")
    except (ValueError, OSError) as error:
        sys.exit(f"🛑 {error}")
