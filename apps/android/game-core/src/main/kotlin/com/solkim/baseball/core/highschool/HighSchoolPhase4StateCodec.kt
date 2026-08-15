package com.solkim.baseball.core.highschool

import com.solkim.baseball.core.pitch.PitchKind
import com.solkim.baseball.core.pitch.PitchOutcome
import com.solkim.baseball.core.pitch.PitchZone
import com.solkim.baseball.core.pitch.SelectionQuality
import com.solkim.baseball.core.pitch.ZoneIntent
import com.solkim.baseball.model.JsonValue
import com.solkim.baseball.model.StrictJson
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.DataInputStream
import java.io.DataOutputStream
import java.nio.ByteBuffer
import java.nio.charset.CodingErrorAction
import java.util.Base64

/** Strict, deterministic, shadow-only Phase 4 snapshot wire. */
public object HighSchoolPhase4StateCodec {
    public const val SCHEMA: String = "baseball-high-school-phase4-state-v1"
    /** v2 profiles/hand; v3 sequence history; v4 tournament/prospect fields; v5 rich content/echo; v6 Meta ledgers; v7 training evidence. */
    public const val SCHEMA_VERSION: Int = 7
    public const val MAX_BYTES: Int = 4 * 1024 * 1024
    private const val MAGIC: String = "P4M1"
    private val ROOT_FIELDS = setOf("schema", "schemaVersion", "payload", "stateCommitment")

    public fun encode(state: HighSchoolPhase4State): ByteArray {
        val kernel = HighSchoolPhase4Kernel()
        kernel.validateSavedState(state)
        val output = ByteArrayOutputStream()
        DataOutputStream(output).use { data ->
            data.writeString(MAGIC)
            data.writeInt(SCHEMA_VERSION)
            data.writeString(HighSchoolStateCodec.encode(state.run).toBase64())
            data.writePitcher(state.startingPitcher, includeProfiles = true)
            data.writeInheritance(state.inheritance)
            data.writeArchive(state.archive)
            data.writeStrings(state.achievements)
            data.writeStrings(state.unacknowledgedAchievements)
            data.writeWeekly(state.weekly, includeMetaFields = true)
            data.writeNullable(state.pledge) { writePledge(it) }
            data.writeNullable(state.nextRunIntent) { writeNextRunIntent(it) }
            data.writeNullableString(state.selectedSignatureLegacyId)
            data.writeNullable(state.returnPlan) { writeReturnPlan(it, includeMetaFields = true) }
            data.writeNullable(state.rebirthEcho) { writeEcho(it) }
            data.writeSeasonLog(state.seasonLog)
            data.writeTournaments(state.tournaments)
            data.writeProspects(state.prospectBoard)
            data.writeNullable(state.activePitch) { writePitchSession(it) }
            data.writeNullable(state.lastPresentation) { writePresentation(it) }
            data.writeBoolean(state.tutorial.started)
            data.writeBoolean(state.tutorial.completed)
            data.writeBoolean(state.challenge.active)
            data.writeNullable(state.challenge.backup) { writeChallengeBackup(it) }
            data.writeULong(state.completedGameCounter)
            data.writeStrings(state.completedGameReceipts)
            data.writeTrainingEvidence(state.trainingEvidence)
            data.writeCommandReceipts(state.commandReceipts)
            data.writeString(state.selectedDayKey)
            data.writeULong(state.revision)
            data.writeString(state.stateCommitment)
        }
        val payload = output.toByteArray().toBase64()
        val root = JsonValue.Obj(linkedMapOf(
            "schema" to JsonValue.Str(SCHEMA),
            "schemaVersion" to JsonValue.Num(SCHEMA_VERSION.toString()),
            "payload" to JsonValue.Str(payload),
            "stateCommitment" to JsonValue.Str(state.stateCommitment),
        ))
        return StrictJson.canonical(root).toByteArray(Charsets.UTF_8)
    }

    public fun decode(bytes: ByteArray): HighSchoolPhase4State {
        if (bytes.isEmpty()) throw HighSchoolPhase4StateCodecException("file.empty")
        if (bytes.size > MAX_BYTES) throw HighSchoolPhase4StateCodecException("file.too_large")
        val root = try { StrictJson.parseUtf8(bytes) as? JsonValue.Obj ?: fail("root.object") }
        catch (error: HighSchoolPhase4StateCodecException) { throw error }
        catch (error: Exception) { throw HighSchoolPhase4StateCodecException("json.invalid") }
        requireExact(root, ROOT_FIELDS, "root")
        if (!bytes.contentEquals(StrictJson.canonical(root).toByteArray(Charsets.UTF_8))) fail("json.noncanonical")
        if (root.string("schema") != SCHEMA) fail("schema.unknown")
        val version = root.integer("schemaVersion")
        if (version !in 1..SCHEMA_VERSION) {
            if (version > SCHEMA_VERSION) fail("schema.future:$version")
            fail("schema.migration:$version")
        }
        val rootCommitment = root.string("stateCommitment")
        val payload = decodeCanonicalBase64(root.string("payload"), "payload.base64")
        val state = try { DataInputStream(ByteArrayInputStream(payload)).use { readState(it, version) } }
        catch (error: HighSchoolPhase4StateCodecException) { throw error }
        catch (error: Exception) { throw HighSchoolPhase4StateCodecException("payload.invalid:${error.javaClass.simpleName}") }
        if (state.stateCommitment != rootCommitment) fail("stateCommitment.mismatch")
        try { HighSchoolPhase4Kernel().validateSavedState(state) }
        catch (error: IllegalArgumentException) { fail(error.message ?: "state.invalid") }
        return state
    }

