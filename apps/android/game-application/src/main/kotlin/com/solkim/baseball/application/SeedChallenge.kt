package com.solkim.baseball.application

import com.solkim.baseball.core.highschool.HighSchoolPhase4Command
import com.solkim.baseball.core.highschool.HighSchoolPhase4Kernel
import com.solkim.baseball.core.highschool.HighSchoolPhase4StartRequest
import com.solkim.baseball.core.highschool.HighSchoolPhase4State
import com.solkim.baseball.model.JsonValue
import java.net.URI
import java.util.Locale

/** Shares the iOS <UInt64 seed>-<life 1...999> contract. It never authorizes a save overwrite. */
public data class SeedChallengeCode(val seed: String, val life: Int) {
    init {
        require(seed.matches(Regex("[0-9]{1,20}")) && seed.toULongOrNull() != null && life in 1..999) { "challenge.code" }
        require(seed == seed.toULong().toString()) { "challenge.canonical_seed" }
    }
    val token: String get() = "${seed.toULong()}-$life"
    val webUrl: String get() = "https://baseball-reincarnation.vercel.app/challenge/$token"
    val appUrl: String get() = "yagurebirth://challenge/$token"

    public companion object {
        public fun parse(raw: String): SeedChallengeCode? = runCatching {
            val input = raw.trim()
            require(input.length in 3..2048)
            val token = if (input.contains("://")) {
                val uri = URI(input)
                require(uri.userInfo == null)
                val path = uri.path.orEmpty().split('/').filter { it.isNotEmpty() }
                when (uri.scheme?.lowercase(Locale.ROOT)) {
                    "yagurebirth" -> {
                        require(uri.host.equals("challenge", true) && path.size == 1)
                        path.single()
                    }
                    "https" -> {
                        require(uri.host.equals("baseball-reincarnation.vercel.app", true) && uri.port in setOf(-1, 443))
                        require(path.size == 2 && path[0].equals("challenge", true))
                        path[1]
                    }
                    else -> error("challenge.scheme")
                }
            } else input
            val match = Regex("([0-9]{1,20})-([0-9]{1,3})").matchEntire(token) ?: return null
            SeedChallengeCode(match.groupValues[1].toULong().toString(), match.groupValues[2].toInt())
        }.getOrNull()
    }
}

public data class SeedChallengeSession(
    val code: SeedChallengeCode,
    val presetId: String,
    val returnStage: GameStage,
    val returnPitch: PitchDurableState?,
    val hadHighSchool: Boolean,
    val returnActiveCareerId: String?,
    val returnArchiveIds: List<String>,
    val returnGameCount: ULong,
)

public object SeedChallengeRules {
    public fun startCommand(code: SeedChallengeCode, presetId: String): GameCommand =
        GameCommand.HighSchool(HighSchoolPhase4Command.StartSeedChallenge(code.seed, code.life, presetId))
    public fun endCommand(): GameCommand = GameCommand.HighSchool(HighSchoolPhase4Command.EndChallenge)
    public fun canStart(state: GameAggregateState): Boolean = !state.deleted && state.stage != GameStage.SETUP &&
        state.meta.seedChallenge == null && state.highSchool?.challenge?.active != true &&
        state.highSchool?.activePitch == null &&
        (state.pitch == null || state.pitch.boundary in setOf(PitchBoundary.COMPLETED, PitchBoundary.ABANDONED))

    internal fun checkpoint(state: GameAggregateState, command: HighSchoolPhase4Command.StartSeedChallenge): HighSchoolPhase4State {
        require(canStart(state)) { "challenge.finish_pitch_first" }
        SeedChallengeCode(command.seed, command.life)
        state.highSchool?.let { return it }
        // A fresh installation has no normal career. This internal sandbox checkpoint is
        // discarded on exit (hadHighSchool=false), so no fictional normal history is created.
        return HighSchoolPhase4Kernel().start(HighSchoolPhase4StartRequest(
            seed = (command.seed.toULong() xor 1UL).toString(), presetId = command.presetId,
            stableUserId = "seed-challenge", weekKey = "1970-W01", dayKey = "1970-01-01",
        )).state
    }

