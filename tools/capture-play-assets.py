#!/usr/bin/env python3
"""Localized real Android captures in the isolated QA app; restore emulator settings."""
import subprocess, pathlib, re, sys, json, time
root=pathlib.Path(__file__).resolve().parents[1]
adb=['/Users/solkim/Library/Android/sdk/platform-tools/adb','-s','emulator-5554']
pkg='com.solkim.baseball.android.reset.compose.qa'
proof=root/'marketing/google-play/2026-09-production/sources';proof.mkdir(parents=True,exist_ok=True)
def run(args):return subprocess.check_output(adb+args,text=True)
def instrument(name,lang,log):
 return subprocess.Popen(adb+['shell','am','instrument','-w','-r','-e','storeLocale',lang,'-e','class','com.solkim.baseball.android.'+name,pkg+'.test/androidx.test.runner.AndroidJUnitRunner'],stdout=log,stderr=subprocess.STDOUT)
size=run(['shell','wm','size']);restore=re.search(r'Override size: (\d+x\d+)',size)
locale=run(['shell','cmd','locale','get-app-locales',pkg]);original=re.search(r'are \[(.*?)\]',locale).group(1)
(proof/'capture-environment.json').write_text(json.dumps({'wmSizeBefore':size,'appLocaleBefore':original},indent=2))
stills='--stills-only' in sys.argv
langs=[x for x in sys.argv[1:] if not x.startswith('--')] or ['ko','en','ja'];assert all(x in ['ko','en','ja'] for x in langs)
recorder=None;pid=None
try:
 run(['shell','wm','size','1080x2160'])
 for lang in langs:
  run(['shell','cmd','locale','set-app-locales',pkg,'--user','0','--locales',lang])
  with (proof/f'capture-{lang}-static.log').open('w') as log:
   process=instrument('StoreMarketingCaptureTest',lang,log);process.wait(timeout=120)
  assert 'OK (1 test)' in (proof/f'capture-{lang}-static.log').read_text(),'Static capture failed: '+lang
  if stills:
   out=root/'apps/promo/public/play-2026-09/captures'/lang;out.mkdir(parents=True,exist_ok=True)
   for name in ['training','conversation','draft','legacy','contract','pro-week','album']:
    (out/f'{name}.png').write_bytes(subprocess.check_output(adb+['exec-out','run-as',pkg,'cat',f'cache/store-{lang}-{name}.png']))
   print('Captured stills '+lang,flush=True)
   continue
  for marker in ['ready','recording']:
   run(['shell','run-as',pkg,'rm','-f',f'cache/store-{lang}-{marker}'])
  with (proof/f'capture-{lang}-live.log').open('w') as log:
   process=instrument('StoreMarketingLiveCaptureTest',lang,log)
   deadline=time.time()+40
   while time.time()<deadline:
    ready=subprocess.run(adb+['shell','run-as',pkg,'test','-f',f'cache/store-{lang}-ready'],capture_output=True)
    if ready.returncode==0:break
    if process.poll() is not None:raise RuntimeError('Live capture exited before ready: '+lang)
    time.sleep(.25)
   else:raise TimeoutError('Pitch input not ready')
   with (proof/f'recorder-{lang}.log').open('w') as errors:
    recorder=subprocess.Popen(adb+['shell',f'echo $$; exec screenrecord --bit-rate 12000000 --time-limit 20 /sdcard/baseball-store-{lang}-pitch.mp4'],stdout=subprocess.PIPE,stderr=errors,text=True)
    pid=recorder.stdout.readline().strip();assert pid.isdigit(),pid
    run(['shell','run-as',pkg,'touch',f'cache/store-{lang}-recording'])
    process.wait(timeout=60)
    run(['shell','kill','-INT',pid]);recorder.wait(timeout=8);recorder=None;pid=None
  assert 'OK (1 test)' in (proof/f'capture-{lang}-live.log').read_text(),'Live capture failed: '+lang
  out=root/'apps/promo/public/play-2026-09/captures'/lang;out.mkdir(parents=True,exist_ok=True)
  for name in ['training','conversation','draft','legacy','contract','pro-week','album','pitch','result']:
   (out/f'{name}.png').write_bytes(subprocess.check_output(adb+['exec-out','run-as',pkg,'cat',f'cache/store-{lang}-{name}.png']))
  for name in ['static','live']:
   (proof/f'{lang}-{name}.json').write_bytes(subprocess.check_output(adb+['exec-out','run-as',pkg,'cat',f'cache/store-{lang}-{name}-proof.json']))
  subprocess.run(adb+['pull',f'/sdcard/baseball-store-{lang}-pitch.mp4',str(out/'pitch-raw.mp4')],check=True)
  print('Captured '+lang,flush=True)
finally:
 if pid:
  subprocess.run(adb+['shell','kill','-INT',pid],capture_output=True)
 if recorder:
  try:recorder.wait(timeout=8)
  except subprocess.TimeoutExpired:recorder.terminate()
 run(['shell','wm','size',restore.group(1) if restore else 'reset'])
 args=['shell','cmd','locale','set-app-locales',pkg,'--user','0']
 if original:args+=['--locales',original]
 run(args)
