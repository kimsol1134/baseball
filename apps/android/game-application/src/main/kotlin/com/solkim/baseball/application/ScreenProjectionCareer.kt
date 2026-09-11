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

internal fun ScreenBuilder.buildP001_OPENING() {
        addSection(ScreenSection("opening", "새로운 시작", listOf(
            ScreenRow("이 게임", "야구 못하면 또 환생함", "한 구씩 직접 던진다. 안 되면 다시 태어나서 더 강해진다. 기본 조작은 투구 슬라이더."),
            ScreenRow("기본 투구", "길게 눌러 와인드업", "손을 떼는 순간이 공을 정한다."),
            ScreenRow("돌아오기", "언제든 이어서", "진행은 저절로 저장된다."),
        )))
        addAction("enterSetup", "시작하기", "내 투수를 만들고 마운드로.", state.stage == GameStage.OPENING, listOf(GameCommand.EnterSetup))
        addAction("startDirect", "프로부터 새로 시작", "고교 과정을 건너뛰고 별도 프로 선수로 시작합니다.", state.stage == GameStage.OPENING,
            listOf(proCommand(ProCommand.StartDirect(ProStartDirectRequest(context.seed(state, "pro-direct"), "power_prospect", "민서준")))))
}


internal fun ScreenBuilder.buildP002_SETUP() {
        addSection(ScreenSection("setup", "선수 만들기", HighSchoolContentCatalog.presets.map { preset ->
            ScreenRow(HighSchoolDisplayRules.presetTitle(preset.id), "구위 ${AbilityDisplayScale.rating(preset.baseStuff)} · 제구 ${AbilityDisplayScale.rating(preset.baseCommand)}", "무브먼트 ${AbilityDisplayScale.rating(preset.baseMovement)} · 체력 ${AbilityDisplayScale.rating(preset.baseStamina)}")
        } + listOf(
            ScreenRow("지역", "19개 지역", "지역마다 학교와 코치, 포수가 다르다."),
            ScreenRow("난이도", "표준", "기본 난이도."),
            ScreenRow("능력 배분", "구위 · 제구 · 무브먼트 · 체력", "유형이 시작 능력을 정한다."),
        )))
        addAction("startHighSchool", "이 투수로 시작하기", "이 이름으로 마운드에 선다.", state.stage == GameStage.SETUP, listOf(ScreenPayloads.startHighSchool(state, context)))
}


