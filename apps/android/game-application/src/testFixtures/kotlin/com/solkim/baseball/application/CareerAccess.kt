package com.solkim.baseball.application

import com.solkim.baseball.core.highschool.HighSchoolPhase4State
import com.solkim.baseball.core.pro.ProState

/**
 * Test/fixture access to career snapshots. Production UI reads [CareerUiRules] and presentation
 * DTOs; [GameAggregateState.highSchool] / [GameAggregateState.pro] stay module-internal.
 */
public object CareerAccess {
    public fun school(state: GameAggregateState?): HighSchoolPhase4State? = state?.highSchool
    public fun pro(state: GameAggregateState?): ProState? = state?.pro
    public fun run(state: GameAggregateState) = state.highSchool?.run
    public fun archive(state: GameAggregateState) = state.highSchool?.archive.orEmpty()
}

/** Public aggregate copy for :app tests. Career fields stay hidden on [GameAggregateState.copy]. */
public fun GameAggregateState.withCareers(
    highSchool: HighSchoolPhase4State? = this.highSchool,
    pro: ProState? = this.pro,
    stage: GameStage = this.stage,
    pitch: PitchDurableState? = this.pitch,
    meta: GameMetaState = this.meta,
    settings: GameSettingsState = this.settings,
    analytics: AnalyticsReceiptState = this.analytics,
    deleted: Boolean = this.deleted,
    revision: ULong = this.revision,
): GameAggregateState = copy(
    highSchool = highSchool,
    pro = pro,
    stage = stage,
    pitch = pitch,
    meta = meta,
    settings = settings,
    analytics = analytics,
    deleted = deleted,
    revision = revision,
)
