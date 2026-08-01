# 비판적 검토 보고서 — 6개 관점 패널 리뷰

> 2026-08-01 · 각 관점을 독립 서브에이전트(Opus 5, medium)가 맡아 실제 코드를 읽고 작성했다.
> 근거는 전부 파일:라인 단위로 검증된 것이다. 이미 알려진 비판(카드 읽기 비중·온보딩 길이·언락 부재·
> 각성 시너지 부재·실패 서사 부재·재시작 마찰)은 중복 지적하지 않도록 지시했다.

## 종합 — 여섯 관점이 교차 지목한 것

여섯 에이전트는 서로의 결과를 보지 못했다. 그런데도 같은 지점을 반복해서 때렸다 — 독립 수렴한 문제가 이 게임의 진짜 구조 결함이다.

### 교차 주제 (독립적으로 2회 이상 지목)

1. **보상이 수학적으로 거짓말을 한다** (수익화 PM · 이코노미 · 로그라이크 — 3중 수렴, 최우선)
   정산 화면은 "야구혼 +37"을 64pt로 카운트업하지만 커널 상한(`min(20, 8+누적/60)`)이 실제로는 +0.6점만 반영한다. 약속 +15%·카르마 배율·프로 계승 보너스 전부가 같은 배수구로 흘러가 EV가 0에 수렴한다. 소비처는 코드 전체에 한 곳도 없다. **이번 세션에 만든 정산 폭발·약속·잭팟이 전부 이 거짓 영수증 위에 서 있다** — 유저가 계산하는 순간(그리고 커뮤니티는 반드시 계산한다) 신뢰가 무너진다.

2. **투구 세션이 저장되지 않는다** (수익화 PM · UX — 2중 수렴)
   게임의 유일한 실제 플레이 구간이 메모리에만 있고, 시드는 시작 시 이미 넘어가 있다. 전화 한 통에 15분이 증발하고 화면엔 경고조차 없다. 유료 게임의 환불 사유.

3. **죽은 시스템이 너무 많다** (이코노미 · 야구 · 로그라이크)
   fanInterest는 표시도 판정도 없는 100% 데드 리소스, stamina는 커널이 검증만 하고 읽지 않으며, RivalMemory가 저장하는 outcome은 분석에서 쓰이지 않고, 완비된 시드 인프라는 화면에 노출되지 않는다. "만들다 만 축"이 유저에게는 얕음으로 읽힌다.

4. **최적해가 하나로 수렴한다** (이코노미 · 로그라이크)
   훈련은 화면이 정답을 읽어 주고(강한 회복 = 무료 성장), 카르마는 noLastChance+erasedMemory 지배 조합(심지어 noLastChance의 페널티는 미구현), 재능은 "낮은 등급 몰빵"이 수학적 최적. 로그라이트의 심장인 "매번 다른 고민"이 산수로 죽어 있다.

5. **애착의 1차 재료가 없다** (내러티브)
   세계 전체가 내 선수의 이름을 단 한 번도 부르지 않는다. 감독·포수는 게임 전체에 4명뿐이고 환생하면 이름조차 기록에 안 남는다. 핵심 3인의 대사는 8회차면 100% 재탕. "내 자식 같은 애착"의 목표와 가장 먼 곳.

6. **좋은 연출이 화면 밖에서 재생된다** (UX)
   성장 잭팟·이닝 정산은 스크롤 위치상 보이지 않는 곳에서 뜨고, 승부구 슬로모는 자동 스크롤이 도중에 끊으며, K 현수막은 심판 콜보다 먼저 떠서 스포일러가 된다. 이번에 만든 도파민 레이어의 상당 부분이 실제로는 전달되지 않고 있다.

### 우선순위 로드맵 제안

| 웨이브 | 내용 | 성격 |
|---|---|---|
| **W1 — 신뢰 회복 (즉시)** | 야구혼 정산 정직화(실반영·상한 표시 or 경제 개편 선행), 투구 세션 타석 단위 저장·복구, 정산·드래프트 화면에 공유 버튼, 별점 요청 조기화(첫 무실점 이닝), 조사 처리 버그("감독은(는)") | 거짓·손실 제거 |
| **W2 — 경제 재설계** | 야구혼 소비처(회차 시작 '규칙 구매'), 카르마 6종 재설계(+noLastChance 실구현), 훈련 회복/강도 트레이드오프 복원, 재능·드래프트 공식(뾰족함 보상), 전조 재조정(갈래 수→갈래 질) | 최적해 다양화 |
| **W3 — 야구 깊이** | 구속차·터널링 판정 도입, 스태미나를 피로 곡선에 편입, 히터스 카운트·2S 커트, 기록 구멍(사구 분리·승계주자·홀드·완봉), 구종 role 승격(결정구 완성 서사) | 야구 팬 신뢰 |
| **W4 — 리텐션·라이브옵스** | '오늘의 이닝'(일일 시드 + Game Center 순위), 시드 입력·카드 각인, 바람 12종+약속 확장(업데이트 소재화), 인물 풀 확장 + 이름 호명 + 환생 시 인연 기록 | 다시 켤 이유 |

한 줄 결론: **지금까지는 루프를 빛나게 했고, 이 보고서의 숙제는 루프가 정직하고 깊어지게 하는 것이다.** W1은 도파민이 아니라 신뢰의 문제라 가장 먼저다.

총 **52건** — P0 15 · P1 27 · P2 10

## 목차
1. 수익화·라이브옵스 PM (유료 프리미엄 전제)
2. 로그라이트 이코노미 디자이너
3. 캐릭터 애착 담당 내러티브 디자이너
4. 모바일 게임 UX 리뷰어 (정보 위계·인지 부하·피드백 타이밍·접근성·한 손 조작)
5. 20년차 야구 게임 하드코어 유저 · 야구 기록 문화 전문가
6. 로그라이크 장르 평론가 (Slay the Spire·Hades·Vampire Survivors 분석 관점)

---

## 1. 수익화·라이브옵스 PM (유료 프리미엄 전제)

**총평** — 공유 자산(회차 카드 이미지)·업적·리더보드·시드 노출까지 "바이럴 부품"은 이미 코드에 박아 놓았는데, 부품끼리 회로가 연결돼 있지 않다 — 시드는 공유되지만 입력할 곳이 없고, 카드는 감정 최고점이 아니라 아카이브 탭에만 붙어 있으며, 앱 전체에 날짜/시간 기반 로직이 단 한 줄도 없어 "내일 다시 켤 이유"가 구조적으로 부재한다. 더 심각한 것은 리텐션의 심장인 야구혼 보상이 수학적으로 거짓 보상이라는 점이다: RunRecapView가 +37을 큰 글씨로 카운트업하는 동안 커널은 캡 8점만 실제로 적용한다. 유료 1위는 "첫날 재미"로 오르지만 순위 유지는 리뷰 유입 속도로 결정되는데, 지금 별점 요청은 1~2시간 플레이 + 지명 성공이라는 이중 관문 뒤에만 열린다.

### [P0] 회차 정산의 '야구혼 +37' 폭발이 실제로는 +8 — 게임 전체의 재접속 보상이 수학적 거짓말

- **근거**: HighSchoolCareerStore.swift:551 nextInheritance가 base=max(4, ratings/8 + record/4)로 회차당 대략 30~40점을 적립하고 RunRecapView.swift:126 run()이 그 값을 64pt 굵기로 카운트업한다. 그런데 HighSchoolCareer.swift:2264 inheritancePointCap(for:) = min(20, 8 + points/60), 2273행 `remaining = min(points, cap(points))`. 누적 37점이면 캡은 8+0=8 → 실제 능력에 스며드는 건 8점뿐이고 29점은 버려진다. 캡 20에 닿으려면 누적 720점, 대략 20회차가 필요하다. RunPledge.bonusPermille=150(약속 이행 +15%, 약 +5점)도 전량 캡에 잘려 초반 회차에서는 능력 차이가 정확히 0이다.
- **개선안**: 둘 중 하나. (A) 야구혼을 '적립형 스탯'이 아니라 '소비형 통화'로 바꿔 회차 시작 화면에서 지출하게 한다(재능 벽 1칸 뚫기 = 200, 기억 슬롯 +1 = 400, 시작 구속 +3 = 120). 캡은 지출 UI가 대신하므로 삭제. (B) 최소한 RunRecapView가 `+\(rewarded)`가 아니라 `applyInheritance가 실제로 쓸 점수`와 `다음 캡까지 남은 점수(예: 다음 +1까지 23점)`를 함께 찍게 한다. 지금은 게임이 유저에게 매 회차 거짓 영수증을 발행하고 있고, 이건 20회차짜리 게임에서 리뷰 이탈 사유다.

### [P0] 앱 전체에 날짜/시간 기반 로직이 0줄 — '오늘 다시 켤 이유'가 코드에 존재하지 않음

- **근거**: apps/ios/Sources + packages/simulation-core/Sources 전체에서 `Date()`/`Calendar.`/`dailySeed`/`streak`/`lastPlayed` grep 결과 게임 코드 히트 0건(유일한 히트는 SaveArchiveCLI/main.swift:16, CLI 도구). UNUserNotificationCenter 사용 0건. 즉 로컬 알림도, 일일 시드도, 접속 연속일도, '지난 회차 이후 며칠' 인지도 전부 없다. 재접속 신호로 계측하는 것조차 GameAnalytics.Event.rebirthStarted 하나뿐이다.
- **개선안**: 코어가 완전 결정론(careerID → 모든 것)이라는 자산을 그대로 쓴다. `careerID = "daily-\(yyyyMMdd)"`로 만든 **오늘의 한 이닝**을 추가: 전 유저가 같은 타순·같은 바람으로 1이닝만 던지고, GKLeaderboard(이미 Leaderboard 열거형·submit 경로 존재)에 그날 성적을 올린다. 본편 진행에 영향 없음 → 밸런스 리스크 0. 하루 3분, 회차 진행 중인 사람도 켤 이유가 생기고, 회차를 끝낸 사람의 공백기를 메운다. 알림은 '오늘의 이닝'과 '어제 순위' 두 종만.

### [P0] 게임의 유일한 실제 플레이(중요 경기)가 중단 복구 불가 — 전화 한 통에 회차의 하이라이트가 증발

- **근거**: HighSchoolCareerStore.swift:340 beginImportantGame()이 `MobileCareerStore.advanced(result.nextSeed)`로 시드를 먼저 굴려 save()한 뒤 PitchSession을 연다(리트라이 스커밍 차단 목적). 그런데 SaveRecord(HighSchoolCareerStore.swift:690~)에 pitchSession 필드가 없다 — PitchSession은 저장되지 않는다. 결과: 이닝 도중 앱이 죽거나 유저가 나가면 그 이닝의 투구는 전부 사라지고, 시드는 이미 넘어가 다른 이닝으로 다시 시작한다. MobileCareerStore.swift:158에 프로도 같은 구조.
- **개선안**: PitchSession을 Codable로 만들어 **타석 경계마다** SaveRecord에 스냅샷한다(공 하나 단위가 아니라 타석 단위면 스커밍도 안 열리고 상태량도 작다). 저장된 세션이 있으면 대시보드 최상단에 '3회말 1사, 2-1 카운트 — 이어서 던지기'를 띄운다. 모바일 유료 게임에서 5~10분짜리 비저장 구간은 세션 설계의 결함이 아니라 환불 사유다.

### [P1] 시드 공유가 단방향 죽은 루프 — 받는 쪽이 그 시드를 플레이할 방법이 코드에 없다

- **근거**: SettingsView.swift:54~66이 careerID를 ShareLink로 내보내며 주석에 '커뮤니티에서 검증된 바이럴 경로'라고 적혀 있다. 그런데 HighSchoolCareerStore.swift:198 startCareer는 `seed: String(UInt64.random(in: 1...UInt64.max))` 하드코딩이고, 시드를 입력받는 UI/파라미터가 HighSchoolSetupView 어디에도 없다. 공유받은 사람은 그 문자열로 아무것도 못 한다. 공유 카드(LifeCardView, LifeArchiveView의 LifeSummaryCard)에도 시드가 인쇄되지 않는다 — 카드만 본 사람은 시드의 존재조차 모른다.
- **개선안**: 세 줄짜리 수정으로 루프가 닫힌다. ①startCareer에 `seed: String? = nil` 추가, ②HighSchoolSetupView에 '시드로 시작' 입력 필드(붙여넣기 감지), ③LifeCardView 푸터에 시드를 monospaced로 각인 + `baseball://seed/<id>` universal link. '이 시드 5회차 안에 지명 가능?' 챌린지가 커뮤니티에서 도는 순간, 유료 게임에서 살 수 없는 유기적 유입이 생긴다.

