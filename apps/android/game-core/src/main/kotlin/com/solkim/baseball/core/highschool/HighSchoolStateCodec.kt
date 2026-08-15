package com.solkim.baseball.core.highschool

import com.solkim.baseball.model.JsonValue
import com.solkim.baseball.model.StrictJson

/**
 * Versioned, deterministic snapshot wire for the Kotlin high-school vertical.
 *
 * This is deliberately a tree codec instead of a permissive serializer: every field is
 * enumerated, unknown/additive fields fail closed, unsigned revisions stay decimal strings, and
 * the kernel commitment is checked after decode. It is a shadow/read-only migration boundary;
 * it is not connected to the production save repository yet.
 */
public object HighSchoolStateCodec {
    public const val SCHEMA: String = "baseball-high-school-state-v1"
    public const val SCHEMA_VERSION: Int = 1
    public const val MAX_BYTES: Int = 1 * 1024 * 1024

    private val kernel = HighSchoolKernel()

    public fun encode(state: HighSchoolState): ByteArray {
        kernel.validateSavedState(state)
        return StrictJson.canonical(root(state)).toByteArray(Charsets.UTF_8)
    }

    public fun decode(bytes: ByteArray): HighSchoolState {
        if (bytes.isEmpty()) throw HighSchoolStateCodecException("file.empty")
        if (bytes.size > MAX_BYTES) throw HighSchoolStateCodecException("file.too_large")
        val document = try {
            StrictJson.parseUtf8(bytes).asObject("root")
        } catch (error: HighSchoolStateCodecException) {
            throw error
        } catch (error: Exception) {
            throw HighSchoolStateCodecException("json.invalid:${error.javaClass.simpleName}")
        }
        document.requireExact(ROOT_FIELDS, "root")
        if (document.string("schema") != SCHEMA) throw HighSchoolStateCodecException("schema.unknown")
        val version = document.integer("schemaVersion")
        if (version > SCHEMA_VERSION) throw HighSchoolStateCodecException("schema.future:$version")
        if (version < SCHEMA_VERSION) throw HighSchoolStateCodecException("schema.migration:$version")
        val state = readState(document.objectValue("state"))
        try {
            kernel.validateSavedState(state)
        } catch (error: IllegalArgumentException) {
            throw HighSchoolStateCodecException(error.message ?: "state.commitment")
        }
        return state
    }

    private fun root(state: HighSchoolState): JsonValue.Obj = obj(
        "schema" to str(SCHEMA),
        "schemaVersion" to num(SCHEMA_VERSION),
        "state" to writeState(state),
    )

    private fun writeState(state: HighSchoolState): JsonValue.Obj = obj(
        "careerId" to str(state.careerId),
        "revision" to str(state.revision.toString()),
        "lifeNumber" to num(state.lifeNumber),
        "presetId" to str(state.presetId),
        "phase" to str(state.phase.wire),
        "identity" to writeIdentity(state.identity),
        "difficulty" to writeDifficulty(state.difficulty),
        "karmas" to strings(state.karmas.map { it.wire }),
        "soulBoosts" to strings(state.soulBoosts.map { it.wire }),
        "legacyRewardPermille" to num(state.legacyRewardPermille),
        "memorySlots" to num(state.memorySlots),
        "pitcher" to writePitcher(state.pitcher),
        "talent" to writeTalent(state.talent),
        "schoolOptions" to array(state.schoolOptions.map(::writeSchool)),
        "school" to (state.school?.let(::writeSchool) ?: JsonValue.Null),
        "rival" to writeRival(state.rival),
        "chapter" to writeChapter(state.chapter),
        "schedule" to writeSchedule(state.schedule),
        "chapterTrainingCount" to num(state.chapterTrainingCount),
        "totalTrainingsCompleted" to num(state.totalTrainingsCompleted),
        "milestoneIndex" to num(state.milestoneIndex),
        "relationshipsCompleted" to num(state.relationshipsCompleted),
        "relationshipTrust" to num(state.relationshipTrust),
        "managerTrust" to num(state.managerTrust),
        "catcherTrust" to num(state.catcherTrust),
        "rivalTrust" to num(state.rivalTrust),
        "selectedAwakenings" to strings(state.selectedAwakenings.map { it.wire }),
        "awakeningOptions" to strings(state.awakeningOptions.map { it.wire }),
        "awakeningSparks" to num(state.awakeningSparks),
        "fatigue" to num(state.fatigue),
        "performance" to writePerformance(state.performance),
        "currentGameScenarioId" to (state.currentGameScenarioId?.let(::str) ?: JsonValue.Null),
        "currentGameScenario" to (state.currentGameScenario?.let(::writeScenario) ?: JsonValue.Null),
        "currentRelationshipTarget" to (state.currentRelationshipTarget?.wire?.let(::str) ?: JsonValue.Null),
        "currentRelationshipCategory" to (state.currentRelationshipCategory?.let(::str) ?: JsonValue.Null),
        "currentRelationshipEvent" to (state.currentRelationshipEvent?.let(::writeRelationshipEvent) ?: JsonValue.Null),
        "news" to strings(state.news),
        "balanceVersion" to num(state.balanceVersion),
        "worldRulesVersion" to num(state.worldRulesVersion),
        "rebirthEcho" to (state.rebirthEcho?.let(::writeEcho) ?: JsonValue.Null),
        "recentRelationshipEventIds" to strings(state.recentRelationshipEventIds),
        "trainingOpportunity" to (state.trainingOpportunity?.let(::writeTrainingOpportunity) ?: JsonValue.Null),
        "lastTraining" to (state.lastTraining?.let(::writeTraining) ?: JsonValue.Null),
        "lastRelationship" to (state.lastRelationship?.let(::writeRelationship) ?: JsonValue.Null),
        "fanInterest" to num(state.fanInterest),
        "armRisk" to num(state.armRisk),
        "injuryRecovery" to num(state.injuryRecovery),
        "automaticGames" to num(state.automaticGames),
        "automaticOuts" to num(state.automaticOuts),
        "automaticRunsAllowed" to num(state.automaticRunsAllowed),
        "draftResult" to (state.draftResult?.let(::writeDraft) ?: JsonValue.Null),
        "legacyOptions" to strings(state.legacyOptions),
        "selectedMemories" to strings(state.selectedMemories),
        "stateCommitment" to str(state.stateCommitment),
    )

