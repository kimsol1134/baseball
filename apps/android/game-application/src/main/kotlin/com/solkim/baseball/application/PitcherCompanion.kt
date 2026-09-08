package com.solkim.baseball.application

import com.solkim.baseball.core.pitch.PitchKind
import com.solkim.baseball.core.pitch.PitchOutcome
import com.solkim.baseball.model.JsonValue

public data class PitchMemory(val id: String, val career: String, val life: Int, val kind: String, val pitch: String = "", val amount: Int = 0, val outing: List<Int> = emptyList(), val sourceId: String = "")
public data class SignatureExperience(val pitch: String, val training: Int = 0, val uses: Int = 0, val strikeouts: Int = 0) {
    public val rank: Int get() = when { strikeouts >= 10 -> 3; strikeouts >= 1 -> 2; uses >= 3 || training >= 3 -> 1; else -> 0 }
}
public data class PitcherCompanion(
    val career: String = "", val representative: String = "four_seam", val nickname: String = "", val jersey: Int = 1,
    val pinned: String = "", val goal: String = "", val goalPitch: String = "", val goalTarget: Int = 0,
    val goalBaseline: Int = 0, val goalCompleted: Boolean = false, val careerStrikeouts: Int = 0,
    val careerSignatureKs: Int = 0, val cleanOutings: Int = 0,
    val experience: List<SignatureExperience> = emptyList(), val memories: List<PitchMemory> = emptyList(),
    val previousStart: List<Int> = emptyList(), val nicknames: Map<String, String> = emptyMap(),
) {
    public fun validate() {
        require(representative in PitchKind.entries.map { it.wire } && nickname.length <= 20 && nickname.none { it.isISOControl() } && jersey in 1..99) { "companion.identity" }
        require(nicknames.size <= 4 && nicknames.all { (pitch, name) -> pitch in PitchKind.entries.map { it.wire } && name.length <= 20 && name.none { it.isISOControl() } }) { "companion.nicknames" }
        require(goalPitch.isEmpty() || goalPitch in PitchKind.entries.map { it.wire }) { "companion.goal_pitch" }
        require(goal in setOf("", "signature", "clean", "best") && goalTarget >= 0 && goalBaseline >= 0) { "companion.goal" }
        require(listOf(careerStrikeouts, careerSignatureKs, cleanOutings).all { it >= 0 }) { "companion.count" }
        require(experience.size <= 4 && experience.map { it.pitch }.distinct().size == experience.size && experience.all { it.pitch in PitchKind.entries.map { p -> p.wire } && it.training >= 0 && it.uses >= 0 && it.strikeouts in 0..it.uses }) { "companion.experience" }
        require(memories.map { it.id }.distinct().size == memories.size && memories.all { it.id.isNotBlank() && it.career.isNotBlank() && it.life > 0 && it.amount >= 0 && (it.pitch.isEmpty() || it.pitch in PitchKind.entries.map { p -> p.wire }) && it.kind in setOf("first_strikeout", "pitch_strikeout", "recovery", "clean_outing", "signature_rank_1", "signature_rank_2", "signature_rank_3", "goal_signature", "goal_clean", "goal_best", "goal_attempt", "starter_trial", "held_lead", "first_save", "best_outing") }) { "companion.memories" }
        require(memories.all { it.outing.isEmpty() && it.sourceId.isEmpty() || (it.outing.size == 3 && it.outing.all { n -> n >= 0 } && it.sourceId.isNotBlank()) }) { "companion.outing" }
        require(previousStart.isEmpty() || previousStart.size == 4 && previousStart.all { it in 20..80 }) { "companion.start" }
        require(pinned.isEmpty() || memories.any { it.id == pinned }) { "companion.pin" }
    }
}

