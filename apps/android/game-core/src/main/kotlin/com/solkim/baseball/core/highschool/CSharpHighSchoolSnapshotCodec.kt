package com.solkim.baseball.core.highschool

import com.solkim.baseball.core.pitch.PitchKind
import com.solkim.baseball.core.pitch.PitchProfileSnapshot
import com.solkim.baseball.core.pitch.PitchUsageRole
import com.solkim.baseball.core.pitch.ThrowingHand
import com.solkim.baseball.model.JsonValue
import com.solkim.baseball.model.StrictJson

/**
 * Reads the Newtonsoft PascalCase `HighSchoolCareerSnapshot` blob stored in C# `coreStateJson`.
 *
 * Decode keeps the C# `StateCommitment` as an opaque token. Write-back uses
 * [CSharpHighSchoolSnapshotWire], which re-signs with the C# FNV-1a algorithm so Unity
 * `Restore()`/`Validate()` can read a Kotlin-advanced snapshot.
 */
public object CSharpHighSchoolSnapshotCodec {
    public const val MAX_BYTES: Int = 1 * 1024 * 1024

    private val snapshotFields = setOf(
        "ArmRisk", "AwakeningOptions", "AwakeningSparks", "BalanceVersion", "CareerId", "CareerWind",
        "CatcherTrust", "Chapter", "ChapterTrainingCount", "CurrentGameScenario", "CurrentRelationshipEvent",
        "Difficulty", "DraftResult", "EffectiveWorldRulesVersion", "FanInterest", "Fatigue", "Identity",
        "InjuryRecovery", "Karmas", "LastRelationship", "LastTraining", "LegacyOptions", "LegacyRewardPermille",
        "LifeNumber", "ManagerTrust", "MemorySlots", "MilestoneIndex", "News", "Performance", "Phase",
        "Pitcher", "RelationshipTrust", "RelationshipsCompleted", "Revision", "Rival", "RivalTrust",
        "Schedule", "School", "SchoolOptions", "SeasonLog", "SelectedAwakenings", "SelectedMemories",
        "SoulBoosts", "StateCommitment", "Talent", "TotalTrainingsCompleted", "TrainingOpportunity",
        "WorldRulesVersion",
    )

    public fun decode(bytes: ByteArray, presetId: String? = null): HighSchoolState {
        if (bytes.isEmpty()) throw CSharpHighSchoolSnapshotCodecException("csharp.snapshot.empty")
        if (bytes.size > MAX_BYTES) throw CSharpHighSchoolSnapshotCodecException("csharp.snapshot.too_large")
        val root = try {
            StrictJson.parseUtf8(bytes) as? JsonValue.Obj
                ?: throw CSharpHighSchoolSnapshotCodecException("csharp.snapshot.root")
        } catch (error: CSharpHighSchoolSnapshotCodecException) {
            throw error
        } catch (error: Exception) {
            throw CSharpHighSchoolSnapshotCodecException("csharp.snapshot.json")
        }
        return decodeObject(root, presetId)
    }

