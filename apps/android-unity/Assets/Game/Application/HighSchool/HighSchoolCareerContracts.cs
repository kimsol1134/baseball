using System;
using System.Collections.Generic;
using System.Linq;
using Baseball.Application.Commands;
using Baseball.Application.Persistence;
using Baseball.Core.Domain;

namespace Baseball.Application.HighSchool
{
    /// <summary>
    /// Application-owned phases. They deliberately do not serialize the evolving Core snapshot.
    /// A Core adapter may translate these values while saves remain stable across engine changes.
    /// </summary>
    public enum HighSchoolPhase
    {
        Prologue,
        SchoolSelection,
        Training,
        Relationship,
        ImportantGame,
        Awakening,
        ChapterReview,
        Draft,
        Legacy,
        Completed
    }

    public enum LegacySelectionMode
    {
        Memories,
        SignatureLegacy
    }

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

    public sealed class PitcherRatingsReadModel
    {
        public PitcherRatingsReadModel(int stuff, int command, int movement, int stamina)
        {
            Stuff = stuff;
            Command = command;
            Movement = movement;
            Stamina = stamina;
        }

        public int Stuff { get; }
        public int Command { get; }
        public int Movement { get; }
        public int Stamina { get; }
        public int Total => Stuff + Command + Movement + Stamina;
    }

    public sealed class CareerPerformanceReadModel
    {
        public CareerPerformanceReadModel(
            int importantGames = 0,
            int pitches = 0,
            int outs = 0,
            int strikeouts = 0,
            int walks = 0,
            int hits = 0,
            int runsAllowed = 0)
        {
            ImportantGames = importantGames;
            Pitches = pitches;
            Outs = outs;
            Strikeouts = strikeouts;
            Walks = walks;
            Hits = hits;
            RunsAllowed = runsAllowed;
        }

        public int ImportantGames { get; }
        public int Pitches { get; }
        public int Outs { get; }
        public int Strikeouts { get; }
        public int Walks { get; }
        public int Hits { get; }
        public int RunsAllowed { get; }
    }

    public sealed class DraftReadModel
    {
        public DraftReadModel(
            bool resolved,
            bool drafted,
            int evaluationScore,
            string teamId = null,
            string teamName = null,
            int? round = null,
            int? overallPick = null)
        {
            Resolved = resolved;
            Drafted = drafted;
            EvaluationScore = evaluationScore;
            TeamId = teamId;
            TeamName = teamName;
            Round = round;
            OverallPick = overallPick;
        }

        public bool Resolved { get; }
        public bool Drafted { get; }
        public int EvaluationScore { get; }
        public string TeamId { get; }
        public string TeamName { get; }
        public int? Round { get; }
        public int? OverallPick { get; }
    }

    public sealed class TournamentBracketReadModel
    {
        public TournamentBracketReadModel(
            string tournamentName,
            IReadOnlyList<string> schools,
            string playerRound)
        {
            TournamentName = tournamentName;
            Schools = (schools ?? Array.Empty<string>()).ToArray();
            PlayerRound = playerRound;
        }

        public string TournamentName { get; }
        public IReadOnlyList<string> Schools { get; }
        public string PlayerRound { get; }
    }

    public sealed class ProspectEntryReadModel
    {
        public ProspectEntryReadModel(
            int rank,
            string name,
            string school,
            string tag,
            bool isPlayer)
        {
            Rank = rank;
            Name = name;
            School = school;
            Tag = tag;
            IsPlayer = isPlayer;
        }

        public int Rank { get; }
        public string Name { get; }
        public string School { get; }
        public string Tag { get; }
        public bool IsPlayer { get; }
    }

    public sealed class CareerGameLineReadModel
    {
        public CareerGameLineReadModel(
            int season,
            int week,
            int outingNumber,
            bool played,
            bool started,
            int outs,
            int strikeouts,
            int walks,
            int? hits,
            int runsAllowed,
            int pitches,
            int teamRuns,
            int opponentRuns,
            string decision,
            int? homeRuns = null,
            int? recordedHits = null)
        {
            Season = season;
            Week = week;
            OutingNumber = outingNumber;
            Played = played;
            Started = started;
            Outs = outs;
            Strikeouts = strikeouts;
            Walks = walks;
            Hits = hits ?? 0;
            RecordedHits = recordedHits;
            RunsAllowed = runsAllowed;
            Pitches = pitches;
            TeamRuns = teamRuns;
            OpponentRuns = opponentRuns;
            Decision = decision;
            HomeRuns = homeRuns;
        }

