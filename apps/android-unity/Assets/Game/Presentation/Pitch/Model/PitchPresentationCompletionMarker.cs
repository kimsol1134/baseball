using System;

namespace Baseball.Presentation.Pitch
{
    /// <summary>
    /// Guards the production device-smoke marker at the durable presentation boundary. Pitch IDs
    /// are never included in the emitted line and are retained only in process for deduplication.
    /// </summary>
    public sealed class PitchPresentationCompletionMarker
    {
        public const string LogLine =
            "BASEBALL_PITCH_PRESENTATION_COMPLETED schema=1 status=passed";

        private string _lastPitchId;

        public bool TryMark(string pitchId, bool commitDurable, bool presentationFinished)
        {
            if (!commitDurable || !presentationFinished || string.IsNullOrWhiteSpace(pitchId))
                return false;
            if (string.Equals(_lastPitchId, pitchId, StringComparison.Ordinal)) return false;
            _lastPitchId = pitchId;
            return true;
        }
    }
}
