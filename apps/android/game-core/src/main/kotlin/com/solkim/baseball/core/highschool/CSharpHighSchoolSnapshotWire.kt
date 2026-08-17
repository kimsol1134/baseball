package com.solkim.baseball.core.highschool

import com.solkim.baseball.core.SplitMix64
import com.solkim.baseball.core.pitch.PitchKind
import com.solkim.baseball.core.pitch.PitchProfileSnapshot
import com.solkim.baseball.core.pitch.PitchUsageRole
import com.solkim.baseball.core.pitch.ThrowingHand
import com.solkim.baseball.model.Hashing
import com.solkim.baseball.model.JsonValue
import com.solkim.baseball.model.StrictJson

/**
 * C# `HighSchoolCareerEngine.Sign` + Newtonsoft PascalCase write-back.
 *
 * Kotlin [HighSchoolKernel] remains the post-cutover command authority. This writer only
 * produces a snapshot the frozen Unity reader can `Restore()`/`Validate()`.
 */
public object CSharpHighSchoolSnapshotWire {
    public const val NEXT_SEED_MIX: ULong = 0x4556454E5400UL

    public data class ReadExtras(
        val installId: String,
        val nextSeed: String,
        val presetId: String? = null,
        val tutorialCompleted: Boolean = false,
        val tutorialAttemptCount: Int = 0,
        val isChallengeRun: Boolean = false,
        val selectedSignatureLegacyId: String? = null,
        val pledgeId: String? = null,
    )

    public fun scheduleToken(schedule: HighSchoolSchedule): String {
        val trainings = schedule.trainingsByChapter.joinToString(",")
        val milestones = schedule.milestonesByChapter.joinToString(";") { chapter ->
            chapter.joinToString(",") { it.wire }
        }
        return "$trainings|$milestones"
    }

    public fun nextSeed(seed: String, revision: ULong): String {
        val parsed = seed.toULongOrNull() ?: throw CSharpHighSchoolSnapshotCodecException("csharp.nextSeed.seed")
        return SplitMix64(parsed xor revision xor NEXT_SEED_MIX).next().toString()
    }

