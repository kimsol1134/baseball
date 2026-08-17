using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Reflection;
using Baseball.Application.Commands;
using Baseball.Application.Persistence;
using Baseball.Core.Catalogs;
using Baseball.Core.Domain;
using Baseball.Core.HighSchool;
using Baseball.Core.Random;
using Newtonsoft.Json;
using Newtonsoft.Json.Converters;
using Newtonsoft.Json.Serialization;

namespace Baseball.Application.HighSchool
{
    public sealed partial class CoreHighSchoolCareerPort
    {
        private static HighSchoolCareerReadModel CopyWithNextSeed(
            HighSchoolCareerReadModel value,
            string nextSeed)
        {
            return new HighSchoolCareerReadModel(
                value.CareerId,
                value.LifeNumber,
                value.Phase,
                nextSeed,
                value.CoreRevision,
                value.PlayerId,
                value.PlayerName,
                value.PresetId,
                value.Ratings,
                value.Performance,
                value.SchoolId,
                value.SchoolName,
                value.SchoolYear,
                value.ChapterNumber,
                value.RemainingImportantGames,
                value.RemainingChapterAdvances,
                value.Draft,
                value.CoreStateJson,
                value.PledgeId,
                value.PledgeDecided,
                value.Karmas,
                value.Awakenings,
                value.SchoolChoices,
                value.TrainingFocusChoices,
                value.TrainingIntensityChoices,
                value.RelationshipChoices,
                value.AwakeningChoices,
                value.LegacyMemoryChoices,
                value.MemorySlots,
                value.Tournament,
                value.ProspectRankings,
                value.GameLines,
                value.SignatureLegacyChoices,
                value.EquippedSignatureLegacyId,
                value.SelectedSignatureLegacyId,
                value.Difficulty,
                value.IsChallengeRun,
                value.LegacySelectionMode,
                value.TutorialCompleted,
                value.TutorialAttemptCount,
                value.PledgeRulesVersion,
                value.LegacyRewardPermille,
                value.RivalStrikeouts,
                value.Fatigue,
                value.ArmRisk,
                value.InjuryRecovery,
                value.ManagerTrust,
                value.CatcherTrust,
                value.RivalTrust,
                value.FanInterest,
                value.DraftForecastScore,
                value.ChapterProgress,
                value.ScheduleMilestones,
                value.CurrentRelationshipEvent,
                value.CurrentGameScenario,
                value.LastTraining,
                value.LastRelationship,
                value.News,
                value.TrainingPitchChoices,
                value.LastTrainingBlock,
                value.MaximumTrainingBlockSessions,
                value.FrozenSignatureLegacyCandidates,
                value.SelectedSignatureLegacy,
                value.LifeDetail,
                value.TrainingOutlooks);
        }

        private static string AdvanceSeed(string value)
        {
            if (!ulong.TryParse(value, NumberStyles.None, CultureInfo.InvariantCulture, out var seed))
                seed = 0x9E3779B97F4A7C15UL;
            var generator = new SplitMix64(seed);
            return Math.Max(1UL, generator.Next() >> 1)
                .ToString(CultureInfo.InvariantCulture);
        }

        private static string InferPresetId(string pitcherId)
        {
            switch (pitcherId)
            {
                case "pitcher-power": return "power_prospect";
                case "pitcher-command": return "precision_commander";
                case "pitcher-artist": return "breaking_ball_artist";
                case "pitcher-stamina": return "innings_eater";
                default: return pitcherId;
            }
        }

        private static string SchoolWire(SchoolId value)
        {
            switch (value)
            {
                case SchoolId.HanbitTraditional: return "hanbit_traditional";
                case SchoolId.MiraeAnalytics: return "mirae_analytics";
                case SchoolId.HaedongPower: return "haedong_power";
                default: return "cheongam_development";
            }
        }

        private static string RelationshipWire(RelationshipResponse value)
        {
            return value == RelationshipResponse.Listen
                ? "listen"
                : value == RelationshipResponse.Explain ? "explain" : "challenge";
        }

        private static string KarmaWire(KarmaId value)
        {
            switch (value)
            {
                case KarmaId.UnknownLand: return "unknown_land";
                case KarmaId.StubbornCoach: return "stubborn_coach";
                case KarmaId.SingleWeapon: return "single_weapon";
                case KarmaId.GeniusGeneration: return "genius_generation";
                case KarmaId.ErasedMemory: return "erased_memory";
                default: return "no_last_chance";
            }
        }

