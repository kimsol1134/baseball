# iOS 출시 전 페르소나 QA · 2026-09-12

대상: `apps/ios` HEAD `67e59a32` (1.2.9 / build 67)을 Debug로 새로 빌드해 iPhone 17 시뮬레이터(iOS 26.5, UDID `641C2F6D…E4BF`)에 설치하고 **실제로 플레이**했다. 조작은 `axe` + `xcrun simctl`, 사운드 켠 상태. 코드는 고치지 않았다.

증거 스크린샷: `apps/ios/releases/qa-1.2.9/personas-0912/{p1,p2,p3}/` (gitignore 대상).

> **후속 (2026-09-12): 이 보고서의 지적은 `docs/IOS_QA_FIXES_2026-09-12.md`로 옮겨 적용을 마쳤다.**
> P0 셋(글자 겹침·탭 바에 깔린 버튼·일본어 카피)과 P1 대부분이 고쳐졌고, 게이트 넷은 초록으로 돌아왔다.
> 남은 것은 둘이다 — **F-08**(알럿 확인 버튼 접근성 중복)은 SwiftUI 제약으로 해결하지 못했고,
> **F-12**(스크롤 위치)는 확인 결과 의도된 자동 스크롤이라 오진이었다. 자세한 내역은 그 문서의 "실행 결과" 표에 있다.

---

## 0. 결론

**지금 상태로는 제출하지 않는 것이 좋다.** 기능·저장·현지화 커버리지는 출시 수준이지만, 아래 셋이 남아 있다.

1. **모든 루킹 스트라이크·볼에서 결과 글자가 겹쳐 깨져 보인다.** 한 회차에 수백 번 보는 화면이고, 한국어·일본어 모두 재현된다. 스토어 스크린샷 한 장으로도 "버그 있는 앱"으로 읽힌다.
2. **장 리뷰의 주 버튼이 탭 바에 깔려 눌러도 다른 탭으로 이동한다.** 고교 8장 내내 매 장마다 지나가는 화면이다.
3. **일본어가 한국어가 아니라 영어에서 기계번역됐다.** 단위가 mph로 남은 문장 5개를 포함해 앱 안에서 수치가 모순되고, 핵심 용어가 화면마다 다른 단어로 불린다. `AGENTS.md`가 일본어 지원을 제출 조건으로 못 박아 둔 만큼 이건 선택 사항이 아니다.

1·2는 코드 몇 줄이고 3은 카피 작업이다. 셋을 처리하면 제출해도 된다고 본다.

덧붙여 **프로젝트 자체 게이트 3개가 빨간 상태**다(§5). 대부분 오탐·낡은 기대값이지만, 빨간 게이트는 진짜 회귀를 가려 준다.

---

## 1. 페르소나

| | P1 박하은 | P2 정민호 | P3 佐藤みなみ |
|---|---|---|---|
| 나이·직업 | 28 · 콘텐츠 마케터 | 34 · 게임 QA | 31 · 회사원(도쿄) |
| 배경 | 주말 중계는 본다. 육성 시뮬은 처음 | 육성 시뮬 다수. 수치와 규칙을 다 읽는다 | 만화로 야구를 안다. 한국 게임은 처음 |
| 환경 | 한국어 · 기본 설정 · **투구 슬라이더 직접 조작** | 한국어 · 설명 밀도 높음 | **일본어 · 글자 크기 접근성(AX3)** |
| 인내심 | 한 화면에서 2분 막히면 이탈 고민 | 막혀도 규칙을 찾아본다. 용어 오류에 민감 | 글자가 잘리면 바로 접는다 |
| 결정 규칙 | 가장 큰 아래 버튼 → 기본값 유지 → 훈련은 맨 위 카드 + 3회 반복 → 설명은 안 읽는다 | 목표는 야심 있는 쪽 → 수치를 대조 → 기록·설정을 연다 | 대사는 읽고 표는 훑는다 → 잘리면 멈춘다 |
| 도달 지점 | **고교 3년 완주 → 미지명(평가 38점) → 유산 화면** | 프로 1시즌 결산 → 오프시즌 → 2시즌 투자 → 기록 탭 · 은퇴 화면(픽스처) | 오프닝 → 첫 불펜 → 훈련 → 기록 탭(일본어·큰 글씨) |
| 한 줄 평 | "던지는 손맛은 진짜인데, 어느 화면에선 뭘 눌러야 할지 모르겠어요" | "구조는 좋다. 그런데 내가 선발로 나간 경기가 기록엔 구원이라고 적혀 있다" | 「文字が切れていて、日本語が時々おかしい」 |
| 별점 | 3.5 / 5 | 3.5 / 5 | 2.5 / 5 |

