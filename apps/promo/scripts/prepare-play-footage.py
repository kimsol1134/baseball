#!/usr/bin/env python3
import json,subprocess
from pathlib import Path
root=Path(__file__).resolve().parents[1]; proof=root.parents[1]/'marketing/google-play/2026-09-production/sources'
plans={}
for lang in ['ko','en','ja']:
 base=root/'public/play-2026-09/captures'/lang; raw=base/'pitch-raw.mp4'
 meta=json.loads(subprocess.check_output(['ffprobe','-v','error','-show_entries','format=duration','-of','json',str(raw)]))
 duration=float(meta['format']['duration']); start=max(4.0,duration-2.7); length=4+duration-start
 filters=f'[0:v]split=2[a][b];[a]trim=0:4,setpts=PTS-STARTPTS[a1];[b]trim=start={start},setpts=PTS-STARTPTS[b1];[a1][b1]concat=n=2:v=1:a=0,fps=30,tpad=stop_mode=clone:stop_duration={max(0,6.7-length)},format=yuv420p[out]'
 subprocess.run(['ffmpeg','-y','-v','error','-i',str(raw),'-filter_complex',filters,'-map','[out]','-an','-c:v','libx264','-preset','medium','-crf','16','-movflags','+faststart',str(base/'pitch.mp4')],check=True)
 plans[lang]={'originalSeconds':duration,'keptSeconds':[[0,4],[start,duration]],'speed':1,'note':'Montage cut removes a result-hold/wait interval. Input and animation playback are not sped up.'}
(proof/'footage-edits.json').write_text(json.dumps(plans,indent=2))
