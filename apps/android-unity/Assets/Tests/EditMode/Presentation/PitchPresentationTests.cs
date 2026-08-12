using System;
using System.Collections.Generic;
using System.Linq;
using Baseball.Core.Domain;
using Baseball.Core.Pitching;
using Baseball.Application.HighSchool;
using Baseball.Application.Persistence;
using Baseball.Platform.Crash;
using Baseball.Presentation.Pitch;
using NUnit.Framework;

namespace Baseball.Presentation.Tests
{
    public sealed class PitchPresentationTests
    {
        [Test]
        public void PitchBackRequiresConfirmationOnlyAtASafeInteractiveBoundary()
        {
            Assert.That(PitchBackPolicy.Resolve(
                PitchPlayPhase.Selecting, false, false), Is.EqualTo(PitchBackAction.ShowExitConfirmation));
            Assert.That(PitchBackPolicy.Resolve(
                PitchPlayPhase.Selecting, false, true), Is.EqualTo(PitchBackAction.CloseConfirmation));
            Assert.That(PitchBackPolicy.Resolve(
                PitchPlayPhase.Timing, false, false), Is.EqualTo(PitchBackAction.CancelRelease));
            Assert.That(PitchBackPolicy.Resolve(
                PitchPlayPhase.Presenting, false, false), Is.EqualTo(PitchBackAction.SkipPresentation));
            Assert.That(PitchBackPolicy.Resolve(
                PitchPlayPhase.Result, false, false), Is.EqualTo(PitchBackAction.SkipPresentation));
            Assert.That(PitchBackPolicy.Resolve(
                PitchPlayPhase.Completed, false, false), Is.EqualTo(PitchBackAction.CompleteResult));
            Assert.That(PitchBackPolicy.Resolve(
                PitchPlayPhase.Selecting, true, false), Is.EqualTo(PitchBackAction.BlockTutorial));
        }

        [Test]
        public void HudProjectsAuthoritativeSituationBatterScoutingRivalAndPitcherReadout()
        {
            var presenter = new PitchPlayPresenter(PitchDemoRequestFactory.Create(false));
            presenter.Start();

            PitchHudContent content = PitchHudProjection.Project(presenter.State);
            Assert.That(content.Situation, Is.EqualTo(
                "8회 · 1아웃 · 우리 팀 1점 리드 · 주자 없음 · 피로 42 · 중요도 매우 높음"));
            Assert.That(content.Batter, Is.EqualTo(
                "도윤 · 우타 · 컨택 57 · 선구 54 · 장타 61"));
            Assert.That(content.Scouting, Does.Contain("강점 직구 · 약점 슬라이더"));
            Assert.That(content.Scouting, Does.Contain("차가운 곳 낮은 왼쪽"));
            Assert.That(content.Pitcher, Is.EqualTo("구위 62 · 제구 56 · 변화 58 · 체력 60"));
            Assert.That(content.Recommendation, Does.Contain("포수 사인"));
            Assert.That(content.Recommendation, Does.Contain("포수 사인 사용 중"));
            Assert.That(content.Rival, Does.StartWith("라이벌 대응"));

            presenter.SelectPitchType(PitchType.Slider);
            Assert.That(PitchHudProjection.Project(presenter.State).Recommendation,
                Does.Contain("내 선택 유지 중"));
        }