    private fun readState(value: JsonValue.Obj): HighSchoolState {
        // The event category was added as an additive v1 field so old shadow snapshots can
        // still be read. Unknown fields remain fail-closed.
        value.requireRequired(STATE_REQUIRED_FIELDS, "state")
        return HighSchoolState(
            careerId = value.string("careerId"),
            revision = value.decimalString("revision"),
            lifeNumber = value.integer("lifeNumber"),
            presetId = value.string("presetId"),
            phase = enumValue(HighSchoolPhase.entries, value.string("phase"), "phase") { it.wire },
            identity = readIdentity(value.objectValue("identity")),
            difficulty = readDifficulty(value.objectValue("difficulty")),
            karmas = enumList(value.array("karmas"), HighSchoolKarma.entries, "karmas") { it.wire },
            soulBoosts = enumList(value.array("soulBoosts"), HighSchoolSoulBoost.entries, "soulBoosts") { it.wire },
            legacyRewardPermille = value.integer("legacyRewardPermille"),
            memorySlots = value.integer("memorySlots"),
            pitcher = readPitcher(value.objectValue("pitcher")),
            talent = readTalent(value.objectValue("talent")),
            schoolOptions = value.array("schoolOptions").values.mapIndexed { index, item ->
                item.asObject("schoolOptions[$index]").let(::readSchool)
            },
            school = value.optionalObject("school")?.let(::readSchool),
            rival = readRival(value.objectValue("rival")),
            chapter = readChapter(value.objectValue("chapter")),
            schedule = readSchedule(value.objectValue("schedule")),
            chapterTrainingCount = value.integer("chapterTrainingCount"),
            totalTrainingsCompleted = value.integer("totalTrainingsCompleted"),
            milestoneIndex = value.integer("milestoneIndex"),
            relationshipsCompleted = value.integer("relationshipsCompleted"),
            relationshipTrust = value.integer("relationshipTrust"),
            managerTrust = value.integer("managerTrust"),
            catcherTrust = value.integer("catcherTrust"),
            rivalTrust = value.integer("rivalTrust"),
            selectedAwakenings = enumList(value.array("selectedAwakenings"), HighSchoolAwakening.entries, "selectedAwakenings") { it.wire },
            awakeningOptions = enumList(value.array("awakeningOptions"), HighSchoolAwakening.entries, "awakeningOptions") { it.wire },
            awakeningSparks = value.integer("awakeningSparks"),
            fatigue = value.integer("fatigue"),
            performance = readPerformance(value.objectValue("performance")),
            currentGameScenarioId = value.optionalString("currentGameScenarioId"),
            currentGameScenario = value.optionalAdditiveObject("currentGameScenario")?.let(::readScenario),
            currentRelationshipTarget = value.optionalString("currentRelationshipTarget")?.let {
                enumValue(HighSchoolRelationshipTarget.entries, it, "currentRelationshipTarget") { target -> target.wire }
            },
            currentRelationshipCategory = if (value.entries.containsKey("currentRelationshipCategory")) {
                value.optionalString("currentRelationshipCategory")
            } else {
                null
            },
            currentRelationshipEvent = value.optionalAdditiveObject("currentRelationshipEvent")?.let(::readRelationshipEvent),
            news = value.optionalAdditiveStrings("news") ?: emptyList(),
            balanceVersion = value.optionalAdditiveInteger("balanceVersion") ?: HighSchoolContentCatalog.BALANCE_VERSION,
            worldRulesVersion = value.optionalAdditiveInteger("worldRulesVersion") ?: HighSchoolContentCatalog.WORLD_RULES_VERSION,
            rebirthEcho = value.optionalAdditiveObject("rebirthEcho")?.let(::readEcho),
            recentRelationshipEventIds = value.optionalAdditiveStrings("recentRelationshipEventIds") ?: emptyList(),
            trainingOpportunity = value.optionalObject("trainingOpportunity")?.let(::readTrainingOpportunity),
            lastTraining = value.optionalObject("lastTraining")?.let(::readTraining),
            lastRelationship = value.optionalObject("lastRelationship")?.let(::readRelationship),
            fanInterest = value.integer("fanInterest"),
            armRisk = value.integer("armRisk"),
            injuryRecovery = value.integer("injuryRecovery"),
            automaticGames = value.integer("automaticGames"),
            automaticOuts = value.integer("automaticOuts"),
            automaticRunsAllowed = value.integer("automaticRunsAllowed"),
            draftResult = value.optionalObject("draftResult")?.let(::readDraft),
            legacyOptions = value.strings("legacyOptions"),
            selectedMemories = value.strings("selectedMemories"),
            stateCommitment = value.string("stateCommitment"),
        )
    }

