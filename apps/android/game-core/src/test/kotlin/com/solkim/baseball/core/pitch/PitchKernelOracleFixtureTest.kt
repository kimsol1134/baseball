package com.solkim.baseball.core.pitch

import com.solkim.baseball.model.Hashing
import com.solkim.baseball.model.JsonValue
import com.solkim.baseball.model.StrictJson
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import java.util.Locale
import java.util.TimeZone

class PitchKernelOracleFixtureTest {
    @Test
    fun frozenCSharpOracleIsRetainedWithItsHistoricalHashes() {
        val fixture = fixtureObject()
        assertEquals("baseball-cross-runtime-fixture-v1", fixture.string("fixtureSchema"))
        assertEquals("csharp", fixture.string("sourceRuntime"))
        assertEquals("23acbb8ec233836e802009c8852c430e08075d3c", fixture.string("sourceCommit"))
        assertEquals("d61eb1b2b39628f55e9318a062628ee71f941de979ccf0f360ccaa5dc1b1b2ce", fixture.string("inputSha256"))
        assertEquals("1be138df2264c62481590ca4c1bfe1ad9072ff45a30b14531316906fcc9127fe", fixture.string("outputSha256"))

        val expected = fixture.objectValue("expected")
        assertEquals(128, expected.number("exactRuns"))
        assertEquals("56b7c99922f1d66d", expected.string("canonicalRowsFnv1a64"))
        assertEquals(128, expected.array("rows").values.size)
        assertEquals(10_000, expected.objectValue("distribution").entries.values.sumOf { it.asNumber() })
    }

    @Test
    fun currentSwiftOracleMatches128RowsAndTenThousandDistribution() {
        val fixture = fixtureObject("fixtures/swift-pitch-kernel-current-v1.json")
        assertEquals("baseball-cross-runtime-fixture-v1", fixture.string("fixtureSchema"))
        assertEquals("swift", fixture.string("sourceRuntime"))
        assertEquals("792d72859dc5dcfdc8cefa8b69ab50bc072c212f", fixture.string("sourceCommit"))
        assertEquals("d61eb1b2b39628f55e9318a062628ee71f941de979ccf0f360ccaa5dc1b1b2ce", fixture.string("inputSha256"))
        assertEquals("37d86e69406862d434a4304f929dd8725502e4d7dc53cb9f73dddd6dd36fbcc6", fixture.string("outputSha256"))

        val expected = fixture.objectValue("expected")
        assertEquals(128, expected.number("exactRuns"))
        assertEquals("63c42bbba86d7410", expected.string("canonicalRowsFnv1a64"))
        val expectedRows = expected.array("rows").values.map { it.asObject() }
        assertEquals(128, expectedRows.size)

        val outcomes = linkedMapOf<String, Int>()
        val canonical = StringBuilder()
        for (seed in 1..10_000) {
            val request = fixtureRequest(seed.toString())
            val kernel = PitchKernel()
            val preparation = kernel.prepare(request)
            val result = kernel.submit(
                PitchKernel.SubmitRequest(
                    seed = request.seed,
                    pitcher = request.pitcher,
                    batter = request.batter,
                    scouting = request.scouting,
                    context = request.context,
                    preparationToken = preparation.preparationToken,
                    call = preparation.primaryRecommendation.call,
                ),
            )
            outcomes[result.snapshot.outcome.wire] = (outcomes[result.snapshot.outcome.wire] ?: 0) + 1
            if (seed <= 128) {
                val row = expectedRows[seed - 1]
                assertEquals(row.string("seed"), seed.toString())
                assertEquals(row.string("outcome"), result.snapshot.outcome.wire, "seed=$seed")
                assertEquals(row.number("actualX"), result.snapshot.execution.actualX, "seed=$seed")
                assertEquals(row.number("actualY"), result.snapshot.execution.actualY, "seed=$seed")
                assertEquals(row.number("velocityTenthsKph"), result.snapshot.execution.velocityTenthsKph, "seed=$seed")
                assertEquals(row.string("eventHash"), result.eventHash, "seed=$seed")
                canonical.append(seed).append('|')
                    .append(result.snapshot.outcome.wire).append('|')
                    .append(result.snapshot.execution.actualX).append('|')
                    .append(result.snapshot.execution.actualY).append('|')
                    .append(result.snapshot.execution.velocityTenthsKph).append('|')
                    .append(result.eventHash).append('\n')
            }
        }
        assertEquals("63c42bbba86d7410", Hashing.fnv1a64Hex(canonical.toString()))
        val expectedDistribution = expected.objectValue("distribution").entries.mapValues { it.value.asNumber() }
        assertEquals(expectedDistribution, outcomes)
    }

