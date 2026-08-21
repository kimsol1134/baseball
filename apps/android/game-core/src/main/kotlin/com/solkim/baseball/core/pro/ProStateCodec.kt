package com.solkim.baseball.core.pro

import com.solkim.baseball.core.pitch.BatSide
import com.solkim.baseball.core.pitch.BatterScoutingSnapshot
import com.solkim.baseball.core.pitch.BatterSnapshot
import com.solkim.baseball.core.pitch.BaserunnerStateSnapshot
import com.solkim.baseball.core.pitch.DefenseSnapshot
import com.solkim.baseball.core.pitch.FielderSnapshot
import com.solkim.baseball.core.pitch.GameLogSnapshot
import com.solkim.baseball.core.pitch.GameStateSnapshot
import com.solkim.baseball.core.pitch.HalfInning
import com.solkim.baseball.core.pitch.InningStateSnapshot
import com.solkim.baseball.core.pitch.ParkSnapshot
import com.solkim.baseball.core.pitch.PitchAnalysisEntry
import com.solkim.baseball.core.pitch.PitchKind
import com.solkim.baseball.core.pitch.PitchProfileSnapshot
import com.solkim.baseball.core.pitch.PitchSequencePitch
import com.solkim.baseball.core.pitch.PitchZone
import com.solkim.baseball.core.pitch.PitcherSnapshot
import com.solkim.baseball.core.pitch.PitchOutcome
import com.solkim.baseball.core.pitch.PitchUsageRole
import com.solkim.baseball.core.pitch.PlateAppearanceContext
import com.solkim.baseball.core.pitch.RivalMemorySnapshot
import com.solkim.baseball.core.pitch.RivalPitchObservation
import com.solkim.baseball.core.pitch.SelectionQuality
import com.solkim.baseball.core.pitch.ThrowingHand
import com.solkim.baseball.core.pitch.TrajectoryPresentationSnapshot
import com.solkim.baseball.core.pitch.ZoneIntent
import com.solkim.baseball.core.highschool.HighSchoolPerformance
import com.solkim.baseball.model.JsonValue
import com.solkim.baseball.model.StrictJson
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.DataInputStream
import java.io.DataOutputStream
import java.nio.ByteBuffer
import java.nio.charset.CodingErrorAction
import java.util.Base64

/** Strict, signed, deterministic Pro snapshot wire. It is shadow-only in Phase 5. */
public object ProStateCodec {
    public const val SCHEMA: String = ProWire.STATE_SCHEMA
    public const val SCHEMA_VERSION: Int = ProWire.SCHEMA_VERSION
    public const val MAX_BYTES: Int = 4 * 1024 * 1024
    private const val MAGIC: String = "PRM1"
    private val ROOT_FIELDS = setOf("schema", "schemaVersion", "payload", "stateCommitment")

    public fun encode(state: ProState): ByteArray {
        require(state.journeyState == null) { "pro.state.journey_requires_v2" }
        try { ProKernel().validateSavedState(state) } catch (error: IllegalArgumentException) { throw ProStateCodecException(error.message ?: "pro.state.invalid") }
        val output = ByteArrayOutputStream()
        DataOutputStream(output).use { data -> writeState(data, state) }
        val root = JsonValue.Obj(linkedMapOf(
            "schema" to JsonValue.Str(SCHEMA),
            "schemaVersion" to JsonValue.Num(SCHEMA_VERSION.toString()),
            "payload" to JsonValue.Str(output.toByteArray().toBase64()),
            "stateCommitment" to JsonValue.Str(state.commitment),
        ))
        return StrictJson.canonical(root).toByteArray(Charsets.UTF_8)
    }

    public fun decode(bytes: ByteArray): ProState {
        if (bytes.isEmpty()) fail("pro.state.empty")
        if (bytes.size > MAX_BYTES) fail("pro.state.too_large")
        val root = try { StrictJson.parseUtf8(bytes) as? JsonValue.Obj ?: fail("pro.state.root") }
        catch (error: ProStateCodecException) { throw error }
        catch (_: Exception) { fail("pro.state.json") }
        requireExact(root, ROOT_FIELDS, "pro.state.root")
        if (!bytes.contentEquals(StrictJson.canonical(root).toByteArray(Charsets.UTF_8))) fail("pro.state.noncanonical")
        if (root.string("schema") != SCHEMA) fail("pro.state.schema")
        val version = root.integer("schemaVersion")
        if (version != SCHEMA_VERSION) fail(if (version > SCHEMA_VERSION) "pro.state.future:$version" else "pro.state.migration:$version")
        val payload = decodeCanonicalBase64(root.string("payload"), "pro.state.payload")
        val state = try { DataInputStream(ByteArrayInputStream(payload)).use { readState(it, version) } }
        catch (error: ProStateCodecException) { throw error }
        catch (_: Exception) { fail("pro.state.payload_invalid") }
        if (root.string("stateCommitment") != state.commitment) fail("pro.state.commitment_mismatch")
        try { ProKernel().validateSavedState(state) } catch (error: IllegalArgumentException) { fail(error.message ?: "pro.state.invalid") }
        return state
    }