    public fun sign(state: HighSchoolState): String {
        val ratings = "${state.pitcher.stuff}:${state.pitcher.command}:${state.pitcher.movement}:${state.pitcher.stamina}"
        val performance = listOf(
            state.performance.importantGamesCompleted,
            state.performance.pitches,
            state.performance.strikeouts,
            state.performance.walks,
            state.performance.runsAllowed,
            state.performance.expectedDamage,
            state.performance.actualDamage,
        ).joinToString(":")
        val draft = when (val result = state.draftResult) {
            null -> "none"
            else -> {
                val outcome = if (result.outcome == HighSchoolDraftOutcome.DRAFTED) "drafted" else "undrafted"
                val team = result.teamId ?: result.team?.id ?: "none"
                "$outcome:${result.evaluationScore}:$team"
            }
        }
        val canonical = mutableListOf(
            state.careerId,
            state.revision.toString(),
            state.phase.wire,
            state.identity.name,
            if (state.identity.throwingHand == "left") "left" else "right",
            bodyValue(state.identity.bodyType),
            state.identity.region,
            state.school?.id?.wire ?: "none",
            difficultyValue(state.difficulty.careerHarshness),
            difficultyValue(state.difficulty.informationClarity),
            difficultyValue(state.difficulty.simulationDifficulty),
            assistValue(state.difficulty.interventionAssist),
            state.karmas.joinToString(",") { it.wire },
            state.legacyRewardPermille.toString(),
            state.memorySlots.toString(),
            state.chapter.number.toString(),
            state.chapterTrainingCount.toString(),
            state.totalTrainingsCompleted.toString(),
            state.milestoneIndex.toString(),
            state.relationshipsCompleted.toString(),
            state.relationshipTrust.toString(),
            state.selectedAwakenings.joinToString(",") { it.wire },
            state.awakeningOptions.joinToString(",") { it.wire },
            state.fatigue.toString(),
            ratings,
            performance,
            state.currentGameScenario?.id ?: state.currentGameScenarioId ?: "none",
            draft,
            state.legacyOptions.joinToString(",") { memoryValue(it) },
            state.selectedMemories.joinToString(",") { memoryValue(it) },
        )
        canonical += "relationships:${state.managerTrust}:${state.catcherTrust}:${state.rivalTrust}"
        canonical += "balance_version:${state.balanceVersion}"
        canonical += "world_rules_version:${state.worldRulesVersion}"
        canonical += "arm_risk:${state.armRisk}"
        canonical += "injury_recovery:${state.injuryRecovery}"
        if (state.awakeningSparks != 0) canonical += "awakening_sparks:${state.awakeningSparks}"
        if (state.soulBoosts.isNotEmpty()) {
            canonical += "soul_boosts:" + state.soulBoosts.joinToString(",") { pascalName(it.wire) }
        }
        if (state.schedule.trainingsByChapter.isNotEmpty() || state.schedule.milestonesByChapter.isNotEmpty()) {
            canonical += "schedule:${scheduleToken(state.schedule)}"
        }
        state.lastRelationship?.let { relationship ->
            val category = state.currentRelationshipCategory
                ?: relationship.target.wire
            val title = state.currentRelationshipEvent?.title ?: relationship.target.wire
            val response = relationship.response.wire
            val focus = relationship.growthFocus?.wire ?: "none"
            canonical += listOf(
                "last_relationship",
                relationship.number.toString(),
                category,
                title,
                response,
                relationship.trustBefore.toString(),
                relationship.trustAfter.toString(),
                relationship.fatigueBefore.toString(),
                relationship.fatigueAfter.toString(),
                relationship.fanInterestBefore.toString(),
                relationship.fanInterestAfter.toString(),
                focus,
                "none",
                "none",
                relationshipFeedback(relationship),
                "current_fan_interest",
                state.fanInterest.toString(),
            ).joinToString(":")
        }
        return Hashing.fnv1a64Hex(canonical.joinToString("|"))
    }

    public fun encode(state: HighSchoolState, previous: JsonValue.Obj? = null): ByteArray {
        val signed = state.copy(stateCommitment = sign(state))
        return StrictJson.canonical(writeSnapshot(signed, previous)).toByteArray(Charsets.UTF_8)
    }

    public fun encodeUtf8(state: HighSchoolState, previous: JsonValue.Obj? = null): String =
        encode(state, previous).toString(Charsets.UTF_8)

    public fun hydratePhase4(run: HighSchoolState, extras: ReadExtras): HighSchoolPhase4State {
        val resigned = HighSchoolKernel().resignShadowState(run)
        val pastPrologue = resigned.phase != HighSchoolPhase.PROLOGUE
        val tutorial = HighSchoolTutorialState(
            started = extras.tutorialCompleted || pastPrologue || extras.tutorialAttemptCount > 0,
            completed = extras.tutorialCompleted || pastPrologue,
        )
        val draft = HighSchoolPhase4State(
            run = resigned,
            startingPitcher = resigned.pitcher,
            inheritance = HighSchoolInheritanceState(
                nextLifeNumber = resigned.lifeNumber + 1,
                soulPoints = 0,
                soulTotalEarned = 0,
                automaticSoulEarned = 0,
                selectedSignatureLegacyId = extras.selectedSignatureLegacyId,
            ),
            weekly = HighSchoolWeeklyState(extras.installId, "1970-W01", emptyList()),
            selectedSignatureLegacyId = extras.selectedSignatureLegacyId,
            tutorial = tutorial,
            challenge = HighSchoolChallengeState(active = extras.isChallengeRun),
        )
        return HighSchoolPhase4Kernel().commitShadowState(draft)
    }

