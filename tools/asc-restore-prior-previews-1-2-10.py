#!/usr/bin/env python3
"""Append the user's selected prior previews without replacing the new preview."""
import hashlib,json,pathlib,subprocess,sys,time
repo=pathlib.Path(__file__).resolve().parents[1]
root=repo/'apps/ios/releases/1.2.10/evidence-b69'
rows=json.loads((root/'localizations-before.json').read_text())['data']
mode=sys.argv[1]
def call(args,name):
 p=subprocess.run(['asc',*args],capture_output=True,text=True)
 (root/(name+'.json')).write_text(p.stdout)
 if p.returncode: raise RuntimeError(p.stderr)
 return json.loads(p.stdout)
for row in rows:
 locale=row['attributes']['locale'];identifier=row['id']
 if mode=='international' and locale=='ko':continue
 if mode!='international' and locale!='ko':continue
 if locale=='ko':
  names=['02-a3-rebirth.mp4','03-p1-growth-journey.mp4'] if mode=='rebirth-growth' else ['01-a1-last-ball.mp4','02-a3-rebirth.mp4']
  paths=[repo/'marketing/appstore/previews-1.2.2-font'/n for n in names]
 else:
  paths=[repo/'marketing/appstore/previews-1.2.1'/('p1-ja.mp4' if locale=='ja' else 'p1-en.mp4')]
 before=json.loads((root/f'{locale}-video-previews-before.json').read_text())
 for device in ['67','65']:
  old=next(s['previews'] for s in before['sets'] if s['set']['attributes']['previewType']=='IPHONE_'+device)
  for path in paths:
   checksum=hashlib.md5(path.read_bytes()).hexdigest()
   match=next(p for p in old if p['attributes']['sourceFileChecksum']==checksum)
   args=['video-previews','upload','--version-localization',identifier,'--path',str(path),'--device-type','IPHONE_'+device,'--skip-existing']
   call([*args,'--dry-run'],f'{locale}-{device}-{path.stem}-restore-plan')
   for attempt in range(3):
    current=call(['video-previews','list','--version-localization',identifier],f'{locale}-prior-preview-status')
    group=next(s['previews'] for s in current['sets'] if s['set']['attributes']['previewType']=='IPHONE_'+device)
    for incomplete in group:
     a=incomplete['attributes']
     if a.get('fileName')==path.name and a.get('assetDeliveryState',{}).get('state')!='COMPLETE':
      call(['video-previews','delete','--id',incomplete['id'],'--confirm'],f'{locale}-{device}-{path.stem}-cleanup-{attempt}')
    try:
     uploaded=call(args,f'{locale}-{device}-{path.stem}-restored')
     break
    except RuntimeError:
     if attempt==2: raise
     print('RETRY',locale,device,path.name,attempt+1,flush=True)
     time.sleep(2)
   print('RESTORED',locale,device,path.name,flush=True)
   current=call(['video-previews','list','--version-localization',identifier],f'{locale}-prior-preview-status')
   group=next(s['previews'] for s in current['sets'] if s['set']['attributes']['previewType']=='IPHONE_'+device)
   target=next(p for p in group if p['attributes']['sourceFileChecksum']==checksum)
   assert target['attributes']['assetDeliveryState']['state']=='COMPLETE'
   call(['video-previews','set-poster-frame','--id',target['id'],'--time-code',match['attributes'].get('previewFrameTimeCode','00:00:01:00')],f'{locale}-{device}-{path.stem}-poster-restored')
