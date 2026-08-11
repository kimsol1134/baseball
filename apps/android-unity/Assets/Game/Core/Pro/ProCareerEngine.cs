using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using Baseball.Core.Catalogs;
using Baseball.Core.Domain;
using Baseball.Core.HighSchool;
using Baseball.Core.Pitching;
using Baseball.Core.Random;

namespace Baseball.Core.Pro
{
    public sealed class ProCareerEngine
    {
        public static readonly IReadOnlyList<int> SeasonDecisionWeeks = new[] { 3, 6, 9, 12, 15, 18, 21 };
        public const int MaximumSeasonDecisions = 7;
        public const int DemotionTrust = 34;
        public static IReadOnlyList<DraftTeamSnapshot> ProTeams { get { return HighSchoolCareerEngine.Teams; } }
        public static IReadOnlyList<ProRivalBatter> RivalBatterCatalog { get { return RivalBatters; } }

        private static readonly int[] SeasonStrikeoutMarks = { 45, 85, 125 };
        private static readonly IReadOnlyList<ProRivalBatter> RivalBatters = new[]
        {
            Rival("pro-rival-seoul", "강도훈", "중심 타선 해결사형", "seoul_comets", "서울 코메츠", "최근 3시즌 82홈런 · OPS .901", "카운트가 몰려도 스윙이 짧아지지 않습니다. 바깥쪽 승부를 기다렸다 밀어칩니다."),
            Rival("pro-rival-busan", "마태오", "우측 담장 거포형", "busan_marines", "부산 블루웨일스", "최근 3시즌 96홈런 · 장타율 .571", "낮게 깔린 공을 퍼올려 우측 담장을 넘깁니다. 몸쪽 실투 한 개를 놓치지 않습니다."),
            Rival("pro-rival-incheon", "백건우", "교타 정확형", "incheon_waves", "인천 크레스트핀스", "통산 타율 .318 · 3년 연속 150안타", "파울로 승부를 늘리다 결정구를 받아칩니다. 삼진보다 인플레이 타구가 많습니다."),
            Rival("pro-rival-daegu", "노진성", "당겨치는 홈런형", "daegu_forge", "대구 포지", "지난 시즌 34홈런 · 최다 장타", "빠른 배트로 안쪽 공을 끌어당깁니다. 초구부터 노림수를 숨기지 않습니다."),
            Rival("pro-rival-daejeon", "천우재", "선구안 출루형", "daejeon_rockets", "대전 로켓츠", "출루율 .420 · 볼넷 최다", "존을 벗어난 공에는 손이 나가지 않습니다. 풀카운트 승부를 두려워하지 않습니다."),
            Rival("pro-rival-gwangju", "서강윤", "중장거리 갭 히터형", "gwangju_phoenix", "광주 피닉스", "2루타 최다 · OPS .880", "좌중간 갭을 노려 장타를 만듭니다. 변화구 타이밍에 강합니다."),
            Rival("pro-rival-suwon", "구본혁", "컨택 무결점형", "suwon_guardians", "수원 가디언즈", "5년 연속 3할·두 자릿수 홈런", "약점 코스가 뚜렷하지 않습니다. 어떤 구종이든 중심에 맞힙니다."),
            Rival("pro-rival-changwon", "류성권", "장신 파워형", "changwon_meteors", "창원 미티어스", "지난 시즌 40홈런 · 장타율 .612", "긴 리치로 바깥쪽까지 커버합니다. 높은 공을 그대로 받아넘깁니다."),
            Rival("pro-rival-jeonju", "문태경", "빠른 발 갭 타자형", "jeonju_hanok", "전주 한울스", "3년 연속 3할·30도루", "짧게 끊어치고 곧바로 다음 베이스를 노립니다. 실투가 곧 실점입니다."),
            Rival("pro-rival-jeju", "한도결", "득점권 해결사형", "jeju_storm", "제주 스톰", "득점권 타율 .352 · 끝내기 다수", "주자가 있을 때 스윙이 더 단단해집니다. 넓은 존을 커버하는 배드볼 히터입니다.")
        };

        public ProCareerResult Start(StartProCareerParams parameters)
        {
            var seed = Seed(parameters.Seed);
            if (parameters.Entitlement == null || parameters.Entitlement.Status != EntitlementStatus.Active)
                throw Invalid("프로 커리어 이용 권한을 확인할 수 없습니다.");
            if (parameters.DraftResult == null || parameters.DraftResult.Outcome != DraftOutcome.Drafted || parameters.DraftResult.Team == null)
                throw Invalid("고교 드래프트 지명 기록이 필요합니다.");
            var team = ProTeams.FirstOrDefault(item => item.Id == parameters.DraftResult.Team.Id) ?? parameters.DraftResult.Team;
            var rng = new SplitMix64(seed);
            var id = "pro-" + StableHash.Fnv1A64(seed + "|" + parameters.Pitcher.Id + "|" + team.Id);
            var state = new ProCareerSnapshot
            {
                ProCareerId = id,
                Revision = 0,
                Phase = ProCareerPhase.ContractOffer,
                Identity = parameters.Identity,
                Pitcher = parameters.Pitcher,
                Team = team,
                Entitlement = parameters.Entitlement,
                Age = 19,
                Season = 1,
                Week = 0,
                Level = ProLevel.Minor,
                Role = ProRole.Starter,
                ManagerTrust = 42,
                CatcherTrust = 45,
                Fatigue = 0,
                InjuryWeeks = 0,
                ServiceYears = 0,
                MilitaryCompleted = false,
                Contract = null,
                CurrentStats = new ProSeasonStats(
                    1, team.Id,
                    hits: 0, homeRuns: 0, pitches: 0, qualityStarts: 0),
                GameLines = null,
                CareerStats = new ProSeasonStats[0],
                Awards = new string[0],
                Milestones = new[] { "프로 지명" },
                News = new[] { "신인 계약 제안 · " + team.Name + " · " + parameters.Identity.Name },
                HallOfFameScore = null,
                Commitment = string.Empty,
                BalanceVersion = PitcherPresetCatalog.BalanceVersion,
                SeasonSegment = ProSeasonSegment.SpringCamp,
                SeasonTrigger = null,
                CurrentRival = null,
                SeasonTensions = null,
                SeasonImportantGames = 0,
                PendingDecision = null,
                DecisionHistory = new ProDecisionRecord[0]
            };
            Sign(state);
            return Result(state, rng.Next().ToString(CultureInfo.InvariantCulture), new[] { "pro_career_started" });
        }

        /// <summary>Creates a deterministic development career without a persisted high-school draft.</summary>
        public ProCareerResult StartDirect(StartDirectProParams parameters)
        {
            var preset = PitcherPresetCatalog.All.FirstOrDefault(value => value.Id == parameters.PresetId);
            var team = ProTeams.FirstOrDefault(value => value.Id == parameters.TeamId);
            var name = (parameters.PlayerName ?? string.Empty).Trim();
            if (preset == null) throw Invalid("unknown pro pitcher preset");
            if (team == null) throw Invalid("unknown pro team");
            if (name.Length < 1 || name.Length > 12) throw Invalid("player name must contain between one and twelve characters");
            var pitcher = new PitcherSnapshot(preset.Pitcher.Id, name, preset.Pitcher.Stuff, preset.Pitcher.Command,
                preset.Pitcher.Movement, preset.Pitcher.Stamina, preset.Pitcher.PitchProfiles, preset.Pitcher.ThrowingHand);
            var identity = new PlayerIdentitySnapshot(name, pitcher.ThrowingHand, BodyType.Balanced, "서울");
            var draft = new DraftResultSnapshot(DraftOutcome.Drafted, 72, "직접 시작", team, 1, 1, 0,
                "프로 적응", new string[0], "직접 프로 커리어 시작");
            var started = Start(new StartProCareerParams(parameters.Seed, identity, pitcher, draft,
                new ProEntitlementSnapshot(EntitlementStatus.Active, EntitlementSource.Development, "direct")));
            return SignContract(new ProStateParams(started.NextSeed, started.Snapshot));
        }

        public ProCareerResult NormalizeBalance(ProStateParams parameters)
        {
            Seed(parameters.Seed);
            ValidateState(parameters.State);
            var state = parameters.State.Clone();
            state.BalanceVersion = Math.Max(parameters.State.BalanceVersion ?? 1, 3);
            Sign(state);
            return new ProCareerResult(state, parameters.Seed, new string[0]);
        }

