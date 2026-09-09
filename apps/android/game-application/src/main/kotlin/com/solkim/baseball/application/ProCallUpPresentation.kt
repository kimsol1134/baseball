package com.solkim.baseball.application

import com.solkim.baseball.core.pro.*

public object ProCallUpPresentation {
    public fun lines(pro: ProState): List<String> = listOf(
        "감독 신뢰 ${pro.managerTrust} / ${ProCallUpRules.TRUST_REQUIRED}",
        "종합 평가 ${AbilityDisplayScale.rating(ProCallUpRules.skill(pro.pitcher))} / ${AbilityDisplayScale.rating(ProCallUpRules.SKILL_REQUIRED)}",
        "경험 조건: 2시즌 진입 또는 ${ProCallUpRules.GAMES_REQUIRED}경기 또는 ${ProCallUpRules.STRIKEOUTS_REQUIRED}탈삼진",
        "현재 ${pro.season}시즌 · ${pro.currentStats.games}경기 · ${pro.currentStats.strikeouts}탈삼진",
        if (ProCallUpRules.qualifies(pro.managerTrust, ProCallUpRules.skill(pro.pitcher), pro.season, pro.currentStats))
            "현재 기준으로 조건을 충족했어요. 다음 주간 진행에서 다시 판정합니다." else "부족한 조건을 채워 보세요. 승격은 주간 진행에서 판정합니다.",
    )
}
