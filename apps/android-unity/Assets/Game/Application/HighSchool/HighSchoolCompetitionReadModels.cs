using System;
using System.Collections.Generic;
using System.Linq;

namespace Baseball.Application.HighSchool
{
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
}
