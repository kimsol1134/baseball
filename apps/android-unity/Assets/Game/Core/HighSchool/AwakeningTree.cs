using System;
using System.Collections.Generic;
using System.Linq;
using Baseball.Core.Domain;

namespace Baseball.Core.HighSchool
{
    public static class AwakeningTree
    {
        public enum Branch { Power, Command, Breaking, Game }
        public sealed class Node
        {
            public Node(AwakeningId id, Branch branch, int tier, params AwakeningId[] parents) { Id=id;Branch=branch;Tier=tier;Parents=parents; }
            public AwakeningId Id{get;} public Branch Branch{get;} public int Tier{get;} public IReadOnlyList<AwakeningId> Parents{get;}
        }
        public const int LeapSparks = 3;
        public static readonly IReadOnlyList<Node> Nodes = new[] {
            N(AwakeningId.ExplosiveFastball,Branch.Power,1), N(AwakeningId.RisingFourSeam,Branch.Power,2,AwakeningId.ExplosiveFastball), N(AwakeningId.IronArm,Branch.Power,2,AwakeningId.ExplosiveFastball), N(AwakeningId.LateInningReserve,Branch.Power,3,AwakeningId.IronArm),
            N(AwakeningId.PinpointEdge,Branch.Command,1), N(AwakeningId.RepeatableRelease,Branch.Command,2,AwakeningId.PinpointEdge), N(AwakeningId.FirstPitchStrike,Branch.Command,2,AwakeningId.PinpointEdge), N(AwakeningId.CalmUnderPressure,Branch.Command,3,AwakeningId.RepeatableRelease), N(AwakeningId.ScoutComposure,Branch.Command,3,AwakeningId.FirstPitchStrike),
            N(AwakeningId.DisappearingBreaker,Branch.Breaking,1), N(AwakeningId.SweepingSlider,Branch.Breaking,2,AwakeningId.DisappearingBreaker), N(AwakeningId.CurveballClock,Branch.Breaking,2,AwakeningId.DisappearingBreaker), N(AwakeningId.FrozenChangeup,Branch.Breaking,3,AwakeningId.SweepingSlider), N(AwakeningId.SinkerTunnel,Branch.Breaking,3,AwakeningId.CurveballClock),
            N(AwakeningId.BatterySync,Branch.Game,1), N(AwakeningId.TwoStrikePlan,Branch.Game,2,AwakeningId.BatterySync), N(AwakeningId.PickoffRhythm,Branch.Game,2,AwakeningId.BatterySync), N(AwakeningId.TrafficController,Branch.Game,3,AwakeningId.TwoStrikePlan)
        };
        public static Node GetNode(AwakeningId id) => Nodes.First(x => x.Id == id);
        public static Branch GetBranch(AwakeningId id) => GetNode(id).Branch;
        public static int GetTier(AwakeningId id) => GetNode(id).Tier;
        public static IReadOnlyList<AwakeningId> Available(IEnumerable<AwakeningId> selected, int? sparks)
        {
            var taken = new HashSet<AwakeningId>(selected ?? Enumerable.Empty<AwakeningId>());
            var canLeap = (sparks ?? LeapSparks) >= LeapSparks;
            return Nodes.Where(node => {
                if (taken.Contains(node.Id)) return false;
                var unmet = node.Parents.Where(x => !taken.Contains(x)).ToArray();
                if (unmet.Length == 0) return true;
                return canLeap && unmet.Length == node.Parents.Count && node.Parents.Count == 1 && taken.Any(x => GetBranch(x) == node.Branch);
            }).Select(x => x.Id).ToArray();
        }
        public static bool IsLeap(AwakeningId id, IEnumerable<AwakeningId> selected)
        { var taken=new HashSet<AwakeningId>(selected); return GetNode(id).Parents.Any(x=>!taken.Contains(x)); }
        public static Branch ForTrainingFocus(TrainingFocus focus)
        {
            switch(focus) { case TrainingFocus.Velocity: case TrainingFocus.Stamina:return Branch.Power; case TrainingFocus.Command: case TrainingFocus.Recovery:return Branch.Command; case TrainingFocus.BreakingBall:return Branch.Breaking; default:return Branch.Game; }
        }
        private static Node N(AwakeningId id,Branch branch,int tier,params AwakeningId[] parents)=>new Node(id,branch,tier,parents);
    }
}
