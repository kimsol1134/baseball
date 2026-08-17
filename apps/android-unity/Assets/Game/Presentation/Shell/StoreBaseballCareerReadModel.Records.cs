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

        private static IReadOnlyList<ScreenSectionViewModel> RecordSections(GameSaveAggregate state)
        {
            var result = new List<ScreenSectionViewModel>();
            PitchReleaseMasteryState release = state.Meta?.PitchReleaseMastery;
            if (release != null && release.DirectPitches > 0)
            {
                int nextTarget = release.PersonalBest < 700 ? 700 :
                    release.PersonalBest < 800 ? 800 :
                    release.PersonalBest < 900 ? 900 :
                    release.PersonalBest < 950 ? 950 : 1000;
                result.Add(new ScreenSectionViewModel(
                    "records-release-mastery",
                    "직접 릴리스 숙련도",
                    ScreenSectionTone.Milestone,
                    new[]
                    {
                        new ScreenRowViewModel(
                            "records-release-personal-best",
                            "개인 최고",
                            release.PersonalBest + "점",
                            release.PersonalBest >= 1000
                                ? "최고 단계를 달성했습니다."
                                : "다음 목표 " + nextTarget + "점까지 " +
                                  (nextTarget - release.PersonalBest) + "점"),
                        new ScreenRowViewModel(
                            "records-release-lifetime",
                            "공식 경기 누적",
                            release.OfficialSessions + "경기 · 직접 투구 " +
                            release.DirectPitches + "구 · 평균 " + release.LifetimeAverage + "점",
                            "타이밍 " + release.LifetimeReleaseAverage +
                            " · 조준 " + release.LifetimeAimAverage)
                    }));
            }
            if (state.HighSchool != null)
            {
                CareerPerformanceReadModel performance = state.HighSchool.Performance ??
                    new CareerPerformanceReadModel();
                var rows = new List<ScreenRowViewModel>
                {
                    new ScreenRowViewModel(
                        "records-current-hs-ratings",
                        state.HighSchool.PlayerName + " · 현재 능력",
                        RatingLine(state.HighSchool.Ratings),
                        "팬 관심 " + state.HighSchool.FanInterest + " · 포수와의 호흡 " +
                        state.HighSchool.CatcherTrust + " · 지도자의 믿음 " + state.HighSchool.ManagerTrust),
                };
                bool highSchoolRecordAvailable = state.HighSchool.GameLines.Count > 0 ||
                    performance.ImportantGames == 0 && performance.Outs == 0 && performance.Pitches == 0;
                AddPitchingRecordRows(
                    rows,
                    "records-current-hs",
                    "고교 누적",
                    state.HighSchool.PitchingRecord,
                    highSchoolRecordAvailable,
                    "피로 " + state.HighSchool.Fatigue + " · 팔 위험 " + state.HighSchool.ArmRisk);
                if (state.HighSchool.News.Count > 0)
                    rows.Add(new ScreenRowViewModel(
                        "records-current-hs-news",
                        "최근 소식",
                        string.Join(" · ", state.HighSchool.News.Take(3))));
                HighSchoolLifeDetailReadModel activeDetail = state.HighSchool.LifeDetail;
                if (activeDetail != null &&
                    (!string.IsNullOrWhiteSpace(activeDetail.Personality) ||
                     !string.IsNullOrWhiteSpace(activeDetail.WindTitle)))
                    rows.Add(new ScreenRowViewModel(
                        "records-current-hs-identity",
                        "선수의 기질",
                        string.IsNullOrWhiteSpace(activeDetail.Personality)
                            ? state.HighSchool.PlayerName
                            : activeDetail.Personality,
                        string.IsNullOrWhiteSpace(activeDetail.WindTitle)
                            ? "선택과 경기에서 드러난 현재 모습입니다."
                            : "3년의 바람 · " + activeDetail.WindTitle));
                if (state.HighSchool.Awakenings.Count > 0)
                    rows.Add(new ScreenRowViewModel(
                        "records-current-hs-awakenings",
                        "현재 각성",
                        string.Join(" · ", state.HighSchool.Awakenings.Select(AwakeningArchiveTitle))));
                result.Add(new ScreenSectionViewModel(
                    "records-current-high-school",
                    "현재 고교 선수",
                    ScreenSectionTone.Information,
                    rows));
                if (state.HighSchool.ProspectRankings.Count > 0)
                    result.Add(new ScreenSectionViewModel(
                        "records-current-hs-prospects",
                        "현재 유망주 순위",
                        ScreenSectionTone.Plain,
                        state.HighSchool.ProspectRankings.Select(entry => new ScreenRowViewModel(
                            "records-current-hs-prospect-" + entry.Rank,
                            entry.Rank + "위 · " + entry.Name,
                            entry.School,
                            entry.Tag + (entry.IsPlayer ? " · 내 선수" : string.Empty))).ToArray()));
            }
            if (state.Pro != null)
            {
                var proRows = new List<ScreenRowViewModel>
                {
                    new ScreenRowViewModel(
                        "records-current-pro-ratings",
                        state.Pro.PlayerName + " · 현재 능력",
                        RatingLine(state.Pro.Ratings),
                        state.Pro.TeamName + " · " + state.Pro.Season + "시즌 " + state.Pro.Week + "주")
                };
                AddPitchingRecordRows(
                    proRows,
                    "records-current-pro",
                    "이번 시즌",
                    state.Pro.RecordBook?.CurrentSeason,
                    state.Pro.RecordBook?.CurrentSeason != null,
                    "지도자의 믿음 " + state.Pro.ManagerTrust + " · 포수와의 호흡 " +
                    state.Pro.CatcherTrust + " · 피로 " + state.Pro.Fatigue);
                result.Add(new ScreenSectionViewModel(
                    "records-current-pro",
                    "현재 프로 선수",
                    ScreenSectionTone.Information,
                    proRows));
                ProRecordBookReadModel recordBook = state.Pro.RecordBook;
                if (recordBook != null &&
                    (recordBook.AwardNames.Count > 0 || recordBook.Milestones.Count > 0 ||
                     recordBook.HallOfFameScore.HasValue))
                {
                    var achievementRows = new List<ScreenRowViewModel>();
                    if (recordBook.AwardNames.Count > 0)
                        achievementRows.Add(new ScreenRowViewModel(
                            "records-current-pro-awards",
                            "수상",
                            string.Join(" · ", recordBook.AwardNames)));
                    if (recordBook.Milestones.Count > 0)
                        achievementRows.Add(new ScreenRowViewModel(
                            "records-current-pro-milestones",
                            "이정표",
                            string.Join(" · ", recordBook.Milestones)));
                    if (recordBook.HallOfFameScore.HasValue)
                        achievementRows.Add(new ScreenRowViewModel(
                            "records-current-pro-hall-score",
                            "명예의 전당 점수",
                            recordBook.HallOfFameScore.Value.ToString(CultureInfo.InvariantCulture)));
                    result.Add(new ScreenSectionViewModel(
                        "records-current-pro-achievements",
                        "프로 성취",
                        ScreenSectionTone.Milestone,
                        achievementRows));
                }
                if (recordBook?.DecisionHistory?.Count > 0)
                    result.Add(new ScreenSectionViewModel(
                        "records-current-pro-decisions",
                        "커리어 선택 기록",
                        ScreenSectionTone.Plain,
                        recordBook.DecisionHistory.Select((decision, index) => new ScreenRowViewModel(
                            "records-current-pro-decision-" + index,
                            decision.Season + "시즌 " + decision.Week + "주 · " + decision.ChoiceTitle,
                            decision.EffectSummary,
                            ProDecisionDeltaLine(decision))).ToArray()));
                if (state.Pro.LeagueStandings.Count > 0)
                    result.Add(new ScreenSectionViewModel(
                        "records-current-pro-standings",
                        "현재 가상 프로 순위",
                        ScreenSectionTone.Plain,
                        state.Pro.LeagueStandings.Select(entry => new ScreenRowViewModel(
                            "records-current-pro-team-" + entry.Rank,
                            entry.Rank + "위 · " + entry.TeamName,
                            entry.Wins + "승 " + entry.Losses + "패 " + entry.Draws + "무",
                            (entry.Rank == 1
                                ? "선두"
                                : "선두와 " + entry.GamesBehind.ToString("0.0") + "경기 차") +
                            (entry.IsPlayerTeam ? " · 내 구단" : string.Empty))).ToArray()));
                if (state.Pro.LeaguePitchers.Count > 0)
                    result.Add(new ScreenSectionViewModel(
                        "records-current-pro-leaders",
                        "현재 투수 순위",
                        ScreenSectionTone.Plain,
                        state.Pro.LeaguePitchers.Select(entry => new ScreenRowViewModel(
                            "records-current-pro-pitcher-" + entry.Rank,
                            entry.Rank + "위 · " + entry.Name,
                            entry.TeamName + " · " + Innings(entry.InningsOuts) +
                            "이닝 · 탈삼진 " + entry.Strikeouts,
                            entry.Wins + "승 " + entry.Losses + "패 · 세이브 " + entry.Saves +
                            " · 볼넷 " + entry.Walks + " · 실점 " + entry.RunsAllowed +
                            " · " + AdvancedCompact(entry.PitchingRecord) +
                            (entry.IsPlayer ? " · 내 선수" : string.Empty))).ToArray()));
            }
            LifeArchiveRecord[] archive = (state.Meta?.LifeArchive ?? Array.Empty<LifeArchiveRecord>())
                .Where(record => record != null)
                .OrderByDescending(record => record.LifeNumber)
                .ToArray();
            if (archive.Length > 0)
            {
                int games = archive.Sum(record => record.HighSchoolPerformance?.ImportantGames ?? 0);
                int pitches = archive.Sum(record => record.Pitches ?? record.HighSchoolPerformance?.Pitches ?? 0);
                int outs = archive.Sum(record => record.Outs ?? record.HighSchoolPerformance?.Outs ?? 0);
                int highSchoolStrikeouts = archive.Sum(record =>
                    record.HighSchoolPerformance?.Strikeouts ?? 0);
                int proStrikeouts = archive.Sum(record => record.ProStrikeouts);
                int walks = archive.Sum(record => record.HighSchoolPerformance?.Walks ?? 0);
                int hits = archive.Sum(record => record.Hits ?? record.HighSchoolPerformance?.Hits ?? 0);
                int runs = archive.Sum(record => record.HighSchoolPerformance?.RunsAllowed ?? 0);
                result.Add(new ScreenSectionViewModel(
                    "records-archive-career",
                    "완주한 선수 통산",
                    ScreenSectionTone.Milestone,
                    new[]
                    {
                        new ScreenRowViewModel(
                            "records-archive-volume",
                            "등판과 이닝",
                            games + "경기 · " + Innings(outs) + "이닝 · " + pitches + "구",
                            archive.Length + "명 · 프로 " + archive.Sum(record => record.ProSeasons) + "시즌"),
                        new ScreenRowViewModel(
                            "records-archive-results",
                            "투구 결과",
                            "고교 탈삼진 " + highSchoolStrikeouts + " · 프로 탈삼진 " + proStrikeouts +
                            " · 볼넷 " + walks,
                            "고교 피안타 " + hits + " · 실점 " + runs + " · " +
                            PerNineLine(highSchoolStrikeouts, walks, runs, outs))
                    }));

                LifeArchiveRecord latest = archive[0];
                var latestRows = new List<ScreenRowViewModel>
                {
                    new ScreenRowViewModel(
                        "records-latest-life-summary",
                        latest.LifeNumber + "번째 선수 · " + latest.PlayerName,
                        (latest.SchoolName ?? "학교 기록 없음") + " · " +
                        (latest.Drafted ? "지명" : "미지명") + " · 평가 " + latest.DraftEvaluation,
                        "고교 탈삼진 " + (latest.HighSchoolPerformance?.Strikeouts ?? 0) +
                        " · 프로 탈삼진 " + latest.ProStrikeouts),
                };
                if (latest.FinalRatings != null)
                    latestRows.Add(new ScreenRowViewModel(
                        "records-latest-life-ratings",
                        "최종 능력",
                        RatingLine(latest.FinalRatings),
                        latest.HighSchoolDetail?.Talents?.Count > 0
                            ? string.Join(" · ", latest.HighSchoolDetail.Talents.Select(value =>
                                value.AbilityTitle + " " + value.GradeTitle))
                            : "저장된 네 능력의 최종 수치입니다."));
                if (latest.HighSchoolDetail != null)
                {
                    string[] story = latest.HighSchoolDetail.Chronicle
                        .Reverse()
                        .Take(3)
                        .Reverse()
                        .ToArray();
                    if (story.Length > 0)
                        latestRows.Add(new ScreenRowViewModel(
                            "records-latest-life-story",
                            "최근 연대기",
                            string.Join(" · ", story)));
                    if (latest.HighSchoolDetail.Nicknames.Count > 0 ||
                        !string.IsNullOrWhiteSpace(latest.HighSchoolDetail.Personality))
                        latestRows.Add(new ScreenRowViewModel(
                            "records-latest-life-identity",
                            "별명과 성격",
                            latest.HighSchoolDetail.Nicknames.Count > 0
                                ? string.Join(" · ", latest.HighSchoolDetail.Nicknames)
                                : latest.PlayerName,
                            string.IsNullOrWhiteSpace(latest.HighSchoolDetail.Personality)
                                ? "저장된 선수 이야기"
                                : latest.HighSchoolDetail.Personality));
                }
                if (latest.Awakenings.Count > 0)
                    latestRows.Add(new ScreenRowViewModel(
                        "records-latest-life-awakenings",
                        "각성",
                        string.Join(" · ", latest.Awakenings.Select(AwakeningArchiveTitle))));
                result.Add(new ScreenSectionViewModel(
                    "records-latest-life",
                    "최근 완주 기록",
                    ScreenSectionTone.Plain,
                    latestRows));

                result.Add(new ScreenSectionViewModel(
                    "records-life-log",
                    "회차 기록",
                    ScreenSectionTone.Plain,
                    archive.Select(record => new ScreenRowViewModel(
                        "records-life-" + record.LifeNumber,
                        record.LifeNumber + "번째 · " + record.PlayerName,
                        (record.HighSchoolPerformance?.ImportantGames ?? 0) + "경기 · " +
                        Innings(record.Outs ?? record.HighSchoolPerformance?.Outs ?? 0) + "이닝 · 탈삼진 " +
                        ((record.HighSchoolPerformance?.Strikeouts ?? 0) + record.ProStrikeouts),
                        record.PlayerLegacy?.Title ?? "이전 버전에서 보관한 선수 기록")).ToArray()));
            }
            if (state.HighSchool?.GameLines?.Count > 0)
                result.Add(new ScreenSectionViewModel("records-high-school", "고교 경기", ScreenSectionTone.Plain,
                    state.HighSchool.GameLines.Select((line, index) => GameLineRow("record-hs", line, index)).ToArray()));
            if (state.Pro?.RecordBook?.SeasonGameLinesAvailable == true)
                result.Add(new ScreenSectionViewModel(
                    "records-pro-games",
                    "프로 이번 시즌 전체 경기",
                    ScreenSectionTone.Plain,
                    state.Pro.RecordBook.SeasonGameLines.Count == 0
                        ? new[]
                        {
                            new ScreenRowViewModel(
                                "records-pro-games-empty",
                                "아직 등판 기록 없음",
                                "이번 시즌 첫 등판 뒤 경기 기록이 저장됩니다.")
                        }
                        : state.Pro.RecordBook.SeasonGameLines
                            .Select((line, index) => GameLineRow("record-pro", line, index))
                            .ToArray()));
            else if (state.Pro?.RecordBook != null)
                result.Add(new ScreenSectionViewModel(
                    "records-pro-games-unavailable",
                    "프로 경기 기록",
                    ScreenSectionTone.Information,
                    new[]
                    {
                        new ScreenRowViewModel(
                            "records-pro-games-unavailable-copy",
                            "전체 경기 기록을 불러올 수 없음",
                            "이전 저장에는 이번 시즌의 모든 경기선이 보관되지 않았습니다.")
                    }));
            if (state.Pro?.RecordBook?.CareerSeasons?.Count > 0)
                result.Add(new ScreenSectionViewModel("records-pro-seasons", "프로 시즌 기록", ScreenSectionTone.Milestone,
                    state.Pro.RecordBook.CareerSeasons.Select(line => new ScreenRowViewModel(
                        "record-season-" + line.Season,
                        line.Season + "시즌",
                        SeasonVolumeLine(line),
                        SeasonResultLine(line) + " · " + AdvancedCompact(line.PitchingRecord))).ToArray()));
            if (result.Count == 0 && state.Meta?.Weekly?.Program != null)
                result.AddRange(WeeklySections(state.Meta.Weekly));
            if (result.Count == 0)
                result.Add(EmptySection("records-empty", "경기 기록", "아직 저장된 경기 기록이 없습니다."));
            result.Insert(0, WeeklyRecordsEntrySection(state.Meta?.Weekly));
            return result;
        }

        private static ScreenSectionViewModel WeeklyRecordsEntrySection(WeeklyProgressState weekly)
        {
            WeeklyProgramState program = weekly?.Program;
            if (program == null)
            {
                return new ScreenSectionViewModel(
                    "records-weekly-note",
                    "주간 야구 노트",
                    ScreenSectionTone.Information,
                    new[]
                    {
                        new ScreenRowViewModel(
                            "records-weekly-note-open",
                            "이번 주 목표",
                            "노트를 열어 세 가지 과제를 확인하세요.",
                            "처음 열 때 현재 선수 생활에 맞는 주간 보드를 안전하게 저장합니다.")
                    });
            }

            string reward = program.Claimed
                ? "이번 주 도장을 이미 받았습니다."
                : program.RewardReady
                    ? "과제 두 개를 마쳐 도장 보상을 받을 수 있습니다."
                    : "과제 두 개를 마치면 도장 보상을 받을 수 있습니다.";
            return new ScreenSectionViewModel(
                "records-weekly-note",
                "주간 야구 노트",
                program.RewardReady ? ScreenSectionTone.Positive : ScreenSectionTone.Information,
                new[]
                {
                    new ScreenRowViewModel(
                        "records-weekly-note-progress",
                        program.WeekKey,
                        program.CompletedCount + "/" + program.Tasks.Count + "개 완료",
                        reward)
                });
        }

        private static string PerNineLine(int strikeouts, int walks, int runs, int outs)
        {
            if (outs <= 0) return "첫 아웃부터 비율 기록을 계산합니다.";
            double innings = outs / 3d;
            return "9이닝당 탈삼진 " + (strikeouts * 9d / innings).ToString("0.0") +
                " · 볼넷 " + (walks * 9d / innings).ToString("0.0") +
                " · 실점 " + (runs * 9d / innings).ToString("0.0");
        }

        private static void AddPitchingRecordRows(
            ICollection<ScreenRowViewModel> rows,
            string prefix,
            string heading,
            PitchingRecordReadModel record,
            bool available,
            string context)
        {
            if (!available || record == null)
            {
                rows.Add(new ScreenRowViewModel(
                    prefix + "-performance",
                    heading,
                    "상세 투구 기록을 불러올 수 없음",
                    "이전 저장에는 경기별 원자료가 모두 보관되지 않았습니다."));
                rows.Add(new ScreenRowViewModel(
                    prefix + "-advanced",
                    heading + " 고급 지표",
                    "계산 가능한 기록 없음",
                    context));
                return;
            }

            rows.Add(new ScreenRowViewModel(
                prefix + "-performance",
                heading,
                record.Games + "경기 · 선발 " + record.Starts + " · " + record.InningsText +
                "이닝 · " + NullableCount(record.Pitches, "투구"),
                "탈삼진 " + record.Strikeouts + " · 볼넷 " + record.Walks +
                " · 실점 " + record.RunsAllowed + " · " +
                NullableCount(record.Hits, "피안타") + " · " +
                NullableCount(record.HomeRuns, "피홈런")));
            rows.Add(new ScreenRowViewModel(
                prefix + "-decisions",
                "승패와 역할",
                record.Wins + "승 " + record.Losses + "패 · " + record.Saves + "세이브",
                record.QualityStarts.HasValue
                    ? "퀄리티 스타트 " + record.QualityStarts.Value
                    : "퀄리티 스타트는 이전 저장에서 집계되지 않았습니다."));
            rows.Add(new ScreenRowViewModel(
                prefix + "-advanced",
                heading + " 고급 지표",
                "9이닝당 실점 " + Metric(record.RunsPerNine) + " · WHIP " +
                Metric(record.Whip) + " · 탈삼진/볼넷 " + Metric(record.StrikeoutToWalk),
                "K/9 " + Metric(record.StrikeoutsPerNine) + " · BB/9 " +
                Metric(record.WalksPerNine) + " · H/9 " + Metric(record.HitsPerNine) +
                " · HR/9 " + Metric(record.HomeRunsPerNine) + " · FIP " +
                Metric(record.FieldingIndependentPitching) + " · 상대 타자 " +
                NullableCount(record.BattersFaced, string.Empty) + " · K% " +
                Percent(record.StrikeoutRate) + " · BABIP " + Babip(record.BattingAverageOnBallsInPlay) +
                ". " + context));
        }

        private static string NullableCount(int? value, string label) => value.HasValue
            ? (string.IsNullOrWhiteSpace(label)
                ? value.Value.ToString(CultureInfo.InvariantCulture)
                : label + " " + value.Value.ToString(CultureInfo.InvariantCulture))
            : (string.IsNullOrWhiteSpace(label) ? "기록 없음" : label + " 미기록");

        private static string Metric(double? value) => value.HasValue
            ? value.Value.ToString("0.00", CultureInfo.InvariantCulture)
            : "기록 없음";

        private static string Percent(double? value) => value.HasValue
            ? value.Value.ToString("0.0%", CultureInfo.InvariantCulture)
            : "기록 없음";

        private static string Babip(double? value) => value.HasValue
            ? value.Value.ToString("0.000", CultureInfo.InvariantCulture)
            : "기록 없음";

        private static IReadOnlyList<ScreenSectionViewModel> LeagueSections(GameSaveAggregate state)
        {
            var result = new List<ScreenSectionViewModel>();
            if (state.Pro?.LeagueStandings?.Count > 0)
                result.Add(new ScreenSectionViewModel("league-standings", "가상 프로 리그 순위", ScreenSectionTone.Plain,
                    state.Pro.LeagueStandings.Select(entry => new ScreenRowViewModel(
                        "league-team-" + entry.Rank,
                        entry.Rank + "위 · " + entry.TeamName,
                        entry.Wins + "승 " + entry.Losses + "패 " + entry.Draws + "무",
                        (entry.Rank == 1 ? "선두" : "선두와 " + entry.GamesBehind.ToString("0.0") + "경기 차") +
                            (entry.IsPlayerTeam ? " · 내 구단" : string.Empty))).ToArray()));
            if (state.Pro?.LeaguePitchers?.Count > 0)
                result.Add(new ScreenSectionViewModel("league-pitchers", "투수 순위", ScreenSectionTone.Plain,
                    state.Pro.LeaguePitchers.Select(entry => new ScreenRowViewModel(
                        "league-pitcher-" + entry.Rank,
                        entry.Rank + "위 · " + entry.Name,
                        entry.TeamName + " · " + Innings(entry.InningsOuts) + "이닝 · 탈삼진 " + entry.Strikeouts,
                        entry.Wins + "승 " + entry.Losses + "패 · 세이브 " + entry.Saves +
                            (entry.IsPlayer ? " · 내 선수" : string.Empty))).ToArray()));
            if (result.Count == 0 && state.HighSchool != null)
            {
                AddHighSchoolCompetition(result, state.HighSchool);
            }
            if (result.Count == 0)
                result.Add(EmptySection("league-empty", "리그 정보", "커리어를 시작하면 실제 대회와 순위가 여기에 표시됩니다."));
            return result;
        }

        private static IReadOnlyList<ScreenSectionViewModel> AchievementSections(AchievementProgressState progress)
        {
            progress = progress ?? AchievementProgressState.Empty;
            string[] ids =
            {
                AchievementIds.FirstDraft, AchievementIds.FirstStrikeout, AchievementIds.CleanInning,
                AchievementIds.PerfectDelivery, AchievementIds.MajorDebut, AchievementIds.HundredStrikeouts,
                AchievementIds.ThirdLife, AchievementIds.FifthLife, AchievementIds.TenthLife,
                AchievementIds.KarmaRun, AchievementIds.DoubleKarma, AchievementIds.AwakenedThrice,
                AchievementIds.FourSchools, AchievementIds.FiveDrafts, AchievementIds.HallOfFame,
            };
            return new[]
            {
                new ScreenSectionViewModel("achievement-list", "업적 목록", ScreenSectionTone.Milestone,
                    ids.Select((id, index) =>
                    {
                        bool unlocked = progress.Unlocked.Contains(id, StringComparer.Ordinal);
                        bool fresh = progress.Unacknowledged.Contains(id, StringComparer.Ordinal);
                        return new ScreenRowViewModel(
                            "achievement-" + index,
                            AchievementTitle(id),
                            unlocked ? fresh ? "새로 달성" : "달성" : "잠김",
                            AchievementCondition(id));
                    }).ToArray())
            };
        }

        private static IReadOnlyList<ScreenSectionViewModel> WeeklySections(WeeklyProgressState weekly)
        {
            var result = new List<ScreenSectionViewModel>();
            WeeklyProgramState program = weekly?.Program;
            if (program != null)
                result.Add(new ScreenSectionViewModel("weekly-tasks", "이번 주 세 가지 과제", ScreenSectionTone.Information,
                    program.Tasks.Select((task, index) => new ScreenRowViewModel(
                        "weekly-task-" + index,
                        WeeklyTaskTitle(task.Kind),
                        Math.Min(task.Progress, task.Target) + "/" + task.Target,
                        task.IsCompleted ? "완료" : "진행 중")).ToArray()));
            if (weekly?.Stamps?.Count > 0)
                result.Add(new ScreenSectionViewModel("weekly-stamps", "주간 스탬프", ScreenSectionTone.Positive,
                    weekly.Stamps.Select((stamp, index) => new ScreenRowViewModel(
                        "weekly-stamp-" + index,
                        stamp.WeekKey,
                        stamp.CompletedTaskCount + "개 완료",
                        stamp.Perfect ? "완벽한 한 주" : "보상 획득")).ToArray()));
            if (result.Count == 0)
                result.Add(EmptySection("weekly-empty", "이번 주", "주간 과제를 준비하는 중입니다. 잠시 후 다시 열어 주세요."));
            return result;
        }

        private static IReadOnlyList<ScreenSectionViewModel> SettingsSections(GameSaveAggregate state)
        {
            var result = new List<ScreenSectionViewModel>();
            int archivedLife = state.Meta.LifeArchive.Count == 0
                ? 0
                : state.Meta.LifeArchive.Max(value => value?.LifeNumber ?? 0);
            int currentLife = state.HighSchool?.LifeNumber ?? state.Meta.LifeNumber;
            int nextLife = Math.Max(Math.Max(currentLife, archivedLife), state.Meta.LifeNumber) + 1;
            string memories = state.Meta.InheritedMemories.Count == 0
                ? "상속된 기억 없음"
                : string.Join(" · ", state.Meta.InheritedMemories.Select(MemoryArchiveTitle));
            string signature = string.IsNullOrWhiteSpace(state.Meta.EquippedSignatureLegacyId)
                ? "장착한 대표 유산 없음"
                : state.Meta.LifeArchive
                    .Select(value => value?.SignatureLegacy)
                    .FirstOrDefault(value => value != null && string.Equals(
                        value.Id,
                        state.Meta.EquippedSignatureLegacyId,
                        StringComparison.Ordinal))?.Title ?? "보관된 대표 유산 장착 중";
            result.Add(new ScreenSectionViewModel(
                "settings-inheritance",
                "다음 선수와 계승",
                ScreenSectionTone.Information,
                new[]
                {
                    new ScreenRowViewModel(
                        "settings-next-player",
                        "다음 선수",
                        nextLife + "번째 야구 인생",
                        state.Meta.NextRunIntent == null
                            ? "다음 회차 목표는 결산 화면에서 정할 수 있습니다."
                            : (state.Meta.NextRunIntent.PledgeTitle ?? "저장된 다음 회차 목표") +
                              " · " + state.Meta.NextRunIntent.Reason),
                    new ScreenRowViewModel(
                        "settings-inherited-memories",
                        "상속 기억",
                        memories,
                        "저장된 기억은 새 선수 만들기에서 자동으로 적용됩니다."),
                    new ScreenRowViewModel(
                        "settings-signature-legacy",
                        "대표 유산",
                        signature,
                        "잠금 해제하고 장착한 대표 유산만 다음 선수에게 이어집니다."),
                    new ScreenRowViewModel(
                        "settings-soul",
                        "야구혼",
                        "보유 " + state.Meta.SoulBalance + " · 누적 " + state.Meta.SoulLifetimeEarned,
                        "다음 시작 자동 계승 " + state.Meta.AutomaticSoulEarned)
                }));

            var progress = new List<ScreenRowViewModel>();
            if (state.HighSchool != null)
            {
                progress.Add(new ScreenRowViewModel(
                    "settings-high-school-progress",
                    "고교 커리어",
                    state.HighSchool.SchoolYear + "학년 · " + HighSchoolPhaseName(state.HighSchool.Phase),
                    state.HighSchool.SchoolName ?? "학교 선택 전"));
            }
            if (state.Pro != null)
            {
                progress.Add(new ScreenRowViewModel(
                    "settings-pro-progress",
                    "프로 커리어",
                    state.Pro.Season + "시즌 " + state.Pro.Week + "주 · " + ProRoleName(state.Pro.Role),
                    (state.Pro.TeamName ?? "가상 구단") + " · " + (state.Pro.SeasonSegmentTitle ?? "현재 일정")));
            }
            if (progress.Count == 0)
                progress.Add(new ScreenRowViewModel(
                    "settings-career-empty",
                    "현재 커리어",
                    "새 선수 시작 전",
                    "선수 만들기에서 첫 야구 인생을 시작할 수 있습니다."));
            result.Add(new ScreenSectionViewModel(
                "settings-progress",
                "현재 진행",
                ScreenSectionTone.Plain,
                progress));

            CareerShareCode code = CareerShareCodePolicy.Project(state);
            result.Add(new ScreenSectionViewModel(
                "settings-share-code",
                "현재 판 공유 코드",
                ScreenSectionTone.Milestone,
                new[]
                {
                    new ScreenRowViewModel(
                        "settings-share-code-value",
                        code == null ? "공유할 판 없음" : code.Mode,
                        code?.Code ?? "커리어를 시작하면 코드가 만들어집니다.",
                        code == null
                            ? "선수 이름이나 익명 설치 식별자는 공유하지 않습니다."
                            : "이 코드에는 선수 이름이나 익명 설치 식별자가 들어가지 않습니다.")
                }));
            result.Add(new ScreenSectionViewModel(
                "settings-reset",
                "저장 데이터 초기화",
                ScreenSectionTone.Warning,
                new[]
                {
                    new ScreenRowViewModel(
                        "settings-reset-detail",
                        "모든 야구 인생과 설정 삭제",
                        "초기화는 되돌릴 수 없습니다.",
                        "저장 삭제와 새 익명 식별자 교체가 함께 성공할 때만 적용됩니다.")
                }));
            return result;
        }

        private static string HighSchoolPhaseName(HighSchoolPhase phase)
        {
            switch (phase)
            {
                case HighSchoolPhase.Prologue: return "프롤로그";
                case HighSchoolPhase.SchoolSelection: return "학교 선택";
                case HighSchoolPhase.Training: return "훈련";
                case HighSchoolPhase.Relationship: return "관계 이야기";
                case HighSchoolPhase.ImportantGame: return "중요 경기";
                case HighSchoolPhase.Awakening: return "각성";
                case HighSchoolPhase.ChapterReview: return "장 결산";
                case HighSchoolPhase.Draft: return "드래프트";
                case HighSchoolPhase.Completed: return "고교 3년 완료";
                case HighSchoolPhase.Legacy: return "대표 유산 선택";
                default: return "현재 일정";
            }
        }

        private static ScreenRowViewModel GameLineRow(string prefix, CareerGameLineReadModel line, int index) =>
            new ScreenRowViewModel(
                prefix + "-game-" + index,
                line.Season + "시즌 " + line.Week + "주 · " + (line.Started ? "선발" : "구원"),
                line.Played
                    ? Innings(line.Outs) + "이닝 · 탈삼진 " + line.Strikeouts + " · 실점 " + line.RunsAllowed
                    : "등판 없음",
                line.Played
                    ? "투구 " + line.Pitches + " · 볼넷 " + line.Walks + " · 피안타 " + line.Hits +
                        " · 팀 " + line.TeamRuns + ":" + line.OpponentRuns
                    : "이번 일정에는 등판하지 않았습니다.");

        private static ScreenSectionViewModel EmptySection(string id, string heading, string message) =>
            new ScreenSectionViewModel(id, heading, ScreenSectionTone.Information,
                new[] { new ScreenRowViewModel(id + "-message", "안내", message) });

        private static string Innings(int outs) => (outs / 3) + "." + Math.Abs(outs % 3);

        private static string AchievementTitle(string id)
        {
            switch (id)
            {
                case AchievementIds.FirstDraft: return "첫 지명";
                case AchievementIds.FirstStrikeout: return "첫 탈삼진";
                case AchievementIds.CleanInning: return "무실점 이닝";
                case AchievementIds.PerfectDelivery: return "완벽한 릴리스";
                case AchievementIds.MajorDebut: return "프로 데뷔";
                case AchievementIds.HundredStrikeouts: return "시즌 100탈삼진";
                case AchievementIds.ThirdLife: return "세 번째 인생";
                case AchievementIds.FifthLife: return "다섯 번째 인생";
                case AchievementIds.TenthLife: return "열 번째 인생";
                case AchievementIds.KarmaRun: return "성향을 품은 삶";
                case AchievementIds.DoubleKarma: return "두 성향의 균형";
                case AchievementIds.AwakenedThrice: return "세 번의 각성";
                case AchievementIds.FourSchools: return "네 학교의 기억";
                case AchievementIds.FiveDrafts: return "다섯 번의 지명";
                case AchievementIds.HallOfFame: return "전설의 투수";
                default: return "숨겨진 업적";
            }
        }

        private static string AchievementCondition(string id)
        {
            switch (id)
            {
                case AchievementIds.FirstDraft: return "처음으로 드래프트 지명을 받으세요.";
                case AchievementIds.FirstStrikeout: return "직접 경기에서 탈삼진을 기록하세요.";
                case AchievementIds.CleanInning: return "한 경기 구간을 무실점으로 막으세요.";
                case AchievementIds.PerfectDelivery: return "직접 릴리스와 코스를 모두 정확히 맞히세요.";
                case AchievementIds.MajorDebut: return "가상 프로 리그에서 첫 시즌을 시작하세요.";
                case AchievementIds.HundredStrikeouts: return "한 시즌 100탈삼진을 기록하세요.";
                case AchievementIds.ThirdLife: return "세 번째 야구 인생을 시작하세요.";
                case AchievementIds.FifthLife: return "다섯 번째 야구 인생을 시작하세요.";
                case AchievementIds.TenthLife: return "열 번째 야구 인생을 시작하세요.";
                case AchievementIds.KarmaRun: return "성향을 지닌 인생을 완주하세요.";
                case AchievementIds.DoubleKarma: return "두 가지 성향을 지닌 인생을 완주하세요.";
                case AchievementIds.AwakenedThrice: return "한 인생에서 세 번 각성하세요.";
                case AchievementIds.FourSchools: return "서로 다른 네 학교의 삶을 기록하세요.";
                case AchievementIds.FiveDrafts: return "다섯 번 드래프트 지명을 받으세요.";
                case AchievementIds.HallOfFame: return "명예 점수 70을 달성하세요.";
                default: return "커리어를 이어가며 조건을 찾아보세요.";
            }
        }

        private static string WeeklyTaskTitle(string kind)
        {
            switch (kind)
            {
                case WeeklyTaskKinds.PlayedOnTwoDays: return "서로 다른 이틀에 플레이";
                case WeeklyTaskKinds.ImportantGamesCompleted: return "중요 경기 완료";
                case WeeklyTaskKinds.ChaptersAdvanced: return "고교 이야기 전진";
                case WeeklyTaskKinds.NextRunStarted: return "다음 인생 시작";
                case WeeklyTaskKinds.PledgeSelected: return "이번 인생의 다짐 선택";
                case WeeklyTaskKinds.DifferentSchoolSelected: return "다른 학교 선택";
                case WeeklyTaskKinds.SequenceMasteryTriggered: return "수싸움 성장 발동";
                case WeeklyTaskKinds.ProWeeksAdvanced: return "프로 주간 일정 진행";
                default: return "주간 과제";
            }
        }

        private static string ProRoleName(string role)
        {
            switch ((role ?? string.Empty).ToLowerInvariant())
            {
                case "starter": return "선발 투수";
                case "reliever": return "구원 투수";
                case "closer": return "마무리 투수";
                default: return "투수진 경쟁";
            }
        }
    }
}
