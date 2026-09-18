#!/usr/bin/env python3
"""Find footage by its actual pixels: Simulator timestamps can pause during app relaunches."""
import json
import pathlib
import subprocess
import sys
import numpy as np
from PIL import Image

locale=sys.argv[1]
repo=pathlib.Path(__file__).resolve().parents[3]
root=repo/'marketing/appstore/2026-09-refresh'
scenes=['pitch','growth','decision','contract','records','album','legacy','rebirth']
cache={}
result={}
for scene in scenes:
 source=root/'sources'/f'{locale}-raw.mp4'
 if scene in ['pitch','rebirth']:
  opening=root/'sources'/f'{locale}-opening-raw.mp4'
  if opening.exists() and opening.stat().st_size>500: source=opening
 if scene=='legacy' and locale=='ko': source=root/'sources'/'ko-legacy-raw.mp4'
 if source not in cache:
  raw=subprocess.check_output(['ffmpeg','-hide_banner','-loglevel','error','-i',str(source),'-vf','fps=2,scale=120:260','-pix_fmt','rgb24','-f','rawvideo','-'])
  cache[source]=np.frombuffer(raw,dtype=np.uint8).reshape(-1,260,120,3)
 target=np.asarray(Image.open(pathlib.Path('/tmp/baseball-asc-refresh')/locale/(scene+'.png')).convert('RGB').resize((120,260)))
 frames=cache[source]
 errors=np.abs(frames[:,22:242].astype(np.float32)-target[22:242].astype(np.float32)).mean(axis=(1,2,3))
 best=int(np.argmin(errors));minimum=float(errors[best])
 matches=np.where(errors<=minimum+0.9)[0]
 # Keep the contiguous stable interval around the best match.
 lo=hi=best
 while lo>0 and lo-1 in matches: lo-=1
 while hi+1<len(errors) and hi+1 in matches: hi+=1
 result[scene]={'source':source.name,'best':best/2,'from':lo/2,'to':hi/2,'meanPixelError':minimum,
                'nearest':[[int(i)/2,round(float(errors[i]),2)] for i in np.argsort(errors)[:8]]}
 print(scene,json.dumps(result[scene]),flush=True)
(root/'sources'/f'{locale}-pixel-matches.json').write_text(json.dumps(result,indent=2))
