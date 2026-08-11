namespace Baseball.Application.Persistence
{
    public enum SaveFaultPoint
    {
        BeforeCandidateValidation,
        AfterCandidateValidation,
        AfterTempWrite,
        AfterTempValidation,
        AfterBackupRotation,
        BeforeCanonicalSwap,
        AfterCanonicalSwap,
        BeforeCanonicalVerification,
        AfterCanonicalVerification
    }

    public interface ISaveFaultInjector
    {
        void Checkpoint(SaveFaultPoint point);
    }

    public sealed class NoSaveFaults : ISaveFaultInjector
    {
        public static NoSaveFaults Instance { get; } = new NoSaveFaults();

        private NoSaveFaults()
        {
        }

        public void Checkpoint(SaveFaultPoint point)
        {
        }
    }
}
