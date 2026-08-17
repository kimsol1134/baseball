using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using Baseball.Application.HighSchool;
using Baseball.Application.Meta;
using Baseball.Application.Persistence;
using Baseball.Application.Pro;
using Baseball.Core.HighSchool;
using Baseball.Presentation.Common;
using Baseball.Presentation.Pitch;

namespace Baseball.Presentation.Shell
{
    public sealed partial class StoreBaseballCareerReadModel
    {

        private static void AddPlayerHeartline(
            IList<ScreenSectionViewModel> sections,
            ShellRoute route,
            HighSchoolCareerReadModel career)
        {
            PlayerHeartlineViewModel heartline = PlayerHeartlinePresentationPolicy.Project(route, career);
            if (heartline == null) return;
            sections.Insert(0, new ScreenSectionViewModel(
                "hs-player-heartline",
                "선수의 속마음",
                ScreenSectionTone.Milestone,
                new[]
                {
                    new ScreenRowViewModel(
                        "hs-player-heartline-" + heartline.BranchId,
                        heartline.Mood,
                        "“" + heartline.Words + "”")
                }));
        }

        private void AddHighSchoolNarrative(
            IList<ScreenSectionViewModel> sections,
            ShellRoute route,
            HighSchoolCareerReadModel career)
        {
            if (career == null) return;
            bool prologue = route == ShellRoute.Prologue &&
                career.Phase == HighSchoolPhase.Prologue;
            if (prologue || route == ShellRoute.HighSchoolOverview)
            {
                CareerWind wind = CareerWind.For(career.CareerId, CareerRulesVersion.V2);
                sections.Insert(0, new ScreenSectionViewModel(
                    "hs-career-wind",
                    "이번 3년의 바람",
                    ScreenSectionTone.Milestone,
                    new[]
                    {
                        new ScreenRowViewModel(
                            "hs-career-wind-copy",
                            wind.Title,
                            wind.Detail,
                            wind.EffectDescriptions.Count == 0
                                ? "능력과 선택으로 길을 만듭니다."
                                : string.Join(" · ", wind.EffectDescriptions))
                    }));
            }
            if (route == ShellRoute.HighSchoolOverview &&
                career.ChapterProgress != null)
            {
                ChapterProgressReadModel chapter = career.ChapterProgress;
                sections.Insert(0, new ScreenSectionViewModel(
                    "hs-overview-metrics",
                    "지금의 선수",
                    ScreenSectionTone.Plain,
                    new[]
                    {
                        new ScreenRowViewModel(
                            "hs-overview-fatigue",
                            "피로",
                            career.Fatigue.ToString()),
                        new ScreenRowViewModel(
                            "hs-overview-trust",
                            "감독 믿음",
                            career.ManagerTrust.ToString()),
                        new ScreenRowViewModel(
                            "hs-overview-training",
                            "이번 장 훈련",
                            chapter.TrainingsCompleted + "/" + chapter.TrainingsRequired)
                    }));
                sections.Add(new ScreenSectionViewModel(
                    "hs-chapter-progress",
                    chapter.Title,
                    ScreenSectionTone.Information,
                    new[]
                    {
                        new ScreenRowViewModel(
                            "hs-chapter-season",
                            chapter.SchoolYear + "학년 · " + chapter.Season,
                            chapter.Goal,
                            "훈련 " + chapter.TrainingsCompleted + "/" + chapter.TrainingsRequired +
                            " · 일정 " + chapter.MilestoneIndex + "/" + chapter.MilestoneCount),
                        new ScreenRowViewModel(
                            "hs-chapter-result",
                            "최근 장면",
                            string.IsNullOrWhiteSpace(chapter.ResultLine) ? "아직 기록된 결과가 없습니다." : chapter.ResultLine)
                    }));
            }

            if (route == ShellRoute.Relationship && career.CurrentRelationshipEvent != null)
            {
                RelationshipEventReadModel scene = career.CurrentRelationshipEvent;
                sections.Insert(0, new ScreenSectionViewModel(
                    "hs-relationship-scene",
                    scene.Title,
                    ScreenSectionTone.Milestone,
                    new[]
                    {
                        new ScreenRowViewModel(
                            "hs-relationship-category",
                            "장면 유형",
                            scene.Category),
                        new ScreenRowViewModel(
                            "hs-relationship-speaker",
                            string.IsNullOrWhiteSpace(scene.Speaker) ? "상대" : scene.Speaker,
                            string.IsNullOrWhiteSpace(scene.Quote) ? scene.Summary : "“" + scene.Quote + "”",
                            scene.Summary),
                        new ScreenRowViewModel(
                            "hs-relationship-trust",
                            "현재 관계",
                            RelationshipTrustTitle(scene.TrustBand))
                    }));
            }

            if (route == ShellRoute.ImportantGame && career.CurrentGameScenario != null)
            {
                GameScenarioNarrativeReadModel game = career.CurrentGameScenario;
                sections.Insert(0, new ScreenSectionViewModel(
                    "hs-important-game-scenario",
                    game.Title,
                    ScreenSectionTone.Warning,
                    new[]
                    {
                        new ScreenRowViewModel(
                            "hs-important-game-narrative",
                            "마운드 상황",
                            game.Narrative,
                            game.Inning + "회 · " + game.Outs + "아웃 · " + ScoreDifferentialTitle(game.ScoreDifferential)),
                        new ScreenRowViewModel(
                            "hs-important-game-leverage",
                            "승부 압박",
                            LeverageTitle(game.Leverage))
                    }));
            }

            if (route == ShellRoute.Training)
            {
                TrainingOutlookReadModel outlook = HighSchoolTrainingOutlookProjection.Resolve(
                    career,
                    _selectedChoice("training_focus"),
                    _selectedChoice("training_intensity"));
                if (outlook != null)
                {
                    sections.Insert(0, new ScreenSectionViewModel(
                        "hs-training-outlook",
                        "선택한 훈련 전망",
                        ScreenSectionTone.Information,
                        new[]
                        {
                            new ScreenRowViewModel(
                                "hs-training-outlook-value",
                                outlook.Title,
                                outlook.Summary,
                                "선택한 초점과 강도를 현재 능력·피로·재능에 적용한 전망입니다.")
                        }));
                }
            }

            if ((route == ShellRoute.Training || route == ShellRoute.HighSchoolOverview) &&
                career.LastTraining != null && career.LastTrainingBlock == null)
            {
                TrainingResultReadModel training = career.LastTraining;
                sections.Add(new ScreenSectionViewModel(
                    "hs-last-training",
                    "최근 훈련 결과",
                    training.Jackpot ? ScreenSectionTone.Milestone : ScreenSectionTone.Positive,
                    new[]
                    {
                        new ScreenRowViewModel(
                            "hs-last-training-line",
                            TrainingFocusTitle(training.Focus) + " · " + TrainingIntensityTitle(training.Intensity),
                            training.Feedback,
                            "성장 +" + Math.Max(0, training.Growth) + " · 피로 " + Signed(training.FatigueChange)),
                        new ScreenRowViewModel(
                            "hs-last-training-metric",
                            "능력 변화",
                            training.MetricBefore.HasValue && training.MetricAfter.HasValue
                                ? training.MetricBefore + " → " + training.MetricAfter
                                : "수치 변화 없음",
                            training.OpportunityHit ? "오늘의 성장 기회를 살렸습니다." : "기본 훈련 결과입니다.")
                    }.Concat(TrainingBloomRows(
                        "hs-last-training-bloom",
                        training.BloomedAbility,
                        training.BloomedGrade)).ToArray()));
            }

            if ((route == ShellRoute.Training || route == ShellRoute.HighSchoolOverview) &&
                career.LastTrainingBlock != null)
            {
                TrainingBlockResultReadModel block = career.LastTrainingBlock;
                var rows = block.Sessions.Select(session => new ScreenRowViewModel(
                    "hs-training-block-session-" + session.Number,
                    session.Number + "회 · " + TrainingFocusTitle(session.Focus) + " · " +
                        TrainingIntensityTitle(session.Intensity),
                    string.IsNullOrWhiteSpace(session.TargetPitch)
                        ? session.Feedback
                        : PitchTitle(session.TargetPitch) + " · " + session.Feedback,
                    "성장 +" + Math.Max(0, session.Growth) + " · 피로 " + Signed(session.FatigueChange)))
                    .ToList();
                rows.Add(new ScreenRowViewModel(
                    "hs-training-block-stop",
                    "연속 훈련 종료",
                    block.CompletedSessions + "/" + block.MaximumSessions + "회 완료",
                    TrainingBlockStopTitle(block.StopReason) + " · 총 성장 +" + Math.Max(0, block.Growth) +
                    " · 총 피로 " + Signed(block.FatigueChange)));
                rows.AddRange(TrainingBloomRows(
                    "hs-training-block-bloom",
                    block.BloomedAbility,
                    block.BloomedGrade));
                sections.Add(new ScreenSectionViewModel(
                    "hs-last-training-block",
                    "연속 훈련 결과",
                    block.Growth > 0 ? ScreenSectionTone.Positive : ScreenSectionTone.Information,
                    rows));
            }

            if ((route == ShellRoute.Relationship || route == ShellRoute.HighSchoolOverview) &&
                career.LastRelationship != null)
            {
                RelationshipResultReadModel relation = career.LastRelationship;
                sections.Add(new ScreenSectionViewModel(
                    "hs-last-relationship",
                    "최근 관계 결과",
                    relation.TrustAfter >= relation.TrustBefore ? ScreenSectionTone.Positive : ScreenSectionTone.Warning,
                    new[]
                    {
                        new ScreenRowViewModel(
                            "hs-last-relationship-line",
                            relation.Title,
                            relation.Feedback,
                            "믿음 " + relation.TrustBefore + " → " + relation.TrustAfter +
                            " · 피로 " + relation.FatigueBefore + " → " + relation.FatigueAfter),
                        new ScreenRowViewModel(
                            "hs-last-relationship-response",
                            "내 응답",
                            RelationshipResponseTitle(relation.Response),
                            "팬 관심 " + relation.FanInterestBefore + " → " + relation.FanInterestAfter)
                    }));
            }

            if (route == ShellRoute.HighSchoolOverview && career.News.Count > 0)
            {
                sections.Add(new ScreenSectionViewModel(
                    "hs-news",
                    "최근 소식",
                    ScreenSectionTone.Plain,
                    career.News.Take(8).Select((line, index) => new ScreenRowViewModel(
                        "hs-news-" + index,
                        (index + 1) + "번째 소식",
                        line)).ToArray()));
            }
        }

