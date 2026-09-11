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
import com.solkim.baseball.core.highschool.HighSchoolPhase4StateCodec
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
    public const val NATIVE_HIGH_SCHOOL_FIELD: String = "nativePhase4State"
    public data class ApplyResult(
        val payload: JsonValue.Obj,
        val eventName: String,
    )

    public fun project(payload: JsonValue.Obj, envelopeRevision: ULong, payloadSha256: String): GameAggregateState {
        val highSchool = tryHydrateHighSchool(payload)
        val pro = CSharpLegacyProBridge.project(payload.objectOrNull("pro"))
        val completedPitch = when (val field = payload.objectOrNull("meta")?.get("nativeTerminalPitch")) {
            null, JsonValue.Null -> null
            is JsonValue.Obj -> GameAggregateCodec.decodePitch(field).let { decoded ->
                decoded.copy(checkpoint = CareerWire.migrateCheckpoint(decoded.checkpoint)).also {
                    it.validate()
                    require(it.boundary in setOf(PitchBoundary.COMPLETED, PitchBoundary.ABANDONED)) { "native.terminal_pitch_boundary" }
                }
            }
            else -> throw GameCommandException("native.terminal_pitch_shape")
        }
        val activePitch = CSharpLegacyPitch.projectPitch(payload.objectOrNull("pitchResume"))
        require(activePitch == null || completedPitch == null) { "native.pitch_owner_conflict" }
        val pitch = activePitch ?: completedPitch
        val savedStage = GameStage.entries.firstOrNull { it.wire == payload.string("stage") }
            ?: throw GameCommandException("game.store.stage_unknown")
        // Older return-plan commands could demote a linked professional to the archived school stage.
        val stage = if (savedStage == GameStage.HIGH_SCHOOL && highSchool?.run?.phase == HighSchoolPhase.COMPLETED &&
            pro != null && pro.phase != ProCareerPhase.COMPLETED && pro.sourceHighSchoolCareerId == highSchool.run.careerId && highSchool.challenge.active == false) {
            when (pro.phase) { ProCareerPhase.RETIREMENT_DECISION -> GameStage.RETIREMENT; ProCareerPhase.LEGACY_SELECTION -> GameStage.LEGACY; else -> GameStage.PRO }
        } else savedStage
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
                retiredProCareers = ProRetirementCodec.decode(payload.objectOrNull("meta")?.get("retiredProCareers")),
                standaloneSoulBalance = ProRetirementCodec.balance(payload.objectOrNull("meta")?.get("standaloneSoulBalance")),
                seedChallenge = SeedChallengeCodec.decode(payload.objectOrNull("meta")?.get("seedChallenge"))?.let { session ->
                    val migrated = session.returnPitch?.copy(checkpoint = CareerWire.migrateCheckpoint(session.returnPitch.checkpoint))
                    if (migrated == session.returnPitch) session else session.copy(returnPitch = migrated)
                },
                playerGrowth = PlayerGrowthReceipt.decode(payload.objectOrNull("meta")?.get("playerGrowth")),
                abilityHistory = AbilityHistory.decode(payload.objectOrNull("meta")?.get("abilityHistory")),
                companion = PitcherCompanionCodec.decode(payload.objectOrNull("meta")?.get("companion")),
                album = PlayerAlbumCodec.decode(payload.objectOrNull("meta")?.get("album")),
            ),
            pitch = pitch,
            settings = payload.objectOrNull("settings")?.toSettings() ?: GameSettingsState(),
            analytics = CSharpLegacyPitch.projectAnalytics(payload.objectOrNull("analyticsReceipts")),
            deleted = payload.boolOrDefault("deleted", false),
            commitment = payloadSha256,
        )
    }

    public fun apply(payload: JsonValue.Obj, envelope: GameCommandEnvelope): ApplyResult {
        val projected = project(payload, payload.ulongOrDefault("revision", 0UL), payload.canonicalPlaceholder())
        val eventName: String
        val next = when (val command = envelope.command) {
            is GameCommand.UpdateCompanion -> {
                eventName = "companion.updated"
                val companion = PitcherCompanionRules.apply(projected, command.operation, command.value)
                val meta = LinkedHashMap((payload["meta"] as JsonValue.Obj).entries).apply { put("companion", PitcherCompanionCodec.encode(companion)) }
                JsonValue.Obj(LinkedHashMap(payload.entries).apply { put("meta", JsonValue.Obj(meta)) })
            }
            is GameCommand.UpdateSettings -> {
                eventName = "settings.updated"
                payload.withSettings(command.settings)
            }
            GameCommand.EnterSetup -> {
                val settled = ProRetirementLedger.settle(projected)
                require(settled.canEnterPlayerSetup()) { "setup.active_career" }
                eventName = "setup.opened"
                withRetirementState(payload, settled).withStage(GameStage.SETUP)
            }
            GameCommand.ResetProgress -> throw GameCommandException("reset.native_only")
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
                val reduced = PitchCommands.reserve(projected, command)
                eventName = reduced.eventName
                CSharpLegacyPitch.applyPitch(payload, reduced.state.pitch)
            }
            is GameCommand.StartPitch -> {
                val reduced = PitchCommands.start(projected, command)
                eventName = reduced.eventName
                CSharpLegacyPitch.applyPitch(payload, reduced.state.pitch)
            }
            is GameCommand.CommitPitch -> {
                val reduced = PitchCommands.commit(projected, command)
                eventName = reduced.eventName
                CSharpLegacyPitch.applyPitch(payload, reduced.state.pitch)
            }
            is GameCommand.ConsumePitch -> {
                val reduced = PitchCommands.consume(projected, command)
                eventName = reduced.eventName
                CSharpLegacyPitch.applyPitch(payload, reduced.state.pitch)
            }
            is GameCommand.MarkPitchTerminal -> {
                val reduced = PitchCommands.terminal(projected, command)
                eventName = reduced.eventName
                CSharpLegacyPitch.applyPitch(payload, reduced.state.pitch)
            }
            is GameCommand.CompletePitch -> {
                val reduced = PitchCommands.complete(projected, command)
                eventName = reduced.eventName
                withRetirementState(CSharpLegacyPitch.applyPitch(payload, reduced.state.pitch, clearResume = true), reduced.state)
            }
            is GameCommand.SuspendPitch -> {
                val reduced = PitchCommands.suspend(projected, command)
                eventName = reduced.eventName
                CSharpLegacyPitch.applyPitch(payload, reduced.state.pitch)
            }
            is GameCommand.ResumePitch -> {
                val reduced = PitchCommands.resume(projected, command)
                eventName = reduced.eventName
                CSharpLegacyPitch.applyPitch(payload, reduced.state.pitch)
            }
            is GameCommand.AbandonPitch -> {
                val reduced = PitchCommands.abandon(projected, command)
                eventName = reduced.eventName
                CSharpLegacyPitch.applyPitch(payload, reduced.state.pitch, clearResume = true)
            }
            is GameCommand.ClearPitchPresentation -> {
                val reduced = PitchCommands.clearPresentation(projected, command)
                eventName = reduced.eventName
                CSharpLegacyPitch.writeClearedPresentation(payload, projected, reduced.state, command)
            }
            is GameCommand.SetPitchHoldCall -> {
                val reduced = PitchCommands.holdCall(projected, command)
                eventName = reduced.eventName
                CSharpLegacyPitch.applyPitch(payload, reduced.state.pitch)
            }
            is GameCommand.RecordAnalytics -> {
                eventName = "analytics.recorded"
                CSharpLegacyPitch.recordAnalytics(payload, projected, command)
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
        if (command == HighSchoolPhase4Command.ClaimWeeklyReward) WeeklyNotePolicy.requireClaimable(projected)
        val base = ProRetirementLedger.settle(projected)
        val existing = if (command is HighSchoolPhase4Command.StartSeedChallenge) SeedChallengeRules.checkpoint(base, command) else base.highSchool
        val isStart = ProRetirementLedger.isHighSchoolStart(command)
        if (existing == null && !isStart) throw GameCommandException("game.highSchool.start_required")
        if (existing != null && isStart) throw GameCommandException("game.highSchool.start_duplicate")
        val nested = try {
            HighSchoolPhase4CommandStore(initialState = existing).dispatch(
                HighSchoolPhase4CommandEnvelope(
                    commandId = envelope.commandId,
                    sessionId = envelope.sessionId,
                    expectedRevision = existing?.revision ?: 0UL,
                    command = ProRetirementLedger.prepareInitialCommand(base, command),
                ),
            )
        } catch (error: HighSchoolPhase4CommandException) {
            throw GameCommandException(error.message ?: "game.highSchool.rejected")
        }
        val next = if (isStart) ProRetirementLedger.attachInitialWallet(nested.state, base.meta.standaloneSoulBalance) else nested.state
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
            base.pro != null && base.stage in setOf(GameStage.PRO, GameStage.RETIREMENT, GameStage.LEGACY) &&
                (command is HighSchoolPhase4Command.PrepareReturnPlan || command is HighSchoolPhase4Command.SaveReturnPlan || command == HighSchoolPhase4Command.DismissReturnPlan) -> base.stage
            next.run.phase == HighSchoolPhase.COMPLETED && (base.pro == null || base.pro.phase == ProCareerPhase.COMPLETED) -> GameStage.BETWEEN_LIVES
            else -> GameStage.HIGH_SCHOOL
        }
        val updated = base.copy(highSchool = next, stage = stage,
            meta = base.meta.copy(completedGameCount = GameCompletionRules.afterHighSchool(base, next), standaloneSoulBalance = if (isStart) 0 else base.meta.standaloneSoulBalance))
        val result = SeedChallengeRules.finish(base, command, updated)
        val output = payload.withHighSchool(readModel.takeIf { result.highSchool != null }, result.stage)
        val pitchAdjusted = if (command is HighSchoolPhase4Command.StartSeedChallenge || command == HighSchoolPhase4Command.EndChallenge) CSharpLegacyPitch.applyPitch(output, result.pitch) else output
        return withRetirementState(pitchAdjusted, result) to "highSchool.${commandName(command)}"
    }

    private fun applyPro(
        payload: JsonValue.Obj,
        projected: GameAggregateState,
        envelope: GameCommandEnvelope,
        command: ProCommand,
    ): Pair<JsonValue.Obj, String> {
        require(projected.highSchool?.challenge?.active != true) { "challenge.pro_locked" }
        val settled = ProRetirementLedger.settle(projected)
        val isStart = command is ProCommand.StartLinked || command is ProCommand.StartDirect
        val restarting = isStart && settled.pro?.phase == ProCareerPhase.COMPLETED
        if (restarting) require(settled.pitch == null || settled.pitch.boundary in setOf(PitchBoundary.COMPLETED, PitchBoundary.ABANDONED)) { "pro.restart_active_pitch" }
        val base = if (restarting) settled.copy(pro = null, pitch = null) else settled
        val existing = base.pro
        if (existing == null && !isStart) throw GameCommandException("game.pro.start_required")
        if (existing != null && isStart) throw GameCommandException("game.pro.start_duplicate")
        if (existing == null && !restarting && payload.objectOrNull("pro") != null) {
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
        val previous = if (restarting) null else payload.objectOrNull("pro")
        val seed = previous?.stringOrNull("nextSeed") ?: next.seed
        val nextSeed = CSharpHighSchoolSnapshotWire.nextSeed(seed, next.revision)
        val readModel = CSharpLegacyProBridge.encodeReadModel(next, nextSeed, previous)
        val stage = when (next.phase) {
            ProCareerPhase.RETIREMENT_DECISION -> GameStage.RETIREMENT
            ProCareerPhase.LEGACY_SELECTION -> GameStage.LEGACY
            ProCareerPhase.COMPLETED -> GameStage.BETWEEN_LIVES
            else -> GameStage.PRO
        }
        val changed = ProRetirementLedger.settle(base.copy(pro = next, stage = stage))
        val output = payload.withPro(readModel, changed.stage)
        return withRetirementState(if (restarting) CSharpLegacyPitch.applyPitch(output, null) else output, changed) to "pro.${commandName(command)}"
    }

    private fun withRetirementState(payload: JsonValue.Obj, state: GameAggregateState): JsonValue.Obj {
        val root = LinkedHashMap(payload.entries)
        val meta = LinkedHashMap(payload.objectOrNull("meta")?.entries ?: emptyMap())
        meta["completedGameCount"] = JsonValue.Num(state.meta.completedGameCount.toString())
        if (state.meta.retiredProCareers.isNotEmpty()) meta["retiredProCareers"] = ProRetirementCodec.encode(state.meta.retiredProCareers)
        if (state.meta.standaloneSoulBalance != 0 || "standaloneSoulBalance" in meta) meta["standaloneSoulBalance"] = JsonValue.Num(state.meta.standaloneSoulBalance.toString())
        if (state.meta.seedChallenge != null) meta["seedChallenge"] = SeedChallengeCodec.encode(state.meta.seedChallenge) else meta.remove("seedChallenge")
        root["meta"] = JsonValue.Obj(meta)
        root["stage"] = JsonValue.Str(state.stage.wire)
        state.highSchool?.let { highSchool ->
            val previous = payload.objectOrNull("highSchool")
            val snapshot = previous?.stringOrNull("coreStateJson")?.let { runCatching { StrictJson.parseUtf8(it.toByteArray()) as? JsonValue.Obj }.getOrNull() }
            val core = CSharpHighSchoolSnapshotWire.encodeUtf8(highSchool.run, snapshot)
            val extras = readExtras(payload.string("installId"), previous, previous?.stringOrNull("nextSeed") ?: "0")
            root["highSchool"] = overlayHighSchool(previous, highSchool, extras, core)
        }
        return JsonValue.Obj(root)
    }

    private fun tryHydrateHighSchool(payload: JsonValue.Obj): HighSchoolPhase4State? {
        val highSchool = payload.objectOrNull("highSchool") ?: return null
        val core = highSchool.stringOrNull("coreStateJson") ?: return null
        highSchool.stringOrNull(NATIVE_HIGH_SCHOOL_FIELD)?.let { native ->
            val decoded = HighSchoolPhase4StateCodec.decode(java.util.Base64.getUrlDecoder().decode(native))
            require(highSchool.stringOrNull("nativePhase4CoreSha256") == com.solkim.baseball.model.Hashing.sha256Hex(core)) { "native.highSchool.core_binding" }
            val legacy = StrictJson.parseUtf8(core.toByteArray()) as JsonValue.Obj
            require(CSharpHighSchoolSnapshotWire.sign(decoded.run) == (legacy["StateCommitment"] as? JsonValue.Str)?.value) { "native.highSchool.snapshot_binding" }
            return decoded
        }
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

    internal fun readExtras(installId: String, highSchool: JsonValue.Obj?, nextSeed: String): CSharpHighSchoolSnapshotWire.ReadExtras =
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

    internal fun overlayHighSchool(
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
        next[NATIVE_HIGH_SCHOOL_FIELD] = JsonValue.Str(java.util.Base64.getUrlEncoder().withoutPadding().encodeToString(HighSchoolPhase4StateCodec.encode(state)))
        next["nativePhase4CoreSha256"] = JsonValue.Str(com.solkim.baseball.model.Hashing.sha256Hex(coreJson))
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

    private fun commandSeed(command: HighSchoolPhase4Command, fallback: String): String = when (command) {
        is HighSchoolPhase4Command.Start -> command.request.seed
        is HighSchoolPhase4Command.StartConfigured -> command.request.seed
        is HighSchoolPhase4Command.StartSeedChallenge -> command.seed
        is HighSchoolPhase4Command.ConfigureRebirth -> command.seed
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
}