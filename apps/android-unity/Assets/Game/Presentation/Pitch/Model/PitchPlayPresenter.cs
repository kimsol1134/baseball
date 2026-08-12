using System;
using System.Collections.Generic;
using Baseball.Core.Domain;
using Baseball.Core.Pitching;

namespace Baseball.Presentation.Pitch
{
    /// <summary>
    /// Deterministic input state machine. It normalizes player intent, then delegates every gameplay
    /// result to PreparePitch/SubmitPitch. It never predicts a call, contact, run, or count locally.
    /// </summary>
    public sealed class PitchPlayPresenter
    {
        private readonly IPitchKernelGateway _kernel;
        private readonly PitcherSnapshot _pitcher;
        private readonly BatterSnapshot _batter;
        private readonly BatterScoutingSnapshot _scouting;
        private readonly PersonalityTrait? _trait;
        private readonly PitchReleaseMeter _releaseMeter = new PitchReleaseMeter();
        private string _seed;
        private PlateAppearanceContext _context;
        private RivalMemorySnapshot _rivalMemory;
        private GameStateSnapshot _gameState;
        private GameLogSnapshot _gameLog;
        private PitchPreparation _preparation;
        private PitchType _pitchType;
        private PitchZone _zone;
        private ZoneIntent _intent;
        private PitchIntensity _intensity;
        private NormalizedPitchAim _aim;
        private PitchKernelResult _lastResult;
        private string _lastPresentationId;
        private bool _hasSelectedCall;
        private bool _holdCall;

        public PitchPlayPresenter(PitchPlayRequest request, IPitchKernelGateway kernel = null)
        {
            if (request == null) throw new ArgumentNullException(nameof(request));
            _kernel = kernel ?? new AuthoritativePitchKernelGateway();
            _seed = request.Seed;
            _pitcher = request.Pitcher;
            _batter = request.Batter;
            _scouting = request.Scouting;
            _context = request.Context;
            _rivalMemory = request.RivalMemory;
            _gameState = request.GameState;
            _gameLog = request.GameLog;
            _trait = request.Trait;
            if (request.SelectedCall != null)
            {
                ApplyRecommendation(request.SelectedCall);
                _hasSelectedCall = true;
                _holdCall = request.HoldCall;
            }
            Phase = PitchPlayPhase.Idle;
        }

        public PitchPlayPhase Phase { get; private set; }
        public PitchPlayViewState State => Snapshot();
        public IReadOnlyList<PitchType> AvailablePitchTypes
        {
            get
            {
                if (_pitcher.PitchProfiles == null) return DomainWire.PitchTypes;
                var pitches = new List<PitchType>(_pitcher.PitchProfiles.Count);
                foreach (PitchProfileSnapshot profile in _pitcher.PitchProfiles) pitches.Add(profile.PitchType);
                return pitches;
            }
        }

        public event Action<PitchPlayViewState> ViewChanged;
        public event Action<PitchCommit> PitchCommitted;
        public event Action<PitchKernelResult> PlateAppearanceCompleted;
        public event Action Aborted;

        public void Start()
        {
            RequirePhase(PitchPlayPhase.Idle);
            _preparation = _kernel.PreparePitch(PrepareParameters());
            if (!_hasSelectedCall)
            {
                ApplyRecommendation(_preparation.PrimaryRecommendation.Call);
                _hasSelectedCall = true;
                _holdCall = false;
            }
            Phase = PitchPlayPhase.Selecting;
            Publish();
        }

        /// <summary>
        /// Restores a Core result that was durably committed before process death. The result is
        /// never submitted to Core again; only its saved presentation is replayed.
        /// </summary>
        public void RestoreCommitted(
            PitchKernelResult result,
            PitchPresentationSnapshot presentation)
        {
            RequirePhase(PitchPlayPhase.Idle);
            if (result?.Snapshot == null) throw new ArgumentNullException(nameof(result));
            if (presentation == null) throw new ArgumentNullException(nameof(presentation));
            if (string.IsNullOrWhiteSpace(presentation.PitchId))
                throw new InvalidOperationException("pitch.presentation_id_missing");
            _lastResult = result;
            _lastPresentationId = presentation.PitchId;
            if (presentation.SelectedCall != null)
            {
                ApplyRecommendation(presentation.SelectedCall);
                _hasSelectedCall = true;
                _holdCall = presentation.HoldsCall;
            }
            Phase = PitchPlayPhase.Presenting;
            Publish();
        }

