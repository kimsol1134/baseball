package com.solkim.baseball.core.pro

import com.solkim.baseball.model.Hashing
import com.solkim.baseball.model.JsonValue
import com.solkim.baseball.model.StrictJson
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

/** Exact Swift-authority hash and semantic parity checks for the checked-in Wave 6 fixture. */
class ProCareerWave6FixtureParityTest {
    @Test
    fun swiftV2FixtureHashesAndSemanticRowsAreStable() {
        val root = fixture()
        assertEquals("baseball-pro-career-fixture-v2", root.string("fixtureSchema"))
        assertEquals("swift", root.string("sourceRuntime"))
        assertNoCommitmentLikeKeys(root)
        assertFalse(root.entries.containsKey("expected"), "v2 must not use the legacy expected.rows envelope")
        val rows = root.array("cases").values.map { it.asObj() }
        assertEquals(11, rows.size)

        val input = root.obj("input")
        val caseIds = inputCaseOrder(root)
        val inputCanonical = listOf(
            "fixture=${input.string("fixture")}",
            "journeyEnabled=${input.bool("journeyEnabled")}",
            "commands=${input.array("commandWire").strings().joinToString(",")}",
            "cases=${caseIds.joinToString(",")}",
            "canonicalFields=semantic-inputs,actual-command-output,stable-error-id",
            "locale=${input.string("locale")}",
            "timezone=${input.string("timezone")}",
        ).joinToString("|")
        assertEquals(root.string("inputSha256"), Hashing.sha256Hex(inputCanonical))

        val outputCanonical = rows.joinToString("") { "${it.string("caseID")}|${it.string("outputCanonical")}\n" }
        assertEquals(root.string("outputSha256"), Hashing.sha256Hex(outputCanonical))
        assertEquals("SHA-256(UTF-8(inputCanonical))", root.obj("canonicalization").string("inputHash"))
        assertEquals("SHA-256(UTF-8(outputCanonical))", root.obj("canonicalization").string("caseOutputHash"))

        rows.forEach { row ->
            val input = row.string("inputCanonical")
            val output = row.string("outputCanonical")
            assertEquals(row.string("inputSha256"), Hashing.sha256Hex(input))
            assertEquals(row.string("outputSha256"), Hashing.sha256Hex(output))
            assertTrue(row.string("hashReason").contains("SHA-256"))
            assertTrue(row.entries.keys.none { it.lowercase().contains("commit") })
        }

        val byCase = rows.associateBy { it.string("caseID") }
        val rookie = byCase.getValue("rookie_contract")
        val rookieOutput = rookie.obj("output")
        assertEquals("rookie", rookieOutput.string("contractKind"))
        assertEquals(3, rookieOutput.int("years"))
        assertEquals(60_000_000L, rookieOutput.long("annualSalary"))
        assertEquals(120_000_000L, rookieOutput.long("signingBonus"))
        assertEquals("weekly_plan", rookieOutput.string("phase"))
        assertEquals(
            "offer:${rookieOutput.string("marketID")}:${rookieOutput.string("teamID")}:rookie",
            rookieOutput.string("offerID"),
        )

        val settlement = byCase.getValue("season_settlement").obj("output")
        assertEquals(rookieOutput.long("annualSalary"), settlement.long("salaryIncome"))
        assertEquals((settlement.int("fanBefore") * 500_000L).coerceAtMost(50_000_000L), settlement.long("merchandiseIncome"))
        assertEquals(settlement.int("fanAfter") - settlement.int("fanBefore"), settlement.int("fanDelta"))
        assertTrue(settlement.int("fanDelta") in -12..20)
        assertEquals(settlement.int("contractYearsBefore") - 1, settlement.int("contractYearsAfter"))
        assertTrue(settlement.int("teamLegacyBefore") in 0..100)
        assertTrue(settlement.int("teamLegacyAfter") in 0..100)
        assertTrue(settlement.int("hallOfFameBefore") in 0..100)
        assertTrue(settlement.int("hallOfFameAfter") in 0..100)
        assertEquals("under_contract", settlement.string("nextRoute"))

        val investment = byCase.getValue("investment").obj("output")
        assertEquals(-50_000_000L, investment.long("amount"))
        assertEquals(
            rookieOutput.long("signingBonus") + settlement.long("salaryIncome") + settlement.long("merchandiseIncome") + investment.long("amount"),
            investment.long("availableFunds"),
        )
        assertEquals(2, investment.int("investmentSeason"))
        assertEquals("pitch_lab", investment.string("transactionID").substringAfterLast(':'))
        assertEquals("weekly_plan", investment.string("phase"))

        val renewal = byCase.getValue("renewal_market").obj("output")
        assertEquals("renewal", renewal.string("kind"))
        assertEquals(2, renewal.int("offerCount"))
        assertEquals(2, renewal.array("canonicalRows").values.size)
        assertTrue(renewal.array("canonicalRows").values.all { (it as JsonValue.Str).value.contains(":renewal:") })

        val freeAgency = byCase.getValue("free_agency_market").obj("output")
        assertEquals("free_agency", freeAgency.string("kind"))
        assertEquals(3, freeAgency.int("offerCount"))
        assertEquals(3, freeAgency.array("teams").values.map { (it as JsonValue.Str).value }.toSet().size)
        listOf(byCase.getValue("renewal_market"), byCase.getValue("free_agency_market")).forEach { marketRow ->
            val parsed = decodeMarketCanonical(marketRow.string("outputCanonical"))
            assertEquals(marketRow.string("outputCanonical"), ProJourneyKernel.canonicalMarket(parsed))
            assertEquals(if (parsed.kind == ProContractMarketKind.RENEWAL) 2 else 3, parsed.offers.size)
            assertEquals(parsed.offers.map { it.id }, parsed.offers.map { it.id }.distinct())
            assertTrue(ProJourneyKernel.isNonDominated(parsed.offers))
        }

        val media = byCase.getValue("fan_finance_media").obj("output")
        assertEquals("media_opportunity.fan_together_shoot", media.string("mediaChoiceID"))
        assertEquals(10_000_000L, media.long("endorsementAmount"))
        assertTrue(media.int("fanSupport") >= 35)
        assertEquals(6, media.int("communityPoints"))
        assertTrue(media.string("endorsementTransactionID").contains(":2:"))

        val legacy = byCase.getValue("team_legacy_ambition_honors").obj("output")
        assertEquals(1, legacy.int("teamSeasons"))
        assertTrue(legacy.int("teamLegacy") in 0..100)
        assertFalse(legacy.bool("retiredNumberEligible"))
        assertTrue(legacy.int("teamSeasons") < 8)
        assertTrue(legacy.array("honorKinds").values.any { (it as JsonValue.Str).value == "career_earnings" })

        val migration = byCase.getValue("legacy_migration").obj("output")
        assertEquals("legacy_safe_boundary", migration.string("source"))
        assertEquals(migration.int("initializedSeason") + 1, migration.int("financeStartsSeason"))
        assertTrue(migration.bool("financeNoticePending"))
        assertEquals(0, migration.int("salaryTransactions"))

        val commandErrors = byCase.getValue("command_errors")
        val errors = commandErrors.obj("output").array("errorIDs").strings()
        assertEquals(listOf("stale_revision", "invalid_offer", "invalid_settlement"), errors)
        assertEquals(errors.joinToString("|"), commandErrors.string("outputCanonical"))

        val replay = byCase.getValue("deterministic_replay_hash")
        assertEquals(Hashing.sha256Hex(replay.string("outputCanonical")), replay.obj("output").string("semanticReplaySha256"))

        val retirement = byCase.getValue("real_retirement_command").obj("output")
        assertEquals("completed", retirement.string("phase"))
        assertEquals(20, retirement.int("completedSeasons"))
        assertEquals("choose_offseason.retire", retirement.string("actualRetirementCommand"))
        assertEquals("maximum_season_evaluation_horizon", retirement.string("retirementMode"))
        assertFalse(retirement.bool("voluntaryRetirement"))
        assertEquals(retirement.array("selectedOffers").values.size, retirement.array("selectedAmbitions").values.size)
        assertEquals(
            retirement.array("completedAmbitions").values.size == 3,
            retirement.bool("allThreeAmbitionsCompleted"),
        )
        assertEquals(20, retirement.obj("commandCounts").int("acknowledge_settlement"))
        assertEquals(20, retirement.obj("commandCounts").int("review_season"))
        assertTrue(retirement.bool("retirementProjectionMatchesCommand"))
    }

