from pathlib import Path
from fontTools.ttLib import TTFont
from fontTools.pens.svgPathPen import SVGPathPen
import base64,json
root=Path(__file__).resolve().parents[3]
out=Path(__file__).resolve().parent
font=TTFont(root/'apps/promo/public/play-2026-09/fonts/GmarketSansBold.woff')
glyphs=font.getGlyphSet(); cmap=font.getBestCmap(); upm=font['head'].unitsPerEm

def text(s,x,y,size,color):
    scale=size/upm; parts=[]
    for c in s:
        if c == ' ':
            x += size * 0.3
            continue
        g=glyphs[cmap.get(ord(c),'.notdef')]; pen=SVGPathPen(glyphs); g.draw(pen)
        parts.append(f'<path d="{pen.getCommands()}" transform="translate({x:.2f} {y}) scale({scale} {-scale})" fill="{color}"/>')
        x+=g.width*scale
    return ''.join(parts)


def picture(path,x,y,w,h):
    data=base64.b64encode(path.read_bytes()).decode()
    return f'<image x="{x}" y="{y}" width="{w}" height="{h}" preserveAspectRatio="xMidYMid meet" href="data:image/png;base64,{data}"/>'

for name,H in [('review-feed',1350),('review-story',1920)]:
    story=H==1920
    s=f'<svg xmlns="http://www.w3.org/2000/svg" width="1080" height="{H}" viewBox="0 0 1080 {H}">'
    s+=f'<rect width="1080" height="{H}" fill="#10271e"/>'
    s+='<circle cx="1100" cy="210" r="340" fill="none" stroke="#31523b" stroke-width="2"/>'
    top=100 if story else 70
    s+=text('야구 못하면 또 환생함',64,top,28,'#f4efdf')
    s+=text('먼저 플레이한 유저의 한마디',64,top+75,28,'#bdf56a')
    s+=text('“더 맘놓고 재밌게',60,top+178,66,'#f4efdf')
    s+=text('즐기는중입니다.”',60,top+269,76,'#bdf56a')
    s+=text('한국 App Store · 별점 5개 리뷰 본문 일부',64,top+328,23,'#c2ccbf')
    y=top+370
    s+=picture(out/'sources/review-original.png',64,y,952,272)
    s+=text('리뷰 원문 캡처 · skdneksls · 2026.08.31',64,y+307,22,'#c2ccbf')
    sy=y+359
    if story:
        s+=text('직접 던지고,',64,sy+60,42,'#f4efdf')
        s+=text('내 투수로 키우고.',64,sy+119,42,'#f4efdf')
        s+=text('은퇴 후에는',64,sy+235,30,'#c2ccbf')
        s+=text('다음 야구 인생으로.',64,sy+282,30,'#c2ccbf')
        s+=picture(root/'apps/promo/public/play-2026-09/captures/ko/pitch.png',580,sy,430,800)
        foot=1770
    else:
        s+=text('직접 던지고,',64,sy+61,42,'#f4efdf')
        s+=text('내 투수로 키우고.',64,sy+120,42,'#f4efdf')
        s+=text('은퇴 후에는',64,sy+218,29,'#c2ccbf')
        s+=text('다음 야구 인생으로.',64,sy+263,29,'#c2ccbf')
        s+=picture(root/'apps/promo/public/play-2026-09/captures/ko/pitch.png',733,sy-4,240,446)
        foot=1266
    s+=text('안드로이드에서도 즐겨보세요!',64,foot-34,32,'#bdf56a')
    s+=text('리뷰: iOS 이용자 · 게임 화면: Android · 캡처: 2026.09.14',64,foot+24,19,'#c2ccbf')
    s+='</svg>'
    (out/f'{name}.svg').write_text(s)
