using System;

namespace Baseball.Application.Persistence
{
    public enum SaveFailureCode
    {
        CandidateInvalid,
        SerializationFailed,
        IoFailed,
        VerificationFailed,
        FutureVersionWouldBeOverwritten,
        MigrationRequired,
        RevisionRegression,
        RevisionConflict
    }

    public sealed class SavePersistenceException : Exception
    {
        public SavePersistenceException(SaveFailureCode code, string message, Exception innerException = null)
            : base(message, innerException)
        {
            Code = code;
        }

        public SaveFailureCode Code { get; }
    }
}
