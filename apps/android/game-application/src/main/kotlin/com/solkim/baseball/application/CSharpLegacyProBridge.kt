package com.solkim.baseball.application

import com.solkim.baseball.core.pro.ProCareerPhase
import com.solkim.baseball.core.pro.ProKernel
import com.solkim.baseball.core.pro.ProStartMode
import com.solkim.baseball.core.pro.ProState
import com.solkim.baseball.core.pro.ProStateCodec
import com.solkim.baseball.model.Hashing
import com.solkim.baseball.model.JsonValue
import com.solkim.baseball.model.StrictJson
import java.util.Base64

/**
 * Dual-write for the C# Pro snapshot. Compose reloads the Kotlin [ProState] sidecar;
 * Unity `Restore()` reads the PascalCase fields and the C# FNV commitment.
 */
public object CSharpLegacyProBridge {
    public const val NATIVE_FIELD: String = "NativeProStateJson"

    public fun project(pro: JsonValue.Obj?): ProState? {
        val core = pro?.stringOrNull("coreStateJson") ?: return null
        val snapshot = runCatching { StrictJson.parseUtf8(core.toByteArray()) as? JsonValue.Obj }.getOrNull() ?: return null
        val native = snapshot.stringOrNull(NATIVE_FIELD) ?: return null
        return try {
            val decoded = ProStateCodec.decode(Base64.getDecoder().decode(native))
            decoded.copy(commitment = ProKernel().commitment(decoded.copy(commitment = "")))
        } catch (_: Exception) {
            null
        }
    }

    public fun encodeReadModel(state: ProState, nextSeed: String, previous: JsonValue.Obj?): JsonValue.Obj {
        val next = LinkedHashMap(previous?.entries ?: linkedMapOf())
        next["proCareerId"] = JsonValue.Str(state.careerId)
        next["origin"] = JsonValue.Str(if (state.startMode == ProStartMode.DIRECT) "direct" else "highSchool")
        next["phase"] = JsonValue.Str(csharpPhaseWire(state.phase))
        next["nextSeed"] = JsonValue.Str(nextSeed)
        next["coreRevision"] = JsonValue.Num(state.revision.toString())
        next["playerId"] = JsonValue.Str(state.pitcher.id)
        next["playerName"] = JsonValue.Str(state.identityName)
        next["teamId"] = JsonValue.Str(state.team.id)
        next["teamName"] = JsonValue.Str(state.team.name)
        next["season"] = JsonValue.Num(state.season.toString())
        next["week"] = JsonValue.Num(state.week.toString())
        next["ratings"] = JsonValue.Obj(linkedMapOf(
            "stuff" to JsonValue.Num(state.pitcher.stuff.toString()),
            "command" to JsonValue.Num(state.pitcher.command.toString()),
            "movement" to JsonValue.Num(state.pitcher.movement.toString()),
            "stamina" to JsonValue.Num(state.pitcher.stamina.toString()),
            "total" to JsonValue.Num((state.pitcher.stuff + state.pitcher.command + state.pitcher.movement + state.pitcher.stamina).toString()),
        ))
        next["currentSeason"] = JsonValue.Obj(linkedMapOf(
            "importantGames" to JsonValue.Num(state.importantGames.toString()),
            "pitches" to JsonValue.Num(state.currentStats.pitches.toString()),
            "outs" to JsonValue.Num(state.currentStats.inningsOuts.toString()),
            "strikeouts" to JsonValue.Num(state.currentStats.strikeouts.toString()),
            "walks" to JsonValue.Num(state.currentStats.walks.toString()),
            "hits" to JsonValue.Num(state.currentStats.hits.toString()),
            "runsAllowed" to JsonValue.Num(state.currentStats.runsAllowed.toString()),
        ))
        next["sourceHighSchoolCareerId"] = state.sourceHighSchoolCareerId?.let(JsonValue::Str) ?: JsonValue.Null
        next["coreStateJson"] = JsonValue.Str(encodeSnapshot(state))
        next["level"] = JsonValue.Str(state.level.wire)
        next["role"] = JsonValue.Str(state.role.wire)
        next["managerTrust"] = JsonValue.Num(state.managerTrust.toString())
        next["catcherTrust"] = JsonValue.Num(state.catcherTrust.toString())
        next["fatigue"] = JsonValue.Num(state.fatigue.toString())
        next["injuryWeeks"] = JsonValue.Num(state.injuryWeeks.toString())
        return JsonValue.Obj(next)
    }

