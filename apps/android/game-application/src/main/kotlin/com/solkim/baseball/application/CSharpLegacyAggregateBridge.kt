package com.solkim.baseball.application

import com.solkim.baseball.core.highschool.CSharpHighSchoolSnapshotCodec
import com.solkim.baseball.core.highschool.CSharpHighSchoolSnapshotCodecException
import com.solkim.baseball.core.highschool.CSharpHighSchoolSnapshotWire
import com.solkim.baseball.core.highschool.HighSchoolPhase
import com.solkim.baseball.core.highschool.HighSchoolPhase4Command
import com.solkim.baseball.core.highschool.HighSchoolPhase4CommandEnvelope
import com.solkim.baseball.core.highschool.HighSchoolPhase4CommandException
import com.solkim.baseball.core.highschool.HighSchoolPhase4CommandStore
import com.solkim.baseball.core.highschool.HighSchoolPhase4Kernel
import com.solkim.baseball.core.highschool.HighSchoolPhase4State
import com.solkim.baseball.core.pro.ProCareerPhase
import com.solkim.baseball.core.pro.ProCommand
import com.solkim.baseball.core.pro.ProCommandEnvelope
import com.solkim.baseball.core.pro.ProCommandException
import com.solkim.baseball.core.pro.ProCommandStore
import com.solkim.baseball.core.pro.ProState
import com.solkim.baseball.model.JsonValue
import com.solkim.baseball.model.StrictJson

/**
 * Translates the frozen C# v1 payload tree into the typed aggregate used by Compose, and writes
 * commands back onto that same tree. [GameStateReducer.dispatch] is intentionally not used: the
 * C# receipt/commitment wire cannot pass [GameAggregateState.validate].
 */
public object CSharpLegacyAggregateBridge {
    public data class ApplyResult(
        val payload: JsonValue.Obj,
        val eventName: String,
    )

    public fun project(payload: JsonValue.Obj, envelopeRevision: ULong, payloadSha256: String): GameAggregateState {
        val highSchool = tryHydrateHighSchool(payload)
        val pro = CSharpLegacyProBridge.project(payload.objectOrNull("pro"))
        val pitch = projectPitch(payload.objectOrNull("pitchResume"))
        val stage = GameStage.entries.firstOrNull { it.wire == payload.string("stage") }
            ?: throw GameCommandException("game.store.stage_unknown")
        return GameAggregateState(
            aggregateVersion = payload.intOrDefault("aggregateVersion", GameAggregateState.CURRENT_AGGREGATE_VERSION),
            revision = envelopeRevision,
            installId = payload.string("installId"),
            stage = stage,
            highSchool = highSchool,
            pro = pro,
            meta = GameMetaState(
                completedGameCount = payload.objectOrNull("meta")?.ulongOrDefault("completedGameCount", 0UL) ?: 0UL,
                activeHighSchoolCareerId = highSchool?.run?.careerId,
                lifeArchiveCareerIds = highSchool?.archive?.map { it.careerId }.orEmpty(),
            ),
            pitch = pitch,
            settings = payload.objectOrNull("settings")?.toSettings() ?: GameSettingsState(),
            analytics = projectAnalytics(payload.objectOrNull("analyticsReceipts")),
            deleted = payload.boolOrDefault("deleted", false),
            commitment = payloadSha256,
        )
    }

    public fun apply(payload: JsonValue.Obj, envelope: GameCommandEnvelope): ApplyResult {
        val projected = project(payload, payload.ulongOrDefault("revision", 0UL), payload.canonicalPlaceholder())
        val eventName: String
        val next = when (val command = envelope.command) {
            is GameCommand.UpdateSettings -> {
                eventName = "settings.updated"
                payload.withSettings(command.settings)
            }
            GameCommand.EnterSetup -> {
                require(projected.stage == GameStage.OPENING) { "setup.opening_required" }
                require(projected.highSchool == null && projected.pro == null) { "setup.active_career" }
                eventName = "setup.opened"
                payload.withStage(GameStage.SETUP)
            }
            is GameCommand.HighSchool -> {
                val applied = applyHighSchool(payload, projected, envelope, command.command)
                eventName = applied.second
                applied.first
            }
            is GameCommand.Pro -> {
                val applied = applyPro(payload, projected, envelope, command.command)
                eventName = applied.second
                applied.first
            }
            is GameCommand.ReservePitch -> {
                eventName = "pitch.reserved"
                applyPitch(payload, reservePitch(projected, command).pitch)
            }
            is GameCommand.StartPitch -> {
                eventName = "pitch.playing"
                applyPitch(payload, startPitch(projected, command).pitch)
            }
            is GameCommand.CommitPitch -> {
                eventName = "pitch.committed"
                applyPitch(payload, commitPitch(projected, command).pitch)
            }
            is GameCommand.ConsumePitch -> {
                eventName = "pitch.consumed"
                applyPitch(payload, consumePitch(projected, command).pitch)
            }
            is GameCommand.MarkPitchTerminal -> {
                eventName = "pitch.terminal"
                applyPitch(payload, terminalPitch(projected, command).pitch)
            }
            is GameCommand.CompletePitch -> {
                eventName = "pitch.completed"
                applyPitch(payload, completePitch(projected, command).pitch, clearResume = true)
            }
            is GameCommand.SuspendPitch -> {
                eventName = "pitch.suspended"
                applyPitch(payload, suspendPitch(projected, command).pitch)
            }
            is GameCommand.ResumePitch -> {
                eventName = "pitch.resumed"
                applyPitch(payload, resumePitch(projected, command).pitch)
            }
            is GameCommand.AbandonPitch -> {
                eventName = "pitch.abandoned"
                applyPitch(payload, abandonPitch(projected, command).pitch, clearResume = true)
            }
            is GameCommand.ClearPitchPresentation -> {
                eventName = "pitch.presentation_cleared"
                clearPresentation(payload, projected, command)
            }
            is GameCommand.RecordAnalytics -> {
                eventName = "analytics.recorded"
                recordAnalytics(payload, projected, command)
            }
        }
        return ApplyResult(next.withCommandReceipt(envelope.commandId), eventName)
    }

