package com.solkim.baseball.core.pro

import com.solkim.baseball.model.JsonValue
import com.solkim.baseball.model.Hashing
import com.solkim.baseball.model.StrictJson
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotEquals
import kotlin.test.assertTrue

/** Android's current Pro aggregate is still legacy-shaped; this test covers the read-only oracle. */
class ProContractMarketWave3FixtureTest {
    @Test
    fun currentSwiftWave3MarketRowsRoundTripAndKeepStableTradeoffs() {
        val root = StrictJson.parseUtf8(
            checkNotNull(javaClass.classLoader.getResourceAsStream("fixtures/swift-pro-career-contract-wave3-oracle-v1.json")).readBytes(),
        ).asObject()
        assertEquals("baseball-pro-career-contract-wave3-fixture-v1", root.string("fixtureSchema"))
        assertEquals("swift", root.string("sourceRuntime"))
        assertEquals("2302efd0478c0c23460bcdb7e4799b84d75fda0fc5ca1e592917d348fec6026a", root.string("inputSha256"))
        assertEquals("90cdfa40a3ec307731168efc145b16e3291ff96791372438edcf020db33554d2", root.string("outputSha256"))

        val rows = root.obj("expected").array("rows").values.map {
            ProContractMarketWave3Codec.decodeRow(it.asObject())
        }
        assertEquals(8, rows.size)
        rows.forEach { row ->
            assertEquals("market:${row.careerId}:${row.forSeason}:${row.kind.wire}", row.marketId)
            assertTrue(row.marketScore in 0..100)
            assertTrue(row.maximumCareerSeasons >= row.forSeason)
            assertEquals(if (row.kind == ProWave3MarketKind.RENEWAL) 2 else 3, row.offers.size)
            assertEquals(row.offers.size, row.offers.map { it.id }.toSet().size)
            assertTrue(row.offers.all { it.signingBonus == null && it.years in 1..4 && it.annualSalary % 10_000_000 == 0 })
            assertTrue(row.offers.all { it.id == "offer:${row.marketId}:${it.teamId}:${it.contractKind.wire}" })

            if (row.kind == ProWave3MarketKind.RENEWAL) {
                assertTrue(row.offers.all { it.teamId == row.currentTeamId && it.preservesTeamLegacy })
                assertEquals(setOf(ProWave3ContractKind.RENEWAL_LONG, ProWave3ContractKind.PROVE_IT), row.offers.map { it.contractKind }.toSet())
            } else {
                assertEquals(row.currentTeamId, row.offers.first().teamId)
                assertEquals(3, row.offers.map { it.teamId }.toSet().size)
                assertTrue(row.offers.drop(1).any { it.teamId != row.currentTeamId })
            }

            val roundTrip = ProContractMarketWave3Codec.decodeRow(
                ProContractMarketWave3Codec.encodeRow(row),
            )
            assertEquals(row, roundTrip)
            assertNotEquals("", ProContractMarketWave3Codec.canonicalRow(roundTrip))
        }

        val canonical = rows.joinToString(separator = "") { row ->
            buildString {
                append(row.seed).append('|').append(row.kind.wire).append('|').append(row.careerId).append('|')
                append(row.forSeason).append('|').append(row.generatedAtRevision).append('|').append(row.currentTeamId).append('|')
                append(row.currentRole.wire).append('|').append(row.level.wire).append('|').append(row.marketScore).append('|')
                append(row.serviceYears).append('|').append(row.age).append('|').append(row.maximumCareerSeasons).append('|')
                append(row.marketId).append('|')
                append(row.offers.joinToString(";") { offer ->
                    listOf(
                        offer.id, offer.teamId, offer.years.toString(), offer.annualSalary.toString(),
                        offer.contractKind.wire, offer.rolePromise.wire, offer.outlook,
                        offer.expectation.kind, offer.expectation.target.toString(), offer.expectation.difficulty,
                        offer.preservesTeamLegacy.toString(),
                    ).joinToString(":")
                })
                append('\n')
            }
        }
        assertEquals(root.string("outputSha256"), Hashing.sha256Hex(canonical))
    }

    private fun JsonValue.asObject(): JsonValue.Obj = this as JsonValue.Obj
    private fun JsonValue.Obj.string(name: String): String = (entries[name] as JsonValue.Str).value
    private fun JsonValue.Obj.obj(name: String): JsonValue.Obj = entries.getValue(name).asObject()
    private fun JsonValue.Obj.array(name: String): JsonValue.Arr = entries.getValue(name) as JsonValue.Arr
}
