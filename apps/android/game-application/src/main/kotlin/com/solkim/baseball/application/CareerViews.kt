package com.solkim.baseball.application

import com.solkim.baseball.core.highschool.HighSchoolArchiveRecord
import com.solkim.baseball.core.highschool.HighSchoolDraftOutcome
import com.solkim.baseball.core.highschool.HighSchoolReturnDestination
import com.solkim.baseball.core.highschool.HighSchoolReturnPlan
import com.solkim.baseball.core.highschool.HighSchoolWeeklyState
import com.solkim.baseball.core.pitch.PitchKind
import com.solkim.baseball.core.pitch.PitchProfileSnapshot

public data class LineageView(val legacyId: String, val rank: Int, val contributions: Int, val nextThreshold: Int?, val family: String)

public data class SchoolRunFacts(
    val careerId: String,
    val playerName: String,
    val lifeNumber: Int,
    val revision: ULong,
    val trainings: Int,
    val learningCompleted: Boolean,
    val learningPitch: PitchKind?,
    val awakeningWires: List<String>,
    val lastBloomed: Boolean,
    val lastFocus: TrainingFocus?,
    val chapterNumber: Int,
    val importantGames: Int,
    val strikeouts: Int,
    val perfectReleases: Int,
    val drafted: Boolean?,
    val phaseWire: String,
    val legacyOptions: List<String>,
    val relationshipEventId: String?,
    val relationshipEventTitle: String?,
    val relationshipEventSummary: String?,
    val relationshipCategory: String?,
)

public data class CareerHeaderView(
    val name: String,
    val lifeNumber: Int,
    val season: Int?,
    val isPro: Boolean,
    val freshman: Boolean,
    val chapterTitle: String,
    val command: Int,
    val stamina: Int,
    val fatigue: Int,
    val pitchProfiles: List<PitchProfileSnapshot>,
)

public data class DraftJourneyView(
    val careerId: String,
    val teamName: String?,
    val round: Int?,
    val overallPick: Int?,
    val playerName: String,
    val schoolName: String?,
    val startRatings: List<Int>,
    val currentRatings: List<Int>,
    val awakeningWires: List<String>,
    val presetId: String,
    val trainings: Int,
    val relationships: Int,
    val coachName: String?,
    val managerTrust: Int,
) {
    public companion object {
        public fun resolve(state: GameAggregateState): DraftJourneyView? {
            val school = state.highSchool ?: return null
            val run = school.run
            val draft = run.draftResult ?: return null
            val start = school.startingPitcher
            return DraftJourneyView(
                careerId = run.careerId,
                teamName = draft.team?.name,
                round = draft.round,
                overallPick = draft.overallPick,
                playerName = run.identity.name,
                schoolName = run.school?.name,
                startRatings = listOf(start.stuff, start.command, start.movement, start.stamina),
                currentRatings = listOf(run.pitcher.stuff, run.pitcher.command, run.pitcher.movement, run.pitcher.stamina),
                awakeningWires = run.selectedAwakenings.map { it.wire },
                presetId = run.presetId,
                trainings = run.totalTrainingsCompleted,
                relationships = run.relationshipsCompleted,
                coachName = run.school?.coachName,
                managerTrust = run.managerTrust,
            )
        }
    }
}

public data class ArchiveLifeView(
    val careerId: String,
    val lifeNumber: Int,
    val playerName: String,
    val schoolName: String?,
    val drafted: Boolean,
    val draftEvaluation: Int,
    val ratings: List<Int>,
    val importantGames: Int,
    val strikeouts: Int,
    val walks: Int,
    val runsAllowed: Int,
    val selectedSignatureLegacyId: String?,
    val perfectReleases: Int,
) {
    public companion object {
        public fun from(record: HighSchoolArchiveRecord): ArchiveLifeView = ArchiveLifeView(
            careerId = record.careerId,
            lifeNumber = record.lifeNumber,
            playerName = record.playerName,
            schoolName = record.schoolName,
            drafted = record.drafted,
            draftEvaluation = record.draftEvaluation,
            ratings = record.ratings,
            importantGames = record.importantGames,
            strikeouts = record.strikeouts,
            walks = record.walks,
            runsAllowed = record.runsAllowed,
            selectedSignatureLegacyId = record.selectedSignatureLegacyId,
            perfectReleases = record.perfectReleases,
        )
    }
}

public data class ReturnPlanView(
    val destination: HighSchoolReturnDestination,
    val reason: String,
    val createdDayKey: String,
    val receiptId: String,
    val dismissed: Boolean,
    val body: String,
    val experimentId: String?,
    val savedDayKey: String?,
    val experimentVariant: String?,
    val developmentRulesVersion: Int?,
) {
    public companion object {
        public fun from(plan: HighSchoolReturnPlan): ReturnPlanView = ReturnPlanView(
            destination = plan.destination,
            reason = plan.reason,
            createdDayKey = plan.createdDayKey,
            receiptId = plan.receiptId,
            dismissed = plan.dismissed,
            body = plan.body,
            experimentId = plan.experimentId,
            savedDayKey = plan.savedDayKey,
            experimentVariant = plan.experimentVariant,
            developmentRulesVersion = plan.developmentRulesVersion,
        )
    }
}

public data class WeeklyTaskView(val id: String, val target: Int, val progress: Int, val completed: Boolean, val kind: String)
public data class WeeklyStampView(val weekKey: String, val completedTaskCount: Int, val perfect: Boolean)
public data class WeeklyNoteView(
    val weekKey: String,
    val tasks: List<WeeklyTaskView>,
    val stamps: List<WeeklyStampView>,
) {
    public companion object {
        public fun from(weekly: HighSchoolWeeklyState): WeeklyNoteView = WeeklyNoteView(
            weekKey = weekly.weekKey,
            tasks = weekly.tasks.map { WeeklyTaskView(it.id, it.target, it.progress, it.completed, it.kind) },
            stamps = weekly.stamps.map { WeeklyStampView(it.weekKey, it.completedTaskCount, it.perfect) },
        )
    }
}
