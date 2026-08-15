package com.solkim.baseball.core.pro

import com.solkim.baseball.model.Hashing
import com.solkim.baseball.model.JsonValue
import com.solkim.baseball.model.StrictJson
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class ProCareerFixtureTest {
    @Test
    fun committedCurrentSwiftMultiSeedFixtureMatchesKotlinProBoundary() {
        val root = StrictJson.parseUtf8(
            checkNotNull(javaClass.classLoader.getResourceAsStream("fixtures/swift-pro-career-oracle-v1.json")).readBytes(),
        ).asObject()
        assertEquals("baseball-pro-career-fixture-v1", root.string("fixtureSchema"))
        assertEquals("swift", root.string("sourceRuntime"))
        assertEquals("792d72859dc5dcfdc8cefa8b69ab50bc072c212f", root.string("sourceCommit"))
        assertEquals("78f6e4e41f638d6ef09bb961d5a731e412126ebfe0b94756b52763ef9885a982", root.string("inputSha256"))
        assertEquals("850ce637c48fa28b689effe52e2233961743fc1327728bdf3e12eada7f224d39", root.string("outputSha256"))
        assertEquals(
            root.string("inputSha256"),
            Hashing.sha256Hex(
                listOf(
                    "ProCareerEngine.Phase5Vertical", "start:linked", "preset:power_prospect", "team:proTeams[0]", "draftEvaluation:72",
                    "entitlement:active", "postStart:signContract", "week1:earnTrust", "decisionWeeks:6,13,20",
                    "maximumCareerSeasons:20", "maximumSeasonDecisions:3", "seeds:100..119", "locale:ko-KR", "timezone:Asia/Seoul",
                ).joinToString("|"),
            ),
        )

        val rows = root.objectValue("expected").array("rows").values
        assertEquals(20, rows.size)
        val canonical = StringBuilder()
        val kernel = ProKernel()
        rows.forEach { value ->
            val row = value.asObject()
            val seed = row.string("seed")
            val start = kernel.startLinked(
                ProStartLinkedRequest(
                    seed = seed,
                    highSchoolCareerId = "fixture-hs-$seed",
                    identityName = "민서준",
                    pitcher = ProCatalog.pitcherForPreset("power_prospect", "민서준"),
                    teamId = ProCatalog.teams.first().id,
                    draftEvaluation = 72,
                    entitlement = ProEntitlement(active = true, source = "development", verifiedAt = "2026-07-22"),
                    activeHighSchoolPreserved = true,
                ),
            )
            assertEquals(row.string("careerID"), start.state.careerId, "seed=$seed career")
            assertEquals(row.string("startNextSeed"), start.nextSeed, "seed=$seed start seed")
            assertEquals(row.string("teamID"), start.state.team.id, "seed=$seed team")

            val signed = kernel.signContract(start.state, start.nextSeed)
            assertEquals(row.integer("signedRevision").toULong(), signed.state.revision, "seed=$seed revision")
            assertEquals(row.string("signedNextSeed"), signed.nextSeed, "seed=$seed contract seed")

            val firstWeek = kernel.planWeek(signed.state, signed.nextSeed, ProWeekPlan.EARN_TRUST)
            assertEquals(row.string("firstWeekNextSeed"), firstWeek.nextSeed, "seed=$seed week seed")
            assertEquals(row.string("phase"), firstWeek.state.phase.wire, "seed=$seed phase")
            assertEquals(row.string("level"), firstWeek.state.level.wire, "seed=$seed level")
            assertEquals(row.string("role"), firstWeek.state.role.wire, "seed=$seed role")
            assertEquals(row.string("segment"), firstWeek.state.seasonSegment.wire, "seed=$seed segment")
            assertEquals(row.integers("firstWeekStats"), listOf(
                firstWeek.state.currentStats.games, firstWeek.state.currentStats.starts, firstWeek.state.currentStats.inningsOuts,
                firstWeek.state.currentStats.strikeouts, firstWeek.state.currentStats.walks, firstWeek.state.currentStats.runsAllowed,
                firstWeek.state.currentStats.hits, firstWeek.state.currentStats.pitches,
            ), "seed=$seed stats")
            assertEquals(listOf(6, 13, 20), row.integers("decisionWeeks"), "seed=$seed decision schedule")
            assertEquals(20, row.integer("maximumCareerSeasons"))
            assertEquals(3, row.integer("maximumSeasonDecisions"))

            canonical.append(seed).append('|')
                .append(row.string("careerID")).append('|')
                .append(row.string("startNextSeed")).append('|')
                .append(row.string("teamID")).append('|')
                .append(row.integer("signedRevision")).append('|')
                .append(row.string("signedNextSeed")).append('|')
                .append(row.string("firstWeekNextSeed")).append('|')
                .append(row.integers("firstWeekStats").joinToString(",")).append('|')
                .append(row.string("phase")).append('|').append(row.string("level")).append('|')
                .append(row.string("role")).append('|').append(row.string("segment")).append('|')
                .append(row.integers("decisionWeeks").joinToString(",")).append('|')
                .append(row.integer("maximumCareerSeasons")).append('|')
                .append(row.integer("maximumSeasonDecisions")).append('\n')
        }
        assertEquals(root.string("outputSha256"), Hashing.sha256Hex(canonical.toString()))
    }

    @Test
    fun directTeamSelectionIsStableAndCoversTheFullFrozenCatalog() {
        val first = (0 until 10_000).map { ProCatalog.teamForSeed(it.toULong()).id }
        assertEquals(first, (0 until 10_000).map { ProCatalog.teamForSeed(it.toULong()).id })
        assertEquals(ProCatalog.teams.map { it.id }.toSet(), first.toSet())
        assertTrue(first.size == 10_000)
    }

    private fun JsonValue.asObject(): JsonValue.Obj = this as JsonValue.Obj
    private fun JsonValue.Obj.string(name: String): String = (entries[name] as JsonValue.Str).value
    private fun JsonValue.Obj.integer(name: String): Int = (entries[name] as JsonValue.Num).raw.toInt()
    private fun JsonValue.Obj.objectValue(name: String): JsonValue.Obj = entries.getValue(name).asObject()
    private fun JsonValue.Obj.array(name: String): JsonValue.Arr = entries.getValue(name) as JsonValue.Arr
    private fun JsonValue.Obj.integers(name: String): List<Int> = array(name).values.map { (it as JsonValue.Num).raw.toInt() }
}