### [P1] 공유 버튼이 감정 최고점 세 곳(정산 폭발·드래프트 스탬프·생애 최고 구속) 전부에 없음

- **근거**: ShareLink 전체 grep 결과 3곳뿐 — SettingsView.swift:62(시드), LifeCardView.swift:172(LifeCardShareButton), LifeArchiveView.swift:224(LifeShareButton). RunRecapView.swift 전체에 ShareLink/LifeCardShareButton 호출이 없다(도장 찍히고 야구혼 차오른 직후 버튼은 '기억을 안고 다음 회차로' 하나뿐). ClimaxViews.swift의 DraftRevealView도 지명 스탬프 직후 PrimaryPill('계속')만 있다. 결국 공유 진입점은 RecordView.swift:33처럼 '회차 끝나고 기록 탭에 들어간 사람'에게만 열린다 — 감정이 식은 뒤다.
- **개선안**: RunRecapView의 soulDone 시점에 LifeCardShareButton을 '다음 회차로' 옆에 동급 크기로 놓는다. DraftRevealView의 지명 스탬프에도 공유를 붙이되 requestReview()와 순서를 나눈다(공유 먼저, 리뷰는 dismiss 시). 추가로 최근 넣은 승부구 슬로모/생애 최고 구속은 지금 순간 연출로만 소비되는데, 여기서 정지 프레임 1장을 ImageRenderer로 구워 '158km/h — 생애 최고' 카드로 남기면 회차당 공유 소재가 1장에서 3장으로 는다.

### [P1] 별점 요청이 이중 관문 뒤에 잠겨 있어 출시 초 리뷰 수집 창을 통째로 놓친다

- **근거**: ClimaxViews.swift:119 — requestReview()는 `if drafted` 조건 아래, 그것도 드래프트 공개 화면의 '계속' 버튼에서만 호출된다. 앱 전체에서 requestReview 호출부는 이 한 곳뿐(grep 확인). 드래프트는 8챕터·훈련 16회·중요 경기 4~6회를 다 지난 뒤이고, 초반 회차는 계승 야구혼이 캡 8점에 불과해 미지명 확률이 높다. 즉 '재미있었지만 아직 지명 못 받은 유저'는 시스템 프롬프트를 평생 못 본다.
- **개선안**: 감정이 양(+)인 조기 지점 하나를 더 연다: 첫 회차의 첫 무실점 이닝 완료(AchievementRules.fromInning의 cleanInning) 또는 첫 별명 획득 직후. iOS는 연 3회로 알아서 제한하므로 두 지점을 열어도 스팸이 되지 않는다. 유료 1위 유지의 실제 변수는 다운로드보다 리뷰 유입 속도이고, 지금 설계는 그 깔때기를 90분 뒤로 밀어 놨다.

### [P1] 업적 15개가 전부 0/100 이진 마일스톤 — 진행률도, 친구 비교 화면도 없다

- **근거**: AchievementStore.swift:78 `entry.percentComplete = 100` — 부분 진행을 보고하는 경로가 없다. AchievementsView.swift도 unlocked/locked 두 덩어리로만 나누고 '한 시즌 100탈삼진'까지 몇 개 남았는지, '네 갈래 길'에서 학교 몇 곳을 가 봤는지 표시하지 않는다. Leaderboard 3종(Achievements.swift:하단)은 submit만 하고 GKGameCenterViewController를 여는 코드가 앱 전체에 없다(GameKit import는 AchievementStore.swift 단 하나) — 유저는 자기 등수를 게임 안에서 볼 수 없다.
- **개선안**: ①AchievementRules에 progress(Double) 반환을 추가해 GKAchievement.percentComplete에 실값을 넣고 AchievementsView에 게이지를 그린다. ②설정 화면 구석이 아니라 기록 탭 상단에 '통산 탈삼진 전체 12,400위 / 상위 8%' 카드를 두고 탭하면 GKGameCenterViewController를 연다. 랭킹은 유료 게임에서 유일하게 무료인 리텐션 콘텐츠다.

### [P2] 프로 커리어가 '탭 → 결과 읽기'로 압축돼 주간 리듬이 게임 안에서 소멸

- **근거**: MobileCareerStore.swift:120 advanceSegment()가 `for _ in 0..<24`로 최대 24주를 한 번에 돌리고, 구간 변경·역할 변경·부상 때만 멈춘다. advanceBlock()은 3주 단위. 즉 프로 시즌 전체가 버튼 몇 번이며, 그 사이 유저 결정은 selectedPlan 하나로 고정된다. ProCareer.swift:294의 주간 자동 등판은 실제 커널을 돌리지만 결과만 집계돼 화면에 남지 않는다.
- **개선안**: 프로에는 '이번 주 딱 하나' 결정을 강제하는 훅이 필요하다 — 예: 3주에 한 번 등장하는 선택(불펜 데이 vs 강행, 신구종 실험 vs 승리 우선)이 시즌 말 성적에 눈에 보이게 반영되고, 그 선택이 회차 카드에 한 줄로 남게. 지금 구조는 '고교가 게임, 프로는 에필로그'라서 플레이 시간의 후반부가 통째로 리텐션에 기여하지 않는다.

### [P2] 회차 변주 풀이 3회차면 바닥 — 40%는 '바람 없는 해'

- **근거**: CareerWind.swift의 all 배열은 5개 항목인데 그중 2개가 완전히 동일한 "calm"(바람 없는 해) → 균등 추첨에서 40%가 무변주다. 나머지 3개(괴물 세대 rivalBonus+5/보상+150‰, 스카우트 풍년 fanInterest 20, 무명의 해 rivalBonus−3/보상+80‰)는 2~3회차면 전부 본다. RunPledge.all은 4개에서 3개를 제시하므로 사실상 첫 회차에 거의 다 노출된다. Nickname은 title 15종.
- **개선안**: '바람 없는 해'는 유지하되(변주의 기준점으로 필요) 바람 풀을 12개 이상으로 늘리고, 업데이트 로드맵을 여기에 건다 — 바람·약속·별명은 전부 careerID의 순수 함수라 저장 호환 리스크가 0이고(CareerWind.swift 주석이 직접 그렇게 설계했다고 명시), 앱 업데이트마다 '새 바람 3종·새 약속 4종'을 무료로 얹는 것이 유료 게임의 라이브옵스에서 가장 값싼 리텐션이다. 시즌제로 묶어 '여름 대회 시즌: 우천 순연의 해 추가'처럼 릴리스 노트를 이벤트화하면 앱스토어 What's New가 재유입 채널이 된다.

---

## 2. 로그라이트 이코노미 디자이너

**총평** — 이 게임의 메타 경제는 "화폐처럼 보이는 점수판" 하나(야구혼)와 "리소스처럼 보이는 죽은 변수" 둘(팬 관심, 잉여 전조)로 이루어져 있다. 야구혼은 소비처가 단 한 곳도 없고, 획득한 값이 60:1로 환산된 뒤 상한 20에 잘리기 때문에 회차당 실효 성장은 +0.9 능력치 남짓인데, 정산 화면은 "+52"를 64pt 폰트로 카운트업한다 — 로그라이트에서 가장 치명적인 종류의 거짓 보상이다. 그 결과 카르마 배율·회차 약속 +15%·프로 계승 보너스가 전부 같은 60:1 배수구로 흘러가 EV가 사실상 0이 되고, 핸디캡은 순손실 선택이 된다. 동시에 훈련 6지 중 2개, 야구혼 배분 3지 중 1개가 기계적으로 완전히 중복이라 선택지의 표시 개수와 실제 개수가 다르다.

### [P0] 야구혼은 화폐가 아니라 점수판 — 싱크가 0개이고, 획득량은 60:1로 환산돼 상한 20에 잘린다

- **근거**: HighSchoolCareerStore.swift:551-556 `soulPoints: previous.soulPoints + rewarded` — 전 코드베이스에서 soulPoints를 **감소**시키는 경로가 없다(grep 확인: 대입은 누적과 proSoulBonus 가산뿐). 실제 소비는 HighSchoolCareer.swift:2264 `inheritancePointCap(for:) = min(20, 8 + points/60)`. 즉 누적 720 이상은 전액 사장. 회차 기대 획득은 base = ratings/8 + record/4 ≈ 27+8 = 35(HighSchoolCareerStore.swift:543-545)이므로 **회차당 상한 증가는 35/60 ≈ +0.58점**, 8→20까지 12점을 채우는 데 약 14회차. 프로 전설 커리어(proSoulBonus = 20+seasons*3+K/25+awards*8+HoF/2, :587)가 250을 줘도 +4.2점이고 그 이후 모든 프로 커리어는 0의 가치다.
- **개선안**: 야구혼을 (a) 누적 점수 `soulTotal`과 (b) 소비 가능 잔액 `soulBalance`로 분리한다. 잔액은 회차 시작 화면에서 **실제로 차감되며** 쓴다: 재능 등급 1단계 구매(등급별 비용 60/120/240/480), 기억 카드 5장 후보를 8장으로 확장(80), 시작 능력 +1(현행 환산가 60), 프리셋 재추첨(40). 상한 20은 '무료 계승'으로 남기되 그 이상은 반드시 결제로만 얻게 해 인플레이션 지점을 제거한다. 최소 개입안: `inheritancePointCap` 분모 60을 유지하되 초과 야구혼을 회차 시작 재능 등급 구매로 자동 환류시킨다.

### [P0] 팬 관심(fanInterest)은 100% 데드 리소스 — 화면에 단 한 번도 표시되지 않고 어떤 판정에도 쓰이지 않는다

- **근거**: `grep -rn fanInterest apps/ios/Sources` 결과 0건, `grep -rn 관심 apps/ios/Sources` 0건. 코어에서도 읽는 곳은 자기 자신의 clamp(HighSchoolCareer.swift:1486, 1514)와 커밋 해시(:2568)뿐. 드래프트 평가식 draftEvaluationCore(:1741-1765)는 ratingScore/performanceScore/processBonus/awakeningScore/relationshipScore/seasonTerm/karmaPenalty/overusePenalty만 쓰고 fanInterest는 없다. 그런데 관계 3택 90여 줄이 전부 fanInterest 델타를 반환하고(:2067-2132, 도전 선택지의 유일한 차별점이 fanInterest +2~+7인 경우가 다수), 회차 바람 5종 중 `scout_frenzy`(CareerWind.swift:34-36)는 **효과가 startingFanInterest 20뿐**이라 전체 회차의 20%가 실효 no-op 바람이다.
- **개선안**: 둘 중 하나를 택한다. (A) 살린다: 드래프트 평가에 `fanInterestScore = (fanInterest-30)/12` (±5 캡)를 추가하고, 60 이상이면 중요 경기 시나리오에 '만원 관중' 압박 보정(첫 타자 피로 +2, 삼진 시 전조 +1)을 건다. 관계 '도전' 선택지의 유일한 대가/보상이 비로소 의미를 갖는다. (B) 제거한다: 필드와 90여 줄의 델타를 삭제하고 `scout_frenzy` 바람을 실효 효과(드래프트 문턱 -3)로 교체한다. 지금처럼 남겨두면 관계 3택은 '신뢰 최대값 고르기' 단일 지배 전략이다.

### [P0] 카르마 배율·약속 +15%·프로 보너스가 전부 60:1 배수구로 흘러가 핸디캡의 EV가 음수다

- **근거**: HighSchoolCareerStore.swift:550 `rewarded = base * (legacyRewardPermille + pledgeBonusPermille)/1000`. base≈35이므로 `erasedMemory`(rewardPermille 250, HighSchoolCareer.swift:70)는 +8.75 야구혼 = 상한 +0.15점. 그 대가는 memorySlots 3→2(:1104)이고 기억 카드 1장은 tuned()로 능력 +2~3(:2302-2319) — **즉시 -2~3점을 내고 다음 회차에 +0.15점을 받는다.** `noLastChance`(350‰)는 +12 야구혼 = +0.2점인데 드래프트 평가에서 karmaPenalty -2(:1750)를 직접 문다. RunPledge.bonusPermille=150(RunPledge.swift:14)은 +5 야구혼 = +0.08점인데 RunRecapView.swift:41은 '약속 이행 — 야구혼 +15%'를 도장으로 찍는다.
- **개선안**: 핸디캡 보상을 야구혼 총량이 아니라 **상한과 슬롯에 직접** 지급한다: rewardPermille를 폐기하고 카르마별 `inheritanceCapBonus`(unknownLand/stubbornCoach +2, singleWeapon +3, geniusGeneration/erasedMemory +4, noLastChance +6)와 `memorySlotBonus`를 준다. erasedMemory는 슬롯 -1 대신 '후보 5장 → 3장'으로 바꿔 정보 손실로 만들고, 약속 이행 보상도 +15%가 아니라 '다음 회차 기억 후보 +2장' 같은 즉시 체감 가능한 형태로 바꾼다.