        public int Season { get; }
        public int Week { get; }
        public int OutingNumber { get; }
        public bool Played { get; }
        public bool Started { get; }
        public int Outs { get; }
        public int Strikeouts { get; }
        public int Walks { get; }
        /// <summary>Legacy compatibility value. Use RecordedHits for record/league surfaces.</summary>
        public int Hits { get; }
        /// <summary>
        /// Null means the source result did not record hits. It must not be rendered as zero.
        /// </summary>
        public int? RecordedHits { get; }
        /// <summary>
        /// Null means the source result did not record home runs. It must not be rendered as zero.
        /// </summary>
        public int? HomeRuns { get; }
        public int RunsAllowed { get; }
        public int Pitches { get; }
        public int TeamRuns { get; }
        public int OpponentRuns { get; }
        public string Decision { get; }
        public bool IsQualityStart => PitchingMetrics.IsQualityStart(Started, Outs, RunsAllowed);
    }

    /// <summary>
    /// Authoritative raw pitching totals plus Core-calculated modern pitching metrics. Nullable
    /// totals are deliberately unavailable: an old or direct-play result that did not record a
    /// hit/home-run count is never silently converted to a zero.
    /// </summary>
    public sealed class PitchingRecordReadModel
    {
        public PitchingRecordReadModel(
            int games,
            int starts,
            int outs,
            int strikeouts,
            int walks,
            int runsAllowed,
            int wins = 0,
            int losses = 0,
            int saves = 0,
            int? hits = null,
            int? homeRuns = null,
            int? pitches = null,
            int? qualityStarts = null)
        {
            Games = games;
            Starts = starts;
            Outs = outs;
            Strikeouts = strikeouts;
            Walks = walks;
            RunsAllowed = runsAllowed;
            Wins = wins;
            Losses = losses;
            Saves = saves;
            Hits = hits;
            HomeRuns = homeRuns;
            Pitches = pitches;
            QualityStarts = qualityStarts;
        }

        public int Games { get; }
        public int Starts { get; }
        public int Outs { get; }
        public int Strikeouts { get; }
        public int Walks { get; }
        public int RunsAllowed { get; }
        public int Wins { get; }
        public int Losses { get; }
        public int Saves { get; }
        public int? Hits { get; }
        public int? HomeRuns { get; }
        public int? Pitches { get; }
        public int? QualityStarts { get; }

        public double Innings => PitchingMetrics.Innings(Outs);
        public string InningsText => PitchingMetrics.InningsText(Outs);
        public double? RunsPerNine => PitchingMetrics.RunsPer9(RunsAllowed, Outs);
        public double? StrikeoutsPerNine => PitchingMetrics.Per9(Strikeouts, Outs);
        public double? WalksPerNine => PitchingMetrics.Per9(Walks, Outs);
        public double? StrikeoutToWalk => PitchingMetrics.StrikeoutToWalk(Strikeouts, Walks);
        public double? Whip => Hits.HasValue
            ? PitchingMetrics.Whip(Hits.Value, Walks, Outs)
            : null;
        public double? HitsPerNine => Hits.HasValue
            ? PitchingMetrics.Per9(Hits.Value, Outs)
            : null;
        public double? HomeRunsPerNine => HomeRuns.HasValue
            ? PitchingMetrics.Per9(HomeRuns.Value, Outs)
            : null;
        public double? FieldingIndependentPitching => HomeRuns.HasValue
            ? PitchingMetrics.Fip(HomeRuns.Value, Walks, 0, Strikeouts, Outs)
            : null;
        public int? BattersFaced => Hits.HasValue
            ? PitchingMetrics.BattersFaced(Outs, Hits.Value, Walks)
            : null;
        public double? StrikeoutRate => BattersFaced.HasValue
            ? PitchingMetrics.StrikeoutRate(Strikeouts, BattersFaced.Value)
            : null;
        public double? BattingAverageOnBallsInPlay => Hits.HasValue && HomeRuns.HasValue
            ? PitchingMetrics.Babip(Hits.Value, HomeRuns.Value, Strikeouts, Outs, Walks)
            : null;