    private fun readState(input: DataInputStream, rootVersion: Int): HighSchoolPhase4State {
        if (input.readString() != MAGIC) fail("payload.magic")
        val payloadVersion = input.readInt()
        if (payloadVersion != rootVersion || payloadVersion !in 1..SCHEMA_VERSION) fail("payload.version")
        val run = HighSchoolStateCodec.decode(input.readString().fromBase64())
        val starting = input.readPitcher(includeProfiles = payloadVersion >= 2)
        val inheritance = input.readInheritance()
        val archive = input.readArchive()
        val achievements = input.readStrings()
        val unacknowledgedAchievements = if (payloadVersion >= 6) input.readStrings() else emptyList()
        val weekly = input.readWeekly(includeMetaFields = payloadVersion >= 6)
        val pledge = input.readNullable { readPledge() }
        val nextRunIntent = input.readNullable { readNextRunIntent() }
        val selectedSignature = input.readNullableString()
        val returnPlan = input.readNullable { readReturnPlan(includeMetaFields = payloadVersion >= 6) }
        val echo = input.readNullable { readEcho(includeRichFields = payloadVersion >= 5) }
        val seasonLog = input.readSeasonLog(includeRichFields = payloadVersion >= 5)
        val tournaments = input.readTournaments(includeSchools = payloadVersion >= 4)
        val prospects = input.readProspects(includeTag = payloadVersion >= 4)
        val activePitch = input.readNullable { readPitchSession(includeSequencePitches = payloadVersion >= 3) }
        val lastPresentation = input.readNullable { readPresentation() }
        val tutorial = HighSchoolTutorialState(input.readBoolean(), input.readBoolean())
        val challengeActive = input.readBoolean()
        val challengeBackup = input.readNullable {
            readChallengeBackup(
                includeProfiles = payloadVersion >= 2,
                includeTournamentSchools = payloadVersion >= 4,
                includeProspectTags = payloadVersion >= 4,
                includeRichEcho = payloadVersion >= 5,
                includeMetaFields = payloadVersion >= 6,
                includeTrainingEvidence = payloadVersion >= 7,
            )
        }
        val completedCounter = input.readULong()
        val completedReceipts = input.readStrings()
        val trainingEvidence = if (payloadVersion >= 7) input.readTrainingEvidence() else emptyList()
        val receipts = input.readCommandReceipts()
        val dayKey = input.readString()
        val revision = input.readULong()
        val commitment = input.readString()
        if (input.available() != 0) fail("payload.trailing")
        return HighSchoolPhase4State(
            run = run,
            startingPitcher = starting,
            inheritance = inheritance,
            archive = archive,
            achievements = achievements,
            unacknowledgedAchievements = unacknowledgedAchievements,
            weekly = weekly,
            pledge = pledge,
            nextRunIntent = nextRunIntent,
            selectedSignatureLegacyId = selectedSignature,
            returnPlan = returnPlan,
            rebirthEcho = echo,
            seasonLog = seasonLog,
            tournaments = tournaments,
            prospectBoard = prospects,
            activePitch = activePitch,
            lastPresentation = lastPresentation,
            tutorial = tutorial,
            challenge = HighSchoolChallengeState(challengeActive, challengeBackup),
            completedGameCounter = completedCounter,
            completedGameReceipts = completedReceipts,
            trainingEvidence = trainingEvidence,
            commandReceipts = receipts,
            selectedDayKey = dayKey,
            revision = revision,
            stateCommitment = commitment,
        )
    }

    private fun DataOutputStream.writePitcher(value: HighSchoolPitcher, includeProfiles: Boolean) {
        writeString(value.id); writeString(value.name); writeInt(value.stuff); writeInt(value.command); writeInt(value.movement); writeInt(value.stamina)
        if (includeProfiles) {
            writeString(value.throwingHand.name.lowercase())
            writeList(value.pitchProfiles) {
                writeString(it.pitchType.wire); writeString(it.role.wire); writeInt(it.velocityTenthsKph); writeInt(it.control)
                writeInt(it.command); writeInt(it.movement); writeInt(it.whiff); writeInt(it.weakContact); writeInt(it.fatigueCost)
            }
        }
    }
    private fun DataInputStream.readPitcher(includeProfiles: Boolean): HighSchoolPitcher {
        val id = readString(); val name = readString(); val stuff = readInt(); val command = readInt(); val movement = readInt(); val stamina = readInt()
        if (!includeProfiles) return HighSchoolPitcher(id, name, stuff, command, movement, stamina)
        val hand = throwingHand(readString())
        val profiles = readList {
            com.solkim.baseball.core.pitch.PitchProfileSnapshot(
                pitchKind(readString()), pitchRole(readString()), readInt(), readInt(), readInt(), readInt(), readInt(), readInt(), readInt(),
            )
        }
        return HighSchoolPitcher(id, name, stuff, command, movement, stamina, profiles, hand)
    }