### [P1] 훈련 6개 선택지 중 2개가 strictly dominated — 실제 메뉴는 4개다

- **근거**: HighSchoolCareer.swift:2385 `command + (focus == .command || focus == .gamePlanning ? points : 0)` + Talent.swift:156 `case .command, .gamePlanning: .command` → **.gamePlanning은 .command와 능력·재능축이 완전 동일**한데, :2376의 프로필 `control`은 `focus == .command`일 때만 오른다. 즉 .gamePlanning ⊊ .command. 마찬가지로 :2387 `stamina + (focus == .stamina || focus == .recovery ? points : 0)`이고 :1312 `recovery = params.focus == .recovery ? 18 : 0` → **.stamina는 .recovery와 성장·재능축이 동일한데 피로 -18을 못 받는다.** 두 경우 모두 유일한 예외는 학교 특기(+110)나 오늘의 기회(+90)가 그 focus를 정확히 가리킬 때뿐(:1222-1225).
- **개선안**: 각 focus에 고유한 2차 효과를 붙여 중복을 깬다. .gamePlanning은 command 대신 **포수 신뢰 +3과 다음 중요 경기 추천 정확도**를 올리게 하고(재능축은 command 유지, 능력치 상승은 0.5배), .stamina는 성장 2배 대신 `profile.fatigueCost` 영구 -1을 주고 피로 회복은 없애서 '지금 아프고 나중에 싸다'로, .recovery는 성장을 0.5배로 낮춰 '성장을 사서 피로를 판다'로 만든다. 지금은 6개 버튼이 4개의 일을 하고, 그 사실이 화면 어디에도 없다.

### [P1] 야구혼 배분 3버튼 중 2개가 기계적으로 동일하고, 3개 설명이 모두 사실과 다르다

- **근거**: PitcherLab.swift:1188-1192 / HighSchoolCareer.swift:2285 `domain == .body ? .velocity : domain == .technique ? .command : .gamePlanning` — 그런데 :2385에서 .command와 .gamePlanning은 동일하게 command만 올린다. **'기술'과 '경기 운영' 버튼은 같은 버튼이다.** 게다가 HighSchoolSetupView.swift:459-461의 설명은 '몸: 구위와 **체력**에 먼저' (실제 .velocity는 stuff만), '기술: 제구와 **변화구**에 먼저' (실제 .command는 command만)로 둘 다 거짓이고, movement(변화구)는 어느 도메인으로도 지정할 수 없다.
- **개선안**: SoulDomain을 4개(구위/제구/변화구/체력)로 능력축과 1:1 정렬하거나, 3개를 유지하되 `.game`을 `.breakingBall`로 재매핑한다. 설명 문구도 실제 매핑으로 교체한다. 동시에 잔여 배분이 '가장 낮은 능력부터'(:2294-2299)라서 회차를 거듭할수록 모든 빌드가 평평해진다 — 도메인 지정분을 절반이 아니라 전액으로 올리고 잔여는 0으로 두어, 야구혼이 빌드를 **뾰족하게** 만드는 자원이 되게 한다.

### [P1] 재능 천장이 계승 야구혼을 조용히 삼킨다 — 아무 고지 없이 break로 폐기

- **근거**: HighSchoolCareer.swift:2294-2299 `let open = rotation.filter(headroom); guard let lowest = ... else { break }` — 네 능력이 전부 천장에 닿으면 남은 야구혼은 **반환도 이월도 없이 사라진다.** 천장은 D=52, C=58(Talent.swift:29-35)인데 프리셋 시작치는 stuff 62/command 63/movement 64/stamina 64(PitcherPresetCatalog.swift:125-155)다. 등급 분포가 D 18% / C 27%(Talent.swift:186-192)이므로 **자기 주력 능력이 시작부터 천장 아래가 아닐 확률이 45%**이고, 그 능력은 만개(bloomThreshold 2~6회 두드림, :57-63) 전까지 계승을 1점도 못 받는다. 화면은 여전히 '야구혼 700을 어디에'(HighSchoolSetupView.swift:349)라고 묻는다.
- **개선안**: (1) 흡수되지 못한 잔여 야구혼을 폐기하지 말고 `talent.pressure`에 이월해 회차 시작부터 만개 게이지를 채운 상태로 시작하게 한다(잔여 20점 = 압박 +2 등). (2) 설정 화면에 실제 흡수량을 명시한다: '야구혼 700 · 이번 회차에 스며드는 양 14점(재능 벽으로 6점은 만개 게이지로 전환)'. 지금은 게임이 가장 크게 자랑하는 숫자와 실제로 일어나는 일이 두 단계나 떨어져 있다.

### [P1] 각성 전조는 공급 과잉 + 무조건 0 리셋 + 첫 각성은 플레이와 무관하게 스케줄 주사위가 결정

- **근거**: 수요: 각성 3회 × 3갈래 = 전조 3이면 만개(HighSchoolCareer.swift:1953 `sparks >= 3 ? 3 : sparks >= 1 ? 2 : 1`). 공급: 중요 경기 1회당 최대 3(:1531-1532, 무실점 또는 4K → +2, 피해 억제 → +1) × 4~6경기 + 만개마다 +1(:1361). 즉 **좋은 등판 한 번이면 게이지가 즉시 만렙**이고, 상한 6(:1533)의 절반은 영원히 쓰이지 않는다. 게다가 :1594 `awakeningSparks: ... ? 0 : nil` — 6을 쌓아도 각성 시 0으로 리셋되므로 초과분 3은 전액 소각. 반대로 makeSchedule(:1012-1024)은 관계/경기/각성 큐 순서를 시드로만 섞으므로 **약 1/3의 회차에서 각성이 첫 국면**이 되고, 그때는 경기가 한 번도 없어 전조 0 → 1갈래가 확정된다(플레이어 행동과 무관).
- **개선안**: (1) 상한을 6에서 3으로 낮추거나, 3 초과분을 리셋 대신 **이월**해 다음 각성에 넘긴다(초과 저축이 의미를 갖는다). (2) 각성 진입 시 전조를 전부 태우는 대신 '3 소비, 나머지 유지'로 바꾼다. (3) makeSchedule에서 첫 각성이 최소 1경기 뒤에 오도록 시퀀스를 제약한다 — 갈래 수를 스케줄 주사위가 정하면 그건 게이트가 아니라 벌금이다.

### [P2] 피로의 실제 임계(45/55)와 화면 경고(70)가 어긋나고, 45 이하에서는 완전 무료라 최적해가 고정 뱅뱅 패턴

- **근거**: HighSchoolCareer.swift:1221 `fatiguePenalty = max(0, state.fatigue - 45) * 3`, :955 `armFatigueFloor = 55`. 그러나 HighSchoolCareerView.swift:299는 `state.fatigue >= 70 ? .warning : .standard` — 페널티가 이미 25점(=신호 -75, 성장 1단계에 해당)을 먹고 있는 구간을 '정상'으로 칠한다. 그리고 45 미만에서는 피로 비용이 정확히 0이므로, 강훈련(비용 15, 신호 280 vs 표준 210)은 45 아래에서 **항상 옳고** 45 위에서는 **항상 틀리다**. 성장 문턱이 260/430(:1229)이라 학교 특기(+110)+오늘의 기회(+90)가 겹치면 강훈련 480은 2성장 확정, 표준 410은 28%만 2성장이다.
- **개선안**: 경고색 임계를 45/55로 코어 상수와 묶고(테스트로 고정), 피로 페널티를 계단이 아닌 연속 함수로 바꾼다 — 예: `fatiguePenalty = fatigue * fatigue / 45`. 그러면 0~45 구간에도 완만한 비용이 생겨 '언제 강훈련을 지를까'가 매 턴의 판단이 된다. 지금은 피로 게이지를 45에 붙여 두는 단일 해가 전 회차에 그대로 통한다.

### [P2] 회차 약속은 스테이크 없는 베팅 — 실패 페널티 0, 스킵은 순수 손해

- **근거**: RunPledge.swift 전체에 실패 시 패널티 경로가 없고, HighSchoolCareerStore.swift:464 `let pledgeBonus = pledgeAchieved ? RunPledge.bonusPermille : 0`으로 미달성은 0이다. HighSchoolCareerView.swift:1474에 `hs.pledge.skip` 버튼이 있는데, 스킵의 기대값은 어떤 약속을 걸든 그것보다 낮다(기대값 ≥ 0 vs 0). 4종 중 `get_drafted`(RunPledge.swift:24)는 회차의 기본 목표 그 자체라 추가 행동 변화가 0이고, `iron_control`(볼넷 8 이하)만이 실제로 투구 조작을 바꾼다. 주석은 '걸어 둔 도파민'이라 부르지만 걸린 것이 없다.
- **개선안**: 약속에 실패 대가를 붙여 진짜 베팅으로 만든다: 이행 시 야구혼 상한 +3(현행 +15%가 아니라), 미달성 시 다음 회차 기억 슬롯 -1. 그리고 난이도별 3티어(작은 약속/큰 약속/무모한 약속)로 배당을 다르게 준다. 스킵 버튼은 '약속 없이 간다 — 상한 +1'처럼 대안 보상을 줘야 결정이 된다. `get_drafted`는 회차 기본 목표와 중복이므로 '1라운드 지명'으로 올린다.

---

## 3. 캐릭터 애착 담당 내러티브 디자이너

**총평** — 문장 단위 품질은 좋다. "네 변화구, 솔직히 나도 못 받겠어. 이건 배터리가 아니라 각자 야구잖아" 같은 대사는 국산 인디 중 상위권이다. 문제는 그 좋은 문장이 게임 전체에 69줄뿐이고, 그중 회차당 4~6장면만 노출되며, 그 장면의 화자가 단 한 번도 내 선수의 이름을 부르지 않는다는 것이다. 애착은 "내가 이 사람과 뭘 겪었는가"의 누적인데, 이 게임은 환생할 때 감독·포수·라이벌의 이름조차 LifeRecord에 남기지 않는다 — 3년을 함께한 사람이 회차 정산 화면에서 완전히 증발한다. 현 상태로는 "내 자식"이 아니라 "잘 쓰인 텍스트를 3회차까지 읽는 경험"이다.

### [P0] 세계 전체가 내 선수를 단 한 번도 이름으로 부르지 않는다 — 애착의 1차 재료가 통째로 없다

- **근거**: CommunityBuzz.swift:70-77 커뮤니티 반응은 전부 3인칭 무명 — "저 선수 몇 학년임? 체격 좋아 보이던데", "프로 갈 생각 있는 선수임?". RelationshipVoiceCatalog.swift:107-410 손대사 69줄 어디에도 이름 보간이 없다(전부 정적 문자열). RelationshipVoiceCatalog.swift:490-516 aftermath는 화자를 "감독/포수/상대"라는 역할어로 낮춘다 — 코드에 school.coachName("윤태문"), state.rival.name("권태오")이 이미 있는데도 쓰지 않는다. HighSchoolCareerStore.swift:420-422 displayName("'제로' 김솔")은 프로필 표시에만 쓰이고 대사에는 절대 들어가지 않는다.
- **개선안**: (1) Scene.quotes를 정적 String에서 (PlayerContext)->String 클로저 또는 {player}/{coach} 토큰 치환으로 바꿔, 최소 각 화자의 첫 대사 한 줄에 이름을 넣는다 — "솔아, 네 변화구가 어디로 올지 몰라서 겁날 때가 있어"는 같은 문장이 전혀 다른 무게가 된다. (2) CommunityBuzz.reactions에 playerName/nickname 파라미터를 넣고 general 풀 8줄 중 4줄을 이름 포함형으로 교체("김솔 저거 몇 학년임?", "'제로' 다음 경기 언제임"). (3) aftermath(speaker:)에 speakerName을 넘겨 "윤태문 감독이 웃었다"로 출력.

### [P0] 관계 텍스트가 양극단으로 고갈된다 — 핵심 3인은 8회차면 100% 재탕, 확장 26종은 50회차 걸려야 다 본다

