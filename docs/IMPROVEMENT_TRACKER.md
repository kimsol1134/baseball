# 개선 트래커 — 패널 리뷰 52건 실행 현황

기준 문서: docs/CRITICAL_REVIEW_PANEL_2026-08-01.md · 목표: 앱스토어 유료 1위 확신까지 반복

## ✅ 완료 (빌드 27, 커밋 cb313a3)

W1 신뢰: 정직한 정산(appliedInheritance 공개+정산 표기) · 투구 세션 타석 체크포인트/복구 · 등판 중단 버튼+확인 · 정산 공유 버튼 · 별점 조기화(첫 무실점) · 조사 버그(커널 particle)
W2 경제: 영혼 상점 4종(재능 돌파 240/기억 확장 160/조기 성장 120/성장 리듬 90) · noLastChance 실구현(부상=시즌 종료) · stubbornCoach 획득 절반 · 회복 훈련 무료 성장 제거 · 전조 하한 2갈래 · 사인 고정 토글 · 팬 관심 노출
UX: 슬로모 스크롤 템포 연동 · K 현수막 콜 이후 · reduceMotion 읽기 시간 · VoiceOver 주자/누적 · 기억 확정 확인
(이전 빌드 21~26: 초상 통일·성장 3단계·기억 카드 아트·도파민 레이어·전조/바람/약속/숙적/정산 — 완료)

## ⏳ W3 야구 깊이 (다음)
- [ ] 구속차·터널링 판정(직전 투구 대비; 기본 경로 0이라 골든 픽스처 안전)
- [ ] velocityEdge 구종별 기준속도 상대화
- [ ] 스태미나→피로 곡선 편입 + fatigueCost 하한 1 (tuned() 감소 폭 조정)
- [ ] 히터스 카운트(2-0/3-1 .hunt) + 2S 파울 커트 (골든 재보정 필요 — check-balance.mjs)
- [ ] RivalMemory: landedZone 학습 + outcome 가중
- [ ] 기록: 사구 분리 집계(WHIP 제외·FIP 전달) · 홀드 · 완투/완봉/무4사구 마일스톤 · 승계주자 분리
- [ ] 구종 role 승격(development→secondary→primary) + 승격 연출
- [ ] AutoOutingSimulator 타자 강점/약점 다양화 + 리그 상수 재측정

## ⏳ W4 리텐션·라이브옵스 (다음)
- [ ] 오늘의 이닝: daily-YYYYMMDD 시드 1이닝 + Game Center 리더보드 + 로컬 알림 2종
- [ ] 시드 입력 UI + 회차 카드에 시드 각인 + universal link
- [ ] CareerWind 12종(규칙 변경자: 혹서기·투고타저 등) + calm weight 정리
- [ ] RunPledge 확장 + 실패 스테이크 + 각성 풀 편향 연결
- [ ] 내러티브: 대사에 선수 이름 호명 · 인물(감독/포수) LifeRecord 기록 · 핵심 3인 대사 풀 확장 · 세계 뉴스-숙적 연결
- [ ] 업적 진행률(percentComplete 실값) + GKGameCenterViewController 진입점
- [ ] 프로 주간 결정 훅(3주 1결정)
- [ ] DraftReveal 공유 + 신기록 정지 프레임 카드

## ⏳ 경제·밸런스 잔여
- [ ] 재능 만개 경제(등급 무관 임계) + 드래프트 뾰족함 가중(max*0.5+rest*0.15)
- [ ] 훈련 기회 희소화(3~4턴 1회) + outlook 숫자 숨김
- [ ] 첫 각성 스케줄 게이트 재설계(전조→갈래 질)
- [ ] 학교 8~10종 + 학교별 규칙 1개
- [ ] 야구혼 잔액-스며듦 분리 회계(spend 후 잔액 유지 vs 소멸 — 현재: 구매분만 차감)

## ⏳ UX 잔여
- [ ] 다이나믹 타입(OptionRow AX 세로 전환·@ScaledMetric) 
- [ ] 대시보드 주 행동 버튼 safeAreaInset 고정 + 훈련 선택 유지(store)
- [ ] 성장/정산 연출 자동 스크롤 보장
- [ ] "이 회차를 접고 다시 시작" 확인 다이얼로그
- [ ] 원버튼 환생(같은 설정 재시작)
- [ ] 프로 경기 PitchView 중단·복구(고교와 동일 처리)

## 반복 루프
각 웨이브 완료 시 6관점 서브에이전트 재검토(Workflow critical-review-panel 재사용) → 새 발견 반영 → "유료 1위 확신" 판정.
