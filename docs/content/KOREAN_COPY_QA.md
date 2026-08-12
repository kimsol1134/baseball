# 한국어 게임 문구 QA

이 저장소는 두 층으로 한국어 문구를 검사한다. 기존 `npm run check:copy`는 내부 용어와 실존 프로야구 리그·구단·선수의 직접 지칭을 차단한다. 새 `npm run check:korean-copy`는 Swift 콘텐츠 카탈로그의 플레이어 노출 문자열을 추출해 장면 문체, 반복 밀도, 화면 분량과 이벤트 폴백을 검사한다. 어느 도구도 문구를 자동으로 고치지 않는다.

## 빠른 실행

```sh
npm run check:korean-copy
npm run test:korean-copy
npm run check:copy
```

개발 명령은 문체 신호를 경고로 보여 주되 종료 코드는 오류만 반영한다. CI는 `npm run check:korean-copy:ci`를 사용해 경고도 실패로 다룬다. 기계 판정이 어색한 문구를 발견하게 돕는 첫 관문이지, 사람의 읽기 검토를 대신하는 합격 인증은 아니다.

기본 대상은 다음 세 파일이다.

- `packages/simulation-core/Sources/SimulationCore/RelationshipVoiceCatalog.swift`
- `packages/simulation-core/Sources/SimulationCore/HighSchoolCareer.swift`
- `packages/simulation-core/Sources/SimulationCore/HighSchoolContentCatalog.swift`

다른 Swift 카탈로그를 직접 검사할 수도 있다.

```sh
node tools/check-korean-game-copy.mjs path/to/One.swift path/to/Two.swift
node tools/check-korean-game-copy.mjs --json path/to/Catalog.swift
```

JSON 출력은 `schemaVersion`, 대상 파일, 추출 문자열 수, 오류·경고 수, `passed`, 발견 목록을 담는다. 문자열 파서는 Swift의 일반/여러 줄 문자열을 읽고 주석은 제외하며 `\u{…}`를 복원한다. Swift 보간식은 화면 길이를 추정할 때 짧은 가시 값으로 취급한다.

## 규칙과 심각도

오류는 신뢰도가 높은 결함에만 쓴다.

- 선택지 제목과 상세가 완전히 같은 경우
- 단일 화면 문자열이 180자를 넘는 경우
- `HighSchoolContentCatalog` 이벤트 카테고리에 `RelationshipVoiceCatalog`의 사건별 장면, 카테고리 폴백 또는 핵심 인물 폴백이 없는 경우

경고는 하나의 자연스러운 출현을 잡지 않고 파일 집합 전체의 횟수와 밀도가 함께 임계값을 넘을 때만 낸다.

- 피동·관공서체·명사화·번역투 연결 표현의 군집
- `설명`, `확인`, `정리`, `차분히`, `결과로 답/보여/증명`, `다음` 계열 상투어 밀도
- 선택지 제목과 상세의 높은 유사도
- 문장 종결형의 과도한 통일
- 반복 3어절과 변수·수치를 걷어 낸 템플릿 뼈대
- 88자를 넘는 단일 화면 문자열

기본 임계값과 예외는 `tools/korean-copy.config.json`에 있다. 예외에는 `ruleId`, 파일, 안정적인 포함 문자열, 사람이 검토한 이유가 모두 있어야 한다. 임계값을 낮춰 현재 카탈로그를 억지로 실패시키거나, 넓은 파일 단위 예외를 추가하지 않는다. 경고를 해소할 때는 실제 장면, 화자, 선택의 비용을 읽고 손으로 고친다.

실존 IP 규칙은 새 도구에 복제하지 않는다. 보수적인 정확 일치 목록이 이미 있는 `tools/check-copy.mjs`를 단일 원본으로 유지한다. 플레이어 노출 콘텐츠를 수정하면 두 검사를 모두 실행해야 한다.

## 블라인드 A/B 평가

정적 검사는 자연스러움을 증명하지 못한다. 대표 관계·훈련 문구는 최소 12쌍, 서로 다른 평가자 최소 5명으로 블라인드 평가한다. 모든 평가자는 모든 항목을 완주해야 한다. 평가 패킷에는 A/B만 있고 원문·개작 표시는 별도 키 파일에만 있다.

저장소에 준비된 실제 평가 재료:

