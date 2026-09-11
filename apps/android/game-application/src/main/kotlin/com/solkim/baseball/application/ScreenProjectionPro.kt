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

internal fun ScreenBuilder.buildP016_PRO_CONTRACT() {
        addSection(ProfessionalStatusPresentation.section(state))
        val market = pro?.journeyState?.pendingContractMarket
        val contract = pro?.contract
        val salary = contract?.annualSalary
        val salaryText = if (salary == null) "제안 대기" else "%,d원".format(java.util.Locale.KOREA, salary)
        if (market != null && market.offers.isNotEmpty()) {
            addSection(
                ScreenSection(
                    "pro-contract-market",
                    if (market.kind == com.solkim.baseball.core.pro.ProContractMarketKind.ROOKIE) "신인 계약 시장" else if (market.kind == com.solkim.baseball.core.pro.ProContractMarketKind.FREE_AGENCY) "FA 시장" else "재계약 시장",
                    market.offers.map { offer ->
                        val team = ProCatalog.teams.firstOrNull { it.id == offer.teamId }
                        ScreenRow(
                            team?.name ?: offer.teamId,
                            "${offer.years}년 · 연봉 ${"%,d원".format(java.util.Locale.KOREA, offer.annualSalary)} · ${offer.rolePromise.label}",
                            buildString {
                                append(contractKindLabel(offer.contractKind))
                                append(" · ")
                                append(outlookLabel(offer.outlook))
                                append(" · ")
                                append(if (offer.preservesTeamLegacy) "잔류 유산 유지" else "이적")
                                offer.signingBonus?.let { append(" · 계약금 ${"%,d원".format(java.util.Locale.KOREA, it)}") }
                            },
                        )
                    },
                ),
            )
            val completedGoals = pro?.journeyState?.goalHistory.orEmpty().filter { it.outcome == com.solkim.baseball.core.pro.ProCareerGoalOutcome.COMPLETED }.map { it.ambition }.toSet()
            val ambitions = com.solkim.baseball.core.pro.ProCareerAmbition.entries.filter { it !in completedGoals }
            market.offers.forEach { offer ->
                val teamName = ProCatalog.teams.firstOrNull { it.id == offer.teamId }?.name ?: offer.teamId
                val choices = ambitions.map { it as com.solkim.baseball.core.pro.ProCareerAmbition? }.ifEmpty { listOf(null) }
                choices.forEach { ambition ->
                    val goalTitle = when (ambition) {
                        com.solkim.baseball.core.pro.ProCareerAmbition.FRANCHISE_ICON -> "한 팀의 전설"
                        com.solkim.baseball.core.pro.ProCareerAmbition.RECORD_BOOK -> "기록으로 남는 투수"
                        com.solkim.baseball.core.pro.ProCareerAmbition.ENDURING_PRO -> "오래 뛰는 선수"
                        null -> "이룬 목표를 이어가기"
                    }
                    val goalDetail = when (ambition) {
                        com.solkim.baseball.core.pro.ProCareerAmbition.FRANCHISE_ICON -> "한 팀에 오래 남아 그 팀의 얼굴이 된다."
                        com.solkim.baseball.core.pro.ProCareerAmbition.RECORD_BOOK -> "숫자로 남는다. 탈삼진과 이닝을 쌓는다."
                        com.solkim.baseball.core.pro.ProCareerAmbition.ENDURING_PRO -> "오래 뛴다. 시즌을 거듭할수록 값이 오른다."
                        null -> "이미 이룬 목표를 이어 간다."
                    }
                    addAction("acceptOffer:${offer.id}:${ambition?.wire ?: "complete"}", "$teamName · $goalTitle",
                        goalDetail, pro?.phase == ProCareerPhase.CONTRACT_OFFER,
                        listOf(proCommand(ProCommand.AcceptContractOffer(context.seed(state, "accept:${offer.id}"), offer.id, ambition))))
                }
            }
        } else {
            addSection(ScreenSection("pro-contract", "프로 계약", listOf(
                ScreenRow("프로 무대로", "고교에서 키운 선수로 도전하기", "고교에서 키운 능력 그대로."),
                ScreenRow("팀", pro?.team?.name ?: "팀을 고르는 중", pro?.team?.developmentPlan ?: "팀의 성장 계획"),
                ScreenRow("계약 기간", "${contract?.yearsRemaining ?: 0}년", "제시된 계약의 남은 시즌"),
                ScreenRow("연봉", salaryText, "한 시즌 연봉"),
                ScreenRow("보직", contract?.rolePromise?.label ?: pro?.role?.label ?: "선발", "약속받은 자리"),
            )))
            addAction("signContract", "계약 서명", "이 계약에 사인한다.", pro?.phase == ProCareerPhase.CONTRACT_OFFER, listOf(proCommand(ProCommand.SignContract)))
        }
        val name = run?.identity?.name ?: "민서준"
        if (highSchool == null && pro == null) addAction("startDirect", "프로부터 새로 시작", "별도 프로 선수로 시작합니다.", true,
            listOf(proCommand(ProCommand.StartDirect(ProStartDirectRequest(context.seed(state, "pro-direct"), "power_prospect", name)))))
        val canLink = highSchool != null && pro == null && run?.draftResult?.outcome == HighSchoolDraftOutcome.DRAFTED && run.phase in setOf(HighSchoolPhase.DRAFT, HighSchoolPhase.COMPLETED)
        if (highSchool != null) addAction("startLinked", "입단 계약 보기", "지명받은 그 이름 그대로 프로에 간다.", canLink,
            if (canLink) listOf(proCommand(ProCommand.StartLinked(linkedRequest(state, context)))) else emptyList())
}


