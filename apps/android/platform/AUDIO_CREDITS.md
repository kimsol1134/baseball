# Android 투구 효과음

2026-09-06. iOS에 사용 중인 아래 CC0 음원을 가공 없이 복사해 사용한다. 상세 출처와 가공 이력은 [iOS 음원 크레딧](../../ios/Audio/CREDITS.md)을 따른다.

- `baseball_glove_catch.wav` ← `glove-catch.wav`
- `baseball_swing_miss.wav` ← `swing-miss.wav`
- `baseball_bat_contact_hard.wav` ← `bat-contact-hard.wav`
- `baseball_bat_contact_weak.wav` ← `bat-contact-weak.wav`
- `baseball_bat_foul.wav` ← `bat-foul.wav`
- `baseball_umpire_strike.wav` ← `umpire-strike.wav`
- `baseball_umpire_strikeout.wav` ← `umpire-strikeout.wav`
- `baseball_crowd_cheer.wav` ← `crowd-cheer.wav`
- `baseball_crowd_groan.wav` ← `crowd-groan.wav`

볼은 iOS와 같이 포구음으로 표현한다. 일반 스트라이크 콜과 삼진 풀콜을 중복 재생하지 않는다.

`baseball_pitch_release.wav`는 iOS의 110ms 공기 소리와 낮아지는 짧은 음을 참고한 자체 합성음이다. `tools/generate-android-pitch-release.py`로 재생성한다. 기존 파일에 잘못 들어 있던 스트라이크 음성을 교체했다.

2026-09-07에 추가한 두 음원도 CC0을 그대로 쓴다. 합성음 대신 공개 음원을 우선한다.

- `baseball_perfect_release.wav` ← freesound `highbell.mp3`, kellyconidi, CC0 1.0, https://freesound.org/people/kellyconidi/sounds/218851
  앞에서 0.50초만 잘라 0.40초부터 페이드아웃하고 피크 -6dB로 맞췄다. 포구음(-3dB)보다 낮아 미트를 가리지 않는다.
- `baseball_pitch_flight.wav` ← freesound `Swipe Whoosh`, qubodup, CC0 1.0, https://freesound.org/people/qubodup/sounds/60007
  0.02초부터 0.30초까지 잘라 0.20초부터 페이드아웃하고 피크 -12dB로 맞췄다. 비행 중 깔리는 소리라 가장 낮다.

두 파일 모두 단일 타격음인지 포락선 피크 수로 확인했고, 음성이 섞여 있지 않다.