        public ProCareerResult SignContract(ProStateParams parameters)
        {
            Validate(parameters.State, ProCareerPhase.ContractOffer);
            var rng = new SplitMix64(Seed(parameters.Seed));
            var contract = new ProContractSnapshot(3, Math.Max(30000000, parameters.State.Pitcher.Stuff * 1000000), ProRole.Starter);
            var tensions = SeasonTensions(parameters.State);
            var state = Next(parameters.State);
            state.Phase = ProCareerPhase.WeeklyPlan;
            state.Contract = contract;
            state.Milestones = AddUnique("신인 계약", state.Milestones);
            state.News = new[] { "신인 계약에 서명했습니다. 2군 선발 경쟁이 시작됩니다.", TensionHeadline(tensions) }.Concat(state.News).ToArray();
            state.SeasonSegment = Segment(state.Week);
            state.SeasonTensions = tensions;
            state.SeasonImportantGames = 0;
            return Result(state, rng.Next().ToString(CultureInfo.InvariantCulture), new[] { "rookie_contract_signed" });
        }

        public ProCareerResult PlanWeek(PlanProWeekParams parameters)
        {
            Validate(parameters.State, ProCareerPhase.WeeklyPlan);
            var rng = new SplitMix64(Seed(parameters.Seed));
            var source = parameters.State;
            var nextWeek = source.Week + 1;
            var recovering = source.InjuryWeeks > 0;
            var skill = (source.Pitcher.Stuff + source.Pitcher.Command + source.Pitcher.Movement + source.Pitcher.Stamina) / 4;
            var resting = recovering || parameters.Plan == ProWeekPlan.Recover;
            int outings;
            int outsTarget;
            int pitchCap;
            if (source.Role == ProRole.Starter) { outings = 1; outsTarget = 18; pitchCap = 96; }
            else if (source.Role == ProRole.LongRelief) { outings = 2; outsTarget = 6; pitchCap = 42; }
            else { outings = 3; outsTarget = 3; pitchCap = 24; }

            var totalOuts = 0;
            var strikeouts = 0;
            var walks = 0;
            var runs = 0;
            var newLines = new List<ProGameLine>();
            if (!resting)
            {
                for (var outingIndex = 0; outingIndex < outings; outingIndex++)
                {
                    var weekSalt = unchecked((ulong)(nextWeek * 0x9E37));
                    var baseSeed = unchecked((rng.Next() ^ weekSalt) + (ulong)outingIndex);
                    var line = new AutoOutingSimulator().Simulate(
                        source.Pitcher, source.Fatigue + outingIndex * 5, outsTarget, pitchCap, baseSeed);
                    totalOuts += line.Outs;
                    strikeouts += line.Strikeouts;
                    walks += line.Walks;
                    runs += line.RunsAllowed;
                    var support = LeagueBaseline.TeamRuns(ref rng);
                    var opponentRuns = line.RunsAllowed + LeagueBaseline.RestOfTeamRuns(Math.Max(0, 27 - line.Outs), ref rng);
                    var started = source.Role == ProRole.Starter;
                    newLines.Add(ProGameLineAdapter.Create(
                        source.Season,
                        nextWeek,
                        (source.GameLines == null ? 0 : source.GameLines.Count) + newLines.Count + 1,
                        started,
                        line.Outs,
                        line.Strikeouts,
                        line.Walks,
                        line.RunsAllowed,
                        line.Pitches,
                        support,
                        opponentRuns,
                        DecisionRules.Decide(started, source.Role == ProRole.Closer, line.Outs, line.RunsAllowed, support, opponentRuns),
                        false,
                        line.Hits,
                        line.HomeRuns));
                }
            }

            var games = resting ? 0 : outings;
            var starts = resting ? 0 : (source.Role == ProRole.Starter ? 1 : 0);
            var fatigueDelta = recovering || parameters.Plan == ProWeekPlan.Recover ? -20 :
                parameters.Plan == ProWeekPlan.DevelopStuff ? 16 :
                parameters.Plan == ProWeekPlan.DevelopMovement ? 13 :
                parameters.Plan == ProWeekPlan.DevelopWeapon ? 15 :
                parameters.Plan == ProWeekPlan.RefineCommand ? 9 :
                parameters.Plan == ProWeekPlan.BuildStamina ? 10 : 10;
            var fatigue = Clamp(source.Fatigue + fatigueDelta, 0, 100);
            var injuryRoll = rng.NextInt(100);
            var newInjury = !recovering && injuryRoll < Math.Max(2, fatigue - 72)
                ? 2 + rng.NextInt(4)
                : Math.Max(0, source.InjuryWeeks - 1);
            var performanceTrust = runs <= 2 ? 3 : runs == 3 ? 0 : runs <= 5 ? -3 : -6;
            var trustGain = recovering ? -1 : parameters.Plan == ProWeekPlan.EarnTrust ? 5 : parameters.Plan == ProWeekPlan.Recover ? 0 : performanceTrust;
            var trust = Clamp(source.ManagerTrust + trustGain, 0, 100);
            var priorStats = RecoverStatEvidence(source.CurrentStats, source.GameLines);
            var stats = new ProSeasonStats(
                source.Season, source.Team.Id,
                priorStats.Games + games,
                priorStats.Starts + starts,
                priorStats.InningsOuts + totalOuts,
                priorStats.Strikeouts + strikeouts,
                priorStats.Walks + walks,
                priorStats.RunsAllowed + runs,
                priorStats.Wins + newLines.Count(line => line.Decision == PitchingDecision.Win),
                priorStats.Losses + newLines.Count(line => line.Decision == PitchingDecision.Loss),
                priorStats.Saves + newLines.Count(line => line.Decision == PitchingDecision.Save),
                hits: AddKnown(priorStats.Hits, newLines.Select(line => line.Hits)),
                homeRuns: AddKnown(priorStats.HomeRuns, newLines.Select(line => line.HomeRuns)),
                pitches: AddKnown(priorStats.Pitches, newLines.Sum(line => line.Pitches)),
                qualityStarts: AddKnown(
                    priorStats.QualityStarts,
                    newLines.Count(line => PitchingMetrics.IsQualityStart(
                        line.Started, line.Outs, line.RunsAllowed))));
            var earnedCallUp = trust >= 60 && skill >= 46 && (source.Season > 1 || stats.Games >= 12 || stats.Strikeouts >= 40);
            var demoted = source.Level == ProLevel.Major && trust < DemotionTrust && !recovering;
            var level = demoted ? ProLevel.Minor : source.Level == ProLevel.Major || earnedCallUp ? ProLevel.Major : ProLevel.Minor;
            var role = level == ProLevel.Major
                ? trust >= 74 ? ProRole.Starter : trust >= 62 ? ProRole.LongRelief : ProRole.Setup
                : trust >= 52 ? ProRole.Starter : ProRole.LongRelief;
            var development = ResolveDevelopment(
                source.Pitcher,
                source.DevelopmentProgress ?? new ProDevelopmentProgress(),
                parameters.Plan,
                parameters.TargetPitch,
                recovering);
            var pitcher = development.Pitcher;
            var callUpGame = source.Level != level && level == ProLevel.Major;
            var priorImportantGames = source.SeasonImportantGames ?? 0;
            ProSeasonTrigger? trigger = nextWeek >= 24 ? (ProSeasonTrigger?)null : ImportantGameTrigger(source, nextWeek, level, trust, stats.Strikeouts, skill, priorImportantGames);
            var history = source.DecisionHistory ?? new ProDecisionRecord[0];
            var decisionsThisSeason = history.Count(record => record.Season == source.Season);
            var shouldOpenDecision = nextWeek < 24 && (source.BalanceVersion ?? 1) >= 4 && SeasonDecisionWeeks.Contains(nextWeek) &&
                !trigger.HasValue && !recovering && newInjury == 0 && decisionsThisSeason < MaximumSeasonDecisions;
            var pendingDecision = shouldOpenDecision ? SeasonDecision(source, nextWeek) : null;
            var phase = nextWeek >= 24 ? ProCareerPhase.SeasonReview : trigger.HasValue ? ProCareerPhase.ImportantGame : pendingDecision != null ? ProCareerPhase.SeasonDecision : ProCareerPhase.WeeklyPlan;
            var rival = trigger.HasValue ? RivalForGame(source, nextWeek, trigger.Value) : null;
            var importantGames = priorImportantGames + (phase == ProCareerPhase.ImportantGame ? 1 : 0);
            var tensions = source.SeasonTensions ?? SeasonTensions(source);
            var priorSegment = source.SeasonSegment ?? Segment(source.Week);
            var nextSegment = Segment(nextWeek);
            var news = source.News.ToList();
            var milestones = source.Milestones.ToArray();
            if (source.Week == 0)
            {
                milestones = AddUnique("프로 첫 공식 등판", milestones);
                news.Insert(0, "프로 첫 공식 등판을 마쳤습니다. " + games + "경기에서 " + strikeouts + "개의 삼진을 잡았습니다.");
            }
            else news.Insert(0, nextWeek + "주차 · " + games + "경기 · " + strikeouts + "K · " + walks + "볼넷 · " + runs + "실점");
            if (source.Level != level)
            {
                if (level == ProLevel.Major)
                {
                    milestones = AddUnique("1군 콜업", milestones);
                    news.Insert(0, "2군 기록과 감독의 믿음을 쌓아 1군 출전 명단에 합류했습니다.");
                }
                else news.Insert(0, "최근 등판이 이어지지 않아 2군으로 내려갑니다. 기록을 다시 쌓아야 합니다.");
            }
            if (source.Role != role)
            {
                var roleName = ProDecisionEffect.RoleLabel(role);
                milestones = AddUnique(source.Season + "시즌 " + roleName + " 역할", milestones);
                news.Insert(0, "감독 면담 뒤 다음 등판부터 " + roleName + " 역할을 맡습니다.");
            }
            AddCareerMarks(source, games, strikeouts, ref milestones);
            if (newInjury > 0 && source.InjuryWeeks == 0) news.Insert(0, "과부하로 " + newInjury + "주 부상자 명단에 올랐습니다.");
            if (development.GrowthLabels.Count > 0) news.Insert(0, "주간 성장 완성 · " + string.Join(" · ", development.GrowthLabels));
            if (nextSegment != priorSegment) news.Insert(0, SegmentEntryNews(nextSegment));
            if (phase == ProCareerPhase.ImportantGame && trigger.HasValue) news.Insert(0, ImportantMomentHeadline(trigger.Value, rival, level));

            var state = Next(source);
            state.Phase = phase;
            state.Pitcher = pitcher;
            state.Week = nextWeek;
            state.Level = level;
            state.Role = role;
            state.ManagerTrust = trust;
            state.Fatigue = fatigue;
            state.InjuryWeeks = newInjury;
            state.CurrentStats = stats;
            state.GameLines = (source.GameLines ?? new ProGameLine[0]).Concat(newLines).ToArray();
            state.Milestones = milestones;
            state.News = news.Take(30).ToArray();
            state.SeasonSegment = nextSegment;
            state.SeasonTrigger = trigger;
            state.CurrentRival = rival;
            state.SeasonTensions = tensions;
            state.SeasonImportantGames = importantGames;
            state.PendingDecision = pendingDecision;
            state.DevelopmentProgress = development.Progress;
            var events = new List<string> { "pro_week_resolved", callUpGame ? "major_call_up" : "weekly_progress" };
            if (phase == ProCareerPhase.SeasonDecision) events.Add("pro_season_decision_opened");
            return Result(state, rng.Next().ToString(CultureInfo.InvariantCulture), events);
        }

