# 문체·용어 편집 전후 보고 (2026-09-03)

기준: 커밋 1d05ec54(감사 이전) → 현재. 카탈로그 2개(Localizable·GameContent, 3,911키).

## 1. 용어 변경

| 이전 | 이후 | 비고 |
|---|---|---|
| 유효 피로 | 실제 피로 | 보정 뒤 실제 피로값이라는 뜻을 살림 |
| 구단에서 쌓은 자리 · 새 팀의 위상 | 팀 내 입지 | 두 표기를 하나로 |
| 스트라이크존 끝 | 존 구석 | 각성 설명 |
| 감독의 믿음 | (유지) | 감사 리포트는 "감독 신뢰"를 제안했으나 `tools/check-copy.mjs`가 "감독 신뢰"를 과거 내부 용어로 금지하고 있어 유지 |
| 계승 포인트 · 각성 · 숙련 | (유지) | 스토어 문안·리뷰 답변에서 이미 쓰는 이름 |

## 2. 통계

| 항목 | 수 |
|---|---|
| 값이 바뀐 키 | 325 |
| 한국어가 바뀐 키 | 177 |
| 일본어만 고친 키(오역·격식) | 143 |
| 영어만 고친 키 | 5 |
| 새로 추가된 키 | 39 |
| 한국어 평균 길이 | 40.7자 → 34.5자 |

편집 원칙: 결과 먼저, "~합니다" 연쇄 완화, 번역투("~에 대한", "~을 통해", 이중 피동) 제거, 군더더기 절 삭제. 코어 한국어와 정확히 일치해야 하는 키(각성·바람·카르마·이벤트 요약·훈련 초점)는 원문 유지.

## 3. 한국어 변경 전체 (이전 → 이후)

### 설정·공통 (8)

| 키 | 이전 | 이후 |
|---|---|---|
| `meta.achievements.offline` | Game Center에 연결되지 않았습니다. 달성 기록은 이 기기에 그대로 남습니다. | Game Center 미연결. 달성 기록은 이 기기에 남습니다. |
| `meta.career-setup.explanation` | 유형은 시작 능력과 구종 구성만 정합니다. 이후 성장은 매주 고르는 훈련과 승부 결과로 갈립니다. | 유형은 시작 능력과 구종만 정합니다. 그 뒤는 매주 고르는 훈련과 승부 결과가 가릅니다. |
| `meta.mastery.meaning` | 이 숙련은 투구 공식의 담당 부분을 최대 %lld‰ 보정합니다. | 투구 공식에서 맡은 부분을 최대 %lld‰ 보정. |
| `meta.weekly.instructions` | 세 가지 중 두 가지만 마치면 됩니다. 놓친 주와 남은 목표에는 벌점이 없습니다. | 셋 중 둘이면 도장. 놓쳐도 벌점 없음. |
| `reminder.nudge.body` | 매일 저녁 7시 30분, 지금 키우는 선수의 다음 목표나 그날의 이닝 중 이어 할 한 가지를 알려 드립니다. 며칠 안 열면 저절로 멈춥니다. | 매일 저녁 7시 30분, 다음 목표나 이어 할 이닝 하나를 알려 드립니다. 며칠 열지 않으면 알림은 저절로 꺼집니다. |
| `settings.audio.haptics.footer` | 진동을 끄면 승부 긴장에 따른 릴리스 미터 흔들림도 사라집니다. 기본 미터 이동과 피로에 따른 조준 흔들림은 그대로입니다. | 진동을 끄면 긴장에 따른 릴리스 미터 흔들림이 사라집니다. 소리는 다른 앱 음악을 멈추지 않고 무음 스위치를 따릅니다. |
| `settings.auto-release.footer` | 타이밍 제스처가 어려우면 켜세요. 항상 안정된 중간 릴리스로 던지므로 진행이 막히는 일은 없습니다. 다만 완벽한 타이밍의 이점도 사라집니다. | 타이밍이 어려우면 켜세요. 늘 중간 릴리스로 던지는 대신, 완벽한 타이밍의 이점은 없습니다. |
| `settings.notifications.footer` | 매일 저녁 7시 30분, 현재 선수의 다음 목표를 알려 드립니다. 며칠 동안 열지 않으면 저절로 멈춥니다. | 매일 저녁 7시 30분에 현재 선수의 다음 목표를 알립니다. 며칠 열지 않으면 알림은 저절로 꺼집니다. |

### 고교 UI (31)

| 키 | 이전 | 이후 |
|---|---|---|
| `conclusion.chronicle.drafted` | 드래프트 %lld라운드 %@ 지명. 3년이 응답받았습니다. | 드래프트 %lld라운드, %@ 지명. 3년이 보답받았습니다. |
| `conclusion.chronicle.personality-changed` | 성격이 달라졌습니다 — '%@'. 사람은 고정된 값이 아닙니다. | 성격이 달라졌습니다 — '%@'. 사람은 변하는 법입니다. |
| `conclusion.draft-reveal.undrafted-body` | 3년은 여기서 끝납니다. 새 선수에게 무엇을 남길지 고르게 됩니다. | 3년은 여기서 끝. 새 선수에게 남길 것을 고르세요. |
| `conclusion.fold.body` | 프로를 포기하고 새 선수로 시작합니다. 남길 기억을 고르게 됩니다. | 프로를 포기하고 새 선수로 시작합니다. 남길 기억을 고르세요. |
| `conclusion.fold.message` | 프로 커리어를 시작하지 않고 이 선수의 이야기를 끝냅니다. 지명은 사라지고 되돌릴 수 없습니다. | 프로 커리어 없이 이 선수의 이야기를 끝냅니다. 지명은 사라지고 되돌릴 수 없습니다. |
| `conclusion.legacy.confirmation-message` | 이 선수의 고교 3년이 닫히고 되돌릴 수 없습니다. 고른 대표 유산 하나만 새 선수에게 직접 이어집니다. | 고교 3년이 닫히고 되돌릴 수 없습니다. 고른 유산 하나만 새 선수에게 이어집니다. |
| `conclusion.life-card.growth.accessibility.no-change` | %1$@ %2$lld에서 %3$lld로 변화 없습니다. | %1$@ %2$lld에서 %3$lld, 변화 없음. |
| `conclusion.pro.awaiting-retirement-body` | 이 선수의 프로 커리어를 마치면 고교 시절과 통산 기록을 함께 돌아보고, 다음 선수에게 남길 대표 유산을 고릅니다. | 프로 커리어를 마치면 고교 시절과 통산 기록을 돌아보고, 다음 선수에게 남길 유산을 고릅니다. |
| `conclusion.signature.description` | 직접 키운 능력과 실제 경기 기록으로 세 가지 유산이 만들어졌습니다. | 키운 능력과 경기 기록으로 유산 세 가지가 만들어졌습니다. |
| `league.interpretation.aligned` | 실점과 FIP가 비슷합니다. 지금 성적이 내용 그대로라는 뜻입니다. | 실점과 FIP가 비슷합니다. 성적이 내용 그대로입니다. |
| `league.interpretation.fip-higher` | 실점이 FIP보다 낮습니다. 수비와 운이 도왔다는 뜻이라, 내용이 그대로면 성적은 나빠질 수 있습니다. | 실점이 FIP보다 낮습니다. 수비와 운이 도왔으니, 내용이 그대로면 성적은 내려갈 수 있습니다. |
| `league.interpretation.fip-lower` | 실점이 FIP보다 높습니다. 수비와 운이 불리하게 작용했다는 뜻이라, 같은 내용이면 성적이 좋아질 여지가 있습니다. | 실점이 FIP보다 높습니다. 수비와 운이 불리했으니, 같은 내용이면 성적은 좋아질 여지가 있습니다. |
| `league.interpretation.small-sample` | 표본이 아직 적습니다. 10이닝을 넘기면 지표가 의미를 갖기 시작합니다. | 표본이 아직 적습니다. 10이닝을 넘기면 지표가 의미를 갖습니다. |
| `legacy.archive.best-strikeouts` | 한 선수 최다 탈삼진 %1$lld (%2$lld번째 선수) — 역대 기록은 깨라고 있는 것입니다. | 한 선수 최다 탈삼진 %1$lld (%2$lld번째 선수) — 기록은 깨라고 있는 겁니다. |
| `legacy.archive.next-strikeouts` | 통산 탈삼진 %2$lld까지 %1$lld개 — 모든 선수의 기록은 영원히 쌓입니다. | 통산 탈삼진 %2$lld까지 %1$lld개 — 모든 선수의 기록은 계속 쌓입니다. |
| `legacy.bloom.meaning.b` | 좋은 재능이 더 멀리 열렸습니다. 다음 단계가 사정권에 들어왔습니다. | 좋은 재능이 더 열렸습니다. 다음 단계가 사정권입니다. |
| `legacy.bloom.meaning.c` | 이 능력이 계속된 훈련으로 더 높은 단계에 닿을 수 있게 됐습니다. | 훈련을 이어 가면 이 능력이 더 높은 단계에 닿습니다. |
| `legacy.pledge.alignment.health` | 현재 팔 부담을 관리하며 완주하는 데 맞춘 목표입니다. | 팔 부담을 관리하며 완주하는 목표입니다. |
| `legacy.pledge.alignment.safe` | 현재 능력 구성과 무관하게 완주를 노리는 안전 목표입니다. | 어떤 능력 구성으로도 완주할 수 있는 안전 목표입니다. |
| `legacy.pledge.intro.first` | 하나를 고르면 3년을 마칠 때 돌아봅니다. 이루면 새 선수가 더 강하게 시작됩니다. | 하나 고르면 3년 뒤 돌아봅니다. 이루면 새 선수 출발이 강해집니다. |
| `legacy.pledge.intro.repeat` | 하나를 고르면 고교 3년을 마칠 때 돌아봅니다. 등급에 따라 계승 포인트를 더 얻습니다. | 하나 고르면 고교 3년 뒤 돌아봅니다. 등급이 높을수록 계승 포인트가 큽니다. |
| `legacy.recap.points.save` | 이전 선수의 커리어가 남긴 포인트입니다. 더 쌓이면 계승 상점에서 새 선수의 규칙을 살 수 있습니다. | 지난 선수가 남긴 포인트. 모아서 계승 상점에서 새 선수의 규칙을 삽니다. |
| `opening.description` | 모든 경기를 던지지 않습니다. 결과를 바꿀 수 있는 순간에만 마운드에 오릅니다. | 매 경기 던지진 않습니다. 결과가 갈리는 순간에만 마운드에 오릅니다. |
| `record.high-school.game-record.empty` | 아직 치른 경기가 없습니다. 첫 고교 공식 경기를 던지면 여기에 쌓입니다. | 아직 경기가 없습니다. 첫 고교 공식 경기부터 여기에 쌓입니다. |
| `record.high-school.stats-empty.body` | 첫 등판을 던지면 여기에 쌓입니다. 탈삼진·볼넷·실점부터 WHIP·FIP 같은 세부 지표까지, 던진 만큼 정확해집니다. | 첫 등판부터 여기에 쌓입니다. 탈삼진·볼넷·실점부터 WHIP·FIP까지, 던질수록 정확해집니다. |
| `return.plan.body.high-school.training` | 다음 훈련으로 직접 키운 능력을 한 단계 더 올려 보세요. | 다음 훈련으로 키운 능력을 한 단계 더 올리세요. |
| `setup.challenge.description` | 지난 선수의 기억·대표 유산·계승 포인트·핸디캡은 쓰지 않습니다. 고른 난이도와 직접 투구만 이 판에 반영됩니다. | 지난 선수의 기억·대표 유산·계승 포인트·핸디캡은 쓰지 않습니다. 이 판에는 고른 난이도와 직접 투구만 들어갑니다. |
| `training.arm-health.result.next.manage` | 다음 행동: 다시 무리하기 전에 회복 훈련을 선택하세요. | 다음: 다시 무리하기 전에 회복 훈련을 고르세요. |
| `training.arm-health.result.outing` | %lld구 투구와 경기 전 피로 %lld로 팔 부담이 %lld 올랐습니다. | %lld구·경기 전 피로 %lld로 팔 부담 %lld 상승. |
| `training.repeat.stop-explanation` | 대화·각성·공식 경기 또는 높은 피로 앞에서 자동으로 멈춥니다. | 대화나 경기, 각성이 오거나 피로가 높아지면 멈추고 알려 드립니다. |
| `training.repeat.title` | 같은 훈련 최대 3회 | 같은 훈련 3번 연속 |