public object PitcherCompanionRules {
    public fun career(state: GameAggregateState): String? = if (state.stage in setOf(GameStage.PRO, GameStage.RETIREMENT)) state.pro?.careerId else state.highSchool?.run?.careerId
    public fun current(state: GameAggregateState): PitcherCompanion {
        val primary = if (state.stage in setOf(GameStage.PRO, GameStage.RETIREMENT)) state.pro?.pitcher?.pitchProfiles else state.highSchool?.run?.pitcher?.pitchProfiles
        val saved = state.meta.companion ?: PitcherCompanion(representative = primary?.firstOrNull { it.role == com.solkim.baseball.core.pitch.PitchUsageRole.PRIMARY }?.pitchType?.wire ?: "four_seam")
        val id = career(state) ?: return saved
        return if (saved.career == id) saved else saved.copy(career = id, goal = "", goalPitch = "", goalTarget = 0, goalBaseline = 0,
            goalCompleted = false, careerStrikeouts = currentKs(state), careerSignatureKs = 0, cleanOutings = 0)
    }
    private fun currentKs(state: GameAggregateState): Int = if (state.stage in setOf(GameStage.PRO, GameStage.RETIREMENT)) {
        state.pro?.let { it.careerStats.sumOf { stat -> stat.strikeouts } + if (it.careerStats.any { stat -> stat.season == it.currentStats.season }) 0 else it.currentStats.strikeouts } ?: 0
    } else (state.highSchool?.run?.performance?.strikeouts ?: 0) + (state.highSchool?.activePitch?.strikeouts ?: 0)
    public fun canChooseGoal(state: GameAggregateState): Boolean = if (state.stage in setOf(GameStage.PRO, GameStage.RETIREMENT))
        state.pro?.phase !in setOf(null, com.solkim.baseball.core.pro.ProCareerPhase.LEGACY_SELECTION, com.solkim.baseball.core.pro.ProCareerPhase.COMPLETED)
    else state.highSchool?.run?.phase !in setOf(null, com.solkim.baseball.core.highschool.HighSchoolPhase.DRAFT, com.solkim.baseball.core.highschool.HighSchoolPhase.LEGACY, com.solkim.baseball.core.highschool.HighSchoolPhase.COMPLETED)