- 원문/개작 입력: `docs/content-evaluation/korean-copy-relationship-training-12-pairs.json`
- 평가자용 블라인드 패킷: `docs/content-evaluation/korean-copy-relationship-training-12-packet.json`
- 보관자용 키: `docs/content-evaluation/korean-copy-relationship-training-12-key.json`

12쌍은 `cdcfad2`의 공통 카테고리 폴백·일반 훈련 피드백을 기준으로, `5868c63`의 사건별 관계 선택지 및 현재 작업 트리의 포커스별 훈련 피드백과 짝지었다. 관계 선택지 8쌍과 구위 성장, 변화구 성장, 제구 무성장, 회복 피드백 4쌍이다. 키는 평가자에게 공유하지 않는다. 저장소에는 이 평가의 실제 응답을 넣지 않았으며 결과를 주장하지 않는다.

새 패킷을 준비한다.

```sh
node tools/evaluate-korean-copy.mjs prepare pairs.json \
  --output packet.json \
  --key key.json \
  --seed review-2026-08
```

같은 입력과 시드는 A/B 배치와 항목 순서가 항상 같다. 입력은 다음 형태이며 `items`가 최소 12개여야 한다.

```json
{
  "name": "평가 이름",
  "items": [
    {
      "id": "고유-id",
      "context": "문구가 보이는 장면",
      "original": "기존 문구",
      "rewrite": "개작 문구"
    }
  ]
}
```

응답 JSON은 아래처럼 모은다. CSV도 같은 열 이름을 지원한다. `evaluatorId`는 익명 식별자이며 한 평가자·한 항목의 중복 행은 거부한다.

```json
{
  "responses": [
    {
      "evaluatorId": "reviewer-01",
      "itemId": "고유-id",
      "preference": "A",
      "aiLikeA": 1,
      "aiLikeB": 4,
      "readabilityA": 5,
      "readabilityB": 3
    }
  ]
}
```

```sh
node tools/evaluate-korean-copy.mjs score \
  --key key.json \
  --responses responses.json

node tools/evaluate-korean-copy.mjs score \
  --key key.json \
  --responses responses.csv \
  --json
```

합격 기준은 전체 유효 응답 중 개작 선호율 80% 이상, 개작 AI 느낌 중앙값 2 이하, 개작 가독성 중앙값 4 이상을 모두 만족하는 것이다. 동률은 유효 응답이지만 개작 승리로 세지 않으므로 선호율 분모에 남는다. 결과는 전체와 항목별 선호율, 동률, 원문·개작 AI 느낌/가독성 중앙값, 두 중앙값의 변화량을 함께 낸다.

`tools/tests/korean-copy.test.mjs`가 만드는 응답은 파서와 계산식을 검증하는 명시적인 합성 데이터일 뿐 사용자 조사 결과가 아니다. 합성 응답을 출시 근거로 인용하거나 실제 응답 다섯 명을 만들어 채우지 않는다.

## 근거와 한계

- [epoko77-ai/im-not-ai](https://github.com/epoko77-ai/im-not-ai)의 한국어 번역투·피동·명사화 관찰을 첫 후보군으로 참고했다. 이 프로젝트는 게임 대사 판별기나 진위 탐지기가 아니므로 단일 단어를 금지하지 않고 밀도 경고에만 쓴다.
- [conorbronsdon/avoid-ai-writing](https://github.com/conorbronsdon/avoid-ai-writing)의 단계별 신호, 문맥별 허용, 군집·구조 반복 관점을 참고했다. 영어용 규칙을 한국어에 그대로 옮기지 않았고, 이 게임의 선택지 쌍과 화면 예산에 맞췄다.
- 탐지기 우회나 “사람처럼 보이게 만들기” 도구는 사용하지 않는다. 목표는 출처를 숨기는 것이 아니라 화자의 목소리, 선택의 차이, 읽기 리듬을 높이는 것이다.
- 정규식은 아이러니, 인용, 캐릭터의 의도적 격식, 실제 화면 줄바꿈을 완전히 이해하지 못한다. 그래서 오류 범위를 좁히고, 경고는 사람 검토와 블라인드 평가로 확인한다.
- 외부 게임 대사를 자연스러움 말뭉치로 복사하지 않는다. [Korpora](https://github.com/ko-nlp/Korpora)는 코퍼스마다 별도 라이선스 정책을 따르므로, 향후 통계 기준에 텍스트를 사용하려면 각 원천의 상업 이용·재배포·파생물 조건을 먼저 검토해야 한다. 허용되더라도 문장을 제품 대사로 가져오지 않는다.
