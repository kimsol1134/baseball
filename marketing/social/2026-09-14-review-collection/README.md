# 리뷰 모음 · 2026-09-14

reviews-feed.png: 1080×1350 PNG. 게임 화면 없이 실제 리뷰 3개의 제목·본문 전체와 작성자, 별점, 한국 날짜를 재배치.
post.txt: 함께 게시할 쓰레드 문안.
reviews.json: 원문과 리뷰 ID, 원문 시각. 출처는 ../2026-09-14-review-captures/sources/reviews-current.json (2026-09-14 ASC 읽기 전용 조회).
공개 앱: https://apps.apple.com/kr/app/id6794754217
실제 스토어 UI 캡처가 아닌 리뷰 원문 재배치 이미지임을 이미지 하단에 표시. 선택 리뷰의 개선 요청과 질문도 보존. 오탈자는 원문 유지. 날짜는 Asia/Seoul로 변환.
별점은 각 리뷰의 별점이며 앱 전체 평점이 아님. 리뷰는 iOS 이용자이며 Google Play 리뷰로 표시하지 않음.
build.py 및 SVG는 재사용 원본. 폰트: 기존 Gmarket Sans Bold, 라이선스 apps/promo/public/play-2026-09/fonts/THIRD_PARTY_FONT_LICENSES.md.
Creative Production 보드 도구는 현재 직접 호출 가능한 도구 목록에 없어 로컬 산출물로 전달. exact-content 및 deterministic-exports 지침 적용.
게시·업로드 미수행.

## 실제 원본 캡처 완성본
사용 파일: reviews-original-captures.png (1080×1350).
Arc의 로그인된 App Store Connect 평가 및 리뷰 화면에서 원본 3개를 직접 캡처했다.
출처: https://appstoreconnect.apple.com/apps/6794754217/distribution/ratings/ios
originals/growth.png, batter.png, fan.png는 전체 화면 증거이며 업로드용이 아니다.
각 -crop.png는 별점·제목·날짜·닉네임·본문 영역만 자른 원본. 문구 재입력·별점 합성·본문 삭제 없음. 관리자 UI와 개발자 답변은 제외했다.
compose-originals.py와 SVG는 배치 재현 소스. PNG 완성본은 캡처의 비율만 유지해 확대 배치했다.
