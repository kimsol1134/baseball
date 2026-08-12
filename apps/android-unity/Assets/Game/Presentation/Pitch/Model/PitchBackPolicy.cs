namespace Baseball.Presentation.Pitch
{
    public enum PitchBackAction
    {
        BlockTutorial,
        CloseConfirmation,
        CancelRelease,
        SkipPresentation,
        CompleteResult,
        ShowExitConfirmation,
    }

    public static class PitchBackPolicy
    {
        public static PitchBackAction Resolve(
            PitchPlayPhase phase,
            bool tutorial,
            bool confirmationVisible)
        {
            if (confirmationVisible) return PitchBackAction.CloseConfirmation;
            if (tutorial) return PitchBackAction.BlockTutorial;
            switch (phase)
            {
                case PitchPlayPhase.Timing: return PitchBackAction.CancelRelease;
                case PitchPlayPhase.Presenting:
                case PitchPlayPhase.Result: return PitchBackAction.SkipPresentation;
                case PitchPlayPhase.Completed: return PitchBackAction.CompleteResult;
                default: return PitchBackAction.ShowExitConfirmation;
            }
        }
    }
}