    private fun writeState(out: DataOutputStream, state: ProState) {
        out.writeString(MAGIC); out.writeInt(SCHEMA_VERSION)
        out.writeString(state.careerId); out.writeULong(state.revision); out.writeString(state.startMode.wire); out.writeNullableString(state.sourceHighSchoolCareerId); out.writeNullable(state.highSchoolLegacyContext) { writeLegacyContext(it) }
        out.writeBoolean(state.activeHighSchoolPreserved); out.writeString(state.seed); out.writeString(state.identityName); out.writePitcher(state.pitcher)
        out.writeTeam(state.team); out.writeEntitlement(state.entitlement)
        out.writeInt(state.age); out.writeInt(state.season); out.writeInt(state.week); out.writeString(state.phase.wire); out.writeString(state.level.wire); out.writeString(state.role.wire); out.writeNullableString(state.rolePreference?.wire)
        out.writeInt(state.managerTrust); out.writeInt(state.catcherTrust); out.writeInt(state.fatigue); out.writeInt(state.injuryWeeks); out.writeInt(state.serviceYears); out.writeBoolean(state.militaryCompleted); out.writeNullable(state.contract) { writeContract(it) }
        out.writeStats(state.currentStats); out.writeList(state.currentGameLines) { writeGameLine(it) }; out.writeList(state.careerStats) { writeStats(it) }; out.writeList(state.seasonLedgers) { writeLedger(it) }
        out.writeStrings(state.awards); out.writeStrings(state.milestones); out.writeList(state.decisionHistory) { writeDecisionRecord(it) }; out.writeNullable(state.pendingDecision) { writeDecision(it) }
        out.writeDevelopment(state.developmentProgress); out.writeString(state.seasonSegment.wire); out.writeNullableString(state.seasonTrigger?.wire); out.writeNullable(state.currentRival) { writeRival(it) }; out.writeList(state.seasonTensions) { writeTension(it) }
        out.writeInt(state.importantGames); out.writeList(state.standings) { writeStanding(it) }; out.writeList(state.leaderboards) { writeLeaderboard(it) }; out.writeList(state.legacyCandidates) { writeLegacy(it) }; out.writeNullableString(state.selectedLegacyId)
        out.writeNullable(state.highSchoolArchiveSettlement) { writeSettlement(it) }; out.writeNullable(state.activePitch) { writePitchSession(it) }; out.writeNullable(state.lastPresentation) { writePresentation(it) }; out.writeNullable(state.lastSegmentProgress) { writeSegmentProgress(it) }; out.writeNullableInt(state.hallOfFameScore); out.writeStrings(state.news)
        out.writeList(state.commandReceipts) { writeReceipt(it) }; out.writeString(state.commitment)
        out.writeInt(state.proRulesVersion)
    }

    private fun readState(input: DataInputStream, version: Int): ProState {
        if (input.readString() != MAGIC) fail("pro.state.magic")
        if (input.readInt() != version || version != SCHEMA_VERSION) fail("pro.state.version")
        val careerId = input.readString(); val revision = input.readULong(); val mode = startMode(input.readString()); val source = input.readNullableString(); val legacyContext = input.readNullable { readLegacyContext() }; val activePreserved = input.readBoolean(); val seed = input.readString(); val name = input.readString(); val pitcher = input.readPitcher(); val team = input.readTeam(); val entitlement = input.readEntitlement()
        val age = input.readInt(); val season = input.readInt(); val week = input.readInt(); val phase = careerPhase(input.readString()); val level = level(input.readString()); val role = role(input.readString()); val rolePreference = input.readNullableString()?.let(::role)
        val managerTrust = input.readInt(); val catcherTrust = input.readInt(); val fatigue = input.readInt(); val injuryWeeks = input.readInt(); val serviceYears = input.readInt(); val military = input.readBoolean(); val contract = input.readNullable { readContract() }
        val currentStats = input.readStats(); val currentLines = input.readList { readGameLine() }; val careerStats = input.readList { readStats() }; val ledgers = input.readList { readLedger() }
        val awards = input.readStrings(); val milestones = input.readStrings(); val decisions = input.readList { readDecisionRecord() }; val pending = input.readNullable { readDecision() }
        val development = input.readDevelopment(); val segment = segment(input.readString()); val trigger = input.readNullableString()?.let(::trigger); val rival = input.readNullable { readRival() }; val tensions = input.readList { readTension() }
        val importantGames = input.readInt(); val standings = input.readList { readStanding() }; val leaderboards = input.readList { readLeaderboard() }; val legacy = input.readList { readLegacy() }; val selectedLegacy = input.readNullableString()
        val settlement = input.readNullable { readSettlement() }; val activePitch = input.readNullable { readPitchSession() }; val presentation = input.readNullable { readPresentation() }; val lastSegment = input.readNullable { readSegmentProgress() }; val hof = input.readNullableInt(); val news = input.readStrings()
        val receipts = input.readList { readReceipt() }; val commitment = input.readString()
        val proRulesVersion = if (input.available() >= 4) input.readInt() else 1
        if (input.available() != 0) fail("pro.state.trailing_bytes")
        return ProState(careerId, revision, mode, source, legacyContext, activePreserved, seed, name, pitcher, team, entitlement, age, season, week, phase, level, role, rolePreference, managerTrust, catcherTrust, fatigue, injuryWeeks, serviceYears, military, contract, currentStats, currentLines, careerStats, ledgers, awards, milestones, decisions, pending, development, segment, trigger, rival, tensions, importantGames, standings, leaderboards, legacy, selectedLegacy, settlement, activePitch, presentation, lastSegment, hof, news, receipts, commitment, proRulesVersion)
    }

