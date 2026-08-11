using System;

namespace Baseball.Core.Domain
{
    public enum SimulationErrorCode
    {
        InvalidSeed,
        InvalidRating,
        InvalidZone,
        InvalidCount,
        InvalidFatigue,
        InvalidPlateAppearance,
        InvalidScouting,
        InvalidPreparationToken,
        InvalidPitchProfile,
        InvalidPitchDelivery,
        InvalidRivalMemory,
        InvalidGameState,
        InvalidGameLog
    }

    public sealed class SimulationException : Exception
    {
        public SimulationException(SimulationErrorCode code, string message) : base(message)
        {
            Code = code;
        }

        public SimulationErrorCode Code { get; }
    }
}