    private fun DataOutputStream.writeInheritance(value: HighSchoolInheritanceState) {
        writeInt(value.nextLifeNumber); writeInt(value.soulPoints); writeInt(value.soulTotalEarned); writeInt(value.automaticSoulEarned)
        writeStrings(value.inheritedMemories); writeNullableString(value.selectedSignatureLegacyId); writeStrings(value.unlockedSignatureLegacyIds); writeNullableInt(value.inheritanceRulesVersion)
        writeList(value.lineageMasteries) { writeString(it.family); writeInt(it.contributions); writeInt(it.rank); writeNullableInt(it.nextThreshold) }
        writeNullable(value.lineageLoadout) { writeInt(it.rulesVersion); writeString(it.legacyId); writeInt(it.masteryRank); writeInt(it.contributions); writeNullableInt(it.sourceLifeNumber) }
    }
    private fun DataInputStream.readInheritance(): HighSchoolInheritanceState {
        val nextLife = readInt(); val soul = readInt(); val total = readInt(); val automatic = readInt()
        val memories = readStrings(); val selected = readNullableString(); val unlocked = readStrings(); val rules = readNullableInt()
        val masteries = readList { HighSchoolLineageMastery(readString(), readInt(), readInt(), readNullableInt()) }
        val loadout = readNullable { HighSchoolLineageLoadout(readInt(), readString(), readInt(), readInt(), readNullableInt()) }
        return HighSchoolInheritanceState(nextLife, soul, total, automatic, memories, selected, unlocked, rules, masteries, loadout)
    }

    private fun DataOutputStream.writeArchive(values: List<HighSchoolArchiveRecord>) {
        writeList(values) { value ->
            writeString(value.careerId); writeInt(value.lifeNumber); writeString(value.playerName); writeNullableString(value.schoolId); writeNullableString(value.schoolName)
            writeBoolean(value.drafted); writeInt(value.draftEvaluation); writeNullableString(value.teamId); writeInts(value.ratings); writeInt(value.importantGames); writeInt(value.pitches)
            writeInt(value.strikeouts); writeInt(value.walks); writeInt(value.runsAllowed); writeStrings(value.selectedAwakenings); writeNullableString(value.selectedSignatureLegacyId)
            writeNullableString(value.pledgeId); writeBoolean(value.pledgeAchieved); writeInt(value.soulEarned); writeULong(value.completedGameCounterAtArchive)
        }
    }
    private fun DataInputStream.readArchive(): List<HighSchoolArchiveRecord> = readList {
        HighSchoolArchiveRecord(
            readString(), readInt(), readString(), readNullableString(), readNullableString(), readBoolean(), readInt(), readNullableString(), readInts(), readInt(), readInt(),
            readInt(), readInt(), readInt(), readStrings(), readNullableString(), readNullableString(), readBoolean(), readInt(), readULong(),
        )
    }

    private fun DataOutputStream.writeWeekly(value: HighSchoolWeeklyState, includeMetaFields: Boolean) {
        writeString(value.stableUserId); writeString(value.weekKey); writeList(value.tasks) {
            writeString(it.id); writeInt(it.target); writeInt(it.progress); writeBoolean(it.completed)
            if (includeMetaFields) writeString(it.kind)
        }; writeBoolean(value.rewardClaimed)
        writeStrings(value.processedReceiptIds); writeStrings(value.playedDayKeys)
        if (includeMetaFields) {
            writeList(value.stamps) {
                writeString(it.weekKey); writeInt(it.completedTaskCount); writeBoolean(it.perfect); writeLong(it.earnedAtUnixSeconds)
            }
            writeNullableString(value.lastObservedWeekStartDayKey)
        }
    }
    private fun DataInputStream.readWeekly(includeMetaFields: Boolean): HighSchoolWeeklyState {
        val stableUserId = readString()
        val weekKey = readString()
        val tasks = readList {
            val id = readString(); val target = readInt(); val progress = readInt(); val completed = readBoolean()
            val kind = if (includeMetaFields) readString() else id
            HighSchoolWeeklyTask(id, target, progress, completed, kind)
        }
        val claimed = readBoolean()
        val receipts = readStrings()
        val days = readStrings()
        val stamps = if (includeMetaFields) readList {
            HighSchoolWeeklyStamp(readString(), readInt(), readBoolean(), readLong())
        } else emptyList()
        val lastObserved = if (includeMetaFields) readNullableString() else null
        return HighSchoolWeeklyState(stableUserId, weekKey, tasks, claimed, receipts, days, stamps, lastObserved)
    }

    private fun DataOutputStream.writePledge(value: HighSchoolPledgeState) {
        writeString(value.definition.id); writeString(value.definition.tier.wire); writeInt(value.definition.target); writeString(value.definition.title); writeString(value.definition.detail)
        writeInt(value.progress); writeBoolean(value.achieved); writeBoolean(value.rewardApplied)
    }
    private fun DataInputStream.readPledge(): HighSchoolPledgeState {
        val definition = HighSchoolPledgeDefinition(readString(), pledgeTier(readString()), readInt(), readString(), readString())
        return HighSchoolPledgeState(definition, readInt(), readBoolean(), readBoolean())
    }

