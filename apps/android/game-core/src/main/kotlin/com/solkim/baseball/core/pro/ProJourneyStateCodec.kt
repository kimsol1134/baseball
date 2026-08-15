package com.solkim.baseball.core.pro

import com.solkim.baseball.model.Hashing
import com.solkim.baseball.model.JsonValue
import com.solkim.baseball.model.StrictJson
import java.util.LinkedHashMap

/** Strict JSON codec for the additive journey block. The legacy ProStateCodec remains v1-only. */
public object ProJourneyStateCodec {
    public const val SCHEMA: String = "baseball-pro-career-journey-state-v2"
    public const val SCHEMA_VERSION: Int = 2
    private val ROOT_FIELDS = setOf("schema", "schemaVersion", "payload", "stateCommitment")

    public fun canonicalToken(state: ProCareerJourneyState): String = StrictJson.canonical(encodeState(state))

    public fun encode(state: ProCareerJourneyState): ByteArray {
        val root = obj(
            "schema" to JsonValue.Str(SCHEMA),
            "schemaVersion" to num(SCHEMA_VERSION),
            "payload" to encodeState(state),
            "stateCommitment" to JsonValue.Str(ProJourneyKernel.stateCommitment(state)),
        )
        return StrictJson.canonical(root).toByteArray(Charsets.UTF_8)
    }

    public fun decode(bytes: ByteArray): ProCareerJourneyState {
        require(bytes.isNotEmpty()) { "pro.journey.empty" }
        val root = try { StrictJson.parseUtf8(bytes).asObj() } catch (error: Exception) { throw ProJourneyCodecException("pro.journey.json", error) }
        requireExact(root, ROOT_FIELDS, "pro.journey.root")
        require(bytes.contentEquals(StrictJson.canonical(root).toByteArray(Charsets.UTF_8))) { "pro.journey.noncanonical" }
        require(root.string("schema") == SCHEMA) { "pro.journey.schema" }
        val version = root.int("schemaVersion")
        require(version == SCHEMA_VERSION) { if (version > SCHEMA_VERSION) "pro.journey.future:$version" else "pro.journey.migration:$version" }
        val state = try { decodeState(root.obj("payload")) } catch (error: ProJourneyCodecException) { throw error } catch (error: Exception) { throw ProJourneyCodecException("pro.journey.payload", error) }
        require(root.string("stateCommitment") == ProJourneyKernel.stateCommitment(state)) { "pro.journey.commitment_mismatch" }
        return state
    }

    /** v1 saves are decoded by the unchanged legacy codec, then upgraded only at a safe boundary. */
    public fun migrateV1(legacyBytes: ByteArray): ProState {
        val legacy = ProStateCodec.decode(legacyBytes)
        require(legacy.phase == ProCareerPhase.WEEKLY_PLAN || legacy.phase == ProCareerPhase.SEASON_REVIEW || legacy.phase == ProCareerPhase.OFFSEASON_DECISION || legacy.phase == ProCareerPhase.COMPLETED) {
            "pro.journey.migration.unsafe_phase"
        }
        val journey = ProJourneyKernel.migrateLegacy(legacy)
        val withJourney = legacy.copy(journeyState = journey, commitment = "")
        return withJourney.copy(commitment = ProKernel().commitment(withJourney))
    }

    public fun decodeV1ToJourney(legacyBytes: ByteArray): ProCareerJourneyState = migrateV1(legacyBytes).journeyState!!

    private fun encodeState(state: ProCareerJourneyState): JsonValue.Obj = obj(
        "rulesVersion" to num(state.rulesVersion),
        "activeGoal" to nullable(state.activeGoal, ::encodeGoalState),
        "goalHistory" to arr(state.goalHistory, ::encodeGoalRecord),
        "pendingContractMarket" to nullable(state.pendingContractMarket, ::encodeMarket),
        "contractHistory" to arr(state.contractHistory, ::encodeContractRecord),
        "teamRecords" to arr(state.teamRecords, ::encodeTeamRecord),
        "recognitions" to arr(state.recognitions, ::encodeRecognition),
        "reputation" to encodeReputation(state.reputation),
        "finances" to encodeFinance(state.finances),
        "activeSeasonBenefit" to nullable(state.activeSeasonBenefit, ::encodeBenefit),
        "lastSettlement" to nullable(state.lastSettlement, ::encodeSettlement),
        "settlementAcknowledged" to JsonValue.Bool(state.settlementAcknowledged),
        "offseasonTransition" to nullable(state.offseasonTransition, ::encodeTransition),
        "retirementHonors" to arr(state.retirementHonors, ::encodeHonor),
        "migration" to encodeMigration(state.migration),
    )