        /// <summary>Exact next-pitch input to save before clearing a committed result.</summary>
        public PitchPlayRequest ContinuationAfter(PitchKernelResult result)
        {
            if (result?.Snapshot == null) throw new ArgumentNullException(nameof(result));
            if (result.Snapshot.Ended || result.NextPreparation == null)
                throw new InvalidOperationException("pitch.plate_appearance_ended");
            InningStateSnapshot? inning = result.GameState == null ? null : result.GameState.InningState;
            var context = new PlateAppearanceContext(
                _context.PlateAppearanceId,
                result.Revision,
                inning.HasValue ? inning.Value.Inning : _context.Inning,
                inning.HasValue ? inning.Value.Outs : _context.Outs,
                result.Snapshot.Balls,
                result.Snapshot.Strikes,
                result.Snapshot.PitchNumber + 1,
                _context.ScoreDifferential,
                _context.Leverage,
                result.Snapshot.FatigueAfterPitch);
            return new PitchPlayRequest(
                result.NextSeed,
                _pitcher,
                _batter,
                _scouting,
                context,
                result.RivalMemory,
                _gameState == null ? null : result.GameState,
                _gameLog == null ? null : result.GameLog,
                _trait,
                new PitchCall(_pitchType, _zone, ZoneIntentRules.Clamp(_intent, _zone), _intensity),
                _holdCall);
        }

        public void SelectPitchType(PitchType pitchType)
        {
            RequirePhase(PitchPlayPhase.Selecting);
            if (_pitcher.PitchProfiles != null && _pitcher.Profile(pitchType) == null)
            {
                throw new ArgumentException("Pitch type is not in the pitcher's repertoire.", nameof(pitchType));
            }
            _pitchType = pitchType;
            _holdCall = true;
            Publish();
        }

        public void SelectZone(PitchZone zone)
        {
            RequirePhase(PitchPlayPhase.Selecting);
            _aim = PitchInputMapper.CenterOf(zone);
            _zone = zone;
            _intent = ZoneIntentRules.Clamp(_intent, zone);
            _holdCall = true;
            Publish();
        }

        public void SelectContinuousAim(double normalizedX, double normalizedY)
        {
            RequirePhase(PitchPlayPhase.Selecting);
            _aim = new NormalizedPitchAim(normalizedX, normalizedY);
            _zone = PitchInputMapper.ZoneFor(_aim);
            _intent = ZoneIntentRules.Clamp(_intent, _zone);
            _holdCall = true;
            Publish();
        }

        public void SelectIntent(ZoneIntent intent)
        {
            RequirePhase(PitchPlayPhase.Selecting);
            _intent = ZoneIntentRules.Clamp(intent, _zone);
            _holdCall = true;
            Publish();
        }

        public void SelectIntensity(PitchIntensity intensity)
        {
            RequirePhase(PitchPlayPhase.Selecting);
            _intensity = intensity;
            _holdCall = true;
            Publish();
        }

        /// <summary>Explicitly returns every call control to the current authoritative catcher sign.</summary>
        public void AcceptCatcherSign()
        {
            RequirePhase(PitchPlayPhase.Selecting);
            if (_preparation?.PrimaryRecommendation?.Call == null)
                throw new InvalidOperationException("pitch.catcher_recommendation_missing");
            ApplyRecommendation(_preparation.PrimaryRecommendation.Call);
            _holdCall = false;
            Publish();
        }

        public void BeginRelease()
        {
            RequirePhase(PitchPlayPhase.Selecting);
            _releaseMeter.Reset();
            Phase = PitchPlayPhase.Timing;
            Publish();
        }

        public void AdvanceRelease(double unscaledDeltaSeconds)
        {
            if (Phase != PitchPlayPhase.Timing) return;
            _releaseMeter.Advance(unscaledDeltaSeconds);
        }

        public void CancelRelease()
        {
            if (Phase != PitchPlayPhase.Timing) return;
            Phase = PitchPlayPhase.Selecting;
            Publish();
        }

        public PitchCommit SubmitRelease()
        {
            RequirePhase(PitchPlayPhase.Timing);
            return Submit(new PitchDelivery(_releaseMeter.Accuracy, PitchInputMapper.AimAccuracy(_aim)), true);
        }

        /// <summary>
        /// Accessibility/automatic delivery. It intentionally bypasses the timing sweep and uses
        /// Core's neutral identity, so it cannot count as a direct or perfect-delivery achievement.
        /// </summary>
        public PitchCommit SubmitNeutralRelease()
        {
            RequirePhase(PitchPlayPhase.Selecting);
            return Submit(PitchDelivery.Neutral, false);
        }

        private PitchCommit Submit(PitchDelivery delivery, bool wasDirect)
        {
            var call = new PitchCall(_pitchType, _zone, ZoneIntentRules.Clamp(_intent, _zone), _intensity);
            PlateAppearanceContext preResultContext = _context;
            RivalMemorySnapshot preResultRivalMemory = _rivalMemory;
            var command = new SubmitPitchParams(
                _seed,
                _pitcher,
                _batter,
                _scouting,
                _context,
                _preparation.PreparationToken,
                call,
                _rivalMemory,
                _gameState,
                _gameLog,
                _trait);
            PitchKernelResult result = _kernel.SubmitPitch(command, delivery);
            PitchPresentationSnapshot presentation = PitchPresentationBuilder.FromResult(
                _context.PlateAppearanceId,
                call,
                result,
                _holdCall);
            _lastResult = result;
            _lastPresentationId = presentation.PitchId;
            Phase = PitchPlayPhase.Presenting;
            Publish();
            int expectedVelocityKph = Math.Max(
                1,
                (_pitcher.Profile(call.PitchType)?.VelocityTenthsKph ??
                    result.Snapshot.Execution.VelocityTenthsKph) / 10);
            string abilityMomentType = PitchCommitMetrics.AbilityMomentType(
                _pitcher,
                call,
                preResultContext,
                result);
            var commit = new PitchCommit(
                call,
                delivery,
                result,
                presentation,
                preResultContext,
                preResultRivalMemory,
                wasDirect,
                expectedVelocityKph,
                abilityMomentType);
            PitchCommitted?.Invoke(commit);
            return commit;
        }