        public static PitchingRecordReadModel FromGameLines(
            IReadOnlyList<CareerGameLineReadModel> gameLines)
        {
            var lines = (gameLines ?? Array.Empty<CareerGameLineReadModel>()).ToArray();
            var hits = KnownSum(lines.Select(value => value.RecordedHits));
            var homeRuns = KnownSum(lines.Select(value => value.HomeRuns));
            return new PitchingRecordReadModel(
                lines.Length,
                lines.Count(value => value.Started),
                lines.Sum(value => value.Outs),
                lines.Sum(value => value.Strikeouts),
                lines.Sum(value => value.Walks),
                lines.Sum(value => value.RunsAllowed),
                lines.Count(value => string.Equals(value.Decision, "win", StringComparison.Ordinal)),
                lines.Count(value => string.Equals(value.Decision, "loss", StringComparison.Ordinal)),
                lines.Count(value => string.Equals(value.Decision, "save", StringComparison.Ordinal)),
                hits,
                homeRuns,
                lines.Sum(value => value.Pitches),
                lines.Count(value => value.IsQualityStart));
        }

        private static int? KnownSum(IEnumerable<int?> values)
        {
            var items = values.ToArray();
            return items.All(value => value.HasValue)
                ? items.Sum(value => value.Value)
                : (int?)null;
        }
    }

    public sealed class ChapterProgressReadModel
    {
        public ChapterProgressReadModel(
            int number,
            string title,
            int schoolYear,
            string season,
            string goal,
            int trainingsCompleted,
            int trainingsRequired,
            int milestoneIndex,
            int milestoneCount,
            string resultLine = null)
        {
            Number = number;
            Title = title;
            SchoolYear = schoolYear;
            Season = season;
            Goal = goal;
            TrainingsCompleted = trainingsCompleted;
            TrainingsRequired = trainingsRequired;
            MilestoneIndex = milestoneIndex;
            MilestoneCount = milestoneCount;
            ResultLine = resultLine;
        }

        public int Number { get; }
        public string Title { get; }
        public int SchoolYear { get; }
        public string Season { get; }
        public string Goal { get; }
        public int TrainingsCompleted { get; }
        public int TrainingsRequired { get; }
        public int MilestoneIndex { get; }
        public int MilestoneCount { get; }
        public string ResultLine { get; }
    }

    public sealed class CareerMilestoneReadModel
    {
        public CareerMilestoneReadModel(
            int chapterNumber,
            int order,
            string phase,
            bool completed,
            bool current)
        {
            ChapterNumber = chapterNumber;
            Order = order;
            Phase = phase;
            Completed = completed;
            Current = current;
        }

        public int ChapterNumber { get; }
        public int Order { get; }
        public string Phase { get; }
        public bool Completed { get; }
        public bool Current { get; }
    }

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

    public sealed class TrainingResultReadModel
    {
        public TrainingResultReadModel(
            int number,
            string focus,
            string intensity,
            int growth,
            int fatigueChange,
            string feedback,
            int? metricBefore,
            int? metricAfter,
            bool opportunityHit,
            bool jackpot,
            string targetPitch = null,
            string bloomedAbility = null,
            string bloomedGrade = null)
        {
            Number = number;
            Focus = focus;
            Intensity = intensity;
            Growth = growth;
            FatigueChange = fatigueChange;
            Feedback = feedback;
            MetricBefore = metricBefore;
            MetricAfter = metricAfter;
            OpportunityHit = opportunityHit;
            Jackpot = jackpot;
            TargetPitch = targetPitch;
            BloomedAbility = bloomedAbility;
            BloomedGrade = bloomedGrade;
        }

        public int Number { get; }
        public string Focus { get; }
        public string Intensity { get; }
        public int Growth { get; }
        public int FatigueChange { get; }
        public string Feedback { get; }
        public int? MetricBefore { get; }
        public int? MetricAfter { get; }
        public bool OpportunityHit { get; }
        public bool Jackpot { get; }
        public string TargetPitch { get; }
        /// <summary>Stable TalentAbility wire captured by Core when a ceiling blooms.</summary>
        public string BloomedAbility { get; }
        /// <summary>Stable TalentGrade wire captured with BloomedAbility.</summary>
        public string BloomedGrade { get; }
    }

