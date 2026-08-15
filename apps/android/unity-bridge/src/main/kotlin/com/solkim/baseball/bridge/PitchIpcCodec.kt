package com.solkim.baseball.bridge

import com.solkim.baseball.model.Hashing
import com.solkim.baseball.model.ImpactKind
import com.solkim.baseball.model.JsonValue
import com.solkim.baseball.model.PitchAcknowledgementKind
import com.solkim.baseball.model.PitchCommandKind
import com.solkim.baseball.model.PitchIpcAcknowledgement
import com.solkim.baseball.model.PitchIpcCommand
import com.solkim.baseball.model.PitchIpcContract
import com.solkim.baseball.model.PitchPresentationRequest
import com.solkim.baseball.model.PitchTerminalResult
import com.solkim.baseball.model.PitchType
import com.solkim.baseball.model.PresentationMarker
import com.solkim.baseball.model.PresentationTerminalStatus
import com.solkim.baseball.model.PresentationVisual
import com.solkim.baseball.model.QualityTier
import com.solkim.baseball.model.StrictJson
import com.solkim.baseball.model.TrailKind
import com.solkim.baseball.model.TrajectoryPoint
import com.solkim.baseball.model.IpcValidationException

/** Strict JSON codec for the native/Unity boundary. Unknown bridge fields fail closed. */
public object PitchIpcCodec {
    public fun encodeCommand(command: PitchIpcCommand): String {
        command.validate()
        command.request?.let(::verifyRequestHash)
        return StrictJson.compact(commandValue(command))
    }

    public fun decodeCommand(json: String): PitchIpcCommand = decodeCommand(json.toByteArray(Charsets.UTF_8))

    public fun decodeCommand(bytes: ByteArray): PitchIpcCommand {
        requireSize(bytes)
        val root = StrictJson.parseUtf8(bytes).asObject()
        root.requireOnly(
            "schema", "schemaVersion", "messageId", "sessionId", "presentationSeed",
            "command", "request", "qualityTier", "reason",
        )
        val command = PitchIpcCommand(
            schema = root.requiredString("schema"),
            schemaVersion = root.requiredInt("schemaVersion"),
            messageId = root.requiredString("messageId"),
            sessionId = root.requiredString("sessionId"),
            presentationSeed = root.requiredString("presentationSeed"),
            command = PitchCommandKind.fromWire(root.requiredString("command")),
            request = root.optionalObject("request")?.let(::requestFromValue),
            qualityTier = root.optionalString("qualityTier")?.let(QualityTier::fromWire),
            reason = root.optionalString("reason"),
        )
        command.validate()
        command.request?.let(::verifyRequestHash)
        return command
    }

    public fun encodeAcknowledgement(acknowledgement: PitchIpcAcknowledgement): String {
        acknowledgement.validate()
        return StrictJson.compact(acknowledgementValue(acknowledgement))
    }

    public fun decodeAcknowledgement(json: String): PitchIpcAcknowledgement =
        decodeAcknowledgement(json.toByteArray(Charsets.UTF_8))

    public fun decodeAcknowledgement(bytes: ByteArray): PitchIpcAcknowledgement {
        requireSize(bytes)
        val root = StrictJson.parseUtf8(bytes).asObject()
        root.requireOnly(
            "schema", "schemaVersion", "messageId", "sessionId", "presentationSeed",
            "acknowledgement", "pitchId", "requestSha256", "marker", "terminal", "errorCode",
        )
        val pitchId = root.optionalString("pitchId")
        val requestSha = root.optionalString("requestSha256")
        val terminalValue = root.optionalObject("terminal")
        val terminal = terminalValue?.let {
            it.requireOnly("status", "pitchId", "requestSha256", "errorCode")
            PitchTerminalResult(
                status = PresentationTerminalStatus.fromWire(it.requiredString("status")),
                pitchId = it.requiredString("pitchId"),
                requestSha256 = it.requiredString("requestSha256"),
                errorCode = it.optionalString("errorCode"),
            )
        }
        return PitchIpcAcknowledgement(
            schema = root.requiredString("schema"),
            schemaVersion = root.requiredInt("schemaVersion"),
            messageId = root.requiredString("messageId"),
            sessionId = root.requiredString("sessionId"),
            presentationSeed = root.requiredString("presentationSeed"),
            acknowledgement = PitchAcknowledgementKind.fromWire(root.requiredString("acknowledgement")),
            pitchId = pitchId,
            requestSha256 = requestSha,
            marker = root.optionalString("marker")?.let(PresentationMarker::fromWire),
            terminal = terminal,
            errorCode = root.optionalString("errorCode"),
        ).also(PitchIpcAcknowledgement::validate)
    }