    private fun applyHighSchool(
        payload: JsonValue.Obj,
        projected: GameAggregateState,
        envelope: GameCommandEnvelope,
        command: HighSchoolPhase4Command,
    ): Pair<JsonValue.Obj, String> {
        val existing = projected.highSchool
        val isStart = command is HighSchoolPhase4Command.Start
        if (existing == null && !isStart) throw GameCommandException("game.highSchool.start_required")
        if (existing != null && isStart) throw GameCommandException("game.highSchool.start_duplicate")
        val nested = try {
            HighSchoolPhase4CommandStore(initialState = existing).dispatch(
                HighSchoolPhase4CommandEnvelope(
                    commandId = envelope.commandId,
                    sessionId = envelope.sessionId,
                    expectedRevision = existing?.revision ?: 0UL,
                    command = command,
                ),
            )
        } catch (error: HighSchoolPhase4CommandException) {
            throw GameCommandException(error.message ?: "game.highSchool.rejected")
        }
        val next = nested.state
        val previousHighSchool = payload.objectOrNull("highSchool")
        val previousSnapshot = previousHighSchool?.stringOrNull("coreStateJson")?.let { raw ->
            runCatching { StrictJson.parseUtf8(raw.toByteArray()) as? JsonValue.Obj }.getOrNull()
        }
        val coreJson = CSharpHighSchoolSnapshotWire.encodeUtf8(next.run, previousSnapshot)
        val seed = commandSeed(command, previousHighSchool?.stringOrNull("nextSeed") ?: "0")
        val nextSeed = CSharpHighSchoolSnapshotWire.nextSeed(seed, next.run.revision)
        val extras = readExtras(payload.string("installId"), previousHighSchool, nextSeed).copy(
            tutorialCompleted = next.tutorial.completed,
            tutorialAttemptCount = if (next.tutorial.started) maxOf(previousHighSchool?.intOrDefault("tutorialAttemptCount", 0) ?: 0, 1) else 0,
            isChallengeRun = next.challenge.active,
            selectedSignatureLegacyId = next.selectedSignatureLegacyId,
            pledgeId = next.pledge?.definition?.id,
            presetId = next.run.presetId,
        )
        val readModel = overlayHighSchool(previousHighSchool, next, extras, coreJson)
        val stage = when {
            next.run.phase == HighSchoolPhase.COMPLETED && projected.pro == null -> GameStage.BETWEEN_LIVES
            else -> GameStage.HIGH_SCHOOL
        }
        return payload.withHighSchool(readModel, stage) to "highSchool.${commandName(command)}"
    }

    private fun applyPro(
        payload: JsonValue.Obj,
        projected: GameAggregateState,
        envelope: GameCommandEnvelope,
        command: ProCommand,
    ): Pair<JsonValue.Obj, String> {
        val existing = projected.pro
        val isStart = command is ProCommand.StartLinked || command is ProCommand.StartDirect
        if (existing == null && !isStart) throw GameCommandException("game.pro.start_required")
        if (existing != null && isStart) throw GameCommandException("game.pro.start_duplicate")
        if (existing == null && payload.objectOrNull("pro") != null) {
            throw GameCommandException("nativeAuthoritative.legacy_pro_snapshot_unreadable")
        }
        val nested = try {
            ProCommandStore(initialState = existing).dispatch(
                ProCommandEnvelope(
                    commandId = envelope.commandId,
                    sessionId = envelope.sessionId,
                    expectedRevision = existing?.revision ?: 0UL,
                    command = command,
                ),
            )
        } catch (error: ProCommandException) {
            throw GameCommandException(error.message ?: "game.pro.rejected")
        } catch (error: IllegalArgumentException) {
            throw GameCommandException(error.message ?: "game.pro.rejected")
        }
        val next = nested.state
        val previous = payload.objectOrNull("pro")
        val seed = previous?.stringOrNull("nextSeed") ?: next.seed
        val nextSeed = CSharpHighSchoolSnapshotWire.nextSeed(seed, next.revision)
        val readModel = CSharpLegacyProBridge.encodeReadModel(next, nextSeed, previous)
        val stage = when (next.phase) {
            ProCareerPhase.RETIREMENT_DECISION -> GameStage.RETIREMENT
            ProCareerPhase.LEGACY_SELECTION -> GameStage.LEGACY
            ProCareerPhase.COMPLETED -> GameStage.BETWEEN_LIVES
            else -> GameStage.PRO
        }
        return payload.withPro(readModel, stage) to "pro.${commandName(command)}"
    }