        private static string FocusTitle(TrainingFocus value)
        {
            switch (value)
            {
                case TrainingFocus.Velocity: return "구속";
                case TrainingFocus.Command: return "제구";
                case TrainingFocus.BreakingBall: return "변화구";
                case TrainingFocus.Stamina: return "체력";
                case TrainingFocus.Recovery: return "회복";
                default: return "경기 운영";
            }
        }

        private static string OutlookTitle(TrainingGrowthOutlook value)
        {
            switch (value)
            {
                case TrainingGrowthOutlook.Wall: return "재능 한계";
                case TrainingGrowthOutlook.None: return "성장 없음";
                case TrainingGrowthOutlook.ZeroOrOne: return "0~1";
                case TrainingGrowthOutlook.One: return "+1";
                case TrainingGrowthOutlook.OneOrTwo: return "+1~2";
                default: return "+2";
            }
        }

        private static string OutlookWire(TrainingGrowthOutlook value)
        {
            switch (value)
            {
                case TrainingGrowthOutlook.Wall: return "wall";
                case TrainingGrowthOutlook.None: return "none";
                case TrainingGrowthOutlook.ZeroOrOne: return "zero_or_one";
                case TrainingGrowthOutlook.One: return "one";
                case TrainingGrowthOutlook.OneOrTwo: return "one_or_two";
                default: return "two";
            }
        }

        private static string IntensityWire(TrainingIntensity value)
        {
            return value == TrainingIntensity.Light
                ? "light"
                : value == TrainingIntensity.Intensive ? "intensive" : "standard";
        }

        private static string OutlookSummary(TrainingGrowthOutlook value)
        {
            switch (value)
            {
                case TrainingGrowthOutlook.Wall:
                    return "지금은 재능의 벽에 막혀 수치가 오르지 않습니다. 대신 계속 두드리면 벽이 열립니다.";
                case TrainingGrowthOutlook.Two:
                    return "크게 오를 훈련입니다. +2가 유력합니다.";
                case TrainingGrowthOutlook.OneOrTwo:
                    return "+1은 확실하고, 잘 풀리면 +2까지 오릅니다.";
                case TrainingGrowthOutlook.One:
                    return "+1이 확실한 훈련입니다.";
                case TrainingGrowthOutlook.ZeroOrOne:
                    return "+1이 나올 수도, 성장 없이 지날 수도 있습니다.";
                default:
                    return "이대로면 성장 없이 지나갑니다. 피로가 높거나 강도가 약합니다.";
            }
        }

        private static string TalentAbilityWire(TalentAbility value)
        {
            switch (value)
            {
                case TalentAbility.Stuff: return "stuff";
                case TalentAbility.Command: return "command";
                case TalentAbility.Movement: return "movement";
                default: return "stamina";
            }
        }

        private static string TalentGradeWire(Baseball.Core.Domain.TalentGrade value)
        {
            switch (value)
            {
                case Baseball.Core.Domain.TalentGrade.D: return "d";
                case Baseball.Core.Domain.TalentGrade.C: return "c";
                case Baseball.Core.Domain.TalentGrade.B: return "b";
                case Baseball.Core.Domain.TalentGrade.A: return "a";
                default: return "s";
            }
        }

        private static string AwakeningTitle(AwakeningId value)
        {
            switch (value)
            {
                case AwakeningId.ExplosiveFastball: return "폭발하는 포심";
                case AwakeningId.PinpointEdge: return "바늘끝 제구";
                case AwakeningId.DisappearingBreaker: return "사라지는 변화구";
                case AwakeningId.IronArm: return "강철 어깨";
                case AwakeningId.CalmUnderPressure: return "위기 속 평정";
                case AwakeningId.BatterySync: return "배터리 호흡";
                case AwakeningId.RisingFourSeam: return "떠오르는 포심";
                case AwakeningId.SinkerTunnel: return "싱커 터널";
                case AwakeningId.FrozenChangeup: return "얼어붙는 체인지업";
                case AwakeningId.SweepingSlider: return "가로지르는 슬라이더";
                case AwakeningId.CurveballClock: return "커브 타이밍";
                case AwakeningId.RepeatableRelease: return "한결같은 손끝";
                case AwakeningId.PickoffRhythm: return "견제 리듬";
                case AwakeningId.TwoStrikePlan: return "투 스트라이크 설계";
                case AwakeningId.FirstPitchStrike: return "초구 스트라이크";
                case AwakeningId.TrafficController: return "주자 통제";
                case AwakeningId.LateInningReserve: return "후반의 여력";
                default: return "스카우트 앞 평정";
            }
        }

