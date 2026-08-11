using System.Linq;
using Baseball.Core.Domain;
using NUnit.Framework;

namespace Baseball.Core.HighSchool.Tests
{
    [TestFixture]
    public sealed class HighSchoolDeterminismTests
    {
        [TestCase("career-20260811-life-1")]
        [TestCase("career-42-life-3")]
        [TestCase("fixture-korean-고교")]
        public void ScheduleIsDeterministicAndInsideSwiftBounds(string careerId)
        {
            var first = HighSchoolCareerEngine.MakeSchedule(careerId);
            var replay = HighSchoolCareerEngine.MakeSchedule(careerId);
            Assert.That(replay.CommitmentToken, Is.EqualTo(first.CommitmentToken));
            Assert.That(first.TrainingTotal, Is.InRange(12, 16));
            Assert.That(first.RelationshipTotal, Is.InRange(4, 6));
            Assert.That(first.ImportantGameTotal, Is.InRange(4, 6));
            Assert.That(first.AwakeningTotal, Is.EqualTo(3));
            Assert.That(first.TrainingsByChapter.All(x => x >= 1), Is.True);
            Assert.That(first.MilestonesByChapter[7], Is.EqualTo(new[] { HighSchoolCareerPhase.Awakening, HighSchoolCareerPhase.ImportantGame }));
        }

        [Test]
        public void StartAndEveryTransitionReplayBitForBit()
        {
            var engine = new HighSchoolCareerEngine();
            var a = engine.Start(new StartHighSchoolCareerParams("20260811", "precision_commander"));
            var b = engine.Start(new StartHighSchoolCareerParams("20260811", "precision_commander"));
            Assert.That(b.NextSeed, Is.EqualTo(a.NextSeed));
            Assert.That(b.EventHash, Is.EqualTo(a.EventHash));
            Assert.That(b.Snapshot.StateCommitment, Is.EqualTo(a.Snapshot.StateCommitment));

            var a2 = engine.CompletePrologue(new AdvanceCareerChapterParams(a.NextSeed, a.Snapshot));
            var b2 = engine.CompletePrologue(new AdvanceCareerChapterParams(b.NextSeed, b.Snapshot));
            Assert.That(b2.EventHash, Is.EqualTo(a2.EventHash));
            Assert.That(b2.Snapshot.Phase, Is.EqualTo(HighSchoolCareerPhase.SchoolSelection));
        }

        [Test]
        public void SwiftStartFixtureMatchesSeedCommitmentAndEventHash()
        {
            var engine = new HighSchoolCareerEngine();
            var started = engine.Start(
                new StartHighSchoolCareerParams("20260811", "precision_commander"));
            Assert.That(started.NextSeed, Is.EqualTo("17440580331433762222"));
            Assert.That(started.Snapshot.Rival.Id, Is.EqualTo("rival-home-run"));
            Assert.That(started.Snapshot.CareerWind.Id, Is.EqualTo("command_year"));
            Assert.That(started.Snapshot.StateCommitment, Is.EqualTo("90cddd4ec353d34e"));
            Assert.That(started.EventHash, Is.EqualTo("82a005036875b27d"));

            var prologue = engine.CompletePrologue(
                new AdvanceCareerChapterParams(started.NextSeed, started.Snapshot));
            AssertSwiftTransition(prologue, HighSchoolCareerPhase.SchoolSelection,
                "1169930280521511745", "55aa0ccc931c92ab", "9d526191d3380801",
                36, 44, 36, 39, 5);

            var school = engine.ChooseSchool(
                new ChooseSchoolParams(prologue.NextSeed, prologue.Snapshot, SchoolId.MiraeAnalytics));
            AssertSwiftTransition(school, HighSchoolCareerPhase.Training,
                "13694056169205714311", "4a1dd6a0c8326c88", "6fc646f77c7cb69d",
                36, 44, 36, 39, 5);

            var training = engine.CommitTraining(
                new CommitCareerTrainingParams(school.NextSeed, school.Snapshot, TrainingFocus.Command, TrainingIntensity.Standard));
            AssertSwiftTransition(training, HighSchoolCareerPhase.Training,
                "14727619764395285174", "fa1c5a90797e4922", "d4a44330e3099c94",
                36, 46, 36, 39, 13);
        }