    public fun createRequest(
        requestId: String,
        pitchId: String,
        sequence: Int,
        pitchType: PitchType,
        flightDurationMs: Int,
        plateXMm: Int,
        plateYMm: Int,
        velocityDeciKph: Int,
        trajectory: List<TrajectoryPoint>,
        presentationSeed: String,
        visual: PresentationVisual,
    ): PitchPresentationRequest {
        val unsigned = PitchPresentationRequest(
            requestId = requestId,
            pitchId = pitchId,
            sequence = sequence,
            pitchType = pitchType,
            flightDurationMs = flightDurationMs,
            plateXMm = plateXMm,
            plateYMm = plateYMm,
            velocityDeciKph = velocityDeciKph,
            trajectory = trajectory,
            presentationSeed = presentationSeed,
            visual = visual,
            requestSha256 = "0".repeat(64),
        )
        val hash = Hashing.sha256Hex(StrictJson.canonical(requestValue(unsigned, includeHash = false)))
        return unsigned.copy(requestSha256 = hash).also { it.validate() }
    }

    private fun commandValue(command: PitchIpcCommand): JsonValue.Obj {
        val entries = linkedMapOf<String, JsonValue>(
            "schema" to JsonValue.Str(command.schema),
            "schemaVersion" to JsonValue.Num(command.schemaVersion.toString()),
            "messageId" to JsonValue.Str(command.messageId),
            "sessionId" to JsonValue.Str(command.sessionId),
            "presentationSeed" to JsonValue.Str(command.presentationSeed),
            "command" to JsonValue.Str(command.command.wire),
        )
        command.request?.let { entries["request"] = requestValue(it, includeHash = true) }
        command.qualityTier?.let { entries["qualityTier"] = JsonValue.Str(it.wire) }
        command.reason?.let { entries["reason"] = JsonValue.Str(it) }
        return JsonValue.Obj(entries)
    }

    private fun acknowledgementValue(acknowledgement: PitchIpcAcknowledgement): JsonValue.Obj {
        val entries = linkedMapOf<String, JsonValue>(
            "schema" to JsonValue.Str(acknowledgement.schema),
            "schemaVersion" to JsonValue.Num(acknowledgement.schemaVersion.toString()),
            "messageId" to JsonValue.Str(acknowledgement.messageId),
            "sessionId" to JsonValue.Str(acknowledgement.sessionId),
            "presentationSeed" to JsonValue.Str(acknowledgement.presentationSeed),
            "acknowledgement" to JsonValue.Str(acknowledgement.acknowledgement.wire),
        )
        acknowledgement.pitchId?.let { entries["pitchId"] = JsonValue.Str(it) }
        acknowledgement.requestSha256?.let { entries["requestSha256"] = JsonValue.Str(it) }
        acknowledgement.marker?.let { entries["marker"] = JsonValue.Str(it.wire) }
        acknowledgement.terminal?.let { terminal ->
            val terminalEntries = linkedMapOf<String, JsonValue>(
                "status" to JsonValue.Str(terminal.status.wire),
                "pitchId" to JsonValue.Str(terminal.pitchId),
                "requestSha256" to JsonValue.Str(terminal.requestSha256),
            )
            terminal.errorCode?.let { terminalEntries["errorCode"] = JsonValue.Str(it) }
            entries["terminal"] = JsonValue.Obj(terminalEntries)
        }
        acknowledgement.errorCode?.let { entries["errorCode"] = JsonValue.Str(it) }
        return JsonValue.Obj(entries)
    }

    private fun requestValue(request: PitchPresentationRequest, includeHash: Boolean): JsonValue.Obj {
        val entries = linkedMapOf<String, JsonValue>(
            "requestId" to JsonValue.Str(request.requestId),
            "pitchId" to JsonValue.Str(request.pitchId),
            "sequence" to JsonValue.Num(request.sequence.toString()),
            "pitchType" to JsonValue.Str(request.pitchType.wire),
            "flightDurationMs" to JsonValue.Num(request.flightDurationMs.toString()),
            "plateXMm" to JsonValue.Num(request.plateXMm.toString()),
            "plateYMm" to JsonValue.Num(request.plateYMm.toString()),
            "velocityDeciKph" to JsonValue.Num(request.velocityDeciKph.toString()),
            "trajectory" to JsonValue.Arr(request.trajectory.map { point ->
                JsonValue.Obj(linkedMapOf(
                    "timePermille" to JsonValue.Num(point.timePermille.toString()),
                    "xMm" to JsonValue.Num(point.xMm.toString()),
                    "yMm" to JsonValue.Num(point.yMm.toString()),
                    "zMm" to JsonValue.Num(point.zMm.toString()),
                ))
            }),
            "presentationSeed" to JsonValue.Str(request.presentationSeed),
            "visual" to JsonValue.Obj(linkedMapOf(
                "trailKind" to JsonValue.Str(request.visual.trailKind.wire),
                "impactKind" to JsonValue.Str(request.visual.impactKind.wire),
                "reducedMotion" to JsonValue.Bool(request.visual.reducedMotion),
                "qualityTier" to JsonValue.Str(request.visual.qualityTier.wire),
            )),
        )
        if (includeHash) entries["requestSha256"] = JsonValue.Str(request.requestSha256)
        return JsonValue.Obj(entries)
    }