internal fun ScreenBuilder.buildP017_PRO_WEEK() {
        if (pro != null) {
            pro.resolvedFollowUps.orEmpty().takeLast(3).reversed().forEach { followUp ->
                addSection(ScreenSection("followup:${followUp.decisionId}", "지난 선택의 결과", listOf(
                    ScreenRow(com.solkim.baseball.core.pro.ProWeeklyDecisionRules.title(followUp.type),
                        com.solkim.baseball.core.pro.ProWeeklyDecisionRules.summary(followUp), "${followUp.season}시즌 ${followUp.week}주차"),
                )))
            }
            if (com.solkim.baseball.core.pro.ProRoleRequestRules.shouldOffer(pro)) {
                addSection(ScreenSection("role-request", "스프링캠프 보직 지원", listOf(
                    ScreenRow("이번 시즌의 자리", "선발·중간·마무리 중 하나에 손을 든다", "시즌에 한 번. 조건부면 6주차에 감독과 다시 얘기한다."),
                )))
                com.solkim.baseball.core.pro.ProRoleRequestRules.requestableRoles.forEach { role ->
                    val outcome = com.solkim.baseball.core.pro.ProRoleRequestRules.evaluate(pro, role)
                    val outlook = when (outcome) {
                        com.solkim.baseball.core.pro.ProRoleRequestOutcome.ACCEPTED -> "감독이 받아 줄 것 같다"
                        com.solkim.baseball.core.pro.ProRoleRequestOutcome.CONDITIONAL -> "6주차까지 보고 정하겠다는 분위기"
                        com.solkim.baseball.core.pro.ProRoleRequestOutcome.REJECTED -> "아직 이르다. 거절당하면 믿음이 깎인다"
                    }
                    addAction("requestRole:${role.wire}", "${role.label} 지원", outlook, true,
                        listOf(proCommand(ProCommand.RequestRole(context.seed(state, "role-request"), role))))
                }
            } else pro.roleRequest?.let { request ->
                val result = when (request.outcome) {
                    com.solkim.baseball.core.pro.ProRoleRequestOutcome.ACCEPTED -> "받아들여졌다"
                    com.solkim.baseball.core.pro.ProRoleRequestOutcome.CONDITIONAL -> "${request.reviewWeek}주차에 다시 얘기하기로"
                    com.solkim.baseball.core.pro.ProRoleRequestOutcome.REJECTED -> "아직 이르다는 답"
                }
                addSection(ScreenSection("role-result", "감독의 대답", listOf(ScreenRow(request.requested.label, result))))
            }
        }
        val remaining = if (pro == null) 0 else ProCatalog.expectedRemainingOutings(pro.week, pro.injuryWeeks, pro.role, pro.proRulesVersion)
        val tensions = pro?.seasonTensions.orEmpty().take(2).map { tension ->
            ScreenRow(tension.title, tension.detail, "시즌 긴장")
        }
        val newsRows = pro?.news.orEmpty().take(3).map { line -> ScreenRow("", line, "") }
        addSection(ScreenSection("pro-week", "이번 주", listOf(
            ScreenRow("주차", pro?.week?.toString() ?: "—", ProCatalog.segmentLabel(pro?.seasonSegment ?: ProSeasonSegment.SPRING_CAMP)),
            ScreenRow("역할", pro?.role?.label ?: "—", "지금은 ${pro?.level?.label ?: "—"}"),
            ScreenRow("내 등판", "이번 시즌 직접 ${pro?.importantGames ?: 0}번 던졌다", "남은 일정에서 감독이 맡길 등판은 ${remaining}경기쯤. 승부처는 따로 부른다."),
            ScreenRow("성장", "구위 ${pro?.pitcher?.stuff?.let(AbilityDisplayScale::rating) ?: 0} · 무브먼트 ${pro?.pitcher?.movement?.let(AbilityDisplayScale::rating) ?: 0}", "이번 주에 무엇을 키울지 고른다."),
            ScreenRow("피로", "${pro?.fatigue ?: 0}", if ((pro?.fatigue ?: 0) >= 70) "몸이 무겁다. 이번 주는 쉬는 게 낫다." else "던질 만하다."),
        ) + tensions + newsRows))
        pro?.pitchLearningProject?.let { project ->
            addSection(ScreenSection("pitch-learning", "구종 익히기", TrainingPresentation.learningLines(project).map { ScreenRow("", it, "") }))
        }
        ProWeekPlan.currentChoices.forEach { plan ->
            addAction(
                "proPlan:${plan.wire}",
                plan.iosTitle(pro),
                plan.iosDescription(pro),
                pro?.phase == com.solkim.baseball.core.pro.ProCareerPhase.WEEKLY_PLAN,
                listOf(proCommand(ProCommand.PlanWeek(context.seed(state, "pro-plan:${plan.wire}"), plan, plan.targetPitchOrNull(pro)))),
            )
        }
        addAction(
            "proAdvanceSegment",
            "이 구간은 감독에게 맡긴다",
            "남은 몇 주를 한 번에 넘긴다.",
            pro?.phase == com.solkim.baseball.core.pro.ProCareerPhase.WEEKLY_PLAN,
            listOf(proCommand(ProCommand.AdvanceSegment(context.seed(state, "pro-segment"), ProWeekPlan.DEVELOP_STUFF, null))),
        )
}


