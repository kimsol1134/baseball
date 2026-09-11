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

internal fun ScreenBuilder.buildP013_DRAFT() {
        addSection(ScreenSection("draft", "드래프트", listOfNotNull(
        if (run?.draftResult == null) ScreenRow("드래프트 당일", "이름이 불릴까.", "3년이 이 한 번의 호명에 달렸다. 숨을 참고 듣는다.")
        else ScreenRow(run.draftResult?.outcome?.label ?: "결과", run.draftResult?.summary.orEmpty(), if (run.draftResult?.outcome?.wire == "drafted") "프로 계약이 기다린다." else "이 생은 여기까지. 기록은 다음 생으로 간다."),
    )))
    .also { addSection(ProfessionalStatusPresentation.section(state)); run?.let { CareerChoicePresentation.conclusion(it).forEach(::addSection) } }
    .also { addAction("resolveDraft", "드래프트 결과 확인", "이름이 불릴까. 숨을 참고 듣는다.", run?.let { it.phase == HighSchoolPhase.DRAFT && it.draftResult == null } == true, listOf(hs(HighSchoolPhase4Command.ResolveDraft(context.seed(state, "draft"))))) }
}


internal fun ScreenBuilder.buildP014_RUN_RECAP() {
        run?.let { CareerChoicePresentation.conclusion(it).forEach(::addSection) }
        addSection(ScreenSection("recap", "이번 생의 기록", listOf(
            ScreenRow("선수", run?.identity?.name ?: "—", "이번 생에 남긴 기록"),
            ScreenRow("투구", "${run?.performance?.pitches ?: 0}구", "실점 ${run?.performance?.runsAllowed ?: 0} · 삼진 ${run?.performance?.strikeouts ?: 0}" + perfectSuffix(run)),
            run?.legacyOptions.orEmpty().filter { id -> HighSchoolSignatureLegacyRules.definitions.any { it.id == id } }.let { frozen ->
                if (frozen.isEmpty()) ScreenRow("유산", "아직 셋으로 추리기 전", "유산 후보 보기를 누르면 이 생이 남긴 셋이 정해진다.")
                else ScreenRow("유산", frozen.joinToString(" · ") { legacyTitle(it) }, "다음 생에 가져갈 건 하나.")
            },
        )))
        addAction("prepareLegacy", "다음 생에 가져갈 능력 고르기", "이 생이 남긴 세 가지 중 하나를 고른다.", run?.let { it.phase == HighSchoolPhase.LEGACY || (it.phase == HighSchoolPhase.COMPLETED && it.draftResult?.outcome?.wire == "drafted") } == true, listOf(hs(HighSchoolPhase4Command.PrepareLegacy)))
        // Old base-engine memory options must first be converted into frozen signature candidates.
        run?.legacyOptions.orEmpty().filter { id -> HighSchoolSignatureLegacyRules.definitions.any { it.id == id } }
            .forEach { legacy -> addAction("selectLegacy:$legacy", legacyTitle(legacy), legacyEffect(legacy), run?.phase == HighSchoolPhase.LEGACY, listOf(hs(HighSchoolPhase4Command.SelectLegacy(legacy)))) }
        addAction("finalizeArchive", "이 생을 마무리", "기록을 남기고 다음 생을 준비한다.", run?.phase == HighSchoolPhase.COMPLETED && highSchool?.selectedSignatureLegacyId != null, listOf(hs(HighSchoolPhase4Command.FinalizeArchive)))
        val draftedReviewReceipt = "review-moment:${run?.careerId}:drafted-reveal-confirmed"
        val recapReviewReceipt = "review-moment:${run?.careerId}:good-recap"
        if (run?.draftResult?.outcome == HighSchoolDraftOutcome.DRAFTED) {
            addAction(
                "confirmDraftResult",
                "이 순간을 기억한다",
                "지명. 3년이 보답받았다.",
                state.analytics.receipts.none { it.receiptId == draftedReviewReceipt },
                listOf(GameCommand.RecordAnalytics(draftedReviewReceipt, "review_moment_drafted_reveal_confirmed")),
            )
        } else if (run?.draftResult != null && ScreenProjection.recapDeservesReview(state)) {
            addAction(
                "confirmRecap",
                "3년, 여기까지",
                "기록은 남는다. 다음 생으로 가져간다.",
                state.analytics.receipts.none { it.receiptId == recapReviewReceipt },
                listOf(GameCommand.RecordAnalytics(recapReviewReceipt, "review_moment_good_recap")),
            )
        }
}


