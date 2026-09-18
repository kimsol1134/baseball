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

cards=[('01-one-more-life', 'legacy', ['한 이닝만 더?', '이번엔 한 생만 더!'], '01  /  은퇴 다음은, 환생', ['이번 생의 아쉬움,', '다음 생의 도전으로.'], ['남긴 능력을 이어받아', '다시 마운드에 오르세요.'], ['야구 인생은 끝나도,', '다음 도전은 계속됩니다!']), ('02-your-next-ace', 'pitch', ['다음 생의 에이스도,', '한 구는 내 손으로!'], '02  /  직접 던지는 투수 성장 RPG', ['구종과 코스를 고르고,', '타이밍 맞춰 릴리스!'], ['슬라이더를 누른 뒤', '원하는 순간에 놓으세요.'], ['성장에 손맛까지 담았습니다.', '안드로이드에서 즐겨보세요!'])]
for name,screen,head,kicker,body,detail,end in cards:
    im=base64.b64encode((root/f'apps/promo/public/play-2026-09/captures/ko/{screen}.png').read_bytes()).decode()
    s='<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="1080" height="1350" viewBox="0 0 1080 1350">'
    s+='<rect width="1080" height="1350" fill="#10271e"/><circle cx="1040" cy="140" r="300" fill="none" stroke="#294738" stroke-width="2"/><circle cx="1040" cy="140" r="360" fill="none" stroke="#294738" stroke-width="2"/>'
    s+=text('야구 못하면 또 환생함',64,74,25,'#efe9d9')
    s+=text('ANDROID',849,74,21,'#bdf56a')
    for i,line in enumerate(head):s+=text(line,60,185+i*97,76,'#f4efdf' if i==0 else '#bdf56a')
    s+='<line x1="64" y1="325" x2="1016" y2="325" stroke="#48614c"/>'
    s+=text(kicker,64,411,25,'#bdf56a')
    for i,line in enumerate(body):s+=text(line,64,505+i*53,36,'#f4efdf')
    for i,line in enumerate(detail):s+=text(line,64,662+i*44,25,'#b8c4b9')
    s+='<path d="M65 799 H190 M175 786 L190 799 L175 812" fill="none" stroke="#bdf56a" stroke-width="3"/>'
    for i,line in enumerate(end):s+=text(line,64,889+i*46,28,'#f4efdf')
    s+='<rect x="550" y="363" width="482" height="875" rx="23" fill="#060e0b" stroke="#46614f" stroke-width="2"/>'
    s+=f'<image x="570" y="379" width="442" height="843" preserveAspectRatio="xMidYMid meet" xlink:href="data:image/png;base64,{im}"/>'
    s+=text('실제 Android 게임 화면',650,1262,18,'#b8c4b9')
    s+=text('내 선택으로 이어 가는 투수 성장 RPG',64,1310,22,'#b8c4b9')
    s+='</svg>'
    (out/f'{name}.svg').write_text(s)
(out/'cards.json').write_text(json.dumps(cards,ensure_ascii=False,indent=2))
