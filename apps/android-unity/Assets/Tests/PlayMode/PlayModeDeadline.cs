using System;
using System.Collections;
using NUnit.Framework;
using UnityEngine;

namespace Baseball.PlayMode.Tests
{
    internal static class PlayModeDeadline
    {
        public const float DefaultSeconds = 5f;

        public static IEnumerator Until(
            Func<bool> condition,
            string failureMessage,
            float timeoutSeconds = DefaultSeconds)
        {
            if (condition == null) throw new ArgumentNullException(nameof(condition));
            if (timeoutSeconds <= 0f) throw new ArgumentOutOfRangeException(nameof(timeoutSeconds));

            float deadline = Time.realtimeSinceStartup + timeoutSeconds;
            while (!condition() && Time.realtimeSinceStartup < deadline)
            {
                yield return null;
            }

            Assert.That(condition(), Is.True, failureMessage + $" ({timeoutSeconds:0.0}초 제한)");
        }
    }
}