internal fun ScreenBuilder.buildP003_PROLOGUE() {
        addSection(ScreenSection("letter", "도착한 편지", listOf(
            ScreenRow("선수", run?.identity?.name ?: "—", "이번 생의 첫 기록"),
            ScreenRow("편지", run?.news?.take(2)?.joinToString("\n\n") ?: "아직 편지가 오지 않았다.", "지난 생이 남긴 말."),
            ScreenRow("첫 공", if (highSchool?.tutorial?.started == true) "던졌다" else "아직", "불펜에서 한 구 던지고 학교를 고른다."),
        )))
        addAction("beginTutorial", "불펜으로", "첫 공을 던지러 간다.", run?.phase == HighSchoolPhase.PROLOGUE && highSchool?.tutorial?.started != true, listOf(hs(HighSchoolPhase4Command.BeginTutorial)))
        addAction("completeTutorial", "학교 고르러 가기", "첫 공은 던졌다. 이제 3년을 보낼 학교를 고른다.", run?.phase == HighSchoolPhase.PROLOGUE && (highSchool?.tutorial?.let { it.started && !it.completed } == true || state.pitch?.boundary == PitchBoundary.COMPLETED), listOf(hs(HighSchoolPhase4Command.CompleteTutorial(context.seed(state, "tutorial-complete")))))
        if (RebirthContinuity.resolve(state) == null) {
            // First life: one tap from the letter to the mound. The tutorial starts and the practice pitch opens together.
            val reusable = state.pitch == null || state.pitch?.boundary in setOf(PitchBoundary.COMPLETED, PitchBoundary.ABANDONED)
            val begin = if (highSchool?.tutorial?.started == true) emptyList() else listOf(hs(HighSchoolPhase4Command.BeginTutorial))
            val thrown = highSchool?.lastPresentation?.pitchNumber ?: 0
            addAction("openTutorialPitch", if (thrown > 0) "한 구 더 던지기" else "첫 공 던지기", if (thrown > 0) "감을 잡을 때까지. 세 구까지." else "포수 사인대로 한 구. 기록에는 안 남는다.",
                run?.phase == HighSchoolPhase.PROLOGUE && reusable && highSchool?.tutorial?.completed != true && (state.pitch?.boundary != PitchBoundary.COMPLETED || thrown in 1..2),
                begin + tutorialCommands(state, context))
        }
        if (RebirthContinuity.resolve(state) != null) {
            val reusable = state.pitch == null || state.pitch?.boundary in setOf(PitchBoundary.COMPLETED, PitchBoundary.ABANDONED)
            val pending = PitchStateTransitions.hasResult(state.pitch)
            val begin = if (highSchool?.tutorial?.started == true) emptyList() else listOf(hs(HighSchoolPhase4Command.BeginTutorial))
            actions.removeAll { it.id == "completeTutorial" }
            addAction("completeTutorial", "학교를 고르고 시작", "이번 생의 첫 등판을 준비합니다.", run?.phase == HighSchoolPhase.PROLOGUE && reusable && highSchool?.tutorial?.completed != true,
                begin + hs(HighSchoolPhase4Command.CompleteTutorial(context.seed(state, "tutorial-complete"))))
            addAction("openTutorialPitch", if (pending) "투구 결과 확인하기" else "지금 몸으로 한 구 던지기", "기록에 안 남는 연습 한 구.",
                run?.phase == HighSchoolPhase.PROLOGUE && ((reusable && highSchool?.tutorial?.completed != true) || pending),
                if (pending) PitchStateTransitions.resumeCommands(state.pitch) else begin + tutorialCommands(state, context))
            addAction("resumePitch", "투구 이어 하기", "던지던 공으로 돌아간다.", state.pitch?.boundary == PitchBoundary.SUSPENDED,
                PitchStateTransitions.resumeCommands(state.pitch))
        }
}


internal fun ScreenBuilder.buildP004_PITCH_TUTORIAL() {
        addSection(ScreenSection("first-pitch", "첫 투구", listOf(
            ScreenRow("첫 공", "포수 사인대로", "구종과 코스는 포수가 골라 뒀다."),
            ScreenRow("던지는 법", "길게 눌러 와인드업", "초록에서 손을 뗀다. 금색 한가운데면 퍼펙트."),
        )))
        val reusable = state.pitch == null || state.pitch?.boundary in setOf(PitchBoundary.COMPLETED, PitchBoundary.ABANDONED)
        val hasPendingResult = PitchStateTransitions.hasResult(state.pitch)
        val inProgress = state.pitch?.careerKind == PitchCareerKind.TUTORIAL && state.pitch?.boundary in setOf(PitchBoundary.RESERVED, PitchBoundary.PLAYING)
        val session = tutorialSession(state)
        val tutorialReady = (highSchool?.tutorial?.let { it.started && !it.completed } == true && reusable) || hasPendingResult || inProgress
        val commands = if (hasPendingResult || inProgress) PitchStateTransitions.resumeCommands(state.pitch) else tutorialCommands(state, context)
        addAction("openTutorialPitch", if (hasPendingResult) "투구 결과 확인하기" else "첫 공 던지기", if (hasPendingResult) "던진 공의 결과를 본다." else "포수 사인대로 한 구. 기록에는 안 남는다.", tutorialReady, commands)
        addAction("resumePitch", "투구 이어 하기", "던지던 공으로 돌아간다.", state.pitch?.boundary == PitchBoundary.SUSPENDED, PitchStateTransitions.resumeCommands(state.pitch))
        addAction("abandonPitch", "투구를 멈추고 나가기", "현재 타자와 기록을 유지하고 나갑니다.", PitchStateTransitions.canAbandon(state.pitch), listOfNotNull(state.pitch?.let { GameCommand.AbandonPitch(it.sessionId, "사용자가 투구를 포기함") }), true)
}


