package com.solkim.baseball.core.highschool

import com.solkim.baseball.core.StableHash
import com.solkim.baseball.core.pitch.PitchCall
import com.solkim.baseball.core.pitch.PitchDelivery
import com.solkim.baseball.model.Hashing
import com.solkim.baseball.model.JsonValue
import com.solkim.baseball.model.StrictJson
import java.nio.ByteBuffer
import java.nio.charset.CodingErrorAction
import java.util.Base64

/** Strict envelope codec for the Phase 4 command boundary. */
public object HighSchoolPhase4CommandCodec {
    private val ROOT_FIELDS = setOf("schema", "schemaVersion", "commandId", "sessionId", "expectedRevision", "kind", "payload")

    public fun commandHash(command: HighSchoolPhase4Command): String = Hashing.sha256Hex(canonical(command))

    public fun envelopeHash(envelope: HighSchoolPhase4CommandEnvelope): String = Hashing.sha256Hex(
        listOf(envelope.schema, envelope.schemaVersion, envelope.sessionId, envelope.expectedRevision, canonical(envelope.command))
            .joinToString("|"),
    )

    public fun resultHash(state: HighSchoolPhase4State, envelope: HighSchoolPhase4CommandEnvelope): String =
        StableHash.fnv1a64("${state.stateCommitment}|${envelope.sessionId}|${envelope.expectedRevision}|${canonical(envelope.command)}")

    public fun encode(envelope: HighSchoolPhase4CommandEnvelope): ByteArray {
        envelope.validate()
        val root = JsonValue.Obj(linkedMapOf(
            "schema" to JsonValue.Str(envelope.schema),
            "schemaVersion" to JsonValue.Num(envelope.schemaVersion.toString()),
            "commandId" to JsonValue.Str(envelope.commandId),
            "sessionId" to JsonValue.Str(envelope.sessionId),
            "expectedRevision" to JsonValue.Str(envelope.expectedRevision.toString()),
            "kind" to JsonValue.Str(kind(envelope.command)),
            "payload" to JsonValue.Str(payload(envelope.command)),
        ))
        return StrictJson.canonical(root).toByteArray(Charsets.UTF_8)
    }

    /**
     * Decode is intentionally strict about the envelope. Payload decoding is provided for the
     * stable command forms used by the shadow store; an unknown/future payload is rejected rather
     * than silently defaulted.
     */
    public fun decode(bytes: ByteArray): HighSchoolPhase4CommandEnvelope {
        val root = try { StrictJson.parseUtf8(bytes) as? JsonValue.Obj ?: fail("command.root") }
        catch (error: HighSchoolPhase4CommandException) { throw error }
        catch (error: Exception) { throw HighSchoolPhase4CommandException("command.json_invalid") }
        requireExact(root, ROOT_FIELDS, "command.root")
        if (!bytes.contentEquals(StrictJson.canonical(root).toByteArray(Charsets.UTF_8))) fail("command.noncanonical")
        val schema = root.string("schema")
        if (schema != HighSchoolPhase4Wire.SCHEMA) fail("command.schema")
        val version = root.integer("schemaVersion")
        if (version != HighSchoolPhase4Wire.SCHEMA_VERSION) fail("command.future_or_old:$version")
        val commandId = root.string("commandId")
        val sessionId = root.string("sessionId")
        val expectedRevision = root.decimal("expectedRevision")
        val kind = root.string("kind")
        val payload = root.string("payload")
        val command = decodeCommand(kind, payload)
        val envelope = HighSchoolPhase4CommandEnvelope(schema, version, commandId, sessionId, expectedRevision, command)
        try {
            envelope.validate()
        } catch (error: IllegalArgumentException) {
            fail("command.envelope_invalid:${error.message ?: "unknown"}")
        }
        return envelope
    }