    private fun writeIdentity(value: HighSchoolIdentity): JsonValue.Obj = obj(
        "name" to str(value.name), "throwingHand" to str(value.throwingHand),
        "bodyType" to str(value.bodyType), "region" to str(value.region),
    )

    private fun readIdentity(value: JsonValue.Obj): HighSchoolIdentity {
        value.requireExact(setOf("name", "throwingHand", "bodyType", "region"), "identity")
        return HighSchoolIdentity(value.string("name"), value.string("throwingHand"), value.string("bodyType"), value.string("region"))
    }

    private fun writeDifficulty(value: HighSchoolDifficulty): JsonValue.Obj = obj(
        "careerHarshness" to str(value.careerHarshness), "informationClarity" to str(value.informationClarity),
        "simulationDifficulty" to str(value.simulationDifficulty), "interventionAssist" to str(value.interventionAssist),
    )

    private fun readDifficulty(value: JsonValue.Obj): HighSchoolDifficulty {
        value.requireExact(setOf("careerHarshness", "informationClarity", "simulationDifficulty", "interventionAssist"), "difficulty")
        return HighSchoolDifficulty(value.string("careerHarshness"), value.string("informationClarity"), value.string("simulationDifficulty"), value.string("interventionAssist"))
    }

    private fun writePitcher(value: HighSchoolPitcher): JsonValue.Obj = obj(
        "id" to str(value.id), "name" to str(value.name), "stuff" to num(value.stuff),
        "command" to num(value.command), "movement" to num(value.movement), "stamina" to num(value.stamina),
        "pitchProfiles" to array(value.pitchProfiles.map(::writePitchProfile)),
        "throwingHand" to str(value.throwingHand.name.lowercase()),
    )

    private fun readPitcher(value: JsonValue.Obj): HighSchoolPitcher {
        val baseFields = setOf("id", "name", "stuff", "command", "movement", "stamina")
        val additiveFields = setOf("pitchProfiles", "throwingHand")
        val missing = baseFields - value.entries.keys
        val unknown = value.entries.keys - baseFields - additiveFields
        if (missing.isNotEmpty()) throw HighSchoolStateCodecException("pitcher.missing:${missing.sorted().joinToString(",")}")
        if (unknown.isNotEmpty()) throw HighSchoolStateCodecException("pitcher.unknown:${unknown.sorted().joinToString(",")}")
        val profiles = if (value.entries.containsKey("pitchProfiles")) {
            value.array("pitchProfiles").values.mapIndexed { index, item ->
                readPitchProfile(item.asObject("pitchProfiles[$index]"))
            }
        } else {
            emptyList()
        }
        val hand = if (value.entries.containsKey("throwingHand")) {
            when (value.string("throwingHand")) {
                "right" -> com.solkim.baseball.core.pitch.ThrowingHand.RIGHT
                "left" -> com.solkim.baseball.core.pitch.ThrowingHand.LEFT
                else -> throw HighSchoolStateCodecException("pitcher.throwingHand.unknown")
            }
        } else {
            com.solkim.baseball.core.pitch.ThrowingHand.RIGHT
        }
        return HighSchoolPitcher(
            value.string("id"), value.string("name"), value.integer("stuff"), value.integer("command"),
            value.integer("movement"), value.integer("stamina"), profiles, hand,
        )
    }

    private fun writePitchProfile(value: com.solkim.baseball.core.pitch.PitchProfileSnapshot): JsonValue.Obj = obj(
        "pitchType" to str(value.pitchType.wire), "role" to str(value.role.wire),
        "velocityTenthsKph" to num(value.velocityTenthsKph), "control" to num(value.control),
        "command" to num(value.command), "movement" to num(value.movement), "whiff" to num(value.whiff),
        "weakContact" to num(value.weakContact), "fatigueCost" to num(value.fatigueCost),
    )

    private fun readPitchProfile(value: JsonValue.Obj): com.solkim.baseball.core.pitch.PitchProfileSnapshot {
        value.requireExact(
            setOf("pitchType", "role", "velocityTenthsKph", "control", "command", "movement", "whiff", "weakContact", "fatigueCost"),
            "pitchProfile",
        )
        return com.solkim.baseball.core.pitch.PitchProfileSnapshot(
            pitchType = enumValue(com.solkim.baseball.core.pitch.PitchKind.entries, value.string("pitchType"), "pitchProfile.pitchType") { it.wire },
            role = enumValue(com.solkim.baseball.core.pitch.PitchUsageRole.entries, value.string("role"), "pitchProfile.role") { it.wire },
            velocityTenthsKph = value.integer("velocityTenthsKph"), control = value.integer("control"),
            command = value.integer("command"), movement = value.integer("movement"), whiff = value.integer("whiff"),
            weakContact = value.integer("weakContact"), fatigueCost = value.integer("fatigueCost"),
        )
    }

    private fun writeTalent(value: HighSchoolTalent): JsonValue.Obj = obj(
        "stuff" to str(value.stuff.name), "command" to str(value.command.name),
        "movement" to str(value.movement.name), "stamina" to str(value.stamina.name),
        "stuffPressure" to num(value.stuffPressure), "commandPressure" to num(value.commandPressure),
        "movementPressure" to num(value.movementPressure), "staminaPressure" to num(value.staminaPressure),
    )

    private fun readTalent(value: JsonValue.Obj): HighSchoolTalent {
        value.requireExact(setOf("stuff", "command", "movement", "stamina", "stuffPressure", "commandPressure", "movementPressure", "staminaPressure"), "talent")
        fun grade(name: String): HighSchoolTalentGrade = enumValue(HighSchoolTalentGrade.entries, value.string(name), "talent.$name") { it.name }
        return HighSchoolTalent(grade("stuff"), grade("command"), grade("movement"), grade("stamina"), value.integer("stuffPressure"), value.integer("commandPressure"), value.integer("movementPressure"), value.integer("staminaPressure"))
    }