    public fun decodeObject(root: JsonValue.Obj, presetId: String? = null): HighSchoolState {
        val unknown = root.entries.keys - snapshotFields
        if (unknown.isNotEmpty()) {
            throw CSharpHighSchoolSnapshotCodecException("csharp.snapshot.unknown:${unknown.sorted().joinToString(",")}")
        }
        val required = setOf(
            "CareerId", "Revision", "LifeNumber", "Phase", "Identity", "Difficulty", "Pitcher",
            "Rival", "Chapter", "StateCommitment",
        )
        val missing = required - root.entries.keys
        if (missing.isNotEmpty()) {
            throw CSharpHighSchoolSnapshotCodecException("csharp.snapshot.missing:${missing.sorted().joinToString(",")}")
        }

        val pitcher = readPitcher(root.obj("Pitcher"))
        val relationshipTrust = root.intOrDefault("RelationshipTrust", 50)
        val event = root.nullableObj("CurrentRelationshipEvent")?.let(::readRelationshipEvent)
        return HighSchoolState(
            careerId = root.string("CareerId"),
            revision = root.ulong("Revision"),
            lifeNumber = root.int("LifeNumber"),
            presetId = presetId ?: inferPresetId(pitcher.id),
            phase = pascalPhase(root.string("Phase")),
            identity = readIdentity(root.obj("Identity")),
            difficulty = readDifficulty(root.obj("Difficulty")),
            karmas = root.stringsOrEmpty("Karmas").map { wireEnum(HighSchoolKarma.entries, it, "karma") { karma -> karma.wire } },
            soulBoosts = root.stringsOrEmpty("SoulBoosts").map { wireEnum(HighSchoolSoulBoost.entries, it, "soulBoost") { boost -> boost.wire } },
            legacyRewardPermille = root.intOrDefault("LegacyRewardPermille", 1000),
            memorySlots = root.intOrDefault("MemorySlots", 3),
            pitcher = pitcher,
            talent = root.nullableObj("Talent")?.let(::readTalent) ?: HighSchoolTalent(
                HighSchoolTalentGrade.C, HighSchoolTalentGrade.C, HighSchoolTalentGrade.C, HighSchoolTalentGrade.C,
            ),
            schoolOptions = root.arrayOrEmpty("SchoolOptions").mapIndexed { index, item ->
                readSchool(item.asObj("SchoolOptions[$index]"))
            },
            school = root.nullableObj("School")?.let(::readSchool),
            rival = readRival(root.obj("Rival")),
            chapter = readChapter(root.obj("Chapter")),
            schedule = root.nullableObj("Schedule")?.let(::readSchedule) ?: HighSchoolSchedule(emptyList(), emptyList()),
            chapterTrainingCount = root.intOrDefault("ChapterTrainingCount", 0),
            totalTrainingsCompleted = root.intOrDefault("TotalTrainingsCompleted", 0),
            milestoneIndex = root.intOrDefault("MilestoneIndex", 0),
            relationshipsCompleted = root.intOrDefault("RelationshipsCompleted", 0),
            relationshipTrust = relationshipTrust,
            managerTrust = root.intOrDefault("ManagerTrust", relationshipTrust),
            catcherTrust = root.intOrDefault("CatcherTrust", relationshipTrust),
            rivalTrust = root.intOrDefault("RivalTrust", relationshipTrust),
            selectedAwakenings = root.stringsOrEmpty("SelectedAwakenings").map { wireEnum(HighSchoolAwakening.entries, it, "awakening") { it.wire } },
            awakeningOptions = root.stringsOrEmpty("AwakeningOptions").map { wireEnum(HighSchoolAwakening.entries, it, "awakening") { it.wire } },
            awakeningSparks = root.intOrDefault("AwakeningSparks", 0),
            fatigue = root.intOrDefault("Fatigue", 0),
            performance = root.nullableObj("Performance")?.let(::readPerformance) ?: HighSchoolPerformance(),
            currentGameScenarioId = root.nullableObj("CurrentGameScenario")?.stringOrNull("Id"),
            currentGameScenario = root.nullableObj("CurrentGameScenario")?.let(::readGameScenario),
            currentRelationshipTarget = event?.category?.let(::relationshipTargetOrNull),
            trainingOpportunity = root.nullableObj("TrainingOpportunity")?.let(::readTrainingOpportunity),
            lastTraining = root.nullableObj("LastTraining")?.let(::readTraining),
            lastRelationship = root.nullableObj("LastRelationship")?.let(::readRelationship),
            fanInterest = root.intOrDefault("FanInterest", 0),
            armRisk = root.intOrDefault("ArmRisk", 0),
            injuryRecovery = root.intOrDefault("InjuryRecovery", 0),
            automaticGames = 0,
            automaticOuts = 0,
            automaticRunsAllowed = 0,
            draftResult = root.nullableObj("DraftResult")?.let(::readDraft),
            legacyOptions = root.stringsOrEmpty("LegacyOptions"),
            selectedMemories = root.stringsOrEmpty("SelectedMemories"),
            currentRelationshipCategory = event?.category,
            currentRelationshipEvent = event,
            news = root.stringsOrEmpty("News"),
            balanceVersion = root.intOrDefault("BalanceVersion", HighSchoolContentCatalog.BALANCE_VERSION),
            worldRulesVersion = root.intOrDefault("WorldRulesVersion", HighSchoolContentCatalog.WORLD_RULES_VERSION),
            rebirthEcho = null,
            recentRelationshipEventIds = emptyList(),
            stateCommitment = root.string("StateCommitment"),
        )
    }