        [Test]
        public void BuilderPreservesAuthoritativeTrajectoryAndPlateCrossing()
        {
            PitchKernelResult result = Result(
                PitchOutcome.CalledStrike,
                new PitchExecution(
                    0, 0, 125, -100, 1452, -80, 120, 800,
                    400, 0, 0,
                    new[]
                    {
                        0, 0, 18440, 1850,
                        200, -50, 9220, 1320,
                        400, 108, 0, 700
                    }),
                null,
                null);

            PitchPresentationSnapshot presentation = PitchPresentationBuilder.FromResult(
                "pa-1",
                new PitchCall(PitchType.Slider, new PitchZone(1, 1), ZoneIntent.Strike, PitchIntensity.Normal),
                result);

            Assert.That(presentation.Trajectory.Count, Is.EqualTo(3));
            Assert.That(presentation.Trajectory[0].ZMeters, Is.EqualTo(18.44).Within(0.0001));
            Assert.That(presentation.Trajectory[2].XMeters, Is.EqualTo(0.108).Within(0.0001));
            Assert.That(presentation.Trajectory[2].YMeters, Is.EqualTo(0.7).Within(0.0001));
            Assert.That(presentation.ActualPlateX, Is.EqualTo(0.25).Within(0.0001));
            Assert.That(presentation.ActualPlateY, Is.EqualTo(-0.2).Within(0.0001));
        }

        [Test]
        public void ContactCuesComeFromCommittedBattedBallOnly()
        {
            var ball = new BattedBall(1620, 240, -110, 825);
            var fielding = new FieldingResolutionSnapshot(
                PitchOutcome.HomeRun, PitchOutcome.InPlayOut, FieldingSector.Fence,
                210, 68, -72, 0, DefenseImpact.HelpedPitcher, FielderPosition.CenterField,
                "한결", 1030, 4100, 260, null, "담장 앞에서 잡았습니다.");
            PitchPresentationSnapshot presentation = PitchPresentationBuilder.FromResult(
                "pa-contact",
                new PitchCall(PitchType.FourSeam, new PitchZone(1, 1), ZoneIntent.Strike, PitchIntensity.Normal),
                Result(PitchOutcome.InPlayOut, Execution(), ball, fielding));

            Assert.That(presentation.Contact, Is.Not.Null);
            Assert.That(presentation.Contact.ExitVelocityKph, Is.EqualTo(162.0));
            Assert.That(presentation.Fielding.FinalOutcome, Is.EqualTo(PitchOutcome.InPlayOut));
            Assert.That(presentation.AudioCue, Is.EqualTo(PitchAudioCue.HardContact));
            Assert.That(presentation.HapticCue, Is.EqualTo(PitchHapticCue.Contact));
            Assert.That(presentation.ScoreDelta.RunsAllowed, Is.Zero);
        }

        [Test]
        public void PresentationSeedIsStableAndDoesNotAffectResult()
        {
            PitchKernelResult result = Result(PitchOutcome.SwingingStrike, Execution(), null, null);
            var call = new PitchCall(PitchType.Changeup, new PitchZone(2, 1), ZoneIntent.Chase, PitchIntensity.Controlled);
            PitchPresentationSnapshot first = PitchPresentationBuilder.FromResult("pa-seed", call, result);
            PitchPresentationSnapshot second = PitchPresentationBuilder.FromResult("pa-seed", call, result);

            Assert.That(first.PresentationSeed, Is.EqualTo(second.PresentationSeed));
            Assert.That(first.Call, Is.EqualTo(PitchOutcome.SwingingStrike));
            Assert.That(second.Call, Is.EqualTo(first.Call));
        }

        [TestCase(0, 0)]
        [TestCase(0, 1)]
        [TestCase(0, 2)]
        [TestCase(1, 0)]
        [TestCase(1, 1)]
        [TestCase(1, 2)]
        [TestCase(2, 0)]
        [TestCase(2, 1)]
        [TestCase(2, 2)]
        public void PitchAimGridCentersRoundTrip(int row, int column)
        {
            var expected = new PitchZone(row, column);
            NormalizedPitchAim center = PitchInputMapper.CenterOf(expected);
            Assert.That(PitchInputMapper.ZoneFor(center), Is.EqualTo(expected));
            Assert.That(PitchInputMapper.AimAccuracy(center), Is.EqualTo(1000));
        }