    private fun decodeCommand(kind: String, payload: String): HighSchoolPhase4Command = when (kind) {
        "start" -> {
            val values = unpack(payload, 29)
            HighSchoolPhase4Command.Start(
                HighSchoolPhase4StartRequest(
                    seed = values[0], presetId = values[1], stableUserId = values[2], weekKey = values[3], dayKey = values[4],
                    lifeNumber = values[5].toIntStrict("start.lifeNumber"),
                    creationAllocation = HighSchoolAllocation(values[6].toIntStrict("start.stuff"), values[7].toIntStrict("start.command"), values[8].toIntStrict("start.movement"), values[9].toIntStrict("start.stamina")),
                    inheritedSoulPoints = values[10].toIntStrict("start.inheritedSoulPoints"),
                    inheritedSoulDomain = values[11].ifEmpty { null }?.let { enumByWire(HighSchoolSoulDomain.entries, it, "start.domain") { value -> value.wire } },
                    inheritedMemories = csv(values[12]), inheritedSignatureLegacyId = values[13].ifEmpty { null },
                    inheritedLineageMasteries = lineageMasteries(values[25]),
                    lineageLoadout = lineageLoadout(values[24]),
                    inheritanceRulesVersion = values[26].ifEmpty { null }?.toIntStrict("start.inheritanceRulesVersion"),
                    inheritedNextRunIntent = nextRunIntent(values[27]),
                    inheritedSoulTotal = values[28].ifEmpty { null }?.toIntStrict("start.inheritedSoulTotal"),
                    identity = HighSchoolIdentity(values[14], values[15], values[16], values[17]),
                    difficulty = HighSchoolDifficulty(values[18], values[19], values[20], values[21]),
                    karmas = csv(values[22]).map { enumByWire(HighSchoolKarma.entries, it, "start.karma") { value -> value.wire } },
                    soulBoosts = csv(values[23]).map { enumByWire(HighSchoolSoulBoost.entries, it, "start.soulBoost") { value -> value.wire } },
                ),
            )
        }
        "beginTutorial" -> exactPayload(kind, payload, "beginTutorial") { HighSchoolPhase4Command.BeginTutorial }
        "completeTutorial" -> HighSchoolPhase4Command.CompleteTutorial(unpack(payload, 1).single())
        "chooseSchool" -> unpack(payload, 2).let { values -> HighSchoolPhase4Command.ChooseSchool(values[0], enumByWire(HighSchoolSchoolId.entries, values[1], "school.id") { value -> value.wire }) }
        "selectPledge" -> HighSchoolPhase4Command.SelectPledge(unpack(payload, 1).single())
        "training" -> unpackOneOf(payload, 3, 4).let { values ->
            HighSchoolPhase4Command.Training(
                values[0],
                enumByWire(HighSchoolTrainingFocus.entries, values[1], "training.focus") { value -> value.wire },
                enumByWire(HighSchoolTrainingIntensity.entries, values[2], "training.intensity") { value -> value.wire },
                values.getOrNull(3)?.ifEmpty { null }?.let { wire -> enumByWire(com.solkim.baseball.core.pitch.PitchKind.entries, wire, "training.targetPitch") { value -> value.wire } },
            )
        }
        "trainingBlock" -> unpack(payload, 2).let { values ->
            HighSchoolPhase4Command.TrainingBlock(values[0], values[1].split(';').filter { it.isNotEmpty() }.map { pair ->
                val parts = pair.split(',')
                if (parts.size != 2) fail("trainingBlock.pair")
                enumByWire(HighSchoolTrainingFocus.entries, parts[0], "trainingBlock.focus") { value -> value.wire } to
                    enumByWire(HighSchoolTrainingIntensity.entries, parts[1], "trainingBlock.intensity") { value -> value.wire }
            })
        }
        "relationship" -> unpack(payload, 2).let { values -> HighSchoolPhase4Command.Relationship(values[0], enumByWire(HighSchoolRelationshipResponse.entries, values[1], "relationship.response") { value -> value.wire }) }
        "reserveImportantGame" -> HighSchoolPhase4Command.ReserveImportantGame(unpack(payload, 1).single())
        "submitPitch" -> unpack(payload, 8).let { values ->
            HighSchoolPhase4Command.SubmitPitch(
                sessionId = values[0],
                call = PitchCall(
                    enumByWire(com.solkim.baseball.core.pitch.PitchKind.entries, values[1], "pitch.type") { value -> value.wire },
                    com.solkim.baseball.core.pitch.PitchZone(values[2].toIntStrict("pitch.row"), values[3].toIntStrict("pitch.column")),
                    enumByWire(com.solkim.baseball.core.pitch.ZoneIntent.entries, values[4], "pitch.intent") { value -> value.wire },
                    enumByWire(com.solkim.baseball.core.pitch.PitchIntensity.entries, values[5], "pitch.intensity") { value -> value.wire },
                ),
                delivery = PitchDelivery(values[6].toIntStrict("pitch.release"), values[7].toIntStrict("pitch.aim")),
            )
        }
        "finishImportantGame" -> exactPayload(kind, payload, "finishImportantGame") { HighSchoolPhase4Command.FinishImportantGame }
        "chooseAwakening" -> unpack(payload, 2).let { values -> HighSchoolPhase4Command.ChooseAwakening(values[0], enumByWire(HighSchoolAwakening.entries, values[1], "awakening.id") { value -> value.wire }) }
        "advanceChapter" -> HighSchoolPhase4Command.AdvanceChapter(unpack(payload, 1).single())
        "resolveDraft" -> HighSchoolPhase4Command.ResolveDraft(unpack(payload, 1).single())
        "prepareLegacy" -> exactPayload(kind, payload, "prepareLegacy") { HighSchoolPhase4Command.PrepareLegacy }
        "selectLegacy" -> HighSchoolPhase4Command.SelectLegacy(unpack(payload, 1).single())
        "finalizeArchive" -> exactPayload(kind, payload, "finalizeArchive") { HighSchoolPhase4Command.FinalizeArchive }
        "beginRebirth" -> unpackOneOf(payload, 2, 3).let { values ->
            HighSchoolPhase4Command.BeginRebirth(
                values[0], values[1], values.getOrNull(2) ?: HighSchoolRebirthEntryPath.COMPLETION_FLOW,
            )
        }
        "startChallenge" -> exactPayload(kind, payload, "startChallenge") { HighSchoolPhase4Command.StartChallenge }
        "endChallenge" -> exactPayload(kind, payload, "endChallenge") { HighSchoolPhase4Command.EndChallenge }
        "claimWeeklyReward" -> exactPayload(kind, payload, "claimWeeklyReward") { HighSchoolPhase4Command.ClaimWeeklyReward }
        "saveReturnPlan" -> unpackOneOf(payload, 5, 12).let { values ->
            val destination = enumByWire(HighSchoolReturnDestination.entries, values[0], "return.destination") { value -> value.wire }
            val legacy = HighSchoolReturnPlan(destination, values[1], values[2], values[3], values[4].toBooleanStrictOrFail("return.dismissed"))
            if (values.size == 5) HighSchoolPhase4Command.SaveReturnPlan(legacy) else
                HighSchoolPhase4Command.SaveReturnPlan(legacy.copy(
                    route = values[5], title = values[6], body = values[7], experimentId = values[8].ifEmpty { null },
                    savedDayKey = values[9].ifEmpty { null }, experimentVariant = values[10].ifEmpty { null },
                    developmentRulesVersion = values[11].ifEmpty { null }?.toIntStrict("return.rulesVersion"),
                ))
        }
        "prepareReturnPlan" -> unpack(payload, 2).let { values ->
            HighSchoolPhase4Command.PrepareReturnPlan(values[0], values[1].toIntStrict("return.rulesVersion"))
        }
        "saveNextRunIntent" -> unpack(payload, 3).let { values -> HighSchoolPhase4Command.SaveNextRunIntent(HighSchoolNextRunIntent(values[0], values[1].toIntStrict("nextIntent.sourceLifeNumber"), values[2])) }
        "clearNextRunIntent" -> exactPayload(kind, payload, "clearNextRunIntent") { HighSchoolPhase4Command.ClearNextRunIntent }
        "dismissReturnPlan" -> exactPayload(kind, payload, "dismissReturnPlan") { HighSchoolPhase4Command.DismissReturnPlan }
        "acknowledgeAchievement" -> HighSchoolPhase4Command.AcknowledgeAchievement(unpack(payload, 1).single())
        else -> fail("command.payload_unsupported:$kind")
    }

