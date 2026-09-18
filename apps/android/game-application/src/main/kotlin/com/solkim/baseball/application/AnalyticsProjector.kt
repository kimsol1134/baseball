package com.solkim.baseball.application

import com.solkim.baseball.core.highschool.HighSchoolDraftOutcome
import com.solkim.baseball.core.highschool.HighSchoolPhase
import com.solkim.baseball.core.highschool.HighSchoolPhase4Command
import com.solkim.baseball.core.highschool.HighSchoolPhase4State
import com.solkim.baseball.core.highschool.HighSchoolSignatureLegacyRules
import com.solkim.baseball.core.highschool.HighSchoolState
import com.solkim.baseball.core.highschool.HighSchoolTrainingFocus
import com.solkim.baseball.core.pro.ProCommand
import com.solkim.baseball.core.pro.ProCatalog
import com.solkim.baseball.model.Hashing

public object AnalyticsProjector {
    /** Stable IDs are aggregate-internal; no raw career/install identifier is sent to SDKs. */
    public fun receiptId(installId: String, eventName: String, scope: String): String =
        "matrix:" + Hashing.sha256Hex("$installId|$eventName|$scope").take(56)

    public fun toReceipt(
        event: ProjectedAnalyticsEvent,
        state: GameAggregateState,
    ): AnalyticsReceipt {
        val properties = event.properties.toSortedMap().map { (key, value) -> key to value.wire() }
        // Projected transitions cross exactly the same typed/domain boundary as explicit
        // viewport/manual receipts. This fails the command before an invalid enum or numeric
        // wire can become durable aggregate evidence.
        AnalyticsContract.validateManual(event.eventName, properties)
        return AnalyticsReceipt(
            receiptId = receiptId(state.installId, event.eventName, event.scope),
            eventName = event.eventName,
            revision = state.revision,
            commitment = state.commitment,
            properties = properties,
        )
    }

    /**
     * Derives only semantic transitions.  Challenge snapshots and the retired Daily wire are
     * hard guards here, so a later caller cannot accidentally bypass the matrix policy.
     */
    public fun project(
        before: GameAggregateState,
        after: GameAggregateState,
        envelope: GameCommandEnvelope,
    ): List<AnalyticsReceipt> {
        val command = envelope.command
        if (before.highSchool?.challenge?.active == true || after.highSchool?.challenge?.active == true) return emptyList()
        val events = linkedSetOf<ProjectedAnalyticsEvent>()

        fun add(eventName: String, scope: String, properties: Map<String, AnalyticsValue> = emptyMap()) {
            if (eventName in AnalyticsContract.nonRetiredEvents) {
                val allowed = AnalyticsContract.allowedProperties.getValue(eventName)
                require(properties.keys.all { it in allowed }) { "analytics.projected_property:$eventName" }
                events += ProjectedAnalyticsEvent(eventName, scope, properties)
            }
        }

        when (command) {
            GameCommand.EnterSetup -> if (before.stage == GameStage.OPENING && after.stage == GameStage.SETUP) {
                add("onboarding_started", "install")
            }
            GameCommand.ResetProgress -> Unit
            is GameCommand.HighSchool -> projectHighSchool(before, after, command.command, ::add)
            is GameCommand.Pro -> projectPro(before, after, command.command, ::add)
            is GameCommand.CompletePitch -> Unit
            is GameCommand.AbandonPitch -> {
                val pitch = before.pitch
                if (pitch != null && !pitch.challengeRun && pitch.careerKind != PitchCareerKind.TUTORIAL) {
                    val run = after.highSchool?.run
                    add(
                        "game_abandoned",
                        "game:${pitch.gameId}",
                        buildMap {
                            put("pitches", AnalyticsValue.Whole(pitch.pitchIndex.toLong()))
                            run?.let {
                                put("chapter", AnalyticsValue.Whole(it.chapter.number.toLong()))
                                put("life_number", AnalyticsValue.Whole(it.lifeNumber.toLong()))
                                put("act_number", AnalyticsValue.Whole(actNumber(it.chapter.number).toLong()))
                                put("phase", AnalyticsValue.Text(it.phase.wire))
                                put("development_rules_version", AnalyticsValue.Whole(it.worldRulesVersion.toLong()))
                            }
                            put("games_completed", AnalyticsValue.Whole(after.meta.completedGameCount.toLong()))
                        },
                    )
                }
            }
            is GameCommand.UpdateCompanion -> Unit
            is GameCommand.UpdateSettings -> Unit
            is GameCommand.SetPitchHoldCall -> Unit
            is GameCommand.RecordAnalytics -> Unit
            is GameCommand.ReservePitch,
            is GameCommand.StartPitch,
            is GameCommand.CommitPitch,
            is GameCommand.ConsumePitch,
            is GameCommand.MarkPitchTerminal,
            is GameCommand.SuspendPitch,
            is GameCommand.ResumePitch,
            is GameCommand.ClearPitchPresentation -> Unit
        }

        val existing = after.analytics.receipts.mapTo(hashSetOf()) { it.receiptId }
        return events.map { toReceipt(it, after) }.filterNot { it.receiptId in existing }
    }