    public fun inferPresetId(pitcherId: String): String = when (pitcherId) {
        "pitcher-power" -> "power_prospect"
        "pitcher-command" -> "precision_commander"
        "pitcher-artist" -> "breaking_ball_artist"
        "pitcher-stamina" -> "innings_eater"
        else -> pitcherId
    }

    private fun readIdentity(value: JsonValue.Obj): HighSchoolIdentity {
        value.requireKnown(setOf("Name", "ThrowingHand", "BodyType", "Region"), "Identity")
        return HighSchoolIdentity(
            name = value.string("Name"),
            throwingHand = pascalScalar(value.string("ThrowingHand")),
            bodyType = pascalScalar(value.string("BodyType")),
            region = value.string("Region"),
        )
    }

    private fun readDifficulty(value: JsonValue.Obj): HighSchoolDifficulty {
        value.requireKnown(
            setOf("CareerHarshness", "InformationClarity", "SimulationDifficulty", "InterventionAssist"),
            "Difficulty",
        )
        return HighSchoolDifficulty(
            careerHarshness = pascalScalar(value.string("CareerHarshness")),
            informationClarity = pascalScalar(value.string("InformationClarity")),
            simulationDifficulty = pascalScalar(value.string("SimulationDifficulty")),
            interventionAssist = pascalScalar(value.string("InterventionAssist")),
        )
    }

    private fun readPitcher(value: JsonValue.Obj): HighSchoolPitcher {
        value.requireKnown(
            setOf("Id", "Name", "Stuff", "Command", "Movement", "Stamina", "PitchProfiles", "ThrowingHand"),
            "Pitcher",
        )
        val profiles = value.arrayOrEmpty("PitchProfiles").mapIndexed { index, item ->
            readPitchProfile(item.asObj("PitchProfiles[$index]"))
        }
        return HighSchoolPitcher(
            id = value.string("Id"),
            name = value.string("Name"),
            stuff = value.int("Stuff"),
            command = value.int("Command"),
            movement = value.int("Movement"),
            stamina = value.int("Stamina"),
            pitchProfiles = profiles,
            throwingHand = when (value.stringOrNull("ThrowingHand")?.lowercase()) {
                null, "right" -> ThrowingHand.RIGHT
                "left" -> ThrowingHand.LEFT
                else -> throw CSharpHighSchoolSnapshotCodecException("csharp.pitcher.hand")
            },
        )
    }

    private fun readPitchProfile(value: JsonValue.Obj): PitchProfileSnapshot {
        value.requireKnown(
            setOf("PitchType", "Role", "VelocityTenthsKph", "Control", "Command", "Movement", "Whiff", "WeakContact", "FatigueCost"),
            "PitchProfile",
        )
        return PitchProfileSnapshot(
            pitchType = pascalPitchKind(value.string("PitchType")),
            role = pascalUsageRole(value.string("Role")),
            velocityTenthsKph = value.int("VelocityTenthsKph"),
            control = value.int("Control"),
            command = value.int("Command"),
            movement = value.int("Movement"),
            whiff = value.int("Whiff"),
            weakContact = value.int("WeakContact"),
            fatigueCost = value.int("FatigueCost"),
        )
    }