- **근거**: HighSchoolCareer.swift:993 relationshipTotal = 4 + rand(3) → 회차당 관계 장면 4~6개가 전부. HighSchoolCareer.swift:1973-1986 앞 3슬롯은 무조건 coach/catcher/rival이므로 확장 슬롯은 1~3개(평균 2)뿐. 코어 풀은 coach 3 / catcher 4 / rival 3(HighSchoolContentCatalog.swift:38-73) → 쿠폰수집 기대값 3·H(3)=5.5회차, 4·H(4)=8.3회차면 코어 10종 전부 소진. 반대로 확장 26종은 26·H(26)≈100뽑기 ÷ 회차당 2 ≈ 50회차. 손대사 총량은 27장면 = 21장면×3밴드 + 환생 6장면×1 = 69줄. 게다가 36개 기본 이벤트 중 16개(evt-bullpen-first, evt-command-wall, evt-rain-delay, evt-team-slump, evt-scorebook-close 등)는 손대사가 아예 없어 "…합니다" 3인칭 요약만 뜬다(RelationshipVoiceCatalog.swift:412-470 categoryScenes quotes: [:]).
- **개선안**: 코어/확장 배분을 뒤집는다. (1) 코어 3인 이벤트를 각 8~10종으로 늘리되 챕터 구간별로 잠가서 1학년 봄의 감독 대사와 3학년 여름의 감독 대사가 다르게 한다(현재는 챕터 무관 랜덤). (2) 확장 슬롯을 카테고리 셔플이 아니라 "이번 회차에 아직 안 본 이벤트" 가중치로 뽑아 50회차 → 13회차로 단축. (3) 손대사 없는 16개 이벤트에 최소 mid 밴드 1줄씩만 붙여도 노출 커버리지가 56%→100%.

### [P0] 감독·포수는 게임 전체에 4명뿐이고 학교 강점과 1:1로 묶여 있어, 구속 빌드를 도는 플레이어는 매 회차 같은 사람을 만난다 — 그리고 환생하면 이름조차 안 남는다

- **근거**: HighSchoolCareer.swift:894-909 schools(for:)는 지역 19곳 × 학교 4개 = 76개 학교명을 쓰지만 coachName/catcherName은 전 지역 공통 고정 4쌍(윤태문·서준호 / 노재형·한도윤 / 오승렬·차민석 / 배도환·문하진). strength가 각각 stamina/gamePlanning/velocity/breakingBall로 고정이라 특정 빌드를 노리면 항상 같은 archetype → 항상 같은 감독. HighSchoolCareerStore.swift:36-63 LifeRecord에는 schoolName만 있고 coachName/catcherName/rivalName 필드가 없다. 그래서 HighSchoolContentCatalog.swift:86 "낯익은 감독 — 감독의 말버릇이 낯익다. 만난 적은 없다"는 실제로 그 감독을 전에 만났는지와 **무관하게** 발동한다.
- **개선안**: (1) 감독/포수 이름을 지역별 세트로 확장(학교명 76개는 이미 있으므로 같은 규모로 이름 테이블만 추가)하고 archetype과 이름을 분리해 같은 '승부형'이라도 회차마다 다른 사람이 되게 한다. (2) LifeRecord에 coachName/catcherName/rivalName + 각 최종 신뢰도를 저장하고, RunRecapView 도장에 "윤태문 감독의 믿음 82로 마감"을 추가. (3) evt-known-coach 계열은 아카이브에 같은 이름이 있을 때만 발동시키고, 대사에 실제 이름을 넣는다 — 이게 환생 게임에서 유일하게 '자식 같은 애착'이 생기는 지점이다.

### [P1] 모든 대화 직후 뜨는 문장에 조사 처리 버그 — "감독은(는) 알겠다고만 했다", "상대이(가) 웃었다"

- **근거**: RelationshipVoiceCatalog.swift:500-515가 "\(who)은(는) 더 말하지 않았다", "\(who)이(가) 웃었다", "\(who)과(와)의 대화는…"을 그대로 출력한다. who는 감독/포수/상대/트레이너/팬/부모님(494-497). 실제 출력: "포수이(가) 고개를 끄덕였다", "상대이(가) 웃었다"(상대는 받침 없음 → 문법도 틀림). 이 문자열은 HighSchoolCareerStore.swift:783-786에서 lastSummary로 화면에 그대로 뜬다 — 관계 장면마다 반드시 보이는 자리다. 프로젝트에는 이미 DesignSystem.swift:319 KoreanCopy.particle(_:final:open:)이 있고 별명 문구(HighSchoolCareerStore.swift:431)는 그걸 쓴다.
- **개선안**: who가 6개 고정 문자열뿐이므로 분기 자체를 없앤다 — Speaker별로 조사가 붙은 완성 문장을 쓰거나, 코어에 KoreanCopy와 동등한 순수 함수(종성 판정 3줄)를 넣어 particle(who, "은", "는")로 치환. ₩4,400 유료 게임에서 첫 30분에 반드시 보이는 문법 오류다.

### [P1] 성격 시스템이 회차의 1/3에서 아예 발동하지 않고, 발동해도 마지막 1~2경기에만 적용된다

- **근거**: PersonalityRules.crystallizationThreshold = 5(Personality.swift:19)인데 관계 슬롯은 4~6 균등(HighSchoolCareer.swift:993). relationshipTotal=4인 회차(≈1/3)는 총 응답 4회 → personality가 영원히 nil → 드래프트 '스카우트 평가서 — 기질' 카드 미표시(HighSchoolCareerView.swift:1088), PersonalityTrait 보정(contact −10~−16) 전무. 5~6인 회차도 5번째 응답은 스케줄 인터리브상 6~7챕터에 오므로(HighSchoolCareer.swift:1012-1035) session.trait = personality?.trait(HighSchoolCareerStore.swift:352)가 4~6경기 중 마지막 1~2경기에만 붙는다. 게다가 responseTally는 환생 때 리셋(HighSchoolCareerStore.swift:222)이라 회차를 넘는 인격 축적도 없다. 성격은 4종뿐이다.
- **개선안**: (1) 임계를 3으로 낮추고 3/4/5회 시점에 '기질이 굳어가는' 중간 단계를 노출(가칭 임시 성격 → 확정). (2) 환생 시 responseTally를 지우지 말고 '전생의 기질'로 20% 가중 이월 — 환생 게임에서 '몇 회차를 살아도 결국 같은 성격으로 굳는 아이'는 강력한 애착 장치다. (3) 성격 4종을 축 조합(listen/explain/challenge 비율 격자 6~9종)으로 늘려 회차마다 다른 스카우트 평가서가 나오게 한다.

### [P1] 커뮤니티 반응이 한 회차 안에서 이미 한 바퀴 돈다 — 경기당 3줄 중 2줄이 고정 8줄 풀에서 나온다

- **근거**: CommunityBuzz.swift:35-66이 else-if 체인이라 상황 코멘트는 경기당 **정확히 1줄**만 나온다. 나머지 2줄은 general 8줄 풀(69-78)에서 채워진다(79-82). 회차당 중요 경기 4~6회 → general 뽑기 8~12회 vs 풀 크기 8 → 한 회차 안에서 1~1.5바퀴, 즉 첫 회차부터 "다음 경기 언제임? 직관 가고 싶은데"를 두 번 본다. 전체 buzz 문자열은 별명 3 + 무실점5K 4 + 무실점 3 + 볼넷 3 + 실점 3 + 삼진 3 + general 8 = 27줄이 전부. 볼넷 2개·2실점·삼진 3개 같은 '평범한 경기'는 매칭되는 조건이 하나도 없어 3줄 전부 generic이 된다.
- **개선안**: (1) else-if를 조건별 독립 append로 바꿔 한 경기가 복수 태그(무실점+볼넷많음)를 가질 수 있게 하고, general 의존을 3줄 중 0~1줄로 줄인다. (2) general 풀을 8→24로 확장하되 절반은 회차 상태 참조형(별명 보유, 학년, 팀 연패, 라이벌 전적)으로 만든다. (3) 이전 경기 대비 코멘트("저번보다 확실히 낫던데")를 넣으면 27줄로 체감 다양성이 배가된다.

### [P1] 세계 뉴스 5템플릿이 회차당 3.2회씩 반복되고, 뉴스 속 유망주와 실제로 상대하는 숙적 8명이 전혀 연결되지 않는다

- **근거**: CommunityBuzz.swift:103-121 rivalNews 템플릿은 5개뿐. 중복 금지는 **한 챕터(2줄) 안에서만** 적용되므로 8챕터 × 2줄 = 16줄이 5템플릿에서 나온다 → 템플릿당 평균 3.2회 반복. 수치 변주도 strikeoutCount(10~14), speedGain(2~5) 둘뿐이다. 더 큰 문제는 등장 인물: 뉴스는 ProspectRanking.board의 절차 생성 이름(ProspectRanking.swift:43-45, 성 20 × 이름 20)에서 뽑는데, 마운드에서 실제로 상대하는 숙적은 HighSchoolCareer.swift:926-941의 고정 8인(서하준·권태오·남도현·배시우·류건우·정세현·강이안·문재윤)이다. 두 명단은 교집합이 없다 — 3년간 뉴스로 쫓던 '괴물'을 끝내 만나지 않고, 8챕터 내내 상대한 권태오는 세상 뉴스에 한 번도 안 나온다.
- **개선안**: (1) rivalNews의 board 인자에 이번 회차 숙적을 강제 편입(랭킹 1~3위 고정)하고, 템플릿 절반을 숙적 전용으로 만든다 — "권태오, 지난주 네게 삼진 3개를 당한 뒤 타격폼을 바꿨다는 소문". RivalLedger(HighSchoolCareerStore.swift:597-606)가 이미 타석/삼진/피안타를 들고 있으므로 데이터는 있다. (2) 템플릿을 5→14로 늘리고 회차 전체에서 usedTemplates를 유지해 반복을 3.2회→1.1회로 낮춘다.

### [P2] 연대기가 5개 고정 템플릿의 로그이고, 실패는 "무너진 날" 한 종류뿐이다 — 3년의 이야기가 인과로 엮이지 않는다

- **근거**: HighSchoolCareerStore.swift:402-408 noteGame은 첫 등판 / 무실점 / 6K+ / 5실점+ 4분기뿐이고 문장도 고정("무너진 날 — {요약}. 이 경기를 기억해야 합니다."). 나머지 note 호출부(101, 270, 293, 331, 394, 431, 653)도 전부 단일 템플릿. 결과적으로 회차당 연대기 8~15줄이 거의 같은 문형으로 채워지고, LifeArchiveView.swift:148-153과 LifeCardView.swift:135-137(첫 1줄 + 마지막 4줄만 표시)이 그 로그를 그대로 재출력한다. 관계 장면에서 무엇을 선택했는지, 누구와 신뢰가 무너졌는지는 연대기에 단 한 줄도 남지 않는다.
- **개선안**: (1) 관계 선택을 연대기에 남긴다 — 신뢰 변화가 ±7 이상인 대화만(RelationshipVoiceCatalog.aftermath의 기존 임계 재활용) "2학년 여름 — 서준호에게 사인을 바꾼 이유를 끝까지 설명했다. 그날 이후 배터리가 흔들리지 않았다." (2) 실패 문형을 3~4종으로 나눈다(볼넷 붕괴 / 장타 붕괴 / 팔 통증 강행 / 라이벌에게 당한 날). (3) 연대기 항목에 인과 태그를 달아 회차 정산에서 "이 회차를 결정한 3장면"으로 뽑아 보여준다.

### [P2] 별명 13종이 강한 회차 한 번에 6~7개가 동시에 붙고, 그중 마지막 하나만 표시된다 — 수집 서사가 2~3회차에 끝난다

- **근거**: NicknameRules.catalogCount = 13(Nickname.swift:24). earned()는 계열별 배타가 아니라 **누적 배열 반환**이라(Nickname.swift:37-101) games≥5·무실점·볼넷0·30K 회차 하나에서 iron-wall, flawless, untouchable, nine-k, workhorse, k-monster가 한꺼번에 성립한다 — 문턱이 "짠 편"이라는 주석(36행)과 달리 좋은 회차 한 번이 도감의 절반을 연다. 반대로 displayName은 nicknames.last 하나만 쓰고(HighSchoolCareerStore.swift:420-422), RunRecapView.swift:38도 nicknames?.last만 도장으로 찍어 나머지 5개는 아카이브 한 줄에만 남는다. 부정 별명 3종(노 컨트롤/배팅볼/미완의 대기)은 games≥3·볼넷 9개 이상 같은 조건이라 반등 서사의 재료가 될 만큼 자주 뜨지 않는다.
- **개선안**: (1) 회차당 신규 별명 획득을 최대 2개로 제한하고 나머지는 다음 회차로 이월 — 도감 소진 속도를 3회차 → 8회차로 늦춘다. (2) 별명을 계열 배타(탈삼진/무실점/제구/서사 중 최고 1개 + 부정 1개)로 바꿔 "지금 이 아이를 부르는 이름"이 항상 하나로 읽히게 한다. (3) 별명 획득 시 감독·포수가 그 별명을 언급하는 대사 1줄을 붙인다 — 세상이 붙인 이름을 곁의 사람이 불러줄 때 비로소 애착이 된다.