        private static void AddRunPledge(
            IList<ScreenSectionViewModel> sections,
            ShellRoute route,
            GameSaveAggregate state)
        {
            if (route != ShellRoute.HighSchoolOverview && route != ShellRoute.RunRecap) return;
            RunPledgeReadModel pledge = RunPledgeRules.Project(state).Selected;
            if (pledge == null) return;
            sections.Add(new ScreenSectionViewModel(
                "run-pledge",
                route == ShellRoute.RunRecap ? "고교 3년 목표 결과" : "고교 3년 목표",
                pledge.Progress.Achieved ? ScreenSectionTone.Positive : ScreenSectionTone.Milestone,
                new[]
                {
                    new ScreenRowViewModel(
                        "run-pledge-progress",
                        PledgeTierTitle(pledge.Tier) + " · " + pledge.Title,
                        pledge.Progress.Line,
                        "진행 " + pledge.Progress.Current + "/" + pledge.Progress.Target +
                        " · 달성 보너스 야구혼 +" + pledge.RewardPermille / 10 + "%"),
                    new ScreenRowViewModel(
                        "run-pledge-result",
                        route == ShellRoute.RunRecap ? "최종 결과" : "현재 상태",
                        pledge.Progress.Achieved ? "달성" : "도전 중",
                        pledge.AlignmentReason)
                }));
        }

