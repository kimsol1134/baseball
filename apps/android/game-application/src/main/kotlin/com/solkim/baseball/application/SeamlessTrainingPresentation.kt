package com.solkim.baseball.application

import com.solkim.baseball.core.highschool.HighSchoolPhase

public data class NextTrainingPreview(
    val state: GameAggregateState,
    val advancePayloads: List<Phase8CommandPayload>,
)

/** Show the next playable choice without spending the optional outing or writing a preview. */
public object SeamlessTrainingPresentation {
    public fun next(state: GameAggregateState, context: Phase8CommandContext): NextTrainingPreview? {
        if (state.highSchool?.run?.phase != HighSchoolPhase.CHAPTER_REVIEW ||
            state.highSchool.run.chapter.number >= com.solkim.baseball.core.highschool.HighSchoolContentCatalog.chapters.size) return null
        val advance = Phase8ScreenProjection.project(state, Phase8ScreenId.P010_CHAPTER, context)
            .actions.singleOrNull { it.id == "advanceChapter" && it.enabled } ?: return null
        val command = (advance.payloads.single().envelope.command as GameCommand.HighSchool).command as
            com.solkim.baseball.core.highschool.HighSchoolPhase4Command.AdvanceChapter
        // Simulate only the career rules. Native saves have their own receipt chain and must
        // never be fed through the shadow aggregate reducer just to render a screen.
        val school = com.solkim.baseball.core.highschool.HighSchoolPhase4Kernel().advanceChapter(command.seed, state.highSchool).state
        val next = state.copy(highSchool = school).let { it.copy(commitment = it.recomputeCommitment()) }
        require(school.run.phase == HighSchoolPhase.TRAINING) { "training.next_phase" }
        return NextTrainingPreview(next, advance.payloads)
    }

    /** The advance and selected training are one captured interaction with consecutive revisions. */
    public fun commit(state: GameAggregateState, preview: NextTrainingPreview, training: List<Phase8CommandPayload>): List<Phase8CommandPayload> {
        require(state.highSchool?.run?.phase == HighSchoolPhase.CHAPTER_REVIEW) { "training.bridge_phase" }
        require(preview.advancePayloads.first().envelope.expectedRevision == state.revision) { "training.bridge_stale" }
        require(training.isNotEmpty() && training.all { it.screenId == Phase8ScreenId.P006_TRAINING }) { "training.bridge_action" }
        return Phase8Payloads.batch(state, Phase8ScreenId.P010_CHAPTER, "advanceChapter",
            preview.advancePayloads.map { it.envelope.command } + training.map { it.envelope.command })
    }
}
