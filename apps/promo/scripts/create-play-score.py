#!/usr/bin/env python3
"""Original, deterministic instrumental bed. No samples or borrowed melody."""
from pathlib import Path
import numpy as np, wave
sr=48000; duration=30; n=sr*duration
rng=np.random.default_rng(7819); mix=np.zeros(n,dtype=np.float64)
def add(start, sound, gain=1):
 i=int(start*sr); end=min(n,i+len(sound))
 if i<n: mix[i:end]+=sound[:end-i]*gain
def midi(v): return 440*2**((v-69)/12)
for bar in range(15):
 chord=[[45,52,60,67],[41,48,57,64],[48,55,60,64],[43,50,59,65]][bar%4]
 t=np.arange(int(2.1*sr))/sr; env=np.minimum(t/.07,1)*np.exp(-t*1.7)
 pad=sum(np.sin(2*np.pi*midi(k)*t)+.13*np.sin(2*np.pi*midi(k)*2*t) for k in chord)*env*.032
 add(bar*2,pad)
 for k in range(8):
  t=np.arange(int(.32*sr))/sr; f=midi(chord[(k+bar)%4]+12)
  add(bar*2+k*.25,np.sin(2*np.pi*f*t)*np.minimum(t/.009,1)*np.exp(-t*14),.045)
for beat in range(60):
 t=np.arange(int(.22*sr))/sr
 phase=2*np.pi*(48*t+70*(1-np.exp(-t*36))/36)
 add(beat*.5,np.sin(phase)*np.exp(-t*18),.33 if beat%4==0 else .23)
 if beat%2:
  t=np.arange(int(.16*sr))/sr; noise=rng.uniform(-1,1,len(t)); noise=np.r_[0,np.diff(noise)]
  add(beat*.5,noise*np.exp(-t*31),.075)
for eighth in range(120):
 t=np.arange(int(.035*sr))/sr; noise=rng.uniform(-1,1,len(t)); noise=np.r_[0,np.diff(noise)]
 add(eighth*.25,noise*np.exp(-t*100),.022)
# Controlled final cadence and an original transition wash.
for at in [6,10,14,17,20,23,27]:
 t=np.arange(int(.18*sr))/sr; noise=rng.uniform(-1,1,len(t)); add(at-.09,noise*np.sin(np.pi*np.arange(len(t))/len(t))*.035)
mix=np.tanh(mix*1.5)*.8
fade=np.minimum(np.arange(n)/(sr*.2),1)*np.minimum(np.arange(n)[::-1]/(sr*1.4),1); mix*=fade
stereo=np.column_stack([mix,np.roll(mix,53)*.96])
out=Path(__file__).resolve().parents[1]/'public/play-2026-09/original-score.wav'
with wave.open(str(out),'wb') as f:f.setnchannels(2);f.setsampwidth(2);f.setframerate(sr);f.writeframes((stereo*32767).astype('<i2').tobytes())
print(out)
