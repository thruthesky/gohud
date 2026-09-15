#!/usr/bin/env python3
"""Launch a gohud preview (gallery, medieval example, demo tour, or any scene) in Godot.

    python3 gohud_preview.py                          # gallery in a window (sandbox project)
    python3 gohud_preview.py gallery --preset scifi_dark --phone
    python3 gohud_preview.py medieval
    python3 gohud_preview.py demo --explore hud       # 15-chapter demo app, opened on one widget
    python3 gohud_preview.py res://ui/main_menu.tscn  # a scene of YOUR project (runs in your project)
    python3 gohud_preview.py gallery --check          # headless: no window, fail on script errors
    python3 gohud_preview.py list                     # targets, presets, demo chapters

Where the add-on comes from, first match wins:
  --source DIR  ->  <project>/addons/gohud  ->  the repository this script ships in
  (plugin install)  ->  a shallow git clone of github.com/thruthesky/gohud in the cache.

gohud's own examples run in a throwaway sandbox project under the cache, so your project's
autoloads, main scene and import cache are never touched. Standard library only.
"""
import argparse
import glob
import hashlib
import os
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path

REPO_URL = "https://github.com/thruthesky/gohud.git"
MIN_ENGINE = (4, 6)
PRESETS = ["default_dark", "default_light", "scifi_dark", "scifi_light", "medieval_dark", "medieval_light"]
SCENES = {
    "gallery": "res://addons/gohud/examples/gallery/gallery.tscn",
    "medieval": "res://addons/gohud/examples/medieval/medieval.tscn",
}
DEMO_CHAPTERS = ["hud", "buttons", "inputs", "selection", "lists", "data", "states", "surfaces",
                 "prompt", "touch", "coach", "scrolling", "forms", "anchors", "theming"]
# Never copied into a sandbox: repository housekeeping, site, tests, tools and nested projects.
SKIP_NAMES = {".git", ".github", ".godot", ".claude", ".claude-plugin", ".review", ".env", ".dist",
              ".playwright-mcp", "__pycache__", "builds", "docs", "tests", "tools", "skills", ".DS_Store"}
SKIP_PATHS = {"examples/usage", "examples/demo", "index.html", ".nojekyll"}
ERROR_LINE = re.compile(r"SCRIPT ERROR|Parse Error|ERROR: Failed|Failed loading resource|Cannot open file")


def say(message):
    print("[gohud-preview] " + message, flush=True)


def fail(message, code=1):
    print("[gohud-preview] ERROR: " + message, file=sys.stderr, flush=True)
    sys.exit(code)


def cache_home():
    if os.environ.get("GOHUD_PREVIEW_HOME"):
        return Path(os.environ["GOHUD_PREVIEW_HOME"]).expanduser()
    if sys.platform == "win32":
        return Path(os.environ.get("LOCALAPPDATA", Path.home())) / "gohud-preview"
    if sys.platform == "darwin":
        return Path.home() / "Library" / "Caches" / "gohud-preview"
    return Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache")) / "gohud-preview"


# ── Godot ────────────────────────────────────────────────────────────────

def engine_version(binary):
    try:
        out = subprocess.run([binary, "--version"], capture_output=True, text=True, timeout=30).stdout
    except (OSError, subprocess.TimeoutExpired):
        return None
    match = re.search(r"(\d+)\.(\d+)", out or "")
    return (int(match.group(1)), int(match.group(2))) if match else None