### 프로 UI (42)

| 키 | 이전 | 이후 |
|---|---|---|
| `pro.action.important-game` | 등판이 잡혔습니다. 위의 '이번 주'에서 승부를 시작하세요. | 등판 확정. 위 '이번 주'에서 승부를 시작하세요. |
| `pro.contract.offer.confirm.transfer-message` | %@와 %lld년 계약을 맺을까요? 통산 기록은 남지만 새 팀의 위상은 처음부터 쌓습니다. | %@와 %lld년 계약할까요? 통산 기록은 남고, 팀 내 입지는 처음부터 쌓습니다. |
| `pro.contract.offer.counter.rejected` | 구단이 요구를 거절했습니다. 팬 지지가 조금 줄었습니다. | 구단이 거절했습니다. 팬 지지가 조금 줄었습니다. |
| `pro.contract.offer.goal.instruction` | 서명하기 전에 방향 하나를 고르세요. 특정 선택을 추천하지 않습니다. | 서명 전에 방향 하나를 고르세요. 정답은 없습니다. |
| `pro.decision.confirm.message` | %1$@ 효과: %2$@. %3$@ 이 선택은 되돌릴 수 없습니다. | %@ 되돌릴 수 없습니다. |
| `pro.decision.follow-up` | 다음 직접 승부에서 이 선택이 준비에 남긴 영향을 확인합니다. | 이 선택의 영향은 다음 직접 승부에서 드러납니다. |
| `pro.decision.immediate-effect` | 미디어 선택의 효과는 즉시 적용됩니다. 다음 직접 승부를 기다리지 않습니다. | 미디어 선택은 효과가 바로 적용됩니다. 다음 승부를 기다리지 않습니다. |
| `pro.decision.warning` | 확인한 뒤에는 되돌릴 수 없습니다. 자동 진행도 이 결정을 건너뛰지 않습니다. | 확인하면 되돌릴 수 없습니다. 자동 진행 중에도 이 결정은 직접 고릅니다. |
| `pro.flow.unavailable.season-decision.recover-detail` | 이번 주 결정을 불러오지 못했습니다. 결정 없이 다음 일정으로 넘어갈 수 있습니다. | 이번 주 결정을 불러오지 못했습니다. 결정 없이 다음 일정으로 넘어가도 됩니다. |
| `pro.important.body` | 한 구씩 직접 던집니다. 구종·코스·노림·힘 배분을 고르면 결과가 그때그때 갈립니다. | 한 구씩 직접 던집니다. 구종·코스·노림·힘 배분에 따라 결과가 그 자리에서 갈립니다. |
| `pro.injury.result.body` | %lld시즌 %lld주차에 발생했습니다. 회복하는 동안 공식 경기에 나가지 않습니다. | %lld시즌 %lld주차 발생. 회복할 때까지 공식 경기에 나가지 않습니다. |
| `pro.injury.result.evidence` | 원피로 %lld · 유효 피로 %lld · %lld구 | 원피로 %lld · 실제 피로 %lld · %lld구 |
| `pro.journey.direction.legacy.hint` | 구단 명예는 함께한 시간, 영구결번은 그 시간 위의 상징입니다. | 구단 명예는 함께한 시간, 영구결번은 그 시간의 상징입니다. |
| `pro.legacy-handoff.link-broken.message` | 은퇴한 선수의 프로 기록이 지금 진행 중인 고교 회차와 달라 그대로 연결할 수 없습니다. 계승 포인트 보상만 남기고 프로 기록을 정리하면 다음 선수를 시작할 수 있습니다. | 은퇴 선수의 프로 기록이 진행 중인 고교 회차와 달라 그대로 잇지 못합니다. 계승 포인트만 남기고 프로 기록을 정리하면 다음 선수를 시작합니다. |
| `pro.locked.path.body` | 고교 탭에서 3년을 보내고 드래프트를 통과하면, 그때의 능력을 그대로 안고 프로에 들어갑니다. | 고교 3년을 보내고 드래프트를 통과하면 그 능력 그대로 프로에 들어갑니다. |
| `pro.locked.skip.description` | 건너뛰면 지명 결과가 시드에서 만들어집니다. 고교 3년의 성장과 기억은 없습니다. | 건너뛰면 지명 결과가 시드로 정해집니다. 고교 3년의 성장과 기억은 없습니다. |
| `pro.locked.skip.locked` | 고교 3년을 한 번 마치면 고교를 건너뛰는 길도 열립니다. | 고교 3년을 한 번 마치면 건너뛰기가 열립니다. |
| `pro.national-team.call.body` | 시즌을 마친 투구가 대표팀 레이더에 걸렸습니다. 수락하면 조별 3경기를 치른 뒤, 결승은 직접 등판합니다. | 시즌 성적이 대표팀 레이더에 걸렸습니다. 수락하면 조별 3경기를 치르고 결승은 직접 등판합니다. |
| `pro.national-team.call.cost` | 대가: 다음 스프링캠프 시작 피로가 남고, 결승에서 많이 던지면 더 무거워집니다. 부상 판정도 한 번 있습니다. | 대가: 다음 스프링캠프를 피로를 안고 시작합니다. 결승에서 많이 던질수록 무겁고, 부상 판정도 한 번 있습니다. |
| `pro.offseason.confirm.free-agency.message` | 시장을 열고 제안을 비교합니다. 선택해도 즉시 이적하지 않으며, 수락 후에만 통산 기록을 유지한 채 새 팀의 위상을 처음부터 쌓습니다. | 시장을 열고 제안을 비교합니다. 골라도 바로 이적하지 않습니다. 수락하면 통산 기록은 남고 팀 내 입지는 처음부터 쌓습니다. |
| `pro.offseason.free-agency.detail` | 시장을 열고 제안을 비교합니다. 선택해도 즉시 이적하지 않습니다. | 시장을 열고 제안을 비교합니다. 골라도 바로 이적하지 않습니다. |
| `pro.offseason.military.detail` | 두 시즌을 비우고 돌아옵니다. 나이가 두 살 늘지만 이후 시즌이 온전해집니다. | 두 시즌을 비우고 돌아옵니다. 나이는 두 살 늘지만 이후 시즌은 온전합니다. |
| `pro.offseason.military.journey.detail` | 두 시즌 동안 계약 시간을 멈춥니다. 팬 지지는 한 번만 줄고 다음 시장으로 돌아옵니다. | 두 시즌 동안 계약이 멈춥니다. 팬 지지는 한 번만 줄고, 돌아오면 다음 시장부터 시작합니다. |
| `pro.offseason.open-market.detail` | 오픈 시장 제안을 비교합니다. 선택해도 즉시 이적하지 않습니다. | 오픈 시장 제안을 비교합니다. 골라도 바로 이적하지 않습니다. |
| `pro.offseason.open-market.service.locked` | 오픈 시장에는 1군 등록 6년이 필요합니다. 지금 %lld년입니다. | 오픈 시장은 1군 등록 6년부터. 지금 %lld년. |
| `pro.offseason.renewal.detail` | %@의 재계약 시장이 열렸습니다. 서명 전에 두 제안을 비교하세요. | %@ 재계약 시장이 열렸습니다. 서명 전에 두 제안을 비교하세요. |
| `pro.offseason.retire.detail` | 여기서 커리어를 마칩니다. 통산 기록과 명예의 전당 점수가 확정됩니다. | 여기서 커리어를 마칩니다. 통산 기록과 명예의 전당 점수 확정. |
| `pro.postseason.finale.champion.body` | 직접 등판과 휴식 선택, 자동 진행된 이닝까지 모두 우승으로 이어졌다. | 직접 등판도, 휴식도, 자동 진행된 이닝도 모두 우승으로 이어졌다. |
| `pro.postseason.finale.runner-up.body` | 우승에는 닿지 못했지만 모든 포스트시즌 경기가 커리어 기록으로 남는다. | 우승엔 닿지 못했다. 그래도 포스트시즌 경기는 전부 커리어 기록에 남는다. |
| `pro.retired.legacy.body` | 고교 시절부터 은퇴까지 직접 키운 능력과 통산 기록으로 대표 유산 세 가지를 찾습니다. 그중 하나를 다음 선수에게 직접 남길 수 있습니다. | 고교부터 은퇴까지 키운 능력과 통산 기록에서 대표 유산 세 가지를 찾습니다. 하나를 다음 선수에게 남깁니다. |
| `pro.retired.legacy.confirm.message` | %@의 프로 커리어를 닫고, 대표 유산을 고르는 화면으로 이동합니다. | %@의 프로 커리어를 닫고 대표 유산 선택으로 넘어갑니다. |
| `pro.retired.legacy.footnote` | 프로 기록을 안전하게 저장한 뒤, 다음 선수에게 남길 대표 유산 하나를 고릅니다. | 프로 기록을 저장한 뒤 다음 선수에게 남길 대표 유산 하나를 고릅니다. |
| `pro.retired.soul.body` | 고교를 건너뛰고 시작한 프로 기록은 계승 포인트로 남습니다. 진행 중인 고교 선수나 다음 고교 선수의 계승 상점에서 사용할 수 있습니다. | 고교를 건너뛴 프로 기록은 계승 포인트로 남습니다. 진행 중인 고교 선수나 다음 선수의 계승 상점에서 씁니다. |
| `pro.retired.soul.footnote` | 프로 기록을 안전하게 저장한 뒤 기존 고교 진행으로 돌아갑니다. | 프로 기록을 저장한 뒤 진행 중인 고교로 돌아갑니다. |
| `pro.retirement.decision.body` | 더 이상 다음 시즌은 없습니다. 통산 기록을 확정하고 유니폼을 벗습니다. | 다음 시즌은 없습니다. 통산 기록을 확정하고 유니폼을 벗습니다. |
| `pro.role-request.body` | 이번 시즌 등판 보직을 고릅니다. 수락 전망은 지금 능력과 믿음을 기준으로 합니다. | 이번 시즌 보직을 고릅니다. 수락 전망은 지금 능력과 감독의 믿음 기준입니다. |
| `pro.weekly-plan.until` | %@ 끝까지 진행 | %@까지 자동 진행 |
| `pro.weekly.advance-stop` | 승부처 경기·역할 변화·부상이 생기면 그 자리에서 멈춥니다. | 중요한 경기나 역할 변경, 부상이 생기면 멈추고 알려 드립니다. |
| `pro.weekly.injury-risk` | 부상 위험 %@ · 유효 피로 %lld | 부상 위험 %@ · 실제 피로 %lld |
| `pro.weekly.standing.schedule` | %1$@ 보직 · 남은 예정 등판 약 %2$lld회. 직접 승부도 이 경기 수 안에 포함됩니다. | %1$@ 보직 · 남은 예정 등판 약 %2$lld회. 직접 승부도 이 안에 포함. |
| `pro.weekly.standing.title` | 구단에서 쌓은 자리 | 팀 내 입지 |
| `pro.weekly.standing.veteran` | 나이만으로 자리를 빼앗기지 않습니다. 최근 성적과 몸 상태로 다음 등판을 정합니다. | 나이만으로 자리를 잃진 않습니다. 최근 성적과 몸 상태가 다음 등판을 정합니다. |

