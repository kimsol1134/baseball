package com.solkim.baseball.core.pro

import com.solkim.baseball.core.StableHash
import com.solkim.baseball.model.JsonValue
import com.solkim.baseball.model.StrictJson
import java.util.Base64

public object ProJourneyWire {
    public const val COMMAND_SCHEMA: String = "baseball-pro-career-command-v2"
    public const val SCHEMA_VERSION: Int = 2
}

public sealed interface ProJourneyCommand {
    public data class Start(
        val careerId: String,
        val teamId: String,
        val draftRound: Int = 2,
        val overallPick: Int = 18,
        val signingBonus: Long = 120_000_000L,
    ) : ProJourneyCommand

    public data class AcceptContract(val marketId: String, val offerId: String, val ambition: ProCareerAmbition?) : ProJourneyCommand
    public data class ReviewSeason(
        val season: Int,
        val teamId: String,
        val salary: Long,
        val merchandise: Long,
        val fanDelta: Int,
        val legacyDelta: Int,
        val hallOfFameDelta: Int,
        val contractYearsBefore: Int,
        val contractYearsAfter: Int,
        val nextRoute: ProSettlementNextRoute,
    ) : ProJourneyCommand
    public data class AcknowledgeSettlement(val settlementId: String) : ProJourneyCommand
    public data class ChooseInvestment(val season: Int, val investment: ProOffseasonInvestment, val focus: ProDevelopmentFocus?) : ProJourneyCommand
    public data class ApplyMediaChoice(
        val season: Int,
        val decisionId: String,
        val choiceId: String,
        val endorsementAmount: Long,
        val fanDelta: Int,
        val communityDelta: Int,
    ) : ProJourneyCommand
    public data class Retire(val lastTeamId: String?) : ProJourneyCommand
}

public data class ProJourneyCommandEnvelope(
    val commandId: String,
    val sessionId: String,
    val expectedRevision: ULong,
    val command: ProJourneyCommand,
    val schema: String = ProJourneyWire.COMMAND_SCHEMA,
    val schemaVersion: Int = ProJourneyWire.SCHEMA_VERSION,
) {
    init {
        require(commandId.isNotBlank() && commandId.length <= 128) { "pro.journey.command_id" }
        require(sessionId.isNotBlank() && sessionId.length <= 128) { "pro.journey.session_id" }
        require(schema == ProJourneyWire.COMMAND_SCHEMA) { "pro.journey.command_schema" }
        require(schemaVersion == ProJourneyWire.SCHEMA_VERSION) { "pro.journey.command_version" }
    }
}

public data class ProJourneyCommandResult(
    val state: ProCareerJourneyState,
    val nextSeed: ULong,
    val commandHash: String,
)

public object ProJourneyCommandCodec {
    private val ROOT_FIELDS = setOf("schema", "schemaVersion", "commandId", "sessionId", "expectedRevision", "kind", "payload")

    public fun encode(envelope: ProJourneyCommandEnvelope): ByteArray {
        val root = JsonValue.Obj(linkedMapOf(
            "schema" to JsonValue.Str(envelope.schema),
            "schemaVersion" to JsonValue.Num(envelope.schemaVersion.toString()),
            "commandId" to JsonValue.Str(envelope.commandId),
            "sessionId" to JsonValue.Str(envelope.sessionId),
            "expectedRevision" to JsonValue.Num(envelope.expectedRevision.toString()),
            "kind" to JsonValue.Str(kind(envelope.command)),
            "payload" to JsonValue.Str(pack(payload(envelope.command))),
        ))
        return StrictJson.canonical(root).toByteArray(Charsets.UTF_8)
    }

    public fun decode(bytes: ByteArray): ProJourneyCommandEnvelope {
        val root = try { StrictJson.parseUtf8(bytes) as? JsonValue.Obj ?: fail("pro.journey.command.root") } catch (error: ProJourneyCommandException) { throw error } catch (_: Exception) { fail("pro.journey.command.json") }
        requireExact(root, ROOT_FIELDS)
        if (!bytes.contentEquals(StrictJson.canonical(root).toByteArray(Charsets.UTF_8))) fail("pro.journey.command.noncanonical")
        val schema = root.string("schema")
        if (schema != ProJourneyWire.COMMAND_SCHEMA) fail("pro.journey.command.schema")
        val version = root.int("schemaVersion")
        if (version != ProJourneyWire.SCHEMA_VERSION) fail("pro.journey.command.future_or_old:$version")
        return ProJourneyCommandEnvelope(
            commandId = root.string("commandId"), sessionId = root.string("sessionId"), expectedRevision = root.ulong("expectedRevision"),
            command = decodeCommand(root.string("kind"), unpack(root.string("payload"))), schema = schema, schemaVersion = version,
        )
    }

    public fun commandHash(command: ProJourneyCommand): String = StableHash.fnv1a64("${kind(command)}|${pack(payload(command))}")