        public ProSegmentAdvanceResult AdvanceSegment(AdvanceProSegmentParams parameters)
        {
            if(parameters==null)throw new ArgumentNullException(nameof(parameters));
            if(parameters.MaximumWeeks<1||parameters.MaximumWeeks>24)throw Invalid("segment advance must contain between one and twenty-four weeks");
            Validate(parameters.State,ProCareerPhase.WeeklyPlan);
            var startingSegment=parameters.State.SeasonSegment??Segment(parameters.State.Week);
            var current=parameters.State;
            var seed=parameters.Seed;
            ProCareerResult result=null;
            var advanced=0;
            var stop=ProSegmentStopReason.MaximumWeeks;
            while(advanced<parameters.MaximumWeeks&&current.Phase==ProCareerPhase.WeeklyPlan)
            {
                var before=current;
                result=PlanWeek(new PlanProWeekParams(seed,current,parameters.Plan,parameters.TargetPitch));
                advanced++;
                current=result.Snapshot;
                seed=result.NextSeed;
                var endingSegment=current.SeasonSegment??Segment(current.Week);
                if(endingSegment!=startingSegment){stop=ProSegmentStopReason.SegmentChanged;break;}
                if(current.Role!=before.Role){stop=ProSegmentStopReason.RoleChanged;break;}
                if(current.Level!=before.Level){stop=ProSegmentStopReason.LevelChanged;break;}
                if(current.InjuryWeeks>before.InjuryWeeks){stop=ProSegmentStopReason.Injury;break;}
                if(current.Phase!=ProCareerPhase.WeeklyPlan){stop=ProSegmentStopReason.PhaseChanged;break;}
            }
            if(result==null)throw Invalid("segment advance did not complete a week");
            var target=(parameters.Plan==ProWeekPlan.DevelopMovement||parameters.Plan==ProWeekPlan.DevelopWeapon)
                ?PitcherGrowthRules.NormalizeBreakingBallTarget(parameters.TargetPitch,parameters.State.Pitcher)
                :null;
            return new ProSegmentAdvanceResult(result,new ProSegmentProgressSnapshot(
                advanced,startingSegment,current.SeasonSegment??Segment(current.Week),stop,parameters.Plan,target));
        }

        public ProCareerResult ApplySeasonDecision(ApplyProSeasonDecisionParams parameters)
        {
            Validate(parameters.State, ProCareerPhase.SeasonDecision);
            Seed(parameters.Seed);
            var pending = parameters.State.PendingDecision;
            if (pending == null) throw Invalid("적용할 시즌 결정이 없습니다.");
            if (pending.Id != parameters.DecisionId) throw Invalid("확인한 시즌 결정이 현재 결정과 다릅니다.");
            var history = parameters.State.DecisionHistory ?? new ProDecisionRecord[0];
            if (history.Any(record => record.DecisionId == pending.Id)) throw Invalid("이미 적용한 시즌 결정입니다.");
            if (history.Count(record => record.Season == parameters.State.Season) >= MaximumSeasonDecisions) throw Invalid("한 시즌에는 일곱 번까지만 결정할 수 있습니다.");
            var choice = pending.Choices.FirstOrDefault(item => item.Id == parameters.ChoiceId);
            if (choice == null) throw Invalid("현재 결정에 없는 선택지입니다.");
            var effect = choice.Effect;
            var state = Next(parameters.State);
            state.Phase = ProCareerPhase.WeeklyPlan;
            state.Pitcher = Apply(effect, parameters.State.Pitcher);
            state.Role = effect.RoleTarget ?? parameters.State.Role;
            state.ManagerTrust = Clamp(parameters.State.ManagerTrust + effect.ManagerTrustDelta, 0, 100);
            state.CatcherTrust = Clamp(parameters.State.CatcherTrust + effect.CatcherTrustDelta, 0, 100);
            state.Fatigue = Clamp(parameters.State.Fatigue + effect.FatigueDelta, 0, 100);
            state.News = (new[] { pending.Title + " · " + choice.Title + " — " + effect.Summary }).Concat(parameters.State.News).Take(30).ToArray();
            state.PendingDecision = null;
            state.DecisionHistory = history.Concat(new[] { new ProDecisionRecord(pending.Id, pending.Type, pending.Season, pending.Week, choice.Id, choice.Title, effect) }).ToArray();
            return Result(state, parameters.Seed, new[] { "pro_season_decision_resolved" });
        }