    private fun DataOutputStream.writeTeam(value: ProTeam) { writeString(value.id); writeString(value.name); writeString(value.positionCompetitor); writeString(value.developmentPlan); writeInt(value.demand) }
    private fun DataInputStream.readTeam(): ProTeam = ProTeam(readString(), readString(), readString(), readString(), readInt())
    private fun DataOutputStream.writeEntitlement(value: ProEntitlement) { writeBoolean(value.active); writeString(value.source); writeString(value.verifiedAt) }
    private fun DataInputStream.readEntitlement(): ProEntitlement = ProEntitlement(readBoolean(), readString(), readString())
    private fun DataOutputStream.writePitcher(value: PitcherSnapshot) { writeString(value.id); writeString(value.name); writeInt(value.stuff); writeInt(value.command); writeInt(value.movement); writeInt(value.stamina); writeString(value.throwingHand.wire()); writeNullable(value.pitchProfiles) { writeList(it) { writeProfile(it) } } }
    private fun DataInputStream.readPitcher(): PitcherSnapshot {
        val id = readString(); val name = readString(); val stuff = readInt(); val command = readInt(); val movement = readInt(); val stamina = readInt(); val throwingHand = hand(readString()); val profiles = readNullable { readList { readProfile() } }
        return PitcherSnapshot(id, name, stuff, command, movement, stamina, profiles, throwingHand)
    }
    private fun DataOutputStream.writeProfile(value: PitchProfileSnapshot) { writeString(value.pitchType.wire); writeString(value.role.wire); writeInt(value.velocityTenthsKph); writeInt(value.control); writeInt(value.command); writeInt(value.movement); writeInt(value.whiff); writeInt(value.weakContact); writeInt(value.fatigueCost) }
    private fun DataInputStream.readProfile(): PitchProfileSnapshot = PitchProfileSnapshot(pitchKind(readString()), pitchRole(readString()), readInt(), readInt(), readInt(), readInt(), readInt(), readInt(), readInt())
    private fun DataOutputStream.writeContract(value: ProContract) { writeInt(value.yearsRemaining); writeInt(value.annualSalary); writeString(value.rolePromise.wire) }
    private fun DataInputStream.readContract(): ProContract = ProContract(readInt(), readInt(), role(readString()))
    private fun DataOutputStream.writeDevelopment(value: ProDevelopmentProgress) { writeInt(value.stuff); writeInt(value.command); writeInt(value.movement); writeInt(value.stamina) }
    private fun DataInputStream.readDevelopment(): ProDevelopmentProgress = ProDevelopmentProgress(readInt(), readInt(), readInt(), readInt())
    private fun DataOutputStream.writeLegacyContext(value: ProHighSchoolLegacyContext) {
        writePitcher(value.startingPitcher); writePitcher(value.highSchoolPitcher)
        writeInt(value.performance.importantGamesCompleted); writeInt(value.performance.pitches); writeInt(value.performance.strikeouts); writeInt(value.performance.walks); writeInt(value.performance.runsAllowed); writeInt(value.performance.expectedDamage); writeInt(value.performance.actualDamage); writeInt(value.performance.outs); writeInt(value.performance.hits)
        writeStrings(value.selectedAwakenings); writeInt(value.managerTrust); writeInt(value.catcherTrust); writeInt(value.rivalTrust)
    }
    private fun DataInputStream.readLegacyContext(): ProHighSchoolLegacyContext = ProHighSchoolLegacyContext(
        startingPitcher = readPitcher(), highSchoolPitcher = readPitcher(),
        performance = HighSchoolPerformance(readInt(), readInt(), readInt(), readInt(), readInt(), readInt(), readInt(), readInt(), readInt()),
        selectedAwakenings = readStrings(), managerTrust = readInt(), catcherTrust = readInt(), rivalTrust = readInt(),
    )

