# 한국 Meta 광고 계획 — 2026-08 출시 테스트

앱: **야구 못하면 또 환생함**
범위: 한국 App Store, iPhone, 유료 다운로드
목표: 광고를 무작정 확대하기 전에 어떤 메시지와 소재가 App Store 방문·구매·초기 활성화를 만드는지 검증한다.

## 결론

출시 직후에는 Meta의 **Advantage+ 앱 캠페인**을 하나만 만들고, 한국·iOS 중심으로 3~6개 소재를 넣는다. 초기 최적화 목표는 `앱 설치`로 시작한다. 현재 빌드에는 Meta SDK/MMP가 없으므로 Meta 광고 관리자에서 구매·활성화까지 직접 최적화한다고 가정하지 않는다.

Meta는 Advantage+ 앱 캠페인에서 입찰·오디언스·배치·예산을 자동화하고, 설치 또는 설치 후 앱 이벤트를 목표로 삼을 수 있다고 안내한다. 다만 이 앱의 구매는 App Store에서 일어나므로, 현재는 App Store Connect 캠페인 링크와 Sales and Trends를 구매 기준으로 사용한다.

## 집행 전 조건

- 앱 심사 승인 및 한국 스토어 노출 확인
- build 39에서 새 아이콘과 `com.solkim.baseball.ios://daily-inning` 딥링크 동작 확인
- 오늘의 이닝 이벤트 카드가 실제로 노출되는지 확인
- App Store Connect에서 캠페인 링크 생성
- Meta 광고 계정의 결제·앱 등록·iOS App Store 연결 확인
- 개인정보 라벨과 분석 수집 고지 상태 재확인

현재 제출된 build 38을 심사 중간에 교체하지 않고, build 39는 우선 로컬 아카이브와 테스트용으로 준비한다. 심사 전략을 바꿀 때만 App Store Connect에 새 빌드를 올린다.

## 캠페인 구조

### 캠페인 1 — 한국 출시 테스트

| 설정 | 권장값 |
|---|---|
| 목표 | 앱 프로모션 / 앱 설치 |
| 국가 | 대한민국만 |
| 기기 | iPhone, iOS |
| 언어 | 한국어 |
| 연령 | 18~44세로 시작 |
| 오디언스 | Advantage+ audience 유지, 관심사는 제안값으로만 사용 |
| 관심사 제안 | 야구, 스포츠 게임, 시뮬레이션 게임, 인디게임, iPhone |
| 배치 | Advantage+ placements 유지 |
| CTA | 앱 다운로드 |
| 도착지 | 한국 App Store 캠페인 링크 |

관심사와 연령을 너무 잘게 나누지 않는다. 초기에는 데이터가 적기 때문에 광고 세트를 여러 개로 쪼개면 학습 신호가 분산된다. 위치만 엄격하게 한국으로 제한하고, Meta가 그 안에서 확장하도록 둔다.

### 예산

- 권장 검증 예산: **하루 30,000원 × 7일 = 210,000원**
- 최소 예산: 하루 10,000원. 이 경우 구매 캠페인이 아니라 소재·클릭 테스트로 해석한다.
- 첫 48시간은 학습 구간으로 보고 큰 수정 없이 유지한다.
- 유료 앱이므로 최종 판단 기준은 CPI가 아니라 `광고로 발생한 App Unit × 실제 순수익`이다.
- 광고비가 앱 1건의 순수익보다 계속 높으면 광고를 확대하지 않고 소재·스토어 전환을 먼저 고친다.

## 소재 운영

### 현재 제작된 3종

| 소재 | 배치 | 핵심 메시지 |
|---|---|---|
| `meta-portrait-1080x1920.png` | Instagram Reels·Stories | 오늘의 이닝 / 세 번 던지고, 전국 순위에 도전 |
| `meta-square-1080x1080.png` | Instagram·Facebook Feed | 한 구씩 직접 던집니다 |
| `meta-landscape-1200x628.png` | Facebook Feed·링크 클릭 | 못하면 다시 태어납니다 |

세 소재는 상단 퍼널용 콘셉트 이미지다. 실제 구매 전환용으로는 기존 게임플레이 스크린샷과 10~15초 실제 화면 녹화를 추가한다. 첫 2초에 사인→조준→투구→판정이 보이게 만들고, 생성 이미지가 실제 게임 화면처럼 오해되지 않도록 광고 문구와 소재를 일치시킨다.

추가 카피 후보:

1. `한 구씩 직접 던지는 투수 게임`
2. `오늘의 타선을 세 번 상대하세요`
3. `못하면 다시 태어납니다`
4. `포수 사인을 읽고, 내 손으로 던집니다`