### 투구 UI (21)

| 키 | 이전 | 이후 |
|---|---|---|
| `pitch.abort.game.message` | 지금까지 던진 이 이닝은 사라집니다. 다음 마운드는 새 이닝입니다. | 이 이닝은 사라집니다. 다음 마운드는 새 이닝부터. |
| `pitch.adaptation.pitch` | %@ 반복이 읽히고 있습니다. 다른 구종을 섞어 보세요. | %@ 반복이 읽혔다. 다른 구종을 섞자. |
| `pitch.adaptation.pitch-and-zone` | %@와 %@ 반복이 읽혔습니다. 둘 중 하나를 바꾸세요. | %@와 %@ 조합이 읽혔다. 하나는 바꾸자. |
| `pitch.analysis.pattern-warning` | 같은 배합이 반복됐습니다. 다음 등판에는 속도나 코스를 먼저 바꿔 보세요. | 같은 배합이 반복됐다. 다음 등판엔 완급이나 코스를 먼저 바꾸자. |
| `pitch.build.stamina` | 이닝 소화형 시너지 · 누적 피로 %lld로 억제 중입니다. | 이닝 소화형 시너지 · 누적 피로 %lld로 억제 |
| `pitch.catcher.card.manual` | 내 배합 · 직접 선택 | 내 배합 |
| `pitch.catcher.hold.body` | 직접 수정하면 자동으로 켜지고, 다음 공에도 같은 배합을 유지합니다. | 다음 공에도 내 배합을 그대로 이어 갑니다. |
| `pitch.catcher.reason.read-pressure` | 상대가 구종을 읽고 있습니다. 앉기 전에 배합을 바꿉니다. | 구종이 읽힌다. 앉기 전에 배합을 바꾼다. |
| `pitch.catcher.scout.estimate` | 아직 추정입니다. 약점은 %@ · %@ 근처로 보입니다. | 아직 추정. 약점은 %@ · %@ 근처. |
| `pitch.delivery.accessibility.hint` | 길게 눌러 와인드업하고, 끌어서 조준한 뒤 떼면 던집니다. 설정에서 자동 릴리스를 켜면 탭 한 번으로 던집니다. | 길게 눌러 와인드업, 끌어서 조준, 떼면 투구. 설정에서 자동 릴리스를 켜면 탭 한 번으로 던집니다. |
| `pitch.inning.process.good` | 구종과 코스를 고른 과정이 좋았다는 평가를 받습니다. | 구종과 코스를 고른 과정이 좋았습니다. |
| `pitch.inning.process.review` | 결과와 별개로 구종 순서를 다시 맞춰야 합니다. | 결과와 별개로, 구종 순서는 다시 볼 것. |
| `pitch.intent.chase.detail` | 고른 코스 바깥으로 빼서 헛스윙을 노리는 대신 볼이 될 확률이 큽니다. | 고른 코스 바깥으로 뺀다. 헛스윙을 노리지만 볼이 되기 쉽다. |
| `pitch.intent.chase.middle.detail` | 한복판에서는 낮은 쪽으로 빼는 공이 됩니다. 헛스윙을 노리는 대신 볼이 될 확률이 큽니다. | 한복판에서는 낮은 쪽으로 뺀다. 헛스윙을 노리지만 볼이 되기 쉽다. |
| `pitch.scenario.pro.autumn.playoff.series.body` | 이 등판은 경기 전체가 아니라 한 구간이다. 눈앞의 승부를 지킨다. | 경기 전체가 아니라 한 구간을 맡는다. 눈앞의 승부만 지킨다. |
| `pitch.scenario.pro.autumn.semifinal.series.body` | 이 승부처를 막고 남은 경기에서 시리즈의 한 승을 결정한다. | 이 승부처를 막는다. 시리즈의 한 승은 남은 경기가 정한다. |
| `pitch.scenario.tutorial.body` | 기록에 남지 않는 연습 한 타석입니다. 마음껏 던져 보세요. | 기록에 안 남는 연습 한 타석. 마음껏 던지세요. |
| `pitch.sequence.expand.detail` | 2스트라이크 뒤 존 밖으로 유인해 좋은 결과를 만들었습니다. | 2스트라이크 뒤 존 밖으로 유인한 게 통했다. |
| `pitch.sequence.steal-strike.detail` | 타자가 예상하지 못한 공으로 스트라이크를 먼저 잡았습니다. | 예상 밖의 공으로 스트라이크를 먼저 잡았다. |
| `pitch.stat.release-best` | 직접 던진 %lld구 평균 — 지금까지 가장 좋았습니다. | 직접 던진 %lld구 평균 — 지금까지 최고. |
| `pitch.state.plate-ended.body` | 타석이 끝났습니다. 다음 타자를 준비하세요. | 타석 종료. 다음 타자를 준비하세요. |

### 용어 사전 (24)

| 키 | 이전 | 이후 |
|---|---|---|
| `content.glossary.awakening.definition` | 한 시즌의 갈림길에서 능력이 크게 열리는 선택입니다. 얻는 것과 잃는 것이 함께 옵니다. | 시즌 갈림길에서 능력이 크게 열리는 선택. 얻는 만큼 잃는 것도 있다. |
| `content.glossary.baseball-spirit.definition` | 이 선수가 남긴 마음가짐입니다. 다음 회차의 시작 힘과 이야기에 남습니다. | 이 선수가 남긴 마음가짐. 다음 회차의 시작과 이야기에 남는다. |
| `content.glossary.catcher-chemistry.definition` | 배터리로 얼마나 맞춰 던지는지입니다. 제구와 승부 판단에 붙습니다. | 포수와 얼마나 잘 맞는지. 제구와 승부 판단에 보탬이 된다. |
| `content.glossary.club-interest.definition` | 지금 이 선수를 얼마나 원하는지입니다. 높음·보통·낮음으로 표시됩니다. | 구단이 지금 이 선수를 얼마나 원하는지. 높음·보통·낮음으로 표시. |
| `content.glossary.command.definition` | 원하는 곳에 공을 넣는 힘입니다. 0에서 100까지이며, 볼넷을 줄입니다. | 원하는 곳에 공을 넣는 힘(0~100). 높을수록 볼넷이 준다. |
| `content.glossary.era.definition` | 9이닝당 자책점입니다. 낮을수록 실점을 잘 막았다는 뜻입니다. | 9이닝당 자책점. 낮을수록 좋다. |
| `content.glossary.fatigue.definition` | 몸이 얼마나 지쳤는지입니다. 높을수록 제구가 흔들리고 부상 위험이 커집니다. | 몸이 얼마나 지쳤는지. 높으면 제구가 흔들리고 부상 위험이 커진다. |
| `content.glossary.k9.definition` | 9이닝당 삼진입니다. 높을수록 구위와 변화구가 타자를 이겼다는 뜻입니다. | 9이닝당 탈삼진. 높을수록 구위와 변화구가 타자를 이긴 것. |
| `content.glossary.lineage.definition` | 지난 선수가 다음 선수에게 남기는 힘입니다. 대표 유산과 기억으로 이어집니다. | 앞 선수가 다음 선수에게 남기는 힘. 대표 유산과 기억으로 이어진다. |
| `content.glossary.manager-faith.definition` | 감독이 이 투수를 얼마나 쓰려 하는지입니다. 보직과 1군 출전에 영향을 줍니다. | 감독이 이 투수를 얼마나 쓰려 하는지. 보직과 1군 출전을 좌우한다. |
| `content.glossary.mastery.definition` | 같은 능력을 오래 갈아 쌓은 깊이입니다. 레벨이 오르면 같은 수치가 더 잘 나옵니다. | 같은 능력을 오래 갈아 쌓은 깊이. 레벨이 오르면 같은 수치도 더 잘 나온다. |
| `content.glossary.military-exemption.definition` | 금메달을 따면 군 복무를 마친 것으로 처리됩니다. 이미 복무를 마쳤다면 팬의 지지가 더 오릅니다. | 금메달이면 군 복무를 마친 것으로 친다. 이미 마쳤다면 팬 지지가 더 오른다. |
| `content.glossary.movement.definition` | 공이 얼마나 꺾이고 떨어지는지입니다. 0에서 100까지입니다. | 공이 얼마나 꺾이고 떨어지는지(0~100). |
| `content.glossary.national-team-call.definition` | 시즌을 마친 뒤 가상 국가대표 대회에 뽑히는 통보입니다. 수락하면 조별 경기와 결승이 이어집니다. | 시즌 뒤 가상 국가대표 대회에 뽑혔다는 통보. 수락하면 조별 경기와 결승이 이어진다. |
| `content.glossary.pitcher-lab.definition` | 구종을 다듬고 숙련을 쌓는 오프시즌 공간입니다. 실전 전에 감각을 올립니다. | 구종을 다듬고 숙련을 쌓는 오프시즌 공간. 실전 전에 감각을 올린다. |
| `content.glossary.platoon.definition` | 타자의 좌우에 맞춰 투수를 나누어 쓰는 운용입니다. 반대손 승부에 불리할 때 꺼냅니다. | 타자 좌우에 맞춰 투수를 나눠 쓰는 운용. 반대손 승부가 불리할 때 꺼낸다. |
| `content.glossary.qs.definition` | 선발이 6이닝 이상, 자책 3점 이하로 막은 등판입니다. 로테이션 투수의 안정 지표입니다. | 선발이 6이닝 이상, 자책 3점 이하로 막은 등판. 선발의 안정 지표. |
| `content.glossary.role.definition` | 등판 역할입니다. 선발은 긴 이닝, 중간은 연결, 마무리는 마지막 아웃을 책임집니다. | 등판 역할. 선발은 긴 이닝, 중간은 연결, 마무리는 마지막 아웃. |
| `content.glossary.season-decision.definition` | 시즌 중간에 멈추는 갈림길입니다. 고른 효과는 바로 적용되고, 어떤 선택은 몇 주 뒤에 결과가 남습니다. | 시즌 중간의 갈림길. 효과는 바로 적용되고, 어떤 선택은 몇 주 뒤에 결과가 남는다. |
| `content.glossary.signing-bonus.definition` | 계약을 맺을 때 먼저 받는 돈입니다. 연봉과 별도로 통장에 들어옵니다. | 계약할 때 먼저 받는 돈. 연봉과는 별도다. |
| `content.glossary.stamina.definition` | 긴 이닝을 버티는 힘입니다. 0에서 100까지이며, 선발에 더 많이 필요합니다. | 긴 이닝을 버티는 힘(0~100). 선발일수록 많이 필요하다. |
| `content.glossary.stuff.definition` | 공의 힘입니다. 0에서 100까지이며, 높을수록 헛스윙이 늘고 구속이 살아납니다. | 공의 힘(0~100). 높을수록 헛스윙이 늘고 구속이 산다. |
| `content.glossary.talent-wall.definition` | 훈련으로 당장 넘기 어려운 상한입니다. 각성이나 성장 대성공으로 열립니다. | 훈련만으론 당장 못 넘는 상한. 각성이나 성장 대성공으로 열린다. |
| `content.glossary.whip.definition` | 이닝당 출루 허용입니다. 안타와 볼넷을 합쳐 이닝으로 나눕니다. 낮을수록 좋습니다. | 이닝당 출루 허용. (안타+볼넷)÷이닝. 낮을수록 좋다. |