    private fun kind(command: ProJourneyCommand): String = when (command) {
        is ProJourneyCommand.Start -> "start"
        is ProJourneyCommand.AcceptContract -> "accept_contract"
        is ProJourneyCommand.ReviewSeason -> "review_season"
        is ProJourneyCommand.AcknowledgeSettlement -> "acknowledge_settlement"
        is ProJourneyCommand.ChooseInvestment -> "choose_investment"
        is ProJourneyCommand.ApplyMediaChoice -> "apply_media_choice"
        is ProJourneyCommand.Retire -> "retire"
    }

    private fun payload(command: ProJourneyCommand): List<String> = when (command) {
        is ProJourneyCommand.Start -> listOf(command.careerId, command.teamId, command.draftRound.toString(), command.overallPick.toString(), command.signingBonus.toString())
        is ProJourneyCommand.AcceptContract -> listOf(command.marketId, command.offerId, command.ambition?.wire.orEmpty())
        is ProJourneyCommand.ReviewSeason -> listOf(command.season, command.teamId, command.salary, command.merchandise, command.fanDelta, command.legacyDelta, command.hallOfFameDelta, command.contractYearsBefore, command.contractYearsAfter, command.nextRoute.wire).map(Any::toString)
        is ProJourneyCommand.AcknowledgeSettlement -> listOf(command.settlementId)
        is ProJourneyCommand.ChooseInvestment -> listOf(command.season.toString(), command.investment.wire, command.focus?.wire.orEmpty())
        is ProJourneyCommand.ApplyMediaChoice -> listOf(command.season, command.decisionId, command.choiceId, command.endorsementAmount, command.fanDelta, command.communityDelta).map { it.toString() }
        is ProJourneyCommand.Retire -> listOf(command.lastTeamId.orEmpty())
    }

    private fun decodeCommand(kind: String, fields: List<String>): ProJourneyCommand = when (kind) {
        "start" -> exact(fields, 5) { ProJourneyCommand.Start(fields[0], fields[1], fields[2].toIntField("start.draftRound"), fields[3].toIntField("start.overallPick"), fields[4].toLongField("start.signingBonus")) }
        "accept_contract" -> exact(fields, 3) { ProJourneyCommand.AcceptContract(fields[0], fields[1], fields[2].ifEmpty { null }?.let(::ambition)) }
        "review_season" -> exact(fields, 10) { ProJourneyCommand.ReviewSeason(fields[0].toIntField("review.season"), fields[1], fields[2].toLongField("review.salary"), fields[3].toLongField("review.merchandise"), fields[4].toIntField("review.fan"), fields[5].toIntField("review.legacy"), fields[6].toIntField("review.hof"), fields[7].toIntField("review.yearsBefore"), fields[8].toIntField("review.yearsAfter"), route(fields[9])) }
        "acknowledge_settlement" -> exact(fields, 1) { ProJourneyCommand.AcknowledgeSettlement(fields[0]) }
        "choose_investment" -> exact(fields, 3) { ProJourneyCommand.ChooseInvestment(fields[0].toIntField("investment.season"), investment(fields[1]), fields[2].ifEmpty { null }?.let(::focus)) }
        "apply_media_choice" -> exact(fields, 6) { ProJourneyCommand.ApplyMediaChoice(fields[0].toIntField("media.season"), fields[1], fields[2], fields[3].toLongField("media.endorsement"), fields[4].toIntField("media.fan"), fields[5].toIntField("media.community")) }
        "retire" -> exact(fields, 1) { ProJourneyCommand.Retire(fields[0].ifEmpty { null }) }
        else -> fail("pro.journey.command.kind:$kind")
    }

    private fun pack(fields: List<String>): String = "p6:" + fields.joinToString(".") {
        val bytes = if (it.isEmpty()) byteArrayOf(0) else it.toByteArray(Charsets.UTF_8)
        Base64.getUrlEncoder().withoutPadding().encodeToString(bytes)
    }
    private fun unpack(value: String): List<String> {
        if (!value.startsWith("p6:")) fail("pro.journey.command.payload_prefix")
        val encoded = value.removePrefix("p6:")
        if (encoded.isEmpty()) return emptyList()
        return encoded.split('.').map { part ->
            try {
                val decoded = Base64.getUrlDecoder().decode(part)
                require(Base64.getUrlEncoder().withoutPadding().encodeToString(decoded) == part) { "noncanonical" }
                decoded.toString(Charsets.UTF_8).removeSuffix("\u0000")
            } catch (_: Exception) { fail("pro.journey.command.payload_encoding") }
        }
    }

