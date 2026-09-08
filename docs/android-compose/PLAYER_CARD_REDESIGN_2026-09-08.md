# 공유 카드 디자인과 상세 투구 성적

## 참고한 실제 사례

- [Spotify Wrapped 공식 소개](https://newsroom.spotify.com/2025-12-03/2025-wrapped-user-experience/): 공식 공유 카드 이미지를 브라우저에서 확인했다. 큰 인물 사진, 제한된 색상, 명확한 글자 크기 차이, 정렬된 상세 정보 배치를 참고했다. 로고·장식·사진을 복제하지 않았다.
- [Strava 공식 활동 공유 안내](https://support.strava.com/en-us/articles/15401840-sharing-your-strava-activities): 사진과 실제 활동 통계를 결합하는 공유 방식 참고.
- [Strava Year in Sport 2021 제작사 사례](https://manual.studio/work/strava-year-in-sport-2021): 제작사가 설명한 기록의 시각화 원칙 참고. 현재 제품 화면으로 간주하지 않았다. 별도 Strava 커뮤니티 글은 접근 제한이 있어 근거로 사용하지 않았다.

## 반영

공유 카드의 형광색·큰 빈 공간·중첩된 둥근 박스를 없앴다. 큰 선수 사진과 이름을 위에 배치하고, 네이비·종이색·파랑의 세 색으로 기록표를 만들었다. WHIP / IP / SO를 크게 보여주며, 아래에 기본 기록 12개와 비율 기록을 정렬한다. 모든 카드는 동일한 렌더러로 미리보기·이미지 저장·공유된다.

기본 기록: G, GS, W, L, SV, IP, H, HR, BB, SO, R, NP.
비율 기록: WHIP, K/9, BB/9, H/9, K/BB, RA/9.

앨범뿐 아니라 경기 기록의 시즌별·프로 통산 선택에도 상세 성적을 제공한다. 별도 자책점 데이터가 없으므로 ERA를 만들어내지 않는다. RA/9는 실점 기준이며, 앱의 기록 용어에서 ERA와의 차이를 설명한다. 과거 상세 기록이 없으면 해당 칸에 —를 표시한다.

## 계산과 보존

[WHIP 공식 정의](https://www.mlb.com/glossary/standard-stats/walks-and-hits-per-inning-pitched), [K/9](https://www.mlb.com/glossary/advanced-stats/strikeouts-per-nine-innings), [BB/9](https://www.mlb.com/glossary/advanced-stats/walks-per-nine-innings)를 확인했다. 계산 분모는 항상 아웃 수/3이다. 예를 들어 표시 2.1이닝은 아웃 7개이며 소수 2.1로 계산하지 않는다. 소수점 두 자리 반올림, 분모 0 또는 누락 데이터는 —로 처리한다.

앨범의 상세 누적 카운터는 optional 배열로 추가하여 구버전 저장 형태와 commitment를 유지한다. 프로의 이전 시즌에 개별 경기 행이 없어도 보존된 시즌 합계로 WHIP 등은 복원한다. 가상의 개별 경기 행을 추가하지 않는다.

## 검증

계산·분수 이닝·0분모·누락 데이터·프로 과거 시즌 복원·저장·백업 관련 타깃 12개 통과. APK 빌드와 lintDebug 통과. 실기기 검증 결과는 최종 확인 후 추가한다.

출력 예시 `artifacts/android-compose/card-redesign-season.png`는 가상 테스트 선수의 예시 성적이다. 실제 사용자의 성적을 바꾸지 않았다.

최종 Galaxy A53 검증: 카드 미리보기·재생, 글씨 2배, 영어/일본어, 상세 성적 이미지 출력 4개 테스트 통과. 최신 앱 설치 및 실행 완료. 사용자 shadow/native 저장 파일 두 개의 설치 전후 SHA-256 동일. 예시 출력의 이름·사진·기록 표가 잘리지 않는 것을 시각적으로 확인했다.

증거: `card-redesign-final.log`, `card-redesign-device-final.log`, `card-redesign-save-before.sha256`, `card-redesign-save-after.sha256`, `card-redesign-launched.txt` (모두 `artifacts/android-compose/`).
