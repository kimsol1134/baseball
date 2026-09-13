package com.solkim.baseball.application

import com.solkim.baseball.core.highschool.HighSchoolDraftOutcome

/** Review requests follow committed player actions, never a screen visit or a rating survey. */
public object ReviewMomentPolicy {
    public fun reasonAfter(actionId: String, before: GameAggregateState, after: GameAggregateState): String? {
        if (after.installId != before.installId || after.revision <= before.revision) return null
        if (CareerUiRules.challengeActive(before) || CareerUiRules.challengeActive(after)) return null
        val oldRun = before.highSchool?.run
        val newRun = after.highSchool?.run ?: return null

        // New path choices proceed directly to school selection, so PROLOGUE is not required.
        val startsLife = actionId in setOf("quickRebirth", "startHighSchool") || actionId.startsWith("rebirthPath:")
        if (startsLife && newRun.lifeNumber >= 3 && newRun.lifeNumber > (oldRun?.lifeNumber ?: 0) &&
            newRun.careerId != oldRun?.careerId) return "third-life"

        // These are the actual visible continuation actions after reading the result/recap.
        val leavesRecap = actionId in setOf("prepareLegacy", "finalizeArchive", "startLinked", "confirmDraftResult", "confirmRecap") ||
            actionId.startsWith("selectLegacy:")
        if (!leavesRecap || !ScreenProjection.recapDeservesReview(before)) return null
        return if (oldRun?.draftResult?.outcome == HighSchoolDraftOutcome.DRAFTED) "drafted-reveal-confirmed" else "good-recap"
    }
}
