#!/usr/bin/env python3
import json,hashlib,pathlib,subprocess
repo=pathlib.Path(__file__).resolve().parents[1]
root=repo/'apps/ios/releases/1.2.10/evidence-b69'
creative=repo/'marketing/appstore/2026-09-refresh'
locales=json.loads((root/'localizations-before.json').read_text())['data']
summary=[]
def call(args,name):
 p=subprocess.run(['asc',*args],text=True,capture_output=True)
 (root/(name+'.json')).write_text(p.stdout)
 if p.returncode: raise RuntimeError(p.stderr)
 return json.loads(p.stdout)
for row in locales:
 locale=row['attributes']['locale'];identifier=row['id'];lang=locale if locale in ['ko','ja'] else 'en'
 folder={'ko':'ko-KR','ja':'ja-JP','en':'en-US'}[lang]
 shots=call(['screenshots','list','--version-localization',identifier],locale+'-screens-final')
 movies=call(['video-previews','list','--version-localization',identifier],locale+'-videos-final')
 for device,size in [('67','6.9'),('65','6.5')]:
  items=next(s['screenshots'] for s in shots['sets'] if s['set']['attributes']['screenshotDisplayType']=='APP_IPHONE_'+device)
  assert [s['attributes']['fileName'] for s in items]==[f'{n:02d}.png' for n in range(1,9)],(locale,size)
  for item in items:
   a=item['attributes'];assert a['assetDeliveryState']['state']=='COMPLETE',a
   assert a['sourceFileChecksum']==hashlib.md5((creative/folder/f'screenshots-{size}'/a['fileName']).read_bytes()).hexdigest()
  previews=next(s['previews'] for s in movies['sets'] if s['set']['attributes']['previewType']=='IPHONE_'+device)
  assert len(previews)==1,(locale,size,len(previews))
  a=previews[0]['attributes'];assert a['assetDeliveryState']['state']=='COMPLETE',a
  assert a['sourceFileChecksum']==hashlib.md5((creative/folder/'preview'/f'app-preview-{lang}-886x1920.mp4').read_bytes()).hexdigest()
  call(['video-previews','set-poster-frame','--id',previews[0]['id'],'--time-code','00:00:01:15'],f'{locale}-poster-{size}')
  summary.append({'locale':locale,'size':size,'screenshots':len(items),'previews':1,'delivery':'COMPLETE','checksumsMatch':True,'posterTimeCode':'00:00:01:15'})
 print('VERIFIED',locale,flush=True)
(root/'media-verification.json').write_text(json.dumps(summary,indent=2))
print('VERIFIED',sum(x['screenshots'] for x in summary),'screenshots',sum(x['previews'] for x in summary),'preview placements',flush=True)
