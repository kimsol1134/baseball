package com.solkim.baseball.application

import com.solkim.baseball.persistence.SaveFailureCode
import com.solkim.baseball.persistence.SaveRepositoryException

public object GameActionFailurePresentation {
    public enum class Kind { RULE, STALE_STATE, PITCH_STATE, STORAGE_FULL, IO, SAVE_VALIDATION, WRITE_DISABLED, UNKNOWN }
    public data class Failure(val kind: Kind, val code: String) {
        public val countsAsStorageFailure: Boolean get() = kind == Kind.IO || kind == Kind.STORAGE_FULL
    }
    public class Repetition {
        private data class Key(val actionId: String, val failure: Failure, val revision: ULong)
        private var previous: Key? = null
        public fun clear() { previous = null }
        public fun record(actionId: String, failure: Failure, revision: ULong): Boolean {
            val key = if (failure.countsAsStorageFailure) Key(actionId, failure, revision) else null
            val repeated = key != null && key == previous
            previous = key
            return repeated
        }
    }

    public fun causes(error: Throwable): List<Throwable> {
        val seen = java.util.Collections.newSetFromMap(java.util.IdentityHashMap<Throwable, Boolean>())
        val result = mutableListOf<Throwable>()
        var next: Throwable? = error
        while (next != null && result.size < 12 && seen.add(next)) { result += next; next = next.cause }
        return result
    }

    public fun classify(error: Throwable, spaceExhausted: Boolean = false): Failure {
        val chain = causes(error)
        val save = chain.filterIsInstance<SaveRepositoryException>().firstOrNull()
        val codes = chain.mapNotNull { it.message }
        val full = spaceExhausted || chain.filterIsInstance<java.nio.file.FileSystemException>().any { it.reason == "ENOSPC" || it.reason == "No space left on device" }
        // Storage wrappers carry more precise truth than a generic outer command exception.
        if (save != null && save.code != SaveFailureCode.IO_FAILED) return when (save.code) {
            SaveFailureCode.REVISION_CONFLICT, SaveFailureCode.REVISION_REGRESSION -> Failure(Kind.STALE_STATE, save.code.name)
            SaveFailureCode.WRITE_DISABLED -> Failure(Kind.WRITE_DISABLED, save.code.name)
            else -> Failure(Kind.SAVE_VALIDATION, save.code.name)
        }
        if (save?.code == SaveFailureCode.IO_FAILED) return if (full) Failure(Kind.STORAGE_FULL,"ENOSPC") else Failure(Kind.IO,"IO_FAILED")
        val rule = codes.firstOrNull { it in setOf("weekly.incomplete", "weekly.already_claimed", "weekly.challenge_locked", "weekly.career_unavailable") }
        if (rule != null) return Failure(Kind.RULE, rule)
        if (codes.any { it == "game.command.stale_revision" }) return Failure(Kind.STALE_STATE,"game.command.stale_revision")
        if (full) return Failure(Kind.STORAGE_FULL,"ENOSPC")
        if (save?.code == SaveFailureCode.IO_FAILED || chain.any { it is java.io.IOException }) return Failure(Kind.IO,"IO_FAILED")
        if (codes.any { it.startsWith("pitch.") || it.startsWith("phase7.") }) return Failure(Kind.PITCH_STATE,"pitch.state")
        if (codes.any { it.startsWith("phase8.action_disabled:") || it.startsWith("phase8.screen_unreachable:") }) return Failure(Kind.RULE,"action.unavailable")
        return Failure(Kind.UNKNOWN,"unknown")
    }

    public fun message(error: Throwable, actionId: String, repeated: Boolean, refreshed: Boolean): String =
        message(classify(error), actionId, repeated, refreshed)

    public fun message(failure: Failure, actionId: String, repeated: Boolean, refreshed: Boolean): String = when (failure.kind) {
        Kind.RULE -> when (failure.code) {
            "weekly.incomplete" -> WeeklyNotePolicy.requirement()
            "weekly.already_claimed" -> "이번 주 보상을 이미 받았어요."
            "weekly.challenge_locked" -> "도전 모드에서는 주간 보상을 받을 수 없어요."
            "weekly.career_unavailable" -> "주간 노트 보상은 고교 과정에서 받을 수 있어요."
            else -> "지금은 이 동작을 진행할 수 없어요. 현재 화면의 조건을 확인해 주세요."
        }
        Kind.STALE_STATE -> if (refreshed) "기록을 다시 불러왔어요. 현재 화면에서 진행할 항목을 선택해 주세요." else "진행 상태가 달라졌어요. 이전 화면으로 돌아가 현재 기록을 확인해 주세요."
        Kind.PITCH_STATE -> if (actionId == "abandonPitch") "중단 처리를 마치지 못했어요. 아래에서 투구를 이어 하거나 저장된 결과를 확인해 주세요." else "투구 상태를 확인해야 해요. 저장된 경기로 돌아가 이어서 진행해 주세요."
        Kind.STORAGE_FULL -> "저장 공간이 부족해 기록을 저장하지 못했어요. 공간을 확보한 뒤 다시 확인해 주세요."
        Kind.IO -> if (repeated) "기록 저장 중 문제가 반복됐어요. 설정의 저장과 기록에서 기록을 파일로 보관한 뒤 다시 확인해 주세요." else "기록을 저장하지 못했어요. 저장된 진행을 다시 확인한 뒤 이어서 진행해 주세요."
        Kind.SAVE_VALIDATION -> if (failure.code in setOf("MIGRATION_REQUIRED", "FUTURE_VERSION_WOULD_BE_OVERWRITTEN")) "이 기록은 다른 버전에서 만들어졌어요. 앱 버전을 확인해 주세요." else "기록을 검증하지 못했어요. 원본을 보존하고 저장과 기록에서 확인해 주세요."
        Kind.WRITE_DISABLED -> "현재 실행 환경에서는 기록을 저장할 수 없어요. 앱 실행 환경을 확인해 주세요."
        Kind.UNKNOWN -> "진행을 마치지 못했어요. 이전 화면으로 돌아가 상태를 확인해 주세요."
    }
}