    internal fun finish(before: GameAggregateState, command: HighSchoolPhase4Command, changed: GameAggregateState): GameAggregateState {
        if (command is HighSchoolPhase4Command.StartSeedChallenge) {
            val session = SeedChallengeSession(SeedChallengeCode(command.seed, command.life), command.presetId,
                before.stage, before.pitch, before.highSchool != null, before.meta.activeHighSchoolCareerId,
                before.meta.lifeArchiveCareerIds, before.meta.completedGameCount)
            return changed.copy(stage = GameStage.HIGH_SCHOOL, pitch = null,
                meta = changed.meta.copy(seedChallenge = session, completedGameCount = before.meta.completedGameCount))
        }
        val session = before.meta.seedChallenge ?: return changed
        if (command == HighSchoolPhase4Command.EndChallenge) {
            return changed.copy(highSchool = changed.highSchool.takeIf { session.hadHighSchool },
                stage = session.returnStage, pitch = session.returnPitch,
                meta = changed.meta.copy(seedChallenge = null, completedGameCount = session.returnGameCount,
                    activeHighSchoolCareerId = session.returnActiveCareerId, lifeArchiveCareerIds = session.returnArchiveIds))
        }
        return changed.copy(stage = GameStage.HIGH_SCHOOL,
            meta = changed.meta.copy(completedGameCount = session.returnGameCount))
    }
}

internal object SeedChallengeCodec {
    fun encode(value: SeedChallengeSession): JsonValue.Obj = JsonValue.Obj(linkedMapOf(
        "schemaVersion" to JsonValue.Num("1"), "seed" to JsonValue.Str(value.code.seed), "life" to JsonValue.Num(value.code.life.toString()),
        "presetId" to JsonValue.Str(value.presetId), "returnStage" to JsonValue.Str(value.returnStage.wire),
        "returnPitch" to (value.returnPitch?.let(GameAggregateCodec::encodePitch) ?: JsonValue.Null),
        "hadHighSchool" to JsonValue.Bool(value.hadHighSchool),
        "returnActiveCareerId" to (value.returnActiveCareerId?.let(JsonValue::Str) ?: JsonValue.Null),
        "returnArchiveIds" to JsonValue.Arr(value.returnArchiveIds.map(JsonValue::Str)),
        "returnGameCount" to JsonValue.Str(value.returnGameCount.toString()),
    ))
    fun decode(value: JsonValue?): SeedChallengeSession? {
        if (value == null) return null
        require(value is JsonValue.Obj && value.entries.keys == setOf("schemaVersion", "seed", "life", "presetId", "returnStage", "returnPitch", "hadHighSchool", "returnActiveCareerId", "returnArchiveIds", "returnGameCount")) { "challenge.session_fields" }
        require((value["schemaVersion"] as? JsonValue.Num)?.raw == "1") { "challenge.session_version" }
        fun str(key: String) = (value[key] as? JsonValue.Str)?.value ?: error("challenge.session.$key")
        val pitch = value["returnPitch"].let {
            if (it == JsonValue.Null) null
            else GameAggregateCodec.decodePitch(it as JsonValue.Obj)
        }
        return SeedChallengeSession(SeedChallengeCode(str("seed"), (value["life"] as JsonValue.Num).raw.toInt()), str("presetId"),
            GameStage.entries.single { it.wire == str("returnStage") }, pitch, (value["hadHighSchool"] as JsonValue.Bool).value,
            value["returnActiveCareerId"].let { if (it == JsonValue.Null) null else (it as JsonValue.Str).value },
            (value["returnArchiveIds"] as JsonValue.Arr).values.map { (it as JsonValue.Str).value }, str("returnGameCount").toULong())
    }
}