    private fun tryHydrateHighSchool(payload: JsonValue.Obj): HighSchoolPhase4State? {
        val highSchool = payload.objectOrNull("highSchool") ?: return null
        val core = highSchool.stringOrNull("coreStateJson") ?: return null
        val parsed = try {
            StrictJson.parseUtf8(core.toByteArray()) as? JsonValue.Obj
        } catch (_: Exception) {
            return null
        } ?: return null
        if (parsed["CareerId"] !is JsonValue.Str || parsed["StateCommitment"] !is JsonValue.Str) return null
        val run = try {
            CSharpHighSchoolSnapshotCodec.decode(core.toByteArray(), highSchool.stringOrNull("presetId"))
        } catch (_: CSharpHighSchoolSnapshotCodecException) {
            return null
        }
        return CSharpHighSchoolSnapshotWire.hydratePhase4(
            run,
            readExtras(payload.string("installId"), highSchool, highSchool.stringOrNull("nextSeed") ?: "0"),
        )
    }

    private fun readExtras(installId: String, highSchool: JsonValue.Obj?, nextSeed: String): CSharpHighSchoolSnapshotWire.ReadExtras =
        CSharpHighSchoolSnapshotWire.ReadExtras(
            installId = installId,
            nextSeed = nextSeed,
            presetId = highSchool?.stringOrNull("presetId"),
            tutorialCompleted = highSchool?.boolOrDefault("tutorialCompleted", false) ?: false,
            tutorialAttemptCount = highSchool?.intOrDefault("tutorialAttemptCount", 0) ?: 0,
            isChallengeRun = highSchool?.boolOrDefault("isChallengeRun", false) ?: false,
            selectedSignatureLegacyId = highSchool?.stringOrNull("selectedSignatureLegacyId"),
            pledgeId = highSchool?.stringOrNull("pledgeId"),
        )