P1은 투구 타이밍을 최적화하지 않고(모든 구종에 같은 홀드 시간) 끝까지 갔다. 즉 **최적화하지 않는 라이트 유저의 3년 결과가 평가 38점 · 미지명**이다. 드래프트 화면이 `직접 등판 성적 −17`·`시즌 기록 −8`로 왜 떨어졌는지 숫자로 설명해 준 점은 9월 3일 보고서의 마찰 #3이 해소된 것이다.

---

## 2. 출시 차단 (P0)

### P0-1. 투구 결과 글자가 겹쳐 깨진다 — 모든 루킹 스트라이크·볼

`PitchDramaView`가 결과 한 단어(`drawVerdict`)를 캔버스 높이의 **0.12** 지점에, 판정 도장(`drawCallStamp`)을 **0.17** 지점에 그린다. 260pt 캔버스에서 13pt 차이인데 결과 단어는 32·scale이라 두 글자가 정면으로 겹친다. 두 그리기 모두 `progress`가 끝나도 불투명도 1로 남아 **겹침이 영구적**이다.

- `apps/ios/Sources/Features/Pitch/PitchDramaView.swift:181` (도장), 같은 파일 `drawVerdict` (결과 단어)
- 도장은 `.calledStrike`·`.ball`에만 찍힌다 = 가장 흔한 두 결과
- 근거: `p1/02-first-pitch-early-crop.png`(한국어 "루킹 스트라이크"+"스트라이크"), `p3/03-bullpen-scrolled.png`(일본어 "見逃しストライク"+"ストライク")

도장 y를 결과 단어 아래(존 위 여백)로 내리거나, 결과 단어가 떠 있는 동안 도장을 그리지 않으면 된다. 주석에 "존과 겹치면 안 된다"는 제약만 적혀 있고 결과 단어와의 충돌은 고려되지 않았다.

### P0-2. 장 리뷰의 "다음 이야기로"가 탭 바 뒤에 깔린다

장 정산 화면에 처음 들어오면 주 버튼이 y 806~858에 놓이는데 플로팅 탭 바가 y 791~874다. 초록 버튼이 탭 바를 통해 비쳐 보이고, **그 자리를 누르면 기록 탭으로 이동한다**(실측 — 자동 주행이 두 번 연속 기록 탭으로 튕겼다). 스크롤을 끝까지 내리면 버튼이 탭 바 위 27pt 지점까지만 올라온다.

- 근거: `p1/25-cta-under-tabbar.png`
- `AppShell.isChoicePhase`는 `.schoolSelection/.relationship/.awakening`만 탭 바를 숨긴다. `.chapterReview`가 빠져 있다 (`apps/ios/Sources/Features/Shell/AppShell.swift:335`)
- 훈련 화면은 `safeAreaInset`으로 고정 바를 얹어 이미 해결돼 있다. 장 리뷰만 본문 안 인라인 버튼이다 (`HighSchoolChapterReviewViews.swift:122`)

고교 8장 × 회차마다 지나가는 화면이라 빈도가 높다.

### P0-3. 일본어가 한국어가 아니라 영어에서 기계번역됐다

같은 키를 세 언어로 나란히 놓으면 분명하다.

| 키 | ko | en | ja |
|---|---|---|---|
| `pro.weekly.plan.stuff.effect` | 구위·포심 구속·헛스윙 성장 | Builds stuff, four-seam velocity, and whiffs | **ビルド内容**、フォーシーム 速度、および 空振り |
| `chapter.review.growth.summary` | 훈련 %lld회의 결과입니다. | This reflects %lld training sessions. | これは、%lld トレーニング セッションを反映しています。 |
| `conclusion.legacy.confirm-action` | 대표 유산을 확정한다 | Lock in the signature legacy | **署名のレガシーをロックインする** |