    private fun DataOutputStream.writeStats(value: ProSeasonStats) { writeInt(value.season); writeString(value.teamId); writeInt(value.games); writeInt(value.starts); writeInt(value.inningsOuts); writeInt(value.strikeouts); writeInt(value.walks); writeInt(value.runsAllowed); writeInt(value.hits); writeInt(value.homeRuns); writeInt(value.pitches); writeInt(value.wins); writeInt(value.losses); writeInt(value.saves) }
    private fun DataInputStream.readStats(): ProSeasonStats = ProSeasonStats(readInt(), readString(), readInt(), readInt(), readInt(), readInt(), readInt(), readInt(), readInt(), readInt(), readInt(), readInt(), readInt(), readInt())
    private fun DataOutputStream.writeGameLine(value: ProGameLine) { writeInt(value.season); writeInt(value.week); writeInt(value.outingNumber); writeBoolean(value.started); writeInt(value.outs); writeInt(value.strikeouts); writeInt(value.walks); writeInt(value.runsAllowed); writeInt(value.pitches); writeInt(value.teamRuns); writeInt(value.opponentRuns); writeString(value.decision.wire); writeBoolean(value.played); writeInt(value.hits); writeInt(value.homeRuns) }
    private fun DataInputStream.readGameLine(): ProGameLine = ProGameLine(readInt(), readInt(), readInt(), readBoolean(), readInt(), readInt(), readInt(), readInt(), readInt(), readInt(), readInt(), pitchingDecision(readString()), readBoolean(), readInt(), readInt())

    private fun DataOutputStream.writeEffect(value: ProDecisionEffect) { writeInt(value.stuffDelta); writeInt(value.commandDelta); writeInt(value.movementDelta); writeInt(value.staminaDelta); writeInt(value.managerTrustDelta); writeInt(value.catcherTrustDelta); writeInt(value.fatigueDelta); writeNullableString(value.roleTarget?.wire) }
    private fun DataInputStream.readEffect(): ProDecisionEffect = ProDecisionEffect(readInt(), readInt(), readInt(), readInt(), readInt(), readInt(), readInt(), readNullableString()?.let(::role))
    private fun DataOutputStream.writeChoice(value: ProDecisionChoice) { writeString(value.id); writeString(value.title); writeString(value.detail); writeEffect(value.effect) }
    private fun DataInputStream.readChoice(): ProDecisionChoice = ProDecisionChoice(readString(), readString(), readString(), readEffect())
    private fun DataOutputStream.writeDecision(value: ProSeasonDecision) { writeString(value.id); writeString(value.type.wire); writeInt(value.season); writeInt(value.week); writeString(value.title); writeString(value.detail); writeList(value.choices) { writeChoice(it) } }
    private fun DataInputStream.readDecision(): ProSeasonDecision = ProSeasonDecision(readString(), decisionType(readString()), readInt(), readInt(), readString(), readString(), readList { readChoice() })
    private fun DataOutputStream.writeDecisionRecord(value: ProDecisionRecord) { writeString(value.decisionId); writeString(value.type.wire); writeInt(value.season); writeInt(value.week); writeString(value.choiceId); writeString(value.choiceTitle); writeEffect(value.effect); writeNullableInt(value.followUpResolvedWeek) }
    private fun DataInputStream.readDecisionRecord(): ProDecisionRecord = ProDecisionRecord(readString(), decisionType(readString()), readInt(), readInt(), readString(), readString(), readEffect(), readNullableInt())