    private fun overlayHighSchool(
        previous: JsonValue.Obj?,
        state: HighSchoolPhase4State,
        extras: CSharpHighSchoolSnapshotWire.ReadExtras,
        coreJson: String,
    ): JsonValue.Obj {
        val run = state.run
        val next = LinkedHashMap(previous?.entries ?: linkedMapOf())
        next["careerId"] = JsonValue.Str(run.careerId)
        next["lifeNumber"] = JsonValue.Num(run.lifeNumber.toString())
        next["phase"] = JsonValue.Str(run.phase.wire)
        next["nextSeed"] = JsonValue.Str(extras.nextSeed)
        next["coreRevision"] = JsonValue.Num(run.revision.toString())
        next["playerId"] = JsonValue.Str(run.pitcher.id)
        next["playerName"] = JsonValue.Str(run.identity.name)
        next["presetId"] = JsonValue.Str(run.presetId)
        next["ratings"] = JsonValue.Obj(linkedMapOf(
            "stuff" to JsonValue.Num(run.pitcher.stuff.toString()),
            "command" to JsonValue.Num(run.pitcher.command.toString()),
            "movement" to JsonValue.Num(run.pitcher.movement.toString()),
            "stamina" to JsonValue.Num(run.pitcher.stamina.toString()),
            "total" to JsonValue.Num((run.pitcher.stuff + run.pitcher.command + run.pitcher.movement + run.pitcher.stamina).toString()),
        ))
        next["performance"] = JsonValue.Obj(linkedMapOf(
            "importantGames" to JsonValue.Num(run.performance.importantGamesCompleted.toString()),
            "pitches" to JsonValue.Num(run.performance.pitches.toString()),
            "outs" to JsonValue.Num(run.performance.outs.toString()),
            "strikeouts" to JsonValue.Num(run.performance.strikeouts.toString()),
            "walks" to JsonValue.Num(run.performance.walks.toString()),
            "hits" to JsonValue.Num(run.performance.hits.toString()),
            "runsAllowed" to JsonValue.Num(run.performance.runsAllowed.toString()),
        ))
        next["schoolId"] = run.school?.id?.let { JsonValue.Str(pascalName(it.wire)) } ?: JsonValue.Null
        next["schoolName"] = run.school?.name?.let(JsonValue::Str) ?: JsonValue.Null
        next["schoolYear"] = JsonValue.Num(run.chapter.schoolYear.toString())
        next["chapterNumber"] = JsonValue.Num(run.chapter.number.toString())
        next["remainingImportantGames"] = JsonValue.Num(CSharpHighSchoolSnapshotWire.remainingImportantGames(run).toString())
        next["remainingChapterAdvances"] = JsonValue.Num(CSharpHighSchoolSnapshotWire.remainingChapterAdvances(run).toString())
        next["coreStateJson"] = JsonValue.Str(coreJson)
        next["karmas"] = JsonValue.Arr(run.karmas.map { JsonValue.Str(it.wire) })
        next["awakenings"] = JsonValue.Arr(run.selectedAwakenings.map { JsonValue.Str(it.wire) })
        next["fatigue"] = JsonValue.Num(run.fatigue.toString())
        next["armRisk"] = JsonValue.Num(run.armRisk.toString())
        next["injuryRecovery"] = JsonValue.Num(run.injuryRecovery.toString())
        next["managerTrust"] = JsonValue.Num(run.managerTrust.toString())
        next["catcherTrust"] = JsonValue.Num(run.catcherTrust.toString())
        next["rivalTrust"] = JsonValue.Num(run.rivalTrust.toString())
        next["fanInterest"] = JsonValue.Num(run.fanInterest.toString())
        next["news"] = JsonValue.Arr(run.news.map(JsonValue::Str))
        next["tutorialCompleted"] = JsonValue.Bool(state.tutorial.completed)
        next["isChallengeRun"] = JsonValue.Bool(state.challenge.active)
        next["selectedSignatureLegacyId"] = state.selectedSignatureLegacyId?.let(JsonValue::Str) ?: JsonValue.Null
        next["pledgeId"] = extras.pledgeId?.let(JsonValue::Str) ?: JsonValue.Null
        if (run.phase != HighSchoolPhase.RELATIONSHIP) next["relationshipChoices"] = JsonValue.Arr(emptyList())
        if (run.phase != HighSchoolPhase.TRAINING) {
            next["trainingFocusChoices"] = JsonValue.Arr(emptyList())
            next["trainingIntensityChoices"] = JsonValue.Arr(emptyList())
            next["trainingPitchChoices"] = JsonValue.Arr(emptyList())
        }
        if (run.phase != HighSchoolPhase.SCHOOL_SELECTION) next["schoolChoices"] = JsonValue.Arr(emptyList())
        if (run.phase != HighSchoolPhase.AWAKENING) next["awakeningChoices"] = JsonValue.Arr(emptyList())
        run.currentRelationshipEvent?.let { event ->
            next["currentRelationshipEvent"] = JsonValue.Obj(linkedMapOf(
                "id" to JsonValue.Str(event.id),
                "title" to JsonValue.Str(event.title),
                "category" to JsonValue.Str(event.category),
                "summary" to JsonValue.Str(event.summary),
            ))
        } ?: run { next["currentRelationshipEvent"] = JsonValue.Null }
        return JsonValue.Obj(next)
    }

    private fun reservePitch(state: GameAggregateState, command: GameCommand.ReservePitch): GameAggregateState {
        require(state.pitch == null || state.pitch.boundary == PitchBoundary.COMPLETED || state.pitch.boundary == PitchBoundary.ABANDONED) { "pitch.reserve_active" }
        require(!state.deleted) { "pitch.reserve_deleted" }
        when (command.careerKind) {
            PitchCareerKind.HIGH_SCHOOL -> {
                val highSchool = state.highSchool
                require(highSchool != null && highSchool.run.careerId == command.careerId) { "pitch.reserve_highSchool_career" }
                require(highSchool.run.phase != HighSchoolPhase.COMPLETED) { "pitch.reserve_highSchool_inactive" }
            }
            PitchCareerKind.PRO -> {
                val pro = state.pro
                require(pro != null && pro.careerId == command.careerId) { "pitch.reserve_pro_career" }
                require(pro.phase != ProCareerPhase.COMPLETED) { "pitch.reserve_pro_inactive" }
            }
            PitchCareerKind.TUTORIAL -> state.requireActiveTutorialPitch(
                careerId = command.careerId,
                boundary = PitchBoundary.RESERVED,
                challengeRun = command.challengeRun,
                errorPrefix = "pitch.reserve_tutorial",
            )
        }
        return state.copy(
            pitch = PitchDurableState(command.sessionId, command.careerKind, command.careerId, command.gameId, command.seed, PitchBoundary.RESERVED, challengeRun = command.challengeRun),
        )
    }