    private fun writeSchool(value: HighSchoolSchool): JsonValue.Obj = obj(
        "id" to str(value.id.wire), "name" to str(value.name), "philosophy" to str(value.philosophy),
        "coachName" to str(value.coachName), "coachArchetype" to str(value.coachArchetype),
        "catcherName" to str(value.catcherName), "catcherArchetype" to str(value.catcherArchetype),
        "strength" to str(value.strength.wire), "tradeoff" to str(value.tradeoff),
        "coachPersonality" to (value.coachPersonality?.let(::str) ?: JsonValue.Null),
        "coachRecord" to (value.coachRecord?.let(::str) ?: JsonValue.Null),
        "catcherPersonality" to (value.catcherPersonality?.let(::str) ?: JsonValue.Null),
        "catcherRecord" to (value.catcherRecord?.let(::str) ?: JsonValue.Null),
    )

    private fun readSchool(value: JsonValue.Obj): HighSchoolSchool {
        val required = setOf("id", "name", "philosophy", "coachName", "coachArchetype", "catcherName", "catcherArchetype", "strength", "tradeoff")
        val additive = setOf("coachPersonality", "coachRecord", "catcherPersonality", "catcherRecord")
        val missing = required - value.entries.keys
        val unknown = value.entries.keys - required - additive
        if (missing.isNotEmpty()) throw HighSchoolStateCodecException("school.missing:${missing.sorted().joinToString(",")}")
        if (unknown.isNotEmpty()) throw HighSchoolStateCodecException("school.unknown:${unknown.sorted().joinToString(",")}")
        return HighSchoolSchool(
            id = enumValue(HighSchoolSchoolId.entries, value.string("id"), "school.id") { it.wire },
            name = value.string("name"),
            philosophy = value.string("philosophy"),
            coachName = value.string("coachName"),
            coachArchetype = value.string("coachArchetype"),
            catcherName = value.string("catcherName"),
            catcherArchetype = value.string("catcherArchetype"),
            strength = enumValue(HighSchoolTrainingFocus.entries, value.string("strength"), "school.strength") { it.wire },
            tradeoff = value.string("tradeoff"),
            coachPersonality = value.optionalAdditiveString("coachPersonality"),
            coachRecord = value.optionalAdditiveString("coachRecord"),
            catcherPersonality = value.optionalAdditiveString("catcherPersonality"),
            catcherRecord = value.optionalAdditiveString("catcherRecord"),
        )
    }

    private fun writeRival(value: HighSchoolRival): JsonValue.Obj = obj(
        "id" to str(value.id), "name" to str(value.name), "archetype" to str(value.archetype),
        "contact" to num(value.contact), "discipline" to num(value.discipline), "power" to num(value.power),
        "personality" to (value.personality?.let(::str) ?: JsonValue.Null),
        "signatureRecord" to (value.signatureRecord?.let(::str) ?: JsonValue.Null),
    )

    private fun readRival(value: JsonValue.Obj): HighSchoolRival {
        val required = setOf("id", "name", "archetype", "contact", "discipline", "power")
        val additive = setOf("personality", "signatureRecord")
        val missing = required - value.entries.keys
        val unknown = value.entries.keys - required - additive
        if (missing.isNotEmpty()) throw HighSchoolStateCodecException("rival.missing:${missing.sorted().joinToString(",")}")
        if (unknown.isNotEmpty()) throw HighSchoolStateCodecException("rival.unknown:${unknown.sorted().joinToString(",")}")
        return HighSchoolRival(
            id = value.string("id"), name = value.string("name"), archetype = value.string("archetype"),
            contact = value.integer("contact"), discipline = value.integer("discipline"), power = value.integer("power"),
            personality = value.optionalAdditiveString("personality"), signatureRecord = value.optionalAdditiveString("signatureRecord"),
        )
    }

    private fun writeChapter(value: HighSchoolChapter): JsonValue.Obj = obj(
        "number" to num(value.number), "title" to str(value.title), "schoolYear" to num(value.schoolYear),
        "season" to str(value.season), "theme" to str(value.theme),
    )

    private fun readChapter(value: JsonValue.Obj): HighSchoolChapter {
        value.requireExact(setOf("number", "title", "schoolYear", "season", "theme"), "chapter")
        return HighSchoolChapter(value.integer("number"), value.string("title"), value.integer("schoolYear"), value.string("season"), value.string("theme"))
    }

    private fun writeSchedule(value: HighSchoolSchedule): JsonValue.Obj = obj(
        "trainingsByChapter" to array(value.trainingsByChapter.map(::num)),
        "milestonesByChapter" to array(value.milestonesByChapter.map { phases -> strings(phases.map { it.wire }) }),
    )

    private fun readSchedule(value: JsonValue.Obj): HighSchoolSchedule {
        value.requireExact(setOf("trainingsByChapter", "milestonesByChapter"), "schedule")
        val trainings = value.array("trainingsByChapter").values.mapIndexed { index, item ->
            item.integerValue("schedule.trainingsByChapter[$index]")
        }
        val milestones = value.array("milestonesByChapter").values.mapIndexed { index, item ->
            val phases = item.asArray("schedule.milestonesByChapter[$index]").values.mapIndexed { phaseIndex, phase ->
                val wire = phase.asString("schedule.milestonesByChapter[$index][$phaseIndex]")
                enumValue(HighSchoolPhase.entries, wire, "schedule.phase") { it.wire }
            }
            phases
        }
        return HighSchoolSchedule(trainings, milestones)
    }

