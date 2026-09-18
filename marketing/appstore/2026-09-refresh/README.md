# App Store 스크린샷·앱 미리보기

최신 로컬 iOS 화면으로 다시 제작한 한국어·영어·일본어 소재다. 사용자 승인 후 **1.2.10(69) 심사 제출을 완료했고 현재 심사 대기 중이다.** 한국어는 새 영상·기존 환생·기존 성장 3편, 영어·일본어는 새 영상·기존 영상 2편으로 등록했다. 최초 소재 ZIP은 승인 당시 제작본이며 최신 제출 상태는 `submission-status.json`에 기록한다.

## 파일

| 언어 | 디렉터리 | App Store 로케일 |
|---|---|---|
| 한국어 | `ko-KR` | `ko` |
| 영어 | `en-US` | `en-US` 및 동일 영어 소재를 쓰는 지역 |
| 일본어 | `ja-JP` | `ja` |

각 언어에 다음이 들어 있다.

- `screenshots-6.9/01.png`–`08.png`: 1320×2868, RGB PNG, 알파 없음.
- `screenshots-6.5/01.png`–`08.png`: 1284×2778, RGB PNG, 알파 없음.
- `preview/app-preview-{ko,en,ja}-886x1920.mp4`: 28초, 30fps, H.264 Main Level 4.0, Rec.709, AAC 스테레오 48kHz.
- `preview/poster.png`: 미리보기 포스터 참고 이미지. ASC에서는 영상 1.5초 프레임을 선택한다.

총 **48장 + 영상 3편 + 포스터 3장**. `review.html`에서 언어·크기를 바꿔 비교할 수 있다. `manifest.json`에는 규격 검사 결과와 SHA-256이 있다. `evidence`에는 전체 스크린샷 및 영상의 장면별 접촉 시트가 있다.

## 마케팅 구성

1. **직접 투구:** '어떤 게임인지'를 첫 화면에서 설명한다. 영상은 실제 수동 투구와 퍼펙트 피드백으로 시작한다.
2. **성장:** 훈련과 각성으로 내 투수가 달라지는 보상을 보여 준다.
3. **선택:** 포수·감독·자신의 판단 사이에서 선수 생활을 선택한다.
4. **프로 계약:** 고교 이후에도 이어지는 커리어를 보여 준다.
5. **기록:** 시즌·통산·성장 수치로 쌓인 시간을 증명한다.
6. **리플레이:** 기억에 남는 공을 다시 보는 새로운 화면을 보여 준다.
7. **계승:** 한 선수의 끝이 다음 투수에게 이어짐을 설명한다.
8. **환생:** 다음 마운드에 대한 기대감으로 마무리한다.

스크린샷은 어두운 초록과 따뜻한 아이보리를 교차해 긴 갤러리의 단조로움을 줄였다. 제목은 작은 카드에서도 읽히게 두 줄로 구성했고, 설명은 한 가지 이점만 말한다. 영상은 무음 재생을 고려한 짧은 자막과 단일 음악 트랙을 사용한다. 한국어 영상 실측은 약 -16.7 LUFS, true peak -1.3 dBFS다.

## 촬영·신뢰성

- iPhone 17 / iOS 26.5 시뮬레이터의 격리 QA 앱에서 최신 제품 화면을 촬영했다. 세 언어 모두 앱을 해당 언어로 실행했다.
- 커리어 수치와 인물은 앱의 엔진 생성 픽스처다. UI를 이미지 편집으로 꾸미거나 숫자를 바꾸지 않았다.
- 첫 투구는 자동 릴리스 OFF인 수동 조작이다. `-uiTestPerfectRelease`를 사용하지 않았다. 퍼펙트 릴리스와 투구 결과는 서로 다른 판정이므로 화면에 함께 보이는 볼 판정도 그대로 남겼다.
- 기록/앨범 화면은 실제로 진행시킨 프로 커리어 자료다. 가짜 후기·별점·가격·타 플랫폼 배지는 넣지 않았다.
- 시뮬레이터 영상의 가변 프레임 시간은 실제 PNG와 픽셀 대조해 편집점을 확정했다. 런처·스플래시를 최종 장면으로 사용하지 않는다.
- 이 소재의 시뮬레이터 촬영은 프로젝트가 요구하는 일본어 **실기기/TestFlight 스모크** 및 대상 App Store 언어 표시 증거를 대신하지 않는다.

## 재렌더

저장소 안에서 유지되는 원본은 `apps/promo/public/asc-2026-09`의 언어별 실제 화면 PNG·편집된 무음 클립과 `score.wav`다. 긴 원본 녹화 및 임시 번들은 중간 산출물이므로 정리하고, 재렌더에 필요한 편집된 클립은 보존했다.

```sh
cd apps/promo
node scripts/render-asc-refresh.mjs
python3 scripts/finalize-asc-refresh.py
# Pillow가 포함된 Python으로 실행
python3 scripts/verify-asc-refresh.py
```

설치된 Remotion **4.0.499**를 사용한다. 새 패키지 업데이트는 필요하지 않다. `ASC_LOCALES=ko`와 `--stills`/`--videos`로 일부만 다시 만들 수 있다. React 소스는 `apps/promo/src/asc-2026-09`에 있다.

새 화면을 다시 촬영하려면 `Release128JourneyUITests/testAppStoreRefreshKO`, `EN`, `JA`를 `BASEBALL_CAPTURE_MODE=1`과 격리 QA 번들로 실행한다. 이 촬영 테스트는 기본 실행에서는 건너뛴다. 시뮬레이터 전면 창을 열고 녹화한 뒤 `match-asc-refresh.py`로 실제 픽셀을 대조하고 `prepare-asc-refresh.py`로 클립을 확정한다.

Apple 기준: [스크린샷 규격](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications), [앱 미리보기 규격](https://developer.apple.com/help/app-store-connect/reference/app-information/app-preview-specifications), [앱 미리보기 구성](https://developer.apple.com/app-store/app-previews/).