        [Test]
        public void ReleaseMeterIsDeterministicAtThePerfectPoint()
        {
            var first = new PitchReleaseMeter();
            var second = new PitchReleaseMeter();
            double elapsed = PitchReleaseMeter.PerfectPhase * PitchReleaseMeter.SweepSeconds;
            first.Advance(elapsed);
            second.Advance(elapsed);
            Assert.That(first.Accuracy, Is.EqualTo(1000));
            Assert.That(second.Accuracy, Is.EqualTo(first.Accuracy));
            Assert.That(PitchReleaseMeter.AccuracyAt(0.0), Is.LessThan(1000));
        }

        [Test]
        public void PitchPlayPresenterUsesPrepareAndSubmitAsItsOnlyAuthority()
        {
            var gateway = new CountingKernelGateway();
            var presenter = new PitchPlayPresenter(PitchDemoRequestFactory.Create(false), gateway);
            presenter.Start();
            presenter.SelectPitchType(PitchType.Slider);
            presenter.SelectContinuousAim(0.80, -0.80);
            presenter.SelectIntent(ZoneIntent.Edge);
            presenter.SelectIntensity(PitchIntensity.MaxEffort);
            presenter.BeginRelease();
            presenter.AdvanceRelease(PitchReleaseMeter.PerfectPhase * PitchReleaseMeter.SweepSeconds);
            PitchCommit commit = presenter.SubmitRelease();

            Assert.That(gateway.PrepareCount, Is.EqualTo(1));
            Assert.That(gateway.SubmitCount, Is.EqualTo(1));
            Assert.That(commit.Result, Is.SameAs(gateway.LastResult));
            Assert.That(commit.Presentation.Call, Is.EqualTo(commit.Result.Snapshot.Outcome));
            Assert.That(commit.Delivery.ReleaseAccuracy, Is.EqualTo(1000));
            Assert.That(commit.Call.Zone, Is.EqualTo(new PitchZone(2, 2)));
        }

        [Test]
        public void IdenticalPitchPlayInputProducesIdenticalCoreHash()
        {
            PitchCommit first = CommitIdenticalPitch();
            PitchCommit second = CommitIdenticalPitch();
            Assert.That(second.Result.EventHash, Is.EqualTo(first.Result.EventHash));
            Assert.That(second.Result.Snapshot.Execution.ActualX, Is.EqualTo(first.Result.Snapshot.Execution.ActualX));
            Assert.That(second.Result.Snapshot.Execution.ActualY, Is.EqualTo(first.Result.Snapshot.Execution.ActualY));
            Assert.That(second.Presentation.PresentationSeed, Is.EqualTo(first.Presentation.PresentationSeed));
        }

        [Test]
        public void PitchPlaySubmitRequiresAnActiveReleaseGesture()
        {
            var presenter = new PitchPlayPresenter(PitchDemoRequestFactory.Create(true));
            presenter.Start();
            Assert.Throws<InvalidOperationException>(() => presenter.SubmitRelease());
            presenter.BeginRelease();
            presenter.CancelRelease();
            Assert.Throws<InvalidOperationException>(() => presenter.SubmitRelease());
        }

        [Test]
        public void AutomaticReleaseUsesNeutralDeliveryAndDoesNotCountAsDirect()
        {
            var presenter = new PitchPlayPresenter(PitchDemoRequestFactory.Create(true));
            presenter.Start();

            PitchCommit commit = presenter.SubmitNeutralRelease();
            PitchCommitMetricEvidence evidence = PitchCommitMetrics.Evaluate(
                PitchSessionMetricsState.Empty,
                commit);
            PitchSessionMetricsState metrics = PitchCommitMetrics.Consuming(
                PitchSessionMetricsState.Empty,
                evidence,
                commit.Result.Snapshot.Ended);

            Assert.That(commit.Delivery.IsNeutral, Is.True);
            Assert.That(commit.WasDirect, Is.False);
            Assert.That(metrics.DirectDeliveryCount, Is.Zero);
            Assert.That(metrics.PerfectDeliveryCount, Is.Zero);
        }