    private fun writePerformance(value: HighSchoolPerformance): JsonValue.Obj = obj(
        "importantGamesCompleted" to num(value.importantGamesCompleted), "pitches" to num(value.pitches),
        "strikeouts" to num(value.strikeouts), "walks" to num(value.walks), "runsAllowed" to num(value.runsAllowed),
        "expectedDamage" to num(value.expectedDamage), "actualDamage" to num(value.actualDamage),
        "outs" to num(value.outs), "hits" to num(value.hits),
    )

    private fun readPerformance(value: JsonValue.Obj): HighSchoolPerformance {
        value.requireExact(setOf("importantGamesCompleted", "pitches", "strikeouts", "walks", "runsAllowed", "expectedDamage", "actualDamage", "outs", "hits"), "performance")
        return HighSchoolPerformance(value.integer("importantGamesCompleted"), value.integer("pitches"), value.integer("strikeouts"), value.integer("walks"), value.integer("runsAllowed"), value.integer("expectedDamage"), value.integer("actualDamage"), value.integer("outs"), value.integer("hits"))
    }

    private fun writeScenario(value: HighSchoolGameScenario): JsonValue.Obj = obj(
        "id" to str(value.id), "title" to str(value.title), "inning" to num(value.inning), "outs" to num(value.outs),
        "firstOccupied" to bool(value.firstOccupied), "secondOccupied" to bool(value.secondOccupied), "thirdOccupied" to bool(value.thirdOccupied),
        "leadRunnerSpeed" to num(value.leadRunnerSpeed), "leverage" to num(value.leverage), "narrative" to str(value.narrative),
        "scoreDifferential" to (value.scoreDifferential?.let(::num) ?: JsonValue.Null), "minChapter" to num(value.minChapter),
    )

    private fun readScenario(value: JsonValue.Obj): HighSchoolGameScenario {
        value.requireExact(
            setOf("id", "title", "inning", "outs", "firstOccupied", "secondOccupied", "thirdOccupied", "leadRunnerSpeed", "leverage", "narrative", "scoreDifferential", "minChapter"),
            "currentGameScenario",
        )
        return HighSchoolGameScenario(
            id = value.string("id"), title = value.string("title"), inning = value.integer("inning"), outs = value.integer("outs"),
            firstOccupied = value.boolean("firstOccupied"), secondOccupied = value.boolean("secondOccupied"), thirdOccupied = value.boolean("thirdOccupied"),
            leadRunnerSpeed = value.integer("leadRunnerSpeed"), leverage = value.integer("leverage"), narrative = value.string("narrative"),
            scoreDifferential = value.optionalAdditiveInteger("scoreDifferential"), minChapter = value.integer("minChapter"),
        )
    }

    private fun writeRelationshipEvent(value: HighSchoolRelationshipEvent): JsonValue.Obj = obj(
        "id" to str(value.id), "title" to str(value.title), "category" to str(value.category), "summary" to str(value.summary),
    )

    private fun readRelationshipEvent(value: JsonValue.Obj): HighSchoolRelationshipEvent {
        value.requireExact(setOf("id", "title", "category", "summary"), "currentRelationshipEvent")
        return HighSchoolRelationshipEvent(value.string("id"), value.string("title"), value.string("category"), value.string("summary"))
    }

    private fun writeEcho(value: HighSchoolRebirthEcho): JsonValue.Obj = obj(
        "previousLifeNumber" to num(value.previousLifeNumber), "previousPlayerName" to str(value.previousPlayerName),
        "previousSchoolName" to (value.previousSchoolName?.let(::str) ?: JsonValue.Null), "previousCareerId" to str(value.previousCareerId),
        "inheritedMemoryCount" to num(value.inheritedMemoryCount), "inheritedSignatureLegacyId" to (value.inheritedSignatureLegacyId?.let(::str) ?: JsonValue.Null),
        "previousArmWarning" to bool(value.previousArmWarning), "previousUndrafted" to bool(value.previousUndrafted),
        "recentEventIds" to strings(value.recentEventIds), "previousNickname" to (value.previousNickname?.let(::str) ?: JsonValue.Null),
        "previousCoachName" to (value.previousCoachName?.let(::str) ?: JsonValue.Null), "previousRivalName" to (value.previousRivalName?.let(::str) ?: JsonValue.Null),
        "inheritedLegacyId" to (value.inheritedLegacyId?.let(::str) ?: JsonValue.Null), "automaticInheritanceTotal" to (value.automaticInheritanceTotal?.let(::num) ?: JsonValue.Null),
        "hadRunsAllowed" to (value.hadRunsAllowed?.let(::bool) ?: JsonValue.Null), "hadCollapseGame" to bool(value.hadCollapseGame),
    )