        public void MarkResultReadable(PitchPresentationSnapshot presentation)
        {
            if (presentation == null) throw new ArgumentNullException(nameof(presentation));
            RequireCurrentPresentation(presentation);
            if (Phase != PitchPlayPhase.Presenting) return;
            Phase = PitchPlayPhase.Result;
            Publish();
        }

        public void CompletePresentation(PitchPresentationSnapshot presentation)
        {
            if (presentation == null) throw new ArgumentNullException(nameof(presentation));
            RequireCurrentPresentation(presentation);
            if (Phase != PitchPlayPhase.Presenting && Phase != PitchPlayPhase.Result) return;
            if (_lastResult == null) throw new InvalidOperationException("A committed Core result is required.");
            if (_lastResult.Snapshot.Ended)
            {
                Phase = PitchPlayPhase.Completed;
                Publish();
                PlateAppearanceCompleted?.Invoke(_lastResult);
                return;
            }

            AdvanceAuthoritativeState(_lastResult);
            if (!_holdCall) ApplyRecommendation(_preparation.PrimaryRecommendation.Call);
            Phase = PitchPlayPhase.Selecting;
            Publish();
        }

        public void Abort()
        {
            if (Phase == PitchPlayPhase.Completed || Phase == PitchPlayPhase.Aborted) return;
            Phase = PitchPlayPhase.Aborted;
            Publish();
            Aborted?.Invoke();
        }

        private void AdvanceAuthoritativeState(PitchKernelResult result)
        {
            if (result.NextPreparation == null) throw new InvalidOperationException("Core did not return the next prepared pitch.");
            InningStateSnapshot? inning = result.GameState == null ? null : result.GameState.InningState;
            _seed = result.NextSeed;
            _context = new PlateAppearanceContext(
                _context.PlateAppearanceId,
                result.Revision,
                inning.HasValue ? inning.Value.Inning : _context.Inning,
                inning.HasValue ? inning.Value.Outs : _context.Outs,
                result.Snapshot.Balls,
                result.Snapshot.Strikes,
                result.Snapshot.PitchNumber + 1,
                _context.ScoreDifferential,
                _context.Leverage,
                result.Snapshot.FatigueAfterPitch);
            _rivalMemory = result.RivalMemory;
            if (_gameState != null) _gameState = result.GameState;
            if (_gameLog != null) _gameLog = result.GameLog;
            _preparation = result.NextPreparation;
            _lastResult = null;
            _lastPresentationId = null;
            _releaseMeter.Reset();
        }

        private void ApplyRecommendation(PitchCall call)
        {
            if (call == null) throw new InvalidOperationException("Core preparation did not contain a catcher recommendation.");
            _pitchType = call.PitchType;
            _zone = call.Zone;
            _intent = call.ZoneIntent;
            _intensity = call.Intensity;
            _aim = PitchInputMapper.CenterOf(call.Zone);
        }

        private PreparePitchParams PrepareParameters()
        {
            return new PreparePitchParams(
                _seed,
                _pitcher,
                _batter,
                _scouting,
                _context,
                _rivalMemory,
                _gameState,
                _gameLog);
        }

        private PitchPlayViewState Snapshot()
        {
            return new PitchPlayViewState(
                Phase,
                _preparation,
                _pitchType,
                _zone,
                _intent,
                _intensity,
                _aim.X,
                _aim.Y,
                _releaseMeter.Phase,
                _lastResult,
                _context,
                _batter,
                _holdCall,
                _pitcher,
                _scouting,
                _rivalMemory,
                _gameState);
        }

        private void Publish()
        {
            ViewChanged?.Invoke(Snapshot());
        }

        private void RequirePhase(PitchPlayPhase required)
        {
            if (Phase != required) throw new InvalidOperationException($"Pitch phase must be {required}, but was {Phase}.");
        }

        private void RequireCurrentPresentation(PitchPresentationSnapshot presentation)
        {
            if (string.IsNullOrEmpty(_lastPresentationId) || presentation.PitchId != _lastPresentationId)
            {
                throw new InvalidOperationException("Pitch presentation is stale or belongs to another committed Core result.");
            }
        }
    }
}