internal fun ScreenBuilder.buildP018_PRO_IMPORTANT_GAME() {
        val headline = pro?.let { ProKernel().importantHeadline(it.seasonTrigger ?: com.solkim.baseball.core.pro.ProSeasonTrigger.STANDINGS_RACE, it.currentRival, it.level) }
        addSection(ScreenSection("pro-game", proScenarioTitle(pro?.seasonTrigger), listOfNotNull(
            ScreenRow("오늘", headline ?: "오늘 이 타석이 시즌의 무게를 가른다.", pro?.currentRival?.profile.orEmpty()),
            if ((pro?.activePitch?.pitches ?: 0) > 0) ScreenRow("지금까지", "${pro?.activePitch?.pitches ?: 0}구 · ${pro?.activePitch?.strikeouts ?: 0}탈삼진", "") else null,
        )))
        val reusable = state.pitch == null || state.pitch?.boundary in setOf(PitchBoundary.COMPLETED, PitchBoundary.ABANDONED)
        val canOpenProImportantGame = pro?.phase == ProCareerPhase.IMPORTANT_GAME && pro.activePitch == null && reusable
        val canOpenNextPitch = pro?.phase == ProCareerPhase.IMPORTANT_GAME && state.pitch?.boundary in setOf(PitchBoundary.COMPLETED, PitchBoundary.ABANDONED) && pro.activePitch != null && pro.activePitch?.ended == false
        val canFinishGame = pro?.phase == ProCareerPhase.IMPORTANT_GAME && pro.activePitch?.ended == true && state.pitch?.boundary in setOf(PitchBoundary.TERMINAL, PitchBoundary.COMPLETED)
        val proFinishCommands = mutableListOf<GameCommand>()
        if (pro?.activePitch?.ended == true) proFinishCommands += proCommand(ProCommand.FinishImportantGame)
        if (state.pitch?.boundary == PitchBoundary.TERMINAL) proFinishCommands += GameCommand.CompletePitch(requireNotNull(state.pitch).sessionId)
        addAction("openProImportantGame", "마운드에 오르기", "내가 던진다.", canOpenProImportantGame, if (canOpenProImportantGame) proImportantGameCommands(state, context) else emptyList())
        addAction("nextProPitch", "이어서 던지기", "현재 경기 상태에서 투구를 이어갑니다.", canOpenNextPitch, if (canOpenNextPitch) nextProPitchCommands(state) else emptyList())
        addAction("finishProGame", "이 경기의 끝을 본다", "결과를 받아들이고 시즌으로 돌아간다.", canFinishGame, proFinishCommands)
        val pendingResult = PitchStateTransitions.hasResult(state.pitch)
        val canResumePitch = pendingResult || state.pitch?.boundary in setOf(PitchBoundary.RESERVED, PitchBoundary.PLAYING, PitchBoundary.SUSPENDED)
        addAction("resumePitch", if (pendingResult) "투구 결과 확인하기" else "투구 이어 하기", if (pendingResult) "던진 공의 결과를 본다." else "던지던 공으로 돌아간다.", canResumePitch, PitchStateTransitions.resumeCommands(state.pitch))
        addAction("abandonPitch", "투구를 멈추고 나가기", "현재 타자와 기록을 유지하고 나갑니다.", PitchStateTransitions.canAbandon(state.pitch), listOfNotNull(state.pitch?.let { GameCommand.AbandonPitch(it.sessionId, "사용자가 투구를 포기함") }), true)
}


