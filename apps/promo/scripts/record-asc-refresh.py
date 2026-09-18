#!/usr/bin/env python3
"""Record the existing iPhone simulator; stop with SIGINT after the capture test finishes."""
import json
import pathlib
import signal
import subprocess
import sys
import time

locale = sys.argv[1]
root = pathlib.Path(__file__).resolve().parents[3] / "marketing/appstore/2026-09-refresh/sources"
root.mkdir(parents=True, exist_ok=True)
output = root / f"{locale}-raw.mp4"
process = subprocess.Popen([
    "xcrun", "simctl", "io", "641C2F6D-BF5F-406F-B22C-FEB35CB4E4BF",
    "recordVideo", "--codec=h264", "--force", str(output),
], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
def stop(*_):
    if process.poll() is None:
        process.send_signal(signal.SIGINT)
signal.signal(signal.SIGINT, stop)
signal.signal(signal.SIGTERM, stop)
for line in process.stdout:
    print(line, end="", flush=True)
    if "Recording started" in line:
        stamp = {"locale": locale, "startedAt": time.time(), "pid": process.pid, "path": str(output)}
        (root / f"{locale}-recording.json").write_text(json.dumps(stamp, indent=2))
        print(json.dumps(stamp), flush=True)
process.wait()