    private fun <T> exactPayload(kind: String, payload: String, expected: String, make: () -> T): T {
        if (payload != expected) fail("command.payload_invalid:$kind")
        return make()
    }

    private fun kind(command: HighSchoolPhase4Command): String = when (command) {
        is HighSchoolPhase4Command.Start -> "start"
        HighSchoolPhase4Command.BeginTutorial -> "beginTutorial"
        is HighSchoolPhase4Command.CompleteTutorial -> "completeTutorial"
        is HighSchoolPhase4Command.ChooseSchool -> "chooseSchool"
        is HighSchoolPhase4Command.SelectPledge -> "selectPledge"
        is HighSchoolPhase4Command.Training -> "training"
        is HighSchoolPhase4Command.TrainingBlock -> "trainingBlock"
        is HighSchoolPhase4Command.Relationship -> "relationship"
        is HighSchoolPhase4Command.ReserveImportantGame -> "reserveImportantGame"
        is HighSchoolPhase4Command.SubmitPitch -> "submitPitch"
        HighSchoolPhase4Command.FinishImportantGame -> "finishImportantGame"
        is HighSchoolPhase4Command.ChooseAwakening -> "chooseAwakening"
        is HighSchoolPhase4Command.AdvanceChapter -> "advanceChapter"
        is HighSchoolPhase4Command.ResolveDraft -> "resolveDraft"
        HighSchoolPhase4Command.PrepareLegacy -> "prepareLegacy"
        is HighSchoolPhase4Command.SelectLegacy -> "selectLegacy"
        HighSchoolPhase4Command.FinalizeArchive -> "finalizeArchive"
        is HighSchoolPhase4Command.BeginRebirth -> "beginRebirth"
        HighSchoolPhase4Command.StartChallenge -> "startChallenge"
        HighSchoolPhase4Command.EndChallenge -> "endChallenge"
        HighSchoolPhase4Command.ClaimWeeklyReward -> "claimWeeklyReward"
        is HighSchoolPhase4Command.SaveReturnPlan -> "saveReturnPlan"
        is HighSchoolPhase4Command.PrepareReturnPlan -> "prepareReturnPlan"
        is HighSchoolPhase4Command.SaveNextRunIntent -> "saveNextRunIntent"
        HighSchoolPhase4Command.ClearNextRunIntent -> "clearNextRunIntent"
        HighSchoolPhase4Command.DismissReturnPlan -> "dismissReturnPlan"
        is HighSchoolPhase4Command.AcknowledgeAchievement -> "acknowledgeAchievement"
    }

