package com.solkim.baseball.application

/** The current career owns the destination, never an archived school plan. */
public object ReturnVisitPresentation {
    public fun isPro(state: GameAggregateState): Boolean = state.pro != null && state.stage in setOf(GameStage.PRO, GameStage.RETIREMENT, GameStage.LEGACY)
    public fun owner(state: GameAggregateState): String = if (isPro(state)) "pro:${state.pro!!.careerId}" else state.highSchool?.run?.careerId?.let { "school:$it" }.orEmpty()
    public fun screen(state: GameAggregateState): ScreenId = ScreenProjection.preferredScreen(state)
    public fun label(state: GameAggregateState): String = when (screen(state)) {
        ScreenId.P018_PRO_IMPORTANT_GAME, ScreenId.P008_IMPORTANT_GAME -> "멈춰 둔 경기"
        ScreenId.P019_PRO_SEASON -> "프로 시즌의 선택"
        ScreenId.P017_PRO_WEEK -> "프로 주간 계획"
        ScreenId.P007_RELATIONSHIP -> "진행 중인 대화"
        else -> if (isPro(state)) "프로 커리어" else "고교 커리어"
    }
    public fun detail(state: GameAggregateState): String = if (isPro(state)) "현재 프로 선수의 다음 일정으로 이어집니다." else "현재 선수의 이야기를 이어갑니다."
}