        private static void AddNextRunIntent(
            IList<ScreenSectionViewModel> sections,
            ShellRoute route,
            GameSaveAggregate state)
        {
            if (route != ShellRoute.RunRecap || !HasCurrentLifeArchive(state)) return;
            NextRunIntentState suggestion = RunPledgeRules.SuggestedNextRunIntent(state.HighSchool);
            if (suggestion == null) return;
            bool saved = string.Equals(
                state.Meta.NextRunIntent?.PledgeId,
                suggestion.PledgeId,
                StringComparison.Ordinal);
            sections.Add(new ScreenSectionViewModel(
                "next-run-intent",
                "새 선수로 다시 도전",
                ScreenSectionTone.Milestone,
                new[]
                {
                    new ScreenRowViewModel(
                        "next-run-intent-pledge",
                        string.IsNullOrWhiteSpace(suggestion.PledgeTitle)
                            ? "추천 목표"
                            : suggestion.PledgeTitle,
                        saved ? "새 선수 목표로 저장됨" : "저장 전",
                        suggestion.Reason +
                        (suggestion.PledgeRewardPermille.HasValue
                            ? " · 달성 보너스 야구혼 +" + suggestion.PledgeRewardPermille.Value / 10 + "%"
                            : string.Empty))
                }));
        }