    public sealed class TrainingBlockResultReadModel
    {
        public TrainingBlockResultReadModel(
            int maximumSessions,
            int completedSessions,
            string focus,
            string intensity,
            string targetPitch,
            string stopReason,
            int growth,
            int fatigueChange,
            IReadOnlyList<TrainingResultReadModel> sessions = null,
            string bloomedAbility = null,
            string bloomedGrade = null)
        {
            MaximumSessions = maximumSessions;
            CompletedSessions = completedSessions;
            Focus = focus;
            Intensity = intensity;
            TargetPitch = targetPitch;
            StopReason = stopReason;
            Growth = growth;
            FatigueChange = fatigueChange;
            Sessions = (sessions ?? Array.Empty<TrainingResultReadModel>()).ToArray();
            BloomedAbility = bloomedAbility;
            BloomedGrade = bloomedGrade;
        }

        public int MaximumSessions { get; }
        public int CompletedSessions { get; }
        public string Focus { get; }
        public string Intensity { get; }
        public string TargetPitch { get; }
        public string StopReason { get; }
        public int Growth { get; }
        public int FatigueChange { get; }
        public IReadOnlyList<TrainingResultReadModel> Sessions { get; }
        /// <summary>The first Core-reported bloom in this bounded block, if any.</summary>
        public string BloomedAbility { get; }
        public string BloomedGrade { get; }
    }

    /// <summary>
    /// Core-calculated growth outlook for one exact focus/intensity payload pair. Presentation
    /// selects a row; it does not reproduce fatigue, opportunity, talent, or career-wind rules.
    /// </summary>
    public sealed class TrainingOutlookReadModel
    {
        public TrainingOutlookReadModel(
            string focusId,
            string intensityId,
            string outlookId,
            string title,
            string summary)
        {
            FocusId = focusId;
            IntensityId = intensityId;
            OutlookId = outlookId;
            Title = title;
            Summary = summary;
        }

        public string FocusId { get; }
        public string IntensityId { get; }
        public string OutlookId { get; }
        public string Title { get; }
        public string Summary { get; }
    }

    public static class HighSchoolTrainingOutlookProjection
    {
        /// <summary>
        /// Returns the saved Core projection only when both supplied payloads are currently
        /// enabled choices. Null is the fail-closed result for stale, blank, or illegal payloads.
        /// </summary>
        public static TrainingOutlookReadModel Resolve(
            HighSchoolCareerReadModel career,
            string focusPayload,
            string intensityPayload)
        {
            if (career == null || career.Phase != HighSchoolPhase.Training ||
                string.IsNullOrWhiteSpace(focusPayload) ||
                string.IsNullOrWhiteSpace(intensityPayload))
            {
                return null;
            }
            var focusAllowed = career.TrainingFocusChoices.Any(value =>
                value != null && value.Enabled &&
                string.Equals(value.Payload, focusPayload, StringComparison.Ordinal));
            var intensityAllowed = career.TrainingIntensityChoices.Any(value =>
                value != null && value.Enabled &&
                string.Equals(value.Payload, intensityPayload, StringComparison.Ordinal));
            if (!focusAllowed || !intensityAllowed) return null;
            return career.TrainingOutlooks.FirstOrDefault(value =>
                value != null &&
                string.Equals(value.FocusId, focusPayload, StringComparison.Ordinal) &&
                string.Equals(value.IntensityId, intensityPayload, StringComparison.Ordinal));
        }
    }

    public static class HighSchoolTrainingActionPayload
    {
        public const string SingleAction = "train";
        public const string BlockAction = "train_block";
        public const int MaximumBlockSessions = 3;

        public static string Encode(string focusId, string intensityId, string targetPitchId = null)
        {
            if (string.IsNullOrWhiteSpace(focusId)) throw new ArgumentException("A focus ID is required.", nameof(focusId));
            if (string.IsNullOrWhiteSpace(intensityId)) throw new ArgumentException("An intensity ID is required.", nameof(intensityId));
            return string.IsNullOrWhiteSpace(targetPitchId)
                ? focusId + ":" + intensityId
                : focusId + ":" + intensityId + ":" + targetPitchId;
        }
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