    private fun decodeState(value: JsonValue.Obj): ProCareerJourneyState {
        requireExact(value, setOf("rulesVersion", "activeGoal", "goalHistory", "pendingContractMarket", "contractHistory", "teamRecords", "recognitions", "reputation", "finances", "activeSeasonBenefit", "lastSettlement", "settlementAcknowledged", "offseasonTransition", "retirementHonors", "migration"), "pro.journey.payload")
        return ProCareerJourneyState(
            rulesVersion = value.int("rulesVersion"),
            activeGoal = value.nullable("activeGoal", ::decodeGoalState),
            goalHistory = value.arr("goalHistory", ::decodeGoalRecord),
            pendingContractMarket = value.nullable("pendingContractMarket", ::decodeMarket),
            contractHistory = value.arr("contractHistory", ::decodeContractRecord),
            teamRecords = value.arr("teamRecords", ::decodeTeamRecord),
            recognitions = value.arr("recognitions", ::decodeRecognition),
            reputation = decodeReputation(value.obj("reputation")),
            finances = decodeFinance(value.obj("finances")),
            activeSeasonBenefit = value.nullable("activeSeasonBenefit", ::decodeBenefit),
            lastSettlement = value.nullable("lastSettlement", ::decodeSettlement),
            settlementAcknowledged = value.bool("settlementAcknowledged"),
            offseasonTransition = value.nullable("offseasonTransition", ::decodeTransition),
            retirementHonors = value.arr("retirementHonors", ::decodeHonor),
            migration = decodeMigration(value.obj("migration")),
        )
    }

    private fun encodeGoalState(value: ProCareerGoalState): JsonValue.Obj = obj(
        "id" to str(value.id), "ambition" to str(value.ambition.wire), "selectedSeason" to num(value.selectedSeason),
        "anchorTeamID" to nullableString(value.anchorTeamId), "completedSeason" to nullableInt(value.completedSeason),
    )

    private fun decodeGoalState(value: JsonValue.Obj): ProCareerGoalState = ProCareerGoalState(
        value.string("id"), ambition(value.string("ambition")), value.int("selectedSeason"), value.nullableString("anchorTeamID"), value.nullableInt("completedSeason"),
    )

    private fun encodeGoalRecord(value: ProCareerGoalRecord): JsonValue.Obj = obj(
        "id" to str(value.id), "ambition" to str(value.ambition.wire), "selectedSeason" to num(value.selectedSeason),
        "anchorTeamID" to nullableString(value.anchorTeamId), "completedSeason" to nullableInt(value.completedSeason),
        "endedSeason" to num(value.endedSeason), "outcome" to str(value.outcome.wire),
    )

    private fun decodeGoalRecord(value: JsonValue.Obj): ProCareerGoalRecord = ProCareerGoalRecord(
        value.string("id"), ambition(value.string("ambition")), value.int("selectedSeason"), value.nullableString("anchorTeamID"),
        value.nullableInt("completedSeason"), value.int("endedSeason"), goalOutcome(value.string("outcome")),
    )

    private fun encodeExpectation(value: ProContractExpectation): JsonValue.Obj = obj(
        "kind" to str(value.kind.wire), "target" to num(value.target), "difficulty" to str(value.difficulty.wire),
    )

    private fun decodeExpectation(value: JsonValue.Obj): ProContractExpectation = ProContractExpectation(
        expectationKind(value.string("kind")), value.int("target"), difficulty(value.string("difficulty")),
    )