### 고교 서사·콘텐츠 (8)

| 키 | 이전 | 이후 |
|---|---|---|
| `content.achievement.double_karma.detail` | 핸디캡 두 개를 안고 키운 선수로 드래프트까지 갑니다. | 핸디캡 둘을 안고 드래프트까지 간다. |
| `content.goal-board.ambition-metric.anchor-team-seasons.hint` | 같은 팀에서 시즌을 이어 한 구단의 상징에 다가갑니다. | 한 팀에서 시즌을 이어 갈수록 구단의 상징에 가까워진다. |
| `content.pledge.awakening-three.detail` | 각성 세 번을 고르고 서로 다른 전략 계열 세 가지를 모은다. | 각성 셋을 서로 다른 전략 계열에서 고른다. |
| `content.pledge.healthy-finish.detail` | 고교 공식 경기 네 번을 치르고 피로를 78 이하로 남긴 채 팔 경고 없이 완주한다. | 고교 공식전 4경기, 피로 78 이하, 팔 경고 없이 완주. |
| `content.pledge.iron-control-five.detail` | 직접 등판 4경기 이상, 볼넷 없이 통산 6탈삼진을 만든다. | 직접 등판 4경기 이상, 볼넷 없이 통산 6탈삼진. |
| `content.pledge.iron-control.detail` | 직접 등판 4경기 이상, 볼넷 없이 통산 4탈삼진을 만든다. | 직접 등판 4경기 이상, 볼넷 없이 통산 4탈삼진. |
| `content.relationship.evt-lost-teammate.choice.challenge.detail` | 작별을 공의 감촉으로 남기되 미련까지 함께 돌아올 수 있다 | 작별을 공의 감촉으로 남긴다. 미련도 같이 돌아올 수 있다 |
| `content.weekly-task.pledge_selected.next-action` | 학교를 고르기 전에 고교 3년의 목표를 정하면 됩니다. | 학교를 고르기 전, 고교 3년의 목표를 정하세요. |

### 프로 서사·결정 (43)

| 키 | 이전 | 이후 |
|---|---|---|
| `content.pro-decision.choice.accept_short_rest.detail` | 앞으로 3주 동안 선발 등판이 1경기 늘고 피로와 감독의 믿음이 함께 움직입니다. | 3주간 선발 등판 1경기 추가. 피로도, 감독의 믿음도 오른다. |
| `content.pro-decision.choice.keep_normal_rest.detail` | 몸은 그대로 두지만 감독의 믿음이 조금 줄어듭니다. | 몸은 그대로, 감독의 믿음은 조금 준다. |
| `content.pro-decision.choice.keep_own_way.detail` | 훈련 효율은 지키지만 포수와의 호흡이 조금 멀어집니다. | 훈련 효율은 지킨다. 대신 포수 호흡이 조금 멀어진다. |
| `content.pro-decision.choice.push_race.detail` | 감독의 믿음을 얻는 대신 피로를 감수합니다. | 피로를 감수하고 감독의 믿음을 얻는다. |
| `content.pro-decision.choice.stay_roster.detail` | 등판은 유지하지만 감독의 믿음이 더 깎입니다. | 등판은 지키지만 감독의 믿음이 더 깎인다. |
| `content.pro-decision.choice.take_mentor.detail` | 포수와의 호흡과 변화구는 오르지만 3주 훈련 효율이 줄어듭니다. | 포수 호흡과 변화구가 오른다. 대신 3주간 훈련 효율이 준다. |
| `content.pro-news.aging.decline` | %lld세 · 전성기가 기울며 구위가 한 단계 떨어졌습니다. | %lld세 · 구위가 한 단계 떨어졌다. 전성기가 기운다. |
| `content.pro-news.autumn.did-not-qualify` | 정규시즌이 끝났습니다. 올해는 플레이오프에 들지 못했습니다. | 정규시즌 종료. 올해 플레이오프는 없다. |
| `content.pro-news.autumn.seed-1` | 정규시즌 1위입니다. 우승 결정전 한 판이 남았습니다. | 정규시즌 1위. 우승 결정전 한 판만 남았다. |
| `content.pro-news.autumn.seed-2` | 정규시즌 2위입니다. 플레이오프 한 판부터 올라갑니다. | 정규시즌 2위. 플레이오프 한 판부터 올라간다. |
| `content.pro-news.autumn.seed-3` | 정규시즌 3위입니다. 준플레이오프 한 판부터 시작합니다. | 정규시즌 3위. 준플레이오프 한 판부터 시작한다. |
| `content.pro-news.autumn.seed-4` | 정규시즌 4위입니다. 와일드카드에서 한 승이면 올라갑니다. | 정규시즌 4위. 와일드카드 한 승이면 올라간다. |
| `content.pro-news.autumn.seed-5` | 정규시즌 5위입니다. 와일드카드에서 두 번을 이겨야 합니다. | 정규시즌 5위. 와일드카드에서 두 번 이겨야 한다. |
| `content.pro-news.autumn.unavailable-injury` | 구단은 가을에 올랐지만 부상으로 마운드에 서지 못했습니다. | 팀은 가을야구에 갔지만, 부상으로 마운드엔 서지 못했다. |
| `content.pro-news.autumn.unavailable-minor` | 구단은 가을에 올랐지만 2군이라 마운드에 서지 못했습니다. | 팀은 가을야구에 갔지만, 2군이라 마운드엔 서지 못했다. |
| `content.pro-news.call-up` | 2군 기록과 감독의 믿음을 쌓아 1군 출전 명단에 합류했습니다. | 1군 합류. 2군 기록과 감독의 믿음이 만든 자리다. |
| `content.pro-news.demotion` | 최근 등판이 이어지지 않아 2군으로 내려갑니다. 기록을 다시 쌓아야 합니다. | 2군행. 최근 등판이 이어지지 않았다. 기록을 다시 쌓아야 한다. |
| `content.pro-news.first-appearance` | 프로 첫 공식 등판을 마쳤습니다. %1$lld경기에서 %2$lld개의 삼진을 잡았습니다. | 프로 첫 공식 등판 완료. %1$lld경기 %2$lld탈삼진. |
| `content.pro-news.national-team.declined` | 국가대표 소집을 사양했습니다. 팬의 시선이 조금 식었습니다. | 국가대표 소집 거절. 팬 시선이 조금 식었다. |
| `content.pro-news.pitch-learning.game-ready` | 구종 연구 진전 · 다음 공식 경기에서 개발 구종을 시험할 수 있습니다. | 구종 연구 진전 · 다음 공식 경기에서 개발 구종을 시험할 수 있다. |
| `content.pro-news.retirement.best-season` | 가장 빛난 해는 %1$lld시즌 — %2$lld경기에서 %3$lld개의 탈삼진을 잡았습니다. | 최고의 해는 %1$lld시즌 · %2$lld경기 %3$lld탈삼진 |
| `content.pro-news.role-request.rejected.closer` | 보직 지원이 거절되었습니다. 구위와 포수와의 호흡이 마무리 기준에 미치지 않습니다. | 보직 지원 거절. 구위와 포수 호흡이 마무리 기준에 못 미친다. |
| `content.pro-news.role-request.rejected.starter` | 보직 지원이 거절되었습니다. 체력과 감독의 믿음이 선발 기준에 미치지 않습니다. | 보직 지원 거절. 체력과 감독의 믿음이 선발 기준에 못 미친다. |
| `content.pro-news.rookie-contract` | 신인 계약에 서명했습니다. 2군 선발 경쟁이 시작됩니다. | 신인 계약 완료. 2군 선발 경쟁 시작. |
| `content.pro-news.segment.all-star` | 올스타 휴식기입니다. 몸을 추스르고 후반기를 준비합니다. | 올스타 휴식기. 몸을 추스르고 후반기를 준비한다. |
| `content.pro-news.segment.first-half` | 전반기 레이스에 들어섰습니다. 긴 시즌의 리듬을 잡습니다. | 전반기 레이스 시작. 긴 시즌의 리듬을 잡을 때다. |
| `content.pro-news.segment.opening` | 개막 시리즈가 시작됐습니다. 첫인상을 남길 시간입니다. | 개막 시리즈. 첫인상을 남길 시간이다. |
| `content.pro-news.segment.pennant-race` | 순위 경쟁이 뜨거워집니다. 한 경기의 무게가 커집니다. | 순위 싸움이 뜨겁다. 한 경기의 무게가 다르다. |
| `content.pro-rival.pro-rival-busan.profile` | 낮게 깔린 공을 퍼올려 우측 담장을 넘깁니다. 몸쪽 실투 한 개를 놓치지 않습니다. | 낮은 공을 퍼올려 우측 담장을 넘긴다. 몸쪽 실투는 놓치지 않는다. |
| `content.pro-rival.pro-rival-changwon.profile` | 긴 리치로 바깥쪽까지 커버합니다. 높은 공을 그대로 받아넘깁니다. | 긴 리치로 바깥쪽까지 커버한다. 높은 공도 그대로 받아넘긴다. |
| `content.pro-rival.pro-rival-daegu.profile` | 빠른 배트로 안쪽 공을 끌어당깁니다. 초구부터 노림수를 숨기지 않습니다. | 빠른 배트로 몸쪽 공을 당겨친다. 초구부터 노림수를 숨기지 않는다. |
| `content.pro-rival.pro-rival-daejeon.profile` | 존을 벗어난 공에는 손이 나가지 않습니다. 풀카운트 승부를 두려워하지 않습니다. | 존 밖 공엔 손이 안 나간다. 풀카운트 승부를 두려워하지 않는다. |
| `content.pro-rival.pro-rival-gwangju.profile` | 좌중간 갭을 노려 장타를 만듭니다. 변화구 타이밍에 강합니다. | 좌중간 갭을 노려 장타를 만든다. 변화구 타이밍에 강하다. |
| `content.pro-rival.pro-rival-incheon.profile` | 파울로 승부를 늘리다 결정구를 받아칩니다. 삼진보다 인플레이 타구가 많습니다. | 파울로 승부를 끌다 결정구를 받아친다. 삼진보다 인플레이 타구가 많다. |
| `content.pro-rival.pro-rival-jeju.profile` | 주자가 있을 때 스윙이 더 단단해집니다. 넓은 존을 커버하는 배드볼 히터입니다. | 주자가 나가면 스윙이 더 단단해진다. 넓은 존을 커버하는 배드볼 히터. |
| `content.pro-rival.pro-rival-jeonju.profile` | 짧게 끊어치고 곧바로 다음 베이스를 노립니다. 실투가 곧 실점입니다. | 짧게 끊어치고 바로 다음 베이스를 노린다. 실투가 곧 실점이다. |
| `content.pro-rival.pro-rival-seoul.profile` | 카운트가 몰려도 스윙이 짧아지지 않습니다. 바깥쪽 승부를 기다렸다 밀어칩니다. | 카운트가 몰려도 스윙이 짧아지지 않는다. 바깥쪽을 기다렸다 밀어친다. |
| `content.pro-rival.pro-rival-suwon.profile` | 약점 코스가 뚜렷하지 않습니다. 어떤 구종이든 중심에 맞힙니다. | 뚜렷한 약점 코스가 없다. 어떤 구종이든 중심에 맞힌다. |
| `content.pro-summary.call-up` | 1군 출전 명단에 합류했습니다. 다음 주목받는 등판이 바로 이어집니다. | 1군 합류. 주목받는 등판이 바로 이어진다. |
| `content.pro-tension.record.command.detail` | 정교한 코스 승부로 불필요한 주자를 내보내지 않습니다. | 코스 승부로 불필요한 주자를 내보내지 않는다. |
| `content.pro-tension.record.power.detail` | 빠른 공으로 타자를 압도해 한 시즌 탈삼진 기록에 도전합니다. | 빠른 공으로 압도해 한 시즌 탈삼진 기록에 도전한다. |
| `content.pro-tension.record.stamina.detail` | 후반에도 구위를 지키며 맡은 아웃카운트를 끝까지 책임집니다. | 후반에도 구위를 지키고 맡은 아웃카운트를 끝까지 책임진다. |
| `content.pro-tension.rival.detail` | %1$@의 %2$@. 올 시즌 몇 번이고 마운드에서 마주칩니다. | %1$@의 %2$@. 올 시즌 몇 번이고 마운드에서 마주친다. |