    public fun remainingImportantGames(state: HighSchoolState): Int {
        val total = state.schedule.milestonesByChapter.sumOf { chapter ->
            chapter.count { it == HighSchoolPhase.IMPORTANT_GAME }
        }
        return (total - state.performance.importantGamesCompleted).coerceAtLeast(0)
    }

    public fun remainingChapterAdvances(state: HighSchoolState): Int =
        (8 - state.chapter.number).coerceAtLeast(0)

    private fun writeSnapshot(state: HighSchoolState, previous: JsonValue.Obj?): JsonValue.Obj {
        val previousLastTraining = previous?.get("LastTraining")
        val previousCareerWind = previous?.get("CareerWind")
        val previousSeasonLog = previous?.get("SeasonLog")
        val previousScenario = previous?.get("CurrentGameScenario")
        return obj(
            "CareerId" to str(state.careerId),
            "Revision" to num(state.revision),
            "LifeNumber" to num(state.lifeNumber),
            "Phase" to str(pascalPhase(state.phase)),
            "Identity" to writeIdentity(state.identity),
            "Difficulty" to writeDifficulty(state.difficulty),
            "Karmas" to strings(state.karmas.map { pascalName(it.wire) }),
            "LegacyRewardPermille" to num(state.legacyRewardPermille),
            "MemorySlots" to num(state.memorySlots),
            "Pitcher" to writePitcher(state.pitcher),
            "SchoolOptions" to JsonValue.Arr(state.schoolOptions.map(::writeSchool)),
            "School" to (state.school?.let(::writeSchool) ?: JsonValue.Null),
            "Rival" to writeRival(state.rival),
            "Chapter" to writeChapter(state.chapter),
            "ChapterTrainingCount" to num(state.chapterTrainingCount),
            "TotalTrainingsCompleted" to num(state.totalTrainingsCompleted),
            "MilestoneIndex" to num(state.milestoneIndex),
            "RelationshipsCompleted" to num(state.relationshipsCompleted),
            "RelationshipTrust" to num(state.relationshipTrust),
            "ManagerTrust" to num(state.managerTrust),
            "CatcherTrust" to num(state.catcherTrust),
            "RivalTrust" to num(state.rivalTrust),
            "SelectedAwakenings" to strings(state.selectedAwakenings.map { pascalName(it.wire) }),
            "AwakeningOptions" to strings(state.awakeningOptions.map { pascalName(it.wire) }),
            "Fatigue" to num(state.fatigue),
            "Performance" to writePerformance(state.performance),
            "SeasonLog" to (previousSeasonLog ?: JsonValue.Arr(emptyList())),
            "CurrentGameScenario" to writeScenario(state, previousScenario),
            "CurrentRelationshipEvent" to (state.currentRelationshipEvent?.let(::writeEvent) ?: JsonValue.Null),
            "LastTraining" to writeTraining(state.lastTraining, previousLastTraining),
            "LastRelationship" to (state.lastRelationship?.let { writeRelationship(it, state) } ?: JsonValue.Null),
            "News" to strings(state.news),
            "FanInterest" to num(state.fanInterest),
            "DraftResult" to (state.draftResult?.let(::writeDraft) ?: JsonValue.Null),
            "LegacyOptions" to strings(state.legacyOptions.map { pascalName(memoryValue(it)) }),
            "SelectedMemories" to strings(state.selectedMemories.map { pascalName(memoryValue(it)) }),
            "BalanceVersion" to num(state.balanceVersion),
            "WorldRulesVersion" to num(state.worldRulesVersion),
            "ArmRisk" to num(state.armRisk),
            "InjuryRecovery" to num(state.injuryRecovery),
            "Schedule" to writeSchedule(state.schedule),
            "TrainingOpportunity" to (state.trainingOpportunity?.let(::writeOpportunity) ?: JsonValue.Null),
            "Talent" to writeTalent(state.talent),
            "SoulBoosts" to if (state.soulBoosts.isEmpty()) JsonValue.Null else strings(state.soulBoosts.map { pascalName(it.wire) }),
            "AwakeningSparks" to if (state.awakeningSparks == 0) JsonValue.Null else num(state.awakeningSparks),
            "StateCommitment" to str(state.stateCommitment),
            "EffectiveWorldRulesVersion" to str(if (state.worldRulesVersion == 2) "V2" else "V1"),
            "CareerWind" to (previousCareerWind ?: JsonValue.Null),
        )
    }