    private fun encodeOffer(value: ProContractOffer): JsonValue.Obj = obj(
        "id" to str(value.id), "teamID" to str(value.teamId), "years" to num(value.years), "annualSalary" to num(value.annualSalary),
        "signingBonus" to nullableLong(value.signingBonus), "contractKind" to str(value.contractKind.wire), "rolePromise" to str(value.rolePromise.wire),
        "outlook" to str(value.outlook.wire), "expectation" to encodeExpectation(value.expectation), "preservesTeamLegacy" to JsonValue.Bool(value.preservesTeamLegacy),
    )

    private fun decodeOffer(value: JsonValue.Obj): ProContractOffer = ProContractOffer(
        value.string("id"), value.string("teamID"), value.int("years"), value.long("annualSalary"), value.nullableLong("signingBonus"),
        contractKind(value.string("contractKind")), role(value.string("rolePromise")), outlook(value.string("outlook")),
        decodeExpectation(value.obj("expectation")), value.bool("preservesTeamLegacy"),
    )

    private fun encodeMarket(value: ProContractMarket): JsonValue.Obj = obj(
        "id" to str(value.id), "kind" to str(value.kind.wire), "forSeason" to num(value.forSeason), "generatedAtRevision" to num(value.generatedAtRevision),
        "offers" to arr(value.offers, ::encodeOffer), "draftRound" to nullableInt(value.draftRound), "overallPick" to nullableInt(value.overallPick),
    )

    private fun decodeMarket(value: JsonValue.Obj): ProContractMarket = ProContractMarket(
        value.string("id"), marketKind(value.string("kind")), value.int("forSeason"), value.ulong("generatedAtRevision"),
        value.arr("offers", ::decodeOffer), value.nullableInt("draftRound"), value.nullableInt("overallPick"),
    )

    private fun encodeContractRecord(value: ProContractRecord): JsonValue.Obj = obj(
        "contractID" to str(value.contractId), "teamID" to str(value.teamId), "kind" to nullable(value.kind) { str(it.wire) },
        "signedSeason" to num(value.signedSeason), "totalYears" to num(value.totalYears), "annualSalary" to num(value.annualSalary),
        "signingBonus" to nullableLong(value.signingBonus), "rolePromise" to str(value.rolePromise.wire), "expectation" to nullable(value.expectation, ::encodeExpectation),
        "coveredSeasons" to ints(value.coveredSeasons), "fulfilledExpectationSeasons" to ints(value.fulfilledExpectationSeasons),
        "endedSeason" to nullableInt(value.endedSeason), "endReason" to nullable(value.endReason) { str(it.wire) },
    )

    private fun decodeContractRecord(value: JsonValue.Obj): ProContractRecord = ProContractRecord(
        value.string("contractID"), value.string("teamID"), value.nullableEnum("kind", ProContractKind.entries, { it.wire }),
        value.int("signedSeason"), value.int("totalYears"), value.long("annualSalary"), value.nullableLong("signingBonus"), role(value.string("rolePromise")),
        value.nullable("expectation", ::decodeExpectation), value.ints("coveredSeasons"), value.ints("fulfilledExpectationSeasons"),
        value.nullableInt("endedSeason"), value.nullableEnum("endReason", ProContractEndReason.entries, { it.wire }),
    )

    private fun encodeTeamRecord(value: ProTeamCareerRecord): JsonValue.Obj = obj(
        "teamID" to str(value.teamId), "completedSeasons" to num(value.completedSeasons), "consecutiveSeasons" to num(value.consecutiveSeasons),
        "games" to num(value.games), "starts" to num(value.starts), "inningsOuts" to num(value.inningsOuts), "strikeouts" to num(value.strikeouts),
        "wins" to num(value.wins), "saves" to num(value.saves), "awardCount" to num(value.awardCount), "communityPoints" to num(value.communityPoints),
        "lastSeason" to nullableInt(value.lastSeason),
    )

    private fun decodeTeamRecord(value: JsonValue.Obj): ProTeamCareerRecord = ProTeamCareerRecord(
        value.string("teamID"), value.int("completedSeasons"), value.int("consecutiveSeasons"), value.int("games"), value.int("starts"),
        value.int("inningsOuts"), value.int("strikeouts"), value.int("wins"), value.int("saves"), value.int("awardCount"), value.int("communityPoints"), value.nullableInt("lastSeason"),
    )