internal fun ScreenBuilder.buildP019_PRO_SEASON() {
        val tournament = pro?.nationalTournament
        val settlement = pro?.journeyState?.lastSettlement
        when {
            pro?.phase == ProCareerPhase.SEASON_SETTLEMENT && settlement != null -> {
                val stats = pro.careerStats.lastOrNull { it.season == settlement.season } ?: pro.currentStats
                val innings = stats.inningsOuts / 3
                val money = { value: Long -> "%,d원".format(java.util.Locale.KOREA, value) }
                val reasonRows = settlement.fanReasons.map { reason ->
                    ScreenRow(
                        fanReasonLabel(reason.kind),
                        "${if (reason.delta >= 0) "+" else ""}${reason.delta}",
                        fanReasonStory(reason.contentId),
                    )
                }
                val arc = com.solkim.baseball.core.pro.ProSeasonArcRules.title(pro.currentGameLines, pro.postseason)
                val goal = settlement.goalProgressAfter
                val goalRow = goal?.let { progress ->
                    val metric = progress.metrics.firstOrNull()
                    ScreenRow(ambitionTitle(progress.ambition),
                        if (progress.completed) "이뤘다" else metric?.let { "${it.current}/${it.target}" } ?: "진행 중",
                        if (progress.completed) "계약에 걸었던 약속을 지켰다." else metric?.let { goalMetricStory(it) } ?: "")
                }
                val hofNow = settlement.hallOfFameAfter
                addSection(ScreenSection("season-settlement", "${settlement.season}시즌 · ${seasonArcTitle(arc)}", listOfNotNull(
                    ScreenRow("성적", "${stats.games}경기 · ${innings}이닝 · ${stats.strikeouts}탈삼진", "9이닝당 실점 ${"%.2f".format(java.util.Locale.ROOT, stats.runPerNinePermille / 1_000.0)}"),
                    goalRow,
                    ScreenRow("연봉", money(settlement.salaryIncome), "올해 계약이 준 돈"),
                    ScreenRow("응원상품", money(settlement.merchandiseIncome), settlement.merchandiseTier?.let { merchandiseTierLabel(it) } ?: "팬이 사 준 만큼"),
                    ScreenRow("팬 지지", "${settlement.fanBefore} → ${settlement.fanAfter}", "올해 ${if (settlement.fanDelta >= 0) "+" else ""}${settlement.fanDelta}"),
                    ScreenRow("이 팀에서의 나", "${teamLegacyTierLabel(settlement.teamLegacyBefore)} → ${teamLegacyTierLabel(settlement.teamLegacyAfter)}", if (hofNow >= 70) "명예의 전당 헌액권 안. (${hofNow}/70)" else "명예의 전당까지 ${70 - hofNow}점 (${hofNow}/70)"),
                    ScreenRow("계약", "${settlement.contractYearsAfter}년 남음", settlementNextRouteLabel(settlement.nextRoute)),
                ) + reasonRows))
                addAction(
                    "acknowledgeSettlement",
                    "올해를 덮는다",
                    "다음 겨울로.",
                    true,
                    listOf(proCommand(ProCommand.AcknowledgeSeasonSettlement(context.seed(state, "season-settlement"), settlement.id))),
                )
            }
            pro?.phase == ProCareerPhase.NATIONAL_TEAM_CALL -> {
                val fan = pro.journeyState?.reputation?.fanSupport ?: 0
                val market = (pro.pitcher.stuff + pro.pitcher.command + pro.pitcher.movement + pro.pitcher.stamina) / 4
                addSection(ScreenSection("national-call", "국가대표 소집", listOf(
                    ScreenRow("전화가 왔다", "올해 성적이 대표팀 명단에 내 이름을 올렸다.", "조별 3경기는 팀이 치른다. 2승이면 결승, 그 마운드는 내가 맡는다."),
                    ScreenRow("대가", "다음 봄을 무거운 몸으로 시작한다.", "결승까지 가서 많이 던질수록 무겁다. 다칠 수도 있다. 조별에서 떨어지면 몸은 가볍다."),
                )))
                addAction(
                    "nationalTeam:accept",
                    "소집을 수락한다",
                    "국기를 달고 던진다.",
                    true,
                    listOf(proCommand(ProCommand.RespondNationalTeamCall(context.seed(state, "national-team:accept"), true))),
                )
                addAction(
                    "nationalTeam:decline",
                    "이번엔 사양한다",
                    "몸을 아낀다. 팬은 조금 실망한다.",
                    true,
                    listOf(proCommand(ProCommand.RespondNationalTeamCall(context.seed(state, "national-team:decline"), false))),
                )
            }
            pro?.phase == ProCareerPhase.NATIONAL_TOURNAMENT && tournament != null -> {
                val groupRows = tournament.groupGames.map { line ->
                    ScreenRow(
                        ProNationalTeamRules.opponentLabel(line.opponentId),
                        "${line.teamRuns}-${line.opponentRuns} ${if (line.won) "승" else "패"}",
                        "조별 ${line.gameNumber}경기",
                    )
                }
                addSection(
                    ScreenSection(
                        "national-group",
                        "환태평양 초청 대회",
                        groupRows + listOf(
                            ScreenRow(
                                "조별 성적",
                                "${tournament.groupWins}승 ${tournament.groupGames.size}경기",
                                if (tournament.stage == ProNationalTournamentStage.AWAITING_FINAL) {
                                    "결승에 올랐다. 이번엔 내가 던진다."
                                } else {
                                    tournament.result?.let(ProNationalTeamRules::resultLabel) ?: "대회 진행 중"
                                },
                            ),
                        ),
                    ),
                )
                if (tournament.stage == ProNationalTournamentStage.AWAITING_FINAL && tournament.result == null) {
                    addAction(
                        "nationalTeam:startFinal",
                        "결승 마운드에 오른다",
                        "국기를 달고 마지막 공을 던진다.",
                        true,
                        listOf(proCommand(ProCommand.StartNationalFinal(context.seed(state, "national-team:start-final")))),
                    )
                }
                tournament.result?.let { outcome ->
                    addSection(
                        ScreenSection(
                            "national-result",
                            "대회 결과",
                            listOfNotNull(
                                ScreenRow(ProNationalTeamRules.resultLabel(outcome), ProNationalTeamRules.news(outcome), "팬 지지 ${if (tournament.fanDelta >= 0) "+" else ""}${tournament.fanDelta}"),
                                if (tournament.exempted) ScreenRow("병역", "군 문제, 이 한 경기로 끝났다.", "금메달 한 번이면 복무를 마친다.") else null,
                            ),
                        ),
                    )
                    addAction(
                        "nationalTeam:acknowledge",
                        "겨울로",
                        "메달을 걸고 돌아간다.",
                        true,
                        listOf(proCommand(ProCommand.AcknowledgeNationalTeamResult(context.seed(state, "national-team:acknowledge")))),
                    )
                    CareerShareCopy.nationalMedal(state)?.let { share ->
                        addSection(ScreenSection("national-share", "공유", listOf(
                            ScreenRow("대회 기록", share, ""),
                        )))
                    }
                }
            }
            else -> {
                val honorRows = (pro?.awards.orEmpty().takeLast(5).map { ScreenRow("수상", it, "") } +
                    pro?.milestones.orEmpty().takeLast(5).map { ScreenRow("이정표", it, "") })
                addSection(ScreenSection("pro-season", "프로 시즌", listOf(
                    ScreenRow("시즌", pro?.season?.toString() ?: "—", ProCatalog.segmentLabel(pro?.seasonSegment ?: ProSeasonSegment.SPRING_CAMP)),
                    ScreenRow("올해의 나", ProSeasonRecordPresentation.line(pro?.currentStats), "이번 시즌 성적"),
                    ScreenRow("팀", pro?.standings?.firstOrNull { it.isPlayerTeam }?.let { "${it.wins}승 ${it.losses}패 ${it.draws}무" } ?: "—", "${pro?.standings?.firstOrNull { it.isPlayerTeam }?.rank ?: "—"}위"),
                    ScreenRow("다음 이야기", pro?.pendingDecision?.title ?: "다음 주간 계획", pro?.pendingDecision?.detail ?: "시즌은 계속된다."),
                ) + honorRows))
                pro?.pendingDecision?.let { decision ->
                    decision.choices.forEach { choice ->
                        addAction("seasonDecision:${choice.id}", choice.title, choice.detail, pro.phase == ProCareerPhase.SEASON_DECISION,
                            listOf(proCommand(ProCommand.ApplySeasonDecision(context.seed(state, "decision:${choice.id}"), decision.id, choice.id))),
                            effects = if (pro.phase == ProCareerPhase.SEASON_DECISION)
                                ProConversationPresentation.preview(pro, context.seed(state, "decision:${choice.id}"), choice.id) else emptyList())
                    }
                }
                addAction("reviewSeason", "시즌 결산 보기", "올해 남긴 것을 본다.", pro?.phase == ProCareerPhase.SEASON_REVIEW, listOf(proCommand(ProCommand.ReviewSeason(context.seed(state, "season-review")))))
                val proPlayed = pro?.currentGameLines.orEmpty().filter { it.played }
                if (proPlayed.isNotEmpty()) {
                    addSection(ScreenSection("pro-game-log", "이번 시즌 등판", proPlayed.asReversed().take(10).map { line -> proGameRow(line) }))
                }
            }
        }
}


