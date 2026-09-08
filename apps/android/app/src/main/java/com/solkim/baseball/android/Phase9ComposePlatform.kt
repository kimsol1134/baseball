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
import com.solkim.baseball.android.LocalizedGameText as Text
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
        Phase8ScreenId.P028_LIFECARD -> Phase9ShareSurface(
            state,
            model,
            selectedLifeCardCareerId,
            onSelectedLifeCardCareerIdChanged,
            onAction,
        )
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
                modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp),
            ) { Text("알림 켜기") }
            androidx.compose.material3.TextButton(
                onClick = { onAction(capturePlatformAction(state, screen, PlatformAction.DISMISS_REMINDER_OFFER)) },
                modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp),
            ) { Text("이번에는 괜찮아요") }
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
                        title = com.solkim.baseball.application.CareerShareCopy.LIFE_CARD_TITLE,
            text = it.text,
            lines = it.lines,
            careerId = it.careerId,
            lifeNumber = it.lifeNumber,
        )
    }
    val shareAllowed = sharePayload != null && state.highSchool?.challenge?.active != true
    Card(colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant)) {
        Column(Modifier.padding(20.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            Text("카드 공유", style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
            Text("한 생을 카드 한 장으로. 이미지와 글이 함께 나간다.", style = MaterialTheme.typography.bodyLarge)
            selectedId?.let { LifeCardVisual(state, it) }
            state.highSchool?.archive.orEmpty().asReversed().forEach { record ->
                SetupSelectionButton(
                    selected = record.careerId == selectedId,
                    onClick = { onSelectedLifeCardCareerIdChanged(record.careerId) },
                    modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp),
                ) {
                    Text("${record.lifeNumber}번째 생")
                }
            }
            Button(
                onClick = { sharePayload?.let { onAction(capturePlatformAction(state, model.id, PlatformAction.SHARE_LIFE_CARD, sharePayload = it)) } },
                enabled = shareAllowed,
                modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp).gameDescription(if (shareAllowed) "카드 공유" else "아직 마친 생이 없어 공유할 수 없다"),
            ) { Text("카드 공유") }
        }
    }
}

internal fun capturePlatformAction(
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