    private fun encodeRecognition(value: ProCareerRecognition): JsonValue.Obj = obj(
        "id" to str(value.id), "kind" to str(value.kind.wire), "contentID" to str(value.contentId), "season" to num(value.season),
        "teamID" to nullableString(value.teamId), "value" to nullableInt(value.value),
    )

    private fun decodeRecognition(value: JsonValue.Obj): ProCareerRecognition = ProCareerRecognition(
        value.string("id"), recognitionKind(value.string("kind")), value.string("contentID"), value.int("season"), value.nullableString("teamID"), value.nullableInt("value"),
    )

    private fun encodeReputation(value: ProReputationState): JsonValue.Obj = obj(
        "fanSupport" to num(value.fanSupport), "lastMerchandiseTier" to nullable(value.lastMerchandiseTier) { str(it.wire) }, "endorsementSeasons" to ints(value.endorsementSeasons),
    )

    private fun decodeReputation(value: JsonValue.Obj): ProReputationState = ProReputationState(
        value.int("fanSupport"), value.nullableEnum("lastMerchandiseTier", ProMerchandiseTier.entries, { it.wire }), value.ints("endorsementSeasons"),
    )

    private fun encodeFinance(value: ProFinanceState): JsonValue.Obj = obj(
        "careerEarnings" to num(value.careerEarnings), "availableFunds" to num(value.availableFunds), "salaryCreditedThroughSeason" to num(value.salaryCreditedThroughSeason),
        "transactions" to arr(value.transactions) { encodeTransaction(it) }, "investmentSeason" to nullableInt(value.investmentSeason),
    )

    private fun decodeFinance(value: JsonValue.Obj): ProFinanceState = ProFinanceState(
        value.long("careerEarnings"), value.long("availableFunds"), value.int("salaryCreditedThroughSeason"), value.arr("transactions", ::decodeTransaction), value.nullableInt("investmentSeason"),
    )

    private fun encodeTransaction(value: ProFinanceTransaction): JsonValue.Obj = obj(
        "id" to str(value.id), "season" to num(value.season), "kind" to str(value.kind.wire), "amount" to num(value.amount),
    )

    private fun decodeTransaction(value: JsonValue.Obj): ProFinanceTransaction = ProFinanceTransaction(value.string("id"), value.int("season"), financeKind(value.string("kind")), value.long("amount"))

    private fun encodeBenefit(value: ProSeasonBenefit): JsonValue.Obj = obj(
        "kind" to str(value.kind.wire), "focus" to nullable(value.focus) { str(it.wire) }, "remainingCharges" to num(value.remainingCharges),
    )

    private fun decodeBenefit(value: JsonValue.Obj): ProSeasonBenefit = ProSeasonBenefit(
        benefitKind(value.string("kind")), value.nullableEnum("focus", ProDevelopmentFocus.entries, { it.wire }), value.int("remainingCharges"),
    )

    private fun encodeFanReason(value: ProFanReason): JsonValue.Obj = obj("id" to str(value.id), "kind" to str(value.kind.wire), "contentID" to str(value.contentId), "delta" to num(value.delta))
    private fun decodeFanReason(value: JsonValue.Obj): ProFanReason = ProFanReason(value.string("id"), fanKind(value.string("kind")), value.string("contentID"), value.int("delta"))

    private fun encodeMetric(value: ProCareerGoalMetric): JsonValue.Obj = obj("kind" to str(value.kind.wire), "current" to num(value.current), "target" to num(value.target))
    private fun decodeMetric(value: JsonValue.Obj): ProCareerGoalMetric = ProCareerGoalMetric(metricKind(value.string("kind")), value.int("current"), value.int("target"))
    private fun encodeProgress(value: ProCareerGoalProgress): JsonValue.Obj = obj("ambition" to str(value.ambition.wire), "metrics" to arr(value.metrics, ::encodeMetric), "completed" to JsonValue.Bool(value.completed))
    private fun decodeProgress(value: JsonValue.Obj): ProCareerGoalProgress = ProCareerGoalProgress(ambition(value.string("ambition")), value.arr("metrics", ::decodeMetric), value.bool("completed"))