        [Test]
        public void ProspectBracketBuzzAndGoalUseIndependentStableSalts()
        {
            var performance = new CareerPerformanceSnapshot(4, 100, 24, 2, 2);
            var board = ProspectRanking.Board("career-20260811-life-1", "민서준", "서울배성고", performance);
            var bracket = TournamentBracket.GetField("career-20260811-life-1", 4, "서울배성고");
            var buzz = CommunityBuzz.Reactions("career-20260811-life-1", 4, 7, 1, 0);
            var goal = ChapterGoal.Get("career-20260811-life-1", 4);
            Assert.That(ProspectRanking.Board("career-20260811-life-1", "민서준", "서울배성고", performance).Select(x => x.Name), Is.EqualTo(board.Select(x => x.Name)));
            Assert.That(TournamentBracket.GetField("career-20260811-life-1", 4, "서울배성고").Schools, Is.EqualTo(bracket.Schools));
            Assert.That(CommunityBuzz.Reactions("career-20260811-life-1", 4, 7, 1, 0), Is.EqualTo(buzz));
            Assert.That(ChapterGoal.Get("career-20260811-life-1", 4).Detail, Is.EqualTo(goal.Detail));
        }

        [Test]
        public void SwiftSameSeedFixtureMatchesExactKoreanPayload()
        {
            const string career = "career-20260811-life-1";
            var schedule = HighSchoolCareerEngine.MakeSchedule(career);
            Assert.That(schedule.CommitmentToken, Is.EqualTo(
                "2,2,2,2,1,3,1,2|awakening,important_game;relationship,awakening;important_game,relationship;important_game,relationship;important_game;relationship;relationship,relationship;awakening,important_game"));

            var goal = ChapterGoal.Get(career, 4);
            Assert.That(goal.Title, Is.EqualTo("나와의 약속"));
            Assert.That(goal.TargetStrikeouts, Is.EqualTo(8));
            Assert.That(goal.Detail, Is.EqualTo("소등 전에 적어 둔 한 줄 — 이번 이야기, 삼진 8개."));

            var bracket = TournamentBracket.GetField(career, 4, "서울배성고");
            Assert.That(bracket.Schools, Is.EqualTo(new[] { "서령고", "북부상고", "서울배성고", "삼도고", "백파고", "청암고", "금강고", "동성공고" }));
            Assert.That(bracket.TournamentName, Is.EqualTo("전국 화랑기"));

            var performance = new CareerPerformanceSnapshot(4, 100, 24, 2, 2);
            var board = ProspectRanking.Board(career, "민서준", "서울배성고", performance);
            Assert.That(ProspectRanking.PlayerRank(performance), Is.EqualTo(9));
            Assert.That(board.Select(x => x.Name), Is.EqualTo(new[] { "정예준", "이영웅", "이은찬", "서성민", "정은찬", "안석현", "이준서", "김서준", "민서준", "배동주", "안동주", "신은찬", "안성민", "유성민", "정성민", "박지호", "최현빈", "고우진", "차도현", "김태윤" }));

            Assert.That(CommunityBuzz.Reactions(career, 4, 7, 1, 0), Is.EqualTo(new[] {
                "오늘 경기 직관했는데 상대 타자들이 공을 아예 못 봄",
                "저 선수 몇 학년임? 체격 좋아 보이던데",
                "다음 경기 언제임? 직관 가고 싶은데"
            }));
        }

        private static void AssertSwiftTransition(
            HighSchoolCareerResult result,
            HighSchoolCareerPhase phase,
            string nextSeed,
            string stateCommitment,
            string eventHash,
            int stuff,
            int command,
            int movement,
            int stamina,
            int fatigue)
        {
            Assert.That(result.Snapshot.Phase, Is.EqualTo(phase));
            Assert.That(result.NextSeed, Is.EqualTo(nextSeed));
            Assert.That(result.Snapshot.StateCommitment, Is.EqualTo(stateCommitment));
            Assert.That(result.EventHash, Is.EqualTo(eventHash));
            Assert.That(result.Snapshot.Pitcher.Stuff, Is.EqualTo(stuff));
            Assert.That(result.Snapshot.Pitcher.Command, Is.EqualTo(command));
            Assert.That(result.Snapshot.Pitcher.Movement, Is.EqualTo(movement));
            Assert.That(result.Snapshot.Pitcher.Stamina, Is.EqualTo(stamina));
            Assert.That(result.Snapshot.Fatigue, Is.EqualTo(fatigue));
        }
    }
}