    private fun startPitch(state: GameAggregateState, command: GameCommand.StartPitch): GameAggregateState {
        val pitch = requirePitch(state, command.sessionId)
        require(pitch.boundary == PitchBoundary.RESERVED) { "pitch.start_boundary" }
        return state.copy(pitch = pitch.copy(boundary = PitchBoundary.PLAYING))
    }

    private fun commitPitch(state: GameAggregateState, command: GameCommand.CommitPitch): GameAggregateState {
        val pitch = requirePitch(state, command.sessionId)
        require(pitch.boundary == PitchBoundary.PLAYING) { "pitch.commit_boundary" }
        require(command.pitchId.isNotBlank() && command.resultHash.isNotBlank()) { "pitch.commit_payload" }
        require(command.pitchId !in pitch.committedPitchIds) { "pitch.commit_duplicate" }
        return state.copy(
            pitch = pitch.copy(
                boundary = PitchBoundary.COMMITTED,
                pitchIndex = pitch.pitchIndex + 1,
                committedPitchIds = pitch.committedPitchIds + command.pitchId,
                resultHashes = pitch.resultHashes + command.resultHash,
                checkpoint = command.checkpoint ?: pitch.checkpoint,
            ),
        )
    }

    private fun consumePitch(state: GameAggregateState, command: GameCommand.ConsumePitch): GameAggregateState {
        val pitch = requirePitch(state, command.sessionId)
        require(pitch.boundary == PitchBoundary.COMMITTED) { "pitch.consume_boundary" }
        require(command.pitchId in pitch.committedPitchIds && command.pitchId !in pitch.consumedPitchIds) { "pitch.consume_payload" }
        return state.copy(pitch = pitch.copy(boundary = PitchBoundary.CONSUMED, consumedPitchIds = pitch.consumedPitchIds + command.pitchId))
    }

    private fun terminalPitch(state: GameAggregateState, command: GameCommand.MarkPitchTerminal): GameAggregateState {
        val pitch = requirePitch(state, command.sessionId)
        require(pitch.boundary == PitchBoundary.CONSUMED) { "pitch.terminal_boundary" }
        require(command.pitchId in pitch.consumedPitchIds && command.terminalHash.isNotBlank()) { "pitch.terminal_payload" }
        val resultHashes = pitch.resultHashes.toMutableList()
        resultHashes[pitch.consumedPitchIds.indexOf(command.pitchId)] = command.terminalHash
        return state.copy(pitch = pitch.copy(boundary = PitchBoundary.TERMINAL, terminalPitchId = command.pitchId, resultHashes = resultHashes))
    }

    private fun completePitch(state: GameAggregateState, command: GameCommand.CompletePitch): GameAggregateState {
        val pitch = requirePitch(state, command.sessionId)
        require(pitch.boundary == PitchBoundary.TERMINAL) { "pitch.complete_boundary" }
        return state.copy(pitch = pitch.copy(boundary = PitchBoundary.COMPLETED))
    }

    private fun suspendPitch(state: GameAggregateState, command: GameCommand.SuspendPitch): GameAggregateState {
        val pitch = requirePitch(state, command.sessionId)
        require(pitch.boundary in setOf(PitchBoundary.RESERVED, PitchBoundary.PLAYING, PitchBoundary.COMMITTED, PitchBoundary.CONSUMED)) { "pitch.suspend_boundary" }
        require(command.checkpoint.isNotBlank()) { "pitch.suspend_checkpoint" }
        return state.copy(pitch = pitch.copy(boundary = PitchBoundary.SUSPENDED, checkpoint = command.checkpoint, suspendedFrom = pitch.boundary))
    }

    private fun resumePitch(state: GameAggregateState, command: GameCommand.ResumePitch): GameAggregateState {
        val pitch = requirePitch(state, command.sessionId)
        require(pitch.boundary == PitchBoundary.SUSPENDED && pitch.suspendedFrom != null) { "pitch.resume_boundary" }
        return state.copy(pitch = pitch.copy(boundary = pitch.suspendedFrom, suspendedFrom = null))
    }

    private fun abandonPitch(state: GameAggregateState, command: GameCommand.AbandonPitch): GameAggregateState {
        val pitch = requirePitch(state, command.sessionId)
        require(pitch.boundary in setOf(PitchBoundary.RESERVED, PitchBoundary.PLAYING, PitchBoundary.SUSPENDED)) { "pitch.abandon_boundary" }
        require(command.reason.isNotBlank()) { "pitch.abandon_reason" }
        return state.copy(pitch = pitch.copy(boundary = PitchBoundary.ABANDONED, abandonedReason = command.reason))
    }