    private fun encodeSettlement(value: ProSeasonSettlement): JsonValue.Obj = obj(
        "id" to str(value.id), "season" to num(value.season), "teamID" to str(value.teamId), "salaryIncome" to num(value.salaryIncome), "merchandiseIncome" to num(value.merchandiseIncome),
        "fanBefore" to num(value.fanBefore), "fanAfter" to num(value.fanAfter), "fanDelta" to num(value.fanDelta), "fanReasons" to arr(value.fanReasons, ::encodeFanReason),
        "merchandiseTier" to nullable(value.merchandiseTier) { str(it.wire) }, "teamLegacyBefore" to num(value.teamLegacyBefore), "teamLegacyAfter" to num(value.teamLegacyAfter),
        "hallOfFameBefore" to num(value.hallOfFameBefore), "hallOfFameAfter" to num(value.hallOfFameAfter), "contractYearsBefore" to num(value.contractYearsBefore), "contractYearsAfter" to num(value.contractYearsAfter),
        "contractExpectation" to nullable(value.contractExpectation, ::encodeExpectation), "contractExpectationActual" to nullableInt(value.contractExpectationActual), "contractExpectationMet" to nullableBool(value.contractExpectationMet),
        "goalProgressBefore" to nullable(value.goalProgressBefore, ::encodeProgress), "goalProgressAfter" to nullable(value.goalProgressAfter, ::encodeProgress), "goalCompleted" to JsonValue.Bool(value.goalCompleted), "nextRoute" to str(value.nextRoute.wire),
    )

    private fun decodeSettlement(value: JsonValue.Obj): ProSeasonSettlement = ProSeasonSettlement(
        value.string("id"), value.int("season"), value.string("teamID"), value.long("salaryIncome"), value.long("merchandiseIncome"), value.int("fanBefore"), value.int("fanAfter"), value.int("fanDelta"),
        value.arr("fanReasons", ::decodeFanReason), value.nullableEnum("merchandiseTier", ProMerchandiseTier.entries, { it.wire }), value.int("teamLegacyBefore"), value.int("teamLegacyAfter"),
        value.int("hallOfFameBefore"), value.int("hallOfFameAfter"), value.int("contractYearsBefore"), value.int("contractYearsAfter"), value.nullable("contractExpectation", ::decodeExpectation), value.nullableInt("contractExpectationActual"), value.nullableBool("contractExpectationMet"),
        value.nullable("goalProgressBefore", ::decodeProgress), value.nullable("goalProgressAfter", ::decodeProgress), value.bool("goalCompleted"), settlementRoute(value.string("nextRoute")),
    )

    private fun encodeTransition(value: ProOffseasonTransition): JsonValue.Obj = obj(
        "afterSeason" to num(value.afterSeason), "nextSeason" to num(value.nextSeason), "ageAdvanceYears" to num(value.ageAdvanceYears), "includesMilitaryService" to JsonValue.Bool(value.includesMilitaryService), "route" to str(value.route.wire),
    )
    private fun decodeTransition(value: JsonValue.Obj): ProOffseasonTransition = ProOffseasonTransition(value.int("afterSeason"), value.int("nextSeason"), value.int("ageAdvanceYears"), value.bool("includesMilitaryService"), transitionRoute(value.string("route")))

    private fun encodeHonor(value: ProRetirementHonor): JsonValue.Obj = obj("id" to str(value.id), "kind" to str(value.kind.wire), "teamID" to nullableString(value.teamId), "referenceID" to nullableString(value.referenceId), "value" to nullableLong(value.value))
    private fun decodeHonor(value: JsonValue.Obj): ProRetirementHonor = ProRetirementHonor(value.string("id"), honorKind(value.string("kind")), value.nullableString("teamID"), value.nullableString("referenceID"), value.nullableLong("value"))

    private fun encodeMigration(value: ProJourneyMigration): JsonValue.Obj = obj("source" to str(value.source.wire), "initializedSeason" to num(value.initializedSeason), "financeStartsSeason" to num(value.financeStartsSeason), "unassignedLegacyAwards" to num(value.unassignedLegacyAwards), "financeNoticePending" to JsonValue.Bool(value.financeNoticePending))
    private fun decodeMigration(value: JsonValue.Obj): ProJourneyMigration = ProJourneyMigration(migrationSource(value.string("source")), value.int("initializedSeason"), value.int("financeStartsSeason"), value.int("unassignedLegacyAwards"), value.bool("financeNoticePending"))

