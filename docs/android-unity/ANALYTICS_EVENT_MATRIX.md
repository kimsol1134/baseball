# Android Unity 분석 이벤트 계약

기준 소스는 iOS `GameAnalytics.swift`와 각 실제 caller다. Android는 모든 속성을
`AnalyticsPrivacyGuard`로 검사하고, 저장형 이벤트는 `MarkAnalyticsReceiptCommand` 성공 뒤에만
`AnalyticsBootstrap.Log`의 128개 startup FIFO에 넣는다. 표의 속성 외에는 SDK 공통 빌드 컨텍스트만
붙는다. 사용자 이름, 커리어 ID, 구단·학교 자유 문자열은 보내지 않는다.

| 이벤트 | Android 발화점 | 이벤트 속성 | 반복/영수증 |
|---|---|---|---|
| `onboarding_started` | 선수 만들기 진입 저장 성공 | 없음 | install lifetime once |
| `onboarding_completed` | 비도전 고교 선수가 실제 생성·저장됨 | 없음 | install lifetime once |
| `first_pitch` | 첫 불펜 전체 세션 완료 저장 성공 | 없음 | install lifetime once |
| `activation_first_game` | 첫 고교/프로 중요 경기 완료 저장 성공 | 없음 | install lifetime once |
| `game_finished` | 비튜토리얼 고교·프로 투구 세션 완료 저장 성공 | 공통 `mode,sequence_mastery_count,sequence_tags,recommendation_acceptance_rate,development_rules_version,ability_moment_count,ability_moment_types`; 고교 `life_number,act_number,result,strikeouts,walks,runs,target_batters,batters`; 프로 `result,strikeouts,walks,runs` | game ID scoped once |
| `chapter_advanced` | 고교 장 전진 저장 성공 | `chapter,act_number` | career/chapter scoped once |
| `draft_resolved` | 드래프트 결과 저장 성공 | `drafted,score,life_number,act_number` | career scoped once |
| `rebirth_started` | 2회차 이상 비도전 고교 선수 생성 저장 성공 | `life_number,entry_point,selected_legacy_id,inheritance_rules_version,soul_total,soul_wallet,soul_lifetime_earned,soul_applied` | life scoped once |
| `life_card_shared` | 미발화(EX-009) | `life_number` | Android chooser는 실제 전달 완료를 증명하지 못함 |
| `life_card_share_tapped` | PNG 또는 텍스트 chooser가 실제 열린 직후 | `life_number` | chooser open마다 |
| `life_card_share_completed` | 미발화(EX-009) | `life_number` | target chosen/전달 완료 callback 부재 |
| `run_pledge_selected` | 약속 선택 또는 건너뛰기 저장 성공 | `pledge_id,tier,life_number,recommended` | career scoped once |
| `run_pledge_resolved` | 회차 유산 원자 정산 저장 성공 | `pledge_id,achieved,progress_ratio,reward_permille` | career scoped once |
| `career_wind_seen` | 실제 바람 카드가 프롤로그/고교 개요에 노출 | `wind_id,rules_version` | career scoped once |
| `next_run_intent_saved` | 다음 회차 목표 저장 성공 | `pledge_id,source_life_number` | career scoped once |
| `next_run_intent_applied` | 저장 목표와 같은 약속이 새 회차에 적용 저장됨 | `pledge_id,life_number` | career scoped once |
| `weekly_program_opened` | 실제 주간 화면 노출 | `week_key,source,completed_tasks` (`source=records`) | 화면 노출마다 |
| `weekly_program_completed` | 2/3 이상 주간 보상 claim 저장 성공 | `week_key,completed_tasks,perfect` | week scoped once |
| `pro_season_decision_selected` | 3주 결정 payload 저장 성공 | `decision_id,choice_id,season,week` | season scoped once |
| `pro_legacy_recorded` | 프로 은퇴 기록이 유산에 저장됨 | `life_number,pro_seasons,soul_bonus,has_signature_candidates` | career scoped once |
| `player_legacy_seen` | 결산·기록 또는 비도전 다음 회차 프롤로그의 실제 저장형 선수 편지 노출 | `source,life_number,drafted,has_frozen_legacy` (`source=recap/archive/next_life`) | life/source scoped once; Opening·도전 회차·동일 회차는 미발화 |
| `player_heartline_seen` | 실제 속마음 카드 노출 | `branch_id,life_number,phase` | career/branch scoped once |
| `recap_continue_tapped` | 결산에서 다음 선수 시작 저장 성공 | `life_number,drafted,entry_path,has_suggested_intent,intent_saved` | career scoped once |
| `signature_legacy_options_seen` | 실제 대표 유산 후보 카드 노출 | `life_number,drafted,includes_pro_career,option_ids` | career scoped once |
| `signature_legacy_selected` | 선택 유산이 회차 정산에 저장됨 | `legacy_id,family,life_number,drafted,rating_growth,includes_pro_career,pro_seasons` | career scoped once |
| `signature_legacy_equipped` | 새 선수 생성 시 유산 효과가 실제 적용·저장됨 | `legacy_id,family,life_number,total_rating_bonus,inheritance_rules_version,soul_total,soul_wallet,soul_lifetime_earned,soul_applied` | life scoped once |
| `life_completed` | 기억·유산·야구혼 원자 정산 저장 성공 | `life_number,act_number,drafted,evaluation,trainings,important_games,pitches,legacy_id,legacy_rules_version,unlocked_legacy_count,inheritance_rules_version,soul_total,soul_wallet,soul_lifetime_earned,soul_applied` | career scoped once |
| `career_training_completed` | 단일 훈련 또는 연속 훈련의 각 session 저장 성공 | `life_number,act_number,focus_id,intensity_id,target_pitch_id,growth_points,fatigue_delta` | training number scoped once |
| `game_growth_applied` | 중요 경기 결과가 실제 능력 성장으로 저장됨 | `life_number,act_number,reason_id,growth_focus,growth_points` | game scoped once |
| `phase_entered` | 비도전 고교의 실제 command/pitch/settlement가 phase 또는 chapter 진입을 저장 | `phase,chapter,act_number,life_number` | 저장 transition revision scope; 초기 Prologue 생성·단순 publish 제외, 같은 phase의 다음 chapter 재진입 허용 |
| `game_abandoned` | 진행 중 고교 중요 투구 포기 저장 성공 | `pitches,chapter,life_number,act_number,phase,development_rules_version,games_completed` | game scoped once |
| `daily_inning_opened` | retired schema, 제품 caller 없음 | 발화 없음 | 재도입 설계 승인 전 0건 |
| `daily_inning_rewarded` | retired schema, 제품 caller 없음 | 발화 없음 | 재도입 설계 승인 전 0건 |
| `pro_career_started` | 드래프트 계약 서명 또는 direct pro 생성 저장 성공 | `round,evaluation,life_number,source` | career scoped once |
| `reminder_changed` | 사용자 선택·OS 권한 결과 또는 재개 시 외부 권한 철회를 aggregate에 저장한 뒤 실제 설정이 확정됨 | `enabled,source` | 권한 결과/변경마다; busy 중 correction은 idle까지 대기 |
| `reminder_offer_shown` | 첫 공식 경기 뒤 고교 개요의 실제 알림 권유 카드 노출 | `source` (`after_first_game`) | install lifetime once |
| `reminder_opened` | 허용 목록 Android notification intent의 분석 영수증 저장 성공 | `destination,reason,plan_receipt,experiment_id,variant,saved_day_key,development_rules_version` | 안정 token hash의 분석 영수증마다 1회. 실제 route 소비 뒤 별도 navigation-completed 영수증을 저장하며, 분석 저장 직후 종료 시 SDK 중복 없이 route만 복구하고 완료 영수증이 있으면 로그·재이동 모두 억제 |
| `return_plan_shown` | guided 복귀 카드 실제 노출 | `destination,reason,plan_receipt,experiment_id,variant,saved_day_key,return_day_key,day_gap,development_rules_version` | plan/day scoped once |
| `return_plan_tapped` | guided CTA interaction 저장 성공 | 위 return-plan 9개 | plan/day scoped once |
| `return_plan_dismissed` | guided dismiss interaction 저장 성공 | 위 return-plan 9개 | plan/day scoped once |
| `return_plan_eligible` | pause의 최신 plan과 eligible receipt 원자 저장 성공 | `destination,reason,plan_receipt,experiment_id,variant,saved_day_key,return_day_key,day_gap,development_rules_version` | Bootstrap durable receipt가 Applied일 때만 |
| `return_plan_cold_start` | 저장 다음 서울 날짜 cold 활성화 영수증 성공 | return-plan 9개 + `launch_type=cold` | experiment/receipt/day scoped once |
| `return_plan_next_day_open` | 저장 다음 서울 날짜 cold/warm 활성화 영수증 성공 | return-plan 9개 + `launch_type` | cold/warm 공통 day scope once |
| `session_ended` | Bootstrap이 pause 저장을 끝낸 `SessionEndPrepared` | `minutes,life_number,games,important_games_total,phase,act_number,lives_finished,return_eligible,return_destination,return_reason,plan_receipt,experiment_id,variant,development_rules_version` | 성공한 running→paused마다 |

## Android 예외

- EX-009: `ACTION_SEND image/png` chooser를 연 사실만 `life_card_share_tapped`로 센다. 현재
  Android API는 실제 전달 완료를 과장 없이 확인할 수 없으므로 `life_card_shared`와
  `life_card_share_completed`는 의도적으로 0 caller다. PNG와 한국어 공유 문구는 같은 intent의
  `EXTRA_STREAM`/`EXTRA_TEXT`로 전달한다.
- `daily_inning_opened`와 `daily_inning_rewarded`는 과거 분석 스키마 해석을 위해 enum 이름만
  보존한다. 현행 제품에서는 두 이벤트 모두 production caller가 0개여야 한다.
- `game_finished`의 ability moment는 각 pitch commit의 call/context/outcome/execution을 Application이
  Core 규칙으로 재검산한 뒤 공 단위 durable metrics에 누적한다. Presentation은 이 report의 실제
  count와 정렬된 wire type만 전송하며 별도 상수를 합성하지 않는다.