---

## 4. 모바일 게임 UX 리뷰어 (정보 위계·인지 부하·피드백 타이밍·접근성·한 손 조작)

**총평** — 코드에 남은 주석은 UX 사고의 깊이가 상당하다는 걸 보여준다 — 좌타 코스 라벨 뒤집기, 심판 콜 박자, "결정하는 자리로 되돌린다" 같은 결정은 대부분의 유료 게임보다 정교하다. 그런데 그 정교함이 전부 '한 화면에 다 보인다'는 전제 위에 서 있고, 실제 구조는 세로 스크롤 1,500pt짜리 대시보드와 320pt 연출 패널이라 전제가 깨져 있다. 그 결과 이 게임의 가장 좋은 순간(성장 잭팟, 이닝 정산, 승부구 슬로모)이 체계적으로 화면 밖에서 재생되거나 도중에 잘려 나간다. 접근성은 reduceMotion 대응은 39곳에 있으나 다이나믹 타입은 12,659행 전체에 `ScaledMetric`/`dynamicTypeSize`가 0건이고, VoiceOver는 주력 화면에서 주자 상황을 읽어주지 않는다. 앱스토어 유료 1위를 노린다면 이 셋 — 연출 가시성, 다이나믹 타입, 투구 화면 탈출구 — 이 출시 전 필수 수정이다.

### [P0] 보상 연출이 구조적으로 화면 밖에서 재생된다 — 성장 카드와 이닝 정산 둘 다

- **근거**: HighSchoolCareerView.swift:118의 대시보드는 평범한 `ScrollView`이고 파일 전체에 `ScrollViewReader`/`scrollTo`가 0건이다(grep: scrollTo는 PitchView.swift 3곳뿐). 성장 카드는 스택 인덱스 ~4번(라인 143-147, 키아트 190pt·메트릭·buzz·worldNews 바로 아래)에 삽입되는데, 유저는 방금 스택 맨 아래(라인 643 `PrimaryButton("훈련하기")`)를 눌러서 그 자리에 있다. 즉 +2 성장·잭팟 연출이 현재 뷰포트에서 약 1,000pt 위에 뜬다. 게다가 HighSchoolCareerStore.swift:745에서 `pendingGains`는 매 `perform()`마다 덮어쓰이므로, 못 본 채 다음 훈련을 누르면 그 회차의 성장은 영영 안 보인 채 사라진다. 같은 결함이 PitchView.swift:1132-1139에도 있다 — `InningSettlementCard`가 `onAppear`에서 0.35+0.45n초 간격으로 슬롯을 열고 라인 1137에서 햅틱까지 치는데, 이 카드는 라인 293의 `lastPitchPanel`(드라마 320pt + 결과 카드) 아래라 뷰포트 밖이고, 라인 202의 자동 스크롤은 `dramaAnchor`로만 간다. 로그라이트의 핵심 문법인 정산 연출이 안 보이는 곳에서 진동만 남기고 끝난다.
- **개선안**: 대시보드를 `ScrollViewReader`로 감싸고 `pendingGains`/`pendingBloom`이 비어있지 않게 되는 `onChange`에서 해당 카드 id로 `scrollTo(anchor:.center)` 한다. 더 나은 안: 성장·잭팟은 인라인 카드를 버리고 `PitchView`의 정산과 같은 전면 오버레이(또는 하단 고정 시트)로 승격 — 회차당 16번 나오는 보상이므로 전면은 과하다면 최소한 화면 하단에 고정되는 토스트형 카드로. `InningSettlementCard`는 `onAppear`가 아니라 실제 가시성(`.onScrollVisibilityChange` 또는 스크롤 완료 콜백) 기준으로 슬롯 열기를 시작하고, `.finished`일 때 자동 스크롤 목적지를 `dramaAnchor` → 1.6초 뒤 정산 카드 앵커로 이어지게 한다.

### [P1] 승부구 슬로모가 재생 도중 자동 스크롤로 잘리고, K 현수막이 심판 콜보다 0.5초 먼저 뜬다

- **근거**: PitchView.swift:531 `let tempo = wasClutch ? 1.625 : 1.0`, 라인 532 재생 길이 `1.6 * tempo` = 승부구일 때 2.6초. 그런데 라인 210의 되돌아가기 지연은 `let delay = reduceMotion ? 0.0 : 1.7`로 tempo와 무관한 상수다. 즉 승부구 슬로모는 1.7초에 화면 밖으로 밀려나고, 라인 546의 삼진 풀콜(`1.32 * tempo` = 2.145초)과 라인 542의 3연속 삼진 축하음(`2.8 * tempo` = 4.55초)은 드라마가 안 보이는 상태에서 소리만 난다. 같은 상수 누락이 KBanner에도 있다 — 라인 1076 `asyncAfter(deadline: .now() + 1.6)`. 라인 1075 주석은 "새 K는 심판 콜(리플레이 ~1.5초)이 끝난 뒤에 걸린다. 결과보다 빠른 자랑은 스포일러다"라고 명시하는데, 승부구 삼진에서는 심판 콜이 2.145초라 K가 0.5초 먼저 걸려 스스로 정한 규칙을 위반한다. 하필 승부구 삼진이 이 게임 최고의 순간이다.
- **개선안**: `tempo`를 `PitchView` 상태로 올려 스크롤 지연과 KBanner 지연이 모두 참조하게 한다: `delay = 1.7 * tempo`(승부구 2.76초), KBanner는 `count` 변경 시 tempo를 함께 받아 `1.6 * tempo`. 근본적으로는 재생 완료 시점을 단일 소스(`replayProgress`가 1에 도달하는 `withAnimation` completion)로 만들고 스크롤·현수막·축하음이 전부 그 완료 신호를 구독하게 리팩터링.

### [P1] reduceMotion을 켜면 결과를 읽을 시간이 0초 — 접근성 설정이 피드백을 삭제한다

- **근거**: PitchView.swift:210 `let delay = reduceMotion ? 0.0 : 1.7`. reduceMotion 사용자는 라인 202에서 `dramaAnchor`로 스크롤한 직후 같은 런루프 다음 틱에 `controlsAnchor`로 다시 스크롤한다. `controlsAnchor`는 라인 303의 `AdaptationBar`에 붙어 있고 결과 카드(라인 363, 구속·존 안/밖·ZoneMiniMap·기질 발동 배지)는 그보다 위이므로 뷰포트 위로 완전히 밀려난다. reduceMotion은 "애니메이션을 줄여달라"는 요청이지 "결과를 보여주지 말라"가 아닌데, 이 설정을 켜면 방금 던진 공이 어디로 갔는지(ZoneMiniMap) 확인할 창이 사라진다. 참고로 라인 521-526에서 사운드 큐는 reduceMotion에서도 0.28초 간격으로 유지하고 있어, 소리는 배려하고 시각 피드백은 안 하는 비대칭이다.
- **개선안**: reduceMotion 분기의 지연을 0이 아니라 사운드 큐 총 길이(0.28×3 ≈ 0.84초)에 여유를 더한 1.2초로 둔다. 더 나은 안: 자동 되돌아가기 자체를 없애고, 결과 카드 아래에 "다음 공 고르기" 같은 명시적 앵커 버튼을 두거나, 컨트롤 영역을 하단 고정 시트로 빼서 스크롤 왕복 자체를 제거한다(그러면 이 타이머 3개가 전부 사라진다).

### [P1] VoiceOver가 주자 상황과 등판 누적을 읽지 않는다 — 레버리지 판단의 절반이 없다

- **근거**: PitchView.swift:652-657 `ScoreboardBar`의 `accessibilityLabel`은 점수차·이닝·아웃·볼·스트라이크·피로·stakes만 읽는다. 그런데 같은 뷰의 라인 617 `RunnerDiamond(runners:)`는 라인 690에서 `.accessibilityHidden(true)`이고 라벨 문자열에도 주자 정보가 전혀 없다. 야구에서 "2사 만루"와 "2사 주자 없음"은 완전히 다른 공인데, 이 게임은 라인 591-597에서 leverage로 무게를 계산하면서도 그 근거를 VoiceOver 사용자에게는 감춘다. 라인 631-638의 등판 누적("1.2이닝 · 3K 1BB 0실점")과 라인 641의 K 현수막도 `accessibilityElement(children:.combine)`이 라인 651에 걸려 있어 상위 라벨(라인 652)로 통째 대체되며 낭독에서 누락된다.
- **개선안**: `ScoreboardBar`의 accessibilityLabel에 주자 상태를 합성해 넣는다 — `runners.firstOccupied/secondOccupied/thirdOccupied` 조합을 "주자 없음/1루/1·2루/만루"로 매핑하는 헬퍼를 `PitchCopy`에 추가하고, 등판 누적 줄도 `accessibilityValue`로 이어 붙인다. 라벨이 길어지는 것이 걱정이면 `combine`을 풀고 스코어보드를 (점수·이닝·아웃) / (카운트·주자) / (등판 누적) 세 요소로 나눠 스와이프 탐색이 되게 한다.

### [P1] 다이나믹 타입 대응이 전무 — 접근성 글자 크기에서 투구 화면이 무너진다

- **근거**: `grep -rn "dynamicTypeSize|ScaledMetric" apps/ios/Sources` 결과 0건(12,659행). 반면 크기 상수는 전부 고정이다: PitchView.swift:328 드라마 패널 `.frame(height: 320)`, DesignSystem.swift:146 `keyArtHeight = 190`, DeliveryControl.swift:137 제스처 패드 `.frame(height: 92)`, PitchView.swift:930 존 그리드 셀 `.frame(height: 44)`, HighSchoolCareerView.swift:592/768/869 선택지 행 `minHeight: 60`. 텍스트도 마찬가지로 PitchView.swift:1055 K 현수막 `.font(.system(size: 15, ...))`, RunRecapView.swift:79 `size: 64`, PitchDramaView.swift:373/382/438은 Canvas에 `size: 13 * scale`, `26 * scale`(비거리 "125m")로 직접 그려서 시스템 글자 크기를 원천적으로 무시한다. 결정적으로 PitchView.swift:967-971의 `OptionRow`는 `.lineLimit(1)` + `.minimumScaleFactor(0.8)`이라 "체인지업", "존 밖 유인", "힘 빼고"가 접근성 크기에서 80%까지만 줄고 그 뒤로는 잘린다 — 구종·노림·힘은 이 게임 판정의 전부인데 그 이름이 읽히지 않는다.
- **개선안**: 최소한 투구 화면의 결정부부터: `OptionRow`에 `@Environment(\.dynamicTypeSize)`를 넣어 `.accessibility1` 이상이면 `HStack` → `VStack` 세로 배치로 전환하고 `lineLimit(2)`로 완화한다. 고정 높이(320/190/92/60)는 `@ScaledMetric(relativeTo: .body)`로 감싼다. Canvas 텍스트는 `context.draw` 대신 SwiftUI `Text` 오버레이로 빼서 시스템 스케일을 따르게 하거나, 최소한 `dynamicTypeSize` 비율을 `scale`에 곱한다. Xcode Previews에 AX3/AX5 변형을 추가해 회귀를 막는다.

### [P1] 투구 화면에 탈출구가 없고 세션은 메모리에만 있다 — 앱이 죽으면 이닝이 경고 없이 증발

- **근거**: PitchView.swift:223 `.toolbar(.hidden, for: .navigationBar)` + 라인 226 `.toolbar(.hidden, for: .tabBar)`로 화면의 모든 나가는 길이 막혀 있고, 라인 482-505 `footer`의 상태는 `DeliveryControl` / "다음 타자" / "경기 결과 반영" 셋뿐이라 중단·일시정지 버튼이 없다. 한편 `PitchSession`은 `@Observable final class`(PitchSession.swift:12)로 `Codable`이 아니고, HighSchoolCareerStore.swift:353에서 메모리 프로퍼티에만 담긴다. 라인 344-349를 보면 시작 시 시드를 미리 advance해서 저장하므로(리트라이 방지 의도) 앱을 껐다 켜면 phase는 여전히 `.importantGame`이라 처음부터 다시 던져야 한다 — 15분짜리 이닝이 통째로 날아가는데 화면 어디에도 그 경고가 없다. 유료 게임에서 이건 환불 사유가 된다.
- **개선안**: footer에 파괴적이지 않은 이탈 경로를 둔다: 상단에 작은 "등판 중단" 버튼 + `confirmationDialog`("지금까지의 이닝이 사라집니다"). 동시에 `PitchSession`의 재개에 필요한 최소 상태(seed, batterIndex, context, gameState, gameLog, 누적 카운트)를 `Codable` 구조체로 뽑아 매 투구마다 `save()`에 실어 앱 재시작 시 이어 던지게 한다 — 시드를 미리 advance하는 기존 안티치트 설계와 충돌하지 않는다.

