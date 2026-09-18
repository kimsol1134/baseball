#!/usr/bin/env python3
"""Render the short air/sweep release cue described by iOS GameAudio.voices(.pitchRelease)."""
from pathlib import Path
import math
import random
import struct
import wave

rate = 48000
rng = random.Random(20260906)
low = high = phase = 0.0
frames = []
for index in range(round(rate * .11)):
    t = index / rate
    noise = rng.uniform(-1, 1)
    low += (1 - math.exp(-2 * math.pi * 3000 / rate)) * (noise - low)
    high += (1 - math.exp(-2 * math.pi * 1100 / rate)) * (low - high)
    air = (low - high) * min(1, t / .006) * max(0, 1 - t / .11) ** 1.4 * .16
    phase += 2 * math.pi * (260 - 110 * min(1, t / .09)) / rate
    sweep = math.sin(phase) * min(1, t / .004) * max(0, 1 - t / .09) ** 1.5 * .03
    frames.append(struct.pack('<h', round(max(-1, min(1, air + sweep)) * 32767)))
target = Path(__file__).resolve().parent.parent / 'apps/android/platform/src/main/res/raw/baseball_pitch_release.wav'
with wave.open(str(target), 'wb') as output:
    output.setparams((1, 2, rate, 0, 'NONE', 'not compressed'))
    output.writeframes(b''.join(frames))
print(target)
