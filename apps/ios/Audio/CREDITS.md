# 음원 출처와 라이선스

이 폴더의 오디오는 **모두** 아래에 출처와 라이선스가 적혀 있어야 한다. 적히지 않은 파일은
쓰지 않는다 — 유료 앱에서 출처 불명 음원은 그 자체가 위험이다.

파일 이름은 `SoundBank.swift`의 `SoundAsset`와 정확히 같아야 하며, 없는 이름은 무시된다.
지원 확장자: wav · m4a · caf · aiff · mp3.

| 파일 | 쓰이는 곳 | 출처 | 라이선스 | 저작자 표기 필요 |
|---|---|---|---|---|
| `crowd-loop.m4a` | 경기 중 관중 웅성거림(이어 재생) | [Wikimedia Commons](https://commons.wikimedia.org/wiki/File:360703_eguobyte_large-crowd-medium-distance-stereo.wav) · eguobyte, "large crowd medium distance stereo" | **CC0** (공용 저작물 기증) | 불필요 |
| `crowd-cheer.wav` | 삼진·호투 뒤 함성 | [Freesound 634512](https://freesound.org/people/cpark12/sounds/634512/) · cpark12, 고교 야구 실경기 녹음에서 타격 직후 관중 반응을 잘라 냄 | **CC0** | 불필요 |
| `crowd-groan.wav` | 피안타·홈런 뒤 탄식 | [Freesound 324897](https://freesound.org/people/deleted_user_2104797/sounds/324897/) · "Crowd Ouch" — 관중이 "오우…" 하는 반응 네 테이크 중 두 번째를 잘라 냄 | **CC0** | 불필요 |
| `glove-catch.wav` | 포수 미트 포구 | [Freesound 649084](https://freesound.org/people/MPooman/sounds/649084/) · MPooman, "Baseball Glove Sounds (High Quality)"에서 첫 포구를 잘라 냄 | **CC0** | 불필요 |
| `bat-contact-hard.wav` | 정타 | [Freesound 628352](https://freesound.org/people/Urkki69/sounds/628352/) · Urkki69, "Hitting a Finnish baseball" — 야외에서 방망이로 공을 실제로 친 단독 녹음 | **CC0** | 불필요 |
| `bat-contact-weak.wav` | 빗맞은 타구 | 위 `bat-contact-hard`와 **같은 녹음에서 파생** (가공 내역 아래) | **CC0** | 불필요 |
| `bat-foul.wav` | 파울 팁 | 정타(`bat-contact-hard`)와 같은 녹음에서 파생 — 고역 통과 1.5kHz×2 + 90ms 절단. 빗맞아 스치면 "딱" 대신 "틱"이 되는 물리를 흉내 낸다 | **CC0** | 불필요 |
| `swing-miss.wav` | 헛스윙 | [Freesound 59995](https://freesound.org/people/qubodup/sounds/59995/) · qubodup, "stick cutting air" — 막대가 실제로 공기를 가르는 녹음 | **CC0** | 불필요 |
| `pitch-release` | 릴리스 | — | — | — |
| `umpire-strike.wav` | 스트라이크 콜 | [Freesound 625473](https://freesound.org/people/jcookvoice/sounds/625473/) · jcookvoice — "Strike three, you're out"에서 첫 단어("Strike!")만 잘라 냄. **음성 인식(whisper)으로 내용을 검증했다** — 봉투 모양만 보고 자르면 "Strike three"를 매 스트라이크마다 외치게 된다(실제로 한 번 그랬다) | **CC0** | 불필요 |
| `umpire-ball` | 볼 콜 | **의도적 무음.** 실제 심판은 볼을 외치지 않고, 미트 소리가 이미 공 하나를 표시한다. 슬롯은 남겨 둔다 | — | — |

성장·기념·UI 음은 화면 피드백이라 녹음을 쓰지 않고 합성음을 유지한다(`SoundAsset.asset(for:)`).

## 실녹음 가공 내역

처음 세트(martinimeniscus의 "Bat Hit"/"Glove Catch")는 실기기에서 "소리가 다 이상하다"는
피드백을 받았다. 확인하니 그 "Bat Hit"의 설명은 *Bat slam* — 방망이로 무언가를 친 소리지
공이 맞는 소리가 아니었다. **제목이 아니라 내용을 검증해야 한다.** 지금 세트는 실제로 공을
친 녹음(핀란드 야구 타격), 포구 전용 고품질 녹음, 실경기 관중 반응으로 갈아 끼웠고,
트랜지언트(피크 순간)를 찾아 그 앞 10ms부터 잘랐다.

빗맞은 타구는 정타와 같은 녹음에서 파생했다(저역 통과 1.4kHz — 배트 끝에 맞으면 그렇게
들린다). 빗맞은 타구만 따로 녹음한 CC0가 없어서, 없는 녹음을 있는 척하지 않고 여기 적는다.

내려받은 것은 Freesound의 미리듣기 MP3다. 원본은 로그인이 필요한데, **한 방 소리에서는
손실 압축이 문제가 되지 않는다** — 인코더가 붙이는 앞뒤 여분 샘플은 어택 앞의 무음을
어차피 잘라 내기 때문이다. 반복 루프(crowd-loop, menu-theme)만 무손실이 필요하다.

## 다음에 채울 칸 (외부 에셋 대기)

| 우선 | 파일 | 무엇을 구해야 하나 |
|---|---|---|
| 1 | `pitch-release` | 공이 날아가는 바람 소리. 합성이 오히려 자연스러울 수 있어 우선순위 낮음 |
| 4 | `menu-theme` | 메뉴 음악 루프. 없으면 합성 패드가 돈다. 무손실이어야 한다(이음매) |

**수용 규격**

- 라이선스: **CC0만.** CC-BY는 앱 안에 표기 자리를 만들어야 해서 이번 범위 밖이다.
  찾는 방법: Openverse API가 Freesound의 CC0 음원을 로그인 없이 검색·내려받게 해 준다
  (`https://api.openverse.org/v1/audio/?q=...&license=cc0`). 받은 뒤 Freesound 원본
  페이지에서 라이선스를 한 번 더 확인한다.
- 길이: 0.3~0.9초. 앞뒤 무음이 붙어 있으면 잘라 낸다 — 판정과 소리 사이의 지연이 손맛을 깎는다.
- 채널: 모노 권장. 앱이 `GameAudio`에서 등파워 패닝을 직접 건다.
- 샘플레이트: 44.1kHz 또는 48kHz. 형식은 무손실(wav/aiff/caf 또는 ALAC .m4a).
  손실 압축은 앞뒤에 인코더 여분 샘플이 붙어 타격음의 어택이 무뎌진다.
- 음량: **피크 기준** −1.5dB(가장 센 소리) ~ −13dB(가장 여린 소리). 한 방 소리에
  LUFS를 쓰면 안 된다 — 게이팅 창이 400ms라 0.5초짜리는 측정이 성립하지 않는다.
- 내용: 관중 소리·해설·구장 반향이 섞이지 않은 **단독 타격음**이어야 한다. 앱이 관중을
  따로 깔기 때문에 겹치면 두 겹이 된다.

파일을 이 폴더에 넣고 위 표에 출처를 적으면 코드 변경 없이 자동으로 교체된다
(`SoundBank`가 파일 유무로 갈린다). 넣기 전과 후를 같은 등판에서 들어 보고, 합성음보다
나쁘면 넣지 않는다 — 두 벌 구조의 목적이 그것이다.

## 저작자 표기가 필요한 라이선스(CC-BY 등)를 쓸 때

앱 안에 표기할 자리를 반드시 만든다. 표기 없이 CC-BY 음원을 넣으면 라이선스 위반이다.

## crowd-loop.m4a 가공 내역

원본은 58초짜리 대형 관중 녹음인데 처음부터 끝까지 계속 커진다(RMS -15dB → +13dB). 그대로
잘라 반복하면 매 바퀴 부풀었다 뚝 떨어져서 오히려 합성음보다 거슬린다. 그래서:

1. 2~20초 구간을 뽑고 `dynaudnorm`(긴 창)으로 커지는 경향만 눌렀다. 순간적인 웅성거림은 남겼다.
2. 45Hz 아래와 12kHz 위를 잘랐다. 멀리 있는 관중에는 그 대역이 없고, 있으면 잡음으로 들린다.
3. 꼬리 2초를 머리 2초 위에 크로스페이드해 **14초 이음매 없는 루프**로 만들었다. 반복 지점이
   원본에서 이어진 구간이 되어 틈이 들리지 않는다.
4. -22 LUFS로 맞췄다. 관중은 배경이라 앞에 나오면 안 된다. 앱에서 다시 `밀도 × 0.35`를 곱한다.

결과: 초당 RMS 평균 -24dB, 최대편차 1.9dB, 시작과 끝 차이 0.5dB.

**손실 압축(AAC)을 쓰지 않은 이유**: AAC는 파일 앞뒤에 인코더가 만든 여분 샘플이 붙는다.
한 번 재생하면 들리지 않지만 이어 붙여 반복하면 그 자리에서 틈이 생긴다. 224KB로 줄일 수
있었지만 1.3MB짜리 무손실(ALAC)을 택했다.