    private fun projectHighSchool(
        before: GameAggregateState,
        after: GameAggregateState,
        command: HighSchoolPhase4Command,
        add: (String, String, Map<String, AnalyticsValue>) -> Unit,
    ) {
        val previous = before.highSchool
        val current = after.highSchool
        if (previous?.challenge?.active == true || current?.challenge?.active == true) return
        val previousRun = previous?.run
        val run = current?.run ?: return
        if (ProRetirementLedger.isHighSchoolStart(command) && previous == null) {
            add("onboarding_completed", "install", emptyMap())
            val inheritedIntent = current.nextRunIntent
            if (inheritedIntent != null) {
                add(
                    "next_run_intent_applied",
                    "career:${run.careerId}",
                    mapOf(
                        "pledge_id" to AnalyticsValue.Text(inheritedIntent.pledgeId),
                        "life_number" to AnalyticsValue.Whole(run.lifeNumber.toLong()),
                    ),
                )
            }
            current.inheritance.selectedSignatureLegacyId?.let { legacyId ->
                add(
                    "signature_legacy_equipped",
                    "life:${run.careerId}",
                    mapOf(
                        "legacy_id" to AnalyticsValue.Text(legacyId),
                        "family" to AnalyticsValue.Text(signatureFamily(legacyId)),
                        "life_number" to AnalyticsValue.Whole(run.lifeNumber.toLong()),
                        "total_rating_bonus" to AnalyticsValue.Whole(signatureBonus(legacyId).toLong()),
                        "inheritance_rules_version" to AnalyticsValue.Whole((current.inheritance.inheritanceRulesVersion ?: 0).toLong()),
                        "soul_total" to AnalyticsValue.Whole(current.inheritance.automaticSoulEarned.toLong()),
                        "soul_wallet" to AnalyticsValue.Whole(current.inheritance.soulPoints.toLong()),
                        "soul_lifetime_earned" to AnalyticsValue.Whole(current.inheritance.soulTotalEarned.toLong()),
                        "soul_applied" to AnalyticsValue.Whole(current.inheritance.automaticSoulEarned.toLong()),
                    ),
                )
            }
            if (run.lifeNumber > 1) {
                add(
                    "rebirth_started",
                    "life:${run.careerId}",
                    mapOf(
                        "life_number" to AnalyticsValue.Whole(run.lifeNumber.toLong()),
                        "entry_point" to AnalyticsValue.Text("setup_flow"),
                        "inheritance_rules_version" to AnalyticsValue.Whole((current.inheritance.inheritanceRulesVersion ?: 0).toLong()),
                        "soul_total" to AnalyticsValue.Whole(current.inheritance.automaticSoulEarned.toLong()),
                        "soul_wallet" to AnalyticsValue.Whole(current.inheritance.soulPoints.toLong()),
                        "soul_lifetime_earned" to AnalyticsValue.Whole(current.inheritance.soulTotalEarned.toLong()),
                        "soul_applied" to AnalyticsValue.Whole(current.inheritance.automaticSoulEarned.toLong()),
                    ),
                )
            }
        }

        if (previousRun != null && previousRun.phase != run.phase && !ProRetirementLedger.isHighSchoolStart(command)) {
            add(
                "phase_entered",
                "career:${run.careerId}|phase:${run.phase.wire}|revision:${after.revision}",
                mapOf(
                    "phase" to AnalyticsValue.Text(run.phase.wire),
                    "chapter" to AnalyticsValue.Whole(run.chapter.number.toLong()),
                    "act_number" to AnalyticsValue.Whole(actNumber(run.chapter.number).toLong()),
                    "life_number" to AnalyticsValue.Whole(run.lifeNumber.toLong()),
                ),
            )
        }

        when (command) {
            is HighSchoolPhase4Command.CompleteTutorial -> {
                if (previous?.tutorial?.completed != true && current.tutorial.completed &&
                    previous?.challenge?.active != true && current.challenge.active != true
                ) {
                    add("first_pitch", "install", emptyMap())
                }
            }
            is HighSchoolPhase4Command.AdvanceChapter -> if (previousRun != null && previousRun.chapter.number != run.chapter.number) {
                add(
                    "chapter_advanced",
                    "career:${run.careerId}|chapter:${run.chapter.number}",
                    mapOf(
                        "chapter" to AnalyticsValue.Whole(run.chapter.number.toLong()),
                        "act_number" to AnalyticsValue.Whole(actNumber(run.chapter.number).toLong()),
                    ),
                )
            }
            is HighSchoolPhase4Command.Training,
            is HighSchoolPhase4Command.TrainingBlock -> {
                val beforeEvidence = previous?.trainingEvidence.orEmpty().map { "${it.careerId}:${it.trainingNumber}" }.toSet()
                current.trainingEvidence
                    .filter { "${it.careerId}:${it.trainingNumber}" !in beforeEvidence }
                    .sortedBy { it.trainingNumber }
                    .forEach { evidence ->
                        add(
                            "career_training_completed",
                            "training:${evidence.careerId}:${evidence.trainingNumber}",
                            buildMap {
                                put("life_number", AnalyticsValue.Whole(evidence.lifeNumber.toLong()))
                                put("act_number", AnalyticsValue.Whole(actNumber(evidence.chapterNumber).toLong()))
                                put("focus_id", AnalyticsValue.Text(evidence.focus.wire))
                                put("intensity_id", AnalyticsValue.Text(evidence.intensity.wire))
                                evidence.targetPitch?.let { put("target_pitch_id", AnalyticsValue.Text(it.wire)) }
                                put("growth_points", AnalyticsValue.Whole(evidence.growthPoints.toLong()))
                                put("fatigue_delta", AnalyticsValue.Whole(evidence.fatigueDelta.toLong()))
                            },
                        )
                    }
            }
            is HighSchoolPhase4Command.SelectPledge -> current?.pledge?.let { pledge ->
                add(
                    "run_pledge_selected",
                    "career:${run.careerId}",
                    mapOf(
                        "pledge_id" to AnalyticsValue.Text(pledge.definition.id),
                        "tier" to AnalyticsValue.Text(pledge.definition.tier.wire),
                        "life_number" to AnalyticsValue.Whole(run.lifeNumber.toLong()),
                        "recommended" to AnalyticsValue.Flag(previous?.nextRunIntent?.pledgeId == pledge.definition.id),
                    ),
                )
            }
            is HighSchoolPhase4Command.SaveNextRunIntent -> add(
                "next_run_intent_saved",
                "career:${run.careerId}",
                mapOf(
                    "pledge_id" to AnalyticsValue.Text(command.intent.pledgeId),
                    "source_life_number" to AnalyticsValue.Whole(command.intent.sourceLifeNumber.toLong()),
                ),
            )
            is HighSchoolPhase4Command.PrepareReturnPlan -> current?.returnPlan?.let { plan ->
                add("return_plan_tapped", "plan:${plan.receiptId}", returnPlanProperties(plan, current.selectedDayKey))
                add("return_plan_eligible", "plan:${plan.receiptId}", returnPlanProperties(plan, current.selectedDayKey))
            }
            is HighSchoolPhase4Command.DismissReturnPlan -> previous?.returnPlan?.let { plan ->
                add("return_plan_dismissed", "plan:${plan.receiptId}", returnPlanProperties(plan, current.selectedDayKey))
            }
            is HighSchoolPhase4Command.ClaimWeeklyReward -> if (current?.weekly?.rewardClaimed == true) {
                add(
                    "weekly_program_completed",
                    "week:${current.weekly.weekKey}",
                    mapOf(
                        "week_key" to AnalyticsValue.Text(current.weekly.weekKey),
                        "completed_tasks" to AnalyticsValue.Whole(current.weekly.tasks.count { it.completed }.toLong()),
                        "perfect" to AnalyticsValue.Flag(current.weekly.tasks.all { it.completed }),
                    ),
                )
            }
            is HighSchoolPhase4Command.ResolveDraft -> current?.run?.draftResult?.let { draft ->
                add(
                    "draft_resolved",
                    "career:${run.careerId}",
                    mapOf(
                        "drafted" to AnalyticsValue.Flag(draft.outcome == HighSchoolDraftOutcome.DRAFTED),
                        "score" to AnalyticsValue.Whole(draft.evaluationScore.toLong()),
                        "life_number" to AnalyticsValue.Whole(run.lifeNumber.toLong()),
                        "act_number" to AnalyticsValue.Whole(actNumber(run.chapter.number).toLong()),
                    ),
                )
            }
            is HighSchoolPhase4Command.SelectLegacy -> {
                val legacyId = command.legacyId
                add(
                    "signature_legacy_selected",
                    "career:${run.careerId}",
                    mapOf(
                        "legacy_id" to AnalyticsValue.Text(legacyId),
                        "family" to AnalyticsValue.Text(signatureFamily(legacyId)),
                        "life_number" to AnalyticsValue.Whole(run.lifeNumber.toLong()),
                        "drafted" to AnalyticsValue.Flag(run.draftResult?.outcome == HighSchoolDraftOutcome.DRAFTED),
                        "rating_growth" to AnalyticsValue.Whole(signatureRatingGrowth(legacyId, current.startingPitcher, run.pitcher).toLong()),
                        "includes_pro_career" to AnalyticsValue.Flag(after.pro?.careerStats?.isNotEmpty() == true),
                        "pro_seasons" to AnalyticsValue.Whole((after.pro?.careerStats?.size ?: 0).toLong()),
                    ),
                )
            }
            is HighSchoolPhase4Command.FinalizeArchive -> current?.archive?.lastOrNull()?.let { record ->
                add(
                    "life_completed",
                    "career:${record.careerId}",
                    buildMap {
                        put("life_number", AnalyticsValue.Whole(record.lifeNumber.toLong()))
                        put("act_number", AnalyticsValue.Whole(actNumber(run.chapter.number).toLong()))
                        put("drafted", AnalyticsValue.Flag(record.drafted))
                        put("evaluation", AnalyticsValue.Whole(record.draftEvaluation.toLong()))
                        put("trainings", AnalyticsValue.Whole(run.totalTrainingsCompleted.toLong()))
                        put("important_games", AnalyticsValue.Whole(record.importantGames.toLong()))
                        put("pitches", AnalyticsValue.Whole(record.pitches.toLong()))
                        record.selectedSignatureLegacyId?.let { put("legacy_id", AnalyticsValue.Text(it)) }
                        put("legacy_rules_version", AnalyticsValue.Whole(HighSchoolSignatureLegacyRules.RULES_VERSION.toLong()))
                        put("unlocked_legacy_count", AnalyticsValue.Whole(current.inheritance.unlockedSignatureLegacyIds.size.toLong()))
                        put("inheritance_rules_version", AnalyticsValue.Whole((current.inheritance.inheritanceRulesVersion ?: 0).toLong()))
                        put("soul_total", AnalyticsValue.Whole(current.inheritance.automaticSoulEarned.toLong()))
                        put("soul_wallet", AnalyticsValue.Whole(current.inheritance.soulPoints.toLong()))
                        put("soul_lifetime_earned", AnalyticsValue.Whole(current.inheritance.soulTotalEarned.toLong()))
                        put("soul_applied", AnalyticsValue.Whole(current.inheritance.automaticSoulEarned.toLong()))
                    },
                )
                val pledgeId = record.pledgeId
                if (pledgeId != null) {
                    add(
                        "run_pledge_resolved",
                        "career:${record.careerId}",
                        mapOf(
                            "pledge_id" to AnalyticsValue.Text(pledgeId),
                            "achieved" to AnalyticsValue.Flag(record.pledgeAchieved),
                            "progress_ratio" to AnalyticsValue.Decimal(
                                current.pledge?.let { pledge ->
                                    if (pledge.definition.target > 0) (pledge.progress.toDouble() / pledge.definition.target.toDouble()).coerceIn(0.0, 1.0) else 0.0
                                } ?: 0.0,
                            ),
                            "reward_permille" to AnalyticsValue.Whole(
                                current.pledge?.definition?.tier?.rewardPermille?.toLong() ?: 0L,
                            ),
                        ),
                    )
                }
            }
            is HighSchoolPhase4Command.BeginRebirth, is HighSchoolPhase4Command.ConfigureRebirth -> {
                val entryPath = (command as? HighSchoolPhase4Command.BeginRebirth)?.entryPath ?: "customize"
                val inheritedIntent = previous?.nextRunIntent
                val appliedIntent = current.nextRunIntent
                if (inheritedIntent != null && appliedIntent == inheritedIntent) {
                    add(
                        "next_run_intent_applied",
                        "career:${run.careerId}",
                        mapOf(
                            "pledge_id" to AnalyticsValue.Text(appliedIntent.pledgeId),
                            "life_number" to AnalyticsValue.Whole(run.lifeNumber.toLong()),
                        ),
                    )
                }
                val inheritedLegacy = previous?.inheritance?.selectedSignatureLegacyId
                val equippedLegacy = current.inheritance.selectedSignatureLegacyId
                if (inheritedLegacy != null && equippedLegacy == inheritedLegacy) {
                    add(
                        "signature_legacy_equipped",
                        "life:${run.careerId}",
                        mapOf(
                            "legacy_id" to AnalyticsValue.Text(equippedLegacy),
                            "family" to AnalyticsValue.Text(signatureFamily(equippedLegacy)),
                            "life_number" to AnalyticsValue.Whole(run.lifeNumber.toLong()),
                            "total_rating_bonus" to AnalyticsValue.Whole(signatureBonus(equippedLegacy).toLong()),
                            "inheritance_rules_version" to AnalyticsValue.Whole((current.inheritance.inheritanceRulesVersion ?: 0).toLong()),
                            "soul_total" to AnalyticsValue.Whole(current.inheritance.automaticSoulEarned.toLong()),
                            "soul_wallet" to AnalyticsValue.Whole(current.inheritance.soulPoints.toLong()),
                            "soul_lifetime_earned" to AnalyticsValue.Whole(current.inheritance.soulTotalEarned.toLong()),
                            "soul_applied" to AnalyticsValue.Whole(current.inheritance.automaticSoulEarned.toLong()),
                        ),
                    )
                }
                add(
                    "rebirth_started",
                    "life:${run.careerId}",
                    buildMap {
                        put("life_number", AnalyticsValue.Whole(run.lifeNumber.toLong()))
                        put("entry_point", AnalyticsValue.Text(entryPath))
                        current.inheritance.selectedSignatureLegacyId?.let { put("selected_legacy_id", AnalyticsValue.Text(it)) }
                        current.inheritance.inheritanceRulesVersion?.let { put("inheritance_rules_version", AnalyticsValue.Whole(it.toLong())) }
                        put("soul_total", AnalyticsValue.Whole(current.inheritance.soulTotalEarned.toLong()))
                        put("soul_wallet", AnalyticsValue.Whole(current.inheritance.soulPoints.toLong()))
                        put("soul_lifetime_earned", AnalyticsValue.Whole(current.inheritance.soulTotalEarned.toLong()))
                        put("soul_applied", AnalyticsValue.Whole(current.inheritance.automaticSoulEarned.toLong()))
                    },
                )
                if (entryPath in setOf("quick_rebirth", "customize")) {
                    add("recap_continue_tapped", "career:${previousRun?.careerId ?: run.careerId}", mapOf(
                        "life_number" to AnalyticsValue.Whole((previousRun?.lifeNumber ?: run.lifeNumber).toLong()),
                        "drafted" to AnalyticsValue.Flag(previousRun?.draftResult?.outcome == HighSchoolDraftOutcome.DRAFTED),
                        "entry_path" to AnalyticsValue.Text(entryPath),
                        "has_suggested_intent" to AnalyticsValue.Flag(previous?.nextRunIntent != null),
                        "intent_saved" to AnalyticsValue.Flag(current.nextRunIntent != null),
                    ))
                }
            }
            is HighSchoolPhase4Command.FinishImportantGame -> {
                val session = previous?.activePitch
                if (session != null && !previous.challenge.active) {
                    val reportProperties = buildMap {
                        put("mode", AnalyticsValue.Text("high_school"))
                        put("sequence_mastery_count", AnalyticsValue.Whole(session.sequenceMasteryCount.toLong()))
                        acceptanceRate(session.recommendationAccepted, session.pitches)?.let { put("recommendation_acceptance_rate", it) }
                        put("development_rules_version", AnalyticsValue.Whole(run.worldRulesVersion.toLong()))
                        put("ability_moment_count", AnalyticsValue.Whole(session.abilityMoments.size.toLong()))
                        session.abilityMoments.distinct().sorted().takeIf { it.isNotEmpty() }?.let {
                            put("ability_moment_types", AnalyticsValue.Text(it.joinToString(",")))
                        }
                        put("life_number", AnalyticsValue.Whole(run.lifeNumber.toLong()))
                        put("act_number", AnalyticsValue.Whole(actNumber(run.chapter.number).toLong()))
                        put("result", AnalyticsValue.Text(if (session.runsAllowed == 0) "scoreless" else "runs_allowed"))
                        put("strikeouts", AnalyticsValue.Whole(session.strikeouts.toLong()))
                        put("walks", AnalyticsValue.Whole(session.walks.toLong()))
                        put("runs", AnalyticsValue.Whole(session.runsAllowed.toLong()))
                    /*
                     * The current Kotlin durable session does not retain the Swift scenario's
                     * maximum batter count or its completed sequence-tag set after a terminal
                     * plate appearance.  Leaving those fields absent is intentional: a zero or
                     * synthesized tag would be false evidence at the native SDK boundary.
                     */
                    }
                    add("game_finished", "game:${before.pitch?.gameId ?: session.log.gameId}", reportProperties)
                    if (before.meta.completedGameCount == 0UL && after.meta.completedGameCount > 0UL) add("activation_first_game", "install", emptyMap())
                    val growthFocus = previousRun?.let { gameGrowthFocus(it, session) }
                    val growth = growthFocus?.let { rating(it, run.pitcher) - rating(it, previousRun.pitcher) } ?: 0
                    if (growth > 0 && growthFocus != null) add("game_growth_applied", "game:${before.pitch?.gameId ?: session.log.gameId}", mapOf(
                        "life_number" to AnalyticsValue.Whole(run.lifeNumber.toLong()),
                        "act_number" to AnalyticsValue.Whole(actNumber(run.chapter.number).toLong()),
                        "reason_id" to AnalyticsValue.Text("important_game"),
                        "growth_focus" to AnalyticsValue.Text(growthFocus.wire),
                        "growth_points" to AnalyticsValue.Whole(growth.toLong()),
                    ))
                }
            }
            else -> Unit
        }
    }