    private fun DataOutputStream.writeLedger(value: ProSeasonLedger) { writeInt(value.season); writeString(value.teamId); writeStats(value.record); writeList(value.standings) { writeStanding(it) }; writeList(value.leaderboards) { writeLeaderboard(it) }; writeStrings(value.awards); writeStrings(value.milestones); writeInt(value.decisionCount) }
    private fun DataInputStream.readLedger(): ProSeasonLedger = ProSeasonLedger(readInt(), readString(), readStats(), readList { readStanding() }, readList { readLeaderboard() }, readStrings(), readStrings(), readInt())
    private fun DataOutputStream.writeStanding(value: ProStanding) { writeInt(value.rank); writeString(value.teamId); writeString(value.teamName); writeInt(value.wins); writeInt(value.losses); writeInt(value.draws); writeInt(value.gamesBehindPermille); writeBoolean(value.isPlayerTeam) }
    private fun DataInputStream.readStanding(): ProStanding = ProStanding(readInt(), readString(), readString(), readInt(), readInt(), readInt(), readInt(), readBoolean())
    private fun DataOutputStream.writeLeaderboard(value: ProLeaderboardRow) { writeString(value.category); writeInt(value.rank); writeString(value.playerId); writeString(value.playerName); writeString(value.teamId); writeInt(value.value); writeBoolean(value.isCurrentPlayer) }
    private fun DataInputStream.readLeaderboard(): ProLeaderboardRow = ProLeaderboardRow(readString(), readInt(), readString(), readString(), readString(), readInt(), readBoolean())
    private fun DataOutputStream.writeLegacy(value: ProLegacyCandidate) { writeString(value.id); writeString(value.title); writeString(value.evidenceSummary); writeString(value.farewell); writeInt(value.score) }
    private fun DataInputStream.readLegacy(): ProLegacyCandidate = ProLegacyCandidate(readString(), readString(), readString(), readString(), readInt())
    private fun DataOutputStream.writeRival(value: ProRivalBatter) { writeString(value.id); writeString(value.name); writeString(value.archetype); writeString(value.teamId); writeString(value.teamName); writeString(value.record); writeString(value.profile) }
    private fun DataInputStream.readRival(): ProRivalBatter = ProRivalBatter(readString(), readString(), readString(), readString(), readString(), readString(), readString())
    private fun DataOutputStream.writeTension(value: ProSeasonTension) { writeString(value.kind); writeString(value.title); writeString(value.detail) }
    private fun DataInputStream.readTension(): ProSeasonTension = ProSeasonTension(readString(), readString(), readString())
    private fun DataOutputStream.writeSettlement(value: ProHighSchoolArchiveSettlement) { writeString(value.highSchoolCareerId); writeString(value.proCareerId); writeString(value.selectedLegacyId); writeString(value.playerName); writeString(value.teamId); writeInt(value.careerSeasons); writeInt(value.careerGames); writeInt(value.careerStrikeouts); writeString(value.archiveReceipt) }
    private fun DataInputStream.readSettlement(): ProHighSchoolArchiveSettlement = ProHighSchoolArchiveSettlement(readString(), readString(), readString(), readString(), readString(), readInt(), readInt(), readInt(), readString())
    private fun DataOutputStream.writeSegmentProgress(value: ProSegmentProgress) { writeInt(value.advancedWeeks); writeString(value.startingSegment.wire); writeString(value.endingSegment.wire); writeString(value.stopReason); writeString(value.plan.wire); writeNullableString(value.targetPitch?.wire) }
    private fun DataInputStream.readSegmentProgress(): ProSegmentProgress = ProSegmentProgress(readInt(), segment(readString()), segment(readString()), readString(), plan(readString()), readNullableString()?.let(::pitchKind))
    private fun DataOutputStream.writeReceipt(value: ProCommandReceipt) { writeString(value.commandId); writeString(value.sessionId); writeString(value.commandHash); writeString(value.resultHash); writeULong(value.revision) }
    private fun DataInputStream.readReceipt(): ProCommandReceipt = ProCommandReceipt(readString(), readString(), readString(), readString(), readULong())

