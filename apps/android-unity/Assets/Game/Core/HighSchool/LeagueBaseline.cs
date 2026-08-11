using System;
using Baseball.Core.Random;

namespace Baseball.Core.HighSchool
{
    public static class LeagueBaseline
    {
        public static readonly int[] TeamRunsPerGamePermille={62,104,131,138,135,119,95,70,50,34,22,14,9,6,4,3,2,1,1};
        public static readonly int[] HighSchoolRunsPerGamePermille={70,92,112,124,126,116,100,80,62,45,32,21,13,7,0};
        public const int MinimumOutsForStarterWin=15, SaveLeadCeiling=3;
        public static int TeamRuns(ref SplitMix64 rng)=>Draw(ref rng,TeamRunsPerGamePermille);
        public static int HighSchoolTeamRuns(ref SplitMix64 rng)=>Draw(ref rng,HighSchoolRunsPerGamePermille);
        public static int RestOfTeamRuns(int outsCovered,ref SplitMix64 rng)=>TeamRuns(ref rng)*Math.Max(0,outsCovered)/27;
        public static int RestOfHighSchoolTeamRuns(int outsCovered,ref SplitMix64 rng)=>HighSchoolTeamRuns(ref rng)*Math.Max(0,outsCovered)/27;
        private static int Draw(ref SplitMix64 rng,int[] weights){var roll=rng.NextInt(1000);var sum=0;for(var i=0;i<weights.Length;i++){sum+=weights[i];if(roll<sum)return i;}return weights.Length-1;}
    }

    public sealed class ProGameLine
    {
        public ProGameLine(int season,int week,int outingNumber,bool started,int outs,int strikeouts,int walks,int runsAllowed,int pitches,int teamRuns,int opponentRuns,PitchingDecision decision,bool played,int? hits=null,int? homeRuns=null)
        {Season=season;Week=week;OutingNumber=outingNumber;Started=started;Outs=outs;Strikeouts=strikeouts;Walks=walks;RunsAllowed=runsAllowed;Pitches=pitches;TeamRuns=teamRuns;OpponentRuns=opponentRuns;Decision=decision;Played=played;Hits=hits;HomeRuns=homeRuns;}
        public int Season{get;}public int Week{get;}public int OutingNumber{get;}public bool Started{get;}public int Outs{get;}public int Strikeouts{get;}public int Walks{get;}public int RunsAllowed{get;}public int Pitches{get;}public int TeamRuns{get;}public int OpponentRuns{get;}public PitchingDecision Decision{get;}public bool Played{get;}public int? Hits{get;}public int? HomeRuns{get;}
        public string Id=>Season+"-"+OutingNumber; public string InningsText=>Outs/3+(Outs%3==0?"":"."+(Outs%3));
    }

    public static class DecisionRules
    {
        public static PitchingDecision Decide(bool started,bool isCloser,int outs,int runsAllowed,int teamRuns,int opponentRuns){var won=teamRuns>opponentRuns;var lost=teamRuns<opponentRuns;if(started){if(won)return outs>=LeagueBaseline.MinimumOutsForStarterWin?PitchingDecision.Win:PitchingDecision.NoDecision;return lost&&runsAllowed>0?PitchingDecision.Loss:PitchingDecision.NoDecision;}if(isCloser&&won&&runsAllowed==0&&teamRuns-opponentRuns<=LeagueBaseline.SaveLeadCeiling)return PitchingDecision.Save;if(lost&&runsAllowed>0)return PitchingDecision.Loss;return PitchingDecision.NoDecision;}
    }
}
