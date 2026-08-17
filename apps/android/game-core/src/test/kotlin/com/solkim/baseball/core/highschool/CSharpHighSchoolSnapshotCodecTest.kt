package com.solkim.baseball.core.highschool

import com.solkim.baseball.core.pitch.PitchKind
import com.solkim.baseball.core.pitch.PitchUsageRole
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertNull
import kotlin.test.assertTrue

class CSharpHighSchoolSnapshotCodecTest {
    @Test
    fun realUnityRelationshipSnapshotDecodesWithoutResigning() {
        val bytes = javaClass.classLoader
            .getResourceAsStream("fixtures/csharp-high-school-snapshot-relationship-v1.json")
            ?.readBytes()
            ?: error("missing csharp high-school snapshot fixture")
        val state = CSharpHighSchoolSnapshotCodec.decode(bytes)

        assertEquals("career-2-life-1", state.careerId)
        assertEquals(3UL, state.revision)
        assertEquals(1, state.lifeNumber)
        assertEquals("power_prospect", state.presetId)
        assertEquals(HighSchoolPhase.RELATIONSHIP, state.phase)
        assertEquals("내부 QA 투수", state.identity.name)
        assertEquals("right", state.identity.throwingHand)
        assertEquals("balanced", state.identity.bodyType)
        assertEquals("서울", state.identity.region)
        assertEquals(HighSchoolSchoolId.HANBIT_TRADITIONAL, state.school?.id)
        assertEquals("서울덕성고", state.school?.name)
        assertEquals("pitcher-power", state.pitcher.id)
        assertEquals(45, state.pitcher.stuff)
        assertEquals(4, state.pitcher.pitchProfiles.size)
        assertEquals(PitchKind.FOUR_SEAM, state.pitcher.pitchProfiles[0].pitchType)
        assertEquals(PitchUsageRole.PRIMARY, state.pitcher.pitchProfiles[0].role)
        assertEquals(HighSchoolTalentGrade.D, state.talent.stuff)
        assertEquals(HighSchoolTalentGrade.S, state.talent.stamina)
        assertEquals(HighSchoolTrainingFocus.GAME_PLANNING, state.trainingOpportunity?.focus)
        assertEquals(1, state.lastTraining?.number)
        assertEquals(HighSchoolTrainingFocus.VELOCITY, state.lastTraining?.focus)
        assertEquals(false, state.lastTraining?.bloomed)
        assertEquals("evt-rival-message", state.currentRelationshipEvent?.id)
        assertEquals(HighSchoolRelationshipTarget.RIVAL, state.currentRelationshipTarget)
        assertEquals("2db72000520a4639", state.stateCommitment)
        assertEquals(listOf(1, 2, 1, 2, 3, 2, 1, 3), state.schedule.trainingsByChapter)
        assertEquals(HighSchoolPhase.RELATIONSHIP, state.schedule.milestonesByChapter.first().first())
        assertNull(state.draftResult)
        assertTrue(state.news.isNotEmpty())
    }

    @Test
    fun unknownSnapshotFieldFailsClosed() {
        val bytes = """{"CareerId":"x","Revision":1,"LifeNumber":1,"Phase":"Training","Identity":{"Name":"n","ThrowingHand":"Right","BodyType":"Balanced","Region":"서울"},"Difficulty":{"CareerHarshness":"Standard","InformationClarity":"Standard","SimulationDifficulty":"Standard","InterventionAssist":"Standard"},"Pitcher":{"Id":"pitcher-power","Name":"n","Stuff":40,"Command":40,"Movement":40,"Stamina":40},"Rival":{"Id":"r","Name":"r","Archetype":"a","Contact":40,"Discipline":40,"Power":40},"Chapter":{"Number":1,"Title":"t","SchoolYear":1,"Season":"봄","Theme":"t"},"StateCommitment":"abc","FutureField":1}""".toByteArray()
        val error = assertFailsWith<CSharpHighSchoolSnapshotCodecException> {
            CSharpHighSchoolSnapshotCodec.decode(bytes)
        }
        assertTrue(error.message.orEmpty().contains("FutureField"))
    }

    @Test
    fun realUnityRelationshipSnapshotMatchesCSharpSign() {
        val state = decodeFixture()
        assertEquals("2db72000520a4639", CSharpHighSchoolSnapshotWire.sign(state))
    }

    @Test
    fun encodeRoundTripsTheRelationshipSnapshotAndKeepsCSharpSign() {
        val original = decodeFixture()
        val previous = com.solkim.baseball.model.StrictJson.parseUtf8(fixtureBytes()) as com.solkim.baseball.model.JsonValue.Obj
        val encoded = CSharpHighSchoolSnapshotWire.encode(original, previous)
        val decoded = CSharpHighSchoolSnapshotCodec.decode(encoded)
        assertEquals(original.careerId, decoded.careerId)
        assertEquals(original.phase, decoded.phase)
        assertEquals(original.school?.id, decoded.school?.id)
        assertEquals(original.currentRelationshipEvent?.id, decoded.currentRelationshipEvent?.id)
        assertEquals(CSharpHighSchoolSnapshotWire.sign(original), decoded.stateCommitment)
        assertEquals(CSharpHighSchoolSnapshotWire.sign(original), CSharpHighSchoolSnapshotWire.sign(decoded))
    }

    @Test
    fun resignedFixtureHydratesAValidPhase4Shadow() {
        val extras = CSharpHighSchoolSnapshotWire.ReadExtras(
            installId = "718fa1083cc647d0b169ff301fdb9ad7",
            nextSeed = "5011836900497972414",
            presetId = "power_prospect",
            tutorialCompleted = false,
        )
        val phase4 = CSharpHighSchoolSnapshotWire.hydratePhase4(decodeFixture(), extras)
        HighSchoolPhase4Kernel().validateSavedState(phase4)
        assertEquals(HighSchoolPhase.RELATIONSHIP, phase4.run.phase)
        assertEquals(true, phase4.tutorial.completed)
        assertEquals(0UL, phase4.revision)
    }

    private fun decodeFixture(): HighSchoolState = CSharpHighSchoolSnapshotCodec.decode(fixtureBytes())

    private fun fixtureBytes(): ByteArray = javaClass.classLoader
        .getResourceAsStream("fixtures/csharp-high-school-snapshot-relationship-v1.json")
        ?.readBytes()
        ?: error("missing csharp high-school snapshot fixture")
}