internal fun ScreenBuilder.buildP005_SCHOOL_SELECTION() {
        val schools = run?.schoolOptions?.ifEmpty { run?.let { HighSchoolContentCatalog.schools(it.identity.region) } } ?: emptyList()
        addSection(ScreenSection("schools", "학교 후보", schools.map { school ->
            ScreenRow(school.name, SchoolChoicePresentation.strength(school), SchoolChoicePresentation.fit(school))
        }))
        schools.forEach { school -> addAction("chooseSchool:${school.id.wire}", school.name, SchoolChoicePresentation.strength(school), run?.phase == HighSchoolPhase.SCHOOL_SELECTION, listOf(hs(HighSchoolPhase4Command.ChooseSchool(context.seed(state, "school:${school.id.wire}"), school.id)))) }
}


internal fun ScreenBuilder.buildP006_TRAINING() {
        val opportunity = run?.trainingOpportunity
        val recommended = opportunity?.focus
        addSection(ScreenSection("training", "오늘 훈련", listOf(
            ScreenRow("장면", recommended?.label ?: "훈련장", opportunity?.reason ?: "코치가 오늘 과제를 정해 뒀다. 하나 골라서 몸에 남기자."),
            ScreenRow("몸 상태", "구위 ${run?.pitcher?.stuff?.let(AbilityDisplayScale::rating) ?: 0} · 제구 ${run?.pitcher?.command?.let(AbilityDisplayScale::rating) ?: 0}", "무브먼트 ${run?.pitcher?.movement?.let(AbilityDisplayScale::rating) ?: 0} · 체력 ${run?.pitcher?.stamina?.let(AbilityDisplayScale::rating) ?: 0}"),
            ScreenRow("이번 훈련", "${run?.chapterTrainingCount ?: 0}회", "훈련이 끝나면 다음 일정으로."),
        )))
        val focuses = if (recommended == null) {
            HighSchoolTrainingFocus.entries
        } else {
            listOf(recommended) + HighSchoolTrainingFocus.entries.filter { it != recommended }
        }
        focuses.forEach { focus ->
            val recommendedMark = if (focus == recommended) "오늘 과제 · " else ""
            addAction(
                "train:${focus.wire}",
                "$recommendedMark${focus.label}",
                if (focus == recommended) {
                    opportunity?.reason ?: "${focus.label}에 집중한다."
                } else {
                    "${focus.label}에 집중한다."
                },
                run?.phase == HighSchoolPhase.TRAINING,
                listOf(hs(HighSchoolPhase4Command.Training(context.seed(state, "training:${focus.wire}"), focus, HighSchoolTrainingIntensity.STANDARD, focus.pitchKindOrNull()))),
            )
        }
}


internal fun ScreenBuilder.buildP007_RELATIONSHIP() {
        val event = run?.currentRelationshipEvent
        addSection(ScreenSection("relationship", event?.title ?: "이번 대화", listOf(
            ScreenRow(run?.let(RelationshipNarrative::speaker) ?: "동료", run?.let(ConversationPresentation::line) ?: "동료와 코치의 목소리가 들린다.", ""),
            ScreenRow("상대", run?.currentRelationshipTarget?.label ?: "팀", "감독 ${trustWord(run?.managerTrust ?: 0)} · 포수 ${trustWord(run?.catcherTrust ?: 0)} · 라이벌 ${trustWord(run?.rivalTrust ?: 0)}"),
        )))
        HighSchoolRelationshipResponse.entries.forEach { response ->
            val effects = run?.let { ConversationPresentation.previewEffects(it, context.seed(state, "relationship:${response.wire}"), response) }.orEmpty()
            addAction(
                "relationship:${response.wire}",
                run?.let { ConversationPresentation.title(it, response) } ?: relationshipChoiceTitle(event?.category, response),
                if (run != null) ChoiceEffect.summary(effects) else relationshipChoiceDetail(event?.category, response),
                run?.phase == HighSchoolPhase.RELATIONSHIP,
                listOf(hs(HighSchoolPhase4Command.Relationship(context.seed(state, "relationship:${response.wire}"), response))),
                effects = effects,
            )
        }
}