    private fun clearPresentation(
        payload: JsonValue.Obj,
        state: GameAggregateState,
        command: GameCommand.ClearPitchPresentation,
    ): JsonValue.Obj {
        requirePitch(state, command.sessionId)
        val highSchool = state.highSchool
        if (highSchool?.lastPresentation != null) {
            val resigned = HighSchoolPhase4Kernel().commitShadowState(highSchool.copy(lastPresentation = null))
            val previous = payload.objectOrNull("highSchool")
            val previousSnapshot = previous?.stringOrNull("coreStateJson")?.let { raw ->
                runCatching { StrictJson.parseUtf8(raw.toByteArray()) as? JsonValue.Obj }.getOrNull()
            }
            val coreJson = CSharpHighSchoolSnapshotWire.encodeUtf8(resigned.run, previousSnapshot)
            val extras = readExtras(payload.string("installId"), previous, previous?.stringOrNull("nextSeed") ?: "0")
            return payload.withHighSchool(overlayHighSchool(previous, resigned, extras, coreJson), GameStage.entries.first { it.wire == payload.string("stage") })
        }
        return payload
    }

    private fun recordAnalytics(
        payload: JsonValue.Obj,
        state: GameAggregateState,
        command: GameCommand.RecordAnalytics,
    ): JsonValue.Obj {
        require(!state.analytics.contains(command.receiptId)) { "analytics.receipt_duplicate" }
        Phase9AnalyticsContract.validateManual(command.eventName, command.properties)
        val scope = csharpScope(command.receiptId)
        val analytics = payload.objectOrNull("analyticsReceipts") ?: JsonValue.Obj(linkedMapOf(
            "schemaVersion" to JsonValue.Num("1"),
            "records" to JsonValue.Arr(emptyList()),
        ))
        val records = (analytics["records"] as? JsonValue.Arr)?.values.orEmpty().toMutableList()
        val exists = records.any { item ->
            (item as? JsonValue.Obj)?.stringOrNull("scopeId") == scope
        }
        if (!exists) {
            records += JsonValue.Obj(linkedMapOf(
                "scopeId" to JsonValue.Str(scope),
                "recordedAtUnixSeconds" to JsonValue.Num((System.currentTimeMillis() / 1000L).toString()),
                "retention" to JsonValue.Str("lifetime"),
            ))
        }
        val next = LinkedHashMap(payload.entries)
        next["analyticsReceipts"] = JsonValue.Obj(linkedMapOf(
            "schemaVersion" to JsonValue.Num("1"),
            "records" to JsonValue.Arr(records),
        ))
        return JsonValue.Obj(next)
    }

    private fun applyPitch(payload: JsonValue.Obj, pitch: PitchDurableState?, clearResume: Boolean = false): JsonValue.Obj {
        val next = LinkedHashMap(payload.entries)
        if (pitch == null || clearResume || pitch.boundary == PitchBoundary.COMPLETED || pitch.boundary == PitchBoundary.ABANDONED) {
            next["pitchResume"] = JsonValue.Null
            next["pendingPitchCompletion"] = JsonValue.Null
        } else {
            next["pitchResume"] = writePitchResume(pitch)
            next["pendingPitchCompletion"] = JsonValue.Null
        }
        return JsonValue.Obj(next)
    }

    private fun writePitchResume(pitch: PitchDurableState): JsonValue.Obj = JsonValue.Obj(linkedMapOf(
        "gameId" to JsonValue.Str(pitch.gameId),
        "careerKind" to JsonValue.Str(pitch.careerKind.wire),
        "careerId" to JsonValue.Str(pitch.careerId),
        "scenarioId" to JsonValue.Str(pitch.gameId),
        "sessionSeed" to JsonValue.Str(pitch.seed),
        "maximumBatters" to JsonValue.Num("1"),
        "completedBatters" to JsonValue.Num("0"),
        "checkpointJson" to JsonValue.Str(encodeNativePitch(pitch)),
        "awaitingCompletion" to JsonValue.Bool(false),
    ))

    private fun projectPitch(resume: JsonValue.Obj?): PitchDurableState? {
        if (resume == null) return null
        val checkpoint = resume.stringOrNull("checkpointJson")
        if (!checkpoint.isNullOrBlank()) {
            decodeNativePitch(checkpoint)?.let { return it }
        }
        val kind = PitchCareerKind.entries.firstOrNull { it.wire == resume.stringOrNull("careerKind") } ?: return null
        return PitchDurableState(
            sessionId = resume.stringOrNull("gameId") ?: return null,
            careerKind = kind,
            careerId = resume.stringOrNull("careerId") ?: return null,
            gameId = resume.stringOrNull("gameId") ?: return null,
            seed = resume.stringOrNull("sessionSeed") ?: return null,
            boundary = PitchBoundary.PLAYING,
        )
    }