    private fun DataOutputStream.writeNextRunIntent(value: HighSchoolNextRunIntent) {
        writeString(value.pledgeId); writeInt(value.sourceLifeNumber); writeString(value.reason)
    }
    private fun DataInputStream.readNextRunIntent(): HighSchoolNextRunIntent =
        HighSchoolNextRunIntent(readString(), readInt(), readString())

    private fun DataOutputStream.writeReturnPlan(value: HighSchoolReturnPlan, includeMetaFields: Boolean) {
        writeString(value.destination.wire); writeString(value.reason); writeString(value.createdDayKey); writeString(value.receiptId); writeBoolean(value.dismissed)
        if (includeMetaFields) {
            writeString(value.route); writeString(value.title); writeString(value.body); writeNullableString(value.experimentId)
            writeNullableString(value.savedDayKey); writeNullableString(value.experimentVariant); writeNullableInt(value.developmentRulesVersion)
        }
    }
    private fun DataInputStream.readReturnPlan(includeMetaFields: Boolean): HighSchoolReturnPlan {
        val destination = returnDestination(readString())
        val reason = readString()
        val createdDayKey = readString()
        val receiptId = readString()
        val dismissed = readBoolean()
        if (!includeMetaFields) return HighSchoolReturnPlan(destination, reason, createdDayKey, receiptId, dismissed)
        return HighSchoolReturnPlan(
            destination = destination,
            reason = reason,
            createdDayKey = createdDayKey,
            receiptId = receiptId,
            dismissed = dismissed,
            route = readString(),
            title = readString(),
            body = readString(),
            experimentId = readNullableString(),
            savedDayKey = readNullableString(),
            experimentVariant = readNullableString(),
            developmentRulesVersion = readNullableInt(),
        )
    }

    private fun DataOutputStream.writeEcho(value: HighSchoolRebirthEcho) {
        writeInt(value.previousLifeNumber); writeString(value.previousPlayerName); writeNullableString(value.previousSchoolName); writeString(value.previousCareerId); writeInt(value.inheritedMemoryCount)
        writeNullableString(value.inheritedSignatureLegacyId); writeBoolean(value.previousArmWarning); writeBoolean(value.previousUndrafted); writeStrings(value.recentEventIds)
        writeNullableString(value.previousNickname); writeNullableString(value.previousCoachName); writeNullableString(value.previousRivalName); writeNullableString(value.inheritedLegacyId); writeNullableInt(value.automaticInheritanceTotal); writeNullableBoolean(value.hadRunsAllowed); writeBoolean(value.hadCollapseGame)
    }
    private fun DataInputStream.readEcho(includeRichFields: Boolean): HighSchoolRebirthEcho {
        val base = HighSchoolRebirthEcho(readInt(), readString(), readNullableString(), readString(), readInt(), readNullableString(), readBoolean(), readBoolean(), readStrings())
        if (!includeRichFields) return base
        return base.copy(
            previousNickname = readNullableString(), previousCoachName = readNullableString(), previousRivalName = readNullableString(),
            inheritedLegacyId = readNullableString(), automaticInheritanceTotal = readNullableInt(), hadRunsAllowed = readNullableBoolean(), hadCollapseGame = readBoolean(),
        )
    }

    private fun DataOutputStream.writeSeasonLog(values: List<HighSchoolSeasonLine>) {
        writeList(values) {
            writeString(it.careerId); writeInt(it.lifeNumber); writeInt(it.chapter); writeInt(it.gameNumber); writeInt(it.pitches); writeInt(it.strikeouts); writeInt(it.walks); writeInt(it.runsAllowed); writeInt(it.expectedDamage); writeInt(it.actualDamage); writeStrings(it.abilityMoments); writeInt(it.rivalStrikeouts)
            writeInt(it.season); writeInt(it.week); writeInt(it.outingNumber); writeBoolean(it.started); writeInt(it.outs); writeInt(it.teamRuns); writeInt(it.opponentRuns); writeString(it.decision.wire); writeBoolean(it.played); writeInt(it.hits); writeInt(it.homeRuns)
        }
    }
    private fun DataInputStream.readSeasonLog(includeRichFields: Boolean): List<HighSchoolSeasonLine> = readList {
        val careerId = readString(); val lifeNumber = readInt(); val chapter = readInt(); val gameNumber = readInt(); val pitches = readInt(); val strikeouts = readInt(); val walks = readInt(); val runsAllowed = readInt(); val expectedDamage = readInt(); val actualDamage = readInt(); val abilityMoments = readStrings(); val rivalStrikeouts = readInt()
        if (!includeRichFields) {
            HighSchoolSeasonLine(careerId, lifeNumber, chapter, gameNumber, pitches, strikeouts, walks, runsAllowed, expectedDamage, actualDamage, abilityMoments, rivalStrikeouts)
        } else {
            HighSchoolSeasonLine(
                careerId = careerId, lifeNumber = lifeNumber, chapter = chapter, gameNumber = gameNumber,
                pitches = pitches, strikeouts = strikeouts, walks = walks, runsAllowed = runsAllowed,
                expectedDamage = expectedDamage, actualDamage = actualDamage, abilityMoments = abilityMoments,
                rivalStrikeouts = rivalStrikeouts, season = readInt(), week = readInt(), outingNumber = readInt(),
                started = readBoolean(), outs = readInt(), teamRuns = readInt(), opponentRuns = readInt(),
                decision = pitchingDecision(readString()), played = readBoolean(), hits = readInt(), homeRuns = readInt(),
            )
        }
    }