동사 "Builds"가 명사 「ビルド内容」로 번역돼 뜻이 사라졌고, "signature"가 서명(署名)이 됐다.

측정한 범위(ja 문자열 4,270개):

| 분류 | 건수 | 예 |
|---|---|---|
| **단위가 mph로 남음** | **5** | `content.event.evt-velocity-drop.title` 「時速1.2マイルの落下」 · `content.draft-team.…competitor-record` 「最高時速98.3マイル」 |
| 버튼이 「～してください」(의뢰문) | 6 | 취소 버튼이 「もう一度選択してください」 |
| 숫자와 조수사 사이 공백 | 67 | 「3 年の風」「%lld 回」「2 つの異なる日」 |
| 일본어 낱말 사이 불필요 공백 | 25 | 「トレーニング セッション」「空振り を構築」 |
| て형으로 끝나는 버튼(미완결) | 1 | `conclusion.memory.confirm-action` 「思い出を閉じ込めて」 |

**mph는 앱 안에서 모순을 만든다.** `GameFormatters.velocity`는 일본어에 km/h를 쓰도록 이미 올바르게 분기돼 있어(`GameFormatters.swift:22`), 투구 화면은 "140.8 km/h"를 보여 주는데 같은 회차의 이벤트 문장은 「時速1.2マイル低下」라고 말한다.

핵심 용어도 화면마다 다르다.

| 개념 | 일본어 표기들 |
|---|---|
| 변화구(능력) | 変化量 / 変化 / 変化球 |
| 대표 유산 | シグネチャーレガシー / 署名のレガシー / 署名の遺産 |
| 각성 | 覚醒 / 目覚め |
| 계승 포인트 | レガシーポイント / 継承ポイント |
| 체력 | スタミナ / 体力 |

`AGENTS.md`의 일본어 조건은 "번역이 존재한다"가 아니라 "일본어 사용자가 쓸 수 있다"이다. 지금 상태로 일본 App Store에 올리면 리뷰에 그대로 적힌다.

---

## 3. 높음 (P1)

### P1-1. 내가 선발로 나간 경기가 기록에는 "구원 · N주차"로 남는다

경기 시작 화면은 **"정규 경기 선발 등판 · 1회 0아웃 · 1회부터 마운드를 맡습니다"**라고 말한다. 그런데 기록 탭의 고교 경기 목록은 같은 경기를 **"2주차 구원 1.1이닝"**으로 적는다.

- `packages/simulation-core/…/HighSchoolCareer.swift:1129` — 플레이어가 직접 던진 줄(`playedLine`)이 `started: false`
- 같은 파일 `:1394` — 자동 시뮬 경기는 `started: true` (**반대로 들어가 있다**)
- `week: params.state.chapter.number`가 `record.game-log.week`("%lld주차")로 렌더된다. 고교는 주가 아니라 장이다
- 부수 효과: `DecisionRules.decide(started: false, …)`라 **승패 판정도 구원 규칙**으로 내려간다

표시만 고치면 안전하지만 `started`를 커널에서 뒤집으면 승패가 바뀌어 골든 픽스처에 영향이 간다. 표시 레이어에서 고교 등판을 선발로 부르고 "N주차"를 "N장"으로 바꾸는 쪽을 권한다.

### P1-2. 라이프 카드가 RA9를 "방어율"이라고 부른다 (한국어만)

`conclusion.life-card.ra9` → ko `방어율`, en `RA9`, ja `RA9`. 값은 `rate.ra9`다(`LifeCardView.swift:131`). 같은 지표를 다른 화면은 "9이닝당 실점"(`pro.totals.ra9`)이나 "RA9"(`record.saber.ra9`)로 부른다 — 한국어 이름이 세 가지다.