    public sealed class HighSchoolCareerReadModel
    {
        public HighSchoolCareerReadModel(
            string careerId,
            int lifeNumber,
            HighSchoolPhase phase,
            string nextSeed,
            ulong coreRevision,
            string playerId,
            string playerName,
            string presetId,
            PitcherRatingsReadModel ratings,
            CareerPerformanceReadModel performance,
            string schoolId = null,
            string schoolName = null,
            int schoolYear = 1,
            int chapterNumber = 1,
            int remainingImportantGames = 0,
            int remainingChapterAdvances = 0,
            DraftReadModel draft = null,
            string coreStateJson = null,
            string pledgeId = null,
            bool pledgeDecided = false,
            IReadOnlyList<string> karmas = null,
            IReadOnlyList<string> awakenings = null,
            IReadOnlyList<CareerChoiceReadModel> schoolChoices = null,
            IReadOnlyList<CareerChoiceReadModel> trainingFocusChoices = null,
            IReadOnlyList<CareerChoiceReadModel> trainingIntensityChoices = null,
            IReadOnlyList<CareerChoiceReadModel> relationshipChoices = null,
            IReadOnlyList<CareerChoiceReadModel> awakeningChoices = null,
            IReadOnlyList<CareerChoiceReadModel> legacyMemoryChoices = null,
            int memorySlots = 0,
            TournamentBracketReadModel tournament = null,
            IReadOnlyList<ProspectEntryReadModel> prospectRankings = null,
            IReadOnlyList<CareerGameLineReadModel> gameLines = null,
            IReadOnlyList<CareerChoiceReadModel> signatureLegacyChoices = null,
            string equippedSignatureLegacyId = null,
            string selectedSignatureLegacyId = null,
            string difficulty = "standard",
            bool isChallengeRun = false,
            LegacySelectionMode legacySelectionMode = LegacySelectionMode.Memories,
            bool tutorialCompleted = false,
            int tutorialAttemptCount = 0,
            int pledgeRulesVersion = 0,
            int legacyRewardPermille = 1000,
            int rivalStrikeouts = 0,
            int fatigue = 0,
            int armRisk = 0,
            int injuryRecovery = 0,
            int managerTrust = 50,
            int catcherTrust = 50,
            int rivalTrust = 50,
            int fanInterest = 0,
            int draftForecastScore = 0,
            ChapterProgressReadModel chapterProgress = null,
            IReadOnlyList<CareerMilestoneReadModel> scheduleMilestones = null,
            RelationshipEventReadModel currentRelationshipEvent = null,
            GameScenarioNarrativeReadModel currentGameScenario = null,
            TrainingResultReadModel lastTraining = null,
            RelationshipResultReadModel lastRelationship = null,
            IReadOnlyList<string> news = null,
            IReadOnlyList<CareerChoiceReadModel> trainingPitchChoices = null,
            TrainingBlockResultReadModel lastTrainingBlock = null,
            int maximumTrainingBlockSessions = HighSchoolTrainingActionPayload.MaximumBlockSessions,
            IReadOnlyList<SignatureLegacyReadModel> frozenSignatureLegacyCandidates = null,
            SignatureLegacyReadModel selectedSignatureLegacy = null,
            HighSchoolLifeDetailReadModel lifeDetail = null,
            IReadOnlyList<TrainingOutlookReadModel> trainingOutlooks = null)
        {
            CareerId = careerId;
            LifeNumber = lifeNumber;
            Phase = phase;
            NextSeed = nextSeed;
            CoreRevision = coreRevision;
            PlayerId = playerId;
            PlayerName = playerName;
            PresetId = presetId;
            Ratings = ratings;
            Performance = performance;
            SchoolId = schoolId;
            SchoolName = schoolName;
            SchoolYear = schoolYear;
            ChapterNumber = chapterNumber;
            RemainingImportantGames = remainingImportantGames;
            RemainingChapterAdvances = remainingChapterAdvances;
            Draft = draft;
            CoreStateJson = coreStateJson;
            PledgeId = pledgeId;
            PledgeDecided = pledgeDecided;
            Karmas = (karmas ?? Array.Empty<string>()).ToArray();
            Awakenings = (awakenings ?? Array.Empty<string>()).ToArray();
            SchoolChoices = (schoolChoices ?? Array.Empty<CareerChoiceReadModel>()).ToArray();
            TrainingFocusChoices = (trainingFocusChoices ?? Array.Empty<CareerChoiceReadModel>()).ToArray();
            TrainingIntensityChoices = (trainingIntensityChoices ?? Array.Empty<CareerChoiceReadModel>()).ToArray();
            RelationshipChoices = (relationshipChoices ?? Array.Empty<CareerChoiceReadModel>()).ToArray();
            AwakeningChoices = (awakeningChoices ?? Array.Empty<CareerChoiceReadModel>()).ToArray();
            LegacyMemoryChoices = (legacyMemoryChoices ?? Array.Empty<CareerChoiceReadModel>()).ToArray();
            MemorySlots = memorySlots;
            Tournament = tournament;
            ProspectRankings = (prospectRankings ?? Array.Empty<ProspectEntryReadModel>()).ToArray();
            GameLines = (gameLines ?? Array.Empty<CareerGameLineReadModel>()).ToArray();
            SignatureLegacyChoices = (signatureLegacyChoices ?? Array.Empty<CareerChoiceReadModel>()).ToArray();
            EquippedSignatureLegacyId = equippedSignatureLegacyId;
            SelectedSignatureLegacyId = selectedSignatureLegacyId;
            Difficulty = difficulty;
            IsChallengeRun = isChallengeRun;
            LegacySelectionMode = legacySelectionMode;
            TutorialCompleted = tutorialCompleted;
            TutorialAttemptCount = tutorialAttemptCount;
            PledgeRulesVersion = pledgeRulesVersion;
            LegacyRewardPermille = Math.Max(1000, legacyRewardPermille);
            RivalStrikeouts = Math.Max(0, rivalStrikeouts);
            Fatigue = fatigue;
            ArmRisk = armRisk;
            InjuryRecovery = injuryRecovery;
            ManagerTrust = managerTrust;
            CatcherTrust = catcherTrust;
            RivalTrust = rivalTrust;
            FanInterest = fanInterest;
            DraftForecastScore = draftForecastScore;
            ChapterProgress = chapterProgress;
            ScheduleMilestones = (scheduleMilestones ?? Array.Empty<CareerMilestoneReadModel>()).ToArray();
            CurrentRelationshipEvent = currentRelationshipEvent;
            CurrentGameScenario = currentGameScenario;
            LastTraining = lastTraining;
            LastRelationship = lastRelationship;
            News = (news ?? Array.Empty<string>()).ToArray();
            TrainingPitchChoices = (trainingPitchChoices ?? Array.Empty<CareerChoiceReadModel>()).ToArray();
            LastTrainingBlock = lastTrainingBlock;
            MaximumTrainingBlockSessions = maximumTrainingBlockSessions;
            FrozenSignatureLegacyCandidates =
                (frozenSignatureLegacyCandidates ?? Array.Empty<SignatureLegacyReadModel>()).ToArray();
            SelectedSignatureLegacy = selectedSignatureLegacy;
            LifeDetail = lifeDetail;
            TrainingOutlooks = (trainingOutlooks ?? Array.Empty<TrainingOutlookReadModel>()).ToArray();
        }

