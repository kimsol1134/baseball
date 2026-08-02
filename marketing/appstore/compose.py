#!/usr/bin/env python3
"""앱스토어 스크린샷 캡션 합성기.

원본 캡처(1320×2868)를 브랜드 배경 위에 축소·라운딩해 얹고, 위에 큰 한국어
헤드라인 두 줄을 놓는다. 검색 결과 카드에서 스크린샷은 절반 크기로 보이므로
헤드라인이 커야 읽힌다.
"""
import sys
from PIL import Image, ImageDraw, ImageFont, ImageFilter

W, H = 1320, 2868
BG = (5, 10, 21)          # fieldNight 0x050A15
ACCENT = (183, 243, 107)  # action 0xB7F36B
GOLD = (216, 181, 101)    # milestone 0xD8B565
WHITE = (244, 246, 243)
FONT = "/System/Library/Fonts/AppleSDGothicNeo.ttc"

def font(size, bold=True):
    # AppleSDGothicNeo.ttc: index 1이 Bold 계열, 실패 시 0.
    for idx in (2, 1, 0):
        try:
            return ImageFont.truetype(FONT, size, index=idx)
        except Exception:
            continue
    raise RuntimeError("font load failed")

def rounded(img, radius):
    mask = Image.new("L", img.size, 0)
    d = ImageDraw.Draw(mask)
    d.rounded_rectangle([0, 0, img.size[0], img.size[1]], radius=radius, fill=255)
    out = Image.new("RGBA", img.size)
    out.paste(img, (0, 0), mask)
    return out

def compose(src_path, line1, line2, accent_line, out_path):
    canvas = Image.new("RGB", (W, H), BG)
    draw = ImageDraw.Draw(canvas)

    # 은은한 상단 글로우 — 밋밋한 단색 배경 방지.
    glow = Image.new("RGB", (W, H), BG)
    gd = ImageDraw.Draw(glow)
    gd.ellipse([W * 0.15, -H * 0.12, W * 0.85, H * 0.16], fill=(14, 26, 44))
    glow = glow.filter(ImageFilter.GaussianBlur(160))
    canvas = Image.blend(canvas, glow, 0.85)
    draw = ImageDraw.Draw(canvas)

    # 헤드라인 (두 줄, 한 줄은 강조색).
    f_big = font(128)
    y = 150
    for text, color in ((line1, WHITE), (line2, ACCENT if accent_line == 2 else WHITE)):
        if not text:
            continue
        if accent_line == 1 and text == line1:
            color = ACCENT
        bbox = draw.textbbox((0, 0), text, font=f_big)
        tw = bbox[2] - bbox[0]
        draw.text(((W - tw) / 2, y), text, font=f_big, fill=color)
        y += 168

    # 스크린샷 본체 — 86% 축소, 라운딩, 미세 보더.
    shot = Image.open(src_path).convert("RGB")
    sw = int(W * 0.86)
    sh = int(shot.height * sw / shot.width)
    shot = shot.resize((sw, sh), Image.LANCZOS)
    shot = rounded(shot, 56)
    top = 560
    # 그림자
    shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.rounded_rectangle([(W - sw) / 2 - 8, top - 8, (W + sw) / 2 + 8, top + sh + 8],
                         radius=64, fill=(0, 0, 0, 160))
    shadow = shadow.filter(ImageFilter.GaussianBlur(40))
    canvas_rgba = canvas.convert("RGBA")
    canvas_rgba.alpha_composite(shadow)
    canvas_rgba.alpha_composite(shot, (int((W - sw) / 2), top))
    d2 = ImageDraw.Draw(canvas_rgba)
    d2.rounded_rectangle([(W - sw) / 2, top, (W + sw) / 2, top + sh],
                         radius=56, outline=(255, 255, 255, 28), width=2)

    canvas_rgba.convert("RGB").save(out_path, "PNG")
    print("OK", out_path)

if __name__ == "__main__":
    src, l1, l2, accent, out = sys.argv[1], sys.argv[2], sys.argv[3], int(sys.argv[4]), sys.argv[5]
    compose(src, l1, l2, accent, out)