internal fun ScreenBuilder.buildP020_OFFSEASON() {
        if (pro?.phase == ProCareerPhase.OFFSEASON_INVESTMENT) {
            val funds = pro.journeyState?.finances?.availableFunds ?: 0L
            val won = { value: Long -> "%,d원".format(java.util.Locale.KOREA, value) }
            fun shortfall(cost: Long): String? = (cost - funds).takeIf { it > 0 }?.let { "자금 ${won(it)} 부족" }
            addSection(ScreenSection("offseason-investment", "겨울 투자", listOf(
                ScreenRow("쓸 수 있는 돈", won(funds), "이번 겨울, 어디에 쓸까."),
            )))
            val enabled = true
            addAction(
                "investment:pitch_lab",
                "피치랩 · ${won(50_000_000L)}",
                shortfall(50_000_000L) ?: "겨울 내내 제구를 다듬는다. 봄에 한 발 앞선다.",
                enabled && funds >= 50_000_000L,
                listOf(proCommand(ProCommand.ChooseInvestment(context.seed(state, "investment:pitch_lab"), ProOffseasonInvestment.PITCH_LAB, ProDevelopmentFocus.COMMAND))),
            )
            addAction(
                "investment:recovery_team",
                "몸 관리팀 · ${won(40_000_000L)}",
                shortfall(40_000_000L) ?: "전문가에게 몸을 맡긴다. 다음 시즌 부상이 덜하다.",
                enabled && funds >= 40_000_000L,
                listOf(proCommand(ProCommand.ChooseInvestment(context.seed(state, "investment:recovery_team"), ProOffseasonInvestment.RECOVERY_TEAM, null))),
            )
            addAction(
                "investment:fan_foundation",
                "팬 재단 · ${won(30_000_000L)}",
                shortfall(30_000_000L) ?: "팬들에게 돌려준다. 지지가 오래 간다.",
                enabled && funds >= 30_000_000L,
                listOf(proCommand(ProCommand.ChooseInvestment(context.seed(state, "investment:fan_foundation"), ProOffseasonInvestment.FAN_FOUNDATION, null))),
            )
            addAction(
                "investment:none",
                "이번엔 안 한다",
                "돈은 아껴 둔다.",
                enabled,
                listOf(proCommand(ProCommand.ChooseInvestment(context.seed(state, "investment:none"), ProOffseasonInvestment.NONE, null))),
            )
        } else {
        addSection(ScreenSection("offseason", "겨울의 선택", listOf(
            ScreenRow("계약", "${pro?.contract?.yearsRemaining ?: 0}년 남음", "남을까, 떠날까, 복무할까, 벗을까."),
            ScreenRow("1군 경력", "${pro?.serviceYears ?: 0}년", if (pro?.militaryCompleted == true) "병역은 끝났다" else "병역은 아직"),
        )))
        val offseasonEnabled = pro?.phase == com.solkim.baseball.core.pro.ProCareerPhase.OFFSEASON_DECISION
        val faEligible = (pro?.serviceYears ?: 0) >= 6 && (pro?.contract?.yearsRemaining ?: 0) == 0
        addAction(
            "offseason:continue",
            "계속하기",
            "한 해 더 이 유니폼을 입는다.",
            offseasonEnabled,
            listOf(proCommand(ProCommand.ChooseOffseason(context.seed(state, "offseason:continue"), OffseasonDecision.CONTINUE))),
        )
        addAction(
            "offseason:military_service",
            "군 복무",
            "두 시즌을 비우고 복무를 다녀온다. 한 번뿐이다.",
            offseasonEnabled && pro?.militaryCompleted != true,
            listOf(proCommand(ProCommand.ChooseOffseason(context.seed(state, "offseason:military_service"), OffseasonDecision.MILITARY_SERVICE))),
        )
        addAction(
            "offseason:free_agency",
            "FA 시장",
            if (faEligible) "새 유니폼을 고른다." else "1군 6년을 채우고 계약이 끝나야 열린다.",
            offseasonEnabled && faEligible,
            listOf(proCommand(ProCommand.ChooseOffseason(context.seed(state, "offseason:free_agency"), OffseasonDecision.FREE_AGENCY))),
        )
        addAction(
            "offseason:retire",
            "은퇴하기",
            "글러브를 벗는다. 되돌릴 수 없다.",
            offseasonEnabled,
            listOf(proCommand(ProCommand.ChooseOffseason(context.seed(state, "offseason:retire"), OffseasonDecision.RETIRE))),
            destructive = true,
        )
        }
}