internal fun ScreenBuilder.buildP015_REBIRTH() {
        addSection(ProfessionalStatusPresentation.section(state))
        val inheritedId = highSchool?.inheritance?.selectedSignatureLegacyId
        addSection(ScreenSection("rebirth", "다음 생에도, 나의 공", listOf(
            ScreenRow("이어지는 힘", inheritedId?.let(::legacyTitle) ?: "남은 기억", inheritedId?.let(::legacyEffect).orEmpty()),
            ScreenRow("남은 기억", highSchool?.inheritance?.inheritedMemories?.size?.toString() ?: "0", "다음 생으로 가져가는 기억"),
            ScreenRow("다시 시작", "같은 이름, 같은 얼굴. 1학년부터.", ""),
        )))
        val canBeginRebirth = run?.phase == HighSchoolPhase.COMPLETED && highSchool?.archive?.any { it.careerId == run.careerId } == true
        if (canBeginRebirth && highSchool != null && run != null) {
            val paths = listOf(
                Triple("endurance", "innings_eater", PitchKind.FOUR_SEAM),
                Triple("closer", "breaking_ball_artist", PitchKind.SLIDER),
                Triple("command", "precision_commander", PitchKind.CHANGEUP))
            addSection(ScreenSection("new-life-path", "이번 생에는 다른 야구", listOf(
                ScreenRow("이전 생은 남아요", "이름·얼굴·앨범·계승 유산 유지", "성장 유형과 구종을 바꾸고 학교 선택부터 시작합니다."))))
            paths.forEach { (path, preset, primary) ->
                val learning = if (primary == PitchKind.CHANGEUP) PitchKind.CURVEBALL else PitchKind.CHANGEUP
                val setup = com.solkim.baseball.core.highschool.HighSchoolRebirthSetup(preset, run.identity, run.difficulty,
                    karmas = run.karmas, primaryPitch = primary, learningPitch = learning)
                addAction("rebirthPath:$path", AceCareerPresentation.pathTitle(path),
                    when(path) { "endurance" -> "체력형 · 포심 중심 · 완투를 목표로"; "closer" -> "변화구형 · 슬라이더 중심 · 마무리에 지원"; else -> "제구형 · 체인지업 중심 · 효율적인 승부" }, true,
                    listOf(hs(HighSchoolPhase4Command.ConfigureRebirth(context.seed(state, "path-$path"), context.dayKey(state), setup)),
                        hs(HighSchoolPhase4Command.BeginTutorial), hs(HighSchoolPhase4Command.CompleteTutorial(context.seed(state, "path-school"))),
                        GameCommand.UpdateCompanion("career_path", path), GameCommand.UpdateCompanion("pitch", primary.wire)))
            }
        }
        addAction(
            "quickRebirth",
            "이 힘으로 환생하기",
            "같은 이름, 같은 얼굴로 1학년부터 다시.",
            canBeginRebirth,
            listOf(hs(HighSchoolPhase4Command.BeginRebirth(context.seed(state, "quick-rebirth"), context.dayKey(state), HighSchoolRebirthEntryPath.QUICK_REBIRTH))),
        )
        addAction(
            "customizeRebirth",
            "다음 생 설정하기",
            "이름·구종·이어받을 힘을 바꿔서 시작한다.",
            canBeginRebirth,
            listOf(GameCommand.EnterSetup),
        )
        addAction(
            "finalizeArchive",
            "이 생을 마무리",
            "기록을 남기고 다음 생을 준비한다.",
            run?.phase == HighSchoolPhase.COMPLETED &&
                highSchool?.selectedSignatureLegacyId != null &&
                highSchool.archive.none { it.careerId == run.careerId },
            listOf(hs(HighSchoolPhase4Command.FinalizeArchive)),
        )
        if ((state.pro == null || (state.pro.phase == ProCareerPhase.COMPLETED && state.pro.sourceHighSchoolCareerId != run?.careerId)) && run?.phase == HighSchoolPhase.COMPLETED) {
            if (run.draftResult?.outcome == HighSchoolDraftOutcome.DRAFTED) addAction(
                "startLinked",
                "입단 계약 보기",
                "지명받은 그 이름 그대로 프로에 간다.",
                true,
                listOf(proCommand(ProCommand.StartLinked(linkedRequest(state, context)))),
            )

        }
}
