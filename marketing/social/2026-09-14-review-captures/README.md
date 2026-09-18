# 실제 App Store 리뷰 캡처 홍보 · 2026-09-14

- review-feed.png: 1080×1350, Threads/Instagram 등 피드용.
- review-story.png: 1080×1920, 스토리용 세로 이미지.
- post.txt: 기존 게시물의 존댓말에 맞춘 게시 문안.
- sources/review-original.png: 실제 공개 App Store 화면에서 리뷰 제목·별점·날짜·닉네임·본문 전체가 포함된 부분을 자른 캡처. 개발자 답변은 제외.
- sources/reviews-visible.jpg: 원문이 보이는 전체 뷰포트 증거.
- build.py, render.cjs, SVG: 재사용 가능한 레이아웃 소스.

출처: https://apps.apple.com/kr/app/6794754217?see-all=reviews&platform=iphone
앱 ID: 6794754217. 리뷰 공개 DOM ID: review-14493369081-title.
리뷰: skdneksls / 2026-08-31 / 별점 5개 / 제목 ‘주인공 어느손 투수인가요?’.
2026-09-14 공개 페이지에서 확인·캡처했다. 내부 ASC 저장 자료의 같은 리뷰와도 대조했다.

리뷰 원문:
재밌게하고있습니다 업데이트도 계속 해주셔서 더 맘놓고 재밌게 즐기는중입니다. 그런데 주인공 어느 손 투수인가요? 게임내에 설명이 없어서요.. 우완좌완 설정도 할수 있었으면 좋겠네용

강조 문구는 연속된 원문 일부다. 이미지에 원문 전체를 함께 실어 손잡이 설정 요청 맥락을 보존했다. 별점·문구·닉네임은 합성하지 않았다. 이 리뷰는 iOS 이용자의 리뷰이며 Google Play 리뷰로 표시하지 않았다. 전체 평점·평가 수·순위는 홍보 이미지에 사용하지 않았다.
Android 화면: apps/promo/public/play-2026-09/captures/ko/pitch.png. 실제 캡처를 원본 비율로 배치.
폰트: 기존 Gmarket Sans Bold. 라이선스: apps/promo/public/play-2026-09/fonts/THIRD_PARTY_FONT_LICENSES.md.
게시·업로드는 수행하지 않았다.

## 성장 재미를 강조한 수정본

growth-review-feed.png / growth-review-story.png / growth-post.txt 사용.
별점 5개 ‘재밌다’, 겜동진132 리뷰로 교체. 2026-09-14 ASC API에서 최신 원문 대조.
리뷰 시각 2026-08-31T20:50:24-07:00는 한국 시각 2026-09-01이다.
선택한 리뷰는 공개 웹의 추천 리뷰 목록에 노출되지 않아, 이 수정본은 캡처를 가장하지 않는 ‘실제 리뷰 본문 일부 인용’ 카드로 제작했다. 원문은 selected-review.json에 보존.
‘회차가 쌓일수록, 내 투수는 더 강하게’는 홍보 카피이며 리뷰 직접 인용과 별도 구역으로 표시.