    private fun readTalent(value: JsonValue.Obj): HighSchoolTalent {
        value.requireKnown(
            setOf("Stuff", "Command", "Movement", "Stamina", "StuffPressure", "CommandPressure", "MovementPressure", "StaminaPressure"),
            "Talent",
        )
        return HighSchoolTalent(
            stuff = talentGrade(value.string("Stuff")),
            command = talentGrade(value.string("Command")),
            movement = talentGrade(value.string("Movement")),
            stamina = talentGrade(value.string("Stamina")),
            stuffPressure = value.intOrDefault("StuffPressure", 0),
            commandPressure = value.intOrDefault("CommandPressure", 0),
            movementPressure = value.intOrDefault("MovementPressure", 0),
            staminaPressure = value.intOrDefault("StaminaPressure", 0),
        )
    }

    private fun readSchool(value: JsonValue.Obj): HighSchoolSchool {
        value.requireKnown(
            setOf(
                "Id", "Name", "Philosophy", "CoachName", "CoachArchetype", "CatcherName", "CatcherArchetype",
                "Strength", "Tradeoff", "CoachPersonality", "CoachRecord", "CatcherPersonality", "CatcherRecord",
            ),
            "School",
        )
        return HighSchoolSchool(
            id = pascalSchool(value.string("Id")),
            name = value.string("Name"),
            philosophy = value.string("Philosophy"),
            coachName = value.string("CoachName"),
            coachArchetype = value.string("CoachArchetype"),
            catcherName = value.string("CatcherName"),
            catcherArchetype = value.string("CatcherArchetype"),
            strength = pascalFocus(value.string("Strength")),
            tradeoff = value.string("Tradeoff"),
            coachPersonality = value.stringOrNull("CoachPersonality"),
            coachRecord = value.stringOrNull("CoachRecord"),
            catcherPersonality = value.stringOrNull("CatcherPersonality"),
            catcherRecord = value.stringOrNull("CatcherRecord"),
        )
    }

    private fun readRival(value: JsonValue.Obj): HighSchoolRival {
        value.requireKnown(
            setOf("Id", "Name", "Archetype", "Contact", "Discipline", "Power", "Personality", "SignatureRecord"),
            "Rival",
        )
        return HighSchoolRival(
            id = value.string("Id"),
            name = value.string("Name"),
            archetype = value.string("Archetype"),
            contact = value.int("Contact"),
            discipline = value.int("Discipline"),
            power = value.int("Power"),
            personality = value.stringOrNull("Personality"),
            signatureRecord = value.stringOrNull("SignatureRecord"),
        )
    }

    private fun readChapter(value: JsonValue.Obj): HighSchoolChapter {
        value.requireKnown(setOf("Number", "Title", "SchoolYear", "Season", "Theme"), "Chapter")
        return HighSchoolChapter(
            number = value.int("Number"),
            title = value.string("Title"),
            schoolYear = value.int("SchoolYear"),
            season = value.string("Season"),
            theme = value.string("Theme"),
        )
    }

    private fun readSchedule(value: JsonValue.Obj): HighSchoolSchedule {
        value.requireKnown(
            setOf(
                "TrainingsByChapter", "MilestonesByChapter", "TrainingTotal", "RelationshipTotal",
                "ImportantGameTotal", "AwakeningTotal", "CommitmentToken",
            ),
            "Schedule",
        )
        val trainings = value.arrayOrEmpty("TrainingsByChapter").mapIndexed { index, item ->
            item.intValue("Schedule.TrainingsByChapter[$index]")
        }
        val milestones = value.arrayOrEmpty("MilestonesByChapter").mapIndexed { index, item ->
            item.asArr("Schedule.MilestonesByChapter[$index]").values.mapIndexed { phaseIndex, phase ->
                pascalPhase(phase.stringValue("Schedule.MilestonesByChapter[$index][$phaseIndex]"))
            }
        }
        return HighSchoolSchedule(trainings, milestones)
    }

