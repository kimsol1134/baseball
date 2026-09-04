package com.solkim.baseball.android

import androidx.compose.foundation.Image
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.solkim.baseball.application.AvatarParts
import com.solkim.baseball.application.AvatarRole
import com.solkim.baseball.design.BaseballColors

public enum class PlayerStage {
    FRESHMAN,
    ACE,
    PRO;

    public val assetPrefix: String
        get() = when (this) {
            FRESHMAN -> "portrait_player_young"
            ACE -> "portrait_player"
            PRO -> "portrait_player_pro"
        }
}

public object PlayerPortraitResolver {
    private val fixedVariants: Map<String, Int> = mapOf(
        "윤태문" to 1, "노재형" to 2, "오승렬" to 3, "배도환" to 4,
        "서준호" to 1, "한도윤" to 2, "차민석" to 3, "문하진" to 4,
    )

    private fun variants(role: AvatarRole): Int = when (role) {
        AvatarRole.COACH, AvatarRole.CATCHER -> 4
        AvatarRole.RIVAL -> 3
        AvatarRole.PLAYER -> 20
    }

    public fun resolveDrawableName(
        seed: String,
        role: AvatarRole,
        stage: PlayerStage = PlayerStage.ACE,
    ): String {
        val count = variants(role)
        val index = fixedVariants[seed] ?: (1 + (AvatarParts.hash("portrait:$seed") % count.toUInt()).toInt())
        return when (role) {
            AvatarRole.COACH -> "portrait_coach_$index"
            AvatarRole.CATCHER -> "portrait_catcher_$index"
            AvatarRole.RIVAL -> "portrait_rival_$index"
            AvatarRole.PLAYER -> "${stage.assetPrefix}_$index"
        }
    }
}

@Composable
public fun PlayerPortrait(
    seed: String,
    modifier: Modifier = Modifier,
    role: AvatarRole = AvatarRole.PLAYER,
    stage: PlayerStage = PlayerStage.ACE,
    width: Dp = 46.dp,
) {
    val context = LocalContext.current
    val resId = remember(seed, role, stage) {
        val primaryName = PlayerPortraitResolver.resolveDrawableName(seed, role, stage)
        var id = context.resources.getIdentifier(primaryName, "drawable", context.packageName)
        if (id == 0 && role == AvatarRole.PLAYER && stage != PlayerStage.ACE) {
            val fallbackName = PlayerPortraitResolver.resolveDrawableName(seed, role, PlayerStage.ACE)
            id = context.resources.getIdentifier(fallbackName, "drawable", context.packageName)
        }
        id
    }

    if (resId != 0) {
        Image(
            painter = painterResource(resId),
            contentDescription = null,
            contentScale = ContentScale.Crop,
            modifier = modifier
                .size(width, width * 76f / 58f)
                .clip(RoundedCornerShape(width * 0.16f))
                .border(1.dp, BaseballColors.border.copy(alpha = 0.5f), RoundedCornerShape(width * 0.16f)),
        )
    } else {
        AvatarFace(
            seed = seed,
            role = role,
            width = width,
            modifier = modifier,
        )
    }
}