internal fun ScreenBuilder.buildP008_IMPORTANT_GAME() {
        val previewRun = highSchool?.takeIf { it.run.phase == HighSchoolPhase.IMPORTANT_GAME && it.activePitch == null }?.let {
            HighSchoolPhase4Kernel().reserveImportantGame(context.seed(state, "important-game"), it).state
        }
        val scenario = previewRun?.run?.currentGameScenario ?: run?.currentGameScenario
        val assignment = previewRun?.activePitch?.assignment ?: highSchool?.activePitch?.assignment
        if (assignment != null) addSection(ScreenSection("outing-assignment", OutingPresentation.roleLabel(assignment.role), listOf(
            ScreenRow("이번 목표", OutingPresentation.goal(assignment)),
            ScreenRow("투입", "${assignment.entryInning}회 · ${assignment.entryOuts}사", if (assignment.inheritedRunners > 0) "주자 ${assignment.inheritedRunners}명 승계" else "주자 없음"))))
        addSection(ScreenSection("important-game", scenario?.title ?: "승부처", listOf(
            ScreenRow("오늘", scenario?.narrative ?: "상황과 상대를 확인한 뒤 마운드에 오릅니다.", "직접 슬라이더로 던지는 타석입니다."),
            ScreenRow("상황", importantGameSituation(scenario), "승부처의 점수와 주자"),
            ScreenRow("기록", "${run?.performance?.pitches ?: 0}구 · ${run?.performance?.strikeouts ?: 0}탈삼진", state.pitch?.boundary?.let { pitchBoundaryLabel(it) } ?: "준비 전"),
        )))
        val reusable = state.pitch == null || state.pitch?.boundary in setOf(PitchBoundary.COMPLETED, PitchBoundary.ABANDONED)
        val canOpenImportantGame = run?.phase == HighSchoolPhase.IMPORTANT_GAME && reusable && highSchool?.activePitch == null
        val canOpenNextPitch = run?.phase == HighSchoolPhase.IMPORTANT_GAME && state.pitch?.boundary in setOf(PitchBoundary.COMPLETED, PitchBoundary.ABANDONED) && highSchool?.activePitch != null
        addAction("openImportantGame", "승부처에 오르기", "중요 경기의 첫 타석을 엽니다.", canOpenImportantGame, if (canOpenImportantGame) importantGameCommands(state, context) else emptyList())
        addAction("nextImportantPitch", "이어서 던지기", "현재 경기 상태에서 투구를 이어갑니다.", canOpenNextPitch, if (canOpenNextPitch) nextHighSchoolPitchCommands(state) else emptyList())
        val pendingResult = PitchStateTransitions.hasResult(state.pitch)
        val canResumePitch = pendingResult || state.pitch?.boundary in setOf(PitchBoundary.RESERVED, PitchBoundary.PLAYING, PitchBoundary.SUSPENDED)
        addAction("resumePitch", if (pendingResult) "투구 결과 확인하기" else "투구 이어 하기", if (pendingResult) "던진 공의 결과를 본다." else "던지던 공으로 돌아간다.", canResumePitch, PitchStateTransitions.resumeCommands(state.pitch))
        addAction("abandonPitch", "투구를 멈추고 나가기", "현재 타자와 기록을 유지하고 나갑니다.", PitchStateTransitions.canAbandon(state.pitch), listOfNotNull(state.pitch?.let { GameCommand.AbandonPitch(it.sessionId, "사용자가 투구를 포기함") }), true)
}


