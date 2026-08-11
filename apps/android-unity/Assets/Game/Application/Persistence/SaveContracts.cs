using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;

namespace Baseball.Application.Persistence
{
    public interface IUtcClock
    {
        DateTimeOffset UtcNow { get; }
    }

    public sealed class SystemUtcClock : IUtcClock
    {
        public DateTimeOffset UtcNow => DateTimeOffset.UtcNow;
    }

    public sealed class SaveValidationResult
    {
        private SaveValidationResult(bool isValid, IReadOnlyList<string> errors)
        {
            IsValid = isValid;
            Errors = errors;
        }

        public bool IsValid { get; }

        public IReadOnlyList<string> Errors { get; }

        public static SaveValidationResult Success { get; } =
            new SaveValidationResult(true, Array.Empty<string>());

        public static SaveValidationResult Invalid(params string[] errors)
        {
            if (errors == null || errors.Length == 0)
            {
                throw new ArgumentException("At least one validation error is required.", nameof(errors));
            }

            return new SaveValidationResult(false, errors);
        }
    }

    public interface ISavePayloadValidator<in TPayload>
    {
        SaveValidationResult Validate(TPayload payload);
    }

    public interface ISaveSemanticPriority<in TPayload>
    {
        int GetPriority(TPayload payload);
    }

    public sealed class AcceptAllSavePayloads<TPayload> : ISavePayloadValidator<TPayload>
    {
        public SaveValidationResult Validate(TPayload payload)
        {
            return payload == null
                ? SaveValidationResult.Invalid("payload.null")
                : SaveValidationResult.Success;
        }
    }

    public sealed class DefaultSaveSemanticPriority<TPayload> : ISaveSemanticPriority<TPayload>
    {
        public int GetPriority(TPayload payload) => 0;
    }

    public interface ISaveRepository<TPayload>
    {
        Task<SaveWriteResult<TPayload>> SaveAsync(
            TPayload payload,
            ulong revision,
            CancellationToken cancellationToken = default);

        Task<SaveLoadResult<TPayload>> LoadAsync(
            CancellationToken cancellationToken = default);

        Task ResetAsync(CancellationToken cancellationToken = default);
    }
}
