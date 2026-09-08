package com.solkim.baseball.application

/** Translate visible copy while retaining all command IDs, captured payloads and save values. */
public fun Phase8ScreenModel.localized(copy: GameCopy, state: GameAggregateState): Phase8ScreenModel {
    val userTexts = if (state.meta.seedChallenge != null) emptySet() else buildSet {
        state.highSchool?.run?.identity?.name?.let(::add)
        state.pro?.identityName?.let(::add)
        state.highSchool?.archive.orEmpty().forEach { add(it.playerName) }
        state.meta.retiredProCareers.forEach { add(it.identityName) }
    }
    fun player(value: String) = value.replace("{player}", if (state.meta.seedChallenge != null) copy.resolve("android.challenge.player") else state.highSchool?.run?.identity?.name.orEmpty())
    fun text(value: String) = player(copy.legacy(value, userTexts))
    return this.copy(title = text(title), subtitle = text(subtitle),
        sections = sections.map { section -> section.copy(title = if (section.id.startsWith("retired:")) section.title else copy.legacy(section.title), rows = section.rows.map {
            val isPlayerName = it.label in setOf("선수", "이름", "지난 생", "기시감") && it.value in userTexts
            it.copy(label = copy.legacy(it.label), value = if (isPlayerName) it.value else if (it.label in setOf("구종", "주 구종", "실전 구종", "연습 구종")) copy.legacy(it.value) else text(it.value), detail = if (section.id == "rebirth" && it.label == "이어지는 힘") state.highSchool?.inheritance?.selectedSignatureLegacyId?.let { id -> SignatureLegacyDisplay.effect(id, copy) } ?: text(it.detail) else text(it.detail))
        }) },
        actions = actions.map { it.copy(label = copy.legacy(it.label), description = if (it.effects.isNotEmpty()) ChoiceEffect.summary(it.effects, copy) else if (it.id.startsWith("selectLegacy:") || it.id.startsWith("selectProLegacy:")) SignatureLegacyDisplay.effect(it.id.substringAfter(':'), copy) ?: text(it.description) else text(it.description)) },
    )
}