    private fun writeIdentity(value: HighSchoolIdentity): JsonValue.Obj = obj(
        "Name" to str(value.name),
        "ThrowingHand" to str(if (value.throwingHand == "left") "Left" else "Right"),
        "BodyType" to str(pascalName(value.bodyType)),
        "Region" to str(value.region),
    )

    private fun writeDifficulty(value: HighSchoolDifficulty): JsonValue.Obj = obj(
        "CareerHarshness" to str(pascalName(difficultyValue(value.careerHarshness))),
        "InformationClarity" to str(pascalName(difficultyValue(value.informationClarity))),
        "SimulationDifficulty" to str(pascalName(difficultyValue(value.simulationDifficulty))),
        "InterventionAssist" to str(pascalName(assistValue(value.interventionAssist))),
    )

    private fun writePitcher(value: HighSchoolPitcher): JsonValue.Obj = obj(
        "Id" to str(value.id),
        "Name" to str(value.name),
        "Stuff" to num(value.stuff),
        "Command" to num(value.command),
        "Movement" to num(value.movement),
        "Stamina" to num(value.stamina),
        "PitchProfiles" to JsonValue.Arr(value.pitchProfiles.map(::writeProfile)),
        "ThrowingHand" to str(if (value.throwingHand == ThrowingHand.LEFT) "Left" else "Right"),
    )

    private fun writeProfile(value: PitchProfileSnapshot): JsonValue.Obj = obj(
        "PitchType" to str(pascalPitch(value.pitchType)),
        "Role" to str(pascalRole(value.role)),
        "VelocityTenthsKph" to num(value.velocityTenthsKph),
        "Control" to num(value.control),
        "Command" to num(value.command),
        "Movement" to num(value.movement),
        "Whiff" to num(value.whiff),
        "WeakContact" to num(value.weakContact),
        "FatigueCost" to num(value.fatigueCost),
    )

    private fun writeSchool(value: HighSchoolSchool): JsonValue.Obj = obj(
        "Id" to str(pascalName(value.id.wire)),
        "Name" to str(value.name),
        "Philosophy" to str(value.philosophy),
        "CoachName" to str(value.coachName),
        "CoachArchetype" to str(value.coachArchetype),
        "CatcherName" to str(value.catcherName),
        "CatcherArchetype" to str(value.catcherArchetype),
        "Strength" to str(pascalName(value.strength.wire)),
        "Tradeoff" to str(value.tradeoff),
        "CoachPersonality" to (value.coachPersonality?.let(::str) ?: JsonValue.Null),
        "CoachRecord" to (value.coachRecord?.let(::str) ?: JsonValue.Null),
        "CatcherPersonality" to (value.catcherPersonality?.let(::str) ?: JsonValue.Null),
        "CatcherRecord" to (value.catcherRecord?.let(::str) ?: JsonValue.Null),
    )

    private fun writeRival(value: HighSchoolRival): JsonValue.Obj = obj(
        "Id" to str(value.id),
        "Name" to str(value.name),
        "Archetype" to str(value.archetype),
        "Contact" to num(value.contact),
        "Discipline" to num(value.discipline),
        "Power" to num(value.power),
        "Personality" to (value.personality?.let(::str) ?: JsonValue.Null),
        "SignatureRecord" to (value.signatureRecord?.let(::str) ?: JsonValue.Null),
    )