    public fun apply(state: GameAggregateState, operation: String, value: String): PitcherCompanion {
        require(state.meta.seedChallenge == null && state.highSchool?.challenge?.active != true) { "companion.challenge" }
        require(career(state) != null) { "companion.no_player" }
        val c = current(state)
        val next = when (operation) {
            "pitch" -> {
                val types = if (state.stage in setOf(GameStage.PRO, GameStage.RETIREMENT)) state.pro?.pitcher?.pitchProfiles?.map { it.pitchType.wire }
                    else state.highSchool?.run?.pitcher?.pitchProfiles?.map { it.pitchType.wire }
                require(value in types.orEmpty()) { "companion.pitch_unknown" }
                c.copy(representative = value, nickname = if (value == c.representative) c.nickname else c.nicknames[value].orEmpty())
            }
            "nickname" -> { require(c.experience.any { it.pitch == c.representative && it.rank >= 2 }) { "companion.nickname_locked" }; c.copy(nickname = value.trim(), nicknames = c.nicknames + (c.representative to value.trim())) }
            "jersey" -> c.copy(jersey = value.toIntOrNull() ?: error("companion.jersey"))
            "pin" -> c.copy(pinned = value)
            "goal" -> {
                require(canChooseGoal(state)) { "companion.career_finished" }
                require(c.goal.isEmpty() || c.goalCompleted) { "companion.goal_active" }
                require(value in setOf("signature", "clean", "best")) { "companion.goal_unknown" }
                require(c.memories.none { it.career == c.career && it.kind == "goal_$value" }) { "companion.goal_already_done" }
                val baseline = when(value) { "signature" -> c.careerSignatureKs; "clean" -> c.cleanOutings; else -> c.careerStrikeouts }
                val best = if (state.stage in setOf(GameStage.PRO, GameStage.RETIREMENT)) state.meta.retiredProCareers.maxOfOrNull { pro ->
                    pro.careerStats.sumOf { it.strikeouts } + if (pro.careerStats.any { it.season == pro.currentStats.season }) 0 else pro.currentStats.strikeouts
                } ?: 0 else state.highSchool?.archive?.maxOfOrNull { it.strikeouts } ?: 0
                val target = if (value == "best") maxOf(c.careerStrikeouts + 1, best + 1) else baseline + 1
                c.copy(goal = value, goalPitch = c.representative, goalTarget = target, goalBaseline = baseline, goalCompleted = false)
            }
            else -> error("companion.operation")
        }
        next.validate()
        return next
    }
    public fun transition(before: GameAggregateState, after: GameAggregateState): PitcherCompanion? {
        if (after.meta.seedChallenge != null || after.highSchool?.challenge?.active == true) return before.meta.companion
        if (career(after) == null) return after.meta.companion
        var c = current(after)
        val life = after.highSchool?.run?.lifeNumber ?: 1
        val oldCompanion = before.meta.companion
        if (oldCompanion != null && oldCompanion.career != c.career && oldCompanion.goal.isNotEmpty() && !oldCompanion.goalCompleted) {
            val attempt = PitchMemory("${oldCompanion.career}:goal_attempt:${oldCompanion.goal}", oldCompanion.career,
                before.highSchool?.run?.lifeNumber ?: 1, "goal_attempt", oldCompanion.goalPitch, (progress(oldCompanion) - oldCompanion.goalBaseline).coerceAtLeast(0))
            if (c.memories.none { it.id == attempt.id }) c = c.copy(memories = c.memories + attempt)
        }
        if (before.highSchool != null && after.highSchool != null && before.highSchool!!.run.careerId != after.highSchool!!.run.careerId && life > before.highSchool!!.run.lifeNumber) {
            val start = before.highSchool!!.startingPitcher
            c = c.copy(previousStart = listOf(start.stuff, start.command, start.movement, start.stamina))
        }
        fun memory(kind: String, pitch: String = "", amount: Int = 0) {
            val id = "${c.career}:$kind:$pitch"
            if (c.memories.any { it.id == id }) return
            val added = c.memories + PitchMemory(id, c.career, life, kind, pitch, amount)
            c = c.copy(memories = added)
        }
        fun experience(pitch: String, training: Int = 0, uses: Int = 0, ks: Int = 0) {
            val previous = c.experience.firstOrNull { it.pitch == pitch } ?: SignatureExperience(pitch)
            val next = previous.copy(training = Math.addExact(previous.training, training), uses = Math.addExact(previous.uses, uses), strikeouts = Math.addExact(previous.strikeouts, ks))
            c = c.copy(experience = c.experience.filterNot { it.pitch == pitch } + next)
            if (previous.rank < next.rank && next.rank > 0) memory("signature_rank_${next.rank}", pitch, next.rank)
        }
        val oldSchool = before.highSchool
        val school = after.highSchool
        if (school != null && oldSchool?.run?.careerId == school.run.careerId && school.run.totalTrainingsCompleted > oldSchool.run.totalTrainingsCompleted) {
            val rows = school.trainingEvidence.filter { it.careerId == school.run.careerId && it.trainingNumber > oldSchool.run.totalTrainingsCompleted }
            rows.forEach { row ->
                val pitch = row.targetPitch?.wire ?: "four_seam".takeIf { row.focus.wire == "velocity" }
                if (pitch != null) experience(pitch, training = 1)
            }
            if (oldSchool.run.fatigue - school.run.fatigue >= 10) memory("recovery", amount = oldSchool.run.fatigue - school.run.fatigue)
        }
        val oldLog = if (after.stage in setOf(GameStage.PRO, GameStage.RETIREMENT)) before.pro?.activePitch?.log else null
        val newLog = if (after.stage in setOf(GameStage.PRO, GameStage.RETIREMENT)) after.pro?.activePitch?.log else null
        val entries = if (newLog != null) newLog.entries.takeLast((newLog.totalPitches - (oldLog?.totalPitches ?: 0)).coerceAtLeast(0)).map { it.pitchType to it.outcome }
            else if (school?.activePitch != null) school.activePitch!!.log.entries.takeLast((school.activePitch!!.log.totalPitches - (oldSchool?.activePitch?.log?.totalPitches ?: 0)).coerceAtLeast(0)).map { it.pitchType to it.outcome } else emptyList()
        // Tutorial has no official game log; no practice result can become a career achievement.
        entries.forEachIndexed { index, it ->
            if (index == 0 && after.meta.companion?.career != c.career && career(before) == c.career) c = c.copy(careerStrikeouts = currentKs(before))
            val strikeout = index == entries.lastIndex && it.second in setOf(PitchOutcome.CALLED_STRIKE, PitchOutcome.SWINGING_STRIKE) &&
                (if (newLog != null) (after.pro?.activePitch?.strikeouts ?: 0) > (before.pro?.activePitch?.strikeouts ?: 0) else (school?.activePitch?.strikeouts ?: 0) > (oldSchool?.activePitch?.strikeouts ?: 0))
            experience(it.first.wire, uses = 1, ks = if (strikeout) 1 else 0)
            if (strikeout) {
                c = c.copy(careerStrikeouts = c.careerStrikeouts + if (newLog == null) 1 else 0,
                    careerSignatureKs = c.careerSignatureKs + if (it.first.wire == (c.goalPitch.ifEmpty { c.representative })) 1 else 0)
                if (currentKs(before) == 0 && (if (newLog != null) after.pro?.activePitch?.strikeouts == 1 else c.careerStrikeouts == 1)) memory("first_strikeout", amount = 1)
                memory("pitch_strikeout", it.first.wire, 1)
            }
        }
        val oldGames = oldSchool?.seasonLog.orEmpty().filter { it.played }.map { "${it.careerId}:${it.gameNumber}" }.toSet()
        school?.seasonLog.orEmpty().filter { it.played && it.careerId == c.career && "${it.careerId}:${it.gameNumber}" !in oldGames }.forEach {
            if (it.outs >= 3 && it.runsAllowed == 0 && it.walks == 0) { c = c.copy(cleanOutings = c.cleanOutings + 1); memory("clean_outing", amount = it.strikeouts) }
        }
        val oldProGames = before.pro?.currentGameLines.orEmpty().filter { it.played }.map { "${it.season}:${it.week}:${it.outingNumber}" }.toSet()
        after.pro?.currentGameLines.orEmpty().filter { it.played && "${it.season}:${it.week}:${it.outingNumber}" !in oldProGames }.forEach {
            if (it.outs >= 3 && it.runsAllowed == 0 && it.walks == 0) { c = c.copy(cleanOutings = c.cleanOutings + 1); memory("clean_outing", amount = it.strikeouts) }
        }
        fun rememberOuting(kind: String, source: String, outs: Int, runs: Int, ks: Int, replaceBest: Boolean = false) {
            if (outs <= 0) return
            val id = "${c.career}:$kind:"
            val existing = c.memories.firstOrNull { it.id == id }
            fun score(o: List<Int>) = o[0] * 4 + o[2] * 3 - o[1] * 8
            val line = listOf(outs, runs, ks)
            if (existing != null && (!replaceBest || (existing.outing.size == 3 && score(existing.outing) >= score(line)))) return
            val remembered = PitchMemory(id, c.career, life, kind, amount = ks, outing = line, sourceId = source)
            c = c.copy(memories = c.memories.filterNot { it.id == id } + remembered)
        }
        val objective = OutingPresentation.assignment(after)
        if (objective?.status == com.solkim.baseball.core.pitch.OutingGoalStatus.ACHIEVED &&
            OutingPresentation.assignment(before)?.status != com.solkim.baseball.core.pitch.OutingGoalStatus.ACHIEVED) {
            val hsPitch = after.highSchool?.activePitch
            val proPitch = after.pro?.activePitch
            val kind = when (objective.goal) {
                com.solkim.baseball.core.pitch.OutingGoal.STARTER_TEST -> "starter_trial"
                com.solkim.baseball.core.pitch.OutingGoal.HOLD_LEAD -> "held_lead"
                else -> null
            }
            if (kind != null) rememberOuting(kind, proPitch?.sessionId ?: hsPitch!!.sessionId,
                proPitch?.outs ?: hsPitch!!.outs, proPitch?.runsAllowed ?: hsPitch!!.runsAllowed, proPitch?.strikeouts ?: hsPitch!!.strikeouts)
        }
        school?.seasonLog.orEmpty().filter { it.played && it.careerId == c.career && "${it.careerId}:${it.gameNumber}" !in oldGames }.forEach {
            rememberOuting("best_outing", "hs:${it.careerId}:${it.gameNumber}", it.outs, it.runsAllowed, it.strikeouts, true)
        }
        val oldFinalGames = before.pro?.currentGameLines.orEmpty().associateBy { "${it.season}:${it.week}:${it.outingNumber}" }
        val nextPro = after.pro?.takeIf { it.careerId == c.career }
        val pending = nextPro?.takeIf { it.phase == com.solkim.baseball.core.pro.ProCareerPhase.IMPORTANT_GAME }?.currentGameLines?.lastOrNull { !it.played && it.week == nextPro.week }
        nextPro?.currentGameLines.orEmpty().filter { it != pending }.forEach {
            val id = "${it.season}:${it.week}:${it.outingNumber}"
            val old = oldFinalGames[id]
            if (old == null || (!old.played && it.played)) {
                if (it.decision == com.solkim.baseball.core.pro.ProPitchingDecision.SAVE) rememberOuting("first_save", "pro:${c.career}:$id", it.outs, it.runsAllowed, it.strikeouts)
                if (it.played) rememberOuting("best_outing", "pro:${c.career}:$id", it.outs, it.runsAllowed, it.strikeouts, true)
            }
        }
        if (after.stage in setOf(GameStage.PRO, GameStage.RETIREMENT) && after.pro?.activePitch == null) c = c.copy(careerStrikeouts = currentKs(after))
        if (c.goal.isNotEmpty() && !c.goalCompleted && !(c.goal == "best" && after.pro?.activePitch != null)) {
            val progress = progress(c)
            if (progress >= c.goalTarget) { memory("goal_${c.goal}", c.goalPitch, progress); c = c.copy(goalCompleted = true) }
        }
        c.validate()
        return c.takeUnless { it == PitcherCompanion(career = c.career, careerStrikeouts = currentKs(after)) && before.meta.companion == null && after.meta.companion == null }
    }
    public fun progress(c: PitcherCompanion): Int = when(c.goal) { "signature" -> c.careerSignatureKs; "clean" -> c.cleanOutings; else -> c.careerStrikeouts }
}