실존 구단·리그·선수·로고를 사용하지 않는다. 실제로 제공하지 않는 기능이나 순위·매출·리뷰를 과장하지 않는다.

## App Store 캠페인 링크

Meta 광고를 하나의 App Store URL로 모두 보내지 말고, 소재별 `ct`를 나눈다.

| 캠페인 토큰 | 용도 |
|---|---|
| `meta_kr_portrait` | 오늘의 이닝 세로 소재 |
| `meta_kr_square` | 한 구씩 직접 정사각 소재 |
| `meta_kr_landscape` | 환생 가로 소재 |
| `meta_kr_gameplay` | 실제 게임플레이 소재 |

App Store Connect 캠페인 링크는 App Store 상품 페이지로 이동하고, 캠페인별 노출·상품 페이지 조회·다운로드·사용·판매를 측정할 수 있다. 특정 캠페인의 데이터는 첫 다운로드 5건 이상과 24시간 경과 후 표시될 수 있으므로, 초반의 작은 숫자는 과해석하지 않는다.

예시 형식:

`https://apps.apple.com/kr/app/apple-store/id6794754217?pt=PROVIDER_TOKEN&ct=meta_kr_portrait&mt=8`

위 URL의 `PROVIDER_TOKEN`은 App Store Connect가 실제로 발급한 값을 사용한다. 임의의 값을 넣지 않는다.

## 7일 운영표

| 시점 | 실행 | 중단·확대 판단 |
|---|---|---|
| 승인 직후 | 링크·가격·아이콘·이벤트·딥링크 확인 후 게시 | 링크가 앱을 열지 못하면 광고 보류 |
| D1~D2 | 3종 소재 모두 송출, 대규모 수정 금지 | 노출·클릭·스토어 방문 유입 확인 |
| D3 | 소재별 CPM, outbound CTR, App Store Product Page Views 기록 | 클릭은 많은데 상품 페이지 전환이 낮으면 스토어 카피·아이콘 점검 |
| D4~D5 | 하위 소재 1개 교체, 실제 게임플레이 소재 추가 | Apple 캠페인별 5 App Units 이상이면 판매·사용 비교 |
| D6~D7 | 상위 소재에 예산 이동 | 구매당 비용이 순수익을 넘으면 확대 중단 |

## 측정 기준

Meta에서 보는 수치:

- CPM
- 링크 클릭률 / outbound CTR
- 광고별 클릭 수
- 빈도와 댓글·저장·공유

App Store Connect에서 보는 수치:

- 캠페인별 Product Page Views
- App Units / Sales / Proceeds
- 상품 페이지 전환율
- 캠페인별 사용·리텐션
- 오늘의 이닝 이벤트 노출·페이지 조회·앱 열기

앱 내부에서는 현재 구현된 Amplitude/Firebase 이벤트 `activation_first_game`, `rebirth_started`, `life_card_shared`를 본다. 다만 현재 빌드에는 Meta SDK/MMP가 없으므로 이 이벤트를 Meta 광고별 구매로 직접 귀속한다고 말하지 않는다. 정확한 Meta 최적화가 필요해질 때 별도 빌드에서 Meta App Events 또는 MMP를 검토하고, 그때 개인정보 라벨과 심사를 다시 맞춘다.

## 출시 전후 메시지

### 출시 전

광고를 집행하지 않고, 한국 야구·인디게임 이용자에게 출시 알림을 모은다. 승인 전에는 App Store 구매가 불가능하므로 광고비를 먼저 쓰지 않는다.

### 승인 직후

> 한 구씩 직접 던지는 투수 게임이 출시됐습니다.
> 오늘의 타선을 세 번 상대하고 기록을 남겨 보세요.

### 이벤트 시작일

> 오늘 자정, 모두 같은 타선을 상대합니다.
> 세 번 던진 기록 중 가장 좋은 점수가 남습니다.

리뷰를 조건으로 보상하거나 5점 평가를 요구하지 않는다. 만족스러운 플레이가 끝난 뒤 솔직한 평가를 부탁한다.

## 공식 참고

- Meta [Advantage+ 앱 캠페인](https://www.facebook.com/business/ads/meta-advantage-plus/app-campaigns)
- Meta [Advantage+ audience](https://www.facebook.com/business/ads/meta-advantage-plus/audience)
- Meta [Advantage+ placements](https://www.facebook.com/business/ads/meta-advantage-plus/placements)
- Apple [App Store 캠페인 링크](https://developer.apple.com/help/app-store-connect-analytics/acquisition/campaign-links)
- Apple [App Analytics 대시보드](https://developer.apple.com/help/app-store-connect-analytics/overview/analytics-dashboard/)
- Apple [Custom Product Pages](https://developer.apple.com/help/app-store-connect-analytics/acquisition/custom-product-pages/)