        private static string MemoryTitle(MemoryCardId value)
        {
            switch (value)
            {
                case MemoryCardId.VelocityBlueprint: return "구속 설계도";
                case MemoryCardId.FingertipMemory: return "손끝의 기억";
                case MemoryCardId.CatcherNotebook: return "포수의 노트";
                case MemoryCardId.RivalNotebook: return "라이벌 노트";
                case MemoryCardId.RecoveryRoutine: return "회복 루틴";
                case MemoryCardId.PressureRehearsal: return "압박 리허설";
                case MemoryCardId.FirstPitchMap: return "초구 지도";
                case MemoryCardId.TwoStrikeSequence: return "투 스트라이크 배합";
                case MemoryCardId.FatigueDiary: return "피로 일지";
                case MemoryCardId.MechanicsVideo: return "투구 동작 영상";
                case MemoryCardId.SchoolPlaybook: return "학교 작전 노트";
                case MemoryCardId.CoachLetter: return "감독의 편지";
                case MemoryCardId.DraftReport: return "드래프트 보고서";
                case MemoryCardId.StadiumEcho: return "구장의 메아리";
                case MemoryCardId.TeamFirstPromise: return "팀 우선의 약속";
                case MemoryCardId.FailureScorebook: return "실패의 스코어북";
                case MemoryCardId.WinterProgram: return "겨울 프로그램";
                default: return "불펜 나침반";
            }
        }

        private static HighSchoolPhase Map(HighSchoolCareerPhase value)
        {
            return (HighSchoolPhase)(int)value;
        }

        private static DraftReadModel Map(DraftResultSnapshot value)
        {
            return value == null
                ? null
                : new DraftReadModel(
                    true,
                    value.Outcome == DraftOutcome.Drafted,
                    value.EvaluationScore,
                    value.Team?.Id,
                    value.Team?.Name,
                    value.Round,
                    value.OverallPick);
        }

        private static T Parse<T>(string value) where T : struct
        {
            var normalized = Normalize(value);
            foreach (T candidate in Enum.GetValues(typeof(T)))
            {
                if (Normalize(candidate.ToString()) == normalized) return candidate;
            }
            throw new InvalidOperationException("high_school.enum_invalid:" + typeof(T).Name);
        }

        private static IReadOnlyList<T> ParseMany<T>(IReadOnlyList<string> values) where T : struct
        {
            return (values ?? Array.Empty<string>()).Select(Parse<T>).ToArray();
        }

        private static IReadOnlyList<T> ParseCsv<T>(string value) where T : struct
        {
            if (string.IsNullOrWhiteSpace(value)) return Array.Empty<T>();
            return value.Split(',').Select(Parse<T>).ToArray();
        }

        private static string[] Parts(string value, int count)
        {
            var parts = (value ?? string.Empty).Split(':');
            if (parts.Length != count) throw new InvalidOperationException("high_school.action_value_invalid");
            return parts;
        }

        private static string[] TrainingParts(string value)
        {
            var parts = (value ?? string.Empty).Split(':');
            if (parts.Length != 2 && parts.Length != 3)
                throw new InvalidOperationException("high_school.training_payload_invalid");
            return parts;
        }

        private static void ValidateTrainingTarget(
            HighSchoolCareerSnapshot state,
            TrainingFocus focus,
            PitchType? targetPitch)
        {
            if (!targetPitch.HasValue) return;
            if (focus != TrainingFocus.BreakingBall ||
                !PitcherGrowthRules.IsOwnedBreakingBall(targetPitch.Value, state.Pitcher))
            {
                throw new InvalidOperationException("high_school.training_target_invalid");
            }
        }

        private static string PitchTitle(PitchType value)
        {
            switch (value)
            {
                case PitchType.FourSeam: return "포심";
                case PitchType.Slider: return "슬라이더";
                case PitchType.Curveball: return "커브";
                default: return "체인지업";
            }
        }

        private static string Normalize(string value)
        {
            return new string((value ?? string.Empty)
                .Where(character => character != '_' && character != '-' && !char.IsWhiteSpace(character))
                .Select(char.ToLowerInvariant)
                .ToArray());
        }

        private sealed class InternalSetterContractResolver : DefaultContractResolver
        {
            protected override JsonProperty CreateProperty(MemberInfo member, MemberSerialization serialization)
            {
                var property = base.CreateProperty(member, serialization);
                if (!property.Writable && member is PropertyInfo propertyInfo &&
                    propertyInfo.GetSetMethod(true) != null)
                {
                    property.Writable = true;
                }
                return property;
            }
        }
    }
}