    private fun readPerformance(value: JsonValue.Obj): HighSchoolPerformance {
        value.requireKnown(
            setOf("ImportantGamesCompleted", "Pitches", "Strikeouts", "Walks", "RunsAllowed", "ExpectedDamage", "ActualDamage", "Outs", "Hits"),
            "Performance",
        )
        return HighSchoolPerformance(
            importantGamesCompleted = value.intOrDefault("ImportantGamesCompleted", 0),
            pitches = value.intOrDefault("Pitches", 0),
            strikeouts = value.intOrDefault("Strikeouts", 0),
            walks = value.intOrDefault("Walks", 0),
            runsAllowed = value.intOrDefault("RunsAllowed", 0),
            expectedDamage = value.intOrDefault("ExpectedDamage", 0),
            actualDamage = value.intOrDefault("ActualDamage", 0),
            outs = value.intOrDefault("Outs", 0),
            hits = value.intOrDefault("Hits", 0),
        )
    }

    private fun readGameScenario(value: JsonValue.Obj): HighSchoolGameScenario {
        value.requireKnown(
            setOf("Id", "Title", "Inning", "Outs", "Runners", "Leverage", "Narrative", "ScoreDifferential", "MinChapter"),
            "CurrentGameScenario",
        )
        val runners = value.nullableObj("Runners")
        runners?.requireKnown(
            setOf("FirstOccupied", "SecondOccupied", "ThirdOccupied", "LeadRunnerSpeed"),
            "CurrentGameScenario.Runners",
        )
        return HighSchoolGameScenario(
            id = value.string("Id"),
            title = value.string("Title"),
            inning = value.intOrDefault("Inning", 1),
            outs = value.intOrDefault("Outs", 0),
            firstOccupied = runners?.boolOrDefault("FirstOccupied", false) ?: false,
            secondOccupied = runners?.boolOrDefault("SecondOccupied", false) ?: false,
            thirdOccupied = runners?.boolOrDefault("ThirdOccupied", false) ?: false,
            leadRunnerSpeed = runners?.intOrDefault("LeadRunnerSpeed", 50) ?: 50,
            leverage = value.intOrDefault("Leverage", 50),
            narrative = value.stringOrNull("Narrative").orEmpty(),
            scoreDifferential = value.intOrNull("ScoreDifferential"),
            minChapter = value.intOrDefault("MinChapter", 1),
        )
    }

    private fun readRelationshipEvent(value: JsonValue.Obj): HighSchoolRelationshipEvent {
        value.requireKnown(setOf("Id", "Title", "Category", "Summary"), "CurrentRelationshipEvent")
        return HighSchoolRelationshipEvent(
            id = value.string("Id"),
            title = value.string("Title"),
            category = value.string("Category"),
            summary = value.string("Summary"),
        )
    }

    private fun readTrainingOpportunity(value: JsonValue.Obj): HighSchoolTrainingOpportunity {
        value.requireKnown(setOf("Focus", "Reason"), "TrainingOpportunity")
        return HighSchoolTrainingOpportunity(pascalFocus(value.string("Focus")), value.string("Reason"))
    }

    private fun readTraining(value: JsonValue.Obj): HighSchoolTrainingResult {
        value.requireKnown(
            setOf(
                "Number", "Focus", "Intensity", "Growth", "FatigueChange", "Feedback", "MetricBefore",
                "MetricAfter", "FatigueBefore", "FatigueAfter", "OpportunityHit", "BloomedAbility",
                "BloomedGrade", "Jackpot", "TargetPitch",
            ),
            "LastTraining",
        )
        return HighSchoolTrainingResult(
            number = value.int("Number"),
            focus = pascalFocus(value.string("Focus")),
            intensity = pascalIntensity(value.string("Intensity")),
            growth = value.int("Growth"),
            fatigueChange = value.int("FatigueChange"),
            opportunityHit = value.boolOrDefault("OpportunityHit", false),
            bloomed = value["BloomedAbility"] !is JsonValue.Null && value["BloomedAbility"] != null,
        )
    }