        [Test]
        public void CoreAbilityMomentSurvivesCommitConsumeAndReportProjection()
        {
            PitchPlayRequest request = PitchDemoRequestFactory.Create(false);
            var call = new PitchCall(
                PitchType.FourSeam,
                new PitchZone(1, 1),
                ZoneIntent.Strike,
                PitchIntensity.Normal);
            PitchKernelResult result = Result(
                PitchOutcome.CalledStrike,
                Execution(),
                null,
                null);
            string ability = PitchCommitMetrics.AbilityMomentType(
                request.Pitcher,
                call,
                request.Context,
                result);
            Assert.That(ability, Is.EqualTo(PitchAbilityKind.Command.Value()));

            var commit = new PitchCommit(
                call,
                PitchDelivery.Neutral,
                result,
                PitchPresentationBuilder.FromResult(request.Context.PlateAppearanceId, call, result),
                request.Context,
                request.RivalMemory,
                false,
                145,
                ability);
            PitchCommitMetricEvidence evidence = PitchCommitMetrics.Evaluate(
                PitchSessionMetricsState.Empty,
                commit);
            PitchSessionMetricsState metrics = PitchCommitMetrics.Consuming(
                PitchSessionMetricsState.Empty,
                evidence,
                false);
            PitchGameReport report = PitchGameReportBuilder.WithMetrics(
                new PitchGameReport("ability-game", 1, 0, 0, 0, 0, 0, 0),
                metrics);

            Assert.That(evidence.AbilityMomentType, Is.EqualTo("command"));
            Assert.That(metrics.AbilityMomentCount, Is.EqualTo(1));
            Assert.That(metrics.AbilityMomentTypes, Is.EqualTo(new[] { "command" }));
            Assert.That(report.AbilityMomentCount, Is.EqualTo(1));
            Assert.That(report.AbilityMomentTypes, Is.EqualTo(new[] { "command" }));
            Assert.That(PitchCommitMetrics.AbilityMomentType(
                request.Pitcher,
                call,
                request.Context,
                Result(PitchOutcome.Ball, Execution(), null, null)), Is.Null);
        }

        [Test]
        public void TutorialCoachCopyFollowsFirstPitchTwoStrikeAndMixCallContract()
        {
            Assert.That(PitchTutorialCoachCopy.For(1, 0), Is.EqualTo(
                "① 길게 눌러 와인드업 — 미터가 가운데 초록에 올 때 떼자. 구종과 코스는 포수가 골라 뒀다."));
            Assert.That(PitchTutorialCoachCopy.For(2, 1), Is.EqualTo(
                "② 같은 곳에 두 번은 없다 — 구종이나 코스를 바꿔 타자의 눈을 흔들자."));
            Assert.That(PitchTutorialCoachCopy.For(4, 2), Is.EqualTo(
                "③ 결정구 — 상대가 약한 구종으로 유인하자. 존을 살짝 벗어나도 방망이가 나온다."));
        }

        [Test]
        public void ManualSelectionIsHeldInDurableContinuationUntilCatcherSignIsAccepted()
        {
            var presenter = new PitchPlayPresenter(PitchDemoRequestFactory.Create(false));
            presenter.Start();
            presenter.SelectPitchType(PitchType.Slider);
            presenter.SelectZone(new PitchZone(2, 2));
            presenter.SelectIntent(ZoneIntent.Chase);
            presenter.SelectIntensity(PitchIntensity.Controlled);
            presenter.BeginRelease();
            presenter.AdvanceRelease(0.37);
            PitchCommit commit = presenter.SubmitRelease();
            Assert.That(commit.Result.Snapshot.Ended, Is.False, "fixture must leave the plate appearance active");

            PitchPlayRequest checkpoint = presenter.ContinuationAfter(commit.Result);
            string json = PitchPersistenceJsonCodec.SerializeCheckpoint(checkpoint, false);
            PitchPlayRequest restored = PitchPersistenceJsonCodec.DeserializeCheckpoint(json).Request;

            Assert.That(restored.HoldCall, Is.True);
            Assert.That(restored.SelectedCall.PitchType, Is.EqualTo(PitchType.Slider));
            Assert.That(restored.SelectedCall.Zone, Is.EqualTo(new PitchZone(2, 2)));
            Assert.That(restored.SelectedCall.ZoneIntent, Is.EqualTo(ZoneIntent.Chase));
            Assert.That(restored.SelectedCall.Intensity, Is.EqualTo(PitchIntensity.Controlled));
        }

