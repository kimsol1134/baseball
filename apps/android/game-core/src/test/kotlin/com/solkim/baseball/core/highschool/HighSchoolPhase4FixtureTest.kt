package com.solkim.baseball.core.highschool

import com.solkim.baseball.model.Hashing
import com.solkim.baseball.model.JsonValue
import com.solkim.baseball.model.StrictJson
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class HighSchoolPhase4FixtureTest {
    @Test
    fun committedCurrentSwiftFixtureIsStructuredAndMatchesKotlinCoreMetaBoundary() {
        val bytes = javaClass.getResourceAsStream("/fixtures/swift-high-school-phase4-oracle-v3.json")!!.readBytes()
        val root = StrictJson.parseUtf8(bytes) as JsonValue.Obj
        assertEquals("baseball-high-school-phase4-fixture-v3", root.string("fixtureSchema"))
        assertEquals("swift", root.string("sourceRuntime"))
        assertEquals("792d72859dc5dcfdc8cefa8b69ab50bc072c212f", root.string("sourceCommit"))
        val inputCanonical = listOf(
            "HighSchoolCareerEngine.Phase4Vertical",
            "preset:power_prospect", "school:haedong_power", "focus:command", "intensity:standard", "relationship:listen",
            "game:pitches18|strikeouts2|walks0|runs0|expected400|actual250|accepted12|outs3|sequence4|hits0",
            "awakening:first_available", "locale:ko-KR", "timezone:Asia/Seoul", "seeds:918220+17*n,n=0..19",
        ).joinToString("|")
        assertEquals(root.string("inputSha256"), Hashing.sha256Hex(inputCanonical))
        val input = root.obj("input")
        assertEquals("ko-KR", input.string("locale"))
        assertEquals("Asia/Seoul", input.string("timezone"))
        val rows = root.obj("expected").array("rows").values
        assertEquals(20, rows.size)
        val kernel = HighSchoolKernel()
        rows.forEach { item ->
            val row = item as JsonValue.Obj
            val vertical = runSourceBackedVertical(kernel, row.string("seed"))
            val state = vertical.state
            assertEquals(row.integer("trainingTotal"), state.schedule.trainingTotal)
            assertEquals(row.integer("relationshipTotal"), state.schedule.milestonesByChapter.flatten().count { it == HighSchoolPhase.RELATIONSHIP })
            assertEquals(row.integer("importantGameTotal"), state.schedule.milestonesByChapter.flatten().count { it == HighSchoolPhase.IMPORTANT_GAME })
            assertEquals(8, row.integer("chapter"))
            assertEquals(3, row.integer("selectedAwakenings"))
            assertEquals(5, row.integer("memoryOptionCount"))
            val starting = kernel.start(HighSchoolKernel.StartRequest(row.string("seed"), "power_prospect")).snapshot.pitcher
            val scored = HighSchoolSignatureLegacyRules.candidates(starting, state, requested = 6)
            val candidates = scored.take(3).map { it.definition.id }
            assertEquals(3, row.integer("signatureLegacyCandidateCount"))
            assertEquals(candidates, row.strings("signatureLegacyCandidateIDs"), "seed=${row.string("seed")} scores=${scored.map { it.definition.id + "=" + it.score }} pitcher=${state.pitcher} performance=${state.performance} trust=${state.managerTrust}/${state.catcherTrust}/${state.rivalTrust}")
            assertEquals(state.performance.importantGamesCompleted, row.integer("completedGames"))
            assertEquals(state.draftResult?.outcome?.wire ?: "none", row.string("draftOutcome"))
            assertEquals(row.integer("draftEvaluation"), state.draftResult?.evaluationScore ?: 0, "seed=${row.string("seed")} draft")
            assertEquals(
                row.integers("finalRatings"),
                listOf(state.pitcher.stuff, state.pitcher.command, state.pitcher.movement, state.pitcher.stamina),
                "seed=${row.string("seed")} ratings",
            )
            assertEquals(
                row.integers("performance"),
                listOf(
                    state.performance.importantGamesCompleted, state.performance.pitches, state.performance.strikeouts,
                    state.performance.walks, state.performance.runsAllowed, state.performance.expectedDamage,
                    state.performance.actualDamage,
                ),
                "seed=${row.string("seed")} performance",
            )
            assertEquals(row.integers("trust"), listOf(state.managerTrust, state.catcherTrust, state.rivalTrust), "seed=${row.string("seed")} trust")
            assertEquals(row.strings("relationshipCategories"), vertical.relationshipCategories, "seed=${row.string("seed")} relationship categories")
            assertEquals(row.strings("relationshipGrowth"), vertical.relationshipGrowth, "seed=${row.string("seed")} relationship growth")
            assertEquals(row.integers("automaticSummary").take(2), listOf(state.automaticOuts, state.automaticRunsAllowed), "seed=${row.string("seed")} automatic summary lines=${vertical.automaticLines}")
            assertEquals(row.integerArrays("automaticLines"), vertical.automaticLines, "seed=${row.string("seed")} automatic lines")
            assertEquals(row.integer("fanInterest"), state.fanInterest, "seed=${row.string("seed")} fan interest")
            assertTrue(row.string("phaseTrace").startsWith("prologue>school_selection>training"))
        }
        val canonicalRows = rows.joinToString("") { item ->
            val row = item as JsonValue.Obj
            listOf(
                row.string("seed"), row.string("phaseTrace"), row.integer("trainingTotal"),
                row.integer("relationshipTotal"), row.integer("importantGameTotal"), row.integer("completedGames"),
                row.integer("chapter"), row.integer("selectedAwakenings"), row.string("draftOutcome"),
                row.integer("draftEvaluation"), row.integer("memoryOptionCount"),
                row.integer("signatureLegacyCandidateCount"), row.strings("signatureLegacyCandidateIDs").joinToString(","),
                row.integers("finalRatings").joinToString(","), row.integers("performance").joinToString(","),
                row.integers("trust").joinToString(","), row.strings("relationshipCategories").joinToString(","),
                row.strings("relationshipGrowth").joinToString(","), row.integers("automaticSummary").joinToString(","),
                row.integerArrays("automaticLines").joinToString(",") { it.joinToString(":") },
                row.integer("fanInterest").toString(),
            ).joinToString("|") + "\n"
        }
        assertEquals(root.string("outputSha256"), Hashing.sha256Hex(canonicalRows))
    }

    private data class Vertical(
        val state: HighSchoolState,
        val relationshipCategories: List<String>,
        val relationshipGrowth: List<String>,
        val automaticLines: List<List<Int>>,
    )

    private fun runSourceBackedVertical(kernel: HighSchoolKernel, seed: String): Vertical {
        var result = kernel.start(HighSchoolKernel.StartRequest(seed, "power_prospect"))
        result = kernel.completePrologue(HighSchoolKernel.AdvanceRequest(result.nextSeed.toString(), result.snapshot))
        result = kernel.chooseSchool(
            HighSchoolKernel.ChooseSchoolRequest(result.nextSeed.toString(), result.snapshot, HighSchoolSchoolId.HAEDONG_POWER),
        )
        val relationshipCategories = mutableListOf<String>()
        val relationshipGrowth = mutableListOf<String>()
        val automaticLines = mutableListOf<List<Int>>()
        var guard = 0
        while (result.snapshot.phase != HighSchoolPhase.COMPLETED && guard++ < 500) {
            result = when (result.snapshot.phase) {
                HighSchoolPhase.TRAINING -> kernel.commitTraining(
                    HighSchoolKernel.TrainingRequest(
                        result.nextSeed.toString(), result.snapshot,
                        HighSchoolTrainingFocus.COMMAND, HighSchoolTrainingIntensity.STANDARD,
                    ),
                )
                HighSchoolPhase.RELATIONSHIP -> kernel.resolveRelationship(
                    HighSchoolKernel.RelationshipRequest(
                        result.nextSeed.toString(), result.snapshot, HighSchoolRelationshipResponse.LISTEN,
                    ).also {
                        relationshipCategories += result.snapshot.currentRelationshipCategory ?: "missing"
                    },
                )
                HighSchoolPhase.IMPORTANT_GAME -> kernel.recordImportantGame(
                    HighSchoolKernel.GameRequest(
                        result.nextSeed.toString(), result.snapshot,
                        HighSchoolGameReport(
                            scenarioNumber = result.snapshot.performance.importantGamesCompleted + 1,
                            pitches = 18, strikeouts = 2, walks = 0, runsAllowed = 0,
                            expectedDamage = 400, actualDamage = 250, recommendationAccepted = 12,
                            outs = 3, hits = 0, sequenceMasteryCount = 4,
                        ),
                    ),
                )
                HighSchoolPhase.AWAKENING -> kernel.chooseAwakening(
                    HighSchoolKernel.AwakeningRequest(
                        result.nextSeed.toString(), result.snapshot, result.snapshot.awakeningOptions.first(),
                    ),
                )
                HighSchoolPhase.CHAPTER_REVIEW -> {
                    automaticLines += HighSchoolAutomaticOutingSimulator()
                        .simulate(result.snapshot, result.snapshot.chapter, result.nextSeed.toULong())
                        .map { listOf(it.outs, it.runsAllowed, it.pitches, it.strikeouts, it.walks, it.hits) }
                    kernel.advanceChapter(HighSchoolKernel.AdvanceRequest(result.nextSeed.toString(), result.snapshot))
                }
                HighSchoolPhase.DRAFT -> kernel.resolveDraft(HighSchoolKernel.AdvanceRequest(result.nextSeed.toString(), result.snapshot))
                HighSchoolPhase.LEGACY -> kernel.selectLegacy(
                    HighSchoolKernel.LegacyRequest(
                        result.nextSeed.toString(), result.snapshot,
                        memoryCards = result.snapshot.legacyOptions.take(result.snapshot.memorySlots),
                    ),
                )
                else -> error("unexpected fixture phase ${result.snapshot.phase}")
            }.also { next ->
                if (result.snapshot.phase == HighSchoolPhase.RELATIONSHIP) {
                    relationshipGrowth += next.snapshot.lastRelationship?.growthFocus?.wire ?: "none"
                }
            }
        }
        assertTrue(guard < 500, "seed=$seed did not finish")
        return Vertical(result.snapshot, relationshipCategories, relationshipGrowth, automaticLines)
    }

    private fun JsonValue.Obj.string(name: String): String = (this[name] as JsonValue.Str).value
    private fun JsonValue.Obj.integer(name: String): Int = (this[name] as JsonValue.Num).raw.toInt()
    private fun JsonValue.Obj.obj(name: String): JsonValue.Obj = this[name] as JsonValue.Obj
    private fun JsonValue.Obj.array(name: String): JsonValue.Arr = this[name] as JsonValue.Arr
    private fun JsonValue.Obj.strings(name: String): List<String> = array(name).values.map { (it as JsonValue.Str).value }
    private fun JsonValue.Obj.integers(name: String): List<Int> = array(name).values.map { (it as JsonValue.Num).raw.toInt() }
    private fun JsonValue.Obj.integerArrays(name: String): List<List<Int>> = array(name).values.map { value ->
        (value as JsonValue.Arr).values.map { (it as JsonValue.Num).raw.toInt() }
    }
}