## 4. 일본어만 고친 키 (143)

기계번역 오역(標識/出産/始球式/手袋/中堅打者 등)과 감독·라이벌 대사의 과한 경어를 고쳤다. 한국어는 그대로다.

| 키 | 이전(ja) | 이후(ja) |
|---|---|---|
| `conclusion.best-evaluation.next-body` | このプレイヤーは %lld を獲得しました。次のマークでそのマークを打ち破ってください。 | 今回の選手は %lld 点。次の選手でこの記録を超えよう。 |
| `conclusion.legacy-preview.body` | そのうちの 1 つが次のプレイヤーに渡されます。選択はプロの話の後に来る。 | このうち1つが次の選手に受け継がれます。選ぶのはプロ編を終えた後です。 |
| `conclusion.life-card.growth.accessibility.up` | %1$@ は、%2$lld から %3$lld に増加し、%4$lld まで増加しました。 | %1$@ は %2$lld から %3$lld へ、%4$lld 上昇。 |
| `conclusion.memory.confirmation-message` | このプレーヤーは機能アップデート前に開始されました。それらのルールに基づいて選択された記憶だけが先に進みます。 | アップデート前に始めた選手です。当時のルールで選んだ記憶だけが次の選手に受け継がれます。 |
| `conclusion.memory.description` | このプレーヤーは機能アップデート前に開始されました。そのランからルールに従って思い出を選択してください。 | アップデート前に始めた選手です。当時のルールで記憶を選びます。 |
| `conclusion.rebirth.summary.eul` | %lld メモリと %lld 継承ポイントから始めます。 | 記憶 %lld 枚 · 継承ポイント %lld を携えて開始。 |
| `conclusion.rebirth.summary.reul` | %lld メモリと %lld 継承ポイントから始めます。 | 記憶 %lld 枚 · 継承ポイント %lld を携えて開始。 |
| `pro.role-request.condition.starter.likely` | 体力 %lld、監督の信頼 %lld — 先発が有力 | 体力 %lld、監督の信頼 %lld — 先発有力 |
| `pro.weekly.plan.trust.effect` | 監督の信頼を築きます。 | 監督の信頼が上がります |
| `setup.karma.stubborn-coach.detail` | コーチの信頼を勝ち取るのはさらに難しい。 | 監督の信頼を得にくくなります。 |
| `content.community-buzz.reaction.dominant-shutout-age` | 彼はその年齢であんなに投げるの？彼が記入すると何が起こるでしょうか？ | あの年であんな球を投げるの？体ができたらどうなるんだ？ |
| `content.community-buzz.reaction.rough-outing-next-test` | %lld 失点は許される...本当の試練は、彼が次回どう答えるかだ。 | %lld失点…次の試合でどう返すかが本当の試験だ |
| `content.community-buzz.reaction.wildness-walks` | 球威はそこにあるけど、 %lld 四球が問題です。 制球 それが今の質問のすべてです。 | 球はいいけど四球%lld個はちょっと…制球が固まるかが鍵だな |
| `content.community-buzz.rival-news.rotation-reset` | %@ (%@) はラフなストレッチの後、回転からバンプしました。彼はリセットが必要なようだ。 | %@（%@）、不振の末に先発から外れた。立て直しが必要に見える。 |
| `content.community-buzz.rival-news.strikeout-record` | %@ (%@) は 1 試合で %lld 奪三振を記録し、同僚の中で最高記録に迫っています。 | %@（%@）が1試合%lld奪三振——同年代の最高記録に迫った。 |
| `content.community-buzz.rival-news.velocity-gain` | %@ (%@) 春以降、%lld km/h が追加されました。誰もが彼が冬の間に何をしたか知りたがっている。 | %@（%@）の球速が春より%lldkm/h上がった。冬に何をしたのか皆が気にしている。 |
| `content.important-game.game-ace-duel.narrative` | 8試合までスコアレス試合。彼らのエースは瞬きしていない。最初のミスで負けます。 | 8回まで0の行進。相手のエースも譲らない。先にミスした方が負ける。 |
| `content.important-game.game-backup-catcher.narrative` | 先発捕手はファウルボールを指に引っ掛けて退場した。ブルペンでバックアップと仕事をしたのは一度だけだ。 | 正捕手がファウルを指に受けて交代。控え捕手とはブルペンで一度合わせただけだ。 |
| `content.important-game.game-damage-control.narrative` | この回に３点を奪い、試合を同点にした。また満塁となる。ここでさらにギブアップすると、試合は振り切ってしまう。 | この回だけで3点を失い同点。再び満塁。ここでさらに失えば試合が傾く。 |
| `content.important-game.game-doubleheader.narrative` | この日の第２試合。走り終えましたが、先ほど使った腕がまだ重く感じます。 | 今日2試合目。1点ビハインド、昼の試合で投げた腕がまだ重い。 |
| `content.important-game.game-fatigue.narrative` | 7回にあなたの速球は一歩を外されました。自分が耐えられる投球を選択してください。 | 7回、速球が落ちてきた。どの球で凌ぐか決めなければならない。 |
| `content.important-game.game-fireman.narrative` | 無人でランナーが二、三塁になった状態で引き継ぎます。ランはあなたに請求されませんが、試合はあなたの手の中にあります。 | 前の投手が残した無死二、三塁を引き継いで上がる。ここで入る点は自分の記録にはならないが、試合は自分の手にある。 |
| `content.important-game.game-nightfall.narrative` | この野原には明かりがなく、太陽が山の向こうに落ちてきています。審判は今日がこの回が最後だと言いました。同点の場合は、明日からやり直します。 | 照明のない球場、日が山の向こうに沈みかけている。審判はこの回が今日最後だと告げた。同点なら明日、最初からやり直しだ。 |
| `content.important-game.game-rival-away.narrative` | ライバル校の遠征で、6回に失点。スタンドはマウンドをブーイングに包まれる。ボールを見るためにはノイズを消す必要があります。 | ライバル校での遠征、1点ビハインドの6回。マウンドに立つたびスタンドがブーイングで覆う。音を消さなければ球が見えない。 |
| `content.important-game.game-rival-rematch.narrative` | 同点6回に中堅打者が打席に入り、前回の投球順序を思い出した。 | 同点の6回、前の試合の配球順を覚えているクリーンアップが打席に入る。 |
| `content.important-game.game-sign-leak.narrative` | 二塁走者は打者に何かをチップしているように見える。彼らが兆候を破った場合、これはコースよりも神経が試されることになります。 | 相手の二塁走者が打者に何かを伝えている気配。サインが読まれているなら、ここからはコースより度胸の勝負だ。 |
| `content.important-game.game-third-look.narrative` | 今日は彼らの4番打者と3度目の対戦です。彼らは最初の2打席からのすべての投球を覚えている。同じシーケンスはもう機能しません。 | 今日3度目の対戦となる相手の4番。前の2打席の球を全部覚えているはずだ。同じ順番はもう通じない。 |
| `content.nickname.batting-practice.reason` | 1試合あたり4失点が許される――打者たちは打撃練習に来たと冗談を言う。 | 1試合4失点——相手打者が打撃練習に来ている、という嘲り。 |
| `content.nickname.flawless.reason` | %lld 四球がゼロの試合 — ゾーンを外すものは何もありません。 | %lld試合で四球0——ゾーンを外れる球がない。 |
| `content.nickname.k-hunter.reason` | %lld キャリア三振 — 2 ストライクで観客が立ち上がりました。 | 通算%lld奪三振——2ストライクで観客が立ち上がる。 |
| `content.nickname.k-monster.reason` | %lld キャリア三振 — 相手の打線はその名前だけで緊張する。 | 通算%lld奪三振——相手打線がその名前だけで揺れる。 |
| `content.nickname.nine-k.reason` | 1 試合あたり 6 つ以上の三振 - ほとんどのアウトを片腕で処理します。 | 1試合6奪三振以上——アウトの大半を一人で取る。 |
| `content.nickname.wild-thing.reason` | 1 試合あたり 3 四球 — 冗談は、投手ですらそれがどこへ行くか分からないということです。 | 1試合四球3個——本人もどこへ行くか分からない、というからかい。 |
| `content.nickname.workhorse.reason` | 全て完了しました %lld 高校公式戦、マウンドから降りることを拒否する腕。 | 高校公式戦%lld試合を全て投げ切った——マウンドを降りない肩。 |
| `content.nickname.zero.reason` | %lld 連続無得点試合 — まだ失点は許されない。 | %lld試合連続無失点——まだ1点も与えていない。 |
| `content.personality.closer.scout-line` | 決して後退しません。大事な試合で強打者相手に初速が上がるタイプ。 | 引き方を知らない。大きな試合、大きな打者の前で球速が上がるタイプ。 |
| `content.personality.opener.scout-line` | その瞬間に試合のどちら側が必要かを知っている。あらゆるクラブハウスにフィットし、機能します。 | 場面に合った顔を出せる。どのクラブハウスに置いても役目を果たすタイプ。 |
| `content.personality.tactician.scout-line` | 感情ではなく証拠を持って答えましょう。打者とのチェスの試合をデザインするのに十分賢い。 | 感情を抜いて根拠で答える。打者との駆け引きを自分で組み立てられる頭。 |
| `content.player-heart.arm-warning.words` | 今日は、ボールの前で私の腕を見てください。次の試合でも団結して戦いたいと思います。 | 今日は球より先に、私の腕を見てほしい。次の試合も一緒に立ちたいから。 |
| `content.player-heart.awakening.words` | どの球種を獲得するかよりも、どのような投手になるかを選択するのに役立ちます。 | どんな球を持つかより、どんな投手になるかを一緒に選んでください。 |
| `content.player-heart.chapter-review.words` | 少し時間を取って、私がどれだけ遠くまで来たのかを振り返ってください。私たちも次の答えを一緒に見つけていきたいです。 | ここまで来た私を、一度振り返ってください。次の物語でも一緒に答えを探したいです。 |
| `content.player-heart.completed-drafted.words` | 彼らは私の名前を呼びました。 3年間をかけてどこまでやれるか試してみるよ。 | 名前が呼ばれました。私たちの3年間も連れて、もっと遠くへ行ってみます。 |
| `content.player-heart.fatigue-warning.words` | 少し疲れました。あなたが私がいつ休むかを決めるのを手伝ってくれれば、私は再び自分の力を見つけることができます。 | 少し疲れました。休む日まで一緒に選んでくれれば、また力が出ます。 |
| `content.player-heart.legacy-drafted.words` | 彼らは私の名前を呼びました。 3年間をかけてどこまでやれるか試してみるよ。 | 名前が呼ばれました。私たちの3年間も連れて、もっと遠くへ行ってみます。 |
| `content.player-legacy.closing.memory-adaptable` | それぞれの状況で見つけた答えと選んだ思い出が、次の選手の始球式に引き継がれる。 | 場面ごとに見つけた答えと、私が選んだ記憶は、次の選手の初球につながります。 |
| `content.player-legacy.closing.memory-analyst` | 私の選択の背後にあるすべての理由と私が選択した思い出は、次の選手の始球式に引き継がれます。 | 毎回その球を選んだ理由と、私が選んだ記憶は、次の選手の初球につながります。 |
| `content.player-legacy.closing.memory-default` | 自分が選んだ思い出は次の選手の始球式に引き継がれる。 | 私が選んだ記憶は、次の選手の初球につながります。 |
| `content.player-legacy.closing.memory-steady` | 私が築いた静かな日々、選んだ思い出は次の選手の始球式に引き継がれる。 | 黙って積み重ねた日々と、私が選んだ記憶は、次の選手の初球につながります。 |
| `content.pro-decision.form_crisis.detail` | 最近の登板が揺れ、監督の信頼も薄くなっている。残りの週をどう耐えるか。 | 最近の登板が揺れ、監督の信頼も薄い。残りの週をどう耐えるか。 |
| `content.pro-decision.rival_analysis.detail` | 次の対戦までに、映画室の時間をどこで過ごすかを決めてください。 | 次の対戦に向け、分析の時間をどこに使うか決める。 |
| `content.relationship.evt-battery-dinner.quote.high` | 「今なら、目を閉じていてもあなたの 変化球 を捕まえることができます。%@ があなたの手から離れた瞬間に、どこに落ちるかわかります。」 | 「もう%@の変化球は目をつぶっても捕れる。手を離れた瞬間にどこへ落ちるか見えるから。」 |
| `content.relationship.evt-body-remembers.quote.high` | 学んだことのないグリップが手に定着します。試してみると、本当に壊れてしまいます。 | 習ったことのないグリップが自然と手に収まる。投げてみると、本当に曲がる。 |
| `content.relationship.evt-body-remembers.quote.low` | 学んだことのないグリップが手に定着します。試してみると、本当に壊れてしまいます。 | 習ったことのないグリップが自然と手に収まる。投げてみると、本当に曲がる。 |
| `content.relationship.evt-body-remembers.quote.mid` | 学んだことのないグリップが手に定着します。試してみると、本当に壊れてしまいます。 | 習ったことのないグリップが自然と手に収まる。投げてみると、本当に曲がる。 |
| `content.relationship.evt-breaker-grip.quote.high` | “%@、打者は投球が来ることを知っていても、それを見逃してしまう可能性があります。必要なのはゾーンへの道だけだ。」 | 「%@、今のは打者が分かっていても届かない。ストライクで入る道さえ見つければいい。」 |
| `content.relationship.evt-breaker-grip.quote.low` | 「よく壊れますが、私のミットではなくあなたの足に着地します。それは試合では言えません。」 | 「よく曲がるけど、ミットじゃなくて足元に落ちる。試合では要求できない。」 |
| `content.relationship.evt-breaker-grip.quote.mid` | 「このグリップはより壊れやすく、古いグリップはターゲットに到達します。どちらを先に救いますか?」 | 「このグリップは大きく曲がる。元のは狙った所に来る。どっちを先に生かす？」 |
| `content.relationship.evt-bullpen-first.quote.high` | 「%@、あなたの速球が流れると、次の球も流れます。今日は 1 つのバッテリー シーケンスを構築しましょう。」 | 「%@、直球が生きれば次の球も生きる。今日はバッテリーの配球を一つ作ろう。」 |
| `content.relationship.evt-bullpen-first.quote.low` | 「私はあなたの速球の後の変化球をまだ拾うことができません。それがあなたの手から離れてから初めてそれを見ることができます。」 | 「直球の次の変化球はまだ捕れない。手を離れてからやっと見える。」 |
| `content.relationship.evt-bullpen-rival.quote.high` | 「%@、そのグリップを見せてください。代わりに私のスライダーを教えて差し上げます。このチームが生き残るためには、私たち二人とも改善する必要があります。」 | 「%@、そのグリップ見せてよ。代わりに俺のスライダーの握り教える。二人とも伸びないとチームが持たない。」 |
| `content.relationship.evt-bullpen-rival.quote.mid` | 「あの新しい 変化球 グリップ…一度見せてもらえますか？ 1枠を争っているが、まだまだ学びたい」。 | 「その新しい変化球の握り…一度だけ見せてくれる？先発の座は奪い合う仲だけど、それでも学びたくて。」 |
| `content.relationship.evt-captain-talk.quote.high` | 「次の試合では、あなたにはもっと深く進んでもらいたいのです、%@。みんながあなたを頼りにしています。」 | 「次の試合は%@に長く投げてもらわないと。みんなそう思ってる。」 |
| `content.relationship.evt-captain-talk.quote.low` | 「次の試合で長いイニングを戦ってもらえますか？今どこにいるのか分からないので聞いています。」 | 「次の試合、長いイニング…任せられる？最近のお前がどうなのか分からなくて聞いてる。」 |
| `content.relationship.evt-captain-talk.quote.mid` | 「次の試合で長いイニングをやってもいいですか？それが多すぎるならそう言ってください。そのほうがチームのためになります。」 | 「次の試合、長いイニング頼める？無理なら無理って言え。その方がチームのためだ。」 |
| `content.relationship.evt-catcher-doubt.quote.high` | 「最近、振り切る球が良くなりましたね、%@。見てみたいです。」 | 「最近、%@が首を振った後の球の方がいい。お前が見てるものを俺も見たい。」 |
| `content.relationship.evt-catcher-doubt.quote.low` | 「あらゆる兆候を振り切るつもりなら、試合全体を自分でコールしてください。…なぜ私は打席の後ろにいるのですか？」 | 「そんなにサインを拒むなら、マウンドで全部一人で決めろ。…俺は何のために座ってるんだ？」 |
| `content.relationship.evt-catcher-doubt.quote.mid` | 「あなたは私の気配を振り払い続けています。何か見落としているのでしょうか？」 | 「最近、俺のサインをやたら拒むだろ。俺が見落としてることがあるのか？」 |
| `content.relationship.evt-catcher-sign.quote.high` | 「今日は 3 つの変更すべてがうまくいきました。私はあなたの提案を誰よりもよく知っています、%@」 | 「三回変えたの、今日は全部当たった。%@の球はもう俺が一番よく分かってる。」 |
| `content.relationship.evt-catcher-sign.quote.low` | 「それは 3 つのバツ印です。…すべてを変えるつもりなら、なぜわざわざバッテリーとして働く必要がありますか?」 | 「またサインが三回変わった。…これじゃ、なんで俺とバッテリー組むんだ？」 |
| `content.relationship.evt-catcher-sign.quote.mid` | 「今日は標識を3回変えました。何を見逃したでしょうか？」 | 「今日はサインが三回も変わった。俺が見逃したのは何だった？」 |
| `content.relationship.evt-coach-bench.quote.high` | 「一日かけて、 %@。あなたが無理をしすぎていることを知ってあなたを送り出すとしたら、それは私の責任です。」 | 「一日休め。%@が無理してると分かってて出したら、それは俺の責任だ。」 |
| `content.relationship.evt-coach-bench.quote.low` | 「今日は座っていますね。自分の気持ちを隠す投手は信用できません」。 | 「今日は外す。体の状態を隠す選手は、長くは信じられない。」 |
| `content.relationship.evt-coach-bench.quote.mid` | 「あなたはこの登板をサボっています。最近あなたの腕は他の人よりも一歩遅れています。」 | 「今回の登板は休め。最近は腕が体より遅れて来てる。」 |
| `content.relationship.evt-coach-last-advice.quote.high` | 「最後のトレーニングはあなたのものです、%@。私は 3 年間あなたを見てきました。あなたの判断を信頼するときが来ました。」 | 「最後の練習は%@、お前に任せる。三年見てきた。そろそろお前の判断を信じてもいい頃だ。」 |
| `content.relationship.evt-coach-last-advice.quote.low` | 「これが最後のトレーニングです。…まだ私があなたのために選ばなければなりませんか？もしあなたが自分で選ぶことができなければ、プロボールはさらに難しくなるでしょう。」 | 「最後の練習だ。…まだ俺が決めてやらなきゃいけないのか。自分で選べなきゃ、プロではもっと迷うぞ。」 |
| `content.relationship.evt-coach-last-advice.quote.mid` | 「あなたは最後のトレーニングを選択しました。まだ足りないものは何ですか?」 | 「最後の練習はお前が決めろ。今一番足りないのは何だ？」 |
| `content.relationship.evt-coach-role.quote.low` | 「先発投手はまだ先のことだ。ブルペンからスタートする。…理由を尋ねるのではなく、もっと球を投げてもいいのに。」 | 「先発はまだ早い。ブルペンから始めろ。…理由を問う暇があったら、もう一球投げてみろ。」 |
| `content.relationship.evt-coach-role.quote.mid` | 「あなたは次のトーナメントでブルペンから先発することになります。遅いイニングにはあなたが必要です。」 | 「次の大会はブルペンから始める。試合の後半を任せる。」 |
| `content.relationship.evt-command-wall.quote.low` | 「打者が一歩踏み出すと、すべての投球がハンドスパンで外れてしまったら、ブルペンのミットを打つ意味がありません。」 | 「ブルペンのミットに当てて何になる。打者が立てばまた一つ分外れるのに。」 |
| `content.relationship.evt-command-wall.quote.mid` | 「打者が立った瞬間に前足が開く。ボールの前に目を向けましょう」。 | 「打者が立った瞬間に前足が早く開く。球じゃなく、まず目線を直そう。」 |
| `content.relationship.evt-draft-projection.quote.high` | 「%@、時々、フィールドが記事よりも遅れて移動することがあります。もう 1 回開始すると、ボードを変更する理由が得られる可能性があります。」 | 「%@、記事より現場が遅れて動く時もある。次の登板があれば、評価を変える根拠ができる。」 |
| `content.relationship.evt-draft-projection.quote.mid` | 「予測ではあなたは2ラウンド上回っていました。私たちはあなたの最後の3試合での指揮をより重視しています。」 | 「予想順位は二ラウンド上だったな。うちは直近三試合の制球をもっと重く見る。」 |
| `content.relationship.evt-drafted-call.quote.high` | 「%@、私たちは皆さんの最も得意なことを消さずに 1 年目をデザインしました。それを組み合わせてみましょう。」 | 「%@選手、今の長所を消さない範囲で一年目を設計しました。一緒に合わせていきましょう。」 |
| `content.relationship.evt-drafted-call.quote.mid` | 「ファーストシーズンプランは、まず体を作り、ちょっとした登板から始めます。皆さんのご意見もお待ちしています。」 | 「一年目はまず体を作り、短いイニングから始める計画です。本人の考えも聞きたい。」 |
| `content.relationship.evt-exam-week.quote.high` | 「%@、あなたの試験は遠征と重なっています。あなたならきっと乗り越えられると思いますので、この話は短くします。ほんの数日です。」 | 「%@、試験と遠征が重なったな。自分でやれるのは分かってるから長くは言わない。数日だけだ。」 |
| `content.relationship.evt-exam-week.quote.mid` | 「試験と遠征が重なっています。本を読むにも数日は必要です。…野球はまだここにあります。」 | 「試験と遠征が重なったな。球と同じくらい、本も数日は握れ。…野球は逃げない。」 |
| `content.relationship.evt-first-awakening.quote.high` | リリース前はミットが近くに見えた。この動議はもう借用されませんでした。それは私のものでした。 | リリースの前からミットが近く見えた。もうこの動きは借り物の感覚じゃない、自分のものだった。 |
| `content.relationship.evt-first-awakening.quote.low` | 追いかける度に消えてしまうモーションが試合初登場。ボールの仕上がりは却下するにはあまりにも異なっていた。 | 練習で掴もうとするほど逃げていた動きが、試合で先に出た。偶然で済ませるには球の切れが違った。 |
| `content.relationship.evt-future-news.quote.high` | ラジオには、私の前世からの正確な順序でお気に入りのタイトルがリストされています。結末を知っている本がまた開いた。 | ラジオが今年の優勝候補を、前の人生と同じ順で読み上げる。結末を知っている本が、また最初の章を開いた。 |
| `content.relationship.evt-future-news.quote.low` | ラジオには、私の前世からの正確な順序でお気に入りのタイトルがリストされています。結末を知っている本がまた開いた。 | ラジオが今年の優勝候補を、前の人生と同じ順で読み上げる。結末を知っている本が、また最初の章を開いた。 |
| `content.relationship.evt-future-news.quote.mid` | ラジオには、私の前世からの正確な順序でお気に入りのタイトルがリストされています。結末を知っている本がまた開いた。 | ラジオが今年の優勝候補を、前の人生と同じ順で読み上げる。結末を知っている本が、また最初の章を開いた。 |
| `content.relationship.evt-glove-worn.quote.high` | 新しい手袋は最初から手のひらに向かって柔らかく折り畳まれます。これは、私が前世で何百回も閉じた角度とまったく同じです。 | 新しいグローブが最初から手のひらの内側へ柔らかく折れる。前の人生で何百回も閉じた、まさにその角度だ。 |
| `content.relationship.evt-glove-worn.quote.low` | 新しい手袋は最初から手のひらに向かって柔らかく折り畳まれます。これは、私が前世で何百回も閉じた角度とまったく同じです。 | 新しいグローブが最初から手のひらの内側へ柔らかく折れる。前の人生で何百回も閉じた、まさにその角度だ。 |
| `content.relationship.evt-glove-worn.quote.mid` | 新しい手袋は最初から手のひらに向かって柔らかく折り畳まれます。これは、私が前世で何百回も閉じた角度とまったく同じです。 | 新しいグローブが最初から手のひらの内側へ柔らかく折れる。前の人生で何百回も閉じた、まさにその角度だ。 |
| `content.relationship.evt-injury-rumor.quote.mid` | 「二度見してしまいました。よかったら、なぜ同じ場所を押すのですか？一緒にトレーナーのところに来てください。」 | 「二回見た。平気なら、なんで同じ所ばかり押すの？一緒にトレーナーの所へ行こう。」 |
| `content.relationship.evt-loaded-bases.quote.mid` | 「満塁で、私はゴロが欲しかったが、あなたは空振りを望んでいた。次は私たちが選択します。」 | 「満塁の初球、俺はゴロが欲しくて、お前は空振りを狙った。次は一つに決めよう。」 |
| `content.relationship.evt-lost-teammate.quote.high` | 前世で最後まで隣で投げたチームメイトが、今度はユニホームを脱いだ。 「私はこれで終わりです。あなたは投げ続けます」。 | 前の人生で最後まで一緒に投げた仲間が、今度はユニホームを脱いだ。「今回はここまでにする。お前は投げ続けろ」 |
| `content.relationship.evt-lost-teammate.quote.low` | 前世で最後まで隣で投げたチームメイトが、今度はユニホームを脱いだ。 「私はこれで終わりです。あなたは投げ続けます」。 | 前の人生で最後まで一緒に投げた仲間が、今度はユニホームを脱いだ。「今回はここまでにする。お前は投げ続けろ」 |
| `content.relationship.evt-lost-teammate.quote.mid` | 前世で最後まで隣で投げたチームメイトが、今度はユニホームを脱いだ。 「私はこれで終わりです。あなたは投げ続けます」。 | 前の人生で最後まで一緒に投げた仲間が、今度はユニホームを脱いだ。「今回はここまでにする。お前は投げ続けろ」 |
| `content.relationship.evt-mechanics-camera.quote.high` | 「%@、たった 2 フレームです。あなたの体は今日もそれらを見つけることができます。」 | 「%@、差はたった2フレームだ。お前の体なら今日中に取り戻せる」 |
| `content.relationship.evt-mechanics-camera.quote.low` | 「気分は大丈夫だと言えますが、カメラはリリースが早いことを示しています。ハイミスは今後も続くでしょう。」 | 「本人が大丈夫だと言っても、映像では手が先に出ている。このままだと高めに抜け続けるぞ」 |
| `content.relationship.evt-memory-ache.quote.high` | 今週は前回腕が折れた週です。何も痛くないのに、その場所が気になって仕方がありません。 | 前回、腕が壊れたのと同じ週だ。痛くはないのに、あの場所がずっと気になる。 |
| `content.relationship.evt-memory-ache.quote.low` | 今週は前回腕が折れた週です。何も痛くないのに、その場所が気になって仕方がありません。 | 前回、腕が壊れたのと同じ週だ。痛くはないのに、あの場所がずっと気になる。 |
| `content.relationship.evt-memory-ache.quote.mid` | 今週は前回腕が折れた週です。何も痛くないのに、その場所が気になって仕方がありません。 | 前回、腕が壊れたのと同じ週だ。痛くはないのに、あの場所がずっと気になる。 |
| `content.relationship.evt-national-stage.quote.high` | 「今日の放送はあなたを中心に構成されています、%@。いつものように投げるだけで、ストーリーは自動的に処理されます。」 | 「今日は%@を中心に撮る。いつも通りやれば、絵は勝手についてくる」 |
| `content.relationship.evt-national-stage.quote.low` | 「今日はブルペンからカメラがあなたを監視しています。それが気になるなら、それはそういうことです」 | 「今日はブルペンからカメラがつく。気になるなら仕方ないが」 |
| `content.relationship.evt-national-stage.quote.mid` | 「ブルペンから何本か打ちます。いつものように投げます。…それが一番難しいですよね」。 | 「今日はブルペンから少し撮らせてもらう。いつも通り投げて。…いつも通りが一番難しいだろ？」 |
| `content.relationship.evt-new-catcher.quote.high` | 「昔ながらの標識はまだ自然に感じられます。しかし、快適なものを使用しましょう。%@ 調整できます。」 | 「前の学校のサインの方が手に馴染んでる。でも%@がやりやすい方でいこう。俺が合わせる」 |
| `content.relationship.evt-new-catcher.quote.low` | 「私たちは母校でこれらの標識を使用していました。…とにかくすべてを呼び出すつもりなら、何でも使ってください。」 | 「前の学校ではこのサインを使ってた。…どうせ全部お前が決めるなら、何でもいいけど」 |
| `content.relationship.evt-new-catcher.quote.mid` | 「この看板は母校で使っていました。次の試合で試してみませんか？」 | 「前の学校ではこのサインを使ってた。うちも次の試合から変えてみない？」 |
| `content.relationship.evt-parent-call.quote.high` | 「試合を見ました。よく頑張りました。…ドラフト後もプレーし続けるんですよね？何を選んでも、ちゃんと食べてください」 | 「試合、見たよ。よくやってた。…ドラフトが終わっても続けるんだろ？何をするにしても、ご飯はちゃんと食べなさい」 |
| `content.relationship.evt-parent-call.quote.low` | 「最近電話してないね。…ドラフト後は何を考えているの？」 | 「最近、連絡がないね。…ドラフトが終わったら、どうするつもりなの」 |
| `content.relationship.evt-parent-call.quote.mid` | 「ドラフト後もプレーを続けるつもりですよね？…まだ答えなくても大丈夫です。ちゃんと食べていますか？」 | 「ドラフトが終わっても続けるんだろ？…いや、返事はゆっくりでいい。ご飯はちゃんと食べてるの」 |
| `content.relationship.evt-rain-delay.choice.challenge.detail` | 滑らかなボールを考慮しながら打者のタイミングを奪います。 | 打者のタイミングを奪う分、濡れたボールの滑りも計算に入れる |
| `content.relationship.evt-rain-delay.quote.high` | 「%@、手はまだ冷たいですよね？低めにセットします。初球は一緒にキャッチしましょう。」 | 「%@、手はまだ冷たいだろ？低めに構えてやる。初球から一緒に取ろう」 |
| `content.relationship.evt-rain-delay.quote.low` | 「腕が冷たいのに全力で開きたいのですか？今決めてください。二度と私を振り落とさないでください。」 | 「腕が冷えてるのに初球から強く行くのか？またサインを変えるな、今決めろ」 |
| `content.relationship.evt-rain-delay.quote.mid` | 「準備球は５球しかない。一番早く手元に戻ってくる球で開幕させよう」。 | 「ブルペンで5球しか投げられない。初球は一番早く手に馴染む球でいこう」 |
| `content.relationship.evt-recovery-day.quote.high` | 「%@、今日休めば、明日は良い投球を20回セーブできる。あなたなら違いがわかると信じています。」 | 「%@、今日休めば次のブルペンの20球が生きる。その違いがわかる選手だと信じている」 |
| `content.relationship.evt-recovery-day.quote.low` | 「隣で誰が投げていても、それが誰の腕なのかは変わりません。今日ボールを拾えば、明日はもっと重く感じるでしょう。」 | 「隣で誰が投げていようと、お前の腕はお前の腕だ。今日また握れば、明日から球が重くなる」 |
| `content.relationship.evt-remembered-pitch.choice.challenge.detail` | 記憶を利用してエンディングを変更し、次のヒットがさらに深くなることがわかっています。 | 記憶を使って結末を変える。ただ、また打たれれば傷は深くなる |
| `content.relationship.evt-remembered-pitch.quote.high` | 前世での得点の瞬間の緊張感が戻ってきた。何も知らずに捕手は決め球をコールした。 「ほら。どうですか？」 | 前の人生で失点した瞬間に似た緊張が戻ってきた。捕手は何も知らずに決め球のサインを出す。「ここ、どうだ？」 |
| `content.relationship.evt-remembered-pitch.quote.low` | 前世での得点の瞬間の緊張感が戻ってきた。何も知らずに捕手は決め球をコールした。 「ほら。どうですか？」 | 前の人生で失点した瞬間に似た緊張が戻ってきた。捕手は何も知らずに決め球のサインを出す。「ここ、どうだ？」 |
| `content.relationship.evt-remembered-pitch.quote.mid` | 前世での得点の瞬間の緊張感が戻ってきた。何も知らずに捕手は決め球をコールした。 「ほら。どうですか？」 | 前の人生で失点した瞬間に似た緊張が戻ってきた。捕手は何も知らずに決め球のサインを出す。「ここ、どうだ？」 |
| `content.relationship.evt-rival-deja-vu.quote.high` | 彼は箱から私を研究します。 「私たちはどこかで顔を合わせたことがあるだろうか？」 | 打席の彼がじっと見てくる。「俺たち…どこかでやり合ったことあるか？」 |
| `content.relationship.evt-rival-deja-vu.quote.low` | 彼は箱から私を研究します。 「私たちはどこかで顔を合わせたことがあるだろうか？」 | 打席の彼がじっと見てくる。「俺たち…どこかでやり合ったことあるか？」 |
| `content.relationship.evt-rival-deja-vu.quote.mid` | 彼は箱から私を研究します。 「私たちはどこかで顔を合わせたことがあるだろうか？」 | 打席の彼がじっと見てくる。「俺たち…どこかでやり合ったことあるか？」 |
| `content.relationship.evt-rival-final.quote.high` | 彼は握り直し、静かに話す。 「%@。これが最後だ。最高の投球を持ってきてください。そうすれば、私たちもそれを忘れることはありません。」 | 打席に入った彼がバットを握り直し、低く言う。「%@。最後だな。一番いい球で来い。勝っても負けても、それなら残る」 |
| `content.relationship.evt-rival-final.quote.low` | 捕手ミットを見ずに笑みを浮かべた。 「とにかく、あなたはそこに投げます。私はあなたのことを知っています。」 | 打席の彼は捕手のミットも見ずに笑う。「どうせそこに来るんだろ。全部わかってる」 |
| `content.relationship.evt-rival-final.quote.mid` | 彼は前の試合と同じ場所にバットを向けた。 「あのコーナーをもう一度試してください。」 | 打席に入った彼が、前の試合と同じコースをバットの先で指す。「もう一回ここに投げてみろよ」 |
| `content.relationship.evt-rival-message.quote.high` | 「次の始球式を当ててほしいですか、%@？…いいえ、むしろ自分の目で見てみたいです。」 | 「%@の次の初球、何を投げるか当ててやろうか。…いや、あれは自分の目で見た方がいいな」 |
| `content.relationship.evt-rival-video.quote.high` | 「%@。私はついにあなたの最高のフォーシームに追いつきました。…それを達成するのに3年かかりました。」スマイリーがクリップを閉じました。 | 「%@。高めのフォーシーム、やっと捉えた。…これ一つ捉えるのに3年かかったけどな」動画の最後に笑顔のマークがついていた。 |
| `content.relationship.evt-scout-stand.choice.challenge.detail` | セッション後半の制球も公開しながら上位を追いかけます。 | 最高球速を狙うが、力が落ちた後の制球も一緒に見られる |
| `content.relationship.evt-scout-stand.quote.low` | 「レーダーの読み取り以外にも書くべきことはたくさんあります。配信を繰り返すことができるかどうか注目しています。」 | 「スコアボードの数字以外にも書くことは多い。同じフォームでもう一度投げられるか、見せてもらう」 |
| `content.relationship.evt-team-slump.quote.mid` | 「私たちは選択する必要があります。個人の仕事を増やすか、全員が早退するかです。沈黙しても責任は取り除かれません。」 | 「自主練を増やすか、全員で早く切り上げるか決めないと。黙ってる人も責任は同じだ」 |
| `content.relationship.evt-undrafted-deja.choice.challenge.detail` | 同じ沈黙に直面しなければならないかもしれないことを知っているので、逃げることを拒否してください。 | 逃げはしない。ただ同じ沈黙が来たら、正面から耐えるしかない |
| `content.relationship.evt-undrafted-deja.quote.high` | 放送が入った瞬間、名前を呼ばれなかった部屋の空気が戻ってくる。第一次選考はまだ始まっていません。 | 中継画面がつくと、最後まで名前を呼ばれなかった部屋の空気が先に戻ってきた。まだ一巡目も始まっていない。 |
| `content.relationship.evt-undrafted-deja.quote.low` | 放送が入った瞬間、名前を呼ばれなかった部屋の空気が戻ってくる。第一次選考はまだ始まっていません。 | 中継画面がつくと、最後まで名前を呼ばれなかった部屋の空気が先に戻ってきた。まだ一巡目も始まっていない。 |
| `content.relationship.evt-undrafted-deja.quote.mid` | 放送が入った瞬間、名前を呼ばれなかった部屋の空気が戻ってくる。第一次選考はまだ始まっていません。 | 中継画面がつくと、最後まで名前を呼ばれなかった部屋の空気が先に戻ってきた。まだ一巡目も始まっていない。 |
| `content.relationship.evt-undrafted-room.quote.low` | 最終的な名前が通りました。部屋には光る放送と3年分の数字だけが残った。 | 最後の名前まで過ぎた。部屋には消えない中継画面と、3年分の数字だけが残った。 |
| `content.relationship.evt-undrafted-room.quote.mid` | 電話は来なかった。スコアブックを開いたとき、支配した日よりも復帰した日が目立ちました。 | 電話は来なかった。スコアブックを開くと、よく投げた日より、もう一度投げた日が先に目に入った。 |
| `content.relationship.evt-winter-weight.choice.listen.detail` | 出産が硬くならないように、冬の間ずっと同じ腕の動かし方を保ちます。 | 冬の間ずっと同じ腕の軌道を保ち、投球フォームが固まるのを防ぐ |
| `content.relationship.evt-winter-weight.quote.high` | 「%@、あなたの体は力を加える準備ができています。しかし、この簡単な腕の動きも資産です。選択するのはあなたです。」 | 「%@、体は力を受け入れる準備ができている。ただ、今の柔らかい腕の軌道も財産だ。お前が選べ」 |
| `content.weekly-task.played_on_two_days.next-action` | 高校でもプロでも、今日はある試合に投げ、別の日に別の試合に投げます。 | 今日1試合、別の日に1試合。高校でもプロでも可。 |