        [Test]
        public void PointerCaptureAcceptsOnlyFirstPointerAndCancellationCannotSubmitAnotherPointer()
        {
            var state = new PitchPointerCaptureState();
            Assert.That(state.TryBeginAim(11), Is.True);
            Assert.That(state.TryBeginAim(22), Is.False);
            Assert.That(state.EndAim(22), Is.False);
            Assert.That(state.OwnsAim(11), Is.True);
            Assert.That(state.CancelAim(11), Is.True);

            Assert.That(state.TryBeginRelease(31), Is.True);
            Assert.That(state.TryBeginRelease(32), Is.False);
            Assert.That(state.EndRelease(32), Is.False);
            Assert.That(state.CancelAll(), Is.True);
            Assert.That(state.ReleasePointerId, Is.Null);
        }

        [Test]
        public void PersistenceCodecRoundTripsCallStateKernelPresentationAndTypedTerminalMarker()
        {
            PitchPlayRequest original = PitchDemoRequestFactory.Create(false);
            var selected = new PitchCall(
                PitchType.Slider,
                new PitchZone(0, 2),
                ZoneIntent.Edge,
                PitchIntensity.Controlled);
            original = new PitchPlayRequest(
                original.Seed,
                original.Pitcher,
                original.Batter,
                original.Scouting,
                original.Context,
                original.RivalMemory,
                original.GameState,
                original.GameLog,
                original.Trait,
                selected,
                true);
            PitchPlayRequest request = PitchPersistenceJsonCodec.DeserializeRequest(
                PitchPersistenceJsonCodec.SerializeRequest(original));
            Assert.That(request.SelectedCall.PitchType, Is.EqualTo(PitchType.Slider));
            Assert.That(request.HoldCall, Is.True);

            var presenter = new PitchPlayPresenter(original);
            presenter.Start();
            PitchCommit commit = presenter.SubmitNeutralRelease();
            PitchKernelResult result = PitchPersistenceJsonCodec.DeserializeKernelResult(
                PitchPersistenceJsonCodec.SerializeKernelResult(commit.Result));
            PitchPresentationSnapshot presentation = PitchPersistenceJsonCodec.DeserializePresentation(
                PitchPersistenceJsonCodec.SerializePresentation(commit.Presentation));
            Assert.That(result.EventHash, Is.EqualTo(commit.Result.EventHash));
            Assert.That(presentation.PitchId, Is.EqualTo(commit.Presentation.PitchId));
            Assert.That(presentation.HoldsCall, Is.True);
            Assert.That(presentation.SelectedCall.Zone, Is.EqualTo(selected.Zone));

            PitchSessionCheckpoint terminal = PitchPersistenceJsonCodec.DeserializeCheckpoint(
                PitchPersistenceJsonCodec.SerializeCheckpoint(null, true));
            Assert.That(terminal.IsTerminal, Is.True);
            Assert.That(terminal.Request, Is.Null);
        }

        [TestCase(PitchOutcome.CalledStrike)]
        [TestCase(PitchOutcome.SwingingStrike)]
        public void EndedStrikeoutUsesDedicatedUmpireCue(PitchOutcome outcome)
        {
            PitchPresentationSnapshot presentation = PitchPresentationBuilder.FromResult(
                "pa-strikeout",
                new PitchCall(PitchType.FourSeam, new PitchZone(1, 1), ZoneIntent.Strike, PitchIntensity.Normal),
                Result(outcome, Execution(), null, null, true, PlateAppearanceResult.Strikeout));

            Assert.That(presentation.AudioCue, Is.EqualTo(PitchAudioCue.UmpireStrikeout));
        }

