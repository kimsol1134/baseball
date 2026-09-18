#!/usr/bin/env python3
"""Freeze real simulator footage at capture markers for deterministic Remotion rendering."""
import hashlib
import json
import pathlib
import re
import shutil
import subprocess
import sys

locale = sys.argv[1]
log = pathlib.Path(sys.argv[2]).expanduser()
legacy_log = pathlib.Path(sys.argv[3]).expanduser() if len(sys.argv) > 3 else None
repo = pathlib.Path(__file__).resolve().parents[3]
root = repo / "marketing/appstore/2026-09-refresh"
public = repo / "apps/promo/public/asc-2026-09" / locale
public.mkdir(parents=True, exist_ok=True)
def markers(p):
    return {name: float(t) for lang, name, t in re.findall(r"ASC_REFRESH (\w+) ([\w-]+) ([\d.]+)", p.read_text()) if lang == locale}
times = markers(log)
matches = json.loads((root / 'sources' / f'{locale}-pixel-matches.json').read_text())
started = json.loads((root / "sources" / f"{locale}-recording.json").read_text())["startedAt"]
raw = root / "sources" / f"{locale}-raw.mp4"
plan = [
    ("pitch", "throw-start", -.50, 4.5, 4.5),
    ("growth", "training-start", .35, 3.5, 3.5),
    ("decision", "decision", .1, 2.8, 3),
    ("contract", "contract", .1, 2.8, 3.5),
    ("records", "records", .1, 2.8, 3.5),
    ("album", "replay-start", .05, 2.8, 3),
    ("legacy", "legacy", .1, 2.8, 3.5),
    ("rebirth", "rebirth", .1, 2.3, 3.5),
]
ledger = []
normalized = {}
for scene, marker, offset, take, duration in plan:
    source, base, marks = raw, started, times
    if scene == "legacy" and legacy_log:
        source = root / "sources" / f"{locale}-legacy-raw.mp4"
        base = json.loads((root / "sources" / f"{locale}-legacy-recording.json").read_text())["startedAt"]
        marks = markers(legacy_log)
    start = max(0, marks[marker] - base + offset)
    match = matches[scene]
    source = root / 'sources' / match['source']
    if match['meanPixelError'] > 10:
        raise RuntimeError(f"{locale}/{scene}: no visually verified source match; recapture required")
    start = max(0, match['to'] - .25) if scene == 'pitch' else max(0, match['from'] + .1)
    if scene == 'growth': start = max(0, match['from'] - .5)
    if scene not in ['pitch','growth','album']:
        take = min(take, max(.5, match['to'] - start))
    target = public / f"{scene}.mp4"
    if source not in normalized:
        # Simulator recording is variable frame rate and may contain no new frame during a
        # static screen. Normalize before seeking so a quiet interval still has real frames.
        normal = source.with_name(source.stem + "-cfr.mp4")
        subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", str(source),
                        "-vf", "fps=30,scale=886:1920:force_original_aspect_ratio=increase,crop=886:1920,setsar=1",
                        "-an", "-c:v", "libx264", "-preset", "veryfast", "-crf", "18", "-pix_fmt", "yuv420p",
                        "-movflags", "+faststart", str(normal)], check=True)
        normalized[source] = normal
    subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-ss", str(start), "-t", str(take),
                    "-i", str(normalized[source]), "-vf", "tpad=stop_mode=clone:stop_duration=2",
                    "-t", str(duration), "-an", "-c:v", "libx264", "-preset", "fast", "-crf", "18", "-pix_fmt", "yuv420p",
                    "-movflags", "+faststart", str(target)], check=True)
    capture = pathlib.Path("/tmp/baseball-asc-refresh") / locale / f"{scene}.png"
    shutil.copy2(capture, public / capture.name)
    ledger.append({"scene": scene, "source": source.name, "start": start, "take": take, "duration": duration, 'pixelMatch': match,
                   "clip": str(target.relative_to(repo)), "sha256": hashlib.sha256(target.read_bytes()).hexdigest(),
                   "screenshotSha256": hashlib.sha256(capture.read_bytes()).hexdigest()})
    print(f"FROZEN {locale} {scene} {start:.2f}s → {duration:.1f}s", flush=True)
(root / "sources" / f"{locale}-capture-ledger.json").write_text(json.dumps({"locale": locale, "captureLog": str(log),
    "legacyCaptureLog": str(legacy_log) if legacy_log else None, "sources": ledger}, indent=2, ensure_ascii=False))
for path in normalized.values():
    path.unlink()
