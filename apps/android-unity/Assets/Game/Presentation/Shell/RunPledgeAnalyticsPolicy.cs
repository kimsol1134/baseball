using System;
using Baseball.Application.Meta;

namespace Baseball.Presentation.Shell
{
    public static class RunPledgeAnalyticsPolicy
    {
        /// <summary>
        /// The command consumes the carried intent, so recommendation evidence must come from
        /// the durable pre-command snapshot rather than the cleared post-command projection.
        /// </summary>
        public static bool WasRecommended(NextRunIntentState beforeIntent, string selectedPledgeId)
        {
            return beforeIntent != null && !string.IsNullOrWhiteSpace(selectedPledgeId) &&
                string.Equals(beforeIntent.PledgeId, selectedPledgeId, StringComparison.Ordinal);
        }
    }
}