    private fun DataOutputStream.writePitchSession(value: ProPitchSession) {
        writeString(value.sessionId); writeInt(value.week); writeString(value.seed); writeInt(value.pitchIndex); writeString(value.preparationToken); writeContext(value.context); writeMemory(value.memory); writeGame(value.game); writeLog(value.log); writeBatter(value.batter); writeScouting(value.scouting)
        writeInt(value.pitches); writeInt(value.strikeouts); writeInt(value.walks); writeInt(value.runsAllowed); writeInt(value.expectedDamage); writeInt(value.actualDamage); writeInt(value.recommendationAccepted); writeInt(value.outs); writeInt(value.hits); writeInt(value.homeRuns); writeStrings(value.abilityMoments); writeInt(value.sequenceMasteryCount); writeList(value.sequencePitches) { writeSequence(it) }; writeBoolean(value.ended); writeString(value.boundary.wire)
    }
    private fun DataInputStream.readPitchSession(): ProPitchSession {
        val sessionId = readString(); val week = readInt(); val seed = readString(); val pitchIndex = readInt(); val token = readString(); val context = readContext(); val memory = readMemory(); val game = readGame(); val log = readLog(); val batter = readBatter(); val scouting = readScouting()
        val pitches = readInt(); val strikeouts = readInt(); val walks = readInt(); val runsAllowed = readInt(); val expected = readInt(); val actual = readInt(); val accepted = readInt(); val outs = readInt(); val hits = readInt(); val homeRuns = readInt(); val moments = readStrings(); val mastery = readInt(); val sequence = readList { readSequence() }; val ended = readBoolean(); val boundary = boundary(readString())
        return ProPitchSession(sessionId, week, seed, pitchIndex, token, context, memory, game, log, batter, scouting, pitches, strikeouts, walks, runsAllowed, expected, actual, accepted, outs, hits, homeRuns, moments, mastery, sequence, ended, boundary)
    }
    private fun DataOutputStream.writeContext(value: PlateAppearanceContext) { writeString(value.plateAppearanceId); writeULong(value.revision); writeInt(value.inning); writeInt(value.outs); writeInt(value.balls); writeInt(value.strikes); writeInt(value.pitchNumber); writeInt(value.scoreDifferential); writeInt(value.leverage); writeInt(value.fatigue) }
    private fun DataInputStream.readContext(): PlateAppearanceContext = PlateAppearanceContext(readString(), readULong(), readInt(), readInt(), readInt(), readInt(), readInt(), readInt(), readInt(), readInt())
    private fun DataOutputStream.writeMemory(value: RivalMemorySnapshot) { writeString(value.matchupId); writeULong(value.revision); writeInt(value.plateAppearancesSeen); writeInt(value.totalPitchesSeen); writeList(value.recentObservations) { writeString(it.pitchType.wire); writeInt(it.zone.row); writeInt(it.zone.column); writeString(it.zoneIntent.wire); writeInt(it.balls); writeInt(it.strikes); writeString(it.outcome.wire) } }
    private fun DataInputStream.readMemory(): RivalMemorySnapshot = RivalMemorySnapshot(readString(), readULong(), readInt(), readInt(), readList { RivalPitchObservation(pitchKind(readString()), PitchZone(readInt(), readInt()), zoneIntent(readString()), readInt(), readInt(), outcome(readString())) })
    private fun DataOutputStream.writeGame(value: GameStateSnapshot) { writeDefense(value.defense); writePark(value.park); writeRunners(value.runners); writeInt(value.runsAllowed); writeNullable(value.inningState) { writeInt(it.inning); writeString(it.half.name.lowercase()); writeInt(it.outs) } }
    private fun DataInputStream.readGame(): GameStateSnapshot = GameStateSnapshot(readDefense(), readPark(), readRunners(), readInt(), readNullable { InningStateSnapshot(readInt(), half(readString()), readInt()) })
    private fun DataOutputStream.writeDefense(value: DefenseSnapshot) { writeInt(value.infield); writeInt(value.outfield); writeInt(value.arm); writeNullable(value.fielders) { writeList(it) { writeFielder(it) } } }
    private fun DataInputStream.readDefense(): DefenseSnapshot = DefenseSnapshot(readInt(), readInt(), readInt(), readNullable { readList { readFielder() } })
    private fun DataOutputStream.writeFielder(value: FielderSnapshot) { writeString(value.id); writeString(value.name); writeString(value.position); writeInt(value.range); writeInt(value.glove); writeInt(value.arm) }
    private fun DataInputStream.readFielder(): FielderSnapshot = FielderSnapshot(readString(), readString(), readString(), readInt(), readInt(), readInt())
    private fun DataOutputStream.writePark(value: ParkSnapshot) { writeString(value.id); writeString(value.name); writeInt(value.hitFactor); writeInt(value.homeRunFactor) }
    private fun DataInputStream.readPark(): ParkSnapshot = ParkSnapshot(readString(), readString(), readInt(), readInt())
    private fun DataOutputStream.writeRunners(value: BaserunnerStateSnapshot) { writeBoolean(value.firstOccupied); writeBoolean(value.secondOccupied); writeBoolean(value.thirdOccupied); writeInt(value.leadRunnerSpeed) }
    private fun DataInputStream.readRunners(): BaserunnerStateSnapshot = BaserunnerStateSnapshot(readBoolean(), readBoolean(), readBoolean(), readInt())
    private fun DataOutputStream.writeLog(value: GameLogSnapshot) { writeString(value.gameId); writeULong(value.revision); writeInt(value.totalPitches); writeList(value.entries) { writeAnalysis(it) } }
    private fun DataInputStream.readLog(): GameLogSnapshot = GameLogSnapshot(readString(), readULong(), readInt(), readList { readAnalysis() })
    private fun DataOutputStream.writeAnalysis(value: PitchAnalysisEntry) { writeString(value.pitchType.wire); writeBoolean(value.wasInZone); writeBoolean(value.batterSwung); writeString(value.outcome.wire); writeString(value.selectionQuality.wire); writeInt(value.executionQuality); writeNullableInt(value.contactQuality); writeInt(value.expectedDamage); writeInt(value.actualDamage); writeBoolean(value.recommendationAccepted); writeNullableInt(value.velocityTenthsKph) }
    private fun DataInputStream.readAnalysis(): PitchAnalysisEntry = PitchAnalysisEntry(pitchKind(readString()), readBoolean(), readBoolean(), outcome(readString()), selection(readString()), readInt(), readNullableInt(), readInt(), readInt(), readBoolean(), readNullableInt())
    private fun DataOutputStream.writeBatter(value: BatterSnapshot) { writeString(value.id); writeString(value.name); writeInt(value.contact); writeInt(value.discipline); writeInt(value.power); writeString(value.batSide.name.lowercase()) }
    private fun DataInputStream.readBatter(): BatterSnapshot = BatterSnapshot(readString(), readString(), readInt(), readInt(), readInt(), batSide(readString()))
    private fun DataOutputStream.writeScouting(value: BatterScoutingSnapshot) { writeInt(value.hotZone.row); writeInt(value.hotZone.column); writeInt(value.coldZone.row); writeInt(value.coldZone.column); writeString(value.pitchStrength.wire); writeString(value.pitchWeakness.wire); writeInt(value.chaseTendency); writeInt(value.reliability) }
    private fun DataInputStream.readScouting(): BatterScoutingSnapshot = BatterScoutingSnapshot(PitchZone(readInt(), readInt()), PitchZone(readInt(), readInt()), pitchKind(readString()), pitchKind(readString()), readInt(), readInt())
    private fun DataOutputStream.writeSequence(value: PitchSequencePitch) { writeString(value.pitchType.wire); writeInt(value.zone.row); writeInt(value.zone.column); writeString(value.intent.wire); writeInt(value.expectedVelocityKph); writeString(value.outcome.wire) }
    private fun DataInputStream.readSequence(): PitchSequencePitch = PitchSequencePitch(pitchKind(readString()), PitchZone(readInt(), readInt()), zoneIntent(readString()), readInt(), outcome(readString()))
    private fun DataOutputStream.writePresentation(value: TrajectoryPresentationSnapshot) { writeString(value.pitchType.wire); writeString(value.presentationSeed); writeInt(value.flightDurationMilliseconds); writeInt(value.plateXMm); writeInt(value.plateYMm); writeInt(value.velocityTenthsKph); writeInts(value.trajectorySeries) }
    private fun DataInputStream.readPresentation(): TrajectoryPresentationSnapshot = TrajectoryPresentationSnapshot(pitchKind(readString()), readString(), readInt(), readInt(), readInt(), readInt(), readInts())