    private fun readEcho(value: JsonValue.Obj): HighSchoolRebirthEcho {
        val required = setOf("previousLifeNumber", "previousPlayerName", "previousSchoolName", "previousCareerId", "inheritedMemoryCount", "inheritedSignatureLegacyId", "previousArmWarning", "previousUndrafted", "recentEventIds")
        val additive = setOf("previousNickname", "previousCoachName", "previousRivalName", "inheritedLegacyId", "automaticInheritanceTotal", "hadRunsAllowed", "hadCollapseGame")
        val missing = required - value.entries.keys
        val unknown = value.entries.keys - required - additive
        if (missing.isNotEmpty()) throw HighSchoolStateCodecException("rebirthEcho.missing:${missing.sorted().joinToString(",")}")
        if (unknown.isNotEmpty()) throw HighSchoolStateCodecException("rebirthEcho.unknown:${unknown.sorted().joinToString(",")}")
        return HighSchoolRebirthEcho(
            previousLifeNumber = value.integer("previousLifeNumber"), previousPlayerName = value.string("previousPlayerName"),
            previousSchoolName = value.optionalString("previousSchoolName"), previousCareerId = value.string("previousCareerId"),
            inheritedMemoryCount = value.integer("inheritedMemoryCount"), inheritedSignatureLegacyId = value.optionalString("inheritedSignatureLegacyId"),
            previousArmWarning = value.boolean("previousArmWarning"), previousUndrafted = value.boolean("previousUndrafted"),
            recentEventIds = value.strings("recentEventIds"), previousNickname = value.optionalAdditiveString("previousNickname"),
            previousCoachName = value.optionalAdditiveString("previousCoachName"), previousRivalName = value.optionalAdditiveString("previousRivalName"),
            inheritedLegacyId = value.optionalAdditiveString("inheritedLegacyId"), automaticInheritanceTotal = value.optionalAdditiveInteger("automaticInheritanceTotal"),
            hadRunsAllowed = when (val raw = value["hadRunsAllowed"]) { null, JsonValue.Null -> null; else -> (raw as? JsonValue.Bool)?.value ?: throw HighSchoolStateCodecException("rebirthEcho.hadRunsAllowed.boolean_required") },
            hadCollapseGame = when (val raw = value["hadCollapseGame"]) { null, JsonValue.Null -> false; else -> (raw as? JsonValue.Bool)?.value ?: throw HighSchoolStateCodecException("rebirthEcho.hadCollapseGame.boolean_required") },
        )
    }

    private fun writeTrainingOpportunity(value: HighSchoolTrainingOpportunity): JsonValue.Obj = obj(
        "focus" to str(value.focus.wire), "reason" to str(value.reason),
    )

    private fun readTrainingOpportunity(value: JsonValue.Obj): HighSchoolTrainingOpportunity {
        value.requireExact(setOf("focus", "reason"), "trainingOpportunity")
        return HighSchoolTrainingOpportunity(enumValue(HighSchoolTrainingFocus.entries, value.string("focus"), "trainingOpportunity.focus") { it.wire }, value.string("reason"))
    }

    private fun writeTraining(value: HighSchoolTrainingResult): JsonValue.Obj = obj(
        "number" to num(value.number), "focus" to str(value.focus.wire), "intensity" to str(value.intensity.wire),
        "growth" to num(value.growth), "fatigueChange" to num(value.fatigueChange),
        "opportunityHit" to bool(value.opportunityHit), "bloomed" to bool(value.bloomed),
    )

    private fun readTraining(value: JsonValue.Obj): HighSchoolTrainingResult {
        value.requireExact(setOf("number", "focus", "intensity", "growth", "fatigueChange", "opportunityHit", "bloomed"), "lastTraining")
        return HighSchoolTrainingResult(
            value.integer("number"),
            enumValue(HighSchoolTrainingFocus.entries, value.string("focus"), "lastTraining.focus") { it.wire },
            enumValue(HighSchoolTrainingIntensity.entries, value.string("intensity"), "lastTraining.intensity") { it.wire },
            value.integer("growth"), value.integer("fatigueChange"), value.boolean("opportunityHit"), value.boolean("bloomed"),
        )
    }

    private fun writeRelationship(value: HighSchoolRelationshipResult): JsonValue.Obj = obj(
        "number" to num(value.number), "target" to str(value.target.wire), "response" to str(value.response.wire),
        "trustBefore" to num(value.trustBefore), "trustAfter" to num(value.trustAfter),
        "fatigueBefore" to num(value.fatigueBefore), "fatigueAfter" to num(value.fatigueAfter),
        "fanInterestBefore" to num(value.fanInterestBefore), "fanInterestAfter" to num(value.fanInterestAfter),
        "growthFocus" to (value.growthFocus?.wire?.let(::str) ?: JsonValue.Null),
    )

    private fun readRelationship(value: JsonValue.Obj): HighSchoolRelationshipResult {
        value.requireExact(setOf("number", "target", "response", "trustBefore", "trustAfter", "fatigueBefore", "fatigueAfter", "fanInterestBefore", "fanInterestAfter", "growthFocus"), "lastRelationship")
        return HighSchoolRelationshipResult(
            value.integer("number"),
            enumValue(HighSchoolRelationshipTarget.entries, value.string("target"), "lastRelationship.target") { it.wire },
            enumValue(HighSchoolRelationshipResponse.entries, value.string("response"), "lastRelationship.response") { it.wire },
            value.integer("trustBefore"), value.integer("trustAfter"), value.integer("fatigueBefore"), value.integer("fatigueAfter"),
            value.integer("fanInterestBefore"), value.integer("fanInterestAfter"),
            value.optionalString("growthFocus")?.let { wire -> enumValue(HighSchoolTrainingFocus.entries, wire, "lastRelationship.growthFocus") { it.wire } },
        )
    }