    public fun encodeSnapshot(state: ProState): String {
        val native = Base64.getUrlEncoder().withoutPadding().encodeToString(ProStateCodec.encode(state))
        val phaseName = csharpPhaseName(state.phase)
        val root = JsonValue.Obj(linkedMapOf(
            "ProCareerId" to JsonValue.Str(state.careerId),
            "Revision" to JsonValue.Num(state.revision.toString()),
            "Phase" to JsonValue.Str(phaseName),
            "Identity" to JsonValue.Obj(linkedMapOf(
                "Name" to JsonValue.Str(state.identityName),
                "ThrowingHand" to JsonValue.Str("Right"),
                "BodyType" to JsonValue.Str("Balanced"),
                "Region" to JsonValue.Str("서울"),
            )),
            "Pitcher" to JsonValue.Obj(linkedMapOf(
                "Id" to JsonValue.Str(state.pitcher.id),
                "Name" to JsonValue.Str(state.pitcher.name),
                "Stuff" to JsonValue.Num(state.pitcher.stuff.toString()),
                "Command" to JsonValue.Num(state.pitcher.command.toString()),
                "Movement" to JsonValue.Num(state.pitcher.movement.toString()),
                "Stamina" to JsonValue.Num(state.pitcher.stamina.toString()),
            )),
            "Team" to JsonValue.Obj(linkedMapOf(
                "Id" to JsonValue.Str(state.team.id),
                "Name" to JsonValue.Str(state.team.name),
                "Need" to JsonValue.Str("Command"),
                "Demand" to JsonValue.Num(state.team.demand.toString()),
                "DevelopmentPlan" to JsonValue.Str(state.team.developmentPlan),
                "PositionCompetitor" to JsonValue.Str(state.team.positionCompetitor),
                "ProCoach" to JsonValue.Str(""),
            )),
            "Entitlement" to JsonValue.Obj(linkedMapOf(
                "ProductId" to JsonValue.Str("baseball_pro_career"),
                "Status" to JsonValue.Str(if (state.entitlement.active) "Active" else "Locked"),
                "Source" to JsonValue.Str("Development"),
                "VerifiedAt" to JsonValue.Str(state.entitlement.verifiedAt),
            )),
            "Age" to JsonValue.Num(state.age.toString()),
            "Season" to JsonValue.Num(state.season.toString()),
            "Week" to JsonValue.Num(state.week.toString()),
            "Level" to JsonValue.Str(if (state.level.wire == "major") "Major" else "Minor"),
            "Role" to JsonValue.Str(pascalRole(state.role.wire)),
            "ManagerTrust" to JsonValue.Num(state.managerTrust.toString()),
            "CatcherTrust" to JsonValue.Num(state.catcherTrust.toString()),
            "Fatigue" to JsonValue.Num(state.fatigue.toString()),
            "InjuryWeeks" to JsonValue.Num(state.injuryWeeks.toString()),
            "ServiceYears" to JsonValue.Num(state.serviceYears.toString()),
            "MilitaryCompleted" to JsonValue.Bool(state.militaryCompleted),
            "CurrentStats" to JsonValue.Obj(linkedMapOf(
                "Season" to JsonValue.Num(state.currentStats.season.toString()),
                "TeamId" to JsonValue.Str(state.currentStats.teamId),
                "Games" to JsonValue.Num(state.currentStats.games.toString()),
                "Strikeouts" to JsonValue.Num(state.currentStats.strikeouts.toString()),
            )),
            "CareerStats" to JsonValue.Arr(emptyList()),
            "Awards" to JsonValue.Arr(state.awards.map(JsonValue::Str)),
            "Milestones" to JsonValue.Arr(state.milestones.map(JsonValue::Str)),
            "News" to JsonValue.Arr(state.news.map(JsonValue::Str)),
            "DevelopmentProgress" to JsonValue.Obj(linkedMapOf(
                "Stuff" to JsonValue.Num(state.developmentProgress.stuff.toString()),
                "Command" to JsonValue.Num(state.developmentProgress.command.toString()),
                "Movement" to JsonValue.Num(state.developmentProgress.movement.toString()),
                "Stamina" to JsonValue.Num(state.developmentProgress.stamina.toString()),
            )),
            "Commitment" to JsonValue.Str(csharpSign(state)),
            NATIVE_FIELD to JsonValue.Str(native),
        ))
        return StrictJson.canonical(root)
    }

    public fun csharpSign(state: ProState): String {
        val values = mutableListOf(
            state.careerId,
            state.revision.toString(),
            csharpPhaseWire(state.phase),
            state.team.id,
            state.age.toString(),
            state.season.toString(),
            state.week.toString(),
            state.level.wire,
            state.role.wire,
            state.managerTrust.toString(),
            state.fatigue.toString(),
            state.currentStats.games.toString(),
            state.currentStats.strikeouts.toString(),
            state.careerStats.size.toString(),
        )
        values += "development:${state.developmentProgress.stuff}:${state.developmentProgress.command}:${state.developmentProgress.movement}:${state.developmentProgress.stamina}"
        return Hashing.fnv1a64Hex(values.joinToString("|"))
    }

    private fun csharpPhaseWire(phase: ProCareerPhase): String = when (phase) {
        ProCareerPhase.LEGACY_SELECTION -> "completed"
        else -> phase.wire
    }

    private fun csharpPhaseName(phase: ProCareerPhase): String = when (phase) {
        ProCareerPhase.CONTRACT_OFFER -> "ContractOffer"
        ProCareerPhase.WEEKLY_PLAN -> "WeeklyPlan"
        ProCareerPhase.SEASON_DECISION -> "SeasonDecision"
        ProCareerPhase.IMPORTANT_GAME -> "ImportantGame"
        ProCareerPhase.SEASON_REVIEW -> "SeasonReview"
        ProCareerPhase.OFFSEASON_DECISION -> "OffseasonDecision"
        ProCareerPhase.RETIREMENT_DECISION -> "RetirementDecision"
        ProCareerPhase.LEGACY_SELECTION, ProCareerPhase.COMPLETED -> "Completed"
    }

    private fun pascalRole(wire: String): String = when (wire) {
        "long_relief" -> "LongRelief"
        "setup" -> "Setup"
        "closer" -> "Closer"
        else -> "Starter"
    }
}