        public string CareerId { get; }
        public int LifeNumber { get; }
        public HighSchoolPhase Phase { get; }
        public string NextSeed { get; }
        public ulong CoreRevision { get; }
        public string PlayerId { get; }
        public string PlayerName { get; }
        public string PresetId { get; }
        public PitcherRatingsReadModel Ratings { get; }
        public CareerPerformanceReadModel Performance { get; }
        public string SchoolId { get; }
        public string SchoolName { get; }
        public int SchoolYear { get; }
        public int ChapterNumber { get; }
        public int RemainingImportantGames { get; }
        public int RemainingChapterAdvances { get; }
        public DraftReadModel Draft { get; }
        public string CoreStateJson { get; }
        public string PledgeId { get; }
        public bool PledgeDecided { get; }
        public IReadOnlyList<string> Karmas { get; }
        public IReadOnlyList<string> Awakenings { get; }
        public IReadOnlyList<CareerChoiceReadModel> SchoolChoices { get; }
        public IReadOnlyList<CareerChoiceReadModel> TrainingFocusChoices { get; }
        public IReadOnlyList<CareerChoiceReadModel> TrainingIntensityChoices { get; }
        public IReadOnlyList<CareerChoiceReadModel> RelationshipChoices { get; }
        public IReadOnlyList<CareerChoiceReadModel> AwakeningChoices { get; }
        public IReadOnlyList<CareerChoiceReadModel> LegacyMemoryChoices { get; }
        public int MemorySlots { get; }
        public TournamentBracketReadModel Tournament { get; }
        public IReadOnlyList<ProspectEntryReadModel> ProspectRankings { get; }
        public IReadOnlyList<CareerGameLineReadModel> GameLines { get; }
        /// <summary>
        /// Full high-school game log projection, including simulated team games. Nullable
        /// advanced-stat inputs remain unavailable when any source line did not record them.
        /// </summary>
        public PitchingRecordReadModel PitchingRecord =>
            PitchingRecordReadModel.FromGameLines(GameLines);
        public IReadOnlyList<CareerChoiceReadModel> SignatureLegacyChoices { get; }
        public string EquippedSignatureLegacyId { get; }
        public string SelectedSignatureLegacyId { get; }
        public string Difficulty { get; }
        public bool IsChallengeRun { get; }
        public LegacySelectionMode LegacySelectionMode { get; }
        /// <summary>
        /// Per-career receipt for the non-progression bullpen. The tutorial may be replayed, but
        /// this durable receipt is required before the prologue can advance.
        /// </summary>
        public bool TutorialCompleted { get; }
        public int TutorialAttemptCount { get; }
        public int PledgeRulesVersion { get; }
        public int LegacyRewardPermille { get; }
        public int RivalStrikeouts { get; }
        public int Fatigue { get; }
        public int ArmRisk { get; }
        public int InjuryRecovery { get; }
        public int ManagerTrust { get; }
        public int CatcherTrust { get; }
        public int RivalTrust { get; }
        public int FanInterest { get; }
        public int DraftForecastScore { get; }
        public ChapterProgressReadModel ChapterProgress { get; }
        public IReadOnlyList<CareerMilestoneReadModel> ScheduleMilestones { get; }
        public RelationshipEventReadModel CurrentRelationshipEvent { get; }
        public GameScenarioNarrativeReadModel CurrentGameScenario { get; }
        public TrainingResultReadModel LastTraining { get; }
        public RelationshipResultReadModel LastRelationship { get; }
        public IReadOnlyList<string> News { get; }
        public IReadOnlyList<CareerChoiceReadModel> TrainingPitchChoices { get; }
        public TrainingBlockResultReadModel LastTrainingBlock { get; }
        public int MaximumTrainingBlockSessions { get; }
        public IReadOnlyList<SignatureLegacyReadModel> FrozenSignatureLegacyCandidates { get; }
        public SignatureLegacyReadModel SelectedSignatureLegacy { get; }
        public HighSchoolLifeDetailReadModel LifeDetail { get; }
        public IReadOnlyList<TrainingOutlookReadModel> TrainingOutlooks { get; }
    }