    private fun readRelationship(value: JsonValue.Obj): HighSchoolRelationshipResult? {
        value.requireKnown(
            setOf(
                "Number", "Category", "Title", "Response", "TrustBefore", "TrustAfter", "FatigueBefore",
                "FatigueAfter", "FanInterestBefore", "FanInterestAfter", "GrowthFocus", "AbilityBefore",
                "AbilityAfter", "Feedback",
            ),
            "LastRelationship",
        )
        val target = relationshipTargetOrNull(value.string("Category")) ?: return null
        return HighSchoolRelationshipResult(
            number = value.int("Number"),
            target = target,
            response = pascalResponse(value.string("Response")),
            trustBefore = value.int("TrustBefore"),
            trustAfter = value.int("TrustAfter"),
            fatigueBefore = value.int("FatigueBefore"),
            fatigueAfter = value.int("FatigueAfter"),
            fanInterestBefore = value.int("FanInterestBefore"),
            fanInterestAfter = value.int("FanInterestAfter"),
            growthFocus = value.stringOrNull("GrowthFocus")?.let(::pascalFocus),
        )
    }

    private fun readDraft(value: JsonValue.Obj): HighSchoolDraftResult {
        value.requireKnown(
            setOf("Outcome", "EvaluationScore", "ProjectedRange", "Team", "Round", "OverallPick", "SigningBonus"),
            "DraftResult",
        )
        val team = value.nullableObj("Team")
        return HighSchoolDraftResult(
            outcome = when (value.string("Outcome")) {
                "Drafted", "drafted" -> HighSchoolDraftOutcome.DRAFTED
                "Undrafted", "undrafted" -> HighSchoolDraftOutcome.UNDRAFTED
                else -> throw CSharpHighSchoolSnapshotCodecException("csharp.draft.outcome")
            },
            evaluationScore = value.int("EvaluationScore"),
            projectedRange = value.stringOrNull("ProjectedRange").orEmpty(),
            teamId = team?.stringOrNull("Id"),
            team = null,
            round = value.intOrNull("Round"),
            overallPick = value.intOrNull("OverallPick"),
            signingBonus = value.intOrNull("SigningBonus"),
        )
    }

    private fun pascalPhase(raw: String): HighSchoolPhase = when (raw) {
        "Prologue", "prologue" -> HighSchoolPhase.PROLOGUE
        "SchoolSelection", "school_selection" -> HighSchoolPhase.SCHOOL_SELECTION
        "Training", "training" -> HighSchoolPhase.TRAINING
        "Relationship", "relationship" -> HighSchoolPhase.RELATIONSHIP
        "ImportantGame", "important_game" -> HighSchoolPhase.IMPORTANT_GAME
        "Awakening", "awakening" -> HighSchoolPhase.AWAKENING
        "ChapterReview", "chapter_review" -> HighSchoolPhase.CHAPTER_REVIEW
        "Draft", "draft" -> HighSchoolPhase.DRAFT
        "Legacy", "legacy" -> HighSchoolPhase.LEGACY
        "Completed", "completed" -> HighSchoolPhase.COMPLETED
        else -> throw CSharpHighSchoolSnapshotCodecException("csharp.phase:$raw")
    }

    private fun pascalSchool(raw: String): HighSchoolSchoolId = when (raw) {
        "HanbitTraditional", "hanbit_traditional" -> HighSchoolSchoolId.HANBIT_TRADITIONAL
        "MiraeAnalytics", "mirae_analytics" -> HighSchoolSchoolId.MIRAE_ANALYTICS
        "HaedongPower", "haedong_power" -> HighSchoolSchoolId.HAEDONG_POWER
        "CheongamDevelopment", "cheongam_development" -> HighSchoolSchoolId.CHEONGAM_DEVELOPMENT
        else -> throw CSharpHighSchoolSnapshotCodecException("csharp.school:$raw")
    }