    private fun projectPro(
        before: GameAggregateState,
        after: GameAggregateState,
        command: ProCommand,
        add: (String, String, Map<String, AnalyticsValue>) -> Unit,
    ) {
        val pro = after.pro ?: return
        when (command) {
            is ProCommand.StartLinked,
            is ProCommand.StartDirect -> add(
                "pro_career_started",
                "career:${pro.careerId}",
                buildMap {
                    put("source", AnalyticsValue.Text(if (command is ProCommand.StartLinked) "high_school_draft" else "direct_setup"))
                    if (command is ProCommand.StartLinked) {
                        before.highSchool?.run?.draftResult?.round?.let { put("round", AnalyticsValue.Whole(it.toLong())) }
                        put("evaluation", AnalyticsValue.Whole(command.request.draftEvaluation.toLong()))
                        before.highSchool?.run?.lifeNumber?.let { put("life_number", AnalyticsValue.Whole(it.toLong())) }
                    }
                },
            )
            is ProCommand.ApplySeasonDecision -> add(
                "pro_season_decision_selected",
                "season:${before.pro?.season ?: pro.season}|decision:${command.decisionId}",
                mapOf(
                    "decision_id" to AnalyticsValue.Text(command.decisionId),
                    "choice_id" to AnalyticsValue.Text(command.choiceId),
                    "season" to AnalyticsValue.Whole((before.pro?.season ?: pro.season).toLong()),
                    "week" to AnalyticsValue.Whole((before.pro?.week ?: pro.week).toLong()),
                ),
            )
            is ProCommand.SelectLegacy -> add(
                "pro_legacy_recorded",
                "career:${pro.careerId}",
                buildMap {
                    // Direct Pro has no HighSchool life; omitting this optional field avoids a
                    // fabricated life number while linked Pro retains the authoritative value.
                    before.highSchool?.run?.lifeNumber?.let { put("life_number", AnalyticsValue.Whole(it.toLong())) }
                    put("pro_seasons", AnalyticsValue.Whole(pro.careerStats.size.toLong()))
                    put("has_signature_candidates", AnalyticsValue.Flag(pro.legacyCandidates.isNotEmpty()))
                },
            )
            is ProCommand.FinishImportantGame, is ProCommand.HandOffOuting -> if (before.pro?.activePitch != null && before.pitch?.challengeRun != true) {
                val session = before.pro?.activePitch ?: return
                add(
                    "game_finished",
                    "game:${before.pitch?.gameId ?: session.log.gameId}",
                    buildMap {
                        put("mode", AnalyticsValue.Text("pro"))
                        put("sequence_mastery_count", AnalyticsValue.Whole(session.sequenceMasteryCount.toLong()))
                        acceptanceRate(session.recommendationAccepted, session.pitches)?.let { put("recommendation_acceptance_rate", it) }
                        put("development_rules_version", AnalyticsValue.Whole(ProCatalog.RULES_VERSION.toLong()))
                        put("ability_moment_count", AnalyticsValue.Whole(session.abilityMoments.size.toLong()))
                        session.abilityMoments.distinct().sorted().takeIf { it.isNotEmpty() }?.let {
                            put("ability_moment_types", AnalyticsValue.Text(it.joinToString(",")))
                        }
                        put("result", AnalyticsValue.Text(if (session.runsAllowed == 0) "scoreless" else "runs_allowed"))
                        put("strikeouts", AnalyticsValue.Whole(session.strikeouts.toLong()))
                        put("walks", AnalyticsValue.Whole(session.walks.toLong()))
                        put("runs", AnalyticsValue.Whole(session.runsAllowed.toLong()))
                    },
                )
                if (before.meta.completedGameCount == 0UL && after.meta.completedGameCount > 0UL) add("activation_first_game", "install", emptyMap())
            }
            else -> Unit
        }
    }