        [Test]
        public void AudioSelectionUsesPresentationSeedVariantsAndAuthoritativeCrowdOutcome()
        {
            PitchPresentationSnapshot homeRun = AudioSnapshot(
                PitchOutcome.HomeRun,
                PitchAudioCue.HardContact,
                1,
                77UL);
            PitchAudioSelection first = PitchAudioSelectionPolicy.Select(homeRun);
            PitchAudioSelection replay = PitchAudioSelectionPolicy.Select(homeRun);
            Assert.That(replay.PrimaryAddress, Is.EqualTo(first.PrimaryAddress));
            Assert.That(replay.CrowdAddress, Is.EqualTo(first.CrowdAddress));
            Assert.That(first.PrimaryAddress, Does.StartWith("baseball/audio/bat-contact-hard"));
            Assert.That(first.CrowdAddress, Does.StartWith("baseball/audio/crowd-groan"));

            PitchAudioSelection strikeout = PitchAudioSelectionPolicy.Select(AudioSnapshot(
                PitchOutcome.SwingingStrike,
                PitchAudioCue.UmpireStrikeout,
                0,
                91UL));
            Assert.That(strikeout.PrimaryAddress, Is.EqualTo("baseball/audio/umpire-strikeout"));
            Assert.That(strikeout.CrowdAddress, Does.StartWith("baseball/audio/crowd-cheer"));

            string[] variants = { "", "-2", "-3" };
            foreach (ulong seed in new[] { 0UL, 1UL, 2UL, 3UL, 4UL, 5UL })
            {
                string address = PitchAudioSelectionPolicy.Select(AudioSnapshot(
                    PitchOutcome.CalledStrike,
                    PitchAudioCue.GloveCatch,
                    0,
                    seed)).PrimaryAddress;
                Assert.That(variants.Any(suffix => address == "baseball/audio/glove-catch" + suffix), Is.True);
            }
        }

        [Test]
        public void PitchGameReportUsesOnlyCompletedAuthoritativeCoreSnapshot()
        {
            var presenter = new PitchPlayPresenter(PitchDemoRequestFactory.Create(false));
            presenter.Start();
            PitchCommit final = null;
            for (int pitch = 0; pitch < 12; pitch++)
            {
                presenter.BeginRelease();
                presenter.AdvanceRelease(PitchReleaseMeter.PerfectPhase * PitchReleaseMeter.SweepSeconds);
                final = presenter.SubmitRelease();
                presenter.MarkResultReadable(final.Presentation);
                presenter.CompletePresentation(final.Presentation);
                if (final.Result.Snapshot.Ended) break;
            }

            Assert.That(final, Is.Not.Null);
            Assert.That(final.Result.Snapshot.Ended, Is.True);
            PitchGameReport report = PitchGameReportBuilder.Build("saved-game", final.Result);
            Assert.That(report.GameId, Is.EqualTo("saved-game"));
            Assert.That(report.Pitches, Is.EqualTo(final.Result.GameLog.TotalPitches));
            Assert.That(report.RunsAllowed, Is.EqualTo(final.Result.Snapshot.RunsScored));
            Assert.That(report.Strikeouts, Is.EqualTo(final.Result.Snapshot.Result == PlateAppearanceResult.Strikeout ? 1 : 0));
            Assert.That(report.Walks, Is.EqualTo(final.Result.Snapshot.Result == PlateAppearanceResult.Walk ? 1 : 0));
            Assert.That(report.Hits, Is.EqualTo(final.Result.Snapshot.Result == PlateAppearanceResult.Hit ? 1 : 0));
            Assert.That(PitchGameReportBuilder.CheckpointJson(final.Result), Does.Contain(final.Result.EventHash));
        }

