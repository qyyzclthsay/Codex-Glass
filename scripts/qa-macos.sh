#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ARCH="$(uname -m)"
APP="$ROOT/dist/macos-$ARCH/Codex Glass.app"
QA="$ROOT/.qa/macos-$ARCH"
mkdir -p "$QA"
export CODEX_GLASS_QA_DIR="$QA"
export CODEX_GLASS_DATA_DIR="$QA/profile"
# Run the packaged app without SwiftPM's original resource directory present.
# This catches packages that only work on the build machine.
RESOURCE="$(find "$ROOT/macos/.build" -path '*/release/CodexGlass_CodexGlass.bundle' -type d | head -1)"
if [[ -n "$RESOURCE" ]]; then mv "$RESOURCE" "$RESOURCE.qa-hidden"; fi
restore() { if [[ -n "$RESOURCE" && -d "$RESOURCE.qa-hidden" ]]; then mv "$RESOURCE.qa-hidden" "$RESOURCE"; fi; }
trap restore EXIT
python3 - "$APP/Contents/MacOS/CodexGlass" "$QA" <<'PY'
import json, os, subprocess, sys, time
exe, qa = sys.argv[1:]
try:
    subprocess.run([exe, '--demo', '--smoke-test'], check=True, timeout=90)
except (subprocess.CalledProcessError, subprocess.TimeoutExpired):
    # Only the isolated demo is launched by the debugger; no real account data.
    with open(os.path.join(qa, 'smoke-backtrace.txt'), 'w') as trace:
        try:
            subprocess.run(['lldb', '--batch', '-o', 'run', '-o', 'thread backtrace all',
                            '--', exe, '--demo', '--smoke-test'], stdout=trace,
                           stderr=subprocess.STDOUT, timeout=60)
        except subprocess.TimeoutExpired:
            trace.write('\nDebugger timed out.\n')
    raise
screens = [name for name in os.listdir(qa) if name.endswith('.png')]
if len(screens) < 3:
    raise SystemExit('Smoke test must produce overview, settings and mini screenshots')
samples = []
process = subprocess.Popen([exe, '--demo', '--measure-demo'])
try:
    for delay in (2, 5, 5):
        time.sleep(delay)
        if process.poll() is not None:
            raise SystemExit('Demo process exited during memory measurement')
        rss = int(subprocess.check_output(['ps', '-o', 'rss=', '-p', str(process.pid)], text=True).strip())
        children = subprocess.run(['pgrep', '-P', str(process.pid)], capture_output=True, text=True)
        samples.append({'rssMiB': round(rss / 1024, 2), 'childPids': children.stdout.split()})
finally:
    process.terminate()
    try: process.wait(timeout=5)
    except subprocess.TimeoutExpired:
        process.kill(); process.wait()
report = {'mode': 'demo overview, no network or account', 'metric': 'resident set size; not Windows private memory',
          'samples': samples, 'screenshots': sorted(screens)}
with open(os.path.join(qa, 'memory.json'), 'w') as f: json.dump(report, f, indent=2)
print(json.dumps(report))
PY
