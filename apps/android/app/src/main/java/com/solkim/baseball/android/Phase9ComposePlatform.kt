package com.solkim.baseball.android

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.solkim.baseball.application.GameAggregateState
import com.solkim.baseball.application.Phase8ScreenId
import com.solkim.baseball.application.Phase8ScreenModel
import com.solkim.baseball.application.Phase8ScreenProjection
import com.solkim.baseball.application.Phase9LifeCardProjection
import com.solkim.baseball.platform.LifeCardSharePayload
import com.solkim.baseball.platform.NotificationPermissionTruth
import com.solkim.baseball.platform.PlatformAction
import com.solkim.baseball.platform.PlatformActionCodec
import com.solkim.baseball.platform.PlatformActionPayload
import com.solkim.baseball.platform.ReviewGateDecision
import com.solkim.baseball.platform.ReviewReason
import com.solkim.baseball.platform.ReminderOfferPolicy

public data class Phase9PlatformUiState(
    public val notificationTruth: NotificationPermissionTruth,
    public val reviewDecision: ReviewGateDecision?,
    public val notificationPermissionAsked: Boolean = false,
    public val reminderOfferDeclined: Boolean = false,
)

public data class Phase9UiAction(
    public val encodedPayload: String,
    public val payload: PlatformActionPayload,
    public val sharePayload: LifeCardSharePayload? = null,
    public val reviewReason: ReviewReason? = null,
)

@Composable
public fun Phase9PlatformSurface(
    state: GameAggregateState,
    model: Phase8ScreenModel,
    platformState: Phase9PlatformUiState,
    selectedLifeCardCareerId: String? = null,
    onSelectedLifeCardCareerIdChanged: (String) -> Unit = {},
    onAction: (Phase9UiAction) -> Unit,
    onViewportExposure: (Phase9ViewportExposure) -> Unit = {},
) {
    when (model.id) {
        Phase8ScreenId.P011_HIGH_SCHOOL_CAREER -> Phase9ReminderOfferSurface(state, model.id, platformState, onAction)
        Phase8ScreenId.P027_SETTINGS -> Phase9SettingsSurface(state, model.id, platformState, onAction, onViewportExposure)
        Phase8ScreenId.P028_LIFECARD -> Phase9ShareSurface(
            state,
            model,
            selectedLifeCardCareerId,
            onSelectedLifeCardCareerIdChanged,
            onAction,
        )
        Phase8ScreenId.P030_REVIEW -> Phase9ReviewSurface(state, model.id, platformState)
        else -> Unit
    }
}

@Composable
private fun Phase9ReminderOfferSurface(
    state: GameAggregateState,
    screen: Phase8ScreenId,
    platformState: Phase9PlatformUiState,
    onAction: (Phase9UiAction) -> Unit,
) {
    if (!ReminderOfferPolicy.shouldShow(
            completedGameCount = state.highSchool?.completedGameCounter ?: 0UL,
            truth = platformState.notificationTruth,
            permissionAsked = platformState.notificationPermissionAsked,
            offerDeclined = platformState.reminderOfferDeclined,
            aggregateEnabled = state.settings.notificationsEnabled,
        )) return
    Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant)) {
        Column(Modifier.padding(20.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Text("첫 경기 뒤의 복귀 안내", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
            Text("다음 장면을 놓치지 않도록 기기 알림을 켤 수 있습니다.", style = MaterialTheme.typography.bodyLarge)
            Button(
                onClick = { onAction(capturePlatformAction(state, screen, PlatformAction.REQUEST_NOTIFICATION_PERMISSION)) },
                modifier = Modifier.fillMaxWidth().heightIn(min = 56.dp),
            ) { Text("알림 켜기") }
            androidx.compose.material3.TextButton(
                onClick = { onAction(capturePlatformAction(state, screen, PlatformAction.DISMISS_REMINDER_OFFER)) },
                modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp),
            ) { Text("이번에는 괜찮아요") }
        }
    }
}

