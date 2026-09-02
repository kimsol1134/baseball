# 1.2.8 릴리스 노트

리뷰 41건 분석(2026-09-02)에 대한 응답 릴리스. 대상 리뷰: 프로 데뷔 후 휴식·훈련 반복 ~10건, 보직을 직접 고르고 싶다 2건, 용어·설명이 길다 3건, 8/29 3★(핀트·글자·용어·콘텐츠). 1.2.7 심사·출시와 별도로 준비한다. App Store `whatsNew`는 아래 ko/en/ja 본문만 올린다.

## whatsNew (ko)

이번 업데이트는 리뷰로 보내주신 의견에 대한 응답입니다.

- 프로 시즌에 3주마다 결정을 고르고, 3주 뒤에 결과 카드로 그 선택이 어떻게 돌아왔는지 확인할 수 있습니다.
- 스프링캠프에서 선발·중간·마무리 보직을 직접 지원할 수 있습니다.
- 낯선 야구 용어를 눌러 설명을 볼 수 있고, 선택지마다 효과 요약이 한 줄로 먼저 보입니다.
- 등판 간격, 2군 재정비, 신구종 실전, 베테랑 조언 네 가지 결정이 더해집니다.
- 안정성을 개선했습니다.

## whatsNew (en)

This update is a response to the reviews you sent us.

- In a professional season you make a choice every three weeks, then see how it landed on a result card three weeks later.
- At spring camp you can request a starter, middle-relief, or closer role.
- Tap an unfamiliar baseball term for a short explanation, and every choice now leads with a one-line summary of its effect.
- Four new decisions: tighten the outing gap, retool with the farm club, take a new pitch into games, or take a veteran's advice.
- Stability improvements.

## whatsNew (ja)

今回のアップデートは、いただいたレビューへの返答です。

- プロのシーズンでは3週ごとに判断を選び、3週後に結果カードでその選択がどう返ってきたかを確認できます。
- 春季キャンプで先発・中継ぎ・抑えの役割に手を挙げられます。
- なじみのない野球用語をタップすると説明が見られ、選択肢ごとに効果の要約が先に一行で表示されます。
- 登板間隔、二軍での立て直し、新しい球種の実戦投入、ベテランの助言という4つの判断が加わります。
- 安定性を改善しました。

## 로케일·금지어

영문 whatsNew는 `en-US`, `en-GB`, `en-AU`, `en-CA`에 동일하게 올린다. 일본어 문안은 `tools/check-ios-localization.mjs`의 `japaneseForbiddenPattern`에 걸리는 실존 기구·구단·금지 표현을 쓰지 않는다.

## 내부 변경 요약

검증된 항목은 보고서에 근거하고, 전용 보고서가 없는 항목은 **구현 중**으로 표시한다. 스토어 문안은 1.2.8이 그 기능을 실은 채 제출된다는 전제다. E2E 보고서가 녹색이 아니면 해당 줄을 빼거나 제출을 미룬다.

- 프로 주간 결정 훅 (`docs/PRO_WEEKLY_DECISION_HOOK_REPORT_2026-09-02.md`): `proRulesVersion` 9. 결정 주 3·6·9·12·15·18·21, 시즌 최대 7회. 선택 즉시 효과 + 3주 뒤 후속 결과 카드. v8 이하는 6·13·20주·최대 3회 유지. `planWeek` RNG 스트림에 `next*()` 추가 없음. 스키마 버전 5 유지.
- 신규 결정 4종: `rotationPush`(등판 간격), `farmReset`(2군 재정비), `newPitchTrial`(신구종 실전), `veteranMentor`(베테랑 조언). 등판 +1은 3주 창에서 선발 1경기만 증가.
- 보직 지원 (`docs/PRO_ROLE_REQUEST_AND_GLOSSARY_SPEC_2026-09-02.md`): 스프링캠프에서 선발/중간/마무리를 1회 지원. 코어 `ProRoleRequestRules`는 워킹트리에 있다. 전용 보고서 `PRO_ROLE_REQUEST_AND_GLOSSARY_REPORT_2026-09-02.md`는 없음 — **구현 중 / 미검증**.
- 용어 설명·효과 요약 한 줄: 같은 스펙. `GlossaryCatalog`·`content.glossary.*` 전용 보고 없음 — **구현 중 / 미검증**.
- 릴리스 게이트 정리 (`docs/RELEASE_GATE_CLEANUP_1_2_8_REPORT_2026-09-02.md`): 테스트 크래시(xctest 시그널 10, `PitcherLabEvent` 박스), 레이어 경계, 현지화 표시 경로, 문구 주석, JSON 키 순서. 게이트 원문 전부 종료 코드 0.
- 시뮬레이터 E2E (`docs/SIMULATOR_E2E_1_2_8_SPEC_2026-09-02.md`): 보고서 `SIMULATOR_E2E_1_2_8_REPORT_2026-09-02.md` 미작성 — **구현 중**. 제출 전 녹색 확인이 필수.

## 미룬 항목 (다음 릴리스 후보)

- FA 계약금·5년 이상 장기계약 (검증기·와이어 포맷 연쇄 수정 필요)
- 협상 오프시즌에도 투자 가능하게
- 안드로이드 프로 패리티(climate/콜 정책 포팅)
- 보직 지원·용어 카드의 전용 수용 보고서와 E2E 보고서 (제출 전 닫을 것)