    private fun requestFromValue(value: JsonValue.Obj): PitchPresentationRequest {
        value.requireOnly(
            "requestId", "pitchId", "sequence", "pitchType", "flightDurationMs", "plateXMm",
            "plateYMm", "velocityDeciKph", "trajectory", "presentationSeed", "visual", "requestSha256",
        )
        val visual = value.requiredObject("visual").also {
            it.requireOnly("trailKind", "impactKind", "reducedMotion", "qualityTier")
        }
        val trajectory = value.requiredArray("trajectory").values.map { raw ->
            raw.asObject().also {
                it.requireOnly("timePermille", "xMm", "yMm", "zMm")
            }.let {
                TrajectoryPoint(
                    timePermille = it.requiredInt("timePermille"),
                    xMm = it.requiredInt("xMm"),
                    yMm = it.requiredInt("yMm"),
                    zMm = it.requiredInt("zMm"),
                )
            }
        }
        return PitchPresentationRequest(
            requestId = value.requiredString("requestId"),
            pitchId = value.requiredString("pitchId"),
            sequence = value.requiredInt("sequence"),
            pitchType = PitchType.fromWire(value.requiredString("pitchType")),
            flightDurationMs = value.requiredInt("flightDurationMs"),
            plateXMm = value.requiredInt("plateXMm"),
            plateYMm = value.requiredInt("plateYMm"),
            velocityDeciKph = value.requiredInt("velocityDeciKph"),
            trajectory = trajectory,
            presentationSeed = value.requiredString("presentationSeed"),
            visual = PresentationVisual(
                trailKind = TrailKind.fromWire(visual.requiredString("trailKind")),
                impactKind = ImpactKind.fromWire(visual.requiredString("impactKind")),
                reducedMotion = visual.requiredBoolean("reducedMotion"),
                qualityTier = QualityTier.fromWire(visual.requiredString("qualityTier")),
            ),
            requestSha256 = value.requiredString("requestSha256"),
        ).also(PitchPresentationRequest::validate)
    }

    private fun verifyRequestHash(request: PitchPresentationRequest) {
        request.validate()
        val expected = Hashing.sha256Hex(StrictJson.canonical(requestValue(request, includeHash = false)))
        if (expected != request.requestSha256) throw IpcValidationException("requestSha256.mismatch")
    }

    private fun requireSize(bytes: ByteArray) {
        if (bytes.size > PitchIpcContract.MAX_MESSAGE_BYTES) {
            throw IpcValidationException("message.bytes_limit")
        }
    }
}

private fun JsonValue.asObject(): JsonValue.Obj = this as? JsonValue.Obj
    ?: throw IpcValidationException("json.object_required")

private fun JsonValue.Obj.requireOnly(vararg names: String) {
    val allowed = names.toSet()
    entries.keys.firstOrNull { it !in allowed }?.let { unknown ->
        throw IpcValidationException("json.unknown_field:$unknown")
    }
}

private fun JsonValue.Obj.requiredString(name: String): String =
    (entries[name] as? JsonValue.Str)?.value
        ?: throw IpcValidationException("json.string_required:$name")

private fun JsonValue.Obj.optionalString(name: String): String? = when (val value = entries[name]) {
    null -> null
    is JsonValue.Str -> value.value
    else -> throw IpcValidationException("json.string_optional:$name")
}

private fun JsonValue.Obj.requiredInt(name: String): Int {
    val raw = (entries[name] as? JsonValue.Num)?.raw
        ?: throw IpcValidationException("json.integer_required:$name")
    if (!Regex("-?(0|[1-9][0-9]*)").matches(raw)) {
        throw IpcValidationException("json.integer_required:$name")
    }
    return raw.toLongOrNull()?.takeIf { it in Int.MIN_VALUE..Int.MAX_VALUE }?.toInt()
        ?: throw IpcValidationException("json.integer_bounds:$name")
}

private fun JsonValue.Obj.requiredBoolean(name: String): Boolean =
    (entries[name] as? JsonValue.Bool)?.value
        ?: throw IpcValidationException("json.boolean_required:$name")

private fun JsonValue.Obj.requiredObject(name: String): JsonValue.Obj =
    entries[name]?.asObject() ?: throw IpcValidationException("json.object_required:$name")

private fun JsonValue.Obj.optionalObject(name: String): JsonValue.Obj? = when (val value = entries[name]) {
    null -> null
    is JsonValue.Obj -> value
    else -> throw IpcValidationException("json.object_optional:$name")
}

private fun JsonValue.Obj.requiredArray(name: String): JsonValue.Arr =
    entries[name] as? JsonValue.Arr ?: throw IpcValidationException("json.array_required:$name")
