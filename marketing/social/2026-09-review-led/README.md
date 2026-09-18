# SNS / Meta 광고 숏폼

2026-09-10. 로컬 제작 완료 파일을 review.html에서 검토한다.

- SocialStory-ko/en/ja: 리뷰 → 평점 → 실제 의견 → 배포된 개선 → 직접 투구 → 환생 → CTA, 30초 세로.
- SocialStory-Feed-ko: 같은 본편을 1080×1350 피드 비율로 재배치.
- SocialProof-ko: 평점 도입 15초.
- SocialPlay-ko: 직접 투구 도입 15초.
- 각 폴더 ad.mp4, cover.png, captions.srt가 업로드용이다. contact-sheet와 safe-zone-review는 검토용.
- 소리는 기존 독자 제작 음악과 CC0 효과음. 나레이션 없이 화면 문구로 전달한다.

한국 App Store 평점 4.5(원자료 4.53297), 별점 평가 182개. ASC API 글 리뷰 전체 조회 48개. 두 수치를 섞지 않는다. 공개 버전 1.2.9, 개선 사례는 1.2.8 프로 시즌 결정·효과 안내. 원문 evidence/asc-reviews.json, 출시 상태와 릴리스 노트 evidence/asc-versions.json 및 asc-release-notes.json, 평점 evidence/apple-kr-lookup.json. claims.json은 광고 주장 범위다.

원문 비판을 칭찬으로 편집하지 않았다. 대표 인용은 프로 콘텐츠에 대한 부정적 리뷰의 일부이며 번역본은 번역 표시. 새로 남은 저장·진행 문제까지 전부 해결했다는 주장은 하지 않는다.

광고의 플레이 화면은 Android 실제 캡처·녹화다. iOS 성과를 Android 성과로 오인하지 않도록 플랫폼과 날짜를 병기했다. 기존 6.7초 투구 녹화는 대기 일부를 잘라낸 편집본이며 조작 속도·결과는 바꾸지 않았다. 광고에서는 그중 최대 6초를 사용한다. UI 관심 부분을 확대했고 기능이나 리뷰는 합성하지 않았다.

SNS 게시·Meta 광고 생성·예산 사용·스토어 배포는 실행하지 않았다. 광고 링크는 실제로 배포된 대상 스토어/랜딩으로 연결한다. 영상의 CTA는 실제 눌리는 앱 UI가 아니라 광고 문구다. 수치는 집행 직전 재조회하고 변경됐으면 copy.ts/claims.json을 함께 갱신한다.

재현:
1. 저장소 루트에서 node tools/asc-social-proof.mjs (읽기 전용, 인증값 출력 없음).
2. apps/promo에서 node scripts/render-social-review.mjs.
3. 루트에서 python3 apps/promo/scripts/finalize-social-review.py.
소스: apps/promo/src/social-review/. 기존 pinned Remotion 4.0.499 유지.