        public ProCareerResult ResolveImportantGame(ResolveProGameParams parameters)
        {
            Validate(parameters.State, ProCareerPhase.ImportantGame);
            var rng = new SplitMix64(Seed(parameters.Seed));
            var report = parameters.Report;
            var soundProcess = report.ActualDamage <= report.ExpectedDamage + 150 || report.RecommendationAccepted * 2 >= report.Pitches;
            var sequenceReward = (parameters.State.BalanceVersion ?? 1) >= 4 ? PitchSequenceMasteryRules.TrustReward(report.SequenceMasteryCount) : 0;
            var trust = Clamp(parameters.State.ManagerTrust + report.Strikeouts * 2 - report.Walks * 2 - report.RunsAllowed * 3 + (soundProcess ? 2 : 0) + sequenceReward, 0, 100);
            var outs = report.Outs ?? Math.Max(3, report.Pitches / 5);
            var started = parameters.State.Role == ProRole.Starter;
            int support;
            int opponentRuns;
            if (report.ScoreDifferentialAtEntry.HasValue)
            {
                var opponentEarlier = rng.NextInt(4);
                var lateTeam = rng.NextInt(3);
                var lateBullpen = started ? rng.NextInt(3) : 0;
                opponentRuns = opponentEarlier + report.RunsAllowed + lateBullpen;
                support = Math.Max(0, opponentEarlier + report.ScoreDifferentialAtEntry.Value + lateTeam);
            }
            else
            {
                support = report.TeamRuns ?? LeagueBaseline.TeamRuns(ref rng);
                opponentRuns = report.RunsAllowed + LeagueBaseline.RestOfTeamRuns(Math.Max(0, 27 - outs), ref rng);
            }
            var decision = DecisionRules.Decide(started, parameters.State.Role == ProRole.Closer, outs, report.RunsAllowed, support, opponentRuns);
            var prior = RecoverStatEvidence(parameters.State.CurrentStats, parameters.State.GameLines);
            var stats = new ProSeasonStats(prior.Season, prior.TeamId, prior.Games + 1, prior.Starts + (started ? 1 : 0),
                prior.InningsOuts + outs, prior.Strikeouts + report.Strikeouts, prior.Walks + report.Walks,
                prior.RunsAllowed + report.RunsAllowed, prior.Wins + (decision == PitchingDecision.Win ? 1 : 0),
                prior.Losses + (decision == PitchingDecision.Loss ? 1 : 0), prior.Saves + (decision == PitchingDecision.Save ? 1 : 0),
                hits: AddKnown(prior.Hits, report.Hits),
                homeRuns: AddKnown(prior.HomeRuns, report.HomeRuns),
                pitches: AddKnown(prior.Pitches, report.Pitches),
                qualityStarts: AddKnown(prior.QualityStarts,
                    PitchingMetrics.IsQualityStart(started, outs, report.RunsAllowed) ? 1 : 0));
            var line = ProGameLineAdapter.Create(parameters.State.Season, parameters.State.Week,
                (parameters.State.GameLines == null ? 0 : parameters.State.GameLines.Count) + 1,
                started, outs, report.Strikeouts, report.Walks, report.RunsAllowed, report.Pitches,
                support, opponentRuns, decision, true, report.Hits, report.HomeRuns);
            var delta = trust - parameters.State.ManagerTrust;
            var evaluation = soundProcess ? "고른 구종과 코스도 좋았다는 평가를 받았습니다." : "경기 결과와 별개로 구종 순서를 다시 맞춥니다.";
            var mastery = sequenceReward > 0 ? " 수싸움 적중으로 감독과 포수의 믿음 +" + sequenceReward + "." : string.Empty;
            var foe = parameters.State.CurrentRival == null ? string.Empty : parameters.State.CurrentRival.Name + "(" + parameters.State.CurrentRival.TeamName + ") 상대 · ";
            var headline = "승부처 등판 · " + foe + report.Strikeouts + "탈삼진 · " + report.Walks + "볼넷 · " + report.RunsAllowed + "실점 · 감독의 믿음 " + (delta >= 0 ? "+" : string.Empty) + delta + ". " + evaluation + mastery;
            var state = Next(parameters.State);
            state.Phase = ProCareerPhase.WeeklyPlan;
            state.ManagerTrust = trust;
            state.CatcherTrust = Clamp(parameters.State.CatcherTrust + (soundProcess ? 2 : -1) + sequenceReward, 0, 100);
            state.CurrentStats = stats;
            state.GameLines = (parameters.State.GameLines ?? new ProGameLine[0]).Concat(new[] { line }).ToArray();
            state.Milestones = parameters.State.Level == ProLevel.Major ? AddUnique("1군 첫 중요 승부", parameters.State.Milestones) : parameters.State.Milestones.ToArray();
            state.News = (new[] { headline }).Concat(parameters.State.News).Take(30).ToArray();
            state.SeasonTrigger = null;
            state.CurrentRival = null;
            return Result(state, rng.Next().ToString(CultureInfo.InvariantCulture), new[] { "pro_important_game_resolved" });
        }

        public ProCareerResult ReviewSeason(ProStateParams parameters)
        {
            Validate(parameters.State, ProCareerPhase.SeasonReview);
            var rng = new SplitMix64(Seed(parameters.Seed));
            var state = Next(parameters.State);
            state.CurrentStats = RecoverStatEvidence(state.CurrentStats, state.GameLines);
            var runsPerNine = state.CurrentStats.InningsOuts == 0 ? 9990 : state.CurrentStats.RunsAllowed * 27000 / state.CurrentStats.InningsOuts;
            var awards = state.Awards.ToArray();
            if (state.CurrentStats.Strikeouts >= 120) awards = AddUnique("시즌 " + state.Season + " 탈삼진상", awards);
            if (runsPerNine < 3000 && state.CurrentStats.Games >= 20) awards = AddUnique("시즌 " + state.Season + " 최소 실점상", awards);
            var walksPerNine = state.CurrentStats.InningsOuts == 0
                ? 9990
                : state.CurrentStats.Walks * 27000 / state.CurrentStats.InningsOuts;
            if (walksPerNine < 2500 && state.CurrentStats.InningsOuts >= 180)
                awards = AddUnique("시즌 " + state.Season + " 정밀 제구상", awards);
            if (state.CurrentStats.Hits.HasValue)
            {
                var hitsPerNine = state.CurrentStats.InningsOuts == 0
                    ? 9990
                    : state.CurrentStats.Hits.Value * 27000 / state.CurrentStats.InningsOuts;
                if (hitsPerNine < 8500 && state.CurrentStats.InningsOuts >= 180)
                    awards = AddUnique("시즌 " + state.Season + " 피안타 억제상", awards);
            }
            if (state.CurrentStats.InningsOuts >= 360)
                awards = AddUnique("시즌 " + state.Season + " 이닝 책임상", awards);
            state.Awards = awards;
            state.Milestones = AddUnique(state.Season + "시즌 완주", state.Milestones);
            state.Phase = state.Season >= 12 || state.Age >= 37 ? ProCareerPhase.RetirementDecision : ProCareerPhase.OffseasonDecision;
            var rate = ((double)runsPerNine / 1000).ToString("F2", CultureInfo.InvariantCulture);
            state.News = (new[] { "시즌 " + state.Season + " 종료 · " + state.CurrentStats.Games + "경기 · " + state.CurrentStats.Strikeouts + "K · 9이닝당 실점 " + rate }).Concat(state.News).Take(30).ToArray();
            state.CareerStats = state.CareerStats.Concat(new[] { state.CurrentStats }).ToArray();
            return Result(state, rng.Next().ToString(CultureInfo.InvariantCulture), new[] { "pro_season_reviewed" });
        }