방어율은 자책점 기준이라 실점 기준 RA9와 다르다. ERA 자체는 있다 — **시즌 비교 카드**가 `ProSeasonMetricKind.earnedRunAverage`로 자책점 기준 평균자책을 계산해 보여 준다(`ProSeasonComparison.swift:37`, 자책점 없는 시즌은 만들지 않는다). 다만 **통산·시즌 합계 화면에는 ERA가 없다** — 기록 탭 세이버 표·은퇴 화면·공유 카드가 전부 RA9다. 그래서 "방어율"이라는 이름만 엉뚱한 자리에 붙어 있는 셈이다.

**공유 카드는 이 게임에서 가장 많이 밖으로 나가는 이미지다.** 거기 적힌 통계 이름이 틀린 것은 야구 게임에서 비싼 실수다.

### P1-3. 접근성 글자 크기에서 투구 화면이 정보를 잃는다

일본어 + 접근성 글자(AX3)에서 핵심 조작 화면이 이렇게 된다(`p3/02-bullpen-ja-ax.png`, `p3/03-bullpen-scrolled.png`):

- 주자·아웃 상태 「0アウト…」 잘림
- 미터 안내 「制球・安定…」 / 템포 「速い・疲労…」 둘 다 잘림 — **릴리스 창을 읽을 수 없다**
- 이번 등판 줄 「0回・0K・0BB・0R・…」 잘림
- 피로 라벨이 「疲」/「労」 두 줄로 쪼개짐
- 구종 버튼 줄과 구속·움직임·코스·체감 피로 행이 **고정 릴리스 바에 가려 화면 밖**. 무슨 공을 던지는지 보이지 않는다
- "자세히" 버튼 프레임이 **5pt × 144pt**로 찌그러진다

훈련 화면은 접근성 크기에서 고정 바를 스크롤 안으로 넣는 처리가 되어 있는데(`HighSchoolCareerView.swift:534`), 투구 화면에는 같은 처리가 없다.

### P1-4. `ProgressiveDisclosure`가 펼친 내용 전체에 제목 라벨을 덮어쓴다

`.accessibilityLabel(…)`이 `DisclosureGroup` 전체에 붙어 있어(`ProgressiveDisclosure.swift:158`) 자식 요소마다 같은 라벨이 전파된다. 시즌 결산 화면에서 「팬 지지 9 → 9」「시즌 변화 +0」「계약 기대 미달 −1」「현재 구단에서 시즌 완주 +1」 네 줄이 전부 접근성 트리에 **"팬 지지 변화 이유, 자세히 펼쳐짐"**으로 보고된다. VoiceOver 사용자는 내용을 하나도 듣지 못하고 제목만 네 번 듣는다.

앱 전체 **17곳**에서 쓴다(투구 포수 카드, 계약, 주간 계획, 시즌 결정, 훈련, 선수 만들기 …). 라벨을 `DisclosureGroup` 전체가 아니라 label 뷰에만 붙이면 된다.

### P1-5. 알럿 확인 버튼이 접근성 트리에 두 번 잡힌다

alert의 Button에 `.accessibilityIdentifier(...)`를 붙인 자리에서 같은 프레임·같은 라벨의 요소가 2개 생긴다. 식별자가 없는 취소 버튼은 1개다.

- 확인: `hs.school.confirm`("이 학교로 간다"), `hs.awakening.confirm`("이걸로 각성한다"), 오프시즌 "시작한다"
- VoiceOver가 같은 버튼을 두 번 읽고, 자동화는 라벨로 탭할 수 없다(`axe`가 "Multiple (2) accessibility elements matched"로 거부)

---

## 4. 중간·낮음