def find_godot(explicit):
    candidates = [explicit, os.environ.get("GODOT_BIN"), os.environ.get("GODOT")]
    candidates += [shutil.which(name) for name in ("godot", "godot4", "Godot", "godot-4")]
    patterns = ["/Applications/Godot*.app/Contents/MacOS/Godot",
                str(Path.home() / "Applications/Godot*.app/Contents/MacOS/Godot"),
                "C:/Program Files/Godot*/Godot*.exe", "C:/Godot*/Godot*.exe",
                str(Path.home() / "Godot*/Godot*"), "/opt/godot*/godot*", "/usr/local/bin/godot*"]
    for pattern in patterns:
        candidates += sorted(glob.glob(pattern), reverse=True)
    for binary in candidates:
        if not binary or not os.path.isfile(binary):
            continue
        if binary.lower().endswith(".exe") and not binary.lower().endswith("_console.exe"):
            console = binary[:-4] + "_console.exe"
            if os.path.isfile(console):
                binary = console
        version = engine_version(binary)
        if version is None:
            continue
        if version < MIN_ENGINE:
            say("skipping %s (Godot %d.%d; gohud needs %d.%d+)" % ((binary,) + version + MIN_ENGINE))
            continue
        return binary, version
    fail("Godot 4.6+ was not found. Install it, or pass --godot PATH / set GODOT_BIN.", 2)


# ── Add-on source ────────────────────────────────────────────────────────

def is_gohud(folder):
    cfg = Path(folder) / "plugin.cfg"
    return cfg.is_file() and re.search(r'^name="gohud"', cfg.read_text(encoding="utf-8", errors="ignore"), re.M)


def find_project(start):
    here = Path(start).resolve()
    for folder in [here] + list(here.parents):
        if (folder / "project.godot").is_file():
            return folder
    return None


def find_source(args, project):
    if args.source:
        if not is_gohud(args.source):
            fail("--source %s is not a gohud add-on folder (no plugin.cfg with name=\"gohud\")" % args.source, 2)
        return Path(args.source).resolve(), "--source"
    if project and is_gohud(project / "addons" / "gohud"):
        return (project / "addons" / "gohud").resolve(), "your project"
    bundled = Path(__file__).resolve().parents[3]
    if is_gohud(bundled):
        return bundled, "bundled with this skill"
    clone = cache_home() / "source"
    if is_gohud(clone):
        if args.update:
            subprocess.run(["git", "-C", str(clone), "pull", "--ff-only", "--quiet"])
        return clone, "cached clone"
    if args.dry_run:
        say("would clone %s into %s" % (REPO_URL, clone))
        return clone, "clone (dry run)"
    if not shutil.which("git"):
        fail("No gohud add-on found and git is not installed. Pass --source DIR.", 2)
    say("cloning %s (shallow) ..." % REPO_URL)
    clone.parent.mkdir(parents=True, exist_ok=True)
    if subprocess.run(["git", "clone", "--depth", "1", "--quiet", REPO_URL, str(clone)]).returncode:
        fail("git clone failed. Check the network, or pass --source DIR.", 2)
    return clone, "fresh clone"


def skipped(rel):
    parts = rel.split("/")
    return (any(p in SKIP_NAMES for p in parts) or rel in SKIP_PATHS
            or any(rel.startswith(p + "/") for p in SKIP_PATHS) or rel.endswith((".zip", ".tmp", ".pyc")))


def tree_files(source, keep=skipped):
    for root, dirs, files in os.walk(source):
        rel_root = os.path.relpath(root, source).replace("\\", "/")
        rel_root = "" if rel_root == "." else rel_root + "/"
        dirs[:] = [d for d in dirs if not keep(rel_root + d) and not os.path.islink(os.path.join(root, d))]
        for name in files:
            if not keep(rel_root + name):
                yield rel_root + name


def fingerprint(source, files):
    digest = hashlib.sha1()
    for rel in sorted(files):
        stat = (Path(source) / rel).stat()
        digest.update(("%s|%d|%d\n" % (rel, stat.st_size, stat.st_mtime_ns)).encode())
    return digest.hexdigest()


def sync(source, target, files):
    """Mirror `files` into `target`; returns True when anything changed."""
    files = list(files)
    stamp = Path(target).parent / (Path(target).name + ".stamp")
    mark = fingerprint(source, files)
    if Path(target).is_dir() and stamp.is_file() and stamp.read_text() == mark:
        return False
    shutil.rmtree(target, ignore_errors=True)
    for rel in files:
        destination = Path(target) / rel
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(Path(source) / rel, destination)
    stamp.write_text(mark)
    return True