        public ProCareerResult ChooseOffseason(ProOffseasonParams parameters)
        {
            if (parameters.State.Phase != ProCareerPhase.OffseasonDecision && parameters.State.Phase != ProCareerPhase.RetirementDecision)
                throw Invalid("지금은 오프시즌 선택을 할 수 없습니다.");
            ValidateState(parameters.State);
            var rng = new SplitMix64(Seed(parameters.Seed));
            var source = parameters.State;
            if (parameters.Decision == OffseasonDecision.Retire || source.Phase == ProCareerPhase.RetirementDecision)
            {
                var score = HallOfFameScore(source);
                var retired = Next(source);
                retired.Phase = ProCareerPhase.Completed;
                retired.Milestones = AddUnique("은퇴 · 통산 " + source.CareerStats.Count + "시즌", source.Milestones);
                retired.News = RetirementRetrospective(source, score).Concat(source.News).ToArray();
                retired.HallOfFameScore = score;
                return Result(retired, rng.Next().ToString(CultureInfo.InvariantCulture), new[] { "pro_career_retired" });
            }
            var age = source.Age + 1;
            var military = source.MilitaryCompleted;
            var service = source.ServiceYears + (source.Level == ProLevel.Major ? 1 : 0);
            var team = source.Team;
            var news = source.News.ToList();
            if (parameters.Decision == OffseasonDecision.MilitaryService)
            {
                if (military) throw Invalid("이미 군 복무를 마쳤습니다.");
                age++;
                military = true;
                news.Insert(0, "두 시즌의 군 복무를 마치고 복귀했습니다.");
            }
            else if (parameters.Decision == OffseasonDecision.FreeAgency)
            {
                if (service < 6) throw Invalid("FA 신청에는 1군 등록 6년이 필요합니다.");
                var index = ProTeams.ToList().FindIndex(value => value.Id == source.Team.Id);
                team = ProTeams[((index < 0 ? 0 : index) + 3) % ProTeams.Count];
                news.Insert(0, "FA 계약: " + team.Name + "과 새 도전을 시작합니다.");
            }
            var season = source.Season + 1;
            var decline = age >= 33 ? 1 : 0;
            var pitcher = decline == 0 ? source.Pitcher : new PitcherSnapshot(source.Pitcher.Id, source.Pitcher.Name,
                Clamp(source.Pitcher.Stuff - decline, 20, 80), source.Pitcher.Command, source.Pitcher.Movement,
                Clamp(source.Pitcher.Stamina - decline, 20, 80), source.Pitcher.PitchProfiles, source.Pitcher.ThrowingHand);
            var oldContract = source.Contract;
            var contract = new ProContractSnapshot(Math.Max(1, (oldContract == null ? 1 : oldContract.YearsRemaining) - 1),
                Math.Max(oldContract == null ? 40000000 : oldContract.AnnualSalary, 40000000 + service * 50000000), source.Role);
            var state = Next(source);
            state.Phase = ProCareerPhase.WeeklyPlan;
            state.Pitcher = pitcher;
            state.Team = team;
            state.Age = age;
            state.Season = season;
            state.Week = 0;
            state.Fatigue = 0;
            state.InjuryWeeks = 0;
            state.ServiceYears = service;
            state.MilitaryCompleted = military;
            state.Contract = contract;
            state.CurrentStats = new ProSeasonStats(
                season, team.Id,
                hits: 0, homeRuns: 0, pitches: 0, qualityStarts: 0);
            state.GameLines = new ProGameLine[0];
            state.News = news.Take(30).ToArray();
            state.PendingDecision = null;
            var tensions = SeasonTensions(state);
            state.News = (new[] { TensionHeadline(tensions) }).Concat(state.News).Take(30).ToArray();
            state.SeasonSegment = ProSeasonSegment.SpringCamp;
            state.SeasonTrigger = null;
            state.CurrentRival = null;
            state.SeasonTensions = tensions;
            state.SeasonImportantGames = 0;
            return Result(state, rng.Next().ToString(CultureInfo.InvariantCulture), new[] { "pro_offseason_resolved" });
        }

        public ProSeasonDecision SeasonDecision(ProCareerSnapshot state, int week)
        {
            var slot = SeasonDecisionWeeks.ToList().IndexOf(week);
            if (slot < 0) return null;
            var types = Enum.GetValues(typeof(ProSeasonDecisionType)).Cast<ProSeasonDecisionType>().ToArray();
            var offset = (int)(StableHash.Fnv1A64Value(state.ProCareerId + "|season" + state.Season + "|season-decisions") % (ulong)types.Length);
            var type = types[(offset + slot) % types.Length];
            var content = DecisionContent(type);
            return new ProSeasonDecision("season-" + state.Season + "-week-" + week + "-" + type.Value(), type,
                state.Season, week, content.Title, content.Detail, content.Choices);
        }

        public string Commitment(ProCareerSnapshot state)
        {
            var values = new List<string>
            {
                state.ProCareerId,
                state.Revision.ToString(CultureInfo.InvariantCulture),
                state.Phase.Value(),
                state.Team.Id,
                state.Age.ToString(CultureInfo.InvariantCulture),
                state.Season.ToString(CultureInfo.InvariantCulture),
                state.Week.ToString(CultureInfo.InvariantCulture),
                state.Level.Value(),
                state.Role.Value(),
                state.ManagerTrust.ToString(CultureInfo.InvariantCulture),
                state.Fatigue.ToString(CultureInfo.InvariantCulture),
                state.CurrentStats.Games.ToString(CultureInfo.InvariantCulture),
                state.CurrentStats.Strikeouts.ToString(CultureInfo.InvariantCulture),
                state.CareerStats.Count.ToString(CultureInfo.InvariantCulture)
            };
            if (state.BalanceVersion.HasValue) values.Add("balance_version:" + state.BalanceVersion.Value);
            if (state.DevelopmentProgress != null)
            {
                values.Add("development:" + state.DevelopmentProgress.Stuff + ":" +
                    state.DevelopmentProgress.Command + ":" + state.DevelopmentProgress.Movement + ":" +
                    state.DevelopmentProgress.Stamina);
            }
            if (state.PendingDecision != null) values.Add("pending_decision:" + DecisionCommitment(state.PendingDecision));
            if (state.DecisionHistory != null && state.DecisionHistory.Count > 0)
            {
                var records = string.Join(",", state.DecisionHistory.Select(RecordCommitment));
                values.Add("decision_history:" + state.DecisionHistory.Count + ":" + StableHash.Fnv1A64(records));
            }
            return StableHash.Fnv1A64(string.Join("|", values));
        }

        private sealed class DecisionContentValue
        {
            public DecisionContentValue(string title, string detail, IReadOnlyList<ProSeasonDecisionChoice> choices)
            { Title = title; Detail = detail; Choices = choices; }
            public string Title { get; }
            public string Detail { get; }
            public IReadOnlyList<ProSeasonDecisionChoice> Choices { get; }
        }