    private fun pascalFocus(raw: String): HighSchoolTrainingFocus = when (raw) {
        "Velocity", "velocity" -> HighSchoolTrainingFocus.VELOCITY
        "Command", "command" -> HighSchoolTrainingFocus.COMMAND
        "BreakingBall", "breaking_ball" -> HighSchoolTrainingFocus.BREAKING_BALL
        "Stamina", "stamina" -> HighSchoolTrainingFocus.STAMINA
        "Recovery", "recovery" -> HighSchoolTrainingFocus.RECOVERY
        "GamePlanning", "game_planning" -> HighSchoolTrainingFocus.GAME_PLANNING
        else -> throw CSharpHighSchoolSnapshotCodecException("csharp.focus:$raw")
    }

    private fun pascalIntensity(raw: String): HighSchoolTrainingIntensity = when (raw) {
        "Light", "light" -> HighSchoolTrainingIntensity.LIGHT
        "Standard", "standard" -> HighSchoolTrainingIntensity.STANDARD
        "Intensive", "intensive" -> HighSchoolTrainingIntensity.INTENSIVE
        else -> throw CSharpHighSchoolSnapshotCodecException("csharp.intensity:$raw")
    }

    private fun pascalPitchKind(raw: String): PitchKind = when (raw) {
        "FourSeam", "four_seam" -> PitchKind.FOUR_SEAM
        "Slider", "slider" -> PitchKind.SLIDER
        "Curveball", "curveball" -> PitchKind.CURVEBALL
        "Changeup", "changeup" -> PitchKind.CHANGEUP
        else -> throw CSharpHighSchoolSnapshotCodecException("csharp.pitch:$raw")
    }

    private fun pascalUsageRole(raw: String): PitchUsageRole = when (raw) {
        "Primary", "primary" -> PitchUsageRole.PRIMARY
        "Secondary", "secondary" -> PitchUsageRole.SECONDARY
        "Development", "development" -> PitchUsageRole.DEVELOPMENT
        else -> throw CSharpHighSchoolSnapshotCodecException("csharp.role:$raw")
    }

    private fun pascalResponse(raw: String): HighSchoolRelationshipResponse = when (raw) {
        "Listen", "listen" -> HighSchoolRelationshipResponse.LISTEN
        "Explain", "explain" -> HighSchoolRelationshipResponse.EXPLAIN
        "Challenge", "challenge" -> HighSchoolRelationshipResponse.CHALLENGE
        else -> throw CSharpHighSchoolSnapshotCodecException("csharp.response:$raw")
    }

    private fun relationshipTargetOrNull(category: String): HighSchoolRelationshipTarget? = when (category) {
        "coach" -> HighSchoolRelationshipTarget.COACH
        "catcher" -> HighSchoolRelationshipTarget.CATCHER
        "rival" -> HighSchoolRelationshipTarget.RIVAL
        else -> null
    }

    private fun pascalScalar(raw: String): String = raw.replaceFirstChar { it.lowercase() }

    private fun talentGrade(raw: String): HighSchoolTalentGrade =
        HighSchoolTalentGrade.entries.firstOrNull { it.name == raw }
            ?: throw CSharpHighSchoolSnapshotCodecException("csharp.talent:$raw")

    private fun <E : Enum<E>> wireEnum(values: Iterable<E>, raw: String, field: String, wire: (E) -> String): E {
        val normalized = if (raw.contains('_')) raw else pascalToSnake(raw)
        return values.firstOrNull { wire(it) == raw || wire(it) == normalized }
            ?: throw CSharpHighSchoolSnapshotCodecException("csharp.$field:$raw")
    }

    private fun pascalToSnake(raw: String): String = buildString {
        raw.forEachIndexed { index, char ->
            if (index > 0 && char.isUpperCase()) append('_')
            append(char.lowercaseChar())
        }
    }