public object PitcherCompanionCodec {
    private fun str(s: String) = JsonValue.Str(s)
    private fun num(n: Int) = JsonValue.Num(n.toString())
    public fun encode(c: PitcherCompanion): JsonValue.Obj = JsonValue.Obj(linkedMapOf(
        "nicknames" to JsonValue.Obj(LinkedHashMap(c.nicknames.toSortedMap().mapValues { str(it.value) })),
        "previousStart" to JsonValue.Arr(c.previousStart.map(::num)),
        "version" to num(1), "career" to str(c.career), "representative" to str(c.representative), "nickname" to str(c.nickname), "jersey" to num(c.jersey),
        "pinned" to str(c.pinned), "goal" to str(c.goal), "goalPitch" to str(c.goalPitch), "goalTarget" to num(c.goalTarget), "goalBaseline" to num(c.goalBaseline),
        "goalCompleted" to JsonValue.Bool(c.goalCompleted), "careerStrikeouts" to num(c.careerStrikeouts), "careerSignatureKs" to num(c.careerSignatureKs), "cleanOutings" to num(c.cleanOutings),
        "experience" to JsonValue.Arr(c.experience.map { JsonValue.Obj(linkedMapOf("pitch" to str(it.pitch), "training" to num(it.training), "uses" to num(it.uses), "strikeouts" to num(it.strikeouts))) }),
        "memories" to JsonValue.Arr(c.memories.map { JsonValue.Obj(linkedMapOf("id" to str(it.id), "career" to str(it.career), "life" to num(it.life), "kind" to str(it.kind), "pitch" to str(it.pitch), "amount" to num(it.amount)).apply { if (it.outing.isNotEmpty()) { put("outing", JsonValue.Arr(it.outing.map(::num))); put("source", str(it.sourceId)) } }) })
    ))
    public fun decode(value: JsonValue?): PitcherCompanion? {
        if (value == null || value == JsonValue.Null) return null
        val v = value as? JsonValue.Obj ?: error("companion.shape")
        fun JsonValue.Obj.s(k: String) = (entries[k] as? JsonValue.Str)?.value ?: error("companion.$k")
        fun JsonValue.Obj.n(k: String) = (entries[k] as? JsonValue.Num)?.raw?.toIntOrNull() ?: error("companion.$k")
        fun JsonValue.Obj.list(k: String) = ((entries[k] as? JsonValue.Arr)?.values ?: error("companion.$k")).map { it as? JsonValue.Obj ?: error("companion.item") }
        require(v.n("version") == 1) { "companion.version" }
        return PitcherCompanion(v.s("career"), v.s("representative"), v.s("nickname"), v.n("jersey"), v.s("pinned"), v.s("goal"), v.s("goalPitch"), v.n("goalTarget"), v.n("goalBaseline"),
            (v.entries["goalCompleted"] as? JsonValue.Bool)?.value ?: error("companion.goalCompleted"), v.n("careerStrikeouts"), v.n("careerSignatureKs"), v.n("cleanOutings"),
            v.list("experience").map { require(it.entries.keys == setOf("pitch", "training", "uses", "strikeouts")) { "companion.experience_fields" }; SignatureExperience(it.s("pitch"), it.n("training"), it.n("uses"), it.n("strikeouts")) },
            v.list("memories").map { require(it.entries.keys == setOf("id", "career", "life", "kind", "pitch", "amount") + setOf("outing", "source").filter { key -> key in it.entries }) { "companion.memory_fields" }; PitchMemory(it.s("id"), it.s("career"), it.n("life"), it.s("kind"), it.s("pitch"), it.n("amount"), (it.entries["outing"] as? JsonValue.Arr)?.values.orEmpty().map { n -> (n as JsonValue.Num).raw.toInt() }, (it.entries["source"] as? JsonValue.Str)?.value.orEmpty()) }, ((v.entries["previousStart"] as? JsonValue.Arr)?.values.orEmpty().map { (it as JsonValue.Num).raw.toInt() }), (v.entries["nicknames"] as? JsonValue.Obj)?.entries.orEmpty().mapValues { (it.value as JsonValue.Str).value }).also { it.validate(); require(encode(it).entries.keys == v.entries.keys) { "companion.fields" } }
    }
}