| # | 내용 | 근거 |
|---|---|---|
| P2-1 | **성장 카드가 국면을 넘어 남고 갱신되지 않는다.** `pendingGains`는 "닫기"로만 비워져서, 각성과 경기를 지난 뒤에도 "성장 · 제구 25 → 28"이 그대로 떠 있다. 같은 화면 능력표에는 제구 25라고 적혀 있다 | `p1/17`, `p1/18` · `HighSchoolCareerView.swift:687` |
| P2-2 | **영어에서 '변화구'(능력)와 '움직임'(구종 지표)이 둘 다 `Movement`.** 투구 화면에 두 숫자가 같이 뜬다 | `setup.stat.movement` vs `pitch.build.metric.movement` |
| P2-3 | **성장 그래프 축 라벨이 8~9pt 고정**이라 Dynamic Type을 무시한다. 공유 카드도 7/9pt | `ProCareerPresentation.swift:1696,1752`, `CareerShareCard.swift:197,200` — `check:design-system` 실패 원인 |
| P2-4 | **국면이 바뀌어도 스크롤 위치가 유지**돼 새 화면이 중간부터 보인다. 경기 시작 화면은 100%, 드래프트 결과는 82% 지점에서 열려 제목과 키아트를 지나친다 | `p1/17` vs `p1/17b`, `p1/32` vs `p1/33` |
| P3-1 | 피로 1에서도 미터 라벨이 "피로 영향"이라고 말한다. 실제 차이는 5ms다(`loop.meter.tired`는 `fatigue > 0` 전부) | `DeliveryControl.swift:111` |
| P3-2 | 선수 만들기 1단계가 같은 말을 네 줄로 한다 — 제목 "선수의 이름을 정하세요" / 부제 "이 투수의 이름을 정하세요" / 설명 "고교 3년 동안 이 이름으로 불립니다." / 캡션 "이 이름이 3년 동안 이 구장에서 불립니다." | `p1/06` |
| P3-3 | 드래프트 결과 화면에 "카드 공유"와 "선수 카드 공유"가 위아래로 붙어 있어 무엇이 다른지 알 수 없다 | `p1/31` |
| P3-4 | 와인드업 버튼의 접근성 라벨("와인드업")과 화면 문구("누르고, 초록에서 놓기")가 다르다 | `p1/01` |
| P3-5 | 리그 순위표의 승차(GB) 값이 행 접근성 라벨에 빠져 있다 | `p2/08` |
| P3-6 | 미지명 화면 배경을 88% 어둡게 덮는다(`ClimaxViews.swift:62`). 의도된 연출이지만 실기기 야외에서는 거의 검은 화면이다 — 0.75 정도로 완화 검토 | `p1/31` |

---

## 5. 게이트 현황 — 3개가 빨갛다

| 게이트 | 결과 | 내용 |
|---|---|---|
| `npm run check:ios-localization` | **통과** | 4,156개 엔트리, 미번역 0 |
| `npm run check:real-names` | **통과** | 실존 구단·리그·선수명 없음 |
| `npm run check:copy` | **실패 5** | 전부 **주석 오탐**(`도전 런`·`이번 생`·`무브먼트`). 린터가 주석을 건너뛰게 하거나 주석 표현을 바꿔야 한다 |
| `npm run check:design-system` | **실패 2** | P2-3의 고정 글자 크기. 2026-09-10 이식 커밋(`c4d17576`·`e7b19291`)부터 빨갛다 |
| `xcodebuild test -only-testing:BaseballIOSTests` | **실패 10 / 632** | `** TEST FAILED **`. 아래 |

단위 테스트 실패 10건을 하나씩 원인까지 봤다. **전부 낡은 기대값이거나 계약 위반이고, 제품 동작 회귀는 없었다.**

| 실패 | 원인 |
|---|---|
| `LocalizationCoverageTests` × 5 | Phase 2가 `PitchOutcome.reachedOnError`를 넣으면서 테스트의 기대 배열이 한 칸씩 밀렸다(기대 10 vs 실제 11). `batterSide` 기대값 `["우타","좌타","우타"]`도 세 번째가 틀렸다 — 카탈로그의 "양타"가 옳다. `setup.inheritance.shop.description`은 카피를 바꾼 뒤 잠금값이 안 따라왔다 |
| `CopyCallerContractTests`, `SabermetricsSurfaceTests` × 2 | 같은 원인 — `ProSeasonSettlementView.swift`가 `resolve/GameCopyText`에 인자를 직접 넘긴다. 이식 중 들어온 계약 위반이고, Presentation 헬퍼로 빼면 둘 다 풀린다 |
| `ScopedPresentationLocalizationTests` × 1 | 당락선 기대값이 66인데 실제는 50. 고교 규칙 8·9의 의도된 밸런스 변경이 기대값에 반영되지 않았다 |
| `RetentionTests` × 2 | **제품이 아니라 테스트가 틀렸다.** 테스트는 `HighSchoolCareerEngine().start(...)`를 직접 부르면서 `completedLives`를 안 넘긴다 → `completedLives ?? (lifeNumber − 1)` 폴백으로 1생 완주 보너스(+3)가 붙는다. 스토어는 실제 아카이브가 비어 있으니 `completedLives: 0`을 넘긴다(`HighSchoolCareerStore+Lifecycle.swift:519`). 스토어 쪽이 맞다 |

