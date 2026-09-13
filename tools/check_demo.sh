#!/usr/bin/env bash
# Standalone demo integration checks, with error-log and timeout guards.
# GODOT_BIN=/path/to/godot bash tools/check_demo.sh
set -euo pipefail
ADDON="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT_BIN:-$(command -v godot || true)}"
[ -n "$GODOT" ] || { echo "Godot not found" >&2; exit 2; }
bash "$ADDON/examples/demo/run.sh" --setup
python3 - "$ADDON" "$GODOT" <<'PY'
import os, pathlib, re, subprocess, sys, tempfile
addon, godot = sys.argv[1:]
project = str(pathlib.Path(addon) / 'examples/demo')
output = pathlib.Path(tempfile.mkdtemp(prefix='gohud-demo-check-'))
print(f'Demo check logs: {output}', flush=True)

def run(name, args, env=None, marker=None):
    log = output / f'{name}.log'
    try:
        with log.open('w') as stream:
            result = subprocess.run([godot, '--headless', '--path', project, *args],
                                    stdout=stream, stderr=subprocess.STDOUT, env=env, timeout=240)
    except subprocess.TimeoutExpired:
        print(f'FAIL {name}: timed out; {log}', flush=True)
        sys.exit(1)
    text = log.read_text()
    if result.returncode or re.search(r'SCRIPT ERROR:|^ERROR:', text, re.M) or (marker and marker not in text):
        print(text[-16000:])
        print(f'FAIL {name}: {log}', flush=True)
        sys.exit(1)
    print(f'PASS {name}', flush=True)

run('import', ['--import'])
for size in ['1680x940', '720x450', '390x844']:
    run(size, ['--fixed-fps', '60', '-s', 'res://addons/gohud/tests/sim_test.gd'],
        dict(os.environ, DEMO_TEST_SIZE=size), marker='DEMO TEST RESULT:')
print('gohud demo tests: PASS', flush=True)
PY