    private fun writeChapter(value: HighSchoolChapter): JsonValue.Obj = obj(
        "Number" to num(value.number),
        "Title" to str(value.title),
        "SchoolYear" to num(value.schoolYear),
        "Season" to str(value.season),
        "Theme" to str(value.theme),
    )

    private fun writePerformance(value: HighSchoolPerformance): JsonValue.Obj = obj(
        "ImportantGamesCompleted" to num(value.importantGamesCompleted),
        "Pitches" to num(value.pitches),
        "Strikeouts" to num(value.strikeouts),
        "Walks" to num(value.walks),
        "RunsAllowed" to num(value.runsAllowed),
        "ExpectedDamage" to num(value.expectedDamage),
        "ActualDamage" to num(value.actualDamage),
        "Outs" to if (value.outs == 0) JsonValue.Null else num(value.outs),
        "Hits" to if (value.hits == 0) JsonValue.Null else num(value.hits),
    )

    private fun writeSchedule(value: HighSchoolSchedule): JsonValue.Obj = obj(
        "TrainingsByChapter" to JsonValue.Arr(value.trainingsByChapter.map { num(it) }),
        "MilestonesByChapter" to JsonValue.Arr(
            value.milestonesByChapter.map { chapter ->
                JsonValue.Arr(chapter.map { str(pascalPhase(it)) })
            },
        ),
        "TrainingTotal" to num(value.trainingTotal),
        "RelationshipTotal" to num(value.milestonesByChapter.sumOf { chapter -> chapter.count { it == HighSchoolPhase.RELATIONSHIP } }),
        "ImportantGameTotal" to num(value.milestonesByChapter.sumOf { chapter -> chapter.count { it == HighSchoolPhase.IMPORTANT_GAME } }),
        "AwakeningTotal" to num(value.milestonesByChapter.sumOf { chapter -> chapter.count { it == HighSchoolPhase.AWAKENING } }),
        "CommitmentToken" to str(scheduleToken(value)),
    )

    private fun writeTalent(value: HighSchoolTalent): JsonValue.Obj = obj(
        "Stuff" to str(value.stuff.name),
        "Command" to str(value.command.name),
        "Movement" to str(value.movement.name),
        "Stamina" to str(value.stamina.name),
        "StuffPressure" to num(value.stuffPressure),
        "CommandPressure" to num(value.commandPressure),
        "MovementPressure" to num(value.movementPressure),
        "StaminaPressure" to num(value.staminaPressure),
    )

    private fun writeEvent(value: HighSchoolRelationshipEvent): JsonValue.Obj = obj(
        "Id" to str(value.id),
        "Title" to str(value.title),
        "Category" to str(value.category),
        "Summary" to str(value.summary),
    )

    private fun writeOpportunity(value: HighSchoolTrainingOpportunity): JsonValue.Obj = obj(
        "Focus" to str(pascalName(value.focus.wire)),
        "Reason" to str(value.reason),
    )

    private fun writeTraining(value: HighSchoolTrainingResult?, previous: JsonValue?): JsonValue {
        if (value == null) return JsonValue.Null
        val previousObj = previous as? JsonValue.Obj
        val previousNumber = (previousObj?.get("Number") as? JsonValue.Num)?.raw?.toIntOrNull()
        if (previousObj != null && previousNumber == value.number) return previousObj
        return obj(
            "Number" to num(value.number),
            "Focus" to str(pascalName(value.focus.wire)),
            "Intensity" to str(pascalName(value.intensity.wire)),
            "Growth" to num(value.growth),
            "FatigueChange" to num(value.fatigueChange),
            "Feedback" to str(trainingFeedback(value)),
            "MetricBefore" to JsonValue.Null,
            "MetricAfter" to JsonValue.Null,
            "FatigueBefore" to JsonValue.Null,
            "FatigueAfter" to JsonValue.Null,
            "OpportunityHit" to JsonValue.Bool(value.opportunityHit),
            "BloomedAbility" to JsonValue.Null,
            "BloomedGrade" to JsonValue.Null,
            "Jackpot" to JsonValue.Bool(false),
            "TargetPitch" to JsonValue.Null,
        )
    }