    public sealed class StartHighSchoolCareerRequest
    {
        public StartHighSchoolCareerRequest(
            string seed,
            string presetId,
            string playerName,
            string region,
            int lifeNumber,
            IReadOnlyList<string> inheritedMemories = null,
            int inheritedSoul = 0,
            IReadOnlyList<string> karmas = null,
            string inheritedSoulDomain = null,
            IReadOnlyList<string> soulBoosts = null,
            string difficulty = "standard",
            string signatureLegacyId = null,
            int? challengeLifeNumber = null)
        {
            Seed = seed;
            PresetId = presetId;
            PlayerName = playerName;
            Region = region;
            LifeNumber = lifeNumber;
            InheritedMemories = (inheritedMemories ?? Array.Empty<string>()).ToArray();
            InheritedSoul = inheritedSoul;
            Karmas = (karmas ?? Array.Empty<string>()).ToArray();
            InheritedSoulDomain = inheritedSoulDomain;
            SoulBoosts = (soulBoosts ?? Array.Empty<string>()).ToArray();
            Difficulty = string.IsNullOrWhiteSpace(difficulty) ? "standard" : difficulty;
            SignatureLegacyId = signatureLegacyId;
            ChallengeLifeNumber = challengeLifeNumber;
        }

        public string Seed { get; }
        public string PresetId { get; }
        public string PlayerName { get; }
        public string Region { get; }
        public int LifeNumber { get; }
        public IReadOnlyList<string> InheritedMemories { get; }
        public int InheritedSoul { get; }
        public IReadOnlyList<string> Karmas { get; }
        public string InheritedSoulDomain { get; }
        public IReadOnlyList<string> SoulBoosts { get; }
        public string Difficulty { get; }
        public string SignatureLegacyId { get; }
        public int? ChallengeLifeNumber { get; }
        public bool IsChallenge => ChallengeLifeNumber.HasValue;
    }

