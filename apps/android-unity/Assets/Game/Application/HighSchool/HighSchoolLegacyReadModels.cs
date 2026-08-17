using System;
using System.Collections.Generic;
using System.Linq;

namespace Baseball.Application.HighSchool
{
    /// <summary>
    /// Frozen evidence shown and selected at the end of a life. Copy changes or later Core
    /// versions must not alter an offered or archived representative legacy.
    /// </summary>
    public sealed class SignatureLegacyReadModel
    {
        public SignatureLegacyReadModel(
            string id,
            string title,
            string detail,
            string evidenceSummary,
            int? score = null)
        {
            Id = id;
            Title = title;
            Detail = detail;
            EvidenceSummary = evidenceSummary;
            Score = score;
        }

        public string Id { get; }
        public string Title { get; }
        public string Detail { get; }
        public string EvidenceSummary { get; }
        public int? Score { get; }
    }


    public sealed class RelationshipResponseTallyReadModel
    {
        public RelationshipResponseTallyReadModel(
            int listen = 0,
            int explain = 0,
            int challenge = 0)
        {
            Listen = Math.Max(0, listen);
            Explain = Math.Max(0, explain);
            Challenge = Math.Max(0, challenge);
        }

        public int Listen { get; }
        public int Explain { get; }
        public int Challenge { get; }
    }


    public sealed class TalentGradeReadModel
    {
        public TalentGradeReadModel(
            string abilityId,
            string abilityTitle,
            string gradeId,
            string gradeTitle)
        {
            AbilityId = abilityId;
            AbilityTitle = abilityTitle;
            GradeId = gradeId;
            GradeTitle = gradeTitle;
        }

        public string AbilityId { get; }
        public string AbilityTitle { get; }
        public string GradeId { get; }
        public string GradeTitle { get; }
    }


    /// <summary>
    /// Per-life source material carried with the live career so settlement can freeze an honest
    /// archive without reopening an opaque Core JSON snapshot after an app update.
    /// </summary>
    public sealed class HighSchoolLifeDetailReadModel
    {
        public HighSchoolLifeDetailReadModel(
            PitcherRatingsReadModel startingRatings = null,
            IReadOnlyList<string> nicknames = null,
            IReadOnlyList<string> chronicle = null,
            string coachName = null,
            string catcherName = null,
            string rivalName = null,
            string personality = null,
            string windId = null,
            string windTitle = null,
            string schoolStrength = null,
            RelationshipResponseTallyReadModel responseTally = null,
            IReadOnlyList<TalentGradeReadModel> talents = null,
            string presetId = null,
            string presetTitle = null,
            string difficultyId = null,
            string difficultyTitle = null)
        {
            StartingRatings = startingRatings;
            Nicknames = (nicknames ?? Array.Empty<string>()).ToArray();
            Chronicle = (chronicle ?? Array.Empty<string>()).ToArray();
            CoachName = coachName;
            CatcherName = catcherName;
            RivalName = rivalName;
            Personality = personality;
            WindId = windId;
            WindTitle = windTitle;
            SchoolStrength = schoolStrength;
            ResponseTally = responseTally ?? new RelationshipResponseTallyReadModel();
            Talents = (talents ?? Array.Empty<TalentGradeReadModel>()).ToArray();
            PresetId = presetId;
            PresetTitle = presetTitle;
            DifficultyId = difficultyId;
            DifficultyTitle = difficultyTitle;
        }

        public PitcherRatingsReadModel StartingRatings { get; }
        public IReadOnlyList<string> Nicknames { get; }
        public IReadOnlyList<string> Chronicle { get; }
        public string CoachName { get; }
        public string CatcherName { get; }
        public string RivalName { get; }
        public string Personality { get; }
        public string WindId { get; }
        public string WindTitle { get; }
        public string SchoolStrength { get; }
        public RelationshipResponseTallyReadModel ResponseTally { get; }
        public IReadOnlyList<TalentGradeReadModel> Talents { get; }
        public string PresetId { get; }
        public string PresetTitle { get; }
        public string DifficultyId { get; }
        public string DifficultyTitle { get; }
    }
}
