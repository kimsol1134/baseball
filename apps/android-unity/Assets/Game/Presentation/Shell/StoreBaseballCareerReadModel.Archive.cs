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

        private static void AddLatestPlayerLegacy(
            IList<ScreenSectionViewModel> sections,
            ShellRoute route,
            GameSaveAggregate state)
        {
            IReadOnlyList<LifeArchiveRecord> archive = state?.Meta?.LifeArchive;
            if (archive == null || archive.Count == 0) return;
            LifeArchiveRecord record = route == ShellRoute.RunRecap
                ? CurrentLifeArchiveFor(state)
                : PreviousPlayerLegacyFor(route, state);
            if (record == null) return;
            sections.Insert(0, new ScreenSectionViewModel(
                "player-legacy-letter",
                route == ShellRoute.Prologue ? "이전 선수가 남긴 말" : "선수가 남긴 말",
                ScreenSectionTone.Milestone,
                new[] { PlayerLegacyRow("player-legacy-letter-copy", record) }));
        }

        public static LifeArchiveRecord PreviousPlayerLegacyFor(
            ShellRoute route,
            GameSaveAggregate state)
        {
            if (route != ShellRoute.Prologue || state?.HighSchool == null ||
                state.HighSchool.Phase != HighSchoolPhase.Prologue ||
                state.HighSchool.IsChallengeRun || state.Meta?.LifeArchive == null) return null;
            return state.Meta.LifeArchive
                .Where(value => value != null && value.LifeNumber < state.HighSchool.LifeNumber)
                .OrderByDescending(value => value.LifeNumber)
                .FirstOrDefault();
        }

        private static ScreenRowViewModel PlayerLegacyRow(string id, LifeArchiveRecord record)
        {
            PlayerLegacyState legacy = record.PlayerLegacy;
            if (legacy == null)
            {
                return new ScreenRowViewModel(
                    id,
                    "이전 버전의 선수 기록",
                    "이 회차에는 선수가 남긴 편지가 보관되지 않았습니다.",
                    "경기 기록과 성적은 인생 보관함에서 확인할 수 있습니다.");
            }
            return new ScreenRowViewModel(
                id,
                legacy.Title,
                legacy.DefiningMoment,
                "“" + legacy.Farewell + "”");
        }

        private static bool HasCompletedLife(GameSaveAggregate state) =>
            state?.Meta?.LifeArchive?.Count > 0;

        private LifeArchiveRecord SelectedLifeRecord(GameSaveAggregate state)
        {
            IReadOnlyList<LifeArchiveRecord> archive = state?.Meta?.LifeArchive;
            if (archive == null || archive.Count == 0) return null;
            string selected = _selectedChoice("archive_life");
            if (int.TryParse(selected, out int lifeNumber))
            {
                LifeArchiveRecord exact = archive.FirstOrDefault(value =>
                    value != null && value.LifeNumber == lifeNumber);
                if (exact != null) return exact;
            }
            return archive
                .Where(value => value != null)
                .OrderByDescending(value => value.LifeNumber)
                .FirstOrDefault();
        }

        private static IReadOnlyList<ScreenSectionViewModel> ArchiveSections(
            IReadOnlyList<LifeArchiveRecord> archive)
        {
            if (archive == null || archive.Count == 0)
                return new[] { EmptySection("archive-empty", "인생 기록", "아직 완주한 야구 인생이 없습니다.") };
            LifeArchiveRecord[] ordered = archive
                .OrderByDescending(value => value.LifeNumber)
                .ToArray();
            int strikeouts = ordered.Sum(record =>
                (record.HighSchoolPerformance?.Strikeouts ?? 0) + record.ProStrikeouts);
            int nicknameCount = ordered
                .SelectMany(record => record.HighSchoolDetail?.Nicknames ?? Array.Empty<string>())
                .Distinct(StringComparer.Ordinal)
                .Count();
            var sections = new List<ScreenSectionViewModel>
            {
                new ScreenSectionViewModel(
                    "archive-overview",
                    "지금까지 키운 선수 " + ordered.Length + "명",
                    ScreenSectionTone.Milestone,
                    new[]
                    {
                        new ScreenRowViewModel(
                            "archive-career-totals",
                            "지난 선수 통산",
                            "지명 " + ordered.Count(record => record.Drafted) + "/" + ordered.Length +
                            " · 통산 탈삼진 " + strikeouts,
                            "최고 평가 " + ordered.Max(record => record.DraftEvaluation) +
                            " · 모은 야구혼 " + ordered.Sum(record => record.SoulEarned)),
                        new ScreenRowViewModel(
                            "archive-nickname-collection",
                            "별명 도감",
                            nicknameCount + "개 수집",
                            nicknameCount == 0
                                ? "완주한 선수의 별명이 생기면 이곳에 쌓입니다."
                                : "모든 선수의 별명과 기록은 회차별 상세에 보존됩니다.")
                    })
            };
            sections.AddRange(ordered.Select(ArchiveLifeSection));
            return sections;
        }

        private static IReadOnlyList<ScreenSectionViewModel> LifeCardSections(LifeArchiveRecord record)
        {
            if (record == null)
            {
                return new[]
                {
                    EmptySection(
                        "life-card-empty",
                        "선수 카드",
                        "완주한 회차를 인생 보관함에서 고르면 공유 카드를 만들 수 있습니다.")
                };
            }

            HighSchoolLifeDetailReadModel detail = record.HighSchoolDetail;
            CareerPerformanceReadModel performance = record.HighSchoolPerformance;
            var sections = new List<ScreenSectionViewModel>
            {
                new ScreenSectionViewModel(
                    "life-card-identity",
                    record.LifeNumber + "번째 선수",
                    ScreenSectionTone.Milestone,
                    new[]
                    {
                        new ScreenRowViewModel(
                            "life-card-player",
                            record.PlayerName,
                            (string.IsNullOrWhiteSpace(record.SchoolName) ? "학교 기록 없음" : record.SchoolName) +
                            (string.IsNullOrWhiteSpace(detail?.Personality)
                                ? string.Empty
                                : " · 성향 " + detail.Personality),
                            string.IsNullOrWhiteSpace(detail?.WindTitle)
                                ? "3년의 바람 기록 없음"
                                : "바람 · " + detail.WindTitle),
                        new ScreenRowViewModel(
                            "life-card-draft",
                            record.Drafted
                                ? (string.IsNullOrWhiteSpace(record.DraftTeamName)
                                    ? "지명 구단 기록 없음"
                                    : record.DraftTeamName + " 지명")
                                : "드래프트 미지명",
                            "스카우트 평가 " + record.DraftEvaluation + "점",
                            record.ProSeasons > 0
                                ? "프로 " + record.ProSeasons + "시즌 · 탈삼진 " + record.ProStrikeouts +
                                  " · 수상 " + record.ProAwards
                                : "고교 커리어 기록")
                    })
            };

            PitcherRatingsReadModel start = detail?.StartingRatings;
            PitcherRatingsReadModel final = record.FinalRatings;
            if (start != null && final != null)
            {
                sections.Add(new ScreenSectionViewModel(
                    "life-card-growth",
                    "3년 동안 키운 것",
                    ScreenSectionTone.Positive,
                    new[]
                    {
                        GrowthRow("life-card-rating-stuff", "구위", start.Stuff, final.Stuff),
                        GrowthRow("life-card-rating-command", "제구", start.Command, final.Command),
                        GrowthRow("life-card-rating-movement", "변화", start.Movement, final.Movement),
                        GrowthRow("life-card-rating-stamina", "체력", start.Stamina, final.Stamina),
                        new ScreenRowViewModel(
                            "life-card-rating-total",
                            "능력 총합",
                            start.Total + " → " + final.Total,
                            GrowthDelta(final.Total - start.Total))
                    }));
            }
            else
            {
                sections.Add(EmptySection(
                    "life-card-growth-unavailable",
                    "3년 동안 키운 것",
                    "이전 버전의 회차라 시작·최종 능력 기록이 없습니다."));
            }

            var pitchingRows = new List<ScreenRowViewModel>
            {
                new ScreenRowViewModel(
                    "life-card-record-counts",
                    "직접 등판 기록",
                    performance.ImportantGames + "경기 · 탈삼진 " + performance.Strikeouts +
                    " · 볼넷 " + performance.Walks + " · 실점 " + performance.RunsAllowed,
                    record.Hits.HasValue
                        ? "피안타 " + record.Hits.Value
                        : "이전 버전의 회차라 피안타 기록이 없습니다."),
                new ScreenRowViewModel(
                    "life-card-record-workload",
                    "이닝과 투구 수",
                    record.Outs.HasValue ? Innings(record.Outs.Value) + "이닝" : "이닝 기록 없음",
                    record.Pitches.HasValue ? record.Pitches.Value + "구" : "투구 수 기록 없음")
            };
            if (record.Outs.HasValue && record.Outs.Value > 0)
            {
                double innings = record.Outs.Value / 3d;
                string whip = record.Hits.HasValue
                    ? ((record.Hits.Value + performance.Walks) / innings)
                        .ToString("0.00", CultureInfo.InvariantCulture)
                    : "기록 없음";
                pitchingRows.Add(new ScreenRowViewModel(
                    "life-card-record-rates",
                    "세부 지표",
                    "방어율 " + (performance.RunsAllowed * 9d / innings)
                        .ToString("0.00", CultureInfo.InvariantCulture) +
                    " · WHIP " + whip,
                    "K/9 " + (performance.Strikeouts * 9d / innings)
                        .ToString("0.0", CultureInfo.InvariantCulture)));
            }
            else
            {
                pitchingRows.Add(new ScreenRowViewModel(
                    "life-card-record-rates-unavailable",
                    "세부 지표",
                    "기록 없음",
                    "이전 버전의 회차는 이닝 기록이 없어 방어율·WHIP·K/9을 계산하지 않습니다."));
            }
            sections.Add(new ScreenSectionViewModel(
                "life-card-record",
                "3년 성적",
                ScreenSectionTone.Plain,
                pitchingRows));

            var storyRows = new List<ScreenRowViewModel>();
            if (detail?.Nicknames?.Count > 0)
                storyRows.Add(new ScreenRowViewModel(
                    "life-card-nicknames",
                    "세상이 부른 이름",
                    string.Join(" · ", detail.Nicknames.Select(value => "'" + value + "'"))));
            if (record.SignatureLegacy != null)
                storyRows.Add(new ScreenRowViewModel(
                    "life-card-signature",
                    "대표 유산 · " + record.SignatureLegacy.Title,
                    record.SignatureLegacy.Detail,
                    record.SignatureLegacy.EvidenceSummary));
            string[] people = LifeCardPeople(detail);
            if (people.Length > 0)
                storyRows.Add(new ScreenRowViewModel(
                    "life-card-people",
                    "함께한 사람들",
                    string.Join(" · ", people)));
            string[] chronicle = LifeCardChronicle(detail?.Chronicle);
            if (chronicle.Length > 0)
                storyRows.Add(new ScreenRowViewModel(
                    "life-card-chronicle",
                    "선수의 연대기",
                    string.Join("\n", chronicle)));
            string challengeCode = LifeCardShareCopy.ChallengeCode(record);
            if (!string.IsNullOrWhiteSpace(challengeCode))
                storyRows.Add(new ScreenRowViewModel(
                    "life-card-challenge",
                    "같은 판에 도전",
                    challengeCode,
                    "설정 화면에서 이 코드를 입력하면 같은 시드와 회차로 기록 없는 도전을 시작합니다."));
            if (storyRows.Count == 0)
                storyRows.Add(new ScreenRowViewModel(
                    "life-card-story-unavailable",
                    "선수 이야기",
                    "기록 없음",
                    "이전 버전에서 완주한 회차라 이야기 기록이 보관되지 않았습니다."));
            sections.Add(new ScreenSectionViewModel(
                "life-card-story",
                "이 선수가 남긴 것",
                ScreenSectionTone.Information,
                storyRows));
            return sections;
        }

        private static IReadOnlyList<ScreenSectionViewModel> RunRecapSections(
            GameSaveAggregate state,
            LifeArchiveRecord record)
        {
            CareerPerformanceReadModel performance = record.HighSchoolPerformance;
            HighSchoolLifeDetailReadModel detail = record.HighSchoolDetail;
            var stamps = new List<ScreenRowViewModel>
            {
                new ScreenRowViewModel(
                    "recap-draft-stamp",
                    record.Drafted
                        ? (string.IsNullOrWhiteSpace(record.DraftTeamName)
                            ? "지명 구단 기록 없음"
                            : record.DraftTeamName + " 지명")
                        : "드래프트 미지명",
                    "스카우트 평가 " + record.DraftEvaluation + "점"),
                new ScreenRowViewModel(
                    "recap-game-stamp",
                    performance.ImportantGames + "등판 · 탈삼진 " + performance.Strikeouts,
                    "볼넷 " + performance.Walks + " · 실점 " + performance.RunsAllowed)
            };
            if (detail?.Nicknames?.Count > 0)
                stamps.Add(new ScreenRowViewModel(
                    "recap-nickname-stamp",
                    "세상이 부른 이름",
                    "'" + detail.Nicknames.Last() + "'"));
            if (!string.IsNullOrWhiteSpace(record.PledgeTitle))
                stamps.Add(new ScreenRowViewModel(
                    "recap-pledge-stamp",
                    record.PledgeAchieved == true ? "목표 달성" : "목표 미완",
                    record.PledgeTitle,
                    (record.PledgeProgressLine ?? "저장된 진행 기록") +
                    " · 보상 야구혼 +" + (record.PledgeRewardPermille ?? 0) / 10 + "%"));
            if (!string.IsNullOrWhiteSpace(detail?.RivalName))
                stamps.Add(new ScreenRowViewModel(
                    "recap-rival-stamp",
                    "숙적과 남긴 기록",
                    detail.RivalName,
                    "이 회차의 관계와 승부 기록에 함께 남았습니다."));

            var result = new List<ScreenSectionViewModel>
            {
                new ScreenSectionViewModel(
                    "recap-stamps",
                    record.PlayerName + "의 3년",
                    ScreenSectionTone.Milestone,
                    stamps)
            };

            PitcherRatingsReadModel start = detail?.StartingRatings;
            PitcherRatingsReadModel final = record.FinalRatings;
            if (start != null && final != null)
            {
                result.Add(new ScreenSectionViewModel(
                    "recap-growth",
                    "3년 동안 키운 것",
                    ScreenSectionTone.Positive,
                    new[]
                    {
                        GrowthRow("recap-rating-stuff", "구위", start.Stuff, final.Stuff),
                        GrowthRow("recap-rating-command", "제구", start.Command, final.Command),
                        GrowthRow("recap-rating-movement", "변화", start.Movement, final.Movement),
                        GrowthRow("recap-rating-stamina", "체력", start.Stamina, final.Stamina),
                    }));
            }
            else
            {
                result.Add(EmptySection(
                    "recap-growth-unavailable",
                    "3년 동안 키운 것",
                    "이전 버전의 회차라 시작·최종 능력 기록이 없습니다."));
            }

            if (record.SignatureLegacy != null)
            {
                result.Add(new ScreenSectionViewModel(
                    "recap-signature",
                    "새 선수에게 이어진 대표 유산",
                    ScreenSectionTone.Milestone,
                    new[]
                    {
                        new ScreenRowViewModel(
                            "recap-signature-selected",
                            record.SignatureLegacy.Title,
                            record.SignatureLegacy.Detail,
                            record.SignatureLegacy.EvidenceSummary),
                        new ScreenRowViewModel(
                            "recap-signature-candidates",
                            "함께 발견한 후보",
                            record.SignatureLegacyCandidates.Count == 0
                                ? "후보 기록 없음"
                                : string.Join(" · ", record.SignatureLegacyCandidates.Select(value => value.Title)),
                            "결산 당시 제시된 후보를 그대로 보관했습니다.")
                    }));
            }

            result.Add(new ScreenSectionViewModel(
                "recap-soul",
                "계승 포인트",
                ScreenSectionTone.Milestone,
                new[]
                {
                    new ScreenRowViewModel(
                        "recap-soul-earned",
                        "이번 선수 적립",
                        "+" + record.SoulEarned + "P",
                        "현재 잔액 " + state.Meta.SoulBalance + "P"),
                    new ScreenRowViewModel(
                        "recap-soul-automatic",
                        "자동 계승 총량",
                        state.Meta.AutomaticSoulEarned + "P",
                        state.Meta.AutomaticSoulEarned > 0
                            ? "새 선수 설정에서 계승 영역과 보너스를 고를 수 있습니다."
                            : "이번 저장에는 자동 계승 포인트가 없습니다.")
                }));

            NextRunIntentState intent = record.SuggestedNextRunIntent ?? state.Meta.NextRunIntent;
            if (intent != null)
            {
                result.Add(new ScreenSectionViewModel(
                    "recap-next-intent",
                    "새 선수로 다시 도전",
                    ScreenSectionTone.Information,
                    new[]
                    {
                        new ScreenRowViewModel(
                            "recap-next-intent-value",
                            string.IsNullOrWhiteSpace(intent.PledgeTitle) ? "추천 목표" : intent.PledgeTitle,
                            intent.Reason,
                            intent.PledgeRewardPermille.HasValue
                                ? "달성 보너스 야구혼 +" + intent.PledgeRewardPermille.Value / 10 + "%"
                                : "저장된 다음 회차 목표")
                    }));
            }
            return result;
        }

        private static ScreenRowViewModel GrowthRow(string id, string title, int start, int final)
        {
            return new ScreenRowViewModel(
                id,
                title,
                start + " → " + final,
                GrowthDelta(final - start));
        }

        private static string GrowthDelta(int delta) =>
            delta > 0 ? "+" + delta : delta == 0 ? "변화 없음" : delta.ToString();

        private static string[] LifeCardPeople(HighSchoolLifeDetailReadModel detail)
        {
            if (detail == null) return Array.Empty<string>();
            return new[]
                {
                    string.IsNullOrWhiteSpace(detail.CoachName) ? null : detail.CoachName + " 감독",
                    string.IsNullOrWhiteSpace(detail.CatcherName) ? null : detail.CatcherName + " 포수",
                    string.IsNullOrWhiteSpace(detail.RivalName) ? null : "숙적 " + detail.RivalName,
                }
                .Where(value => value != null)
                .ToArray();
        }

        private static string[] LifeCardChronicle(IReadOnlyList<string> chronicle)
        {
            if (chronicle == null || chronicle.Count == 0) return Array.Empty<string>();
            if (chronicle.Count <= 5) return chronicle.ToArray();
            return new[] { chronicle[0] }
                .Concat(chronicle.Skip(Math.Max(1, chronicle.Count - 4)))
                .ToArray();
        }

        private static ScreenSectionViewModel ArchiveLifeSection(LifeArchiveRecord record)
        {
            var rows = new List<ScreenRowViewModel>
            {
                new ScreenRowViewModel(
                    "archive-life-summary-" + record.LifeNumber,
                    record.LifeNumber + "번째 선수 · " + record.PlayerName,
                    (record.SchoolName ?? "학교 미정") + " · " +
                    (record.Drafted ? "지명" : "미지명") + " · 프로 " + record.ProSeasons + "시즌",
                    "고교 탈삼진 " + (record.HighSchoolPerformance?.Strikeouts ?? 0) +
                    " · 프로 탈삼진 " + record.ProStrikeouts + " · 야구혼 +" + record.SoulEarned)
            };

            HighSchoolLifeDetailReadModel detail = record.HighSchoolDetail;
            if (record.PlayerLegacy != null)
                rows.Add(PlayerLegacyRow("archive-player-legacy-" + record.LifeNumber, record));
            if (detail?.Chronicle?.Count > 0)
            {
                rows.AddRange(detail.Chronicle
                    .Select((line, index) => new ScreenRowViewModel(
                        "archive-chronicle-" + record.LifeNumber + "-" + index,
                        "연대기 " + (index + 1),
                        line)));
            }
            if (detail?.Nicknames?.Count > 0)
                rows.Add(new ScreenRowViewModel(
                    "archive-nicknames-" + record.LifeNumber,
                    "세상이 부른 이름",
                    string.Join(" · ", detail.Nicknames)));
            if (detail != null)
            {
                if (!string.IsNullOrWhiteSpace(detail.PresetTitle) ||
                    !string.IsNullOrWhiteSpace(detail.DifficultyTitle))
                {
                    string preset = string.IsNullOrWhiteSpace(detail.PresetTitle)
                        ? "기존 저장의 투수 유형"
                        : detail.PresetTitle;
                    string difficulty = string.IsNullOrWhiteSpace(detail.DifficultyTitle)
                        ? "기본 난이도"
                        : detail.DifficultyTitle;
                    rows.Add(new ScreenRowViewModel(
                        "archive-origin-" + record.LifeNumber,
                        "선수의 시작",
                        preset + " · " + difficulty,
                        string.IsNullOrWhiteSpace(record.DraftTeamName)
                            ? "드래프트 구단 기록 없음"
                            : "지명 구단 · " + record.DraftTeamName));
                }
                if (detail.Talents?.Count > 0)
                    rows.Add(new ScreenRowViewModel(
                        "archive-talents-" + record.LifeNumber,
                        "처음 발견한 재능",
                        string.Join(" · ", detail.Talents.Select(value =>
                            value.AbilityTitle + " " + value.GradeTitle))));
                var people = new[] { detail.CoachName, detail.CatcherName, detail.RivalName }
                    .Where(value => !string.IsNullOrWhiteSpace(value))
                    .ToArray();
                if (people.Length > 0)
                    rows.Add(new ScreenRowViewModel(
                        "archive-people-" + record.LifeNumber,
                        "함께한 사람들",
                        string.Join(" · ", people),
                        string.IsNullOrWhiteSpace(detail.Personality)
                            ? "선택과 관계가 이 선수의 이야기를 만들었습니다."
                            : "성향 · " + detail.Personality));
                RelationshipResponseTallyReadModel tally = detail.ResponseTally;
                if (tally != null && tally.Listen + tally.Explain + tally.Challenge > 0)
                    rows.Add(new ScreenRowViewModel(
                        "archive-relationship-choices-" + record.LifeNumber,
                        "관계에서 고른 답",
                        "먼저 듣기 " + tally.Listen + " · 설명하기 " + tally.Explain +
                        " · 결과로 답하기 " + tally.Challenge));
                if (!string.IsNullOrWhiteSpace(detail.WindTitle))
                    rows.Add(new ScreenRowViewModel(
                        "archive-wind-" + record.LifeNumber,
                        "3년의 바람",
                        detail.WindTitle,
                        string.IsNullOrWhiteSpace(detail.SchoolStrength)
                            ? "학교와 선수의 선택이 남긴 방향입니다."
                            : "학교 강점 · " + detail.SchoolStrength));
            }
            if (record.SignatureLegacy != null)
            {
                rows.Add(new ScreenRowViewModel(
                    "archive-signature-" + record.LifeNumber,
                    "대표 유산 · " + record.SignatureLegacy.Title,
                    record.SignatureLegacy.Detail,
                    record.SignatureLegacy.EvidenceSummary));
                string[] others = record.SignatureLegacyCandidates
                    .Where(value => value != null && !string.Equals(
                        value.Id,
                        record.SignatureLegacy.Id,
                        StringComparison.Ordinal))
                    .Select(value => value.Title)
                    .ToArray();
                if (others.Length > 0)
                    rows.Add(new ScreenRowViewModel(
                        "archive-signature-candidates-" + record.LifeNumber,
                        "함께 발견한 유산",
                        string.Join(" · ", others),
                        "결산 당시 제시된 세 후보를 그대로 보관했습니다."));
            }
            if (!string.IsNullOrWhiteSpace(record.PledgeTitle))
                rows.Add(new ScreenRowViewModel(
                    "archive-pledge-" + record.LifeNumber,
                    "고교 3년 목표 · " + record.PledgeTitle,
                    record.PledgeAchieved == true ? "달성" : "미달성",
                    (record.PledgeProgressLine ?? "저장된 진행 기록") +
                    " · 보상 야구혼 +" + (record.PledgeRewardPermille ?? 0) / 10 + "%"));

            PitcherRatingsReadModel start = detail?.StartingRatings;
            PitcherRatingsReadModel final = record.FinalRatings;
            if (start != null && final != null)
                rows.Add(new ScreenRowViewModel(
                    "archive-ratings-" + record.LifeNumber,
                    "시작 능력 → 최종 능력",
                    RatingLine(start) + " → " + RatingLine(final)));
            rows.Add(new ScreenRowViewModel(
                "archive-pitching-" + record.LifeNumber,
                "투구와 성적",
                (record.HighSchoolPerformance?.ImportantGames ?? 0) + "경기 · " +
                (record.Pitches ?? record.HighSchoolPerformance?.Pitches ?? 0) + "구 · " +
                (record.Outs ?? record.HighSchoolPerformance?.Outs ?? 0) + "아웃",
                "볼넷 " + (record.HighSchoolPerformance?.Walks ?? 0) + " · 피안타 " +
                (record.Hits ?? record.HighSchoolPerformance?.Hits ?? 0) + " · 실점 " +
                (record.HighSchoolPerformance?.RunsAllowed ?? 0)));

            AddArchivedChoiceRow(rows, "archive-awakenings-" + record.LifeNumber, "각성", record.Awakenings, AwakeningArchiveTitle);
            AddArchivedChoiceRow(rows, "archive-karmas-" + record.LifeNumber, "성향", record.Karmas, KarmaArchiveTitle);
            AddArchivedChoiceRow(rows, "archive-memories-" + record.LifeNumber, "가져간 기억", record.Memories, MemoryArchiveTitle);
            return new ScreenSectionViewModel(
                "archive-life-" + record.LifeNumber,
                record.LifeNumber + "번째 선수 · " + record.PlayerName,
                ScreenSectionTone.Plain,
                rows);
        }

        private static void AddArchivedChoiceRow(
            ICollection<ScreenRowViewModel> rows,
            string id,
            string label,
            IReadOnlyList<string> values,
            Func<string, string> title)
        {
            if (values == null || values.Count == 0) return;
            rows.Add(new ScreenRowViewModel(id, label, string.Join(" · ", values.Select(title))));
        }

        private static string RatingLine(PitcherRatingsReadModel value) =>
            "구위 " + value.Stuff + " · 제구 " + value.Command + " · 변화 " + value.Movement +
            " · 체력 " + value.Stamina;

        private static string KarmaArchiveTitle(string value)
        {
            switch (NormalizeArchiveId(value))
            {
                case "unknownland": return "낯선 지역";
                case "stubborncoach": return "완고한 지도";
                case "singleweapon": return "한 가지 무기";
                case "geniusgeneration": return "천재 세대";
                case "erasedmemory": return "흐릿한 기억";
                case "nolastchance": return "마지막 기회 없음";
                default: return "기록된 성향";
            }
        }

        private static string AwakeningArchiveTitle(string value)
        {
            switch (NormalizeArchiveId(value))
            {
                case "explosivefastball": return "폭발하는 포심";
                case "pinpointedge": return "바늘끝 제구";
                case "disappearingbreaker": return "사라지는 변화구";
                case "ironarm": return "강철 어깨";
                case "calmunderpressure": return "위기 속 평정";
                case "batterysync": return "배터리 호흡";
                case "risingfourseam": return "떠오르는 포심";
                case "sinkertunnel": return "싱커 터널";
                case "frozenchangeup": return "얼어붙는 체인지업";
                case "sweepingslider": return "가로지르는 슬라이더";
                case "curveballclock": return "커브 타이밍";
                case "repeatablerelease": return "한결같은 손끝";
                case "pickoffrhythm": return "견제 리듬";
                case "twostrikeplan": return "투 스트라이크 설계";
                case "firstpitchstrike": return "초구 스트라이크";
                case "trafficcontroller": return "주자 통제";
                case "lateinningreserve": return "후반의 여력";
                case "scoutcomposure": return "스카우트 앞 평정";
                default: return "기록된 각성";
            }
        }

        private static string MemoryArchiveTitle(string value)
        {
            switch (NormalizeArchiveId(value))
            {
                case "velocityblueprint": return "구속 설계도";
                case "fingertipmemory": return "손끝의 기억";
                case "catchernotebook": return "포수의 노트";
                case "rivalnotebook": return "라이벌 노트";
                case "recoveryroutine": return "회복 루틴";
                case "pressurerehearsal": return "압박 리허설";
                case "firstpitchmap": return "초구 지도";
                case "twostrikesequence": return "투 스트라이크 배합";
                case "fatiguediary": return "피로 일지";
                case "mechanicsvideo": return "투구 동작 영상";
                case "schoolplaybook": return "학교 작전 노트";
                case "coachletter": return "감독의 편지";
                case "draftreport": return "드래프트 보고서";
                case "stadiumecho": return "구장의 메아리";
                case "teamfirstpromise": return "팀 우선의 약속";
                case "failurescorebook": return "실패의 스코어북";
                case "winterprogram": return "겨울 프로그램";
                case "bullpencompass": return "불펜 나침반";
                default: return "기록된 기억";
            }
        }

        private static string NormalizeArchiveId(string value) =>
            (value ?? string.Empty).ToLowerInvariant().Replace("_", string.Empty).Replace("-", string.Empty);

        public static LifeArchiveRecord CurrentLifeArchiveFor(GameSaveAggregate state)
        {
            if (state?.Meta?.LifeArchive == null) return null;
            int lifeNumber = state.HighSchool?.LifeNumber ?? state.Meta.LifeNumber;
            return state.Meta.LifeArchive.FirstOrDefault(record =>
                record != null && record.LifeNumber == lifeNumber);
        }

        private static bool HasCurrentLifeArchive(GameSaveAggregate state) =>
            CurrentLifeArchiveFor(state) != null;
    }
}