    private fun DataOutputStream.writeNullableString(value: String?) { writeBoolean(value != null); if (value != null) writeString(value) }
    private fun DataInputStream.readNullableString(): String? = if (readBoolean()) readString() else null
    private fun DataOutputStream.writeNullableInt(value: Int?) { writeBoolean(value != null); if (value != null) writeInt(value) }
    private fun DataInputStream.readNullableInt(): Int? = if (readBoolean()) readInt() else null
    private inline fun <T> DataOutputStream.writeNullable(value: T?, writer: DataOutputStream.(T) -> Unit) { writeBoolean(value != null); if (value != null) writer(value) }
    private inline fun <T> DataInputStream.readNullable(reader: DataInputStream.() -> T): T? = if (readBoolean()) reader() else null
    private inline fun <T> DataOutputStream.writeList(values: List<T>, writer: DataOutputStream.(T) -> Unit) { writeInt(values.size); values.forEach { writer(it) } }
    private inline fun <T> DataInputStream.readList(reader: DataInputStream.() -> T): List<T> { val count = readCount(); return List(count) { reader() } }
    private fun DataOutputStream.writeStrings(values: List<String>) { writeList(values) { writeString(it) } }
    private fun DataInputStream.readStrings(): List<String> = readList { readString() }
    private fun DataOutputStream.writeInts(values: List<Int>) { writeList(values) { writeInt(it) } }
    private fun DataInputStream.readInts(): List<Int> = readList { readInt() }
    private fun DataOutputStream.writeULong(value: ULong) { writeLong(value.toLong()) }
    private fun DataInputStream.readULong(): ULong = readLong().toULong()
    private fun DataOutputStream.writeString(value: String) { val bytes = value.toByteArray(Charsets.UTF_8); writeInt(bytes.size); write(bytes) }
    private fun DataInputStream.readString(): String { val size = readCount(MAX_STRING_BYTES); val bytes = ByteArray(size); readFully(bytes); return try { Charsets.UTF_8.newDecoder().onMalformedInput(CodingErrorAction.REPORT).onUnmappableCharacter(CodingErrorAction.REPORT).decode(ByteBuffer.wrap(bytes)).toString() } catch (_: Exception) { fail("pro.state.utf8") } }
    private fun DataInputStream.readCount(maximum: Int = MAX_LIST_COUNT): Int { val value = readInt(); if (value !in 0..maximum) fail("pro.state.count"); return value }

