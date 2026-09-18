package com.solkim.baseball.application.fixtures

import com.solkim.baseball.application.*
import com.solkim.baseball.core.highschool.*
import com.solkim.baseball.model.JsonValue
import java.util.Base64

/** Controlled task progress on a real save; preserves its core run and all non-weekly data. */
public fun weeklyNoteFixture(payload: JsonValue.Obj, completed: Int): JsonValue.Obj {
    require(completed in 0..3)
    val state = CSharpLegacyAggregateBridge.project(payload, 0UL, "fixture")
    val hs = requireNotNull(state.highSchool)
    val tasks = hs.weekly.tasks.mapIndexed { index, task -> task.copy(progress = if (index < completed) task.target else 0, completed = index < completed) }
    require(tasks.size == 3)
    val next = HighSchoolPhase4Kernel().commitShadowState(hs.copy(weekly = hs.weekly.copy(tasks = tasks, rewardClaimed = false,
        stamps = hs.weekly.stamps.filterNot { it.weekKey == hs.weekly.weekKey })))
    val raw = payload["highSchool"] as JsonValue.Obj
    val replaced = JsonValue.Obj(LinkedHashMap(raw.entries).apply {
        put(CSharpLegacyAggregateBridge.NATIVE_HIGH_SCHOOL_FIELD, JsonValue.Str(Base64.getUrlEncoder().withoutPadding().encodeToString(HighSchoolPhase4StateCodec.encode(next))))
    })
    return JsonValue.Obj(LinkedHashMap(payload.entries).apply { put("highSchool", replaced) })
}