        private static DecisionContentValue DecisionContent(ProSeasonDecisionType type)
        {
            switch (type)
            {
                case ProSeasonDecisionType.ExtraBullpen:
                    return Content("추가 불펜", "정규 훈련이 끝난 뒤 마운드 사용 시간이 남았습니다.",
                        Choice(type, "high_intensity", "강하게 더 던진다", "구위와 변화구를 함께 끌어올립니다.", new ProDecisionEffect(1, movementDelta: 1, fatigueDelta: 14)),
                        Choice(type, "shape_work", "변화구만 다듬는다", "부담을 줄이고 변화구 감각에 집중합니다.", new ProDecisionEffect(movementDelta: 1, fatigueDelta: 7)),
                        Choice(type, "rest", "오늘은 멈춘다", "성장 대신 몸을 회복합니다.", new ProDecisionEffect(fatigueDelta: -16)));
                case ProSeasonDecisionType.CatcherGamePlan:
                    return Content("포수와 경기 계획", "다음 등판의 구종 순서와 승부 방식을 정합니다.",
                        Choice(type, "battery_plan", "포수와 함께 짠다", "배터리 호흡과 코스 실행을 우선합니다.", new ProDecisionEffect(commandDelta: 1, catcherTrustDelta: 8, fatigueDelta: 4)),
                        Choice(type, "staff_report", "감독 보고서를 따른다", "벤치가 원하는 경기 운영에 맞춥니다.", new ProDecisionEffect(managerTrustDelta: 7, catcherTrustDelta: 1, fatigueDelta: 3)),
                        Choice(type, "own_sequence", "내 공을 밀어붙인다", "변화구 감각을 얻는 대신 두 사람의 믿음을 겁니다.", new ProDecisionEffect(movementDelta: 1, managerTrustDelta: -2, catcherTrustDelta: -3, fatigueDelta: 5)));
                case ProSeasonDecisionType.RoleMeeting:
                    return Content("역할 면담", "코칭스태프가 남은 시즌의 등판 역할을 묻습니다.",
                        Choice(type, "hold_role", "현재 역할을 지킨다", "익숙한 준비 리듬을 유지합니다.", new ProDecisionEffect(managerTrustDelta: 3, fatigueDelta: -4)),
                        Choice(type, "challenge_starter", "선발에 도전한다", "긴 이닝 준비와 경쟁 부담을 받아들입니다.", new ProDecisionEffect(staminaDelta: 1, managerTrustDelta: -3, fatigueDelta: 10, roleTarget: ProRole.Starter)),
                        Choice(type, "focus_relief", "구원에 집중한다", "짧은 등판의 구위와 포수 호흡을 택합니다.", new ProDecisionEffect(stuffDelta: 1, catcherTrustDelta: 3, fatigueDelta: 6, roleTarget: ProRole.LongRelief)));
                case ProSeasonDecisionType.RecordChase:
                    return Content("기록 추격", "개인 기록과 팀에 필요한 투구 사이에서 훈련 방향을 고릅니다.",
                        Choice(type, "strikeouts", "탈삼진을 노린다", "결정구 두 가지를 강하게 연마합니다.", new ProDecisionEffect(stuffDelta: 1, movementDelta: 1, fatigueDelta: 12)),
                        Choice(type, "run_prevention", "실점 억제를 택한다", "제구와 배터리 운영을 다듬습니다.", new ProDecisionEffect(commandDelta: 1, catcherTrustDelta: 4, fatigueDelta: 7)),
                        Choice(type, "body_management", "몸을 관리한다", "긴 시즌을 버틸 체력과 회복을 택합니다.", new ProDecisionEffect(staminaDelta: 1, fatigueDelta: -12)));
                case ProSeasonDecisionType.RivalAnalysis:
                    return Content("라이벌 분석", "다음 맞대결을 앞두고 분석 시간을 어디에 쓸지 정합니다.",
                        Choice(type, "attack_weakness", "약점을 깊게 판다", "포수와 코스를 정교하게 맞춥니다.", new ProDecisionEffect(commandDelta: 1, catcherTrustDelta: 5, fatigueDelta: 6)),
                        Choice(type, "keep_strength", "내 장점을 유지한다", "구위와 변화구 완성도를 높입니다.", new ProDecisionEffect(stuffDelta: 1, movementDelta: 1, fatigueDelta: 8)),
                        Choice(type, "defer", "맞대결까지 보류한다", "추가 훈련 없이 몸을 가볍게 만듭니다.", new ProDecisionEffect(fatigueDelta: -8)));
                default:
                    return Content("시즌 막바지", "순위 경쟁과 회복, 동료 지원 사이에서 마지막 힘을 배분합니다.",
                        Choice(type, "push_race", "순위 경쟁에 건다", "감독의 믿음을 얻는 대신 피로를 감수합니다.", new ProDecisionEffect(managerTrustDelta: 8, fatigueDelta: 14)),
                        Choice(type, "recover_first", "회복을 우선한다", "출전 의지를 의심받더라도 몸을 회복합니다.", new ProDecisionEffect(managerTrustDelta: -2, fatigueDelta: -18)),
                        Choice(type, "support_youth", "젊은 선수를 돕는다", "벤치와 배터리의 신뢰를 함께 쌓습니다.", new ProDecisionEffect(managerTrustDelta: 4, catcherTrustDelta: 6, fatigueDelta: 3)));
            }
        }

        private static DecisionContentValue Content(string title, string detail, params ProSeasonDecisionChoice[] choices)
        { return new DecisionContentValue(title, detail, choices); }
        private static ProSeasonDecisionChoice Choice(ProSeasonDecisionType type, string suffix, string title, string detail, ProDecisionEffect effect)
        { return new ProSeasonDecisionChoice(type.Value() + "." + suffix, title, detail, effect); }

        private static ProSeasonTrigger? ImportantGameTrigger(ProCareerSnapshot state, int nextWeek, ProLevel level, int trust, int strikeouts, int skill, int priorImportantGames)
        {
            if (priorImportantGames >= 6) return null;
            if (state.Level == ProLevel.Minor && level == ProLevel.Major) return ProSeasonTrigger.MajorDebut;
            var segment = Segment(nextWeek);
            if (segment == ProSeasonSegment.Opening && nextWeek == AnchorWeek(state, "opening", 2, 4)) return ProSeasonTrigger.OpeningStatement;
            if (segment == ProSeasonSegment.SeasonFinale && nextWeek == AnchorWeek(state, "finale", 21, 23)) return ProSeasonTrigger.StandingsRace;
            if (level == ProLevel.Minor && skill >= 44 && state.ManagerTrust < 57 && trust >= 57) return ProSeasonTrigger.CallUpAudition;
            foreach (var mark in SeasonStrikeoutMarks)
                if (state.CurrentStats.Strikeouts < mark && strikeouts >= mark) return ProSeasonTrigger.RecordChase;
            if (level == ProLevel.Major)
                foreach (var band in new[] { 63, 75 }) if (state.ManagerTrust < band && trust >= band) return ProSeasonTrigger.RoleShowdown;
            return null;
        }

        private static int AnchorWeek(ProCareerSnapshot state, string salt, int lower, int upper)
        {
            return lower + (int)(StableHash.Fnv1A64Value(state.ProCareerId + "|season" + state.Season + "|" + salt) % (ulong)(upper - lower + 1));
        }

        private static ProSeasonSegment Segment(int week)
        {
            if (week < 1) return ProSeasonSegment.SpringCamp;
            if (week <= 4) return ProSeasonSegment.Opening;
            if (week <= 10) return ProSeasonSegment.FirstHalf;
            if (week <= 13) return ProSeasonSegment.AllStarBreak;
            if (week <= 20) return ProSeasonSegment.PennantRace;
            return ProSeasonSegment.SeasonFinale;
        }

        public static string SegmentLabel(ProSeasonSegment segment)
        {
            switch (segment)
            {
                case ProSeasonSegment.SpringCamp: return "스프링캠프";
                case ProSeasonSegment.Opening: return "개막";
                case ProSeasonSegment.FirstHalf: return "전반기";
                case ProSeasonSegment.AllStarBreak: return "올스타 휴식기";
                case ProSeasonSegment.PennantRace: return "순위 경쟁";
                default: return "시즌 결말";
            }
        }

        private static string SegmentEntryNews(ProSeasonSegment segment)
        {
            switch (segment)
            {
                case ProSeasonSegment.SpringCamp: return "스프링캠프가 열렸습니다. 새 시즌 준비를 시작합니다.";
                case ProSeasonSegment.Opening: return "개막 시리즈가 시작됐습니다. 첫인상을 남길 시간입니다.";
                case ProSeasonSegment.FirstHalf: return "전반기 레이스에 들어섰습니다. 긴 시즌의 리듬을 잡습니다.";
                case ProSeasonSegment.AllStarBreak: return "올스타 휴식기입니다. 몸을 추스르고 후반기를 준비합니다.";
                case ProSeasonSegment.PennantRace: return "순위 경쟁이 뜨거워집니다. 한 경기의 무게가 커집니다.";
                default: return "시즌 막바지, 마지막 순위 싸움이 남았습니다.";
            }
        }

        private static string ImportantMomentHeadline(ProSeasonTrigger trigger, ProRivalBatter rival, ProLevel level)
        {
            var foe = rival == null ? "상대 팀 중심타자" : rival.TeamName + " " + rival.Name;
            switch (trigger)
            {
                case ProSeasonTrigger.MajorDebut: return "처음으로 1군 마운드에 오릅니다. " + foe + "와의 승부가 기다립니다.";
                case ProSeasonTrigger.OpeningStatement: return "개막 시리즈 선발 맞대결. " + foe + " 앞에서 올 시즌 첫인상을 만듭니다.";
                case ProSeasonTrigger.CallUpAudition: return "콜업이 눈앞입니다. " + foe + "를 막으면 1군 문이 열립니다.";
                case ProSeasonTrigger.RecordChase: return "기록에 다가서는 등판. " + foe + "를 상대로 탈삼진을 쌓습니다.";
                case ProSeasonTrigger.RoleShowdown: return foe + "와의 승부로 다음 역할이 갈립니다.";
                default: return "순위가 걸린 한 경기. " + foe + "를 넘어야 가을이 보입니다.";
            }
        }

        private static ProRivalBatter RivalForGame(ProCareerSnapshot state, int week, ProSeasonTrigger trigger)
        {
            var hash = StableHash.Fnv1A64Value(state.Team.Id + "|season" + state.Season + "|week" + week + "|" + trigger.Value());
            var index = (int)(hash % (ulong)RivalBatters.Count);
            if (RivalBatters[index].TeamId == state.Team.Id) index = (index + 1) % RivalBatters.Count;
            return RivalBatters[index];
        }