    private fun startMode(value: String): ProStartMode = ProStartMode.entries.firstOrNull { it.wire == value } ?: fail("pro.state.start_mode")
    private fun careerPhase(value: String): ProCareerPhase = ProCareerPhase.entries.firstOrNull { it.wire == value } ?: fail("pro.state.phase")
    private fun level(value: String): ProLevel = ProLevel.entries.firstOrNull { it.wire == value } ?: fail("pro.state.level")
    private fun role(value: String): ProRole = ProRole.entries.firstOrNull { it.wire == value } ?: fail("pro.state.role")
    private fun plan(value: String): ProWeekPlan = ProWeekPlan.entries.firstOrNull { it.wire == value } ?: fail("pro.state.plan")
    private fun segment(value: String): ProSeasonSegment = ProSeasonSegment.entries.firstOrNull { it.wire == value } ?: fail("pro.state.segment")
    private fun trigger(value: String): ProSeasonTrigger = ProSeasonTrigger.entries.firstOrNull { it.wire == value } ?: fail("pro.state.trigger")
    private fun decisionType(value: String): ProSeasonDecisionType = ProSeasonDecisionType.entries.firstOrNull { it.wire == value } ?: fail("pro.state.decision_type")
    private fun pitchingDecision(value: String): ProPitchingDecision = ProPitchingDecision.entries.firstOrNull { it.wire == value } ?: fail("pro.state.pitching_decision")
    private fun pitchKind(value: String): PitchKind = PitchKind.entries.firstOrNull { it.wire == value } ?: fail("pro.state.pitch_kind")
    private fun pitchRole(value: String): PitchUsageRole = PitchUsageRole.entries.firstOrNull { it.wire == value } ?: fail("pro.state.pitch_role")
    private fun hand(value: String): ThrowingHand = ThrowingHand.entries.firstOrNull { it.wire() == value } ?: fail("pro.state.hand")
    private fun ThrowingHand.wire(): String = name.lowercase()
    private fun outcome(value: String): PitchOutcome = PitchOutcome.entries.firstOrNull { it.wire == value } ?: fail("pro.state.outcome")
    private fun selection(value: String): SelectionQuality = SelectionQuality.entries.firstOrNull { it.wire == value } ?: fail("pro.state.selection")
    private fun zoneIntent(value: String): ZoneIntent = ZoneIntent.entries.firstOrNull { it.wire == value } ?: fail("pro.state.zone_intent")
    private fun batSide(value: String): BatSide = BatSide.entries.firstOrNull { it.name.lowercase() == value } ?: fail("pro.state.bat_side")
    private fun half(value: String): HalfInning = HalfInning.entries.firstOrNull { it.name.lowercase() == value } ?: fail("pro.state.half")
    private fun boundary(value: String): ProPitchBoundary = ProPitchBoundary.entries.firstOrNull { it.wire == value } ?: fail("pro.state.boundary")

    private fun requireExact(value: JsonValue.Obj, expected: Set<String>, field: String) { val missing = expected - value.entries.keys; val unknown = value.entries.keys - expected; if (missing.isNotEmpty()) fail("$field.missing:${missing.sorted().joinToString(",")}"); if (unknown.isNotEmpty()) fail("$field.unknown:${unknown.sorted().joinToString(",")}") }
    private fun JsonValue.Obj.string(name: String): String = (this[name] as? JsonValue.Str)?.value ?: fail("pro.state.$name")
    private fun JsonValue.Obj.integer(name: String): Int = (this[name] as? JsonValue.Num)?.raw?.toIntOrNull() ?: fail("pro.state.$name")
    private fun ByteArray.toBase64(): String = Base64.getEncoder().encodeToString(this)
    private fun decodeCanonicalBase64(value: String, code: String): ByteArray = try { val bytes = Base64.getDecoder().decode(value); if (Base64.getEncoder().encodeToString(bytes) != value) fail(code); bytes } catch (error: ProStateCodecException) { throw error } catch (_: Exception) { fail(code) }
    private const val MAX_LIST_COUNT: Int = 200_000
    private const val MAX_STRING_BYTES: Int = 1_000_000
    private fun fail(code: String): Nothing = throw ProStateCodecException(code)
}

public class ProStateCodecException(message: String) : IllegalArgumentException(message)
