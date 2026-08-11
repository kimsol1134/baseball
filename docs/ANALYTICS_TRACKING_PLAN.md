# 분석 이벤트 추적 계획

모든 이벤트에는 `app_version`, `build`, `distribution`, `environment`, `platform=ios`가 자동으로 붙는다. `distribution=app_store`, `environment=production`만 정식 코호트로 집계한다. 이름, 자유 입력 문구, 원시 시드, `careerID`는 보내지 않는다. Amplitude SDK 직행 payload에는 `ingestion_origin=ios_sdk_direct`, `event_schema_version=2`를 추가하고 Firebase payload에는 추가하지 않는다. Firebase의 기존 공통 속성은 그대로 유지한다.

| 이벤트 | 소유 화면/로직 | 필수 속성 | 의미 |
|---|---|---|---|
| `game_finished` | 고교·프로 스토어, 오늘의 이닝 | `mode`, `result`, `development_rules_version`; 고교는 `life_number`, `act_number`, `target_batters`, `batters` | 실제 경기 완료 |
| `game_abandoned` | 고교 중요 경기 스토어 | `pitches`, `chapter`, `life_number`, `act_number`, `phase`, `development_rules_version`, `games_completed` | 저장에 성공한 뒤 사용자가 진행 중인 공식 경기를 포기한 시점 |
| `life_card_share_tapped` | 공통 공유 버튼 | `life_number` | 시스템 공유 UI 열기 |
| `life_card_share_completed` | 공통 공유 완료 콜백 | `life_number` | 취소·오류 없는 공유 완료 |
| `life_card_shared` | 공통 공유 버튼 | `life_number` | 1.0.2 호환용 탭 이벤트. 다음 스키마 버전에서 폐기 |
| `run_pledge_selected` | 고교 커리어 스토어 | `pledge_id`, `tier`, `life_number`, `recommended` | 고교 3년 목표 선택 |
| `run_pledge_resolved` | 고교 회차 정산 | `pledge_id`, `achieved`, `progress_ratio`(Double, 0...1), `reward_permille`(Int, 0...350) | 약속 결과 확정 |
| `career_wind_seen` | 고교 프롤로그 | `wind_id`, `rules_version` | 바람 카드 최초 실제 노출 |
| `next_run_intent_saved` | 회차 정산 | `pledge_id`, `source_life_number` | 다음 회차 목표 저장 |
| `next_run_intent_applied` | 약속 선택 | `pledge_id`, `life_number` | 저장 목표 재도전 |
| `weekly_program_opened` | 주간 야구 노트 | `week_key`, `source` | 주간 상세 진입 |
| `weekly_program_completed` | 주간 프로그램 스토어 | `week_key`, `completed_tasks` | 2/3 완료 및 보상 확정 |
| `pro_season_decision_selected` | 프로 시즌 결정 | `decision_id`, `choice_id`, `season`, `week` | 3주 단위 결정 확정 |
| `pro_legacy_recorded` | 프로 은퇴 → 대표 유산 선택 | `life_number`, `pro_seasons`, `soul_bonus`, `has_signature_candidates` | 프로 원본을 지우기 전에 통산 기록·야구혼·대표 유산 후보가 고교 저장에 원자적으로 기록된 시점 |
| `player_heartline_seen` | 고교 커리어의 실제 갈림길·건강 경고 | `branch_id`, `life_number`, `phase` | 첫 공식 경기 뒤 의미 있는 속마음 카드가 실제로 보인 시점. 커리어·회차·branch별 1회 |
| `player_legacy_seen` | 3년 돌아보기·선수 기록·다음 선수 프롤로그 | `source`(`recap`/`archive`/`next_life`), `life_number`, `drafted`, `has_frozen_legacy` | 끝난 선수의 편지가 실제로 보인 시점. recap은 인용문 reveal 뒤, archive는 펼친 인용문 표시 뒤에 화면·회차별 1회 |
| `recap_continue_tapped` | 고교 3년 돌아보기 하단 행동 | `life_number`, `drafted`, `entry_path`(`quick_rebirth`/`completion_flow`/`customize`), `has_suggested_intent`, `intent_saved` | 정산을 본 뒤 다음 선수 동선으로 나간 시점 |
| `pro_career_started` | 고교 완료 → 프로 생성 | `round`, `evaluation`, `life_number`, `source=high_school_draft` | 프로 저장 상태가 실제로 새로 생성되어 ready가 된 시점. 생성 시도·실패는 제외 |
| `signature_legacy_options_seen` | 고교 3년 또는 프로 은퇴 결산 | `life_number`, `drafted`, `includes_pro_career`, 정렬·중복 제거한 `option_ids` | 실제 성장·경기 기록으로 합성된 대표 유산 세 후보 카드가 화면에 들어온 시점 |
| `signature_legacy_selected` | 선수 정산 | `legacy_id`, `family`, `life_number`, `drafted`, `rating_growth`, `includes_pro_career`, `pro_seasons` | 후보 하나를 확정하고 아카이브·계승에 원자적으로 저장한 시점 |
| `signature_legacy_equipped` | 새 선수 생성 | `legacy_id`, `family`, `life_number`, `total_rating_bonus`, `inheritance_rules_version`, `soul_total`, `soul_wallet`, `soul_lifetime_earned`, `soul_applied` | 발견 목록에서 고른 대표 유산과 야구혼이 새 선수의 시작 능력에 실제 적용된 시점 |
| `rebirth_started` | 새 선수 생성 | `life_number`, `entry_point`, `selected_legacy_id`, `inheritance_rules_version`, `soul_total`, `soul_wallet`, `soul_lifetime_earned`, `soul_applied` | 이전 선수의 유산을 들고 다음 선수의 저장이 실제로 완료된 시점 |
| `life_completed` | 고교 선수 정산 | `life_number`, `act_number`, `drafted`, `evaluation`, `trainings`, `important_games`, `pitches`, `legacy_id`, `legacy_rules_version`, `unlocked_legacy_count`, `inheritance_rules_version`, `soul_total`, `soul_wallet`, `soul_lifetime_earned`, `soul_applied` | 기억·대표 유산·야구혼·아카이브 정산이 로컬 원본에 모두 저장돼 한 선수의 이야기가 닫힌 시점 |
| `career_training_completed` | 고교 훈련 확정 | `life_number`, `act_number`, `focus_id`, `intensity_id`, `growth_points`, `fatigue_delta` | 사용자가 고른 훈련이 상태에 실제 반영된 시점 |
| `game_growth_applied` | 고교 공식 경기 확정 | `life_number`, `act_number`, `reason_id`, `growth_focus`, `growth_points` | 직접 던진 과정이 능력치 성장으로 실제 반영된 시점 |
| `reminder_offer_shown` | 첫 공식 경기 뒤 알림 권유 카드 | `source=after_first_game` | 알림 허용률의 실제 노출 분모. 사용자당 최초 1회 |
| `reminder_changed` | 알림 권유·오늘의 이닝·설정 | `enabled`, `source` | 알림 허용·거절·해제 결과. 권한 요청 시도와 허용을 분리 |
| `reminder_opened` | 알림 응답 라우터 | `destination`, `reason`, `plan_receipt`, `experiment_id`, `variant`, `saved_day_key`, `development_rules_version` | 알림을 눌러 약속한 화면으로 돌아온 시점 |
| `return_plan_eligible` | 실제 경기 완료 뒤 세션 종료 | `destination`, `reason`, `plan_receipt`, `experiment_id`, `variant`, `saved_day_key`, `return_day_key`, `development_rules_version` | `completedGameCount > 0`인 활성 사용자만 다음 행동과 `next_action_v2` 대조군·개인화군을 고정한 실험 분모. 동일 영수증 1회 |
| `return_plan_next_day_open` | 다음 KST 날짜 cold 시작·warm 재활성화 | `destination`, `reason`, `plan_receipt`, `experiment_id`, `variant`, `saved_day_key`, `return_day_key`, `day_gap`, `launch_type`(`cold`/`warm`), `development_rules_version` | 저장 계획 뒤 실제 다음 날짜에 앱이 열린 복귀. `experiment_id|plan_receipt|return_day_key`로 cold/warm 중복 제거 |
| `return_plan_cold_start` | 다음 KST 날짜 cold 시작 | 위 `return_plan_next_day_open`과 동일(단 `launch_type=cold`) | 기존 소비자 호환용 cold-only 이벤트. 새 D1 KPI에는 포함하지 않는다 |
| `return_plan_shown` | 앱 복귀 상단 카드 | `destination`, `reason`, `plan_receipt`, `experiment_id`, `variant`, `saved_day_key`, `return_day_key`, `day_gap`, `development_rules_version` | 개인화군에서만 보조 카드가 실제 노출된 시점 |
| `return_plan_tapped` | 앱 복귀 상단 카드 | 위와 동일 | 카드에서 문구와 일치하는 고교·프로·오늘의 이닝 화면으로 이동한 시점 |
| `return_plan_dismissed` | 앱 복귀 상단 카드 | 위와 동일 | 카드를 닫은 시점. 반복 노출 피로의 가드레일 |
| `session_ended` | 앱 백그라운드 전환 | `minutes`, `life_number`, `games`, `important_games_total`, `act_number`, `lives_finished`, `return_eligible`, `return_destination`, `return_reason`, `plan_receipt`, `experiment_id`, `variant`, `development_rules_version` | `games`는 이번 세션에서 실제 완료한 고교·프로·일일 경기 수이고, 고교 회차 누적은 `important_games_total`로 분리. 첫 실제 경기 전에는 `return_eligible=false`, `experiment_id=none`, `variant=ineligible`이며 새 계획을 만들지 않는다 |

