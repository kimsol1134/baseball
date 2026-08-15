package com.solkim.baseball.core.pro

import com.solkim.baseball.model.Hashing
import com.solkim.baseball.model.JsonValue
import com.solkim.baseball.model.StrictJson
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotNull
import kotlin.test.assertTrue

/** Exact Swift-authority hash and semantic parity checks for the checked-in Wave 6 fixture. */
class ProCareerWave6FixtureParityTest {
    @Test
    fun swiftV2FixtureHashesAndSemanticRowsAreStable() {
        val root = fixture()
        assertEquals("baseball-pro-career-fixture-v2", root.string("fixtureSchema"))
        assertEquals("swift", root.string("sourceRuntime"))
        assertEquals("ece04be7d1f0c1ba5e46ca011381c70d255a00cf3b133e46f3f9abfe30b3c14f", root.string("inputSha256"))
        assertEquals("c32a97361e4d9e447872322e0d7eceeb53f30c7294c432ee8643301cdbb6dab0", root.string("outputSha256"))
        val rows = root.obj("expected").array("rows").values.map { it.asObj() }
        assertEquals(10, rows.size)

        rows.forEach { row ->
            val input = row.string("inputCanonical")
            val output = row.string("outputCanonical")
            assertEquals(row.string("inputSha256"), Hashing.sha256Hex(input))
            assertEquals(row.string("outputSha256"), Hashing.sha256Hex(output))
            assertEquals(row.string("outputSha256"), row.string("wireCommitment"))
        }

        val byCase = rows.associateBy { it.string("caseID") }
        val rookie = byCase.getValue("rookie_contract")
        val rookieOutput = rookie.obj("output")
        assertEquals("rookie", rookieOutput.string("contractKind"))
        assertEquals(3, rookieOutput.int("years"))
        assertEquals(60_000_000L, rookieOutput.long("annualSalary"))
        assertEquals(120_000_000L, rookieOutput.long("signingBonus"))
        assertEquals("weekly_plan", rookieOutput.string("phase"))
        assertTrue(rookieOutput.string("offerID").startsWith("offer:${rookieOutput.string("marketID")}:"))

        val settlement = byCase.getValue("season_settlement").obj("output")
        assertEquals(60_000_000L, settlement.long("salaryIncome"))
        assertEquals(10_000_000L, settlement.long("merchandiseIncome"))
        assertEquals(20, settlement.int("fanBefore"))
        assertEquals(29, settlement.int("fanAfter"))
        assertEquals(9, (settlement.int("fanAfter") - settlement.int("fanBefore")).coerceIn(-12, 20))
        assertEquals(14, settlement.int("teamLegacyAfter"))
        assertEquals(11, settlement.int("hallOfFameAfter"))
        assertEquals("under_contract", settlement.string("nextRoute"))

        val investment = byCase.getValue("investment").obj("output")
        assertEquals(-50_000_000L, investment.long("amount"))
        assertEquals(140_000_000L, investment.long("availableFunds"))
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
            assertTrue(ProJourneyKernel.isNonDominated(parsed.offers))
        }

        val media = byCase.getValue("fan_finance_media").obj("output")
        assertEquals("media_opportunity.fan_together_shoot", media.string("mediaChoiceID"))
        assertEquals(10_000_000L, media.long("endorsementAmount"))
        assertTrue(media.int("fanSupport") >= 35)
        assertEquals(6, media.int("communityPoints"))

        val legacy = byCase.getValue("team_legacy_ambition_honors").obj("output")
        assertEquals(2, legacy.int("teamSeasons"))
        assertEquals(38, legacy.int("teamLegacy"))
        assertFalse(legacy.bool("retiredNumberEligible"))
        assertTrue(legacy.array("honorKinds").values.any { (it as JsonValue.Str).value == "career_earnings" })

        val migration = byCase.getValue("legacy_migration").obj("output")
        assertEquals("legacy_safe_boundary", migration.string("source"))
        assertEquals(1, migration.int("financeStartsSeason"))
        assertTrue(migration.bool("financeNoticePending"))
        assertEquals(1, migration.int("salaryTransactions"))

        val errors = byCase.getValue("command_errors").obj("output").array("errorIDs").values.map { (it as JsonValue.Str).value }
        assertEquals(listOf("stale_revision_or_market", "invalid_offer", "invalid_settlement"), errors)
        assertEquals("b040a7ecde7d66af6e61134f9b8419fb527725988d29fa69a4aee9b625b11f22", byCase.getValue("deterministic_next_seed_commitment").obj("output").string("replayCanonicalSha256"))
    }

    private fun fixture(): JsonValue.Obj = StrictJson.parseUtf8(
        checkNotNull(javaClass.classLoader.getResourceAsStream("fixtures/swift-pro-career-oracle-v2.json")).readBytes(),
    ).asObj()

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