    private fun <T> exact(fields: List<String>, count: Int, factory: () -> T): T { if (fields.size != count) fail("pro.journey.command.payload_count"); return factory() }
    private fun requireExact(root: JsonValue.Obj, expected: Set<String>) { require(root.entries.keys == expected) { "pro.journey.command.fields" } }
    private fun JsonValue.Obj.string(name: String): String = (entries[name] as? JsonValue.Str)?.value ?: fail("pro.journey.command.$name")
    private fun JsonValue.Obj.int(name: String): Int = stringOrNumber(name).toIntField(name)
    private fun JsonValue.Obj.ulong(name: String): ULong = stringOrNumber(name).toULongOrNull() ?: fail("pro.journey.command.$name")
    private fun JsonValue.Obj.stringOrNumber(name: String): String = when (val value = entries[name]) { is JsonValue.Str -> value.value; is JsonValue.Num -> value.raw; else -> fail("pro.journey.command.$name") }
    private fun String.toIntField(code: String): Int = toIntOrNull() ?: fail(code)
    private fun String.toLongField(code: String): Long = toLongOrNull() ?: fail(code)
    private fun ambition(value: String) = ProCareerAmbition.entries.firstOrNull { it.wire == value } ?: fail("pro.journey.command.ambition")
    private fun investment(value: String) = ProOffseasonInvestment.entries.firstOrNull { it.wire == value } ?: fail("pro.journey.command.investment")
    private fun focus(value: String) = ProDevelopmentFocus.entries.firstOrNull { it.wire == value } ?: fail("pro.journey.command.focus")
    private fun route(value: String) = ProSettlementNextRoute.entries.firstOrNull { it.wire == value } ?: fail("pro.journey.command.route")
    private fun fail(code: String): Nothing = throw ProJourneyCommandException(code)
}

public class ProJourneyCommandException(message: String) : IllegalArgumentException(message)

/** Command application is deliberately pure and revision-agnostic; the app layer owns CAS. */
public object ProJourneyCommandKernel {
    public fun apply(
        state: ProCareerJourneyState,
        careerId: String,
        envelope: ProJourneyCommandEnvelope,
    ): ProJourneyCommandResult {
        val commandHash = ProJourneyCommandCodec.commandHash(envelope.command)
        val next = when (val command = envelope.command) {
            is ProJourneyCommand.Start -> state.copy(pendingContractMarket = ProJourneyKernel.rookieMarket(careerId, command.teamId, envelope.expectedRevision, 1, command.draftRound, command.overallPick, command.signingBonus))
            is ProJourneyCommand.AcceptContract -> accept(state, careerId, command)
            is ProJourneyCommand.ReviewSeason -> ProJourneyKernel.settle(state, careerId, command.season, command.teamId, command.salary, command.merchandise, command.fanDelta, command.legacyDelta, command.hallOfFameDelta, command.contractYearsBefore, command.contractYearsAfter, command.nextRoute)
            is ProJourneyCommand.AcknowledgeSettlement -> ProJourneyKernel.acknowledgeSettlement(state, command.settlementId)
            is ProJourneyCommand.ChooseInvestment -> ProJourneyKernel.applyInvestment(state, careerId, command.season, command.investment, command.focus)
            is ProJourneyCommand.ApplyMediaChoice -> ProJourneyKernel.applyMediaChoice(state, careerId, command.season, command.decisionId, command.choiceId, command.endorsementAmount, command.fanDelta, command.communityDelta)
            is ProJourneyCommand.Retire -> state.copy(retirementHonors = ProJourneyKernel.retirementPreview(state, command.lastTeamId).honors)
        }
        return ProJourneyCommandResult(next, StableHash.fnv1a64("${envelope.sessionId}|${envelope.expectedRevision}|$commandHash").toULong(16), commandHash)
    }

    private fun accept(state: ProCareerJourneyState, careerId: String, command: ProJourneyCommand.AcceptContract): ProCareerJourneyState {
        val market = state.pendingContractMarket ?: error("pro.journey.market_missing")
        require(market.id == command.marketId) { "pro.journey.market_stale" }
        val offer = market.offers.firstOrNull { it.id == command.offerId } ?: error("pro.journey.offer_missing")
        val record = ProContractRecord(offer.id, offer.teamId, offer.contractKind, market.forSeason, offer.years, offer.annualSalary, offer.signingBonus, offer.rolePromise, offer.expectation, emptyList(), emptyList(), null, null)
        val signing = offer.signingBonus?.let { ProFinanceTransaction("signing-bonus:$careerId:${market.forSeason}", market.forSeason, ProFinanceTransactionKind.SIGNING_BONUS, it) }
        val finance = signing?.let { state.finances.copy(careerEarnings = state.finances.careerEarnings + it.amount, availableFunds = state.finances.availableFunds + it.amount, transactions = state.finances.transactions + it) } ?: state.finances
        val goal = command.ambition?.let { ProCareerGoalState("goal:$careerId:${market.forSeason}:${it.wire}", it, market.forSeason, offer.teamId, null) }
        return state.copy(pendingContractMarket = null, contractHistory = state.contractHistory + record, finances = finance, activeGoal = goal, settlementAcknowledged = true)
    }
}