    private fun obj(vararg fields: Pair<String, JsonValue>): JsonValue.Obj = JsonValue.Obj(LinkedHashMap<String, JsonValue>().apply { fields.forEach { put(it.first, it.second) } })
    private fun str(value: String): JsonValue = JsonValue.Str(value)
    private fun num(value: Int): JsonValue = JsonValue.Num(value.toString())
    private fun num(value: Long): JsonValue = JsonValue.Num(value.toString())
    private fun num(value: ULong): JsonValue = JsonValue.Num(value.toString())
    private fun nullableString(value: String?): JsonValue = value?.let(::str) ?: JsonValue.Null
    private fun nullableInt(value: Int?): JsonValue = value?.let(::num) ?: JsonValue.Null
    private fun nullableLong(value: Long?): JsonValue = value?.let(::num) ?: JsonValue.Null
    private fun nullableBool(value: Boolean?): JsonValue = value?.let { JsonValue.Bool(it) } ?: JsonValue.Null
    private fun <T> nullable(value: T?, encoder: (T) -> JsonValue): JsonValue = value?.let(encoder) ?: JsonValue.Null
    private fun <T> arr(values: List<T>, encoder: (T) -> JsonValue): JsonValue = JsonValue.Arr(values.map(encoder))
    private fun ints(values: List<Int>): JsonValue = JsonValue.Arr(values.map(::num))

    private fun JsonValue.asObj(): JsonValue.Obj = this as? JsonValue.Obj ?: fail("pro.journey.object")
    private fun JsonValue.Obj.obj(name: String): JsonValue.Obj = (entries[name] ?: fail("pro.journey.$name")).asObj()
    private fun JsonValue.Obj.string(name: String): String = (entries[name] as? JsonValue.Str)?.value ?: fail("pro.journey.$name")
    private fun JsonValue.Obj.int(name: String): Int = (entries[name] as? JsonValue.Num)?.raw?.toIntOrNull() ?: fail("pro.journey.$name")
    private fun JsonValue.Obj.long(name: String): Long = (entries[name] as? JsonValue.Num)?.raw?.toLongOrNull() ?: fail("pro.journey.$name")
    private fun JsonValue.Obj.ulong(name: String): ULong = (entries[name] as? JsonValue.Num)?.raw?.toULongOrNull() ?: fail("pro.journey.$name")
    private fun JsonValue.Obj.bool(name: String): Boolean = (entries[name] as? JsonValue.Bool)?.value ?: fail("pro.journey.$name")
    private fun JsonValue.Obj.nullableString(name: String): String? = when (val value = entries[name] ?: fail("pro.journey.$name")) { JsonValue.Null -> null; is JsonValue.Str -> value.value; else -> fail("pro.journey.$name") }
    private fun JsonValue.Obj.nullableInt(name: String): Int? = when (val value = entries[name] ?: fail("pro.journey.$name")) { JsonValue.Null -> null; is JsonValue.Num -> value.raw.toIntOrNull() ?: fail("pro.journey.$name"); else -> fail("pro.journey.$name") }
    private fun JsonValue.Obj.nullableLong(name: String): Long? = when (val value = entries[name] ?: fail("pro.journey.$name")) { JsonValue.Null -> null; is JsonValue.Num -> value.raw.toLongOrNull() ?: fail("pro.journey.$name"); else -> fail("pro.journey.$name") }
    private fun JsonValue.Obj.nullableBool(name: String): Boolean? = when (val value = entries[name] ?: fail("pro.journey.$name")) { JsonValue.Null -> null; is JsonValue.Bool -> value.value; else -> fail("pro.journey.$name") }
    private fun <T> JsonValue.Obj.nullable(name: String, decoder: (JsonValue.Obj) -> T): T? = when (val value = entries[name] ?: fail("pro.journey.$name")) { JsonValue.Null -> null; is JsonValue.Obj -> decoder(value); else -> fail("pro.journey.$name") }
    private fun <T> JsonValue.Obj.arr(name: String, decoder: (JsonValue.Obj) -> T): List<T> = (entries[name] as? JsonValue.Arr)?.values?.map { decoder(it.asObj()) } ?: fail("pro.journey.$name")
    private fun JsonValue.Obj.ints(name: String): List<Int> = (entries[name] as? JsonValue.Arr)?.values?.map { (it as? JsonValue.Num)?.raw?.toIntOrNull() ?: fail("pro.journey.$name") } ?: fail("pro.journey.$name")
    private inline fun <reified T> JsonValue.Obj.nullableEnum(name: String, values: List<T>, crossinline wire: (T) -> String): T? = nullableString(name)?.let { raw -> values.firstOrNull { wire(it) == raw } ?: fail("pro.journey.$name") }

