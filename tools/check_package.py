"""Exercise package.sh in temporary checkouts; never touch the working copy.

The release version comes from package.json and packaging must never raise it.
Run: python3 tools/check_package.py
"""
import contextlib
import importlib.util
import io
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from unittest.mock import patch
import zipfile

ADDON = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location("package_version", ADDON / "tools/package_version.py")
versioning = importlib.util.module_from_spec(spec)
spec.loader.exec_module(versioning)
TRACKED = versioning.FILES + (versioning.MANIFEST,) + versioning.READMES


class PackageTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="gohud-package-check-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.addon = self.root / "add-on with spaces '"
        (self.addon / "tools").mkdir(parents=True)
        (self.addon / "core").mkdir()
        for name in ("package.sh", "package_version.py"):
            shutil.copy2(ADDON / "tools" / name, self.addon / "tools" / name)
        self.set_manifest("1.2.9")
        (self.addon / "plugin.cfg").write_text('[plugin]\nversion="1.2.9"\n')
        (self.addon / "core/go_ui.gd").write_text('const VERSION := "1.2.9"\n')
        (self.addon / "CHANGELOG.md").write_text(
            '# Changelog\n\n## [Unreleased]\n\n### Fixed\n\n- Pending fix.\n\n'
            '## [1.2.9]\n\n- Previous release.\n')
        (self.addon / "LICENSE").write_text("LICENSE\n")
        (self.addon / "THIRD_PARTY_NOTICES.md").write_text("THIRD_PARTY_NOTICES.md\n")
        self.set_readmes("1.2.9")

    def set_readmes(self, version):
        (self.addon / "README.md").write_text(f"# gohud\n\n**Version {version}.** What is new.\n")
        (self.addon / "README.ko.md").write_text(f"# gohud\n\n**\ubc84\uc804 {version}.** \uc0c8\ub85c\uc6b4 \uac83.\n")

    def set_manifest(self, version):
        (self.addon / "package.json").write_text(json.dumps({"version": version}, indent=2) + "\n")

    def snapshot(self):
        return {name: (self.addon / name).read_bytes() for name in TRACKED if (self.addon / name).exists()}

    def run_package(self, *args, ok=True, env=None):
        before = self.snapshot()
        result = subprocess.run(['bash', str(self.addon / "tools/package.sh"), *args],
                                capture_output=True, text=True, env=env, timeout=30)
        if ok:
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        else:
            self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertEqual(self.snapshot(), before, "failure changed release metadata")
            self.assertFalse(list(self.addon.rglob('*.zip')))
        return result

    def assert_release(self, version, archive=None):
        self.assertEqual(json.loads((self.addon / "package.json").read_text())["version"], version,
                         "packaging must never change package.json")
        self.assertIn(f'version="{version}"', (self.addon / "plugin.cfg").read_text())
        self.assertIn(f'const VERSION := "{version}"', (self.addon / "core/go_ui.gd").read_text())
        self.assertRegex((self.addon / "CHANGELOG.md").read_text(), rf'(?m)^## \[{version}\]')
        archive = archive or self.addon / f"builds/{version}/gohud-{version}.zip"
        with zipfile.ZipFile(archive) as zipped:
            for name in versioning.FILES:
                self.assertEqual(zipped.read("addons/gohud/" + name), (self.addon / name).read_bytes())
            self.assertNotIn("addons/gohud/package.json", zipped.namelist())
        self.assertFalse((self.addon / "builds/.package-lock").exists())
        return archive

    def test_same_version_every_run(self):
        before = self.snapshot()
        first = self.run_package()
        archive = self.assert_release("1.2.9")
        self.assertEqual(self.snapshot(), before, "an already released version changes nothing")
        self.assertNotIn("replaced", first.stdout)
        self.assertIn("Unreleased notes stay under Unreleased", first.stdout)
        archive.write_bytes(b'previous build')
        second = self.run_package()
        self.assert_release("1.2.9")
        self.assertEqual(self.snapshot(), before)
        self.assertIn("replaced the existing ZIP", second.stdout)
        self.assertEqual([p.name for p in (self.addon / "builds").iterdir() if not p.name.startswith(".")],
                         ["1.2.9"])

    def test_new_version_follows_package_json(self):
        self.set_manifest("2.0.0")
        self.set_readmes("2.0.0")
        result = self.run_package()
        self.assert_release("2.0.0")
        self.assertIn("1.2.9 → 2.0.0", result.stdout)
        text = (self.addon / "CHANGELOG.md").read_text()
        self.assertIn('## [2.0.0] - ', text)
        self.assertLess(text.index('## [Unreleased]'), text.index('## [2.0.0]'))
        self.assertLess(text.index('## [2.0.0]'), text.index('- Pending fix.'))
        self.assertLess(text.index('- Pending fix.'), text.index('## [1.2.9]'))
        after = self.snapshot()
        self.run_package()
        self.assert_release("2.0.0")
        self.assertEqual(self.snapshot(), after, "the second run of a version must not move anything")
        self.assertEqual((self.addon / "CHANGELOG.md").read_text().count('- Pending fix.'), 1)

    def test_lower_version_is_taken_as_written(self):
        self.set_manifest("1.0.0")
        self.set_readmes("1.0.0")
        self.run_package()
        self.assert_release("1.0.0")

    def test_custom_output(self):
        output = self.root / "output with spaces '"
        self.set_manifest("1.3.0")
        self.set_readmes("1.3.0")
        self.run_package('--out', str(output))
        self.assert_release("1.3.0", output / "gohud-1.3.0.zip")
        self.assertFalse((self.addon / "builds/1.3.0").exists())

    def test_changelog_without_unreleased(self):
        p = self.addon / "CHANGELOG.md"
        p.write_text('# Changelog\n\n## [1.2.9]\n\n- Existing notes.\n')
        self.set_manifest("1.2.10")
        self.set_readmes("1.2.10")
        self.run_package()
        self.assert_release("1.2.10")
        self.assertIn('## [1.2.9]\n\n- Existing notes.', p.read_text())

    def test_mismatched_version_files_are_brought_in_line(self):
        (self.addon / "plugin.cfg").write_text('[plugin]\nversion="1.2.8"\n')
        self.run_package()
        self.assert_release("1.2.9")

    def test_help_and_invalid_options_do_not_change_versions(self):
        before = self.snapshot()
        self.run_package('--help')
        self.assertEqual(self.snapshot(), before)
        for args in (('--out',), ('--out', '--full'), ('--unknown',), ('--increase-minor-version',)):
            with self.subTest(args=args):
                self.run_package(*args, ok=False)

    def test_readme_must_announce_the_packaged_version(self):
        self.set_manifest("1.3.0")
        result = self.run_package(ok=False)          # both READMEs still say 1.2.9
        self.assertIn("README.md announces version 1.2.9", result.stderr)
        self.set_readmes("1.3.0")
        (self.addon / "README.ko.md").write_text("# gohud\n\nno version here\n")
        self.assertIn("README.ko.md must say the version once", self.run_package(ok=False).stderr)
        self.set_readmes("1.3.0")
        self.run_package()
        self.assert_release("1.3.0")

    def test_invalid_package_json(self):
        manifest = self.addon / "package.json"
        for content in ('', '{', '[]', '{}', '{"version": 1.3}', '{"version": "1.2"}',
                        '{"version": "01.2.9"}', '{"version": "1.2.9-beta"}', '{"version": "1.2.9+build"}',
                        '{"version": " 1.2.9"}'):
            with self.subTest(content=content):
                manifest.write_text(content)
                result = self.run_package(ok=False)
                self.assertIn("package.json", result.stderr)
        manifest.unlink()
        self.assertIn("package.json is missing", self.run_package(ok=False).stderr)

    def test_unreadable_version_lines(self):
        for name, content in (("plugin.cfg", '[plugin]\n'), ("plugin.cfg", 'version="1.2.9"\nversion="1.2.9"\n'),
                              ("core/go_ui.gd", 'extends Node\n')):
            with self.subTest(name=name, content=content):
                original = (self.addon / name).read_bytes()
                (self.addon / name).write_text(content)
                self.run_package(ok=False)
                (self.addon / name).write_bytes(original)

    def test_late_gate_failure_keeps_original_version(self):
        self.set_manifest("1.3.0")
        self.set_readmes("1.3.0")
        (self.addon / 'invalid.key').write_text('test fixture, not a key')
        self.run_package(ok=False)
        self.assertIn('version="1.2.9"', (self.addon / "plugin.cfg").read_text())
        self.assertFalse((self.addon / "builds/.package-lock").exists())
        (self.addon / 'invalid.key').unlink()
        self.run_package()
        self.assert_release('1.3.0')

    def test_zip_failure_keeps_original_version(self):
        self.set_manifest("1.3.0")
        self.set_readmes("1.3.0")
        commands = self.root / 'bin'
        commands.mkdir()
        (commands / 'zip').write_text('#!/bin/sh\nexit 7\n')
        (commands / 'zip').chmod(0o755)
        self.run_package(ok=False, env=dict(os.environ, PATH=str(commands) + os.pathsep + os.environ['PATH']))

    def test_concurrent_package_is_rejected(self):
        lock = self.addon / 'builds/.package-lock'
        lock.mkdir(parents=True)
        self.run_package(ok=False)
        self.assertTrue(lock.is_dir(), 'must preserve the other process lock')

    def prepare_publish(self, version="1.3.0"):
        self.set_manifest(version)
        self.set_readmes(version)
        stage = self.root / 'stage'
        shutil.copytree(self.addon, stage / 'addons/gohud')
        with contextlib.redirect_stdout(io.StringIO()):
            versioning.prepare(stage, version)
        (stage / 'package.zip').write_bytes(b'validated archive fixture')
        return stage

    def test_publish_failure_restores_metadata(self):
        stage = self.prepare_publish()
        before = self.snapshot()
        destination = self.root / 'gohud-1.3.0.zip'
        replace = os.replace

        def fail_archive(source, target):
            if target == destination:
                raise OSError('simulated publication failure')
            return replace(source, target)

        with patch.object(versioning.os, 'replace', side_effect=fail_archive):
            with self.assertRaises(OSError):
                versioning.publish(self.addon, stage, destination)
        self.assertEqual(self.snapshot(), before)
        self.assertFalse(destination.exists())
        self.assertFalse(list(self.root.rglob('*.tmp')))

    def test_publish_preserves_concurrent_edit(self):
        stage = self.prepare_publish()
        (self.addon / 'CHANGELOG.md').write_text('An edit made during packaging.\n')
        before = self.snapshot()
        with self.assertRaises(ValueError):
            versioning.publish(self.addon, stage, self.root / 'package.zip')
        self.assertEqual(self.snapshot(), before)

    def test_publish_stops_when_package_json_changes(self):
        stage = self.prepare_publish()
        self.set_manifest("1.4.0")
        before = self.snapshot()
        with self.assertRaises(ValueError):
            versioning.publish(self.addon, stage, self.root / 'package.zip')
        self.assertEqual(self.snapshot(), before)
        self.assertFalse((self.root / 'package.zip').exists())

    def test_real_addon_archive(self):
        self.addon = self.root / 'real-addon'
        shutil.copytree(ADDON, self.addon, symlinks=True, ignore=shutil.ignore_patterns(
            '.git*', '.env*', '.claude', '.review', '.playwright-mcp', '.godot',
            'builds', '.dist', 'docs', 'www', '__pycache__', '*.zip', '*.tmp'))
        version = versioning.read_version(self.addon)
        usage = self.addon / 'examples/usage'
        usage.mkdir(parents=True, exist_ok=True)
        (usage / 'project.godot').write_text('config_version=5\n')
        (usage / 'main.gd').write_text('extends Node\nconst SCENE = "res://main.tscn"\n')
        self.run_package()
        archive = self.assert_release(version)
        with zipfile.ZipFile(archive) as package:
            self.assertFalse(any(name.startswith('addons/gohud/examples/usage/')
                                 for name in package.namelist()))
            for name in ('themes/presets/medieval_dark.tres', 'themes/presets/medieval_light.tres',
                         'themes/skins/go_skin_medieval.gd', 'widgets/go_stylebox_medieval.gd',
                         'icons/gohud_icons_medieval.tres', 'assets/fonts/cinzel/Cinzel.ttf',
                         'assets/fonts/cinzel/OFL.txt', 'examples/medieval/medieval.tscn'):
                self.assertIn('addons/gohud/' + name, package.namelist())


if __name__ == '__main__':
    unittest.main(verbosity=2)
