using System;

namespace Baseball.Application.Commands
{
    /// <summary>
    /// Stable, presentation-facing option for a domain command. The ID (or Payload when supplied)
    /// is the value that must be sent back to Application; labels are display-only Korean copy.
    /// </summary>
    public sealed class CareerChoiceReadModel
    {
        public CareerChoiceReadModel(
            string id,
            string title,
            string detail = null,
            string effectSummary = null,
            bool enabled = true,
            string disabledReason = null,
            string payload = null,
            bool recommended = false,
            string recommendationReason = null)
        {
            if (string.IsNullOrWhiteSpace(id))
                throw new ArgumentException("A stable choice ID is required.", nameof(id));
            Id = id;
            Title = string.IsNullOrWhiteSpace(title) ? id : title;
            Detail = detail;
            EffectSummary = effectSummary;
            Enabled = enabled;
            DisabledReason = enabled ? null : disabledReason;
            Payload = string.IsNullOrWhiteSpace(payload) ? id : payload;
            Recommended = recommended;
            RecommendationReason = recommended ? recommendationReason : null;
        }

        public string Id { get; }
        public string Title { get; }
        public string Detail { get; }
        public string EffectSummary { get; }
        public bool Enabled { get; }
        public string DisabledReason { get; }
        public string Payload { get; }
        public bool Recommended { get; }
        public string RecommendationReason { get; }
    }
}
