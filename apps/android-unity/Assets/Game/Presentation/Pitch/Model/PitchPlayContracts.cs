using System;
using Baseball.Core.Domain;
using Baseball.Core.Pitching;

namespace Baseball.Presentation.Pitch
{
    public enum PitchPlayPhase
    {
        Idle,
        Selecting,
        Timing,
        Presenting,
        Result,
        Completed,
        Aborted,
    }

    public interface IPitchKernelGateway
    {
        PitchPreparation PreparePitch(PreparePitchParams parameters);
        PitchKernelResult SubmitPitch(SubmitPitchParams parameters, PitchDelivery delivery);
    }

    /// <summary>The only gameplay authority used by the pitch presentation.</summary>
    public sealed class AuthoritativePitchKernelGateway : IPitchKernelGateway
    {
        private readonly PitchKernelEngine _engine;

        public AuthoritativePitchKernelGateway(PitchKernelEngine engine = null)
        {
            _engine = engine ?? new PitchKernelEngine();
        }

        public PitchPreparation PreparePitch(PreparePitchParams parameters) => _engine.PreparePitch(parameters);

        public PitchKernelResult SubmitPitch(SubmitPitchParams parameters, PitchDelivery delivery) =>
            _engine.SubmitPitch(parameters, delivery);
    }

    /// <summary>Platform-free boundary. Android audio and haptics implement this outside Presentation.</summary>
    public interface IPitchFeedbackBoundary
    {
        void OnSessionStarted();
        void OnSessionEnded();
        void OnRelease(PitchHapticCue cue);
        void OnResult(PitchPresentationSnapshot presentation);
    }

    public sealed class NullPitchFeedbackBoundary : IPitchFeedbackBoundary
    {
        public static readonly NullPitchFeedbackBoundary Instance = new NullPitchFeedbackBoundary();
        private NullPitchFeedbackBoundary() { }
        public void OnSessionStarted() { }
        public void OnSessionEnded() { }
        public void OnRelease(PitchHapticCue cue) { }
        public void OnResult(PitchPresentationSnapshot presentation) { }
    }

    public sealed class PitchPlayRequest
    {
        public PitchPlayRequest(
            string seed,
            PitcherSnapshot pitcher,
            BatterSnapshot batter,
            BatterScoutingSnapshot scouting,
            PlateAppearanceContext context,
            RivalMemorySnapshot rivalMemory = null,
            GameStateSnapshot gameState = null,
            GameLogSnapshot gameLog = null,
            PersonalityTrait? trait = null,
            PitchCall selectedCall = null,
            bool holdCall = false)
        {
            Seed = string.IsNullOrWhiteSpace(seed) ? throw new ArgumentException("A deterministic seed is required.", nameof(seed)) : seed;
            Pitcher = pitcher ?? throw new ArgumentNullException(nameof(pitcher));
            Batter = batter ?? throw new ArgumentNullException(nameof(batter));
            Scouting = scouting ?? throw new ArgumentNullException(nameof(scouting));
            Context = context ?? throw new ArgumentNullException(nameof(context));
            RivalMemory = rivalMemory;
            GameState = gameState;
            GameLog = gameLog;
            Trait = trait;
            SelectedCall = selectedCall;
            HoldCall = selectedCall != null && holdCall;
        }

        public string Seed { get; }
        public PitcherSnapshot Pitcher { get; }
        public BatterSnapshot Batter { get; }
        public BatterScoutingSnapshot Scouting { get; }
        public PlateAppearanceContext Context { get; }
        public RivalMemorySnapshot RivalMemory { get; }
        public GameStateSnapshot GameState { get; }
        public GameLogSnapshot GameLog { get; }
        public PersonalityTrait? Trait { get; }
        /// <summary>
        /// Player-selected call carried through a durable per-pitch checkpoint. A null value means
        /// the next Core catcher recommendation should seed the controls.
        /// </summary>
        public PitchCall SelectedCall { get; }
        public bool HoldCall { get; }
    }

    public sealed class PitchCommit
    {
        public PitchCommit(
            PitchCall call,
            PitchDelivery delivery,
            PitchKernelResult result,
            PitchPresentationSnapshot presentation,
            PlateAppearanceContext preResultContext = null,
            RivalMemorySnapshot preResultRivalMemory = null,
            bool wasDirect = true,
            int expectedVelocityKph = 0,
            string abilityMomentType = null)
        {
            Call = call ?? throw new ArgumentNullException(nameof(call));
            Delivery = delivery;
            Result = result ?? throw new ArgumentNullException(nameof(result));
            Presentation = presentation ?? throw new ArgumentNullException(nameof(presentation));
            PreResultContext = preResultContext;
            PreResultRivalMemory = preResultRivalMemory;
            WasDirect = wasDirect;
            ExpectedVelocityKph = expectedVelocityKph;
            AbilityMomentType = abilityMomentType;
        }

        public PitchCall Call { get; }
        public PitchDelivery Delivery { get; }
        public PitchKernelResult Result { get; }
        public PitchPresentationSnapshot Presentation { get; }
        public PlateAppearanceContext PreResultContext { get; }
        public RivalMemorySnapshot PreResultRivalMemory { get; }
        public bool WasDirect { get; }
        public int ExpectedVelocityKph { get; }
        /// <summary>Core PitchAbilityKind wire value computed from the pre-result readout.</summary>
        public string AbilityMomentType { get; }
    }

    public sealed class PitchPlayViewState
    {
        public PitchPlayViewState(
            PitchPlayPhase phase,
            PitchPreparation preparation,
            PitchType pitchType,
            PitchZone zone,
            ZoneIntent intent,
            PitchIntensity intensity,
            double normalizedAimX,
            double normalizedAimY,
            double releasePhase,
            PitchKernelResult result,
            PlateAppearanceContext context,
            BatterSnapshot batter,
            bool holdsCall = false,
            PitcherSnapshot pitcher = null,
            BatterScoutingSnapshot scouting = null,
            RivalMemorySnapshot rivalMemory = null,
            GameStateSnapshot gameState = null)
        {
            Phase = phase;
            Preparation = preparation;
            PitchType = pitchType;
            Zone = zone;
            Intent = intent;
            Intensity = intensity;
            NormalizedAimX = normalizedAimX;
            NormalizedAimY = normalizedAimY;
            ReleasePhase = releasePhase;
            Result = result;
            Context = context;
            Batter = batter;
            HoldsCall = holdsCall;
            Pitcher = pitcher;
            Scouting = scouting;
            RivalMemory = rivalMemory;
            GameState = gameState;
        }

        public PitchPlayPhase Phase { get; }
        public PitchPreparation Preparation { get; }
        public PitchType PitchType { get; }
        public PitchZone Zone { get; }
        public ZoneIntent Intent { get; }
        public PitchIntensity Intensity { get; }
        public double NormalizedAimX { get; }
        public double NormalizedAimY { get; }
        public double ReleasePhase { get; }
        public PitchKernelResult Result { get; }
        public PlateAppearanceContext Context { get; }
        public BatterSnapshot Batter { get; }
        public bool HoldsCall { get; }
        public PitcherSnapshot Pitcher { get; }
        public BatterScoutingSnapshot Scouting { get; }
        public RivalMemorySnapshot RivalMemory { get; }
        public GameStateSnapshot GameState { get; }
    }
}