    private fun payload(command: HighSchoolPhase4Command): String = when (command) {
        is HighSchoolPhase4Command.Start -> pack(listOf(
            command.request.seed, command.request.presetId, command.request.stableUserId, command.request.weekKey, command.request.dayKey,
            command.request.lifeNumber.toString(), command.request.creationAllocation.stuff.toString(), command.request.creationAllocation.command.toString(),
            command.request.creationAllocation.movement.toString(), command.request.creationAllocation.stamina.toString(), command.request.inheritedSoulPoints.toString(),
            command.request.inheritedSoulDomain?.wire.orEmpty(), command.request.inheritedMemories.joinToString(","), command.request.inheritedSignatureLegacyId.orEmpty(),
            command.request.identity.name, command.request.identity.throwingHand, command.request.identity.bodyType, command.request.identity.region,
            command.request.difficulty.careerHarshness, command.request.difficulty.informationClarity, command.request.difficulty.simulationDifficulty, command.request.difficulty.interventionAssist,
            command.request.karmas.joinToString(",") { it.wire }, command.request.soulBoosts.joinToString(",") { it.wire },
            lineageLoadout(command.request.lineageLoadout), lineageMasteries(command.request.inheritedLineageMasteries),
            command.request.inheritanceRulesVersion?.toString().orEmpty(),
            nextRunIntent(command.request.inheritedNextRunIntent),
            command.request.inheritedSoulTotal?.toString().orEmpty(),
        ))
        HighSchoolPhase4Command.BeginTutorial -> "beginTutorial"
        is HighSchoolPhase4Command.CompleteTutorial -> pack(listOf(command.seed))
        is HighSchoolPhase4Command.ChooseSchool -> pack(listOf(command.seed, command.schoolId.wire))
        is HighSchoolPhase4Command.SelectPledge -> pack(listOf(command.pledgeId))
        is HighSchoolPhase4Command.Training -> pack(listOf(command.seed, command.focus.wire, command.intensity.wire, command.targetPitch?.wire.orEmpty()))
        is HighSchoolPhase4Command.TrainingBlock -> pack(listOf(command.seed, command.requests.joinToString(";") { it.first.wire + "," + it.second.wire }))
        is HighSchoolPhase4Command.Relationship -> pack(listOf(command.seed, command.response.wire))
        is HighSchoolPhase4Command.ReserveImportantGame -> pack(listOf(command.seed))
        is HighSchoolPhase4Command.SubmitPitch -> pack(listOf(command.sessionId, command.call.pitchType.wire, command.call.zone.row.toString(), command.call.zone.column.toString(), command.call.zoneIntent.wire, command.call.intensity.wire, command.delivery.releaseAccuracy.toString(), command.delivery.aimAccuracy.toString()))
        HighSchoolPhase4Command.FinishImportantGame -> "finishImportantGame"
        is HighSchoolPhase4Command.ChooseAwakening -> pack(listOf(command.seed, command.awakening.wire))
        is HighSchoolPhase4Command.AdvanceChapter -> pack(listOf(command.seed))
        is HighSchoolPhase4Command.ResolveDraft -> pack(listOf(command.seed))
        HighSchoolPhase4Command.PrepareLegacy -> "prepareLegacy"
        is HighSchoolPhase4Command.SelectLegacy -> pack(listOf(command.legacyId))
        HighSchoolPhase4Command.FinalizeArchive -> "finalizeArchive"
        is HighSchoolPhase4Command.BeginRebirth -> pack(listOf(command.seed, command.dayKey, command.entryPath))
        HighSchoolPhase4Command.StartChallenge -> "startChallenge"
        HighSchoolPhase4Command.EndChallenge -> "endChallenge"
        HighSchoolPhase4Command.ClaimWeeklyReward -> "claimWeeklyReward"
        is HighSchoolPhase4Command.SaveReturnPlan -> {
            val base = listOf(command.plan.destination.wire, command.plan.reason, command.plan.createdDayKey, command.plan.receiptId, command.plan.dismissed.toString())
            if (!command.plan.isExtendedWire()) pack(base) else pack(base + listOf(
                command.plan.route, command.plan.title, command.plan.body, command.plan.experimentId.orEmpty(),
                command.plan.savedDayKey.orEmpty(), command.plan.experimentVariant.orEmpty(), command.plan.developmentRulesVersion?.toString().orEmpty(),
            ))
        }
        is HighSchoolPhase4Command.PrepareReturnPlan -> pack(listOf(command.dayKey, command.developmentRulesVersion.toString()))
        is HighSchoolPhase4Command.SaveNextRunIntent -> pack(listOf(command.intent.pledgeId, command.intent.sourceLifeNumber.toString(), command.intent.reason))
        HighSchoolPhase4Command.ClearNextRunIntent -> "clearNextRunIntent"
        HighSchoolPhase4Command.DismissReturnPlan -> "dismissReturnPlan"
        is HighSchoolPhase4Command.AcknowledgeAchievement -> pack(listOf(command.achievementId))
    }