    private fun DataOutputStream.writeTournaments(values: List<HighSchoolTournamentSnapshot>) {
        writeList(values) {
            writeInt(it.chapter); writeString(it.name); writeString(it.playerRound); writeString(it.bracketSeed); writeBoolean(it.completed)
            writeStrings(it.schools)
        }
    }
    private fun DataInputStream.readTournaments(includeSchools: Boolean): List<HighSchoolTournamentSnapshot> = readList {
        HighSchoolTournamentSnapshot(
            chapter = readInt(), name = readString(), playerRound = readString(), bracketSeed = readString(), completed = readBoolean(),
            schools = if (includeSchools) readStrings() else emptyList(),
        )
    }

    private fun DataOutputStream.writeProspects(values: List<HighSchoolProspectEntry>) {
        writeList(values) {
            writeString(it.playerId); writeString(it.name); writeString(it.schoolName); writeInt(it.rank); writeInt(it.score); writeBoolean(it.isCurrentPlayer)
            writeString(it.tag)
        }
    }
    private fun DataInputStream.readProspects(includeTag: Boolean): List<HighSchoolProspectEntry> = readList {
        HighSchoolProspectEntry(
            playerId = readString(), name = readString(), schoolName = readString(), rank = readInt(), score = readInt(),
            isCurrentPlayer = readBoolean(), tag = if (includeTag) readString() else "",
        )
    }

    private fun DataOutputStream.writePitchSession(value: HighSchoolPitchSession) {
        writeString(value.sessionId); writeInt(value.gameNumber); writeString(value.seed); writeInt(value.pitchIndex); writeString(value.preparationToken)
        writeContext(value.context); writeMemory(value.memory); writeGame(value.game); writeLog(value.log)
        writeInt(value.pitches); writeInt(value.strikeouts); writeInt(value.walks); writeInt(value.runsAllowed); writeInt(value.expectedDamage); writeInt(value.actualDamage); writeInt(value.recommendationAccepted); writeInt(value.outs); writeInt(value.hits); writeStrings(value.abilityMoments); writeBoolean(value.ended)
        writeInt(value.sequenceMasteryCount)
        writeList(value.sequencePitches) {
            writeString(it.pitchType.wire); writeInt(it.zone.row); writeInt(it.zone.column); writeString(it.intent.wire); writeInt(it.expectedVelocityKph); writeString(it.outcome.wire)
        }
    }
    private fun DataInputStream.readPitchSession(includeSequencePitches: Boolean): HighSchoolPitchSession {
        val sessionId = readString(); val gameNumber = readInt(); val seed = readString(); val pitchIndex = readInt(); val preparationToken = readString()
        val context = readContext(); val memory = readMemory(); val game = readGame(); val log = readLog()
        val pitches = readInt(); val strikeouts = readInt(); val walks = readInt(); val runsAllowed = readInt(); val expectedDamage = readInt(); val actualDamage = readInt(); val accepted = readInt(); val outs = readInt(); val hits = readInt(); val abilityMoments = readStrings(); val ended = readBoolean()
        val sequenceMasteryCount = if (includeSequencePitches) readInt() else 0
        val sequencePitches = if (includeSequencePitches) readList {
            com.solkim.baseball.core.pitch.PitchSequencePitch(
                pitchKind(readString()),
                PitchZone(readInt(), readInt()),
                zoneIntent(readString()),
                readInt(),
                pitchOutcome(readString()),
            )
        } else emptyList()
        return HighSchoolPitchSession(
            sessionId = sessionId,
            gameNumber = gameNumber,
            seed = seed,
            pitchIndex = pitchIndex,
            preparationToken = preparationToken,
            context = context,
            memory = memory,
            game = game,
            log = log,
            pitches = pitches,
            strikeouts = strikeouts,
            walks = walks,
            runsAllowed = runsAllowed,
            expectedDamage = expectedDamage,
            actualDamage = actualDamage,
            recommendationAccepted = accepted,
            outs = outs,
            hits = hits,
            abilityMoments = abilityMoments,
            ended = ended,
            sequenceMasteryCount = sequenceMasteryCount,
            sequencePitches = sequencePitches,
        )
    }