    public sealed class HighSchoolAction
    {
        public HighSchoolAction(string kind, string value = null)
        {
            Kind = kind;
            Value = value;
        }

        public string Kind { get; }
        public string Value { get; }
    }

    public sealed class PitchGameReport
    {
        public PitchGameReport(
            string gameId,
            int pitches,
            int batters,
            int outs,
            int strikeouts,
            int walks,
            int hits,
            int runsAllowed,
            int sequenceMasteryCount = 0,
            int expectedDamage = 0,
            int actualDamage = 0,
            int recommendationAccepted = 0,
            int directDeliveryCount = 0,
            int deliveryScoreTotal = 0,
            int bestDeliveryScore = 0,
            int perfectDeliveryCount = 0,
            int rivalStrikeouts = 0,
            int abilityMomentCount = 0,
            IReadOnlyList<string> abilityMomentTypes = null,
            int? homeRuns = null)
        {
            GameId = gameId;
            Pitches = pitches;
            Batters = batters;
            Outs = outs;
            Strikeouts = strikeouts;
            Walks = walks;
            Hits = hits;
            RunsAllowed = runsAllowed;
            SequenceMasteryCount = sequenceMasteryCount;
            ExpectedDamage = expectedDamage;
            ActualDamage = actualDamage;
            RecommendationAccepted = recommendationAccepted;
            DirectDeliveryCount = directDeliveryCount;
            DeliveryScoreTotal = deliveryScoreTotal;
            BestDeliveryScore = bestDeliveryScore;
            PerfectDeliveryCount = perfectDeliveryCount;
            RivalStrikeouts = rivalStrikeouts;
            AbilityMomentCount = abilityMomentCount;
            AbilityMomentTypes = (abilityMomentTypes ?? Array.Empty<string>())
                .Distinct(StringComparer.Ordinal)
                .OrderBy(value => value, StringComparer.Ordinal)
                .ToArray();
            HomeRuns = homeRuns;
        }

        public string GameId { get; }
        public int Pitches { get; }
        public int Batters { get; }
        public int Outs { get; }
        public int Strikeouts { get; }
        public int Walks { get; }
        public int Hits { get; }
        public int RunsAllowed { get; }
        public int SequenceMasteryCount { get; }
        public int ExpectedDamage { get; }
        public int ActualDamage { get; }
        public int RecommendationAccepted { get; }
        public int DirectDeliveryCount { get; }
        public int DeliveryScoreTotal { get; }
        public int BestDeliveryScore { get; }
        public int PerfectDeliveryCount { get; }
        /// <summary>Strikeouts against the named high-school rival, supplied by the typed lineup report.</summary>
        public int RivalStrikeouts { get; }
        public int AbilityMomentCount { get; }
        public IReadOnlyList<string> AbilityMomentTypes { get; }
        /// <summary>Null means the pitch-session source did not classify home runs.</summary>
        public int? HomeRuns { get; }
        public int? AverageDeliveryScore => DirectDeliveryCount == 0
            ? (int?)null
            : DeliveryScoreTotal / DirectDeliveryCount;
    }

    /// <summary>
    /// Narrow boundary for the evolving Core high-school engine. Application tests use a fake;
    /// the production adapter can bind once the Core command surface is frozen.
    /// </summary>
    public interface IHighSchoolCareerPort
    {
        HighSchoolCareerReadModel Start(StartHighSchoolCareerRequest request);

        HighSchoolCareerReadModel Apply(
            HighSchoolCareerReadModel current,
            HighSchoolAction action);

        /// <summary>Consumes and advances the deterministic game seed before play is exposed.</summary>
        HighSchoolCareerReadModel ReservePitch(
            HighSchoolCareerReadModel current,
            string scenarioId);

        HighSchoolCareerReadModel ApplyPitchResult(
            HighSchoolCareerReadModel current,
            PitchGameReport report);
    }

    public interface IHighSchoolPitchScenarioPort
    {
        PitchScenarioReadModel CreatePitchScenario(
            HighSchoolCareerReadModel current,
            string requestedScenarioId);
    }

    public interface IHighSchoolTutorialScenarioPort
    {
        PitchScenarioReadModel CreateTutorialPitchScenario(
            HighSchoolCareerReadModel current,
            string requestedScenarioId);
    }
}
