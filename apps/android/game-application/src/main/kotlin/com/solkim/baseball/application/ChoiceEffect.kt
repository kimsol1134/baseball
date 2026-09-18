package com.solkim.baseball.application

/** Semantic effects survive localization; costs never disappear because they were third in a string list. */
public data class ChoiceEffect(val label: String, val delta: Int? = null, val favorable: Boolean = true) {
    public val source: String get() = if (delta == null) label else "$label ${if (delta > 0) "+" else ""}$delta"
    private fun trainingSupport(): TrainingFocus? = TrainingFocus.entries.firstOrNull {
        label == "다음 ${TrainingPresentation.title(it)} 지원"
    }
    public fun localized(copy: GameCopy): String {
        trainingSupport()?.let { return trainingSupportLabel(it, copy) }
        return if (delta == null) copy.legacy(label) else copy.resolve("improve.effect.delta",
            GameCopyArgument.UserText(copy.legacy(label)), GameCopyArgument.UserText("${if (delta > 0) "+" else ""}$delta"))
    }
    public fun explanation(copy: GameCopy): String? = trainingSupport()?.let {
        copy.resolve("conversation.support.explanation", GameCopyArgument.UserText(copy.legacy(TrainingPresentation.title(it))))
    }
    public companion object {
        public fun trainingSupportLabel(focus: TrainingFocus, copy: GameCopy): String = copy.resolve("conversation.support.reward",
            GameCopyArgument.UserText(copy.legacy(TrainingPresentation.title(focus))))
        public fun fromSource(source: String): ChoiceEffect {
            if (source == "부상 · 재활 필요") return ChoiceEffect(source, favorable = false)
            val match = Regex("^(.*) ([+−-][0-9]+)$").matchEntire(source) ?: return ChoiceEffect(source)
            val label = match.groupValues[1]
            val delta = match.groupValues[2].replace('−', '-').toInt()
            return ChoiceEffect(label, delta, if (label in setOf("피로", "팔 부담", "실점", "부상 위험")) delta <= 0 else delta >= 0)
        }
        public fun highlighted(effects: List<ChoiceEffect>): List<ChoiceEffect> {
            val costs = effects.filter { !it.favorable }
            return if (costs.isEmpty()) effects.take(2) else listOfNotNull(effects.firstOrNull { it.favorable }) + costs
        }
        public fun summary(effects: List<ChoiceEffect>, copy: GameCopy = GameCopy(GameLanguage.KOREAN)): String {
            val shown = highlighted(effects)
            val extra = (effects.size - shown.size).coerceAtLeast(0)
            return (shown.map { it.localized(copy) } + listOfNotNull(
                if (extra > 0) copy.resolve("improve.effect.more", GameCopyArgument.Whole(extra.toLong())) else null)).joinToString(" · ")
        }
    }
}
