using System;

namespace Baseball.Platform.Identity
{
    /// <summary>Pure ID generation/validation policy shared by Unity storage and static tests.</summary>
    public static class AnonymousInstallIdentityPolicy
    {
        public static string CreateCandidate() => Guid.NewGuid().ToString("N");

        public static bool IsValid(string value) => Guid.TryParseExact(value, "N", out _);
    }
}