    private fun encodeNativePitch(pitch: PitchDurableState): String = StrictJson.canonical(
        JsonValue.Obj(linkedMapOf(
            "nativePitch" to JsonValue.Obj(linkedMapOf(
                "sessionId" to JsonValue.Str(pitch.sessionId),
                "careerKind" to JsonValue.Str(pitch.careerKind.wire),
                "careerId" to JsonValue.Str(pitch.careerId),
                "gameId" to JsonValue.Str(pitch.gameId),
                "seed" to JsonValue.Str(pitch.seed),
                "boundary" to JsonValue.Str(pitch.boundary.wire),
                "challengeRun" to JsonValue.Bool(pitch.challengeRun),
                "pitchIndex" to JsonValue.Num(pitch.pitchIndex.toString()),
                "committedPitchIds" to JsonValue.Arr(pitch.committedPitchIds.map(JsonValue::Str)),
                "consumedPitchIds" to JsonValue.Arr(pitch.consumedPitchIds.map(JsonValue::Str)),
                "terminalPitchId" to (pitch.terminalPitchId?.let(JsonValue::Str) ?: JsonValue.Null),
                "resultHashes" to JsonValue.Arr(pitch.resultHashes.map(JsonValue::Str)),
                "checkpoint" to (pitch.checkpoint?.let(JsonValue::Str) ?: JsonValue.Null),
                "suspendedFrom" to (pitch.suspendedFrom?.wire?.let(JsonValue::Str) ?: JsonValue.Null),
                "abandonedReason" to (pitch.abandonedReason?.let(JsonValue::Str) ?: JsonValue.Null),
            )),
        )),
    )

    private fun decodeNativePitch(raw: String): PitchDurableState? {
        val root = runCatching { StrictJson.parseUtf8(raw.toByteArray()) as? JsonValue.Obj }.getOrNull() ?: return null
        val native = root.objectOrNull("nativePitch") ?: return null
        val kind = PitchCareerKind.entries.firstOrNull { it.wire == native.stringOrNull("careerKind") } ?: return null
        val boundary = PitchBoundary.entries.firstOrNull { it.wire == native.stringOrNull("boundary") } ?: return null
        return PitchDurableState(
            sessionId = native.stringOrNull("sessionId") ?: return null,
            careerKind = kind,
            careerId = native.stringOrNull("careerId") ?: return null,
            gameId = native.stringOrNull("gameId") ?: return null,
            seed = native.stringOrNull("seed") ?: return null,
            boundary = boundary,
            challengeRun = native.boolOrDefault("challengeRun", false),
            pitchIndex = native.intOrDefault("pitchIndex", 0),
            committedPitchIds = native.stringArray("committedPitchIds"),
            consumedPitchIds = native.stringArray("consumedPitchIds"),
            terminalPitchId = native.stringOrNull("terminalPitchId"),
            resultHashes = native.stringArray("resultHashes"),
            checkpoint = native.stringOrNull("checkpoint"),
            suspendedFrom = native.stringOrNull("suspendedFrom")?.let { wire -> PitchBoundary.entries.firstOrNull { it.wire == wire } },
            abandonedReason = native.stringOrNull("abandonedReason"),
        )
    }

    private fun projectAnalytics(value: JsonValue.Obj?): AnalyticsReceiptState {
        val records = (value?.get("records") as? JsonValue.Arr)?.values.orEmpty().mapNotNull { item ->
            val record = item as? JsonValue.Obj ?: return@mapNotNull null
            val scope = record.stringOrNull("scopeId") ?: return@mapNotNull null
            AnalyticsReceipt(
                receiptId = scope.removePrefix("once:"),
                eventName = scope.removePrefix("once:"),
                revision = 1UL,
                commitment = "",
            )
        }
        return AnalyticsReceiptState(records)
    }

    private fun csharpScope(receiptId: String): String {
        val normalized = receiptId.lowercase()
        val scoped = if (normalized.startsWith("once:")) normalized else "once:$normalized"
        require(scoped.length <= 96 && scoped.matches(Regex("once:[a-z0-9:_.-]+"))) { "analytics.scope_invalid" }
        return scoped
    }

    private fun requirePitch(state: GameAggregateState, sessionId: String): PitchDurableState {
        val pitch = state.pitch ?: throw GameCommandException("pitch.missing")
        require(pitch.sessionId == sessionId) { "pitch.session_mismatch" }
        return pitch
    }

    private fun commandSeed(command: HighSchoolPhase4Command, fallback: String): String = when (command) {
        is HighSchoolPhase4Command.Start -> command.request.seed
        is HighSchoolPhase4Command.CompleteTutorial -> command.seed
        is HighSchoolPhase4Command.ChooseSchool -> command.seed
        is HighSchoolPhase4Command.Training -> command.seed
        is HighSchoolPhase4Command.TrainingBlock -> command.seed
        is HighSchoolPhase4Command.Relationship -> command.seed
        is HighSchoolPhase4Command.ReserveImportantGame -> command.seed
        is HighSchoolPhase4Command.ChooseAwakening -> command.seed
        is HighSchoolPhase4Command.AdvanceChapter -> command.seed
        is HighSchoolPhase4Command.ResolveDraft -> command.seed
        is HighSchoolPhase4Command.BeginRebirth -> command.seed
        else -> fallback
    }