야구혼 속성에서 `soul_total`은 이번 선수 능력에 스며들 수 있는 자동 누적, `soul_wallet`은 구매 뒤 남은 지갑, `soul_lifetime_earned`는 프로 보상을 포함한 평생 획득량이다. 프로 보상은 지갑과 평생 획득량만 올리고 자동 누적에는 더하지 않는다.

`game_finished`에는 `sequence_mastery_count`, 정렬된 고유 `sequence_tags`(최대 6개), `recommendation_acceptance_rate`(Double, 0...1), `ability_moment_count`, 정렬된 고유 `ability_moment_types`가 들어간다. `ability_moment_types`는 `power`, `command`, `movement` 중 실제 커널 입력과 성공 결과가 함께 성립한 종류만 싣고, 볼·안타·파울에는 기록하지 않는다. 체력은 한 공의 결과 원인이 아니라 고교 경기 뒤 누적 피로 계산에 쓰이므로 투구 순간 유형으로 보내지 않는다. 고교·프로·오늘의 이닝은 모두 `PitchSession.gameFinishedAnalyticsMetrics`를 사용한다. 이벤트 소유자는 각 기능 스토어이며, 스키마 변경 검토 소유자는 iOS 클라이언트 담당자다. `weekly_program_opened`는 기록 탭의 상세가 실제로 나타날 때마다 기록하며 주 단위로 영구 중복 제거하지 않는다.