    private fun writeRelationship(value: HighSchoolRelationshipResult, state: HighSchoolState): JsonValue.Obj {
        val category = state.currentRelationshipCategory ?: value.target.wire
        val title = state.currentRelationshipEvent?.title ?: value.target.wire
        return obj(
            "Number" to num(value.number),
            "Category" to str(category),
            "Title" to str(title),
            "Response" to str(pascalName(value.response.wire)),
            "TrustBefore" to num(value.trustBefore),
            "TrustAfter" to num(value.trustAfter),
            "FatigueBefore" to num(value.fatigueBefore),
            "FatigueAfter" to num(value.fatigueAfter),
            "FanInterestBefore" to num(value.fanInterestBefore),
            "FanInterestAfter" to num(value.fanInterestAfter),
            "GrowthFocus" to (value.growthFocus?.let { str(pascalName(it.wire)) } ?: JsonValue.Null),
            "AbilityBefore" to JsonValue.Null,
            "AbilityAfter" to JsonValue.Null,
            "Feedback" to str(relationshipFeedback(value)),
        )
    }

    private fun writeDraft(value: HighSchoolDraftResult): JsonValue.Obj = obj(
        "Outcome" to str(if (value.outcome == HighSchoolDraftOutcome.DRAFTED) "Drafted" else "Undrafted"),
        "EvaluationScore" to num(value.evaluationScore),
        "ProjectedRange" to str(value.projectedRange),
        "Team" to ((value.teamId ?: value.team?.id)?.let { id ->
            obj("Id" to str(id), "Name" to str(value.team?.name ?: id))
        } ?: JsonValue.Null),
        "Round" to (value.round?.let(::num) ?: JsonValue.Null),
        "OverallPick" to (value.overallPick?.let(::num) ?: JsonValue.Null),
        "SigningBonus" to (value.signingBonus?.let(::num) ?: JsonValue.Null),
        "FirstSeasonGoal" to (value.firstSeasonGoal?.let(::str) ?: JsonValue.Null),
        "EvaluationBreakdown" to strings(value.evaluationBreakdown.orEmpty()),
        "Summary" to str(value.summary),
    )

    private fun writeScenario(state: HighSchoolState, previous: JsonValue?): JsonValue {
        val scenario = state.currentGameScenario
        if (scenario != null) {
            return obj(
                "Id" to str(scenario.id),
                "Title" to str(scenario.title),
                "Inning" to num(scenario.inning),
                "Outs" to num(scenario.outs),
                "Runners" to obj(
                    "FirstOccupied" to JsonValue.Bool(scenario.firstOccupied),
                    "SecondOccupied" to JsonValue.Bool(scenario.secondOccupied),
                    "ThirdOccupied" to JsonValue.Bool(scenario.thirdOccupied),
                    "LeadRunnerSpeed" to num(scenario.leadRunnerSpeed),
                ),
                "Leverage" to num(scenario.leverage),
                "Narrative" to str(scenario.narrative),
                "ScoreDifferential" to (scenario.scoreDifferential?.let(::num) ?: JsonValue.Null),
                "MinChapter" to num(scenario.minChapter),
            )
        }
        val previousObj = previous as? JsonValue.Obj
        val previousId = (previousObj?.get("Id") as? JsonValue.Str)?.value
        if (previousObj != null && previousId != null && previousId == state.currentGameScenarioId) {
            return previousObj
        }
        return JsonValue.Null
    }

