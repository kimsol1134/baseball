# 기질 특성 설계 (2026-07-30, 구현 진행 중)

성격(A4)이 곧 발동 조건인 공개 특성. 가챠 없음, 발동 시 화면 배지(숨은 조작 금지).

## 매핑 (성격 → 특성, 발동 조건은 전부 커널이 이미 아는 값)
| 성격 | 특성 이름 | 발동 조건 | 효과(계획) |
|---|---|---|---|
| 불같은 승부사 | 결정구 | strikes == 2 | contact −14, quality +12 (투수 유리) |
| 조용한 버팀목 | 위기의 어깨 | 주자 있음(gameState.runners 비어있지 않음) | contact −12, quality +10 |
| 차가운 분석가 | 수싸움 | 같은 타석 5구째부터(context.pitchNumber ≥ 5) | contact −16, quality +12 |
| 유연한 중심 | 초구 장악 | 타석 첫 구(pitchNumber == 1) | contact −10, quality +10 |

효과 스케일 근거: 스카우팅 보정이 −36..+32 (절반으로 줄인 뒤 밴드 통과한 값).
특성은 그보다 작게 시작(±10~16) → CLI 측정 → check-balance 26 불변식 통과 확인.

## 구현 계획
1. 커널: `PersonalityTrait` enum(4종, id/이름/발동조건/효과) — SubmitPitchParams에
   `traitID: String?` **옵셔널**(init 기본값 nil, 커밋 해시 미포함!) → resolvePitch에서
   조건 검사 후 보정 가산. traitID nil이면 완전 동일 동작(골든 픽스처 불변).
2. 발동 여부를 PlateAppearanceSnapshot에 옵셔널 필드 `traitFired: String?`로 노출
   (커밋 해시 미포함, decodeIfPresent) → UI 배지.
3. PitchSession: HighSchoolCareerStore.personality → trait 결정 → SubmitPitchParams에 전달.
   프로(MobileCareerStore)는 v1 제외(고교 성격만; 프로 이관은 후속).
4. UI: PitchView 판정 카드에 "『결정구』 발동" 배지(BaseballTheme.milestone).
5. 검증: 커널 유닛(조건별 발동/미발동, nil 동작 불변) + 전체 코어(픽스처) +
   CLI 균형 측정(tools/check-balance.mjs 통과 필수, 필요시 효과 축소) + iOS 테스트.

## 주의
- 야구혼 캡 불변, 새 커널 난수 없음(보정은 결정 항), 저장 필드 전부 옵셔널.
- sim-cli에 trait 플래그 추가해 A/B 측정 (--trait closer 등).

## 진행 체크리스트 (2026-07-30 오전)
- [x] PersonalityTrait.swift (4종·발동조건·보정치·발동문구)
- [x] Personality.trait 연결 (PersonalityRules 4개 생성자)
- [x] SubmitPitchParams.trait 옵셔널(`var trait: PersonalityTrait? = nil` — 기존 init 불변)
- [x] resolvePitch 훅: traitContact/traitQuality를 scoutingContact/Quality 합산에 가산
- [x] PitchSession: `var trait` + 제출 시 `params.trait` 설정(var 바인딩으로 구성 후 대입)
      + `lastTraitFired` 계산(fires()를 같은 입력으로 UI가 재평가 — 커널 스냅샷 변경 불필요!)
- [x] 스토어: beginImportantGame에서 session.trait = personality?.trait (고교만, 프로 v1 제외)
- [x] PitchView 판정 카드에 발동 배지("『결정구』 발동") — milestone 톤
- [x] 기록 탭 성격 카드에 특성 소개 줄(trait.title + activationLine)
- [x] 커널 테스트: nil 동작 불변(같은 시드 결과 동일)·조건별 발동·보정 방향
- [x] 전체 코어 스위트(225/225, 픽스처 불변 확인)(골든 픽스처 218+) — trait nil 경로 불변 확인
- [x] check-balance 통과 확인(특성은 세션 밖 CLI에 없음 → 밴드 영향 없음이 기대,
      실제 영향은 고교 세션에만 존재. sim-cli --trait 플래그는 후속으로)
- [ ] 커밋 → 전체 iOS 테스트 → 빌드 12 업로드+노트

## 현재 상태
- ④①② 완료 커밋: 433f9fa(세계 뉴스), 83d11be(가상 지명), 8709076(대진표).
- ③은 이 문서 기준으로 구현 시작.
