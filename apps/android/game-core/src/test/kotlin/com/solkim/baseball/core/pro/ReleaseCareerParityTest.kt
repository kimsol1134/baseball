package com.solkim.baseball.core.pro

import com.solkim.baseball.core.pitch.*
import com.solkim.baseball.core.highschool.*
import com.solkim.baseball.model.JsonValue
import com.solkim.baseball.model.StrictJson
import java.nio.file.Path
import java.nio.file.Files
import kotlin.test.*

/** Replay Swift-authored commands; fixed game reports isolate career rules from mound rendering. */
class ReleaseCareerParityTest {
    private val kernel = ProKernel(gameplayRulesVersion = 10)
    private fun signed(s: ProState): ProState = s.copy(commitment = kernel.commitment(s))
    private fun values(s: ProState): List<String> {
        val r = s.currentStats
        // Android keeps a separate post-retirement legacy-choice boundary; iOS owns it in the app layer.
        val phase = if (s.phase in setOf(ProCareerPhase.LEGACY_SELECTION, ProCareerPhase.COMPLETED) && s.hallOfFameScore != null) "retired" else s.phase.wire
        return listOf(phase, s.season.toString(), s.week.toString(), s.level.wire, s.role.wire,
            "${s.pitcher.stuff},${s.pitcher.command},${s.pitcher.movement},${s.pitcher.stamina}",
            "${s.fatigue},${s.managerTrust},${s.catcherTrust},${s.injuryWeeks}",
            "${r.games},${r.starts},${r.inningsOuts},${r.strikeouts},${r.walks},${r.runsAllowed},${r.hits},${r.pitches}",
            (s.journeyState?.finances?.availableFunds ?: 0).toString(), s.careerStats.size.toString(), (s.contract?.yearsRemaining ?: 0).toString(), "${r.wins},${r.losses},${r.saves}", (s.contract?.annualSalary ?: 0).toString(), (s.journeyState?.reputation?.fanSupport ?: 0).toString(), (s.hallOfFameScore ?: -1).toString(), "${s.pitcher.effectiveMastery.stuff},${s.pitcher.effectiveMastery.command},${s.pitcher.effectiveMastery.movement},${s.pitcher.effectiveMastery.stamina}",
            "${s.journeyState?.activeGoal?.ambition?.wire ?: "none"}:${s.journeyState?.activeGoal?.completedSeason ?: 0}:${s.journeyState?.goalHistory.orEmpty().count { it.outcome == ProCareerGoalOutcome.COMPLETED }}",
            s.journeyState?.pendingContractMarket?.offers.orEmpty().joinToString(";") { "${it.teamId}:${it.years}:${it.annualSalary}:${it.signingBonus ?: 0}:${it.contractKind.wire}:${it.rolePromise.wire}:${it.expectation.kind.wire}:${it.expectation.target}:${it.expectation.difficulty.wire}" })
    }
    private fun replayHighSchool(root: JsonValue.Obj): HighSchoolState {
        val k = HighSchoolKernel(balanceRulesVersion = 4)
        var state: HighSchoolState? = null
        val rows = (root["highSchool"] as JsonValue.Arr).values.map { it as JsonValue.Obj }
        for ((index, row) in rows.withIndex()) {
            fun text(key: String) = (row[key] as JsonValue.Str).value
            val seed = text("seed")
            val args = (row["args"] as JsonValue.Arr).values.map { (it as JsonValue.Str).value }
            val before = state
            val result = when (text("action")) {
                "start" -> k.start(HighSchoolKernel.StartRequest(seed, "power_prospect")).let { r ->
                    r.copy(snapshot = k.resignShadowState(r.snapshot.copy(pitcher = r.snapshot.pitcher.copy(pitchProfiles = PitchLearningRules.configure(r.snapshot.pitcher.pitchProfiles, PitchKind.FOUR_SEAM, PitchKind.CURVEBALL)), pitchLearningProject = PitchLearningProject(PitchKind.CURVEBALL))))
                }
                "prologue" -> k.completePrologue(HighSchoolKernel.AdvanceRequest(seed, before!!))
                "school" -> k.chooseSchool(HighSchoolKernel.ChooseSchoolRequest(seed, before!!, HighSchoolSchoolId.HAEDONG_POWER))
                "training" -> k.commitTraining(HighSchoolKernel.TrainingRequest(seed, before!!, HighSchoolTrainingFocus.entries.single { it.wire == args[0] }, HighSchoolTrainingIntensity.STANDARD, PitchKind.CURVEBALL.takeIf { args[0] == "breaking_ball" }))
                "relationship" -> k.resolveRelationship(HighSchoolKernel.RelationshipRequest(seed, before!!, HighSchoolRelationshipResponse.LISTEN))
                "game" -> k.recordImportantGame(HighSchoolKernel.GameRequest(seed, before!!, HighSchoolGameReport(before.performance.importantGamesCompleted + 1, 18, 2, 0, 0, 400, 250, 12, outs = 3, sequenceMasteryCount = 4, hits = 0)))
                "awakening" -> k.chooseAwakening(HighSchoolKernel.AwakeningRequest(seed, before!!, HighSchoolAwakening.entries.single { it.wire == args[0] }))
                "chapter" -> k.advanceChapter(HighSchoolKernel.AdvanceRequest(seed, before!!))
                "draft" -> k.resolveDraft(HighSchoolKernel.AdvanceRequest(seed, before!!))
                "legacy" -> k.selectLegacy(HighSchoolKernel.LegacyRequest(seed, before!!, memoryCards = args))
                else -> error("unknown HS action")
            }
            state = result.snapshot
            val p = state.pitcher; val project = state.pitchLearningProject; val d = state.draftResult
            val actual = listOf(state.phase.wire, "${p.stuff},${p.command},${p.movement},${p.stamina}", "${state.fatigue},${state.armRisk}",
                "${project?.practiceCredits ?: -1},${project?.qualityUses ?: -1},${project?.stage ?: "legacy"}",
                p.pitchProfiles.sortedBy { it.pitchType.wire }.joinToString(";") { "${it.pitchType.wire}:${it.role.wire}:${it.velocityTenthsKph}:${it.control}:${it.command}:${it.movement}:${it.whiff}:${it.weakContact}:${it.fatigueCost}" },
                "${state.managerTrust},${state.catcherTrust},${state.rivalTrust},${state.fanInterest}",
                "${state.performance.importantGamesCompleted},${state.performance.pitches},${state.performance.strikeouts},${state.performance.walks},${state.performance.runsAllowed}",
                "${d?.outcome?.wire ?: "none"}:${d?.evaluationScore ?: 0}:${d?.teamId ?: "none"}:${d?.round ?: 0}:${d?.signingBonus ?: 0}", state.selectedAwakenings.joinToString(",") { it.wire })
            val expected = (row["values"] as JsonValue.Arr).values.map { (it as JsonValue.Str).value }
            assertEquals(expected, actual, "HS step=$index action=${text("action")}")
            assertEquals(text("nextSeed"), result.nextSeed, "HS RNG at $index")
            state = HighSchoolStateCodec.decode(HighSchoolStateCodec.encode(state))
        }
        return requireNotNull(state)
    }
    @Test fun currentSwiftTwentySeasonTranscriptMatchesEveryCareerTransition() {
        val root = com.solkim.baseball.core.SwiftReleaseReference.read()
        val evidenceDirectory = Path.of("../../../artifacts/android-compose/release-gate")
        Files.createDirectories(evidenceDirectory)
        assertEquals(10, (root["rulesVersion"] as JsonValue.Num).raw.toInt())
        assertEquals(HighSchoolContentCatalog.BALANCE_VERSION, (root["balanceVersion"] as JsonValue.Num).raw.toInt())
        val linkedSchool = replayHighSchool(root)
        for (scenario in listOf("pro", "proFa", "proLinked")) {
        val rows = (root[scenario] as JsonValue.Arr).values.map { it as JsonValue.Obj }
        var state: ProState? = null
        val output = mutableListOf<JsonValue>()
        for ((index, row) in rows.withIndex()) {
            fun text(key: String) = (row[key] as JsonValue.Str).value
            val args = (row["args"] as JsonValue.Arr).values.map { (it as JsonValue.Str).value }
            val seed = text("seed")
            val s = state
            val result = when(text("action")) {
                "start" -> if (scenario == "proLinked") {
                    val hs = linkedSchool; val d = hs.draftResult!!
                    kernel.startLinked(ProStartLinkedRequest(seed, hs.careerId, hs.identity.name, hs.copy(pitchLearningProject = null).toPitcherSnapshot(), d.teamId!!, d.evaluationScore,
                        pitchLearningProject = hs.pitchLearningProject, draftRound = d.round, signingBonus = d.signingBonus?.toLong(), overallPick = d.overallPick, sourceFanInterest = hs.fanInterest))
                } else kernel.startLinked(ProStartLinkedRequest(seed, "fixture-hs", "민서준", ProCatalog.pitcherForPreset("power_prospect", "민서준"), ProCatalog.teams.first().id, 72, draftRound = 2, signingBonus = 120_000_000, overallPick = 18))
                "contract" -> kernel.acceptContractOffer(s!!, seed, s.journeyState!!.pendingContractMarket!!.offers.first().id, ProCareerAmbition.entries.firstOrNull { it.wire == args[0] })
                "week" -> kernel.planWeek(s!!, seed, ProWeekPlan.entries.single { it.wire == args[0] })
                "decision" -> { require(s!!.pendingDecision!!.choices.any { it.id == args[0] }) { "step=$index expected=${args[0]} actual=${s.pendingDecision!!.type.wire}:${s.pendingDecision!!.choices.map { it.id }}" }; kernel.applySeasonDecision(s, seed, s.pendingDecision!!.id, args[0]) }
                "game" -> {
                    // Swift receives an ImportantInningReport. Adapt the same report to Android's session boundary.
                    val prepared = kernel.reserveImportantGame(s!!, seed).state
                    val entry = PitchAnalysisEntry(PitchKind.FOUR_SEAM, true, false, PitchOutcome.CALLED_STRIKE, SelectionQuality.entries.first(), 700, null, 0, 0, true, 1400)
                    val session = prepared.activePitch!!.copy(seed = seed, pitches = 24, pitchIndex = 24, preparationToken = "", boundary = ProPitchBoundary.COMPLETED, log = prepared.activePitch!!.log.copy(totalPitches = 24, entries = List(24) { entry }), strikeouts = 4, walks = 0, runsAllowed = 0,
                        expectedDamage = 420, actualDamage = 160, recommendationAccepted = 16, outs = 3, hits = 0, homeRuns = 0,
                        sequenceMasteryCount = 1, ended = true, context = prepared.activePitch!!.context.copy(scoreDifferential = 2))
                    kernel.finishImportantGame(signed(s.copy(activePitch = session)))
                }
                "review" -> kernel.reviewSeason(s!!, seed)
                "settlement" -> kernel.acknowledgeSeasonSettlement(s!!, seed, s.journeyState!!.lastSettlement!!.id)
                "fa" -> kernel.chooseOffseason(s!!, seed, OffseasonDecision.FREE_AGENCY)
                "continue" -> kernel.chooseOffseason(s!!, seed, OffseasonDecision.CONTINUE)
                "retire" -> kernel.chooseOffseason(s!!, seed, OffseasonDecision.RETIRE)
                "investment" -> kernel.chooseInvestment(s!!, seed, ProOffseasonInvestment.NONE, null)
                "national_decline" -> kernel.respondToNationalTeamCall(s!!, seed, false)
                "national_ack" -> kernel.acknowledgeNationalTeamResult(s!!, seed)
                else -> error("unhandled action ${text("action")}")
            }
            state = result.state
            val actual = values(state)
            val expected = (row["values"] as JsonValue.Arr).values.map { (it as JsonValue.Str).value }
            output += JsonValue.Obj(linkedMapOf("step" to JsonValue.Num(index.toString()), "action" to row.entries.getValue("action"),
                "expected" to row.entries.getValue("values"), "actual" to JsonValue.Arr(actual.map(JsonValue::Str)),
                "expectedSeed" to row.entries.getValue("nextSeed"), "actualSeed" to JsonValue.Str(result.nextSeed), "rawAndroidPhase" to JsonValue.Str(state.phase.wire)))
            if (index % 50 == 0 || index == rows.lastIndex || expected != actual || text("nextSeed") != result.nextSeed) Files.writeString(evidenceDirectory.resolve("kotlin-release-parity-$scenario.json"), StrictJson.canonical(JsonValue.Arr(output)))
            assertEquals(expected, actual, "first divergence step=$index action=${text("action")} seed=$seed")
            assertEquals(text("nextSeed"), result.nextSeed, "seed divergence at $index ${text("action")}")
            state = ProStateCodec.decode(ProStateCodec.encode(state))
        }
        assertEquals(20, state!!.careerStats.size)
        if (state.phase == ProCareerPhase.LEGACY_SELECTION) state = kernel.selectLegacy(state, state.legacyCandidates.first().id).state
        assertEquals(ProCareerPhase.COMPLETED, state.phase)
        }
    }
}
