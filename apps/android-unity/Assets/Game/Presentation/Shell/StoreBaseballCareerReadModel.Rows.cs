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

        private ScreenRowViewModel ProjectRow(
            ShellRoute route,
            ScreenRowViewModel row,
            GameSaveAggregate state)
        {
            LifeArchiveRecord latestLife = SelectedLifeRecord(state);
            PitcherRatingsReadModel ratings = state.Pro?.Ratings ?? state.HighSchool?.Ratings ?? latestLife?.FinalRatings;
            CareerPerformanceReadModel performance = state.Pro?.CurrentSeason ?? state.HighSchool?.Performance ?? latestLife?.HighSchoolPerformance;
            string value = row.Value;
            switch (row.Id)
            {
                case "fastball": value = ratings == null ? "능력 기록 없음" : ratings.Stuff.ToString(); break;
                case "control": value = ratings == null ? "능력 기록 없음" : ratings.Command.ToString(); break;
                case "movement": value = ratings == null ? "능력 기록 없음" : ratings.Movement.ToString(); break;
                case "stamina": value = ratings == null ? "능력 기록 없음" : ratings.Stamina.ToString(); break;
                case "games": value = performance == null ? "0" : performance.ImportantGames.ToString(); break;
                case "strikeouts": value = performance == null ? "0" : performance.Strikeouts.ToString(); break;
                case "walks": value = performance == null ? "0" : performance.Walks.ToString(); break;
                case "runs": value = performance == null ? "0" : performance.RunsAllowed.ToString(); break;
                case "chapter": value = state.HighSchool == null ? "고교 커리어 시작 전" : state.HighSchool.SchoolYear + "학년 · " + state.HighSchool.ChapterNumber + "장"; break;
                case "health":
                    if (state.HighSchool != null)
                    {
                        value = "피로 " + state.HighSchool.Fatigue + " · 팔 부담 " + state.HighSchool.ArmRisk;
                        return new ScreenRowViewModel(row.Id, row.Label, value,
                            state.HighSchool.InjuryRecovery > 0
                                ? "부상 회복까지 " + state.HighSchool.InjuryRecovery + " 일정"
                                : "현재 부상 회복 일정은 없습니다.");
                    }
                    if (state.Pro != null) value = "피로 " + state.Pro.Fatigue;
                    else value = "커리어 시작 전";
                    break;
                case "opportunity": value = state.HighSchool == null
                    ? "고교 일정 시작 전"
                    : "중요 경기 " + state.HighSchool.RemainingImportantGames + "회 · 장 진행 " +
                      state.HighSchool.RemainingChapterAdvances + "회"; break;
                case "school_choice": value = state.HighSchool?.SchoolName ?? "아직 선택하지 않음"; break;
                case "remaining": value = state.HighSchool == null ? "0" : state.HighSchool.RemainingImportantGames.ToString(); break;
                case "club": value = state.Pro?.TeamName ?? state.HighSchool?.Draft?.TeamName ?? "아직 정해지지 않음"; break;
                case "week": value = state.Pro == null ? "프로 커리어 시작 전" : state.Pro.Season + "시즌 " + state.Pro.Week + "주"; break;
                case "condition": value = state.Pro == null ? "프로 커리어 시작 전" : "피로 " + state.Pro.Fatigue; break;
                case "role": value = state.Pro == null ? "보직 미정" : ProRoleName(state.Pro.Role); break;
                case "recent_result":
                    CareerGameLineReadModel recent = state.Pro?.RecentGameLines.LastOrDefault(line => line.Played);
                    value = recent == null
                        ? "아직 이번 시즌 등판 기록이 없습니다."
                        : InningsTitle(recent.Outs) +
                          "이닝 · " + recent.Strikeouts + "탈삼진 · " + recent.RunsAllowed + "실점";
                    break;
                case "season_record": value = state.Pro == null
                    ? "시즌 기록 없음"
                    : state.Pro.CurrentSeason.ImportantGames + "경기 · " + state.Pro.CurrentSeason.Strikeouts +
                      "탈삼진 · " + state.Pro.CurrentSeason.RunsAllowed + "실점"; break;
                case "award": value = state.Pro == null ? "수상 기록 없음" : state.Pro.Awards + "회"; break;
                case "career_games": value = state.Pro == null
                    ? "0"
                    : (state.Pro.CurrentSeason.ImportantGames + state.Pro.CareerSeasons.Sum(line => line.Games)).ToString(); break;
                case "seasons": value = state.Pro == null ? "0" : state.Pro.CareerSeasons.Count.ToString(); break;
                case "career_strikeouts": value = state.Pro == null ? "0" : state.Pro.CareerStrikeouts.ToString(); break;
                case "career_record": value = state.Pro == null
                    ? "프로 기록 없음"
                    : state.Pro.CareerStrikeouts + "탈삼진 · " + state.Pro.Awards + "수상"; break;
                case "hall": value = state.Pro == null ? "0" : state.Pro.HallOfFameScore.ToString(); break;
                case "players": value = state.Meta.LifeArchive.Count.ToString(); break;
                case "legacies": value = state.Meta.InheritedMemories.Count.ToString(); break;
                case "unlocked": value = state.Meta.Achievements.Unlocked.Count.ToString(); break;
                case "player_name": value = latestLife?.PlayerName ?? "기록 없음"; break;
                case "soul": value = state.Meta.SoulBalance.ToString(); break;
                case "player": value = route == ShellRoute.LifeCard
                    ? latestLife?.PlayerName ?? "기록 없음"
                    : state.Pro?.PlayerName ?? state.HighSchool?.PlayerName ?? latestLife?.PlayerName ?? "기록 없음"; break;
                case "evaluation_detail": value = state.HighSchool?.Draft?.EvaluationScore.ToString() ?? "아직 평가 전"; break;
                case "forecast": value = state.HighSchool?.Draft?.Resolved == true
                    ? state.HighSchool.Draft.Drafted ? "지명" : "미지명"
                    : "결과 대기"; break;
                case "result_detail": value = state.HighSchool?.Draft?.Resolved == true
                    ? state.HighSchool.Draft.Drafted
                        ? (state.HighSchool.Draft.TeamName ?? "가상 구단") + " 지명"
                        : "미지명"
                    : "결과 대기"; break;
                case "record": value = performance == null
                    ? "기록 없음"
                    : "탈삼진 " + performance.Strikeouts + " · 볼넷 " + performance.Walks + " · 실점 " + performance.RunsAllowed; break;
                case "stamp_status": value = state.Meta.Weekly.Program == null
                    ? "프로그램 준비 전"
                    : state.Meta.Weekly.Program.CompletedCount + "/" + state.Meta.Weekly.Program.Tasks.Count; break;
                case "drafted": value = state.Meta.LifeArchive.Count(record => record.Drafted).ToString(); break;
                case "awakenings": value = state.HighSchool?.Awakenings.Count.ToString() ?? "0"; break;
                case "detail" when route == ShellRoute.Opening:
                    return row;
                default:
                    return null;
            }
            string detail = row.Detail;
            if (route == ShellRoute.Prologue && state.HighSchool?.Phase == HighSchoolPhase.Prologue)
            {
                string talentAbilityId = string.Equals(row.Id, "fastball", StringComparison.Ordinal)
                    ? "stuff"
                    : row.Id;
                TalentGradeReadModel talent = state.HighSchool.LifeDetail?.Talents?
                    .FirstOrDefault(candidate => string.Equals(candidate.AbilityId, talentAbilityId, StringComparison.Ordinal));
                if (talent != null) detail = "재능 " + talent.GradeTitle;
            }
            return new ScreenRowViewModel(row.Id, row.Label, value, detail);
        }

        private static string InningsTitle(int outs)
        {
            int safeOuts = Math.Max(0, outs);
            switch (safeOuts % 3)
            {
                case 1: return safeOuts / 3 + "⅓";
                case 2: return safeOuts / 3 + "⅔";
                default: return (safeOuts / 3).ToString();
            }
        }
    }
}