    private fun JsonValue.Obj.requireKnown(allowed: Set<String>, field: String) {
        val unknown = entries.keys - allowed
        if (unknown.isNotEmpty()) throw CSharpHighSchoolSnapshotCodecException("csharp.$field.unknown:${unknown.sorted().joinToString(",")}")
    }

    private fun JsonValue.Obj.obj(name: String): JsonValue.Obj =
        this[name] as? JsonValue.Obj ?: throw CSharpHighSchoolSnapshotCodecException("csharp.$name.object")
    private fun JsonValue.Obj.nullableObj(name: String): JsonValue.Obj? = when (val value = this[name]) {
        null, JsonValue.Null -> null
        is JsonValue.Obj -> value
        else -> throw CSharpHighSchoolSnapshotCodecException("csharp.$name.object_or_null")
    }
    private fun JsonValue.Obj.string(name: String): String =
        (this[name] as? JsonValue.Str)?.value ?: throw CSharpHighSchoolSnapshotCodecException("csharp.$name.string")
    private fun JsonValue.Obj.stringOrNull(name: String): String? = when (val value = this[name]) {
        null, JsonValue.Null -> null
        is JsonValue.Str -> value.value
        else -> throw CSharpHighSchoolSnapshotCodecException("csharp.$name.string_or_null")
    }
    private fun JsonValue.Obj.int(name: String): Int =
        intOrNull(name) ?: throw CSharpHighSchoolSnapshotCodecException("csharp.$name.integer")
    private fun JsonValue.Obj.intOrNull(name: String): Int? = when (val value = this[name]) {
        null, JsonValue.Null -> null
        is JsonValue.Num -> value.raw.toIntOrNull()
        else -> throw CSharpHighSchoolSnapshotCodecException("csharp.$name.integer")
    }
    private fun JsonValue.Obj.intOrDefault(name: String, default: Int): Int = intOrNull(name) ?: default
    private fun JsonValue.Obj.ulong(name: String): ULong = when (val value = this[name]) {
        is JsonValue.Num -> value.raw.toULongOrNull()
        is JsonValue.Str -> value.value.toULongOrNull()
        else -> null
    } ?: throw CSharpHighSchoolSnapshotCodecException("csharp.$name.ulong")
    private fun JsonValue.Obj.boolOrDefault(name: String, default: Boolean): Boolean = when (val value = this[name]) {
        null, JsonValue.Null -> default
        is JsonValue.Bool -> value.value
        else -> throw CSharpHighSchoolSnapshotCodecException("csharp.$name.boolean")
    }
    private fun JsonValue.Obj.arrayOrEmpty(name: String): List<JsonValue> = when (val value = this[name]) {
        null, JsonValue.Null -> emptyList()
        is JsonValue.Arr -> value.values
        else -> throw CSharpHighSchoolSnapshotCodecException("csharp.$name.array")
    }
    private fun JsonValue.Obj.stringsOrEmpty(name: String): List<String> =
        arrayOrEmpty(name).mapIndexed { index, item ->
            (item as? JsonValue.Str)?.value ?: throw CSharpHighSchoolSnapshotCodecException("csharp.$name[$index].string")
        }
    private fun JsonValue.asObj(field: String): JsonValue.Obj =
        this as? JsonValue.Obj ?: throw CSharpHighSchoolSnapshotCodecException("csharp.$field.object")
    private fun JsonValue.asArr(field: String): JsonValue.Arr =
        this as? JsonValue.Arr ?: throw CSharpHighSchoolSnapshotCodecException("csharp.$field.array")
    private fun JsonValue.intValue(field: String): Int =
        (this as? JsonValue.Num)?.raw?.toIntOrNull() ?: throw CSharpHighSchoolSnapshotCodecException("csharp.$field.integer")
    private fun JsonValue.stringValue(field: String): String =
        (this as? JsonValue.Str)?.value ?: throw CSharpHighSchoolSnapshotCodecException("csharp.$field.string")
}

public class CSharpHighSchoolSnapshotCodecException(message: String) : IllegalArgumentException(message)
