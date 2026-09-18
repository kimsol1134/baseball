package com.solkim.baseball.core.highschool

import com.solkim.baseball.core.pitch.*
import com.solkim.baseball.model.*
import java.nio.file.*
import kotlin.test.*

class ReleaseTrainingParityTest {
    private fun values(s: HighSchoolState): List<String> {
        val p = s.pitcher; val project = s.pitchLearningProject
        return listOf(s.phase.wire, "${p.stuff},${p.command},${p.movement},${p.stamina}", "${s.fatigue},${s.armRisk}",
            "${project?.practiceCredits ?: -1},${project?.qualityUses ?: -1},${project?.stage ?: "legacy"}",
            p.pitchProfiles.sortedBy { it.pitchType.wire }.joinToString(";") { "${it.pitchType.wire}:${it.role.wire}:${it.velocityTenthsKph}:${it.control}:${it.command}:${it.movement}:${it.whiff}:${it.weakContact}:${it.fatigueCost}" })
    }
    @Test fun allPresetsLearningPitchesFocusAndIntensityMatchCurrentSwift() {
        val root = com.solkim.baseball.core.SwiftReleaseReference.read()
        val cases = (root["training"] as JsonValue.Arr).values.map { it as JsonValue.Obj }
        assertEquals(216, cases.size)
        val core = HighSchoolKernel(balanceRulesVersion = 4)
        for (row in cases) {
            fun text(key: String) = (row[key] as JsonValue.Str).value
            fun expected(key: String) = (row[key] as JsonValue.Arr).values.map { (it as JsonValue.Str).value }
            val target = PitchKind.entries.single { it.wire == text("learning") }
            var result = core.start(HighSchoolKernel.StartRequest("918220", text("preset")))
            var state = result.snapshot
            state = core.resignShadowState(state.copy(pitcher = state.pitcher.copy(pitchProfiles = PitchLearningRules.configure(state.pitcher.pitchProfiles, PitchKind.FOUR_SEAM, target)), pitchLearningProject = PitchLearningProject(target)))
            result = core.completePrologue(HighSchoolKernel.AdvanceRequest(result.nextSeed, state))
            result = core.chooseSchool(HighSchoolKernel.ChooseSchoolRequest(result.nextSeed, result.snapshot, HighSchoolSchoolId.HAEDONG_POWER))
            val label = "${text("preset")}/${text("learning")}/${text("focus")}/${text("intensity")}"
            assertEquals(expected("before"), values(result.snapshot), "$label before")
            val focus = HighSchoolTrainingFocus.entries.single { it.wire == text("focus") }
            val after = core.commitTraining(HighSchoolKernel.TrainingRequest(text("seed"), result.snapshot, focus,
                HighSchoolTrainingIntensity.entries.single { it.wire == text("intensity") }, target.takeIf { focus == HighSchoolTrainingFocus.BREAKING_BALL }))
            assertEquals(expected("after"), values(after.snapshot), "$label after")
            assertEquals(text("nextSeed"), after.nextSeed, "$label RNG")
            assertEquals(after.snapshot, HighSchoolStateCodec.decode(HighSchoolStateCodec.encode(after.snapshot)))
        }
    }
}