    private fun requireExact(value: JsonValue.Obj, expected: Set<String>, field: String) {
        val missing = expected - value.entries.keys
        val unknown = value.entries.keys - expected
        require(missing.isEmpty()) { "$field.missing:${missing.sorted().joinToString(",")}" }
        require(unknown.isEmpty()) { "$field.unknown:${unknown.sorted().joinToString(",")}" }
    }

    private fun <T> fromWire(value: String, values: Iterable<T>, wire: (T) -> String, code: String): T = values.firstOrNull { wire(it) == value } ?: fail(code)
    private fun ambition(value: String) = fromWire(value, ProCareerAmbition.entries, { it.wire }, "pro.journey.ambition")
    private fun goalOutcome(value: String) = fromWire(value, ProCareerGoalOutcome.entries, { it.wire }, "pro.journey.outcome")
    private fun contractKind(value: String) = fromWire(value, ProContractKind.entries, { it.wire }, "pro.journey.contract_kind")
    private fun role(value: String) = fromWire(value, ProRole.entries, { it.wire }, "pro.journey.role")
    private fun outlook(value: String) = fromWire(value, ProTeamOutlook.entries, { it.wire }, "pro.journey.outlook")
    private fun expectationKind(value: String) = fromWire(value, ProContractExpectationKind.entries, { it.wire }, "pro.journey.expectation_kind")
    private fun difficulty(value: String) = fromWire(value, ProExpectationDifficulty.entries, { it.wire }, "pro.journey.difficulty")
    private fun marketKind(value: String) = fromWire(value, ProContractMarketKind.entries, { it.wire }, "pro.journey.market_kind")
    private fun recognitionKind(value: String) = fromWire(value, ProCareerRecognitionKind.entries, { it.wire }, "pro.journey.recognition_kind")
    private fun financeKind(value: String) = fromWire(value, ProFinanceTransactionKind.entries, { it.wire }, "pro.journey.finance_kind")
    private fun benefitKind(value: String) = fromWire(value, ProSeasonBenefitKind.entries, { it.wire }, "pro.journey.benefit_kind")
    private fun fanKind(value: String) = fromWire(value, ProFanReasonKind.entries, { it.wire }, "pro.journey.fan_kind")
    private fun metricKind(value: String) = fromWire(value, ProCareerGoalMetricKind.entries, { it.wire }, "pro.journey.metric_kind")
    private fun settlementRoute(value: String) = fromWire(value, ProSettlementNextRoute.entries, { it.wire }, "pro.journey.route")
    private fun transitionRoute(value: String) = fromWire(value, ProOffseasonTransitionRoute.entries, { it.wire }, "pro.journey.transition_route")
    private fun honorKind(value: String) = fromWire(value, ProRetirementHonorKind.entries, { it.wire }, "pro.journey.honor_kind")
    private fun migrationSource(value: String) = fromWire(value, ProJourneyMigrationSource.entries, { it.wire }, "pro.journey.migration_source")
    private fun merch(value: String) = fromWire(value, ProMerchandiseTier.entries, { it.wire }, "pro.journey.merch")

    private fun fail(code: String): Nothing = throw ProJourneyCodecException(code)
}

public class ProJourneyCodecException(message: String, cause: Throwable? = null) : IllegalArgumentException(message, cause)
