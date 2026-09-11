package com.solkim.baseball.application

import com.solkim.baseball.core.highschool.HighSchoolTournamentRules

import com.solkim.baseball.core.highschool.HighSchoolContentCatalog
import com.solkim.baseball.core.highschool.HighSchoolDifficulty
import com.solkim.baseball.core.highschool.HighSchoolPledgeRules
import com.solkim.baseball.core.highschool.HighSchoolAwakening
import com.solkim.baseball.core.highschool.HighSchoolAchievementRules
import com.solkim.baseball.core.highschool.HighSchoolDraftOutcome
import com.solkim.baseball.core.highschool.HighSchoolIdentity
import com.solkim.baseball.core.highschool.HighSchoolKarma
import com.solkim.baseball.core.highschool.HighSchoolPhase
import com.solkim.baseball.core.highschool.HighSchoolState
import com.solkim.baseball.core.highschool.HighSchoolPhase4Command
import com.solkim.baseball.core.highschool.HighSchoolPhase4Kernel
import com.solkim.baseball.core.highschool.HighSchoolPhase4StartRequest
import com.solkim.baseball.core.highschool.HighSchoolRebirthEntryPath
import com.solkim.baseball.core.highschool.HighSchoolRelationshipTarget
import com.solkim.baseball.core.highschool.HighSchoolRelationshipResponse
import com.solkim.baseball.core.highschool.HighSchoolReturnDestination
import com.solkim.baseball.core.highschool.HighSchoolSeasonLine
import com.solkim.baseball.core.highschool.HighSchoolSchoolId
import com.solkim.baseball.core.highschool.HighSchoolSignatureLegacyRules
import com.solkim.baseball.core.highschool.HighSchoolTrainingFocus
import com.solkim.baseball.core.highschool.HighSchoolTrainingIntensity
import com.solkim.baseball.core.pro.OffseasonDecision
import com.solkim.baseball.core.pro.ProCatalog
import com.solkim.baseball.core.pro.ProCareerPhase
import com.solkim.baseball.core.pro.ProCommand
import com.solkim.baseball.core.pro.ProDevelopmentFocus
import com.solkim.baseball.core.pro.ProEntitlement
import com.solkim.baseball.core.pro.ProFanReasonKind
import com.solkim.baseball.core.pro.ProGameLine
import com.solkim.baseball.core.pro.ProState
import com.solkim.baseball.core.pro.ProMerchandiseTier
import com.solkim.baseball.core.pro.ProSettlementNextRoute
import com.solkim.baseball.core.pro.ProOffseasonInvestment
import com.solkim.baseball.core.pro.ProHighSchoolLegacyContext
import com.solkim.baseball.core.pro.ProKernel
import com.solkim.baseball.core.pro.ProLevel
import com.solkim.baseball.core.pro.ProNationalTeamRules
import com.solkim.baseball.core.pro.ProNationalTournamentStage
import com.solkim.baseball.core.pro.ProRole
import com.solkim.baseball.core.pro.ProSeasonSegment
import com.solkim.baseball.core.pro.ProStartDirectRequest
import com.solkim.baseball.core.pro.ProStartLinkedRequest
import com.solkim.baseball.core.pro.ProWeekPlan
import com.solkim.baseball.core.pro.careerGames
import com.solkim.baseball.core.pro.careerStrikeouts
import com.solkim.baseball.core.pitch.PitchKind
import com.solkim.baseball.core.pitch.PitchProfileSnapshot
import com.solkim.baseball.core.pitch.PitchUsageRole
import com.solkim.baseball.core.pitch.PitcherSnapshot
import com.solkim.baseball.model.Hashing
import java.time.Clock
import java.time.LocalDate
import java.time.ZoneId
import java.time.temporal.WeekFields