    @Test
    fun preparationAndSubmissionAreLocaleAndTimezoneInvariant() {
        val originalLocale = Locale.getDefault()
        val originalTimezone = TimeZone.getDefault()
        try {
            val request = fixtureRequest("20260721")
            Locale.setDefault(Locale.US)
            TimeZone.setDefault(TimeZone.getTimeZone("UTC"))
            val utc = submit(request)
            Locale.setDefault(Locale.KOREA)
            TimeZone.setDefault(TimeZone.getTimeZone("Asia/Seoul"))
            val seoul = submit(request)
            assertEquals(utc, seoul)
        } finally {
            Locale.setDefault(originalLocale)
            TimeZone.setDefault(originalTimezone)
        }
    }

    @Test
    fun approvedSwiftPitchSummaryAgreesWithTheFrozenCSharpExport() {
        val fixture = fixtureObject("fixtures/swift-pitch-kernel-approved-v2.json")
        assertEquals("swift", fixture.string("sourceRuntime"))
        assertEquals("23acbb8ec233836e802009c8852c430e08075d3c", fixture.string("sourceCommit"))
        assertEquals("d61eb1b2b39628f55e9318a062628ee71f941de979ccf0f360ccaa5dc1b1b2ce", fixture.string("inputSha256"))
        assertEquals("1be138df2264c62481590ca4c1bfe1ad9072ff45a30b14531316906fcc9127fe", fixture.string("outputSha256"))
        val expected = fixture.objectValue("expected")
        assertEquals(128, expected.number("exactRuns"))
        assertEquals("56b7c99922f1d66d", expected.string("canonicalRowsFnv1a64"))
        assertEquals(10_000, expected.objectValue("distribution").entries.values.sumOf { it.asNumber() })
    }

    @Test
    fun staleTokenAndInvalidDeliveryFailClosed() {
        val request = fixtureRequest("20260721")
        val preparation = PitchKernel().prepare(request)
        assertFailsWith<PitchKernelException> {
            PitchKernel().submit(
                PitchKernel.SubmitRequest(
                    request.seed, request.pitcher, request.batter, request.scouting, request.context,
                    preparation.preparationToken + "-stale", preparation.primaryRecommendation.call,
                ),
            )
        }
        assertFailsWith<PitchKernelException> {
            PitchKernel().submit(
                PitchKernel.SubmitRequest(
                    request.seed, request.pitcher, request.batter, request.scouting, request.context,
                    preparation.preparationToken, preparation.primaryRecommendation.call,
                ),
                PitchDelivery(1001, 500),
            )
        }
    }

    private fun submit(request: PitchKernel.PrepareRequest): PitchKernelResult {
        val kernel = PitchKernel()
        val preparation = kernel.prepare(request)
        return kernel.submit(
            PitchKernel.SubmitRequest(
                request.seed, request.pitcher, request.batter, request.scouting, request.context,
                preparation.preparationToken, preparation.primaryRecommendation.call,
            ),
        )
    }

    private fun fixtureRequest(seed: String): PitchKernel.PrepareRequest = PitchKernel.PrepareRequest(
        seed = seed,
        pitcher = PitcherSnapshot("pitcher-1", "테스트투수", 62, 54, 58, 60),
        batter = BatterSnapshot("batter-1", "이준호", 56, 52, 58),
        scouting = BatterScoutingSnapshot(PitchZone(1, 1), PitchZone(2, 0), PitchKind.FOUR_SEAM, PitchKind.SLIDER, 48),
        context = PlateAppearanceContext("pa-1", 0UL, 7, 0, 1, 1, 1, 0, 600, 12),
    )

    private fun fixtureObject(resource: String = "fixtures/csharp-pitch-oracle-v1.json"): JsonValue.Obj {
        val stream = checkNotNull(javaClass.classLoader.getResourceAsStream(resource))
        return StrictJson.parseUtf8(stream.readBytes()).asObject()
    }

    private fun JsonValue.asObject(): JsonValue.Obj = this as? JsonValue.Obj ?: error("object expected")
    private fun JsonValue.asNumber(): Int = (this as JsonValue.Num).raw.toInt()
    private fun JsonValue.Obj.string(name: String): String = (entries[name] as JsonValue.Str).value
    private fun JsonValue.Obj.number(name: String): Int = (entries[name] as JsonValue.Num).raw.toInt()
    private fun JsonValue.Obj.objectValue(name: String): JsonValue.Obj = entries.getValue(name).asObject()
    private fun JsonValue.Obj.array(name: String): JsonValue.Arr = entries.getValue(name) as JsonValue.Arr
}