## 5. 새로 추가된 키 (39)

| 키 | ko | en |
|---|---|---|
| `settings.reading-size` | 글자 크기 | Text size |
| `settings.reading-size.standard` | 표준 | Standard |
| `settings.reading-size.large` | 크게 | Large |
| `settings.reading-size.extra-large` | 아주 크게 | Extra large |
| `settings.reading-size.footer` | 기기 설정보다 작아지지는 않아요. 큰 쪽을 따릅니다. | Never smaller than your device setting. The larger of the two wins. |
| `glossary.term.action` | %@ 뜻 보기 | Define %@ |
| `meta.weekly.rules.title` | 노트 규칙 | How the notes work |
| `meta.weekly.rules.summary` | 셋 중 둘이면 도장. 놓쳐도 벌점 없음. | Two of three earns a stamp. No penalty for missing. |
| `pitch.catcher.rationale.title` | 포수의 생각 | Catcher's read |
| `pitch.catcher.chip.confidence` | 사인 확신 %lld%% | Call confidence %lld%% |
| `pitch.catcher.chip.trust` | 포수 호흡 %lld · %@ | Catcher trust %lld · %@ |
| `pitch.build.chip.movement` | 움직임 %lld | Movement %lld |
| `pitch.build.chip.command` | 코스 %lld | Location %lld |
| `pitch.build.chip.fatigue` | 체감 피로 %lld | Effective fatigue %lld |
| `pro.weekly.injury-chip` | 부상 %@ | Injury %@ |
| `pro.weekly.gain-chip` | %@ ▲ | %@ ▲ |
| `pro.weekly.delta.caption` | 이번 주 %@ | This week %@ |
| `pro.weekly.option.detail-title` | 효과와 부담 | Effect and cost |
| `training.chip.gain` | %@ ▲ | %@ ▲ |
| `training.chip.fatigue` | 피로 %+lld | Fatigue %+lld |
| `training.chip.arm-recovery` | 팔 상태 회복 | Arm recovery |
| `training.chip.risk.high` | 부상 위험 높음 | Injury risk: high |
| `training.chip.risk.some` | 부상 위험 약간 | Injury risk: some |
| `training.chip.no-growth` | 능력 성장 없음 | No rating growth |
| `training.option.detail.title` | 자세히 | Details |
| `training.option.detail.summary` | 이 훈련의 효과와 대가. | What this training gives and costs. |
| `setup.region.group.title` | 권역 | Area |
| `setup.region.group.capital` | 수도권 | Capital area |
| `setup.region.group.chungcheong` | 충청 | Chungcheong |
| `setup.region.group.honam` | 호남 | Honam |
| `setup.region.group.yeongnam` | 영남 | Yeongnam |
| `setup.region.group.gangwon-jeju` | 강원·제주 | Gangwon · Jeju |
| `setup.inheritance.shop.guide.title` | 계승 포인트란 | About inheritance points |
| `setup.inheritance.shop.summary` | 이전 선수가 남긴 포인트로 이번 3년의 규칙을 삽니다. | Spend what the last player left on rules for this run. |
| `awakening.guide.title` | 읽는 법 | How to read this |
| `awakening.guide.summary` | 체크는 보유 스킬, ‘다음’은 다음 각성의 후보. | Checks are owned skills; ‘Next’ marks the next awakening's candidates. |
| `awakening.selection.title` | 고르는 법 | How choosing works |
| `awakening.selection.summary` | 고른 갈래의 다음 가지가 열림 · 남은 각성 %lld번 | Next node in this branch opens · %lld awakenings left |
| `conclusion.signature.guide.summary` | 고른 하나는 바로 이어지고, 나머지는 발견 목록에 남습니다. | One passes on now; the rest stay in your discovered list. |