    private fun writeDraft(value: HighSchoolDraftResult): JsonValue.Obj = obj(
        "outcome" to str(value.outcome.wire), "evaluationScore" to num(value.evaluationScore),
        "projectedRange" to str(value.projectedRange), "teamId" to (value.teamId?.let(::str) ?: JsonValue.Null),
        "team" to (value.team?.let(::writeDraftTeam) ?: JsonValue.Null),
        "round" to (value.round?.let(::num) ?: JsonValue.Null),
        "overallPick" to (value.overallPick?.let(::num) ?: JsonValue.Null),
        "signingBonus" to (value.signingBonus?.let(::num) ?: JsonValue.Null),
        "firstSeasonGoal" to (value.firstSeasonGoal?.let(::str) ?: JsonValue.Null),
        "evaluationBreakdown" to (value.evaluationBreakdown?.let { strings(it) } ?: JsonValue.Null),
        "summary" to str(value.summary),
    )

    private fun readDraft(value: JsonValue.Obj): HighSchoolDraftResult {
        val required = setOf("outcome", "evaluationScore", "projectedRange", "teamId")
        val additive = setOf("team", "round", "overallPick", "signingBonus", "firstSeasonGoal", "evaluationBreakdown", "summary")
        val missing = required - value.entries.keys
        val unknown = value.entries.keys - required - additive
        if (missing.isNotEmpty()) throw HighSchoolStateCodecException("draftResult.missing:${missing.sorted().joinToString(",")}")
        if (unknown.isNotEmpty()) throw HighSchoolStateCodecException("draftResult.unknown:${unknown.sorted().joinToString(",")}")
        return HighSchoolDraftResult(
            outcome = enumValue(HighSchoolDraftOutcome.entries, value.string("outcome"), "draftResult.outcome") { it.wire },
            evaluationScore = value.integer("evaluationScore"),
            projectedRange = value.string("projectedRange"),
            teamId = value.optionalString("teamId"),
            team = value.optionalAdditiveObject("team")?.let(::readDraftTeam),
            round = value.optionalAdditiveInteger("round"),
            overallPick = value.optionalAdditiveInteger("overallPick"),
            signingBonus = value.optionalAdditiveInteger("signingBonus"),
            firstSeasonGoal = value.optionalAdditiveString("firstSeasonGoal"),
            evaluationBreakdown = value.optionalAdditiveStrings("evaluationBreakdown"),
            summary = value.optionalAdditiveString("summary") ?: "",
        )
    }

    private fun writeDraftTeam(value: HighSchoolDraftTeam): JsonValue.Obj = obj(
        "id" to str(value.id), "name" to str(value.name), "need" to str(value.need.wire), "demand" to num(value.demand),
        "developmentPlan" to str(value.developmentPlan), "positionCompetitor" to str(value.positionCompetitor), "proCoach" to str(value.proCoach),
        "competitorProfile" to (value.competitorProfile?.let(::str) ?: JsonValue.Null),
        "competitorRecord" to (value.competitorRecord?.let(::str) ?: JsonValue.Null),
        "coachProfile" to (value.coachProfile?.let(::str) ?: JsonValue.Null),
        "coachRecord" to (value.coachRecord?.let(::str) ?: JsonValue.Null),
    )

    private fun readDraftTeam(value: JsonValue.Obj): HighSchoolDraftTeam {
        value.requireExact(
            setOf("id", "name", "need", "demand", "developmentPlan", "positionCompetitor", "proCoach", "competitorProfile", "competitorRecord", "coachProfile", "coachRecord"),
            "draftResult.team",
        )
        return HighSchoolDraftTeam(
            id = value.string("id"), name = value.string("name"),
            need = enumValue(HighSchoolTrainingFocus.entries, value.string("need"), "draftResult.team.need") { it.wire },
            demand = value.integer("demand"), developmentPlan = value.string("developmentPlan"),
            positionCompetitor = value.string("positionCompetitor"), proCoach = value.string("proCoach"),
            competitorProfile = value.optionalString("competitorProfile"), competitorRecord = value.optionalString("competitorRecord"),
            coachProfile = value.optionalString("coachProfile"), coachRecord = value.optionalString("coachRecord"),
        )
    }

    private fun obj(vararg fields: Pair<String, JsonValue>): JsonValue.Obj = JsonValue.Obj(linkedMapOf(*fields))
    private fun str(value: String): JsonValue = JsonValue.Str(value)
    private fun num(value: Int): JsonValue = JsonValue.Num(value.toString())
    private fun bool(value: Boolean): JsonValue = JsonValue.Bool(value)
    private fun strings(values: List<String>): JsonValue = JsonValue.Arr(values.map(::str))
    private fun array(values: List<JsonValue>): JsonValue = JsonValue.Arr(values)

    private fun <T> enumValue(values: Iterable<T>, wire: String, field: String, wireOf: (T) -> String): T =
        values.firstOrNull { wireOf(it) == wire } ?: throw HighSchoolStateCodecException("$field.unknown:$wire")

    private fun <T> enumList(value: JsonValue.Arr, values: Iterable<T>, field: String, wireOf: (T) -> String): List<T> =
        value.values.mapIndexed { index, item -> enumValue(values, item.asString("$field[$index]"), "$field[$index]", wireOf) }

    private fun JsonValue.asObject(field: String): JsonValue.Obj = this as? JsonValue.Obj
        ?: throw HighSchoolStateCodecException("$field.object_required")

    private fun JsonValue.Obj.objectValue(name: String): JsonValue.Obj = (this[name]
        ?: throw HighSchoolStateCodecException("$name.missing")).asObject(name)
    private fun JsonValue.Obj.optionalObject(name: String): JsonValue.Obj? = when (val value = this[name]) {
        null -> throw HighSchoolStateCodecException("$name.missing")
        JsonValue.Null -> null
        else -> value.asObject(name)
    }