    private fun canonical(command: HighSchoolPhase4Command): String = when (command) {
        is HighSchoolPhase4Command.Start -> "start|${command.request}"
        HighSchoolPhase4Command.BeginTutorial -> "beginTutorial"
        is HighSchoolPhase4Command.CompleteTutorial -> "completeTutorial|${command.seed}"
        is HighSchoolPhase4Command.ChooseSchool -> "chooseSchool|${command.seed}|${command.schoolId.wire}"
        is HighSchoolPhase4Command.SelectPledge -> "selectPledge|${command.pledgeId}"
        is HighSchoolPhase4Command.Training -> "training|${command.seed}|${command.focus.wire}|${command.intensity.wire}|${command.targetPitch?.wire ?: "none"}"
        is HighSchoolPhase4Command.TrainingBlock -> "trainingBlock|${command.seed}|${command.requests.joinToString(",") { it.first.wire + ":" + it.second.wire }}"
        is HighSchoolPhase4Command.Relationship -> "relationship|${command.seed}|${command.response.wire}"
        is HighSchoolPhase4Command.ReserveImportantGame -> "reserveImportantGame|${command.seed}"
        is HighSchoolPhase4Command.SubmitPitch -> "submitPitch|${command.sessionId}|${command.call}|${command.delivery}"
        HighSchoolPhase4Command.FinishImportantGame -> "finishImportantGame"
        is HighSchoolPhase4Command.ChooseAwakening -> "chooseAwakening|${command.seed}|${command.awakening.wire}"
        is HighSchoolPhase4Command.AdvanceChapter -> "advanceChapter|${command.seed}"
        is HighSchoolPhase4Command.ResolveDraft -> "resolveDraft|${command.seed}"
        HighSchoolPhase4Command.PrepareLegacy -> "prepareLegacy"
        is HighSchoolPhase4Command.SelectLegacy -> "selectLegacy|${command.legacyId}"
        HighSchoolPhase4Command.FinalizeArchive -> "finalizeArchive"
        is HighSchoolPhase4Command.BeginRebirth -> "beginRebirth|${command.seed}|${command.dayKey}|${command.entryPath}"
        HighSchoolPhase4Command.StartChallenge -> "startChallenge"
        HighSchoolPhase4Command.EndChallenge -> "endChallenge"
        HighSchoolPhase4Command.ClaimWeeklyReward -> "claimWeeklyReward"
        is HighSchoolPhase4Command.SaveReturnPlan -> "saveReturnPlan|${command.plan}"
        is HighSchoolPhase4Command.PrepareReturnPlan -> "prepareReturnPlan|${command.dayKey}|${command.developmentRulesVersion}"
        is HighSchoolPhase4Command.SaveNextRunIntent -> "saveNextRunIntent|${command.intent}"
        HighSchoolPhase4Command.ClearNextRunIntent -> "clearNextRunIntent"
        HighSchoolPhase4Command.DismissReturnPlan -> "dismissReturnPlan"
        is HighSchoolPhase4Command.AcknowledgeAchievement -> "acknowledgeAchievement|${command.achievementId}"
    }

