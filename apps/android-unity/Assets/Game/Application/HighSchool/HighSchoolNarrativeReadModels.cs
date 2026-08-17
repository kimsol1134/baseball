using System;
using System.Collections.Generic;
using System.Linq;

namespace Baseball.Application.HighSchool
{
    public sealed class RelationshipEventReadModel
    {
        public RelationshipEventReadModel(
            string id,
            string title,
            string category,
            string summary,
            string speaker,
            string trustBand,
            string quote)
        {
            Id = id;
            Title = title;
            Category = category;
            Summary = summary;
            Speaker = speaker;
            TrustBand = trustBand;
            Quote = quote;
        }

        public string Id { get; }
        public string Title { get; }
        public string Category { get; }
        public string Summary { get; }
        public string Speaker { get; }
        public string TrustBand { get; }
        public string Quote { get; }
    }


    public sealed class GameScenarioNarrativeReadModel
    {
        public GameScenarioNarrativeReadModel(
            string id,
            string title,
            string narrative,
            int inning,
            int outs,
            int leverage,
            int scoreDifferential)
        {
            Id = id;
            Title = title;
            Narrative = narrative;
            Inning = inning;
            Outs = outs;
            Leverage = leverage;
            ScoreDifferential = scoreDifferential;
        }

        public string Id { get; }
        public string Title { get; }
        public string Narrative { get; }
        public int Inning { get; }
        public int Outs { get; }
        public int Leverage { get; }
        public int ScoreDifferential { get; }
    }


    public sealed class RelationshipResultReadModel
    {
        public RelationshipResultReadModel(
            int number,
            string category,
            string title,
            string response,
            int trustBefore,
            int trustAfter,
            int fatigueBefore,
            int fatigueAfter,
            int fanInterestBefore,
            int fanInterestAfter,
            string feedback)
        {
            Number = number;
            Category = category;
            Title = title;
            Response = response;
            TrustBefore = trustBefore;
            TrustAfter = trustAfter;
            FatigueBefore = fatigueBefore;
            FatigueAfter = fatigueAfter;
            FanInterestBefore = fanInterestBefore;
            FanInterestAfter = fanInterestAfter;
            Feedback = feedback;
        }

        public int Number { get; }
        public string Category { get; }
        public string Title { get; }
        public string Response { get; }
        public int TrustBefore { get; }
        public int TrustAfter { get; }
        public int FatigueBefore { get; }
        public int FatigueAfter { get; }
        public int FanInterestBefore { get; }
        public int FanInterestAfter { get; }
        public string Feedback { get; }
    }
}
