#!/usr/bin/env python3
"""6.9인치(1320×2868) 최종본 → 6.5인치(1284×2778) 파생.

비율 차(0.4603 vs 0.4622)는 좌우 3px 패드로 흡수 — 눈에 안 보인다.
"""
import os
from PIL import Image

SRC = os.path.dirname(os.path.abspath(__file__))
DST = os.path.join(SRC, "65")
os.makedirs(DST, exist_ok=True)
BG = (5, 10, 21)

for name in sorted(os.listdir(SRC)):
    if not (name.startswith("final-") and name.endswith(".png")):
        continue
    img = Image.open(os.path.join(SRC, name)).convert("RGB")
    h = 2778
    w = round(img.width * h / img.height)
    img = img.resize((w, h), Image.LANCZOS)
    canvas = Image.new("RGB", (1284, 2778), BG)
    canvas.paste(img, ((1284 - w) // 2, 0))
    canvas.save(os.path.join(DST, name), "PNG")
    print("65:", name)