    private fun DataOutputStream.writeContext(value: HighSchoolPitchContext) {
        writeString(value.plateAppearanceId); writeULong(value.revision); writeInt(value.inning); writeInt(value.outs); writeInt(value.balls); writeInt(value.strikes); writeInt(value.pitchNumber); writeInt(value.scoreDifferential); writeInt(value.leverage); writeInt(value.fatigue)
    }
    private fun DataInputStream.readContext(): HighSchoolPitchContext = HighSchoolPitchContext(readString(), readULong(), readInt(), readInt(), readInt(), readInt(), readInt(), readInt(), readInt(), readInt())

    private fun DataOutputStream.writeMemory(value: HighSchoolPitchMemory) {
        writeULong(value.revision); writeInt(value.plateAppearancesSeen); writeInt(value.totalPitchesSeen); writeList(value.observations) { writeString(it.pitchType.wire); writeInt(it.zone.row); writeInt(it.zone.column); writeString(it.zoneIntent.wire); writeInt(it.balls); writeInt(it.strikes); writeString(it.outcome.wire) }
    }
    private fun DataInputStream.readMemory(): HighSchoolPitchMemory = HighSchoolPitchMemory(readULong(), readInt(), readInt(), readList { HighSchoolPitchObservation(pitchKind(readString()), PitchZone(readInt(), readInt()), zoneIntent(readString()), readInt(), readInt(), pitchOutcome(readString())) })

    private fun DataOutputStream.writeGame(value: HighSchoolPitchGame) {
        writeInt(value.runsAllowed); writeInt(value.inning); writeInt(value.outs); writeBoolean(value.firstOccupied); writeBoolean(value.secondOccupied); writeBoolean(value.thirdOccupied)
    }
    private fun DataInputStream.readGame(): HighSchoolPitchGame = HighSchoolPitchGame(readInt(), readInt(), readInt(), readBoolean(), readBoolean(), readBoolean())

    private fun DataOutputStream.writeLog(value: HighSchoolPitchLog) {
        writeString(value.gameId); writeInt(value.totalPitches); writeList(value.entries) {
            writeString(it.pitchType.wire); writeBoolean(it.wasInZone); writeBoolean(it.batterSwung); writeString(it.outcome.wire); writeString(it.selectionQuality.wire); writeInt(it.executionQuality); writeNullableInt(it.contactQuality); writeInt(it.expectedDamage); writeInt(it.actualDamage); writeBoolean(it.recommendationAccepted); writeNullableInt(it.velocityTenthsKph)
        }
    }
    private fun DataInputStream.readLog(): HighSchoolPitchLog = HighSchoolPitchLog(readString(), readInt(), readList { HighSchoolPitchLogEntry(pitchKind(readString()), readBoolean(), readBoolean(), pitchOutcome(readString()), selectionQuality(readString()), readInt(), readNullableInt(), readInt(), readInt(), readBoolean(), readNullableInt()) })

    private fun DataOutputStream.writePresentation(value: HighSchoolPresentationState) {
        writeString(value.snapshot.pitchType.wire); writeString(value.snapshot.presentationSeed); writeInt(value.snapshot.flightDurationMilliseconds); writeInt(value.snapshot.plateXMm); writeInt(value.snapshot.plateYMm); writeInt(value.snapshot.velocityTenthsKph); writeInts(value.snapshot.trajectorySeries); writeInt(value.pitchNumber); writeString(value.outcome); writeBoolean(value.terminal)
    }
    private fun DataInputStream.readPresentation(): HighSchoolPresentationState = HighSchoolPresentationState(
        com.solkim.baseball.core.pitch.TrajectoryPresentationSnapshot(pitchKind(readString()), readString(), readInt(), readInt(), readInt(), readInt(), readInts()), readInt(), readString(), readBoolean(),
    )