@Composable
private fun Phase9SettingsSurface(
    state: GameAggregateState,
    screen: Phase8ScreenId,
    platformState: Phase9PlatformUiState,
    onAction: (Phase9UiAction) -> Unit,
    onViewportExposure: (Phase9ViewportExposure) -> Unit,
) {
    val truthText = when (platformState.notificationTruth) {
        NotificationPermissionTruth.ALLOWED -> "알림 켜짐"
        NotificationPermissionTruth.REQUESTABLE -> "알림 권한을 아직 확인하지 않음"
        NotificationPermissionTruth.DENIED -> "알림 권한이 필요함"
        NotificationPermissionTruth.BLOCKED -> "기기 설정에서 알림이 차단됨"
        NotificationPermissionTruth.UNAVAILABLE -> "이 기기에서는 알림을 사용할 수 없음"
    }
    Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant)) {
        Column(Modifier.padding(20.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Text("기기 알림", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
            Text(truthText, style = MaterialTheme.typography.bodyLarge)
            Text("복귀 계획이 있을 때만 저장된 안내를 예약합니다.", style = MaterialTheme.typography.bodyMedium)
            val action = if (platformState.notificationTruth == NotificationPermissionTruth.REQUESTABLE) {
                PlatformAction.REQUEST_NOTIFICATION_PERMISSION
            } else {
                PlatformAction.OPEN_NOTIFICATION_SETTINGS
            }
            OutlinedButton(
                onClick = { onAction(capturePlatformAction(state, screen, action)) },
                enabled = platformState.notificationTruth != NotificationPermissionTruth.UNAVAILABLE,
                modifier = Modifier.fillMaxWidth().heightIn(min = 56.dp).semantics { contentDescription = "기기 알림 설정. $truthText" },
            ) { Text(if (action == PlatformAction.REQUEST_NOTIFICATION_PERMISSION) "알림 권한 요청" else "알림 설정 열기") }
        }
    }
}

@Composable
private fun Phase9ShareSurface(
    state: GameAggregateState,
    model: Phase8ScreenModel,
    selectedLifeCardCareerId: String?,
    onSelectedLifeCardCareerIdChanged: (String) -> Unit,
    onAction: (Phase9UiAction) -> Unit,
) {
    val selectedId = selectedLifeCardCareerId ?: state.highSchool?.archive?.lastOrNull()?.careerId
    val card = Phase9LifeCardProjection.selected(state, selectedId)
    val sharePayload = card?.let {
        LifeCardSharePayload(
            title = "마운드의 계절 · 라이프 카드",
            text = it.text,
            lines = it.lines,
            careerId = it.careerId,
            lifeNumber = it.lifeNumber,
        )
    }
    val shareAllowed = sharePayload != null && state.highSchool?.challenge?.active != true
    Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant)) {
        Column(Modifier.padding(20.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Text("라이프 카드 공유", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
            Text("카드 이미지와 한국어 글을 함께 기기의 공유 화면으로 보냅니다.", style = MaterialTheme.typography.bodyLarge)
            selectedId?.let { LifeCardVisual(state, it) }
            state.highSchool?.archive.orEmpty().asReversed().forEach { record ->
                OutlinedButton(
                    onClick = { onSelectedLifeCardCareerIdChanged(record.careerId) },
                    modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp),
                ) {
                    Text(if (record.careerId == selectedId) "선택됨 · ${record.lifeNumber}번째 생" else "${record.lifeNumber}번째 생 기록 선택")
                }
            }
            Button(
                onClick = { sharePayload?.let { onAction(capturePlatformAction(state, model.id, PlatformAction.SHARE_LIFE_CARD, sharePayload = it)) } },
                enabled = shareAllowed,
                modifier = Modifier.fillMaxWidth().heightIn(min = 56.dp).semantics {
                    contentDescription = if (shareAllowed) "라이프 카드 공유. 이미지와 한국어 글을 함께 준비합니다." else "보관된 생이 없어 공유할 수 없음"
                },
            ) { Text("라이프 카드 공유") }
        }
    }
}

@Composable
private fun Phase9ReviewSurface(
    state: GameAggregateState,
    screen: Phase8ScreenId,
    platformState: Phase9PlatformUiState,
) {
    val reason = Phase8ScreenProjection.reviewTrigger(state)?.let(::reviewReason)
    val decision = platformState.reviewDecision
    Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant)) {
        Column(Modifier.padding(20.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Text("리뷰 안내", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
            Text(reason?.label ?: "아직 리뷰를 묻는 장면이 아닙니다.", style = MaterialTheme.typography.bodyLarge)
            Text(if (decision?.eligible == true) "이유별 한 번, 요청 사이 24시간 간격을 지킵니다." else "같은 이유로 반복해서 묻지 않습니다.", style = MaterialTheme.typography.bodyMedium)
            Text("리뷰 요청은 실제 결산 확인 또는 새 생 시작 직후에만 표시됩니다.", style = MaterialTheme.typography.bodyMedium)
        }
    }
}

private data class ReviewReasonUi(val reason: ReviewReason, val label: String)

private fun reviewReason(trigger: String): ReviewReasonUi? = when (trigger) {
    "third-life" -> ReviewReasonUi(ReviewReason.THIRD_LIFE, "세 번째 생의 결산을 마쳤습니다.")
    "good-recap" -> ReviewReasonUi(ReviewReason.GOOD_RECAP, "좋은 결산을 확인했습니다.")
    "drafted-reveal-confirmed" -> ReviewReasonUi(ReviewReason.DRAFTED_REVEAL_CONFIRMED, "드래프트 결과를 확인했습니다.")
    else -> null
}

private fun capturePlatformAction(
    state: GameAggregateState,
    screen: Phase8ScreenId,
    action: PlatformAction,
    sharePayload: LifeCardSharePayload? = null,
    reviewReason: ReviewReason? = null,
): Phase9UiAction {
    val parameters = buildMap {
        sharePayload?.let {
            put("share", it.text)
            put("career_id", it.careerId)
            put("life_number", it.lifeNumber.toString())
        }
        reviewReason?.let { put("reason", it.wire) }
    }
    val payload = PlatformActionPayload(
        screenWire = screen.wire,
        action = action,
        expectedRevision = state.revision,
        stateCommitment = state.commitment,
        parameterHash = PlatformActionCodec.parameterHash(parameters),
    )
    return Phase9UiAction(PlatformActionCodec.encode(payload), payload, sharePayload, reviewReason)
}