internal fun ScreenBuilder.buildP024_WEEKLY() {
        val weekly = highSchool?.weekly
        val taskRows = weekly?.tasks.orEmpty().map { task ->
            ScreenRow(
                weeklyTaskTitle(task.kind),
                "${task.progress}/${task.target}${if (task.completed) " · 완료" else ""}",
                if (task.completed) "채웠다" else "훈련과 경기로 채운다",
            )
        }
        val stampRows = weekly?.stamps.orEmpty().takeLast(6).map { stamp ->
            ScreenRow(
                readableWeek(stamp.weekKey),
                if (stamp.perfect) "완벽 도장" else "도장 ${stamp.completedTaskCount}",
                "",
            )
        }
        addSection(ScreenSection("weekly", "주간 야구 노트", listOf(
            ScreenRow("이번 주", weekly?.weekKey?.let(::readableWeek) ?: "기록 없음", ""),
            ScreenRow("과제", "${weekly?.tasks?.count { it.completed } ?: 0}/${weekly?.tasks?.size ?: 0}", ""),
            ScreenRow("도장", weekly?.stamps?.size?.toString() ?: "0", "과제를 채운 주마다 하나. 셋 다 채우면 완벽 도장."),
            ScreenRow("보상", if (weekly?.rewardClaimed == true) "받았다" else "아직", if (weekly?.rewardClaimed == true) "" else WeeklyNotePolicy.explanation(state)),
        ) + taskRows + stampRows))
        addAction("claimWeeklyReward", "보상 받기", WeeklyNotePolicy.explanation(state), WeeklyNotePolicy.canClaim(state), if (WeeklyNotePolicy.canClaim(state)) listOf(hs(HighSchoolPhase4Command.ClaimWeeklyReward)) else emptyList())
}


internal fun ScreenBuilder.buildP025_RECORDS_LEAGUE() {
        if (state.canEnterPlayerSetup()) addAction("enterSetup", "새로운 야구 인생 시작", "남긴 기록과 야구혼을 간직하고 다음 생에서 시작합니다.", true, listOf(GameCommand.EnterSetup))
        state.meta.retiredProCareers.filter { state.meta.seedChallenge == null && it.careerId != pro?.careerId }.asReversed().forEach { retired ->
            addSection(ScreenSection("retired:${retired.careerId}", retired.identityName, listOf(
                ScreenRow("프로 통산", "${retired.careerStats.size}시즌 · ${retired.careerGames()}경기 · ${retired.careerStrikeouts()}탈삼진"),
                ScreenRow("남긴 유산", retired.legacyCandidates.firstOrNull { it.id == retired.selectedLegacyId }?.title ?: "기억"),
                ScreenRow("명예의 전당", (retired.hallOfFameScore ?: 0).let { if (it >= 70) "헌액 ($it/70)" else "헌액까지 ${70 - it}점 ($it/70)" }),
            )))
        }
        val standings = pro?.standings.orEmpty().take(5)
        val nothingYet = (run?.performance?.pitches ?: 0) == 0 && (pro?.careerGames() ?: 0) == 0 && (highSchool?.archive?.size ?: 0) == 0
        addSection(ScreenSection("records", "기록과 순위", (if (nothingYet) listOf(
            ScreenRow("아직 던진 공이 없다", "첫 등판을 마치면 여기 쌓인다.", ""),
        ) else listOf(
            ScreenRow("고교 기록", "${run?.performance?.pitches ?: 0}구 · ${run?.performance?.strikeouts ?: 0}탈삼진" + perfectSuffix(run), "이번 생의 투구 기록"),
            ScreenRow("프로 기록", "${pro?.careerGames() ?: 0}경기 · ${pro?.careerStrikeouts() ?: 0}탈삼진" + proPerfectSuffix(proCareerPerfect(pro)), "프로 통산 ${pro?.careerStats?.size ?: 0}시즌"),
            ScreenRow("지난 생", "${highSchool?.archive?.size ?: 0}번", "한 생을 마치면 카드가 남는다."),
        )) + standings.map { row ->
            ScreenRow("${row.rank}위 ${row.teamName}", "${row.wins}승 ${row.losses}패", if (row.isPlayerTeam) "내 구단" else "리그 순위")
        }))
}


internal fun ScreenBuilder.buildP026_ACHIEVEMENTS() {
        val unlocked = highSchool?.achievements.orEmpty()
        val pending = highSchool?.unacknowledgedAchievements.orEmpty()
        val legacyOnly = setOf(HighSchoolAchievementRules.MAJOR_DEBUT, HighSchoolAchievementRules.HUNDRED_STRIKEOUTS, HighSchoolAchievementRules.HALL_OF_FAME)
        addSection(ScreenSection("achievements", "업적", HighSchoolAchievementRules.all.filter { it !in legacyOnly || it in unlocked }.map { achievement ->
            ScreenRow(
                achievementTitle(achievement),
                when {
                    achievement in pending -> "새 기록"
                    achievement in unlocked -> "확인함"
                    else -> "잠김"
                },
                achievementDescription(achievement),
            )
        }))
        pending.forEach { achievement -> addAction("ack:$achievement", "${achievementTitle(achievement)} 확인", "새 업적을 확인합니다.", true, listOf(hs(HighSchoolPhase4Command.AcknowledgeAchievement(achievement)))) }
}