### [P1] 되돌릴 수 없는 결정의 확인 절차가 일관되지 않다 — 가장 무거운 두 결정에 확인이 없다

- **근거**: 학교 선택(HighSchoolCareerView.swift:471-493)과 각성(라인 882-900)은 `confirmationDialog` + "다시 고른다"로 이중 확인을 받는다. 주석(라인 426-428)도 "잘못 눌러 3년을 날리는 일은 실제로 일어나고, 그 사람은 게임을 지운다"고 못 박는다. 그런데 그보다 무거운 두 결정에는 확인이 없다: (1) 라인 1205 `PrimaryButton("기억을 확정한다") { career.confirmLegacy() }` — 회차를 영구히 접고 계승 기억을 확정하는 단발 실행, (2) 라인 1273-1274 `Button { if opensLegacy { career.openLegacy() } ... }` — 라벨이 "이 회차를 접고 다시 시작"이고 부제가 "프로를 포기하고"인데 탭 한 번에 즉시 실행된다. 프로 커리어 진입 포기는 이 게임에서 되돌릴 수 없는 결정 중 가장 큰 것인데, 학교 선택보다 마찰이 낮다. 반면 설정의 "모든 진행 삭제"(SettingsView.swift:83)는 제대로 확인을 받는다.
- **개선안**: 라인 1273의 "이 회차를 접고 다시 시작"과 라인 1205의 "기억을 확정한다"에 학교/각성과 동일한 `confirmationDialog`를 붙인다. 문구는 결과를 구체적으로: "프로 커리어를 시작하지 않고 이 선수의 이야기를 끝냅니다. 지명은 사라집니다." / "기억 N장을 확정하고 이 회차를 닫습니다. 되돌릴 수 없습니다." iOS 26 팝오버 이슈 때문에 라인 483·897처럼 역할 없는 취소 버튼을 함께 넣는 기존 패턴을 그대로 따른다.

### [P2] 최소 조작 경로(그냥 던지기)가 곧 '사인대로 던지기'라 반복 페널티에 자동으로 걸린다

- **근거**: PitchSession.swift:307-313 `applyRecommendation(_:)`이 매 투구 준비마다 `selectedPitchType/Zone/Intent/Intensity`를 포수 추천으로 **무조건 덮어쓴다**(라인 256의 `absorb` 경로와 라인 300의 `prepare` 경로 양쪽). 즉 플레이어가 "이 타자한테는 낮은 바깥쪽 슬라이더로 밀어붙이겠다"고 정해도 다음 공에서 선택이 초기화되고, 유지하려면 매 투구 2~4탭을 다시 쳐야 한다. 반대로 아무 탭도 안 하고 와인드업만 하면 항상 포수 사인대로 던지게 되는데, 그 반복이 PitchView.swift:708의 `AdaptationBar`(0~900 눈금, 라인 119 "완전히 읽힘")를 올리는 바로 그 행동이다. 즉 인지 부하가 가장 낮은 경로가 게임이 벌하는 경로이고, 플레이어의 의도를 유지하는 저비용 수단은 없다(라인 873의 "사인대로 맞추기"는 반대 방향만 지원한다).
- **개선안**: 의도 유지를 1탭 이하로: CatcherCard에 "직전 배합 유지" 토글을 추가하거나(`applyRecommendation`을 스킵), 최소한 직전 투구의 call을 "방금 그 공 다시" 칩으로 컨트롤 영역 상단에 노출한다. 또는 구종만 유지하고 코스·노림만 사인으로 갱신하는 부분 적용 — "같은 구종을 코스만 바꿔 던진다"가 실제 투수의 사고 단위다.

### [P2] 대시보드의 주 행동 버튼이 고정되지 않아 매 턴 위치가 바뀌고, 훈련 선택은 매번 기본값으로 리셋된다

- **근거**: PitchView는 라인 482-505에서 `footer`를 `ScrollView` 밖 고정 영역에 두는데, 대시보드는 그런 고정 영역이 없다(HighSchoolCareerView.swift:118 단일 ScrollView). 훈련 턴 한 번의 스택은 조건에 따라 키아트 190pt + 메트릭 + 업적 배너 + 만개 + 성장 카드 + buzz + worldNews + 약속 줄 + TournamentCard(배너 84pt + 8팀 대진) + ChapterGoalCard + tally + TrainingCard(부상 카드 + 오늘의 기회 + 4×60pt 선택지 + 강도 카드 + 전망)까지 최대 13블록이라 `PrimaryButton("훈련하기")`(라인 643)에 닿기까지 1,500pt 이상을 내려야 하고, 조건부 카드 유무에 따라 그 버튼의 화면상 위치가 매 턴 달라진다 — 회차당 16회 반복되는 동작이다. 더해서 라인 502-503 `@State private var focus: TrainingFocus = .command` / `intensity: .standard`는 phase가 `.relationship`·`.importantGame`을 거쳐 `.training`으로 돌아올 때 뷰가 재생성되며 기본값으로 되돌아가, 같은 훈련을 이어가려는 플레이어에게 매번 재선택 탭을 강요한다.
- **개선안**: 대시보드 하단에 `safeAreaInset(edge: .bottom)`으로 주 행동 버튼(훈련하기/마운드에 오르기/다음 챕터로)을 고정한다 — PitchView의 footer와 같은 문법이라 일관성도 얻는다. 훈련 focus/intensity는 `@State`가 아니라 `HighSchoolCareerStore`의 지속 프로퍼티(직전 선택)로 올려 기본값으로 복원한다. 또한 buzz·worldNews·TournamentCard는 훈련 국면에서 접힌 상태(요약 1줄 + 탭하면 펼침)로 시작해 결정부까지의 거리를 줄인다.

---

## 5. 20년차 야구 게임 하드코어 유저 · 야구 기록 문화 전문가

**총평** — 투구 커널의 뼈대(타구 EV/LA 분리, BABIP·FIP·배럴 정의, 플래툰, 파크팩터, 희생플라이·병살 분기)는 국산 모바일 야구 게임 중 상위권이고, "자책점이 없으니 ERA를 쓰지 않는다" 같은 정직함은 야구 팬이 신뢰할 만한 태도다. 그런데 정작 투수 게임의 핵심 축 두 개 — **구속차/터널링(왜 체인지업을 던지는가)**와 **투구수·체력 관리(왜 8회에 팔이 무거워지는가)** — 가 판정식에 아예 없다. 스태미나 능력치는 커널이 검증만 하고 한 번도 읽지 않으며, 훈련으로 구종 피로비용을 0으로 만들면 100구를 던져도 피로가 오르지 않는다. 지금 상태는 "배합 게임의 외피를 쓴 코스 맞히기 게임"이고, 야구를 아는 사람일수록 20경기쯤에서 그 사실을 눈치챈다.

### [P0] 구속이 '절대값'으로만 평가돼 체인지업·커브의 존재 이유(구속차·터널링)가 판정에 없다

- **근거**: PitchKernelEngine.swift:1302 `velocityEdge = clamp((execution.velocityTenthsKPH - 1_370) / 2, -80, 180)` 가 구종 구분 없이 pitchDifficulty에 더해진다. 프리셋 속도(PitcherPresetCatalog.swift:49-53)로 계산하면 포심 1410 → +20, 체인지업 1210 → -80(하한), 커브 1090 → -80(하한). 즉 느린 공은 무조건 100점 손해를 안고 시작하고(contactChance 범위 120~940 기준 약 10%p), 직전 투구의 구속·궤적은 resolvePitch 어디에도 인자로 들어오지 않는다(1203-1377 전체에 lastPitch 없음). 각성 `sinkerTunnel`은 이름이 '같은 길에서 갈라지는 공'인데 실제 효과는 HighSchoolCareer.swift:2334 `tuned(..., pitchSet:[.fourSeam,.changeup], profileMovement:3, weakContact:5)` — 터널링 메커니즘이 아니라 숫자 +5다.
- **개선안**: SubmitPitchParams에 직전 투구의 (velocityTenthsKPH, actualX, actualY, flightTimeMilliseconds)를 넘기고 resolvePitch에 두 항을 추가한다. ①구속차: `deltaV = |v - prevV|`, contactChance -= min(70, max(0, deltaV-80)/3) — 141km/h 뒤의 121km/h 체인지업이 실제로 배트를 앞세우게. ②터널: trajectorySeries의 15/24 지점(이미 trajectoryControlX/Y로 뽑고 있다) 좌표가 직전 공과 200 이내면 추가 -40, 대신 최종 도달점이 멀수록 가중. 그리고 velocityEdge를 구종별 기준속도(포심 1420/슬라 1275/커브 1165/체인지업 1285) 대비 상대값으로 바꿔 '느린 커브'가 페널티가 아니라 중립이 되게 한다.

### [P0] 스태미나 능력치가 마운드에서 아무 일도 하지 않고, 훈련으로 '피로'라는 축 자체를 소거할 수 있다

- **근거**: PitchKernelEngine.swift:736에서 `pitcher.stamina`를 20~80 범위로 검증하지만, 이후 1911줄 전체에서 stamina를 읽는 판정식이 하나도 없다(grep 결과 736·1732행의 검증/해시뿐). 피로 증가는 fatigueCost()(1847-1859) = `profile.fatigueCost + intensityModifier`가 전부이고 스태미나와 무관하다. 반면 HighSchoolCareer.swift:2381 `fatigueCost: focus == .stamina ? max(0, profile.fatigueCost - points/2)` — 체력 훈련이 구종별 피로비용을 영구히 깎는다. 프리셋 innings_eater는 시작부터 포심·체인지업 fatigueCost 0(PitcherPresetCatalog.swift:112,115)이라 그 두 구종만 normal로 던지면 **첫 회부터 피로가 1도 오르지 않는다**. controlled는 -1이라 어차피 max(0,...)=0.
- **개선안**: 피로 산식을 `base = 2 + intensityModifier`, `cost = max(1, base * (140 - pitcher.stamina) / 90)`로 바꿔 하한 1을 보장하고 스태미나가 곧 투구수 곡선이 되게 한다(스태미나 80이면 구당 약 1.3, 30이면 약 2.4 → 100구 시점 피로가 각각 ~35 대 ~70). 훈련은 fatigueCost를 0으로 만드는 대신 stamina 레이팅만 올리도록 grow()를 수정한다. 그리고 등판 화면에 '남은 체력 기준 예상 소화 이닝'을 노출해 투구수 관리가 플레이어의 결정이 되게 한다.

### [P1] 타자가 카운트로 구종을 노리지 않는다 — 히터스 카운트가 없고, 3볼은 무조건 소극적이며, 2스트라이크 커트도 없다

- **근거**: PitchKernelEngine.swift:873-878 `pitchWeights = [(.fourSeam,340),(.slider,260),(.changeup,200),(.curveball,200)]` 는 볼카운트와 무관한 고정값이다(적응도 lean만 더해진다). 905-912의 approach는 `strikes==2 → .protect`, `balls==3 → .patient`뿐이라 3-1·3-0을 구분하지 못하고, .patient는 1254행에서 스윙 -150을 먹는다 — 실제 야구에서 장타율이 가장 높은 3-1 카운트가 이 엔진에선 가장 소극적인 카운트다. 파울 확률(1326-1331) `470 + (movement - contact)*3 + foulShift` 에는 strikes가 들어가지 않아, 2스트라이크에서 파울로 버티는 장면이 구조적으로 존재하지 않는다.
- **개선안**: commitBatterPlan에서 `balls - strikes >= 2`(2-0, 3-0, 3-1)일 때 fourSeam 가중치 +260을 주고 approach에 `.hunt`(zoneSwing +130, chase -90)를 신설하되 3-0만 .patient를 유지한다. foulChance에 `strikes == 2 ? +90 : 0`을 더해 커트 승부를 만들고, 그만큼 2스트라이크 삼진율이 떨어지므로 whiff 계수를 재보정한다(tools/check-balance.mjs로 K/9 9.97 유지 확인).

### [P1] 라이벌은 '내가 부른 코스'만 학습하고 '무슨 일이 일어났는지'는 버린다 — 저장한 outcome이 죽은 데이터