        [Test]
        public void PostgameProjectsFullDurableReportAndTargetVersusActualPitchLog()
        {
            var report = new PitchGameReport(
                "postgame",
                pitches: 2,
                batters: 1,
                outs: 1,
                strikeouts: 1,
                walks: 0,
                hits: 0,
                runsAllowed: 0,
                sequenceMasteryCount: 1,
                expectedDamage: 120,
                actualDamage: 40,
                recommendationAccepted: 1,
                directDeliveryCount: 2,
                deliveryScoreTotal: 1700,
                bestDeliveryScore: 900,
                perfectDeliveryCount: 1,
                abilityMomentCount: 1,
                abilityMomentTypes: new[] { "command" });
            var log = new[]
            {
                new PitchLogEntryState(
                    "pitch-1", 0, 1, "four_seam", 0, 1, "edge", "normal",
                    0, 500, 25, 460, 1450, 18, -92, 880, "called_strike", true, 1),
                new PitchLogEntryState(
                    "pitch-2", 0, 2, "slider", 2, 0, "chase", "max_effort",
                    -500, -500, -430, -610, 1320, -124, -48, 820, "swinging_strike", false, 2),
            };

            PitchPostgameContent content = PitchPostgameProjection.Project(report, log);
            Assert.That(content.Summary, Does.Contain("1타자 · 2구 · 1아웃"));
            Assert.That(content.Analysis, Is.EqualTo("기대 피해 120 · 실제 피해 40 · 포수 사인 수락 1/2"));
            Assert.That(content.Growth, Does.Contain("수싸움 성장 1 · 능력 발현 1(제구)"));
            Assert.That(content.Pitches.Count, Is.EqualTo(2));
            Assert.That(content.Pitches[0].Title, Does.Contain("직구 · 높은 가운데 · 스트라이크"));
            Assert.That(content.Pitches[0].Detail, Does.Contain("목표 (0,500) → 실제 (25,460)"));
            Assert.That(content.Pitches[1].Title, Does.Contain("슬라이더 · 낮은 왼쪽 · 헛스윙"));
            Assert.That(content.Pitches[1].Detail, Does.Contain("직접 배합"));
        }

        [Test]
        public void PitchGameReportRejectsPresentationBeforeCoreEndsPlateAppearance()
        {
            PitchKernelResult incomplete = Result(PitchOutcome.CalledStrike, Execution(), null, null);
            Assert.Throws<InvalidOperationException>(() => PitchGameReportBuilder.Build("game", incomplete));
        }

        [Test]
        public void PitchQualityPolicyUsesMemoryFrameP95AndLowMemoryFailSafe()
        {
            Assert.That(PitchQualityPolicy.Select(new PitchQualitySignals(8192, 0d, 0, false)),
                Is.EqualTo(PitchQualityTier.High));
            Assert.That(PitchQualityPolicy.Select(new PitchQualitySignals(4096, 12d, 90, false)),
                Is.EqualTo(PitchQualityTier.Low));
            Assert.That(PitchQualityPolicy.Select(new PitchQualitySignals(8192, 28.1d, 60, false)),
                Is.EqualTo(PitchQualityTier.Low));
            Assert.That(PitchQualityPolicy.Select(new PitchQualitySignals(8192, 12d, 90, true)),
                Is.EqualTo(PitchQualityTier.Low));
            Assert.That(PitchQualityTier.High.Value(), Is.EqualTo("high"));
            Assert.That(PitchQualityTier.Low.Value(), Is.EqualTo("low"));
        }

        [Test]
        public void FrameBudgetDowngradePublishesLowCrashDiagnosticTier()
        {
            CrashReporting.Reset();
            PitchQualityTier selected = PitchQualityPolicy.Select(
                new PitchQualitySignals(8192, 28.1d, 60, false));

            Assert.That(CrashRuntimeDiagnostics.PublishQualityTier(selected.Value()), Is.True);
            Assert.That(CrashRuntimeDiagnostics.CurrentQualityTier, Is.EqualTo("low"));
            CrashReporting.Reset();
        }

