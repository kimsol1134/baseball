# Google Play marketing pack · 2026-09-10

한국어(ko-KR), English(en-US), 日本語(ja-JP).

- `review.html`: 스크린샷·영상·설명 통합 검토 페이지.
- `play-store-{locale}.zip`: 언어별 업로드 파일. 내부 QA 로그·세이브·원본 녹화 제외.
- `{locale}/screenshots/01.png`–`08.png`: 1080×1920 RGB PNG. 직접 투구 → 훈련 → 환생·유산 → 대화·선택 → 드래프트 → 계약 → 프로 시즌 → 선수 앨범.
- `{locale}/feature-graphic.png`: 1024×500 RGB PNG.
- `{locale}/youtube-thumbnail.png`: 1280×720 RGB PNG.
- `{locale}/trailer-portrait.mp4`: 1080×1920 / 30초 / 30fps.
- `{locale}/trailer-landscape.mp4`: 1920×1080 / 30초 / 30fps.
- 영상: H.264, yuv420p, AAC 48kHz, 음량 정규화. 나레이션 없이 현지화 화면·카피·음악으로 구성.
- `listing-copy.json`, `STORE_COPY*.md`, `{locale}/store-listing.txt`: 앱 이름, 간단한 설명, 자세한 설명, 영상 제목.
- `upload-manifest.json`: 파일 규격·크기·SHA-256.
- `RESEARCH.md`: 경쟁작 관찰과 공식 규격 출처.

## 콘솔 반영
이번 작업은 로컬 제작이다. Play Console 저장·업로드·심사 제출·프로덕션 출시, YouTube 업로드는 실행하지 않았다.
기존 콘솔 기본 언어는 한국어였다. 영어·일본어는 해당 언어의 스토어 등록정보를 추가해 각 언어 파일을 넣는다.
스크린샷은 01부터 08 순서로 넣고 그래픽 이미지는 feature-graphic.png를 사용한다.
Play 미리보기 영상 필드에는 MP4 대신 YouTube URL을 넣는다. 가로판 또는 세로판을 광고 없는 공개/일부 공개, 삽입 가능, 연령 제한 없는 영상으로 업로드하고 URL을 연결한다. 썸네일은 같은 언어의 youtube-thumbnail.png를 쓴다.

## 제작 근거
최신 Android Compose UI를 격리된 reset QA 패키지에서 각 언어로 캡처했다. 원래 사용자 QA 패키지의 커리어로 촬영하지 않았다. 영상은 실제 직접 투구이며 성공 결과를 조작하지 않았다. 녹화의 대기 구간 일부만 편집하고 속도는 바꾸지 않았다. 선수가 직접 정하는 한국어 이름은 그대로 보일 수 있다.
정적 화면은 실제 커널 상태와 앱 뷰를 사용하는 촬영 테스트다. 마케팅 문구만 별도 배치했으며 앱 내 기능·수치·성과는 합성하지 않았다. 경쟁작의 그림·로고·선수·음악은 사용하지 않았다.
Remotion 4.0.499 유지. 소스: `apps/promo/src/play-2026-09/`. 재현: `apps/promo/scripts/render-play-store.mjs`, `finalize-play-store.py`. 음악과 폰트 출처: `apps/promo/public/play-2026-09/CREDITS.md`.

## 출시 검증과 구분
마케팅 파일의 완성은 바이너리 출시 검증 완료를 의미하지 않는다. 실기기·OS 복원·서명된 RC 검증은 이전 QA의 별도 미완료 항목으로 유지한다.