- **근거**: RivalMemory.swift:305-312 record()는 `call.pitchType`, `call.zone`을 저장한다 — 실제 도달 좌표(execution.actualX/actualY, PitchKernelEngine.swift:1227-1230의 landedZone)가 아니다. 그래서 손에서 빠져 반대쪽으로 간 공도 '그 코스를 반복했다'로 학습된다. 더 큰 문제는 `outcome`을 관측에 담아 두고(RivalMemory.swift:14) analyze()(203-293)에서 단 한 번도 쓰지 않는다는 것 — pitchSignal·zoneSignal·level 전부 빈도만 센다. 야구 팬이 기대하는 '방금 그 슬라이더에 좋은 스윙이 나왔으니 다음에 노린다'가 없고, 반대로 헛스윙 3개를 잡아낸 결정구도 빈도만으로 똑같이 읽힌다.
- **개선안**: 관측을 landedZone 기준으로 바꾼다(코스 반복 학습이 실제 제구와 연동된다). analyze()의 pitchShare를 결과 가중 빈도로 대체: 정타/2루타 이상 = ×3, 파울/인플레이아웃 = ×2, 볼 = ×1, 헛스윙/루킹삼진 = ×0.5. 그러면 '읽혔다' 경고가 '반복했다'가 아니라 '먹혔다'를 뜻하게 되고, 포수의 repetitionAvoided 전환(PitchKernelEngine.swift:30-34)도 야구적으로 옳은 시점에 걸린다.

### [P1] 기록 문법의 구멍 — 사구가 볼넷으로 집계되고, 승계주자·자책점·홀드·완봉/노히트가 전무하다

- **근거**: advanceCount(PitchKernelEngine.swift:1476-1482)가 .hitByPitch를 `.walk` 버킷에 넣는다. 그 결과 PitchSession.swift:234 `walks += snapshot.result == .walk`, AutoOutingSimulator의 `if paResult == .walk { line.walks += 1 }` 가 사구를 볼넷으로 센다 → RecordView.swift:83 '볼넷' 지표와 LeagueView.swift:29 WHIP(안타+볼넷)에 사구가 섞인다(실제 WHIP은 사구 제외). 기록 전체를 grep해도 hitByPitch 카운터는 존재하지 않는다(PitchingMetrics.fip의 인자는 항상 기본값 0으로 호출된다, LeagueView.swift:41-43). 승계주자도 없다: PitchScenario.swift:91·98의 프로 등판은 8회 무사 1루·9회 무사 1·2루로 시작하는 명백한 구원 등판인데, PitchSession.swift:235 `runsAllowed += snapshot.runsScored`가 앞선 투수의 주자까지 전부 내 실점으로 적는다. 홀드·완투·완봉·노히트 마일스톤도 전무하다(grep 무결과).
- **개선안**: ①PlateAppearanceSnapshot에 hitByPitch 플래그를 노출하고 ProGameLine·HighSchoolPerformance에 hitByPitch 필드를 추가, WHIP에서 제외하고 fip(hitByPitch:)에 실제로 전달한다. ②PitchScenario에 `inheritedRunners`를 두고 그 주자의 득점은 '승계주자 실점'으로 별도 집계해 RA9 분모에서 뺀다 — 구원 등판을 파는 게임이 이걸 안 나누면 기록을 아는 유저는 성적표를 믿지 않는다. ③DecisionRules에 홀드를 추가하고(3점 이내 리드 유지 + 아웃 3 이상), 완투·완봉·무4사구·노히트 마일스톤을 ProCareer.milestones에 넣는다. KBO 팬에게 홀드 없는 불펜 기록은 기록이 아니다.

### [P1] 시뮬레이션 리그의 모든 타자가 '포심에 강하고 커브엔 약점이 없다' — 리그 평균과 FIP 상수가 편향 표본 위에 서 있다

- **근거**: AutoOutingSimulator.swift의 scouting 생성부: `pitchStrength: .fourSeam` 고정, `pitchWeakness: rng.nextInt(upperBound: 2) == 0 ? .slider : .changeup`. 즉 리그 전체에서 커브가 약점인 타자는 0명이고 모든 타자가 직구에 강하다. 그런데 resolvePitch(1242-1245)는 strengthMatched에 contact +26/quality +32, weaknessMatched에 -30/-36을 준다. 게다가 자동 등판은 `call: preparation.primaryRecommendation.call` 로 포수 추천을 100% 그대로 던지고, 포수는 weaknessBonus 90(PitchKernelEngine.swift:134) 때문에 슬라이더/체인지업만 부른다 → 커브는 리그 통계에 거의 등장하지 않는다. PitchingMetrics.swift:79·107의 leagueRunsPer9 3.5와 fipConstant 3.67은 '600등판 실측'이라고 적혀 있지만 그 실측이 바로 이 편향된 타선에서 나온 값이다.
- **개선안**: AutoOutingSimulator의 강점/약점을 4구종에서 결정론적으로 추첨하되 서로 다르게 강제한다(hot/cold 존을 대칭으로 잡은 기존 처리와 같은 방식). 동시에 자동 등판이 추천을 100%가 아니라 ~85%만 수용하고 15%는 대체 추천을 쓰게 해서, 플레이어가 자기 배합으로 만든 성적과 리그 기준선이 같은 규칙 위에 서게 한다. 그 뒤 leagueRunsPer9·fipConstant를 재측정한다(현재 값은 재보정 필요라고 주석에 이미 명시돼 있다).

### [P1] 구종이 4개로 고정이고 역할(주무기/세컨/육성중)도 회차를 넘어 영원히 바뀌지 않는다 — 로그라이트인데 레퍼토리 성장이 없다

- **근거**: Domain.swift:3-7 PitchType은 fourSeam/slider/curveball/changeup 4종이 전부다(투심·포크·커터·스플리터 없음). PitcherPresetCatalog의 4개 프리셋(35-119행) 모두 같은 4구종 조합이고 다른 것은 숫자뿐이다. 더 심각한 건 role이 절대 변하지 않는다는 점: grow()(HighSchoolCareer.swift:2374)와 tuned()(2356)가 `role: profile.role`을 그대로 복사하고, 다른 어떤 경로도 role을 쓰지 않는다. 따라서 precision_commander의 커브는 8챕터·수십 회차 동안 훈련을 아무리 해도 영구히 `.development`이며, 포수 추천에서 -120(PitchKernelEngine.swift:144), 대체 구종 후보에서는 아예 필터로 제외된다(163행 `$0.role != .development`). 결정구를 완성해 가는 서사가 시스템에 없다.
- **개선안**: ①breakingBall/command 훈련 누적 신호가 임계치를 넘으면 development → secondary → primary로 role을 승격시키고, 승격 순간을 성장 연출(GrowthCelebrationView)로 터뜨린다 — 이 게임에 가장 필요한 '내 결정구가 완성됐다'는 순간이다. ②5번째 구종(투심·포크·커터)을 각성 갈래 또는 기억 카드 해금으로 붙인다. PitchType 확장은 App.tsx의 exhaustive Record가 tsc로 막혀 있으므로, PitchProfileSnapshot에 `variant` 필드를 두어 fourSeam→투심(무브먼트↑·구속↓), changeup→포크(수직 -250)처럼 같은 enum 위에서 파생시키는 방식이 안전하다.

### [P2] 포수 사인이 '정보'가 아니라 '기본 입력값'으로 채워져, 배합의 주체가 플레이어가 아니라 포수다

- **근거**: PitchSession.swift:307-313 applyRecommendation()이 매 투구 준비마다 `selectedPitchType/Zone/Intent/Intensity`를 포수 추천으로 덮어쓴다 — 화면을 열면 이미 추천대로 세팅돼 있어 던지기 버튼만 누르면 된다. 그리고 selectionQuality(1485-1519)는 약점 구종 +170, 강점 구종 -190, 콜드존 +130, 핫존 -170으로 사실상 '추천을 따르면 excellent'가 되도록 채점한다. 자동 등판까지 추천을 100% 수용하므로, 게임 전체에서 배합을 실제로 설계하는 주체는 CatcherRecommendationEngine이다. 이 게임이 파는 '내가 상대를 읽어서 이겼다'는 감각이 여기서 샌다.
- **개선안**: 추천을 선택 상태로 채우지 말고 존 그리드 위 반투명 오버레이로만 표시한다(플레이어가 능동적으로 '사인 수락' 또는 '고개 젓기'를 누르게). 그리고 catcherTrust(ProCareerSnapshot에 이미 있다)를 추천 신뢰도에 연결해, 신뢰가 낮으면 추천이 흔들리고 높으면 정확해지게 한다. 등판 정산에 '내 배합 성공률 vs 포수 배합 성공률'을 나란히 보여 주면 사인 거부가 도박이 아니라 학습이 된다 — recommendationAccepted 카운터가 이미 집계되고 있으므로 화면만 붙이면 된다.

---

## 6. 로그라이크 장르 평론가 (Slay the Spire·Hades·Vampire Survivors 분석 관점)

**총평** — 이 게임은 "로그라이트의 부품"은 거의 다 갖췄지만, 부품마다 **정답이 하나로 수렴하는 산수**가 코드에 박혀 있다. 훈련 16회는 화면이 정답을 읽어 주고(강한 회복 = 성장 +1~2에 피로 −3), 카르마 6종은 noLastChance+erasedMemory가 거의 공짜로 ×1.6이며, 재능 시스템은 만개 경제가 역전돼 "나쁜 재능에 몰빵"이 최적이다. 더 뼈아픈 건 결정론·시드 인프라(careerID 순수함수)가 완비돼 있는데 시드가 화면에 단 한 번도 노출되지 않는다는 점 — 일일 도전이라는 리플레이 엔진이 코드 10줄 거리에 방치돼 있다. 그리고 야구혼 메타는 inheritancePointCap이 17회차쯤 20에서 수학적으로 끝난다. 즉 이 게임의 반복 수명은 "언락이 없어서"가 아니라 **약 15~20회차에서 계산이 끝나도록 설계돼 있어서** 짧다.

### [P0] 훈련 16회 — 게임의 최대 결정 루프가 '화면이 정답을 알려주는' 단일 최적해로 붕괴

- **근거**: HighSchoolCareer.swift:1211-1227 trainingSignalBase: base(light 130/standard 210/hard 280) + schoolBonus 110 + opportunity 90 − max(0,fatigue−45)*3, 성장은 signal≥430→2, ≥260→1, 그 외 0. 여기에 HighSchoolCareer.swift:~1327 `let recovery = params.focus == .recovery ? 18 : 0` vs hard fatigueCost 15 → **강한 회복 훈련은 피로 −3인데 스태미나는 +1~2 성장**(grow()는 .recovery도 stamina를 올린다). 즉 피로 페널티(>45)가 원리적으로 발동하지 않아 강도 선택의 긴장이 0이다. trainingOpportunity(HighSchoolCareer.swift:2502)는 **매 훈련마다 반드시 하나 뜬다**(6종 중 직전과 다른 것) — 희소 이벤트가 아니라 상시 배지다. 결정타는 HighSchoolCareerView.swift:513-533 outlookCopy가 "크게 오를 훈련입니다. +2가 유력합니다"를 그대로 출력한다는 것. 최적 절차: 기회==학교특기면 강하게(=480, +2 확정), 아니면 강한 회복(피로 회수+무료 성장). 16번 반복.
- **개선안**: (a) 회복 훈련의 성장을 0으로 하거나 피로 감소를 −8로 낮춰 '성장 vs 회복'을 진짜 배타적 선택으로 만든다. (b) 기회 배지를 매 턴이 아니라 3~4턴에 한 번만 띄우고, 뜬 턴에는 강도 상한을 걸어 '지금 몰아붙이면 팔이 상한다' 트레이드오프를 만든다. (c) outlook은 숫자 예측 대신 코스트 축(피로·팔위험 증가분)만 보여주고 성장 구간은 감춘다 — StS가 카드 데미지는 보여주되 뽑을 카드는 안 보여주는 것과 같은 원리.

### [P0] 카르마 6종에 지배 조합이 고정돼 있고, 최고 보상 카르마의 설명은 코드에 구현조차 없다