        [Test]
        public void ProductionCompletionMarkerRequiresDurablePresentationAndDeduplicatesPitch()
        {
            var marker = new PitchPresentationCompletionMarker();

            Assert.That(marker.TryMark("pitch-1", false, true), Is.False);
            Assert.That(marker.TryMark("pitch-1", true, false), Is.False);
            Assert.That(marker.TryMark("pitch-1", true, true), Is.True);
            Assert.That(marker.TryMark("pitch-1", true, true), Is.False);
            Assert.That(marker.TryMark("pitch-2", true, true), Is.True);
            Assert.That(PitchPresentationCompletionMarker.LogLine, Is.EqualTo(
                "BASEBALL_PITCH_PRESENTATION_COMPLETED schema=1 status=passed"));
            Assert.That(PitchPresentationCompletionMarker.LogLine, Does.Not.Contain("pitch-1"));
        }

        private static PitchPresentationSnapshot AudioSnapshot(
            PitchOutcome outcome,
            PitchAudioCue cue,
            int runs,
            ulong seed) =>
            new PitchPresentationSnapshot(
                "audio-" + seed,
                PitchType.FourSeam,
                0d,
                0d,
                145d,
                0.4d,
                Array.Empty<TrajectoryPoint>(),
                outcome,
                outcome == PitchOutcome.SwingingStrike ? SwingPresentation.Miss : SwingPresentation.Contact,
                null,
                null,
                new ScoreDelta(runs),
                cue,
                PitchHapticCue.Contact,
                seed,
                "오디오 선택 테스트");

        private static PitchCommit CommitIdenticalPitch()
        {
            var presenter = new PitchPlayPresenter(PitchDemoRequestFactory.Create(false));
            presenter.Start();
            presenter.SelectPitchType(PitchType.FourSeam);
            presenter.SelectZone(new PitchZone(0, 1));
            presenter.SelectIntent(ZoneIntent.Edge);
            presenter.SelectIntensity(PitchIntensity.Normal);
            presenter.BeginRelease();
            presenter.AdvanceRelease(0.55);
            return presenter.SubmitRelease();
        }

        private sealed class CountingKernelGateway : IPitchKernelGateway
        {
            private readonly PitchKernelEngine _engine = new PitchKernelEngine();
            public int PrepareCount { get; private set; }
            public int SubmitCount { get; private set; }
            public PitchKernelResult LastResult { get; private set; }

            public PitchPreparation PreparePitch(PreparePitchParams parameters)
            {
                PrepareCount++;
                return _engine.PreparePitch(parameters);
            }

            public PitchKernelResult SubmitPitch(SubmitPitchParams parameters, PitchDelivery delivery)
            {
                SubmitCount++;
                LastResult = _engine.SubmitPitch(parameters, delivery);
                return LastResult;
            }
        }

        private static PitchExecution Execution()
        {
            return new PitchExecution(
                0, 0, 0, 0, 1430, 40, -80, 720,
                430, null, null,
                new[] { 0, 0, 18440, 1850, 430, 0, 0, 750 });
        }

        private static PitchKernelResult Result(
            PitchOutcome outcome,
            PitchExecution execution,
            BattedBall ball,
            FieldingResolutionSnapshot fielding,
            bool ended = false,
            PlateAppearanceResult? plateResult = null)
        {
            var snapshot = new PlateAppearanceSnapshot(
                2, 0, ended ? 3 : 1, 1, ended, plateResult, outcome, SelectionQuality.Good,
                true, 4, execution, ball, fielding,
                BaserunnerStateSnapshot.Empty, BaserunnerStateSnapshot.Empty,
                0, null, null, new List<string>(), "판정", "상세", "판정 요약");
            return new PitchKernelResult(
                2, "43", snapshot, null, null, null, null, null, null,
                "5d5264f7e323b35a", new[] { new PitchKernelEvent("pitch_resolved", 0, outcome: outcome) });
        }
    }
}