복귀 계획의 `destination`/`return_destination`은 `daily_inning`, `high_school`, `pro` 중 하나다. `reason`/`return_reason`은 `daily_inning`, `run_pledge`, `high_school_phase`, `next_run_intent`, `pro_phase` 중 하나이며, 업데이트 전 저장 계획은 `experiment_id=next_action_v1`로 호환한다. 새 저장 계획은 `experiment_id=next_action_v2`이며 ID와 안정 ID를 함께 해시해 `holdout`/`guided`를 고정한다. 선수명·목표 자유 문구는 분석으로 보내지 않는다.

복귀 효과는 `return_plan_eligible`의 안정 식별자·동일 `development_rules_version`을 분모로, `holdout`과 `guided`의 **다음 KST 날짜** `return_plan_next_day_open`(cold/warm) 및 그 뒤 같은 세션 `game_finished`를 비교한다. `return_plan_cold_start`는 기존 소비자 호환용 cold-only 보조 이벤트라 새 D1 인과 KPI에서 제외한다. `return_plan_shown/tapped/dismissed`는 이미 앱을 연 개인화군의 탐색 지표이므로 D1 인과 KPI가 아니다. 기존 13.9% 기준선은 24시간 구간 관측이라 이 KST 정의와 직접 비교하지 않고 새 계측으로 기준선을 다시 만든다.