    private fun pack(values: List<String>): String = "p4:" + values.joinToString(".") { Base64.getUrlEncoder().withoutPadding().encodeToString(it.toByteArray(Charsets.UTF_8)) }
    private fun unpack(payload: String, expected: Int): List<String> {
        val values = unpackValues(payload)
        if (values.size != expected) fail("command.payload_count")
        return values
    }
    private fun unpackOneOf(payload: String, vararg expected: Int): List<String> {
        val values = unpackValues(payload)
        if (values.size !in expected.toSet()) fail("command.payload_count")
        return values
    }
    private fun unpackValues(payload: String): List<String> {
        if (!payload.startsWith("p4:")) fail("command.payload_prefix")
        val encoded = payload.removePrefix("p4:").split('.')
        return encoded.map {
            try {
                val bytes = Base64.getUrlDecoder().decode(it)
                val canonical = Base64.getUrlEncoder().withoutPadding().encodeToString(bytes)
                if (canonical != it) fail("command.payload_noncanonical")
                decodeUtf8(bytes)
            } catch (error: HighSchoolPhase4CommandException) { throw error }
            catch (_: Exception) { fail("command.payload_encoding") }
        }
    }
    private fun lineageLoadout(value: String): HighSchoolLineageLoadout? {
        if (value.isEmpty()) return null
        val parts = value.split('|')
        if (parts.size != 5) fail("start.lineage_loadout")
        return HighSchoolLineageLoadout(
            rulesVersion = parts[0].toIntOrNull() ?: fail("start.lineage.rules"),
            legacyId = parts[1],
            masteryRank = parts[2].toIntOrNull() ?: fail("start.lineage.rank"),
            contributions = parts[3].toIntOrNull() ?: fail("start.lineage.contributions"),
            sourceLifeNumber = parts[4].ifEmpty { null }?.toIntOrNull() ?: if (parts[4].isEmpty()) null else fail("start.lineage.sourceLife"),
        )
    }
    private fun lineageLoadout(value: HighSchoolLineageLoadout?): String = value?.let {
        listOf(it.rulesVersion, it.legacyId, it.masteryRank, it.contributions, it.sourceLifeNumber ?: "").joinToString("|")
    }.orEmpty()
    private fun lineageMasteries(value: String): List<HighSchoolLineageMastery> {
        if (value.isEmpty()) return emptyList()
        return value.split(';').map { item ->
            val parts = item.split(',')
            if (parts.size != 4) fail("start.lineage_mastery")
            HighSchoolLineageMastery(
                family = parts[0],
                contributions = parts[1].toIntOrNull() ?: fail("start.lineage_mastery.contributions"),
                rank = parts[2].toIntOrNull() ?: fail("start.lineage_mastery.rank"),
                nextThreshold = parts[3].ifEmpty { null }?.toIntOrNull() ?: if (parts[3].isEmpty()) null else fail("start.lineage_mastery.threshold"),
            )
        }
    }
    private fun lineageMasteries(value: List<HighSchoolLineageMastery>): String = value.joinToString(";") {
        listOf(it.family, it.contributions, it.rank, it.nextThreshold ?: "").joinToString(",")
    }
    private fun nextRunIntent(value: String): HighSchoolNextRunIntent? {
        if (value.isEmpty()) return null
        val parts = value.split('|')
        if (parts.size != 3 || parts[0].isBlank() || parts[2].isBlank()) fail("start.next_run_intent")
        return HighSchoolNextRunIntent(parts[0], parts[1].toIntOrNull() ?: fail("start.next_run_intent.life"), parts[2])
    }
    private fun nextRunIntent(value: HighSchoolNextRunIntent?): String = value?.let {
        listOf(it.pledgeId, it.sourceLifeNumber, it.reason).joinToString("|")
    }.orEmpty()
    private fun decodeUtf8(bytes: ByteArray): String = try {
        Charsets.UTF_8.newDecoder()
            .onMalformedInput(CodingErrorAction.REPORT)
            .onUnmappableCharacter(CodingErrorAction.REPORT)
            .decode(ByteBuffer.wrap(bytes))
            .toString()
    } catch (_: Exception) {
        fail("command.payload_utf8")
    }
    private fun csv(value: String): List<String> = value.split(',').filter { it.isNotEmpty() }
    private fun String.toIntStrict(field: String): Int = toIntOrNull() ?: fail(field)
    private fun String.toBooleanStrictOrFail(field: String): Boolean = when (this) { "true" -> true; "false" -> false; else -> fail(field) }
    private fun <T> enumByWire(values: Iterable<T>, wire: String, field: String, wireOf: (T) -> String): T = values.firstOrNull { wireOf(it) == wire } ?: fail("$field.unknown")

    private fun HighSchoolReturnPlan.isExtendedWire(): Boolean =
        route != destination.wire || title != reason || body != reason || experimentId != null ||
            savedDayKey != null || experimentVariant != null || developmentRulesVersion != null

    private fun requireExact(value: JsonValue.Obj, expected: Set<String>, field: String) {
        val missing = expected - value.entries.keys
        val unknown = value.entries.keys - expected
        if (missing.isNotEmpty()) fail("$field.missing:${missing.sorted().joinToString(",")}")
        if (unknown.isNotEmpty()) fail("$field.unknown:${unknown.sorted().joinToString(",")}")
    }

    private fun JsonValue.Obj.string(name: String): String = (this[name] as? JsonValue.Str)?.value ?: fail("command.$name")
    private fun JsonValue.Obj.integer(name: String): Int = (this[name] as? JsonValue.Num)?.raw?.toIntOrNull() ?: fail("command.$name")
    private fun JsonValue.Obj.decimal(name: String): ULong {
        val value = string(name)
        if (!Regex("0|[1-9][0-9]*").matches(value)) fail("command.$name")
        return value.toULongOrNull() ?: fail("command.$name")
    }
    private fun fail(code: String): Nothing = throw HighSchoolPhase4CommandException(code)
}