internal fun ScreenBuilder.buildP009_AWAKENING() {
        addSection(ScreenSection("awakening", "새로운 감각", (run?.awakeningOptions ?: HighSchoolContentCatalog.awakeningNodes.map { it.id }).take(8).map { awakening ->
            ScreenRow(awakening.label, "선택 가능", "이번 선택은 다음 장의 투구 감각에 남습니다.")
        }))
        run?.awakeningOptions.orEmpty().forEach { awakening -> addAction("awakening:${awakening.wire}", awakening.label, "${awakening.label}을(를) 선택합니다.", run?.phase == HighSchoolPhase.AWAKENING, listOf(hs(HighSchoolPhase4Command.ChooseAwakening(context.seed(state, "awakening:${awakening.wire}"), awakening)))) }
}


internal fun ScreenBuilder.buildP010_CHAPTER() {
        val chapter = run?.chapter
        addSection(ScreenSection("chapter", "이번에 쌓은 것", buildList {
            if ((run?.chapterTrainingCount ?: 0) > 0) add(ScreenRow("훈련", "${run?.chapterTrainingCount}회", "완료한 훈련"))
            addAll(chapterGameRows(state))
        }))
        addAction("advanceChapter", "다음 훈련 준비", "다음 훈련으로 이어갑니다.", run?.phase == HighSchoolPhase.CHAPTER_REVIEW, listOf(hs(HighSchoolPhase4Command.AdvanceChapter(context.seed(state, "chapter")))))
        val canClaim = run?.phase == HighSchoolPhase.CHAPTER_REVIEW && (chapter?.number ?: 8) < HighSchoolContentCatalog.chapters.size && run.chapterGameClaimed.not() && highSchool?.activePitch == null
        if (canClaim) {
            addAction("claimChapterGame", "한 경기 더 던지기", "원하면 정규 경기에 직접 등판할 수 있어요.", true, listOf(hs(HighSchoolPhase4Command.ClaimChapterGame(context.seed(state, "chapter-game")))))
        } else if (run?.chapterGameClaimed == true) {
            addAction("claimChapterGame", "이번 장은 던졌다", "정규 경기는 장마다 한 번.", false, emptyList())
        }
}


internal fun ScreenBuilder.buildP011_HIGH_SCHOOL_CAREER() {
        val played = highSchool?.seasonLog.orEmpty().filter { it.played && it.careerId == run?.careerId }
        val pitchedOuts = played.sumOf { it.outs }
        addSection(ScreenSection("career", "고교 커리어", listOf(
            ScreenRow("선수", run?.identity?.name ?: "—", "${run?.lifeNumber ?: 0}번째 생"),
            ScreenRow("현재 장면", run?.chapter?.title ?: "—", run?.phase?.label ?: "—"),
            ScreenRow("공식 경기", "${played.size + (run?.automaticGames ?: 0)}경기", "직접·자동 경기 합산"),
            ScreenRow("시즌 이닝", inningsLabel(pitchedOuts + (run?.automaticOuts ?: 0)), "직접·자동 투구 합산"),
            ScreenRow("직접 던진 이닝", inningsLabel(pitchedOuts), "자동 경기는 빼고 내 손으로 던진 것만"),
            ScreenRow("직접 던진 기록", "${run?.performance?.strikeouts ?: 0}탈삼진 ${run?.performance?.walks ?: 0}볼넷 ${run?.performance?.runsAllowed ?: 0}실점" + perfectSuffix(run), "${run?.performance?.pitches ?: 0}구"),
        )))
        if (played.isNotEmpty()) {
            addSection(ScreenSection("game-log", "경기 기록", played.asReversed().take(10).map { line -> highSchoolGameRow(line) }))
        }
}


internal fun ScreenBuilder.buildP012_TOURNAMENT_LEAGUE() {
        val rows = highSchool?.tournaments.orEmpty().filter { highSchool?.archive.isNullOrEmpty() || HighSchoolTournamentRules.belongsTo(it, run!!.careerId) }.map { tournament ->
            ScreenRow(tournament.name, tournament.playerRound, if (tournament.completed) "완료" else "진행 중")
        } + highSchool?.prospectBoard.orEmpty().take(8).map { prospect ->
            ScreenRow("${prospect.rank}위 ${prospect.name}", prospect.schoolName, "평가 ${prospect.score} · ${prospect.tag}")
        }
        addSection(ScreenSection("league", "대회와 순위", rows))
}
