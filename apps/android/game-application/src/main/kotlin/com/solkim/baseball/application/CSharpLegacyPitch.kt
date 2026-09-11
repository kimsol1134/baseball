package com.solkim.baseball.application

import com.solkim.baseball.core.highschool.CSharpHighSchoolSnapshotWire
import com.solkim.baseball.model.JsonValue
import com.solkim.baseball.model.StrictJson

internal object CSharpLegacyPitch {
    internal fun writeClearedPresentation(
        payload: JsonValue.Obj,
        before: GameAggregateState,
        after: GameAggregateState,
        command: GameCommand.ClearPitchPresentation,
    ): JsonValue.Obj {
        val pitch = PitchCommands.requirePitch(before, command.sessionId)
        if (pitch.careerKind == PitchCareerKind.PRO) {
            val resigned = after.pro ?: return payload
            val previous = payload.objectOrNull("pro")
            return payload.withPro(CSharpLegacyProBridge.encodeReadModel(resigned, previous?.stringOrNull("nextSeed") ?: resigned.seed, previous), after.stage)
        }
        val resigned = after.highSchool ?: return payload
        if (before.highSchool?.lastPresentation == null) return payload
        val previous = payload.objectOrNull("highSchool")
        val previousSnapshot = previous?.stringOrNull("coreStateJson")?.let { raw ->
            runCatching { StrictJson.parseUtf8(raw.toByteArray()) as? JsonValue.Obj }.getOrNull()
        }
        val coreJson = CSharpHighSchoolSnapshotWire.encodeUtf8(resigned.run, previousSnapshot)
        val extras = CSharpLegacyAggregateBridge.readExtras(payload.string("installId"), previous, previous?.stringOrNull("nextSeed") ?: "0")
        return payload.withHighSchool(CSharpLegacyAggregateBridge.overlayHighSchool(previous, resigned, extras, coreJson), GameStage.entries.first { it.wire == payload.string("stage") })
    }

    internal fun recordAnalytics(
        payload: JsonValue.Obj,
        state: GameAggregateState,
        command: GameCommand.RecordAnalytics,
    ): JsonValue.Obj {
        require(!state.analytics.contains(command.receiptId)) { "analytics.receipt_duplicate" }
        AnalyticsContract.validateManual(command.eventName, command.properties)
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

    internal fun applyPitch(payload: JsonValue.Obj, pitch: PitchDurableState?, clearResume: Boolean = false): JsonValue.Obj {
        val next = LinkedHashMap(payload.entries)
        // C# resume state must be cleared after completion, while Compose needs the
        // durable result to route the tutorial and continue the same multi-pitch game.
        val meta = LinkedHashMap(payload.objectOrNull("meta")?.entries ?: emptyMap())
        val terminal = pitch?.takeIf {
            it.boundary in setOf(PitchBoundary.COMPLETED, PitchBoundary.ABANDONED)
        }?.let(GameAggregateCodec::encodePitch)
        if (terminal != null) meta["nativeTerminalPitch"] = terminal else meta.remove("nativeTerminalPitch")
        next["meta"] = JsonValue.Obj(meta)
        if (pitch == null || clearResume || pitch.boundary == PitchBoundary.COMPLETED || pitch.boundary == PitchBoundary.ABANDONED) {
            next["pitchResume"] = JsonValue.Null
            next["pendingPitchCompletion"] = JsonValue.Null
        } else {
            next["pitchResume"] = writePitchResume(pitch)
            next["pendingPitchCompletion"] = JsonValue.Null
        }
        return JsonValue.Obj(next)
    }

    internal fun writePitchResume(pitch: PitchDurableState): JsonValue.Obj = JsonValue.Obj(linkedMapOf(
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

    internal fun projectPitch(resume: JsonValue.Obj?): PitchDurableState? {
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

    internal fun encodeNativePitch(pitch: PitchDurableState): String = StrictJson.canonical(
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

    internal fun decodeNativePitch(raw: String): PitchDurableState? {
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
            checkpoint = CareerWire.migrateCheckpoint(native.stringOrNull("checkpoint")),
            suspendedFrom = native.stringOrNull("suspendedFrom")?.let { wire -> PitchBoundary.entries.firstOrNull { it.wire == wire } },
            abandonedReason = native.stringOrNull("abandonedReason"),
        )
    }

    internal fun projectAnalytics(value: JsonValue.Obj?): AnalyticsReceiptState {
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

    internal fun csharpScope(receiptId: String): String {
        val normalized = receiptId.lowercase()
        val scoped = if (normalized.startsWith("once:")) normalized else "once:$normalized"
        require(scoped.length <= 96 && scoped.matches(Regex("once:[a-z0-9:_.-]+"))) { "analytics.scope_invalid" }
        return scoped
    }
}