        private static IReadOnlyList<ProSeasonTension> SeasonTensions(ProCareerSnapshot state)
        {
            var skill = (state.Pitcher.Stuff + state.Pitcher.Command + state.Pitcher.Movement + state.Pitcher.Stamina) / 4;
            var role = new ProSeasonTension("role", state.Team.PositionCompetitor + "와의 자리 싸움", ProDecisionEffect.RoleLabel(state.Role) + " 한 자리를 두고 시즌 내내 성적을 견줍니다.");
            var goal = state.Level == ProLevel.Major ? Math.Max(120, skill * 2) : Math.Max(80, skill * 3 / 2);
            var record = new ProSeasonTension("record", "시즌 " + goal + "탈삼진", "한 시즌 개인 기록을 새로 쓰는 것이 목표입니다.");
            var rival = RivalForGame(state, 0, ProSeasonTrigger.StandingsRace);
            var rivalTension = new ProSeasonTension("rival", rival.Name + " 맞대결", rival.TeamName + "의 " + rival.Archetype + ". 올 시즌 몇 번이고 마운드에서 마주칩니다.");
            return new[] { role, record, rivalTension };
        }

        private static string TensionHeadline(IReadOnlyList<ProSeasonTension> values)
        { return "올해의 세 가지 긴장 · " + string.Join(" · ", values.Select(value => value.Title)); }

        private static void AddCareerMarks(ProCareerSnapshot source, int games, int strikeouts, ref string[] milestones)
        {
            var priorGames = source.CareerStats.Sum(item => item.Games) + source.CurrentStats.Games;
            var nextGames = priorGames + games;
            foreach (var mark in new[] { 50, 100, 300 }) if (priorGames < mark && nextGames >= mark) milestones = AddUnique("프로 통산 " + mark + "경기", milestones);
            var priorStrikeouts = source.CareerStats.Sum(item => item.Strikeouts) + source.CurrentStats.Strikeouts;
            var nextStrikeouts = priorStrikeouts + strikeouts;
            foreach (var mark in new[] { 50, 100, 200, 500 }) if (priorStrikeouts < mark && nextStrikeouts >= mark) milestones = AddUnique("프로 통산 " + mark + "탈삼진", milestones);
        }

        private sealed class DevelopmentResolution
        {
            public DevelopmentResolution(PitcherSnapshot pitcher, ProDevelopmentProgress progress, IReadOnlyList<string> growthLabels)
            { Pitcher = pitcher; Progress = progress; GrowthLabels = growthLabels; }
            public PitcherSnapshot Pitcher { get; }
            public ProDevelopmentProgress Progress { get; }
            public IReadOnlyList<string> GrowthLabels { get; }
        }

        private static DevelopmentResolution ResolveDevelopment(
            PitcherSnapshot pitcher,
            ProDevelopmentProgress progress,
            ProWeekPlan plan,
            PitchType? targetPitch,
            bool paused)
        {
            if(paused||plan==ProWeekPlan.Recover||plan==ProWeekPlan.EarnTrust)
                return new DevelopmentResolution(pitcher,progress,new string[0]);
            var stuff=progress.Stuff;
            var command=progress.Command;
            var movement=progress.Movement;
            var stamina=progress.Stamina;
            var value=pitcher;
            var labels=new List<string>();
            Action<ProWeekPlan> advance=focus=>
            {
                if(focus==ProWeekPlan.DevelopStuff)
                {
                    if(stuff==0)stuff=1;else{stuff=0;value=PitcherGrowthRules.Grow(value,TrainingFocus.Velocity,1);labels.Add("구위 +1");}
                }
                else if(focus==ProWeekPlan.RefineCommand)
                {
                    if(command==0)command=1;else{command=0;value=PitcherGrowthRules.Grow(value,TrainingFocus.Command,1);labels.Add("제구 +1");}
                }
                else if(focus==ProWeekPlan.DevelopMovement)
                {
                    if(movement==0)movement=1;else{movement=0;value=PitcherGrowthRules.Grow(value,TrainingFocus.BreakingBall,1,targetPitch);labels.Add("변화구 +1");}
                }
                else if(focus==ProWeekPlan.BuildStamina)
                {
                    if(stamina==0)stamina=1;else{stamina=0;value=PitcherGrowthRules.Grow(value,TrainingFocus.Stamina,1);labels.Add("체력 +1");}
                }
            };
            if(plan==ProWeekPlan.DevelopWeapon)
            {
                advance(ProWeekPlan.DevelopStuff);
                advance(ProWeekPlan.DevelopMovement);
            }
            else advance(plan);
            return new DevelopmentResolution(value,new ProDevelopmentProgress(stuff,command,movement,stamina),labels);
        }

        private static PitcherSnapshot Apply(ProDecisionEffect effect, PitcherSnapshot pitcher)
        {
            return new PitcherSnapshot(pitcher.Id, pitcher.Name,
                Clamp(pitcher.Stuff + effect.StuffDelta, 20, 80), Clamp(pitcher.Command + effect.CommandDelta, 20, 80),
                Clamp(pitcher.Movement + effect.MovementDelta, 20, 80), Clamp(pitcher.Stamina + effect.StaminaDelta, 20, 80),
                pitcher.PitchProfiles, pitcher.ThrowingHand);
        }

        private static int HallOfFameScore(ProCareerSnapshot state)
        {
            var strikeouts = state.CareerStats.Sum(item => item.Strikeouts);
            var outs = state.CareerStats.Sum(item => item.InningsOuts);
            var decisions = state.CareerStats.Sum(item => item.Wins + item.Saves);
            var qualitySeasons = state.CareerStats.Count(season =>
                season.InningsOuts >= 180 &&
                season.RunsAllowed * 27000 / Math.Max(1, season.InningsOuts) < 4000);
            return Clamp(
                strikeouts / 150 +
                outs / 300 +
                decisions / 12 +
                qualitySeasons * 2 +
                state.Awards.Count * 8 +
                state.ServiceYears * 3,
                0,
                100);
        }

        private static IReadOnlyList<string> RetirementRetrospective(ProCareerSnapshot state, int score)
        {
            var lines = new List<string> { score >= 70 ? "명예의 전당 헌액이 확정됐습니다." : "은퇴식에서 선수 생활의 마지막 공을 돌아봤습니다." };
            if (state.CareerStats.Count > 0)
            {
                var games = state.CareerStats.Sum(item => item.Games);
                var strikeouts = state.CareerStats.Sum(item => item.Strikeouts);
                var outs = state.CareerStats.Sum(item => item.InningsOuts);
                var runs = state.CareerStats.Sum(item => item.RunsAllowed);
                var rate = (outs == 0 ? 0D : (double)(runs * 27000 / outs) / 1000).ToString("F2", CultureInfo.InvariantCulture);
                lines.Add("통산 " + state.CareerStats.Count + "시즌 · " + games + "경기 · " + strikeouts + "탈삼진 · 9이닝당 실점 " + rate);
                var best = state.CareerStats.OrderByDescending(item => item.Strikeouts).First();
                if (best.Strikeouts > 0) lines.Add("가장 빛난 해는 " + best.Season + "시즌 — " + best.Games + "경기에서 " + best.Strikeouts + "개의 탈삼진을 잡았습니다.");
            }
            if (state.Milestones.Count > 0)
            {
                var award = state.Awards.Count == 0 ? string.Empty : " · 마지막 수상: " + state.Awards[state.Awards.Count - 1];
                lines.Add("첫 기록: " + state.Milestones[0] + award);
            }
            lines.Add("마지막 공은 " + state.Team.Name + "의 유니폼으로 던졌습니다.");
            return lines;
        }

        private void Validate(ProCareerSnapshot state, ProCareerPhase phase)
        {
            if (state.Phase != phase) throw Invalid("expected " + phase.Value() + ", got " + state.Phase.Value());
            ValidateState(state);
        }