즉 **초록으로 되돌리는 일은 기대값 갱신 + 인자 조립 한 군데 리팩터**다. 다만 그 전까지는 이 스위트로 회귀를 못 본다.

테스트 로그에서 따로 발견한 위생 문제 둘:

- **단위 테스트가 실제 `NSUbiquitousKeyValueStore`에 테스트마다 새 키를 써서 1024키 한도를 넘겼다**(`Exceeded maximum number of keys (1024)` 52회). 제품 경로는 고정 키 5개(`baseball-mobile-highschool-v1.json` 등)라 안전하지만, 한도에 걸린 뒤로는 저장 검사가 의미를 잃는다. 테스트용 스토어를 주입하거나 종료 시 키를 지워야 한다
- 테스트 실행이 실제 Amplitude로 이벤트를 쏴서 429(rate limit)를 받는다. `AnalyticsContext`가 Debug를 `distribution: debug`로 태깅하니 대시보드에서 거를 수는 있지만, 테스트는 아예 안 쏘는 편이 낫다

---

## 6. 확인된 개선 (9월 3일 페르소나 보고서 대비)

- **탭 바 4개 → 3개**(내 투수/기록/설정), 훈련 화면의 `훈련하기`·`같은 훈련 3번 연속`이 탭 바 위 고정 바로 올라왔다 — 당시 마찰 #1(주 행동이 탭 바 뒤)이 훈련·계약·중요 경기에서 해소됐다. 장 리뷰만 남았다(P0-2)
- **온보딩이 "먼저 던져 보고 시작"으로 바뀌었다.** 오프닝 → 첫 불펜(8구) → 선수 만들기 3단계. 첫 화면에 "누르고, 초록에서 놓기"가 있어 라이트 유저가 바로 손맛을 만난다. 불펜에서 얻은 성장이 실제 시작 능력치에 반영된다
- **드래프트 컷이 플레이 중에 보인다.** 장 머리말에 예보가 붙고, 결과 화면이 `직접 등판 성적 −17`·`시즌 기록 −8`로 감점 근거를 적는다 — 당시 마찰 #3 해소
- **저장 게이트 교착이 고쳐졌다.** `MobileCareerStore.canWrite()`가 후보 스탬프가 아니라 빌드 상수 `ProCareerPersistence.currentSchemaVersion`과 비교한다(`MobileCareerStore+Persistence.swift:187`) — 8/30 "저장공간" 1점 리뷰의 원인
- 주간 노트 분모가 정상(3/3, 2/2)이고, 빈 시즌은 `—`와 "サンプルがまだ少ない" 안내로 방어한다
- 투구 슬라이더가 기본값(`PitchControlPreferences.defaultAutoRelease = false`)이고 실제로 슬라이더로만 던져진다 — `AGENTS.md` 불변 규칙 충족
- 앱 이름이 세 언어로 현지화돼 번들에 들어 있다(ko/en/ja `InfoPlist.strings`), `PrivacyInfo.xcprivacy`·`ITSAppUsesNonExemptEncryption` 준비됨, 알림 권한은 설정에서 켤 때만 요청
- 앱 소스에 `fatalError`/`try!`가 없고 강제 언랩은 오디오 렌더 콜백 12곳뿐

---

## 7. 권하는 순서

