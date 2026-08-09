# 분석 이벤트 추적 계획

모든 이벤트에는 `app_version`, `build`, `distribution`, `environment`, `platform=ios`가 자동으로 붙는다. `distribution=app_store`, `environment=production`만 정식 코호트로 집계한다. 이름, 자유 입력 문구, 원시 시드, `careerID`는 보내지 않는다.

| 이벤트 | 소유 화면/로직 | 필수 속성 | 의미 |
|---|---|---|---|
| `game_finished` | 고교·프로 스토어, 오늘의 이닝 | `mode`, `result`; 고교는 `life_number` | 실제 경기 완료 |
| `life_card_share_tapped` | 공통 공유 버튼 | `life_number` | 시스템 공유 UI 열기 |
| `life_card_share_completed` | 공통 공유 완료 콜백 | `life_number` | 취소·오류 없는 공유 완료 |
| `life_card_shared` | 공통 공유 버튼 | `life_number` | 1.0.2 호환용 탭 이벤트. 다음 스키마 버전에서 폐기 |
| `run_pledge_selected` | 고교 커리어 스토어 | `pledge_id`, `tier`, `life_number`, `recommended` | 회차 약속 선택 |
| `run_pledge_resolved` | 고교 회차 정산 | `pledge_id`, `achieved`, `progress_ratio`, `reward_permille` | 약속 결과 확정 |
| `career_wind_seen` | 고교 프롤로그 | `wind_id`, `rules_version` | 바람 카드 최초 실제 노출 |
| `next_run_intent_saved` | 회차 정산 | `pledge_id`, `source_life_number` | 다음 회차 목표 저장 |
| `next_run_intent_applied` | 약속 선택 | `pledge_id`, `life_number` | 저장 목표 재도전 |
| `weekly_program_opened` | 주간 야구 노트 | `week_key`, `source` | 주간 상세 진입 |
| `weekly_program_completed` | 주간 프로그램 스토어 | `week_key`, `completed_tasks` | 2/3 완료 및 보상 확정 |
| `pro_season_decision_selected` | 프로 시즌 결정 | `decision_id`, `choice_id`, `season`, `week` | 3주 단위 결정 확정 |

`game_finished`에는 웨이브 3부터 `sequence_mastery_count`, 정렬된 고유 `sequence_tags`(최대 6개), `recommendation_acceptance_rate`가 추가된다. 이벤트 소유자는 각 기능 스토어이며, 스키마 변경 검토 소유자는 iOS 클라이언트 담당자다.
