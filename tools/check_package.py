"""Exercise package.sh in temporary checkouts; never increment the working copy.

Run: python3 tools/check_package.py
"""
import contextlib
import importlib.util
import io
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
        (self.addon / "plugin.cfg").write_text('[plugin]\nversion="1.2.9"\n')
        (self.addon / "core/go_ui.gd").write_text('const VERSION := "1.2.9"\n')
        (self.addon / "CHANGELOG.md").write_text(
            '# Changelog\n\n## [Unreleased]\n\n### Fixed\n\n- Pending fix.\n\n'
            '## [1.2.9]\n\n- Previous release.\n')
        for name in ("LICENSE", "README.md", "THIRD_PARTY_NOTICES.md"):
            (self.addon / name).write_text(name + "\n")

    def snapshot(self):
        return {name: (self.addon / name).read_bytes() for name in versioning.FILES}

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
        self.assertIn(f'version="{version}"', (self.addon / "plugin.cfg").read_text())
        self.assertIn(f'const VERSION := "{version}"', (self.addon / "core/go_ui.gd").read_text())
        self.assertIn(f'## [{version}] - ', (self.addon / "CHANGELOG.md").read_text())
        archive = archive or self.addon / f"builds/{version}/gohud-{version}.zip"
        with zipfile.ZipFile(archive) as zipped:
            for name in versioning.FILES:
                self.assertEqual(zipped.read("addons/gohud/" + name), (self.addon / name).read_bytes())
        self.assertFalse((self.addon / "builds/.package-lock").exists())

    def test_patch_increments_each_run_and_moves_notes(self):
        self.run_package()
        self.assert_release("1.2.10")
        text = (self.addon / "CHANGELOG.md").read_text()
        self.assertLess(text.index('## [1.2.10]'), text.index('- Pending fix.'))
        self.assertLess(text.index('- Pending fix.'), text.index('## [1.2.9]'))
        self.run_package()
        self.assert_release("1.2.11")
        self.assertEqual((self.addon / "CHANGELOG.md").read_text().count('- Pending fix.'), 1)

    def test_minor_resets_patch_with_custom_output(self):
        output = self.root / "output with spaces '"
        self.run_package('--out', str(output), '--increase-minor-version')
        self.assert_release("1.3.0", output / "gohud-1.3.0.zip")
        self.run_package()
        self.assert_release("1.3.1")

    def test_changelog_without_unreleased(self):
        p = self.addon / "CHANGELOG.md"
        p.write_text('# Changelog\n\n## [1.2.9]\n\n- Existing notes.\n')
        self.run_package()
        self.assert_release("1.2.10")
        self.assertIn('## [1.2.9]\n\n- Existing notes.', p.read_text())

    def test_help_and_invalid_options_do_not_change_versions(self):
        before = self.snapshot()
        self.run_package('--help')
        self.assertEqual(self.snapshot(), before)
        for args in (('--out',), ('--out', '--increase-minor-version'), ('--unknown',)):
            with self.subTest(args=args):
                self.run_package(*args, ok=False)

    def test_invalid_or_mismatched_versions(self):
        for value in ('1.2', '01.2.9', '1.2.9-beta', '1.2.9+build', '1.2.8'):
            with self.subTest(version=value):
                (self.addon / "plugin.cfg").write_text(f'[plugin]\nversion="{value}"\n')
                if value != '1.2.8':
                    (self.addon / "core/go_ui.gd").write_text(f'const VERSION := "{value}"\n')
                self.run_package(ok=False)

    def test_late_gate_failure_keeps_original_version(self):
        (self.addon / 'invalid.key').write_text('test fixture, not a key')
        self.run_package(ok=False)
        self.assertFalse((self.addon / "builds/.package-lock").exists())
        (self.addon / 'invalid.key').unlink()
        self.run_package()
        self.assert_release('1.2.10')

    def test_zip_failure_keeps_original_version(self):
        commands = self.root / 'bin'
        commands.mkdir()
        (commands / 'zip').write_text('#!/bin/sh\nexit 7\n')
        (commands / 'zip').chmod(0o755)
        self.run_package(ok=False, env=dict(os.environ, PATH=str(commands) + os.pathsep + os.environ['PATH']))

    def test_existing_archive_is_preserved(self):
        output = self.root / 'output'
        output.mkdir()
        existing = output / 'gohud-1.2.10.zip'
        existing.write_bytes(b'previous artifact')
        self.run_package('--out', str(output), ok=False)
        self.assertEqual(existing.read_bytes(), b'previous artifact')

    def test_existing_release_heading_is_rejected(self):
        path = self.addon / 'CHANGELOG.md'
        path.write_text(path.read_text() + '\n## [1.2.10]\n')
        self.run_package(ok=False)

    def test_concurrent_package_is_rejected(self):
        lock = self.addon / 'builds/.package-lock'
        lock.mkdir(parents=True)
        self.run_package(ok=False)
        self.assertTrue(lock.is_dir(), 'must preserve the other process lock')

    def prepare_publish(self):
        stage = self.root / 'stage'
        shutil.copytree(self.addon, stage / 'addons/gohud')
        with contextlib.redirect_stdout(io.StringIO()):
            versioning.prepare(stage, 'patch')
        (stage / 'package.zip').write_bytes(b'validated archive fixture')
        return stage

    def test_publish_failure_restores_metadata(self):
        before = self.snapshot()
        stage = self.prepare_publish()
        destination = self.root / 'gohud-1.2.10.zip'
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

    def test_real_addon_archive(self):
        self.addon = self.root / 'real-addon'
        shutil.copytree(ADDON, self.addon, symlinks=True, ignore=shutil.ignore_patterns(
            '.git*', '.env*', '.claude', '.review', '.playwright-mcp', '.godot',
            'builds', '.dist', 'docs', 'www', '__pycache__', '*.zip', '*.tmp'))
        original = (self.addon / 'plugin.cfg').read_text().split('version="')[1].split('"')[0]
        major, minor, patch_number = map(int, original.split('.'))
        usage = self.addon / 'examples/usage'
        usage.mkdir(parents=True, exist_ok=True)
        (usage / 'project.godot').write_text('config_version=5\n')
        (usage / 'main.gd').write_text('extends Node\nconst SCENE = "res://main.tscn"\n')
        self.run_package()
        version = f'{major}.{minor}.{patch_number + 1}'
        self.assert_release(version)
        archive = self.addon / 'builds' / version / f'gohud-{version}.zip'
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