    private fun commandName(command: Any): String =
        command.javaClass.simpleName.replace('$', '.').replace("Command", "").replaceFirstChar { it.lowercase() }

    private fun pascalName(wire: String): String =
        wire.split('_').joinToString("") { part -> part.replaceFirstChar { it.uppercase() } }

    private fun JsonValue.Obj.withSettings(settings: GameSettingsState): JsonValue.Obj {
        val next = LinkedHashMap(entries)
        next["settings"] = JsonValue.Obj(linkedMapOf(
            "schemaVersion" to JsonValue.Num("1"),
            "autoReleaseEnabled" to JsonValue.Bool(settings.autoReleaseEnabled),
            "soundEnabled" to JsonValue.Bool(settings.soundEnabled),
            "musicEnabled" to JsonValue.Bool(settings.musicEnabled),
            "hapticsEnabled" to JsonValue.Bool(settings.hapticsEnabled),
            "notificationsEnabled" to JsonValue.Bool(settings.notificationsEnabled),
            "highContrastEnabled" to JsonValue.Bool(settings.highContrastEnabled),
            "reducedMotionEnabled" to JsonValue.Bool(settings.reducedMotionEnabled),
        ))
        return JsonValue.Obj(next)
    }

    private fun JsonValue.Obj.withStage(stage: GameStage): JsonValue.Obj {
        val next = LinkedHashMap(entries)
        next["stage"] = JsonValue.Str(stage.wire)
        return JsonValue.Obj(next)
    }

    private fun JsonValue.Obj.withHighSchool(highSchool: JsonValue.Obj, stage: GameStage): JsonValue.Obj {
        val next = LinkedHashMap(entries)
        next["highSchool"] = highSchool
        next["stage"] = JsonValue.Str(stage.wire)
        return JsonValue.Obj(next)
    }

    private fun JsonValue.Obj.withPro(pro: JsonValue.Obj, stage: GameStage): JsonValue.Obj {
        val next = LinkedHashMap(entries)
        next["pro"] = pro
        next["stage"] = JsonValue.Str(stage.wire)
        return JsonValue.Obj(next)
    }

    private fun JsonValue.Obj.withCommandReceipt(commandId: String): JsonValue.Obj {
        val next = LinkedHashMap(entries)
        val revision = ulongOrDefault("revision", 0UL) + 1UL
        next["revision"] = JsonValue.Num(revision.toString())
        val receipts = stringArray("commandReceipts").toMutableSet()
        receipts += commandId
        next["commandReceipts"] = JsonValue.Arr(receipts.toList().sorted().map(JsonValue::Str))
        return JsonValue.Obj(next)
    }

    private fun JsonValue.Obj.toSettings(): GameSettingsState = GameSettingsState(
        autoReleaseEnabled = boolOrDefault("autoReleaseEnabled", false),
        soundEnabled = boolOrDefault("soundEnabled", true),
        musicEnabled = boolOrDefault("musicEnabled", true),
        hapticsEnabled = boolOrDefault("hapticsEnabled", true),
        notificationsEnabled = boolOrDefault("notificationsEnabled", false),
        highContrastEnabled = boolOrDefault("highContrastEnabled", false),
        reducedMotionEnabled = boolOrDefault("reducedMotionEnabled", false),
    )

    private fun JsonValue.Obj.canonicalPlaceholder(): String = "legacy"
}

internal fun JsonValue.Obj.objectOrNull(name: String): JsonValue.Obj? = this[name] as? JsonValue.Obj
internal fun JsonValue.Obj.string(name: String): String =
    (this[name] as? JsonValue.Str)?.value ?: throw IllegalStateException("game.store.${name}_missing")
internal fun JsonValue.Obj.stringOrNull(name: String): String? = when (val value = this[name]) {
    null, JsonValue.Null -> null
    is JsonValue.Str -> value.value
    else -> null
}
internal fun JsonValue.Obj.intOrDefault(name: String, default: Int): Int =
    (this[name] as? JsonValue.Num)?.raw?.toIntOrNull() ?: default
internal fun JsonValue.Obj.ulongOrDefault(name: String, default: ULong): ULong =
    when (val value = this[name]) {
        is JsonValue.Num -> value.raw.toULongOrNull() ?: default
        is JsonValue.Str -> value.value.toULongOrNull() ?: default
        else -> default
    }
internal fun JsonValue.Obj.boolOrDefault(name: String, default: Boolean): Boolean =
    (this[name] as? JsonValue.Bool)?.value ?: default
internal fun JsonValue.Obj.stringArray(name: String): List<String> =
    (this[name] as? JsonValue.Arr)?.values?.mapNotNull { (it as? JsonValue.Str)?.value } ?: emptyList()