        private static IEnumerable<ScreenRowViewModel> TrainingBloomRows(
            string id,
            string ability,
            string grade)
        {
            if (string.IsNullOrWhiteSpace(ability) || string.IsNullOrWhiteSpace(grade))
                return Array.Empty<ScreenRowViewModel>();
            return new[]
            {
                new ScreenRowViewModel(
                    id,
                    "재능이 만개했습니다",
                    TalentAbilityTitle(ability) + " · " + grade.ToUpperInvariant() + "등급",
                    "훈련 결과에 저장된 재능 상한 성장입니다.")
            };
        }

        private static void AddHighSchoolCompetition(
            ICollection<ScreenSectionViewModel> sections,
            HighSchoolCareerReadModel career)
        {
            if (career == null) return;
            if (career.Tournament != null)
            {
                sections.Add(new ScreenSectionViewModel(
                    "hs-tournament",
                    career.Tournament.TournamentName,
                    ScreenSectionTone.Information,
                    new[]
                    {
                        new ScreenRowViewModel(
                            "hs-tournament-chapter",
                            "대회 장",
                            career.ChapterNumber.ToString()),
                        new ScreenRowViewModel("hs-tournament-round", "현재 라운드", career.Tournament.PlayerRound),
                        new ScreenRowViewModel(
                            "hs-tournament-schools",
                            "대진 학교",
                            string.Join(" · ", career.Tournament.Schools))
                    }));
            }
            if (career.ProspectRankings.Count > 0)
            {
                sections.Add(new ScreenSectionViewModel(
                    "hs-prospects",
                    "고교 유망주 순위",
                    ScreenSectionTone.Plain,
                    career.ProspectRankings.Select(entry => new ScreenRowViewModel(
                        "hs-prospect-" + entry.Rank,
                        entry.Rank + "위 · " + entry.Name,
                        entry.School,
                        entry.Tag + (entry.IsPlayer ? " · 내 선수" : string.Empty))).ToArray()));
            }
            if (career.GameLines.Count > 0)
            {
                sections.Add(new ScreenSectionViewModel(
                    "hs-game-lines",
                    "최근 경기",
                    ScreenSectionTone.Plain,
                    career.GameLines.Select((line, index) => GameLineRow("hs", line, index)).ToArray()));
            }
        }
    }
}