        private void ValidateState(ProCareerSnapshot state)
        {
            if (!ValidStats(state.CurrentStats) || state.CareerStats == null ||
                state.CareerStats.Any(value => !ValidStats(value)))
                throw Invalid("pro season statistics are invalid");
            if ((state.Phase == ProCareerPhase.SeasonDecision) != (state.PendingDecision != null)) throw Invalid("season decision phase and pending decision must match");
            if (state.PendingDecision != null)
            {
                var pending = state.PendingDecision;
                if (pending.Season != state.Season || pending.Week != state.Week) throw Invalid("pending decision season or week mismatch");
                if (pending.Choices.Count != 3 || pending.Choices.Select(item => item.Id).Distinct().Count() != 3) throw Invalid("pending decision requires three unique choices");
                ValidatePendingDecision(pending);
            }
            if (state.DecisionHistory != null && state.DecisionHistory.Count > 0)
            {
                if (state.DecisionHistory.Select(item => item.DecisionId).Distinct().Count() != state.DecisionHistory.Count) throw Invalid("decision history contains duplicate decisions");
                if (state.DecisionHistory.Any(item => !SeasonDecisionWeeks.Contains(item.Week) || string.IsNullOrEmpty(item.ChoiceId))) throw Invalid("decision history contains an invalid record");
                if (state.DecisionHistory.GroupBy(item => item.Season).Any(group => group.Count() > MaximumSeasonDecisions)) throw Invalid("decision history exceeds the season limit");
            }
            if (state.Commitment != Commitment(state)) throw Invalid("state commitment mismatch");
        }

        private static bool ValidStats(ProSeasonStats value)
        {
            return value != null && value.Games >= 0 && value.Starts >= 0 &&
                value.Starts <= value.Games && value.InningsOuts >= 0 &&
                value.Strikeouts >= 0 && value.Walks >= 0 && value.RunsAllowed >= 0 &&
                value.Wins >= 0 && value.Losses >= 0 && value.Saves >= 0 &&
                (!value.Hits.HasValue || value.Hits.Value >= 0) &&
                (!value.HomeRuns.HasValue || value.HomeRuns.Value >= 0) &&
                (!value.Pitches.HasValue || value.Pitches.Value >= 0) &&
                (!value.QualityStarts.HasValue ||
                 value.QualityStarts.Value >= 0 && value.QualityStarts.Value <= value.Starts);
        }

        private static void ValidatePendingDecision(ProSeasonDecision pending)
        {
            if (!SeasonDecisionWeeks.Contains(pending.Week)) throw Invalid("pending decision week is not scheduled");
            if (pending.Id != "season-" + pending.Season + "-week-" + pending.Week + "-" + pending.Type.Value()) throw Invalid("pending decision id mismatch");
            if (string.IsNullOrWhiteSpace(pending.Title) || string.IsNullOrWhiteSpace(pending.Detail)) throw Invalid("pending decision copy is empty");
            var prefix = pending.Type.Value() + ".";
            foreach (var choice in pending.Choices)
            {
                var suffix = choice.Id.StartsWith(prefix, StringComparison.Ordinal) ? choice.Id.Substring(prefix.Length) : string.Empty;
                if (!choice.Id.StartsWith(prefix, StringComparison.Ordinal) || !StableIdentifier(suffix)) throw Invalid("pending decision choice id mismatch");
                if (string.IsNullOrWhiteSpace(choice.Title) || string.IsNullOrWhiteSpace(choice.Detail)) throw Invalid("pending decision choice copy is empty");
                if (!Reasonable(choice.Effect)) throw Invalid("pending decision effect is out of range");
            }
        }

        private static bool StableIdentifier(string value)
        { return value.Length > 0 && value.All(character => character >= 'a' && character <= 'z' || character >= '0' && character <= '9' || character == '_'); }
        private static bool Reasonable(ProDecisionEffect effect)
        {
            return new[] { effect.StuffDelta, effect.CommandDelta, effect.MovementDelta, effect.StaminaDelta }.All(value => value >= -4 && value <= 4) &&
                new[] { effect.ManagerTrustDelta, effect.CatcherTrustDelta }.All(value => value >= -20 && value <= 20) &&
                effect.FatigueDelta >= -30 && effect.FatigueDelta <= 30;
        }

        private static string DecisionCommitment(ProSeasonDecision decision)
        {
            var values = new List<string> { decision.Id, decision.Type.Value(), decision.Season.ToString(), decision.Week.ToString(), decision.Title, decision.Detail, decision.Choices.Count.ToString() };
            values.AddRange(decision.Choices.Select(ChoiceCommitment));
            return StableHash.Fnv1A64(string.Join("|", values));
        }
        private static string ChoiceCommitment(ProSeasonDecisionChoice choice)
        { return StableHash.Fnv1A64(string.Join("|", new[] { choice.Id, choice.Title, choice.Detail, EffectCommitment(choice.Effect) })); }
        private static string RecordCommitment(ProDecisionRecord record)
        { return StableHash.Fnv1A64(string.Join("|", new[] { record.DecisionId, record.Type.Value(), record.Season.ToString(), record.Week.ToString(), record.ChoiceId, record.ChoiceTitle, EffectCommitment(record.Effect) })); }
        private static string EffectCommitment(ProDecisionEffect effect)
        {
            return string.Join(",", new[] { effect.StuffDelta, effect.CommandDelta, effect.MovementDelta, effect.StaminaDelta, effect.ManagerTrustDelta, effect.CatcherTrustDelta, effect.FatigueDelta }.Select(value => value.ToString(CultureInfo.InvariantCulture))) + "," +
                (effect.RoleTarget.HasValue ? effect.RoleTarget.Value.Value() : "-");
        }

        private ProCareerResult Result(ProCareerSnapshot state, string nextSeed, IReadOnlyList<string> events)
        { Sign(state); return new ProCareerResult(state, nextSeed, events); }
        private void Sign(ProCareerSnapshot state) { state.Commitment = Commitment(state); }
        private static ProCareerSnapshot Next(ProCareerSnapshot state) { var value = state.Clone(); value.Revision++; return value; }
        private static string[] AddUnique(string value, IReadOnlyList<string> values)
        { return values.Contains(value) ? values.ToArray() : values.Concat(new[] { value }).ToArray(); }
        private static ProRivalBatter Rival(string id, string name, string archetype, string teamId, string teamName, string record, string profile)
        { return new ProRivalBatter(id, name, archetype, teamId, teamName, record, profile); }
        private static ulong Seed(string value)
        { ulong parsed; if (!ulong.TryParse(value, NumberStyles.None, CultureInfo.InvariantCulture, out parsed)) throw new SimulationException(SimulationErrorCode.InvalidSeed, "invalid seed: " + value); return parsed; }
        private static SimulationException Invalid(string message) { return new SimulationException(SimulationErrorCode.InvalidGameState, message); }
        private static ProSeasonStats RecoverStatEvidence(
            ProSeasonStats stats,
            IReadOnlyList<ProGameLine> gameLines)
        {
            var lines = (gameLines ?? new ProGameLine[0]).ToArray();
            if (lines.Length != stats.Games) return stats;
            var hits = stats.Hits ?? KnownSum(lines.Select(value => value.Hits));
            var homeRuns = stats.HomeRuns ?? KnownSum(lines.Select(value => value.HomeRuns));
            var pitches = stats.Pitches ?? lines.Sum(value => value.Pitches);
            var qualityStarts = stats.QualityStarts ?? lines.Count(value =>
                PitchingMetrics.IsQualityStart(value.Started, value.Outs, value.RunsAllowed));
            if (hits == stats.Hits && homeRuns == stats.HomeRuns &&
                pitches == stats.Pitches && qualityStarts == stats.QualityStarts)
                return stats;
            return new ProSeasonStats(
                stats.Season,
                stats.TeamId,
                stats.Games,
                stats.Starts,
                stats.InningsOuts,
                stats.Strikeouts,
                stats.Walks,
                stats.RunsAllowed,
                stats.Wins,
                stats.Losses,
                stats.Saves,
                hits,
                homeRuns,
                pitches,
                qualityStarts);
        }
        private static int? KnownSum(IEnumerable<int?> values)
        {
            var items = values.ToArray();
            return items.All(value => value.HasValue)
                ? items.Sum(value => value.Value)
                : (int?)null;
        }
        private static int? AddKnown(int? prior, int value)
        { return prior.HasValue ? prior.Value + value : (int?)null; }
        private static int? AddKnown(int? prior, int? value)
        { return prior.HasValue && value.HasValue ? prior.Value + value.Value : (int?)null; }
        private static int? AddKnown(int? prior, IEnumerable<int?> values)
        {
            var items = values.ToArray();
            return prior.HasValue && items.All(value => value.HasValue)
                ? prior.Value + items.Sum(value => value.Value)
                : (int?)null;
        }
        private static int Clamp(int value, int lower, int upper) { return Math.Min(upper, Math.Max(lower, value)); }
    }
}