    private fun JsonValue.Obj.string(name: String): String = (this[name]
        ?: throw HighSchoolStateCodecException("$name.missing")).asString(name)
    private fun JsonValue.Obj.optionalString(name: String): String? = when (val value = this[name]) {
        null -> throw HighSchoolStateCodecException("$name.missing")
        JsonValue.Null -> null
        else -> value.asString(name)
    }

    /** Additive fields may be absent in v1 shadow snapshots; present null remains valid. */
    private fun JsonValue.Obj.optionalAdditiveString(name: String): String? = when (val value = this[name]) {
        null, JsonValue.Null -> null
        else -> value.asString(name)
    }

    private fun JsonValue.Obj.optionalAdditiveInteger(name: String): Int? = when (val value = this[name]) {
        null, JsonValue.Null -> null
        else -> value.integerValue(name)
    }

    private fun JsonValue.Obj.optionalAdditiveObject(name: String): JsonValue.Obj? = when (val value = this[name]) {
        null, JsonValue.Null -> null
        else -> value.asObject(name)
    }

    private fun JsonValue.Obj.optionalAdditiveStrings(name: String): List<String>? = when (val value = this[name]) {
        null, JsonValue.Null -> null
        else -> value.asArray(name).values.mapIndexed { index, item -> item.asString("$name[$index]") }
    }

    private fun JsonValue.asString(field: String): String = (this as? JsonValue.Str)?.value
        ?: throw HighSchoolStateCodecException("$field.string_required")

    private fun JsonValue.Obj.integer(name: String): Int = (this[name]
        ?: throw HighSchoolStateCodecException("$name.missing")).integerValue(name)

    private fun JsonValue.integerValue(field: String): Int {
        val raw = (this as? JsonValue.Num)?.raw ?: throw HighSchoolStateCodecException("$field.integer_required")
        if (!Regex("-?(0|[1-9][0-9]*)").matches(raw)) throw HighSchoolStateCodecException("$field.integer_invalid")
        return raw.toLongOrNull()?.takeIf { it in Int.MIN_VALUE..Int.MAX_VALUE }?.toInt()
            ?: throw HighSchoolStateCodecException("$field.integer_bounds")
    }

    private fun JsonValue.Obj.decimalString(name: String): ULong {
        val value = string(name)
        if (!Regex("0|[1-9][0-9]*").matches(value)) throw HighSchoolStateCodecException("$name.invalid")
        return value.toULongOrNull() ?: throw HighSchoolStateCodecException("$name.bounds")
    }

    private fun JsonValue.Obj.boolean(name: String): Boolean = (this[name] as? JsonValue.Bool)?.value
        ?: throw HighSchoolStateCodecException("$name.boolean_required")

    private fun JsonValue.Obj.strings(name: String): List<String> = array(name).values.mapIndexed { index, value -> value.asString("$name[$index]") }
    private fun JsonValue.Obj.array(name: String): JsonValue.Arr = this[name] as? JsonValue.Arr
        ?: throw HighSchoolStateCodecException("$name.array_required")

    private fun JsonValue.asArray(field: String): JsonValue.Arr = this as? JsonValue.Arr
        ?: throw HighSchoolStateCodecException("$field.array_required")

    private fun JsonValue.Obj.requireExact(expected: Set<String>, field: String) {
        val missing = expected - entries.keys
        val unknown = entries.keys - expected
        if (missing.isNotEmpty()) throw HighSchoolStateCodecException("$field.missing:${missing.sorted().joinToString(",")}")
        if (unknown.isNotEmpty()) throw HighSchoolStateCodecException("$field.unknown:${unknown.sorted().joinToString(",")}")
    }

    private fun JsonValue.Obj.requireRequired(required: Set<String>, field: String) {
        val missing = required - entries.keys
        val unknown = entries.keys - STATE_FIELDS
        if (missing.isNotEmpty()) throw HighSchoolStateCodecException("$field.missing:${missing.sorted().joinToString(",")}")
        if (unknown.isNotEmpty()) throw HighSchoolStateCodecException("$field.unknown:${unknown.sorted().joinToString(",")}")
    }

    private val ROOT_FIELDS = setOf("schema", "schemaVersion", "state")
    private val STATE_FIELDS = setOf(
        "careerId", "revision", "lifeNumber", "presetId", "phase", "identity", "difficulty", "karmas", "soulBoosts",
        "legacyRewardPermille", "memorySlots", "pitcher", "talent", "schoolOptions", "school", "rival", "chapter", "schedule",
        "chapterTrainingCount", "totalTrainingsCompleted", "milestoneIndex", "relationshipsCompleted", "relationshipTrust",
        "managerTrust", "catcherTrust", "rivalTrust", "selectedAwakenings", "awakeningOptions", "awakeningSparks", "fatigue",
        "performance", "currentGameScenarioId", "currentGameScenario", "currentRelationshipTarget", "currentRelationshipEvent", "news", "balanceVersion", "worldRulesVersion", "rebirthEcho", "recentRelationshipEventIds", "trainingOpportunity", "lastTraining", "lastRelationship",
        "fanInterest", "armRisk", "injuryRecovery", "automaticGames", "automaticOuts", "automaticRunsAllowed", "draftResult",
        "legacyOptions", "selectedMemories", "currentRelationshipCategory", "stateCommitment",
    )
    private val STATE_REQUIRED_FIELDS = STATE_FIELDS - setOf(
        "currentRelationshipCategory", "currentGameScenario", "currentRelationshipEvent", "news", "balanceVersion",
        "worldRulesVersion", "rebirthEcho", "recentRelationshipEventIds",
    )
}

public class HighSchoolStateCodecException(message: String) : IllegalArgumentException(message)