    private fun relationshipFeedback(value: HighSchoolRelationshipResult): String = when (value.response) {
        HighSchoolRelationshipResponse.LISTEN -> "상대의 말을 끝까지 듣고 다음 준비 기준을 함께 확인했습니다."
        HighSchoolRelationshipResponse.EXPLAIN -> "선택의 이유를 기록으로 설명했습니다."
        HighSchoolRelationshipResponse.CHALLENGE -> "결과로 답하기로 했습니다."
    }

    private fun trainingFeedback(value: HighSchoolTrainingResult): String {
        val label = when (value.focus) {
            HighSchoolTrainingFocus.VELOCITY -> "구위"
            HighSchoolTrainingFocus.COMMAND -> "제구"
            HighSchoolTrainingFocus.BREAKING_BALL -> "변화구"
            HighSchoolTrainingFocus.STAMINA, HighSchoolTrainingFocus.RECOVERY -> "체력"
            HighSchoolTrainingFocus.GAME_PLANNING -> "타자 상대법과 제구"
        }
        return "${label} 능력치가 ${value.growth} 올랐습니다."
    }

    private fun pascalPhase(phase: HighSchoolPhase): String = when (phase) {
        HighSchoolPhase.PROLOGUE -> "Prologue"
        HighSchoolPhase.SCHOOL_SELECTION -> "SchoolSelection"
        HighSchoolPhase.TRAINING -> "Training"
        HighSchoolPhase.RELATIONSHIP -> "Relationship"
        HighSchoolPhase.IMPORTANT_GAME -> "ImportantGame"
        HighSchoolPhase.AWAKENING -> "Awakening"
        HighSchoolPhase.CHAPTER_REVIEW -> "ChapterReview"
        HighSchoolPhase.DRAFT -> "Draft"
        HighSchoolPhase.LEGACY -> "Legacy"
        HighSchoolPhase.COMPLETED -> "Completed"
    }

    private fun pascalPitch(kind: PitchKind): String = when (kind) {
        PitchKind.FOUR_SEAM -> "FourSeam"
        PitchKind.SLIDER -> "Slider"
        PitchKind.CURVEBALL -> "Curveball"
        PitchKind.CHANGEUP -> "Changeup"
    }

    private fun pascalRole(role: PitchUsageRole): String = when (role) {
        PitchUsageRole.PRIMARY -> "Primary"
        PitchUsageRole.SECONDARY -> "Secondary"
        PitchUsageRole.DEVELOPMENT -> "Development"
    }

    private fun bodyValue(raw: String): String = when (raw.lowercase()) {
        "compact" -> "compact"
        "tall" -> "tall"
        else -> "balanced"
    }

    private fun difficultyValue(raw: String): String = when (raw.lowercase()) {
        "relaxed" -> "relaxed"
        "challenging" -> "challenging"
        else -> "standard"
    }

    private fun assistValue(raw: String): String = when (raw.lowercase()) {
        "full" -> "full"
        "minimal" -> "minimal"
        else -> "standard"
    }

    private fun memoryValue(raw: String): String = if (raw.contains('_')) raw else snake(raw)

    private fun pascalName(wire: String): String =
        wire.split('_').joinToString("") { part -> part.replaceFirstChar { it.uppercase() } }

    private fun snake(raw: String): String = buildString {
        raw.forEachIndexed { index, char ->
            if (index > 0 && char.isUpperCase()) append('_')
            append(char.lowercaseChar())
        }
    }

    private fun obj(vararg pairs: Pair<String, JsonValue>): JsonValue.Obj =
        JsonValue.Obj(linkedMapOf(*pairs))
    private fun str(value: String): JsonValue.Str = JsonValue.Str(value)
    private fun num(value: Int): JsonValue.Num = JsonValue.Num(value.toString())
    private fun num(value: ULong): JsonValue.Num = JsonValue.Num(value.toString())
    private fun strings(values: List<String>): JsonValue.Arr = JsonValue.Arr(values.map(::str))
}
