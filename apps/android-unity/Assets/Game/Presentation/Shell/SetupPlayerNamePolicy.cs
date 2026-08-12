using System;
using Baseball.Application.HighSchool;
using Baseball.Application.Persistence;

namespace Baseball.Presentation.Shell
{
    /// <summary>
    /// Distinguishes a new durable Setup cycle from re-rendering or navigating away from the same
    /// unsaved draft. A challenge exit re-enters Setup from an active career; a rebirth changes the
    /// life number. Both must reset transient controls, while same-cycle route changes must not.
    /// </summary>
    public sealed class SetupDraftLifecyclePolicy
    {
        private bool _observed;
        private bool _wasSetupActive;
        private string _installId = string.Empty;
        private int _lifeNumber = -1;

        public bool Observe(
            bool setupActive,
            string installId,
            int lifeNumber,
            bool storeReplaced = false)
        {
            string normalizedInstallId = installId ?? string.Empty;
            bool shouldReset = setupActive &&
                (storeReplaced || !_observed || !_wasSetupActive ||
                 _lifeNumber != lifeNumber ||
                 !string.Equals(_installId, normalizedInstallId, StringComparison.Ordinal));
            _observed = true;
            _wasSetupActive = setupActive;
            _installId = normalizedInstallId;
            _lifeNumber = lifeNumber;
            return shouldReset;
        }
    }

    public static class SetupPlayerNamePolicy
    {
        public const int MaximumLength = 12;

        public static bool TryUpdate(string current, string input, out string next)
        {
            string candidate = (input ?? string.Empty).Trim();
            if (candidate.Length > MaximumLength)
            {
                next = current ?? string.Empty;
                return false;
            }
            next = candidate;
            return true;
        }

        public static string Resolve(string draft, string suggested)
        {
            string entered = (draft ?? string.Empty).Trim();
            if (entered.Length > 0) return entered;
            string fallback = (suggested ?? string.Empty).Trim();
            return fallback.Length > 0 ? fallback : "민서준";
        }
    }

    /// <summary>
    /// Keeps the setup CTA and the production command boundary on the same seed validation rule.
    /// An empty input deliberately selects the installation-derived default seed; every non-empty
    /// input must parse successfully before a career command can be created.
    /// </summary>
    public static class SetupSeedInputPolicy
    {
        public const string InvalidMessage =
            "시드는 숫자, 도전 코드는 숫자-회차 형식으로 입력해 주세요.";

        public static bool IsValid(string input) =>
            HighSchoolSetupCatalog.TryParseSeedInput(input, out _, out _);

        public static string ValidationMessage(string input) =>
            IsValid(input) ? string.Empty : InvalidMessage;

        public static bool TryResolve(
            string input,
            string defaultSeed,
            out HighSchoolSeedSelection selection,
            out string resolvedSeed)
        {
            if (!HighSchoolSetupCatalog.TryParseSeedInput(input, out selection, out _))
            {
                resolvedSeed = null;
                return false;
            }

            resolvedSeed = selection?.Seed ?? (defaultSeed ?? string.Empty).Trim();
            return !string.IsNullOrWhiteSpace(resolvedSeed);
        }
    }

    /// <summary>
    /// Identifies the durable career/phase that owns transient choice controls. Re-rendering or
    /// leaving and returning to the same phase keeps the draft; a replacement store, new career,
    /// or authoritative phase transition starts a fresh projection.
    /// </summary>
    public sealed class CareerChoiceDraftLifecyclePolicy
    {
        private bool _observed;
        private string _key = string.Empty;

        public bool Observe(GameSaveAggregate state, bool storeReplaced = false)
        {
            string next = Key(state);
            bool changed = storeReplaced || !_observed ||
                !string.Equals(_key, next, StringComparison.Ordinal);
            _observed = true;
            _key = next;
            return changed;
        }

        public static string Key(GameSaveAggregate state)
        {
            if (state == null) return "unavailable";
            return state.Stage + "|hs:" + (state.HighSchool?.CareerId ?? "none") + ":" +
                (state.HighSchool?.Phase.ToString() ?? "none") + "|pro:" +
                (state.Pro?.ProCareerId ?? "none") + ":" +
                (state.Pro?.Phase.ToString() ?? "none");
        }
    }
}