# ── Sandbox projects ─────────────────────────────────────────────────────

def write_project(folder, version, main_scene, preset, size):
    width, height = size
    lines = ['config_version=5', '', '[application]', '', 'config/name="gohud preview"',
             'run/main_scene="%s"' % main_scene, 'config/features=PackedStringArray("%d.%d")' % version, '',
             '[display]', '', 'window/size/viewport_width=%d' % width, 'window/size/viewport_height=%d' % height,
             'window/stretch/mode="canvas_items"', 'window/stretch/aspect="expand"', '']
    if preset:
        lines += ['[gohud]', '', 'theme/preset="%s"' % preset, '']
    lines += ['[rendering]', '', 'renderer/rendering_method="gl_compatibility"',
              'renderer/rendering_method.mobile="gl_compatibility"', '']
    path = Path(folder) / "project.godot"
    text = "\n".join(lines)
    if not path.is_file() or path.read_text() != text:
        path.write_text(text)


def import_project(godot, folder, force):
    if not force and (Path(folder) / ".godot" / "global_script_class_cache.cfg").is_file():
        return
    say("importing %s (first run takes a little while) ..." % folder)
    result = subprocess.run([godot, "--headless", "--path", str(folder), "--import"],
                            capture_output=True, text=True, errors="replace")
    errors = [line for line in (result.stdout + result.stderr).splitlines() if ERROR_LINE.search(line)]
    if result.returncode or errors:
        print("\n".join(errors[-20:] or (result.stdout + result.stderr).splitlines()[-20:]), file=sys.stderr)
        fail("import failed in %s" % folder)


def prepare_sandbox(godot, version, source, preset, size):
    folder = cache_home() / "sandbox"
    folder.mkdir(parents=True, exist_ok=True)
    changed = sync(source, folder / "addons" / "gohud", tree_files(source))
    write_project(folder, version, SCENES["gallery"], preset, size)
    import_project(godot, folder, changed)
    return folder


def prepare_demo(godot, version, source):
    demo = Path(source) / "examples" / "demo"
    if not (demo / "sim.tscn").is_file():
        fail("this gohud copy has no examples/demo (sim.tscn)", 2)
    folder = cache_home() / "demo"
    folder.mkdir(parents=True, exist_ok=True)
    # The demo folder carries `.gdignore` (so a host project skips it) and an `addons/gohud` link back to
    # the add-on root; as a project root both would break the demo, so neither is copied.
    keep_out = lambda rel: rel.split("/")[0] in {"addons", ".godot", ".gdignore"} or skipped(rel)
    changed = sync(demo, folder / "app", tree_files(demo, keep_out))
    app = folder / "app"
    if not (app / "project.godot").is_file() and (app / "project.godot.demo").is_file():
        shutil.copy2(app / "project.godot.demo", app / "project.godot")
    changed = sync(source, app / "addons" / "gohud", tree_files(source)) or changed
    import_project(godot, app, changed)
    return app


# ── Run ──────────────────────────────────────────────────────────────────