internal fun ScreenBuilder.buildP027_SETTINGS() {
        addSection(ScreenSection("settings", "플레이 방식", listOf(
            ScreenRow("자동 릴리스", boolLabel(state.settings.autoReleaseEnabled), "자동 릴리스는 보조 조작. 기본은 길게 눌러 와인드업."),
            ScreenRow("소리와 음악", "${boolLabel(state.settings.soundEnabled)} · ${boolLabel(state.settings.musicEnabled)}", "경기 분위기"),
            ScreenRow("진동", boolLabel(state.settings.hapticsEnabled), "선택과 결과의 손맛"),
            ScreenRow("알림", boolLabel(state.settings.notificationsEnabled), "복귀 안내"),
            ScreenRow("접근성", "고대비 ${boolLabel(state.settings.highContrastEnabled)} · 모션 ${if (state.settings.reducedMotionEnabled) "줄임" else "기본"}", "읽기 편한 화면"),
            ScreenRow("진행 삭제", "첫 화면으로 돌아갑니다", "모든 생의 기록이 사라진다. 되돌릴 수 없다."),
        )))
        addAction("toggleAutoRelease", if (state.settings.autoReleaseEnabled) "자동 릴리스 끄기" else "자동 릴리스 켜기", "탭 한 번으로 던지는 보조 조작", true, listOf(settingsCommand(state) { it.copy(autoReleaseEnabled = !it.autoReleaseEnabled) }))
        addAction("toggleSound", if (state.settings.soundEnabled) "소리 끄기" else "소리 켜기", "효과음", true, listOf(settingsCommand(state) { it.copy(soundEnabled = !it.soundEnabled) }))
        addAction("toggleMusic", if (state.settings.musicEnabled) "음악 끄기" else "음악 켜기", "배경 음악", true, listOf(settingsCommand(state) { it.copy(musicEnabled = !it.musicEnabled) }))
        addAction("toggleHaptics", if (state.settings.hapticsEnabled) "진동 끄기" else "진동 켜기", "손맛", true, listOf(settingsCommand(state) { it.copy(hapticsEnabled = !it.hapticsEnabled) }))
        addAction("toggleContrast", if (state.settings.highContrastEnabled) "고대비 끄기" else "고대비 켜기", "더 또렷한 화면", true, listOf(settingsCommand(state) { it.copy(highContrastEnabled = !it.highContrastEnabled) }))
        addAction("toggleMotion", if (state.settings.reducedMotionEnabled) "기본 모션 사용" else "모션 줄이기", "움직임을 줄인 화면", true, listOf(settingsCommand(state) { it.copy(reducedMotionEnabled = !it.reducedMotionEnabled) }))
        addSection(ScreenSection("glossary", "용어집", BaseballGlossary.terms.map { term ->
            ScreenRow(term.name, term.definition)
        }))
        if (state.meta.seedChallenge == null) addAction("resetProgress", "진행 삭제", "모든 기록을 지우고 처음부터. 되돌릴 수 없다.", true, listOf(GameCommand.ResetProgress), destructive = true)
}


internal fun ScreenBuilder.buildP028_LIFECARD() {
        val card = LifeCardProjection.selected(state)
        addSection(ScreenSection("life-card", "선수 앨범", if (card == null) listOf(
            ScreenRow("보관된 생", "아직 없음", "한 생을 마치면 카드가 생긴다."),
        ) else card.lines.map { line -> ScreenRow(line.substringBefore(": ", "기록"), line.substringAfter(": ", line)) }))
}


internal fun ScreenBuilder.buildP029_RETURN_PLAN() {
        addSection(ScreenSection("return-plan", "복귀 계획", listOf(
            ScreenRow("다음 목적지", ReturnVisitPresentation.label(state), "잠깐 쉬고 돌아올 위치"),
            ScreenRow("안내", ReturnVisitPresentation.detail(state), ""),
            ScreenRow("알림", "내일 아침 9시에 한 번", "알림을 허용했을 때만 온다."),
        )))
        addAction("prepareReturnPlan", "내일 아침에 알려 줘", "돌아올 자리는 여기. 내일 아침 9시에 한 번만 알린다.", highSchool != null || pro != null, emptyList())
        addAction("dismissReturnPlan", "알림 예약 취소", "예약한 복귀 알림을 취소합니다.", highSchool != null || pro != null, emptyList())
}


internal fun ScreenBuilder.buildP030_REVIEW() {
        addSection(ScreenSection("review", "리뷰", listOf(
            ScreenRow("리뷰", "재밌었다면 한 줄 남겨 주세요.", "다음 생을 만드는 데 큰 힘이 됩니다."),
        )))
}