internal fun ScreenBuilder.buildP021_PRO_RETIREMENT() {
        val preview = pro?.journeyState?.let { com.solkim.baseball.core.pro.ProJourneyKernel.retirementPreview(it, pro.team.id) }
        val hof = pro?.let { ProKernel().hallOfFameProjection(it) } ?: 0
        val honorRows = preview?.honors.orEmpty().map { honor -> ScreenRow("훈장", retirementHonorTitle(honor.kind, honor.teamId), retirementHonorStory(honor.kind)) }
        addSection(ScreenSection("retirement", "은퇴", listOfNotNull(
            ScreenRow("${pro?.age ?: "—"}살, 마지막 계절", "${pro?.careerStats?.size ?: 0}시즌 · ${pro?.careerGames() ?: 0}경기 · ${pro?.careerStrikeouts() ?: 0}탈삼진", "마지막 공은 ${pro?.team?.name ?: "이 팀"}의 유니폼으로 던진다."),
            ScreenRow("명예의 전당", if (hof >= 70) "헌액 확정" else "헌액까지 ${70 - hof}점", "$hof/70"),
            pro?.let { ScreenRow("다음 생으로", "야구혼 +${ProRetirementLedger.soulBonus(it)}", "이 커리어가 다음 생에 남기는 힘") },
            preview?.careerEarnings?.takeIf { it > 0 }?.let { ScreenRow("통산 수입", "%,d원".format(java.util.Locale.KOREA, it), "") },
        ) + honorRows))
        addAction("retire", "은퇴하고 기록 남기기", "글러브를 벗는다. 되돌릴 수 없다.", pro?.phase == ProCareerPhase.RETIREMENT_DECISION, listOf(proCommand(ProCommand.ChooseOffseason(context.seed(state, "retire"), OffseasonDecision.RETIRE))), destructive = true)
}