    private fun fixture(): JsonValue.Obj = StrictJson.parseUtf8(
        checkNotNull(javaClass.classLoader.getResourceAsStream("fixtures/swift-pro-career-oracle-v2.json")).readBytes(),
    ).asObj()

    private fun assertNoCommitmentLikeKeys(value: JsonValue, path: String = "$") {
        when (value) {
            is JsonValue.Obj -> value.entries.forEach { (key, nested) ->
                assertFalse(key.lowercase().contains("commit"), "commitment-like key at $path.$key")
                assertNoCommitmentLikeKeys(nested, "$path.$key")
            }
            is JsonValue.Arr -> value.values.forEachIndexed { index, nested ->
                assertNoCommitmentLikeKeys(nested, "$path[$index]")
            }
            else -> Unit
        }
    }

    private fun JsonValue.asObj(): JsonValue.Obj = this as JsonValue.Obj
    private fun JsonValue.Obj.string(name: String): String = (entries[name] as JsonValue.Str).value
    private fun JsonValue.Obj.int(name: String): Int = stringNumber(name).toInt()
    private fun JsonValue.Obj.long(name: String): Long = stringNumber(name).toLong()
    private fun JsonValue.Obj.bool(name: String): Boolean = (entries[name] as JsonValue.Bool).value
    private fun JsonValue.Obj.stringNumber(name: String): String = when (val value = entries[name]) {
        is JsonValue.Num -> value.raw
        is JsonValue.Str -> value.value
        else -> error("missing $name")
    }
    private fun JsonValue.Obj.obj(name: String): JsonValue.Obj = (entries[name] as JsonValue.Obj)
    private fun JsonValue.Obj.array(name: String): JsonValue.Arr = entries[name] as JsonValue.Arr
    private fun JsonValue.Arr.strings(): List<String> = values.map { (it as JsonValue.Str).value }