    private fun DataOutputStream.writeChallengeBackup(value: HighSchoolChallengeBackup) {
        writeString(HighSchoolStateCodec.encode(value.run).toBase64()); writePitcher(value.startingPitcher, includeProfiles = true); writeInheritance(value.inheritance); writeArchive(value.archive); writeStrings(value.achievements); writeStrings(value.unacknowledgedAchievements); writeWeekly(value.weekly, includeMetaFields = true); writeNullable(value.pledge) { writePledge(it) }; writeNullable(value.nextRunIntent) { writeNextRunIntent(it) }; writeNullableString(value.selectedSignatureLegacyId); writeNullable(value.returnPlan) { writeReturnPlan(it, includeMetaFields = true) }; writeNullable(value.rebirthEcho) { writeEcho(it) }; writeSeasonLog(value.seasonLog); writeTournaments(value.tournaments); writeProspects(value.prospectBoard); writeULong(value.completedGameCounter); writeStrings(value.completedGameReceipts); writeTrainingEvidence(value.trainingEvidence); writeString(value.selectedDayKey); writeBoolean(value.tutorial.started); writeBoolean(value.tutorial.completed); writeCommandReceipts(value.commandReceipts); writeULong(value.revision); writeNullable(value.lastPresentation) { writePresentation(it) }
    }
    private fun DataInputStream.readChallengeBackup(
        includeProfiles: Boolean,
        includeTournamentSchools: Boolean,
        includeProspectTags: Boolean,
        includeRichEcho: Boolean,
        includeMetaFields: Boolean,
        includeTrainingEvidence: Boolean,
    ): HighSchoolChallengeBackup {
        val run = HighSchoolStateCodec.decode(readString().fromBase64())
        val startingPitcher = readPitcher(includeProfiles)
        val inheritance = readInheritance()
        val archive = readArchive()
        val achievements = readStrings()
        val unacknowledgedAchievements = if (includeMetaFields) readStrings() else emptyList()
        val weekly = readWeekly(includeMetaFields = includeMetaFields)
        val pledge = readNullable { readPledge() }
        val nextRunIntent = readNullable { readNextRunIntent() }
        val selectedSignature = readNullableString()
        val returnPlan = readNullable { readReturnPlan(includeMetaFields = includeMetaFields) }
        val echo = readNullable { readEcho(includeRichFields = includeRichEcho) }
        val seasonLog = readSeasonLog(includeRichFields = includeRichEcho)
        val tournaments = readTournaments(includeSchools = includeTournamentSchools)
        val prospects = readProspects(includeTag = includeProspectTags)
        val counter = readULong()
        val receipts = readStrings()
        val trainingEvidence = if (includeTrainingEvidence) readTrainingEvidence() else emptyList()
        val selectedDayKey = readString()
        val tutorial = HighSchoolTutorialState(readBoolean(), readBoolean())
        val commandReceipts = readCommandReceipts()
        val revision = readULong()
        val lastPresentation = readNullable { readPresentation() }
        return HighSchoolChallengeBackup(
            run = run,
            startingPitcher = startingPitcher,
            inheritance = inheritance,
            archive = archive,
            achievements = achievements,
            unacknowledgedAchievements = unacknowledgedAchievements,
            weekly = weekly,
            pledge = pledge,
            selectedSignatureLegacyId = selectedSignature,
            returnPlan = returnPlan,
            rebirthEcho = echo,
            seasonLog = seasonLog,
            tournaments = tournaments,
            prospectBoard = prospects,
            completedGameCounter = counter,
            completedGameReceipts = receipts,
            trainingEvidence = trainingEvidence,
            selectedDayKey = selectedDayKey,
            tutorial = tutorial,
            commandReceipts = commandReceipts,
            revision = revision,
            lastPresentation = lastPresentation,
            nextRunIntent = nextRunIntent,
        )
    }

    private fun DataOutputStream.writeCommandReceipts(values: List<HighSchoolCommandReceipt>) {
        writeList(values) { writeString(it.commandId); writeULong(it.revision); writeString(it.resultHash); writeString(it.commandHash); writeString(it.sessionId) }
    }
    private fun DataInputStream.readCommandReceipts(): List<HighSchoolCommandReceipt> = readList { HighSchoolCommandReceipt(readString(), readULong(), readString(), readString(), readString()) }

    private fun DataOutputStream.writeTrainingEvidence(values: List<HighSchoolTrainingEvidence>) {
        writeList(values) { value ->
            writeString(value.careerId); writeInt(value.lifeNumber); writeInt(value.chapterNumber); writeInt(value.trainingNumber)
            writeString(value.focus.wire); writeString(value.intensity.wire); writeNullableString(value.targetPitch?.wire)
            writeInt(value.growthPoints); writeInt(value.fatigueDelta); writeInt(value.codecVersion)
        }
    }

    private fun DataInputStream.readTrainingEvidence(): List<HighSchoolTrainingEvidence> = readList {
        val careerId = readString()
        val lifeNumber = readInt()
        val chapterNumber = readInt()
        val trainingNumber = readInt()
        val focusWire = readString()
        val intensityWire = readString()
        HighSchoolTrainingEvidence(
            careerId = careerId,
            lifeNumber = lifeNumber,
            chapterNumber = chapterNumber,
            trainingNumber = trainingNumber,
            focus = HighSchoolTrainingFocus.entries.firstOrNull { it.wire == focusWire } ?: fail("trainingEvidence.focus"),
            intensity = HighSchoolTrainingIntensity.entries.firstOrNull { it.wire == intensityWire } ?: fail("trainingEvidence.intensity"),
            targetPitch = readNullableString()?.let(::pitchKind),
            growthPoints = readInt(),
            fatigueDelta = readInt(),
            codecVersion = readInt(),
        )
    }