def run(command, args, log_name):
    say("$ " + " ".join('"%s"' % part if " " in part else part for part in command))
    if args.dry_run:
        return 0
    if args.check:
        result = subprocess.run(command, capture_output=True, text=True, errors="replace", timeout=args.timeout)
        errors = [line for line in (result.stdout + result.stderr).splitlines() if ERROR_LINE.search(line)]
        for line in errors[:30]:
            print(line, file=sys.stderr)
        ok = result.returncode == 0 and not errors
        say(("PASS" if ok else "FAIL") + " — exit %d, %d error line(s)" % (result.returncode, len(errors)))
        return 0 if ok else 1
    if args.wait:
        return subprocess.run(command).returncode
    log = cache_home() / (log_name + ".log")
    handle = open(log, "w")
    options = {"stdout": handle, "stderr": subprocess.STDOUT}
    if sys.platform == "win32":
        options["creationflags"] = 0x00000008 | 0x00000200   # DETACHED_PROCESS | CREATE_NEW_PROCESS_GROUP
    else:
        options["start_new_session"] = True
    process = subprocess.Popen(command, **options)
    time.sleep(2.0)
    if process.poll() is not None:
        handle.close()
        print(log.read_text(errors="replace")[-3000:], file=sys.stderr)
        fail("Godot exited immediately (exit %s). Log: %s" % (process.returncode, log))
    say("window opened (pid %d). Close it when done. Log: %s" % (process.pid, log))
    return 0


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("target", nargs="?", default="gallery",
                        help="gallery (default) | medieval | demo | list | res://path/scene.tscn")
    parser.add_argument("--preset", choices=None, help="preset id for gallery/scene runs, e.g. scifi_dark")
    parser.add_argument("--size", default="1280x800", help="window size WxH (default 1280x800)")
    parser.add_argument("--phone", action="store_true", help="portrait phone window, 390x844")
    parser.add_argument("--explore", help="demo only: open one chapter (see `list`)")
    parser.add_argument("--project", help="Godot project folder (default: search upward from the cwd)")
    parser.add_argument("--source", help="gohud add-on folder to preview")
    parser.add_argument("--in-project", action="store_true", help="run gohud's example inside your project")
    parser.add_argument("--check", action="store_true", help="headless smoke test, no window")
    parser.add_argument("--frames", type=int, default=120, help="frames to run with --check (default 120)")
    parser.add_argument("--timeout", type=int, default=300, help="seconds before --check gives up")
    parser.add_argument("--wait", action="store_true", help="stay attached until the window closes")
    parser.add_argument("--dry-run", action="store_true", help="print the commands only")
    parser.add_argument("--update", action="store_true", help="git pull the cached clone first")
    parser.add_argument("--godot", help="Godot 4.6+ executable")
    args = parser.parse_args()

    if args.target == "list":
        print("targets : gallery, medieval, demo, res://<your scene>.tscn")
        print("presets : " + ", ".join(PRESETS) + " (plus any themes/presets/<id>.tres)")
        print("demo    : --explore " + " | ".join(DEMO_CHAPTERS))
        return 0
    shape = re.fullmatch(r"(\d+)x(\d+)", args.size)
    if not shape:
        fail("--size must look like 1280x800", 2)
    size = (390, 844) if args.phone else (int(shape.group(1)), int(shape.group(2)))
    godot, version = find_godot(args.godot)
    project = find_project(args.project or os.getcwd())
    say("Godot %d.%d at %s" % (version + (godot,)))
    base = [godot] + (["--headless", "--quit-after", str(args.frames)] if args.check else
                      ["--resolution", "%dx%d" % size])

    own_scene = args.target.startswith("res://") and not args.target.startswith("res://addons/gohud/")
    if own_scene or args.in_project:
        if project is None:
            fail("no project.godot found — pass --project DIR", 2)
        if not is_gohud(project / "addons" / "gohud"):
            fail("%s has no res://addons/gohud — install the add-on first" % project, 2)
        scene = SCENES.get(args.target, args.target)
        if not args.dry_run:
            import_project(godot, project, False)
        return run(base + ["--path", str(project), scene], args, "project")

    source, origin = find_source(args, project)
    say("gohud source: %s (%s)" % (source, origin))
    # --dry-run prints the command without copying, importing or launching anything.
    if args.target == "demo":
        app = cache_home() / "demo" / "app" if args.dry_run else prepare_demo(godot, version, source)
        extra = ["--", "--explore=%s" % args.explore] if args.explore else []
        return run(base + ["--path", str(app)] + extra, args, "demo")
    scene = SCENES.get(args.target, args.target)
    if not scene.startswith("res://"):
        fail("unknown target %r — try `list`" % args.target, 2)
    folder = cache_home() / "sandbox" if args.dry_run else prepare_sandbox(godot, version, source, args.preset, size)
    return run(base + ["--path", str(folder), scene], args, "sandbox")


if __name__ == "__main__":
    sys.exit(main())