    private fun returnPlanProperties(
        plan: com.solkim.baseball.core.highschool.HighSchoolReturnPlan,
        returnDayKey: String,
    ): Map<String, AnalyticsValue> = buildMap {
        put("destination", AnalyticsValue.Text(plan.destination.wire))
        put("reason", AnalyticsValue.Text(plan.reason))
        put("plan_receipt", AnalyticsValue.Text(plan.receiptId))
        plan.experimentId?.let { put("experiment_id", AnalyticsValue.Text(it)) }
        plan.experimentVariant?.let { put("variant", AnalyticsValue.Text(it)) }
        val savedDayKey = plan.savedDayKey ?: plan.createdDayKey
        put("saved_day_key", AnalyticsValue.Text(savedDayKey))
        put("return_day_key", AnalyticsValue.Text(returnDayKey))
        com.solkim.baseball.core.highschool.HighSchoolReturnPlanRules.dayGap(savedDayKey, returnDayKey)?.let {
            put("day_gap", AnalyticsValue.Whole(it.toLong()))
        }
        plan.developmentRulesVersion?.let { put("development_rules_version", AnalyticsValue.Whole(it.toLong())) }
    }

    private fun signatureFamily(id: String): String = runCatching { HighSchoolSignatureLegacyRules.definition(id).family }.getOrDefault("unknown")
    private fun signatureBonus(id: String): Int = runCatching {
        val value = HighSchoolSignatureLegacyRules.definition(id)
        value.stuff + value.command + value.movement + value.stamina
    }.getOrDefault(0)