- **근거**: HighSchoolCareer.swift:66-73 rewardPermille — noLastChance 350, erasedMemory/geniusGeneration 250, singleWeapon 200, unknownLand/stubbornCoach 150. 최대 2개 선택(HighSchoolSetupView.swift:394). 그런데 noLastChance의 코드상 전부는 HighSchoolCareer.swift:1750 `+ (state.karmas.contains(.noLastChance) ? 2 : 0)` — **드래프트 −2점이 전부**다. UI(HighSchoolPresentation.swift:168)는 "부상 한 번이 커리어를 끝낼 수 있습니다"라고 약속하지만 armRisk/injuryRecovery 어디에도 noLastChance 분기가 없다(전체 grep 결과 2곳뿐). erasedMemory는 기억 슬롯 3→2(:1099)인데 기억 카드 1장의 실효는 스탯 +2 = 드래프트 0.5점(ratingScore=ratings/4). 즉 **noLastChance+erasedMemory = 실비용 약 2.5 드래프트점에 야구혼 ×1.6**. 반대로 geniusGeneration(+250)은 라이벌 +4로 실제 투구 난이도를 올린다 — 아무도 안 고른다. stubbornCoach(+150)는 :1378 `isCoach && impact.trust < 0`일 때만 발동 → 감독에게 '도전'만 안 고르면 완전 무료 +15%.
- **개선안**: 각 카르마가 **회차 내 의사결정을 바꾸도록** 재설계한다. noLastChance는 문구대로 구현: 부상 1회 시 회차 즉시 종료(대신 그때까지의 야구혼 전액 지급). stubbornCoach는 부호 조건을 없애고 '감독 신뢰 획득량 절반'으로. erasedMemory는 슬롯 축소 대신 '계승 기억이 회차 중반까지 잠김'으로 바꿔 시간 축 페널티를 준다. 그리고 보상‰는 **실측 클리어율에 비례**해 재조정 — 지금은 난이도가 아니라 텍스트가 값을 정했다.

### [P0] 재능 만개 경제가 역전 — '나쁜 재능에 몰빵'이 수학적 최적, 드래프트 공식이 이를 확정한다

- **근거**: Talent.swift:29-37 ceiling(D 52/C 58/B 65/A 72/S 80), :58-66 bloomThreshold(D 2/C 3/B 4/A 6/S ∞). 벽 1회 두드림당 천장 증가는 D→C +6/2회=3.0, C→B +7/3=2.33, B→A +7/4=1.75, A→S +8/6=1.33 — **가장 낮은 재능이 투자 효율 최고**. 그런데 HighSchoolCareer.swift:1744 `let ratings = stuff+command+movement+stamina; ratingScore = ratings/4 + 15` — 드래프트는 **4능력의 합만** 본다. 어느 능력이 높은지는 평가에 없다. 게다가 만개는 :1340/:1363에서 awakeningSparks +1을 주므로 저재능 몰빵이 각성 갈래 수까지 벌어준다. 결과: 회차마다 '이번엔 D가 뭐지?'만 확인하고 거기에 16회를 붓는 것이 항상 최적 — 재능이 회차에 성격을 주기는커녕 매 회차 같은 절차를 만든다.
- **개선안**: (a) 만개 임계를 등급 무관 고정(예: 전 등급 4회)으로 하고, 대신 낮은 등급은 '만개해도 다음 등급까지만'으로 상한 회수를 제한한다. (b) 드래프트 ratingScore를 합이 아니라 **최고 능력 가중**(예: max*0.5 + 나머지 합*0.15)으로 바꿔 '뾰족한 투수'가 보상받게 한다 — 지금은 뾰족함에 보상이 0이라 빌드 개념 자체가 성립하지 않는다. (c) 재능 등급을 화면에서 '벽'이 아니라 '이번 회차의 정체성'으로 프레이밍(S가 있으면 그 축으로 미는 것이 더 이득이 되게).

### [P1] CareerWind는 5종이 아니라 실질 3종이고, 회차 중 어떤 결정도 바꾸지 않는다

- **근거**: CareerWind.swift:25-40 — all 배열 5개 중 인덱스 0,1이 **완전히 동일한 calm**. 즉 40%는 바람 없음, 실질 변주는 monster_generation/scout_frenzy/quiet_season 3종. 효과 전부가 시작 스냅샷 3개 필드뿐: rivalBonus(+5/0/−3, 20~80 스케일에서 6%), startingFanInterest(5/20/0), rewardBonusPermille(150/0/80). 파일 주석도 스스로 "상태에 저장하지 않는다 — 시작할 때 효과를 스냅샷에 새겨 넣는다"고 밝힌다. 결과적으로 바람은 뉴스 한 줄(newsLine) + 라이벌 능력 미세 보정이며, 훈련·각성·관계·경기 어느 국면의 **선택지 구성이나 규칙을 하나도 바꾸지 않는다**. Hades의 미러/Pact나 뱀서의 스테이지 모디파이어와 달리 '판이 다르다'는 감각이 발생할 지점이 없다.
- **개선안**: 바람을 **규칙 변경자**로 승격한다. 최소 8~10종으로 늘리고 각각 국면 규칙을 하나씩 건드린다 예: 「혹서기」 피로 회복 −50%·회복 훈련 성장 2배, 「스카우트 풍년」 매 경기 후 드래프트 예측 공개 + 관계 슬롯 1개가 미디어 이벤트로 대체, 「투고타저의 해」 모든 타자 power −8·홈런 시 야구혼 2배, 「부상 유행」 armRisk 축적 1.5배·재활 1회 단축. 그리고 duplicate calm 두 줄은 weight 필드로 바꿔 의도를 코드에 드러낸다(지금은 버그와 구분 불가).

### [P1] 야구혼 메타는 약 17회차에 수학적으로 종료된다 — 상한 20 도달 후 모든 보상이 장식

- **근거**: HighSchoolCareer.swift:2264 `inheritancePointCap = min(20, 8 + points/60)`, :2273에서 `remaining = min(points, cap)`. 회차당 획득은 HighSchoolCareerStore.swift:543-550 `base = max(4, ratings/8 + max(0,record)/4)` × 배율 — 평범한 회차가 ratings≈220, record(K40/BB8/R6)≈60 → base≈42, 카르마 최적 조합이면 ×1.6~2.5 → 회차당 60~105점. 720점(상한 20 도달)은 **7~12회차면 닿는다**. 그 이후 획득한 야구혼은 계승에 1점도 반영되지 않고, 소비처(언락·상점·영구 특성)가 코드에 전혀 없다. 게다가 headroom() 검사 때문에 재능 벽 아래에서만 스며들어 실효는 20보다 더 작다. 그런데 RunRecapView.swift:82는 매 회차 "다음 회차의 시작 능력에 스며듭니다"라고만 말한다 — 상한을 알리는 UI가 앱 전체에 없다.
- **개선안**: 상한 도달 이후를 위한 **두 번째 통화 축**을 연다. (a) 야구혼 총량을 소비해 회차 시작 전 '규칙 구매'(예: 각성 갈래 +1 영구, 훈련 잭팟 확률 +8%, 기억 슬롯 4번째)를 하도록 — 스탯이 아니라 규칙을 사면 상한 문제가 사라진다. (b) 최소한 정산 화면에 "이번 회차 계승 반영 12/20 (상한)"을 표기해 거짓 약속을 끊는다. (c) 상한식을 min(20, …)에서 로그 곡선으로 바꿔 30회차까지 완만히 성장시킨다.

### [P1] 일일 도전용 결정론 인프라가 100% 완비돼 있는데 시드가 화면에 단 한 번도 노출되지 않는다

- **근거**: HighSchoolCareer.swift:1088 `careerID = "career-\(params.seed)-life-\(params.lifeNumber)"` 이후 **회차의 뼈대 전부가 careerID의 순수 함수**다: 재능 TalentRules.make(careerID:) (:1091), 바람 CareerWind.wind(careerID:) (:1094), 스케줄 makeSchedule(careerID:) (:1113), 훈련 기회 trainingOpportunity(careerID:index:) (:2502), 경기 시나리오 "game_scenario|careerID" (:2294 부근), 관계 순서 "core_order|careerID", 회차 약속 RunPledge.options(careerID:) (RunPledge.swift:32), 챕터 목표 ChapterGoal.goal(careerID:). 심지어 stateCommitment 해시(:2523)로 상태 위조 검증까지 있다. 그런데 시드 생성은 HighSchoolCareerStore.swift:199 `String(UInt64.random(in: 1...UInt64.max))` 단 한 줄이고, 앱 어디에도 시드 표시·입력 UI가 없다. 드래프트 점수(draftForecast: 20~95)라는 **비교 가능한 단일 스칼라**까지 이미 있는데 순위표가 없다.
- **개선안**: 오늘 날짜를 시드로 고정한 '오늘의 회차'를 추가한다: seed = "daily-YYYYMMDD", 카르마·난도·프리셋 고정, 결과는 draftEvaluationCore.total로 채점. Game Center 리더보드는 이미 Achievements 배선이 있으니 재활용 가능. 추가로 정산 화면에 시드 문자열과 '이 시드로 다시 하기' 버튼을 넣으면, 한국 앱스토어 유료 1위에 필요한 **커뮤니티 공유 루프**(같은 시드 도전 인증샷)가 코드 변경 없이 생긴다.

### [P1] 학교 4종이 19개 지역에서 이름만 다른 동일 객체 — 그런데 학교 특기가 게임 최대 빌드 결정 요인이다

- **근거**: HighSchoolCareer.swift:891-910 schools(for:)는 지역별로 `names`만 갈아끼우고 **id·특기·감독 원형·포수 원형·트레이드오프가 전 지역 동일**하다: 한빛(stamina/원칙형/안정형), 미래(gamePlanning/분석형/분석형), 해동(velocity/승부형/공격형), 청암(breakingBall/육성형/공감형). regions 19개(:886)는 전부 화장이다. 반면 학교 특기의 기계적 무게는 최대급이다 — schoolBonus 110은 강도 light→hard 차이(150)에 맞먹고, 특기 focus를 강하게 훈련하면 signal 390(성장 1~2), 비특기는 280(27% 확률로 0) → **성장 속도가 사실상 2배**. 게다가 command 특기 학교가 없어 제구 빌드는 gamePlanning 학교로 우회해야 하고, 그 우회는 grow()에서 control 성장을 잃는다(:1400 부근). 이 모든 게 선택 화면에는 철학 문장과 tradeoff 텍스트로만 나온다.
- **개선안**: (a) 학교를 8~10종으로 늘리고 지역마다 후보 4개를 careerID로 추첨해 '이번 회차의 진학 선택'이 실제 변수가 되게 한다. (b) 각 학교에 특기 외에 **규칙 하나**를 붙인다(해동: 중요 경기 1회 추가·팔위험 축적 1.3배 / 미래: 스카우팅 신뢰도 +25 / 청암: 각성 후보가 항상 변화구 계열 1개 보장 / 한빛: 잭팟 확률 2배). (c) 선택 화면에 "이 학교에서 훈련하면 ○○ 성장이 약 2배"를 수치로 명시 — 지금은 가장 무거운 선택이 가장 안 보이는 선택이다.

### [P2] 각성의 유일한 조종 레버(직전 훈련 focus)가 완전히 숨겨져 있고, 전조 게이트는 못하는 플레이어만 처벌한다

- **근거**: HighSchoolCareer.swift:1914-1940 awakeningOptions: 후보 3개 중 첫 번째가 `focusOptions[state.lastTraining?.focus]`에서 뽑힌다 — 즉 **각성 직전 훈련을 무엇으로 했는지가 각성 후보를 지정한다**(velocity→폭발하는 포심/떠오르는 포심, breakingBall→5종 중 1, gamePlanning→4종 중 1). 이것이 18종 각성에서 원하는 것을 끌어오는 게임 내 유일한 결정론적 레버인데, apps/ios/Sources 전체에서 이를 언급하는 문자열이 0건이다(grep "각성" 결과 — 안내는 "고른 각성은 되돌릴 수 없습니다"뿐). 반대로 전조 게이트(:1946-1954)는 sparks≥3이면 3갈래인데, sparkGain(:1532)이 `무실점 or 삼진 4개 → +2, actualDamage≤expectedDamage → +1`이라 **호투 한 번이면 3점**이다. 즉 잘하는 사람에겐 상시 3갈래(변주 없음), 못하는 사람에겐 1갈래(선택권 박탈) — 실력 하강 나선만 만든다.
- **개선안**: (a) 각성 화면에 "직전 훈련(변화구)이 이 갈래를 불렀습니다"를 명시하고, 각성 국면 직전 훈련 카드에 '다음은 각성' 배지를 달아 **의도적 빌드 조종**을 가능하게 한다 — 숨은 시스템은 발견의 재미가 아니라 정보 격차다. (b) 전조는 갈래 '수'가 아니라 갈래 '등급'을 정하게 바꾼다: 전조 0이어도 3갈래를 주되 효과 크기를 60%로, 전조 6이면 상위 각성(현재 효과의 1.5배 또는 2연쇄) 후보를 연다 — 처벌이 아니라 보상 축으로 뒤집는다. (c) RunPledge 4종(RunPledge.swift:17-30, 3개 제시라 사실상 매번 같은 판)과 묶어, 약속 종류가 각성 후보 풀을 편향시키게 하면 '베팅→빌드'의 인과가 생긴다.