    private fun inputCaseOrder(root: JsonValue.Obj): List<String> = root.obj("input").array("caseOrder").strings()

    private fun decodeMarketCanonical(value: String): ProContractMarket {
        val fields = value.split('|', limit = 5)
        val offers = fields[4].split(';').map { encoded ->
            val parts = encoded.split(':')
            require(parts.size == 18 && parts[0] == "offer")
            ProContractOffer(
                id = parts.take(7).joinToString(":"),
                teamId = parts[7],
                years = parts[8].toInt(),
                annualSalary = parts[9].toLong(),
                signingBonus = parts[10].takeUnless { it == "-" }?.toLong(),
                contractKind = ProContractKind.entries.first { it.wire == parts[11] },
                rolePromise = ProRole.entries.first { it.wire == parts[12] },
                outlook = ProTeamOutlook.entries.first { it.wire == parts[13] },
                expectation = ProContractExpectation(
                    ProContractExpectationKind.entries.first { it.wire == parts[14] },
                    parts[15].toInt(),
                    ProExpectationDifficulty.entries.first { it.wire == parts[16] },
                ),
                preservesTeamLegacy = parts[17] == "1",
            )
        }
        return ProContractMarket(
            id = fields[0], kind = ProContractMarketKind.entries.first { it.wire == fields[1] }, forSeason = fields[2].toInt(),
            generatedAtRevision = fields[3].toULong(), offers = offers,
        )
    }
}