    private fun signatureRatingGrowth(
        id: String,
        starting: com.solkim.baseball.core.highschool.HighSchoolPitcher,
        current: com.solkim.baseball.core.highschool.HighSchoolPitcher,
    ): Int {
        val definition = runCatching { HighSchoolSignatureLegacyRules.definition(id) }.getOrNull() ?: return 0
        return when (definition.family) {
            "power" -> (current.stuff - starting.stuff).coerceAtLeast(0)
            "command" -> (current.command - starting.command).coerceAtLeast(0)
            "breaking" -> (current.movement - starting.movement).coerceAtLeast(0)
            "endurance" -> (current.stamina - starting.stamina).coerceAtLeast(0)
            "gamecraft" -> ((current.command - starting.command).coerceAtLeast(0) +
                (current.movement - starting.movement).coerceAtLeast(0))
            "battery" -> (current.command - starting.command).coerceAtLeast(0)
            else -> 0
        }
    }

    private fun acceptanceRate(accepted: Int, pitches: Int): AnalyticsValue.Decimal? =
        pitches.takeIf { it > 0 }?.let {
            AnalyticsValue.Decimal((accepted.toDouble() / it.toDouble()).coerceIn(0.0, 1.0))
        }

    private fun gameGrowthFocus(state: HighSchoolState, session: com.solkim.baseball.core.highschool.HighSchoolPitchSession): HighSchoolTrainingFocus? = when {
        session.strikeouts >= 2 && session.runsAllowed <= 1 && session.actualDamage <= session.expectedDamage ->
            if (state.pitcher.stuff >= state.pitcher.movement) HighSchoolTrainingFocus.VELOCITY else HighSchoolTrainingFocus.BREAKING_BALL
        session.outs == 3 && session.pitches >= 9 && session.runsAllowed <= 1 && session.actualDamage <= session.expectedDamage ->
            HighSchoolTrainingFocus.STAMINA
        session.sequenceMasteryCount >= 4 && session.walks == 0 && session.actualDamage <= session.expectedDamage ->
            HighSchoolTrainingFocus.COMMAND
        else -> null
    }

    private fun rating(focus: HighSchoolTrainingFocus, pitcher: com.solkim.baseball.core.highschool.HighSchoolPitcher): Int = when (focus) {
        HighSchoolTrainingFocus.VELOCITY -> pitcher.stuff
        HighSchoolTrainingFocus.COMMAND,
        HighSchoolTrainingFocus.GAME_PLANNING -> pitcher.command
        HighSchoolTrainingFocus.BREAKING_BALL -> pitcher.movement
        HighSchoolTrainingFocus.STAMINA,
        HighSchoolTrainingFocus.RECOVERY -> pitcher.stamina
    }

    private fun actNumber(chapter: Int): Int = if (chapter <= 0) 0 else ((chapter + 1) / 2).coerceIn(1, 4)

    private fun AnalyticsValue.wire(): String = when (this) {
        is AnalyticsValue.Text -> value
        is AnalyticsValue.Flag -> value.toString()
        is AnalyticsValue.Whole -> value.toString()
        is AnalyticsValue.Decimal -> value.toString()
    }
}