    private fun DataOutputStream.writeStrings(values: List<String>) { writeList(values) { writeString(it) } }
    private fun DataInputStream.readStrings(): List<String> = readList { readString() }
    private fun DataOutputStream.writeInts(values: List<Int>) { writeList(values) { writeInt(it) } }
    private fun DataInputStream.readInts(): List<Int> = readList { readInt() }
    private fun DataOutputStream.writeULong(value: ULong) { writeString(value.toString()) }
    private fun DataInputStream.readULong(): ULong = readString().toULongOrNull() ?: fail("ulong.invalid")
    private fun DataOutputStream.writeNullableString(value: String?) { writeBoolean(value != null); if (value != null) writeString(value) }
    private fun DataInputStream.readNullableString(): String? = if (readBoolean()) readString() else null
    private fun DataOutputStream.writeNullableInt(value: Int?) { writeBoolean(value != null); if (value != null) writeInt(value) }
    private fun DataInputStream.readNullableInt(): Int? = if (readBoolean()) readInt() else null
    private fun DataOutputStream.writeNullableBoolean(value: Boolean?) { writeBoolean(value != null); if (value != null) writeBoolean(value) }
    private fun DataInputStream.readNullableBoolean(): Boolean? = if (readBoolean()) readBoolean() else null
    private fun <T> DataOutputStream.writeNullable(value: T?, writer: DataOutputStream.(T) -> Unit) { writeBoolean(value != null); if (value != null) writer(value) }
    private fun <T> DataInputStream.readNullable(reader: DataInputStream.() -> T): T? = if (readBoolean()) reader() else null
    private fun <T> DataOutputStream.writeList(values: List<T>, writer: DataOutputStream.(T) -> Unit) { if (values.size > 1_000) fail("list.too_large"); writeInt(values.size); values.forEach { writer(it) } }
    private fun <T> DataInputStream.readList(reader: DataInputStream.() -> T): List<T> { val size = readInt(); if (size !in 0..1_000) fail("list.size"); return List(size) { reader() } }

    private fun DataOutputStream.writeString(value: String) {
        val bytes = value.toByteArray(Charsets.UTF_8)
        if (bytes.size > 1_000_000) fail("string.too_large")
        writeInt(bytes.size); write(bytes)
    }
    private fun DataInputStream.readString(): String {
        val size = readInt()
        if (size !in 0..1_000_000) fail("string.size")
        val bytes = ByteArray(size).also(::readFully)
        return try {
            Charsets.UTF_8.newDecoder()
                .onMalformedInput(CodingErrorAction.REPORT)
                .onUnmappableCharacter(CodingErrorAction.REPORT)
                .decode(ByteBuffer.wrap(bytes))
                .toString()
        } catch (_: Exception) {
            fail("string.utf8")
        }
    }

    private fun pledgeTier(wire: String): HighSchoolPledgeTier = HighSchoolPledgeTier.entries.firstOrNull { it.wire == wire } ?: fail("pledge.tier")
    private fun returnDestination(wire: String): HighSchoolReturnDestination = HighSchoolReturnDestination.entries.firstOrNull { it.wire == wire } ?: fail("return.destination")
    private fun pitchKind(wire: String): PitchKind = PitchKind.entries.firstOrNull { it.wire == wire } ?: fail("pitch.kind")
    private fun pitchRole(wire: String): com.solkim.baseball.core.pitch.PitchUsageRole = com.solkim.baseball.core.pitch.PitchUsageRole.entries.firstOrNull { it.wire == wire } ?: fail("pitch.role")
    private fun throwingHand(wire: String): com.solkim.baseball.core.pitch.ThrowingHand = when (wire) {
        "right" -> com.solkim.baseball.core.pitch.ThrowingHand.RIGHT
        "left" -> com.solkim.baseball.core.pitch.ThrowingHand.LEFT
        else -> fail("pitch.throwingHand")
    }
    private fun zoneIntent(wire: String): ZoneIntent = ZoneIntent.entries.firstOrNull { it.wire == wire } ?: fail("pitch.zoneIntent")
    private fun pitchOutcome(wire: String): PitchOutcome = PitchOutcome.entries.firstOrNull { it.wire == wire } ?: fail("pitch.outcome")
    private fun selectionQuality(wire: String): SelectionQuality = SelectionQuality.entries.firstOrNull { it.wire == wire } ?: fail("pitch.selection")
    private fun pitchingDecision(wire: String): HighSchoolPitchingDecision = HighSchoolPitchingDecision.entries.firstOrNull { it.wire == wire } ?: fail("seasonLine.decision")

    private fun String.toBase64(): String = Base64.getEncoder().encodeToString(toByteArray(Charsets.ISO_8859_1))
    private fun ByteArray.toBase64(): String = Base64.getEncoder().encodeToString(this)
    private fun String.fromBase64(): ByteArray = decodeCanonicalBase64(this, "base64.invalid")
    private fun decodeCanonicalBase64(value: String, code: String): ByteArray = try {
        val decoded = Base64.getDecoder().decode(value)
        if (Base64.getEncoder().encodeToString(decoded) != value) fail(code)
        decoded
    } catch (error: HighSchoolPhase4StateCodecException) { throw error }
    catch (_: Exception) { fail(code) }

    private fun requireExact(value: JsonValue.Obj, expected: Set<String>, field: String) {
        val missing = expected - value.entries.keys
        val unknown = value.entries.keys - expected
        if (missing.isNotEmpty()) fail("$field.missing:${missing.sorted().joinToString(",")}")
        if (unknown.isNotEmpty()) fail("$field.unknown:${unknown.sorted().joinToString(",")}")
    }
    private fun JsonValue.Obj.string(name: String): String = (this[name] as? JsonValue.Str)?.value ?: fail("$name.string")
    private fun JsonValue.Obj.integer(name: String): Int = (this[name] as? JsonValue.Num)?.raw?.toIntOrNull() ?: fail("$name.integer")
    private fun fail(code: String): Nothing = throw HighSchoolPhase4StateCodecException(code)
}

public class HighSchoolPhase4StateCodecException(message: String) : IllegalArgumentException(message)