1. **P0-1** 도장 y 좌표 (1줄) — `PitchDramaView.drawCallStamp`
2. **P0-2** `isChoicePhase`에 `.chapterReview` 추가하거나 리뷰 CTA를 `safeAreaInset`으로 (1~5줄)
3. **P1-2** `conclusion.life-card.ra9` 한국어를 "9이닝당 실점"으로 (카피 1줄). ERA를 실제로 보여 줄지는 별도 판단
4. **P1-1** 고교 등판 표시를 선발/장으로 (표시 레이어)
5. **P0-3** 일본어 재작업 — **한국어 원문에서** 다시 번역. 최소한 mph 5건·버튼 6건·용어 5종은 출시 전에
6. **P1-4 / P1-5** 접근성 라벨 2건 (각 1~2줄, 영향 범위는 넓다)
7. **P1-3** 접근성 글자 크기의 투구 화면 — 훈련 화면과 같은 방식으로
8. 게이트 3개 초록 복구 (§5) — 진짜 회귀를 보려면 먼저 필요하다
9. P2·P3 항목

---

## 8. 검증한 것 / 못한 것

**했다** — 신규 설치 첫 실행부터 고교 3년 완주·드래프트·유산까지 직접 플레이(P1, 슬라이더 투구 205구 + 수동 12구). 프로 시즌 결산 → 오프시즌 → 2시즌 투자, 기록 탭, 은퇴 화면(픽스처). 일본어 + 접근성 글자 크기로 오프닝·불펜·훈련·기록. 정적 게이트 4종과 단위 테스트 632개 전량(실패 10건은 원인까지 추적). 카탈로그 3언어 전수 점검(4,270 ja 문자열 포함).

**못 했다** —

- **실기기 확인 없음.** 전부 시뮬레이터다. 햅틱·실제 오디오 지연·야외 밝기(P3-6)는 기기에서 다시 봐야 한다
- **프로 2시즌 이상 정규 주행 없음.** 프로 후반부는 픽스처로만 열었고, 픽스처의 시즌 데이터가 비어 있어(0경기) 세이버 표·성장 그래프·앨범은 **수치가 든 상태로 보지 못했다**
- (확인 완료 · 제품 문제 아님) 은퇴 화면이 통산 210경기·540이닝과 함께 "시즌 1"을 보여 주는 것은 픽스처 탓이다. `pro.totals.seasons`는 `state.careerStats.count`를 쓰는데(`ProRetirementViews.swift:333`), 픽스처가 8시즌 합계를 한 줄에 담아 넣는다
- `QACaptureUITests`는 기준선에서도 끝나지 않아 돌리지 않았다(알려진 문제)
- 영어 카피는 형식 검사만 했고 정독하지 않았다. 일본어에서 나온 문제는 영어 원문이 아니라 번역 공정의 문제로 보인다

---

## 9. 재현

```bash
# 빌드·설치
xcodebuild -project apps/ios/Baseball.xcodeproj -scheme BaseballIOS -configuration Debug \
  -destination "platform=iOS Simulator,id=641C2F6D-BF5F-406F-B22C-FEB35CB4E4BF" build
xcrun simctl install 641C2F6D-… <DerivedData>/Build/Products/Debug-iphonesimulator/BaseballIOS.app

# P1 (한국어·기본)
xcrun simctl launch 641C2F6D-… com.solkim.baseball.ios -uiTestResetCareer
# 투구는 axe touch -x 201 -y 778 --down --up --delay <초>. 홀드 시간 ≈ sweepSeconds/2,
# sweepSeconds = 1.18 − (구속tenths−1100)/400×0.38 − 피로/100×0.24

# P2 (프로 후반 픽스처 — -uiTestResetCareer와 함께 줘야 적용된다)
xcrun simctl launch 641C2F6D-… com.solkim.baseball.ios -uiTestResetCareer -uiTestSeasonReviewFixture
xcrun simctl launch 641C2F6D-… com.solkim.baseball.ios -uiTestResetCareer -uiTestRetiredShareFixture

# P3 (일본어·접근성 글자)
xcrun simctl ui 641C2F6D-… content_size accessibility-extra-large
xcrun simctl launch 641C2F6D-… com.solkim.baseball.ios -AppleLanguages "(ja)" -AppleLocale ja_JP -uiTestResetCareer
xcrun simctl ui 641C2F6D-… content_size large   # 끝나면 되돌린다
```