internal fun ScreenBuilder.buildP022_PRO_LEGACY() {
        val ceremony = pro?.news.orEmpty().take(3)
        val honorRows = pro?.journeyState?.retirementHonors.orEmpty().map { honor -> ScreenRow("훈장", retirementHonorTitle(honor.kind, honor.teamId), retirementHonorStory(honor.kind)) }
        if (ceremony.isNotEmpty() || honorRows.isNotEmpty()) addSection(ScreenSection("retirement-ceremony", "은퇴식", ceremony.map { ScreenRow("", it, "") } + honorRows))
        addSection(ScreenSection("pro-legacy", "다음 생에 가져갈 하나", pro?.legacyCandidates.orEmpty().map { candidate ->
            val family = HighSchoolSignatureLegacyRules.definitions.firstOrNull { it.id == candidate.id }?.family.orEmpty()
            ScreenRow(candidate.title, legacyEvidence(candidate.evidenceSummary, pro), proLegacyFarewell(family))
        }))
        pro?.legacyCandidates.orEmpty().forEach { candidate ->
            val family = HighSchoolSignatureLegacyRules.definitions.firstOrNull { it.id == candidate.id }?.family.orEmpty()
            addAction("selectProLegacy:${candidate.id}", candidate.title, legacyEffect(candidate.id), pro?.phase == ProCareerPhase.LEGACY_SELECTION, listOf(proCommand(ProCommand.SelectLegacy(candidate.id))))
        }
}
