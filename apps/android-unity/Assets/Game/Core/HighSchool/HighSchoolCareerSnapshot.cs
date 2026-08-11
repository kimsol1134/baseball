using System;
using System.Collections.Generic;
using System.Linq;
using Baseball.Core.Domain;

namespace Baseball.Core.HighSchool
{
    public sealed class HighSchoolCareerSnapshot
    {
        internal HighSchoolCareerSnapshot() { }
        public string CareerId { get; internal set; }
        public ulong Revision { get; internal set; }
        public int LifeNumber { get; internal set; }
        public HighSchoolCareerPhase Phase { get; internal set; }
        public PlayerIdentitySnapshot Identity { get; internal set; }
        public CareerDifficultySnapshot Difficulty { get; internal set; }
        public IReadOnlyList<KarmaId> Karmas { get; internal set; }
        public int LegacyRewardPermille { get; internal set; }
        public int MemorySlots { get; internal set; }
        public PitcherSnapshot Pitcher { get; internal set; }
        public IReadOnlyList<SchoolSnapshot> SchoolOptions { get; internal set; }
        public SchoolSnapshot School { get; internal set; }
        public RivalSnapshot Rival { get; internal set; }
        public CareerChapterSnapshot Chapter { get; internal set; }
        public int ChapterTrainingCount { get; internal set; }
        public int TotalTrainingsCompleted { get; internal set; }
        public int MilestoneIndex { get; internal set; }
        public int RelationshipsCompleted { get; internal set; }
        public int RelationshipTrust { get; internal set; }
        public int? ManagerTrust { get; internal set; }
        public int? CatcherTrust { get; internal set; }
        public int? RivalTrust { get; internal set; }
        public IReadOnlyList<AwakeningId> SelectedAwakenings { get; internal set; }
        public IReadOnlyList<AwakeningId> AwakeningOptions { get; internal set; }
        public int Fatigue { get; internal set; }
        public CareerPerformanceSnapshot Performance { get; internal set; }
        public IReadOnlyList<ProGameLine> SeasonLog { get; internal set; }
        public ImportantGameScenarioContent CurrentGameScenario { get; internal set; }
        public CareerEventContent CurrentRelationshipEvent { get; internal set; }
        public CareerTrainingSnapshot LastTraining { get; internal set; }
        public CareerRelationshipResultSnapshot LastRelationship { get; internal set; }
        public IReadOnlyList<string> News { get; internal set; }
        public int FanInterest { get; internal set; }
        public DraftResultSnapshot DraftResult { get; internal set; }
        public IReadOnlyList<MemoryCardId> LegacyOptions { get; internal set; }
        public IReadOnlyList<MemoryCardId> SelectedMemories { get; internal set; }
        public int? BalanceVersion { get; internal set; }
        public int? WorldRulesVersion { get; internal set; }
        public int? ArmRisk { get; internal set; }
        public int? InjuryRecovery { get; internal set; }
        public CareerScheduleSnapshot Schedule { get; internal set; }
        public TrainingOpportunitySnapshot TrainingOpportunity { get; internal set; }
        public TalentSnapshot Talent { get; internal set; }
        public IReadOnlyList<string> SoulBoosts { get; internal set; }
        public int? AwakeningSparks { get; internal set; }
        public string StateCommitment { get; internal set; }
        public CareerRulesVersion EffectiveWorldRulesVersion => WorldRulesVersion == 2 ? CareerRulesVersion.V2 : CareerRulesVersion.V1;
        public CareerWind CareerWind => CareerWind.For(CareerId, EffectiveWorldRulesVersion);

        internal HighSchoolCareerSnapshot Clone()
        {
            return new HighSchoolCareerSnapshot {
                CareerId=CareerId,Revision=Revision,LifeNumber=LifeNumber,Phase=Phase,Identity=Identity,Difficulty=Difficulty,Karmas=Karmas.ToArray(),LegacyRewardPermille=LegacyRewardPermille,MemorySlots=MemorySlots,Pitcher=Pitcher,SchoolOptions=SchoolOptions.ToArray(),School=School,Rival=Rival,Chapter=Chapter,ChapterTrainingCount=ChapterTrainingCount,TotalTrainingsCompleted=TotalTrainingsCompleted,MilestoneIndex=MilestoneIndex,RelationshipsCompleted=RelationshipsCompleted,RelationshipTrust=RelationshipTrust,ManagerTrust=ManagerTrust,CatcherTrust=CatcherTrust,RivalTrust=RivalTrust,SelectedAwakenings=SelectedAwakenings.ToArray(),AwakeningOptions=AwakeningOptions.ToArray(),Fatigue=Fatigue,Performance=Performance,SeasonLog=SeasonLog==null?null:SeasonLog.ToArray(),CurrentGameScenario=CurrentGameScenario,CurrentRelationshipEvent=CurrentRelationshipEvent,LastTraining=LastTraining,LastRelationship=LastRelationship,News=News.ToArray(),FanInterest=FanInterest,DraftResult=DraftResult,LegacyOptions=LegacyOptions.ToArray(),SelectedMemories=SelectedMemories.ToArray(),BalanceVersion=BalanceVersion,WorldRulesVersion=WorldRulesVersion,ArmRisk=ArmRisk,InjuryRecovery=InjuryRecovery,Schedule=Schedule,TrainingOpportunity=TrainingOpportunity,Talent=Talent,SoulBoosts=SoulBoosts==null?null:SoulBoosts.ToArray(),AwakeningSparks=AwakeningSparks,StateCommitment=StateCommitment
            };
        }
    }

    public sealed class StartHighSchoolCareerParams
    {
        public StartHighSchoolCareerParams(string seed,string presetId,int lifeNumber=1,CreationAllocationSnapshot creationAllocation=null,int inheritedSoulPoints=0,SoulDomain? inheritedSoulDomain=null,IReadOnlyList<MemoryCardId> inheritedMemories=null,PlayerIdentitySnapshot identity=null,CareerDifficultySnapshot difficulty=null,IReadOnlyList<KarmaId> karmas=null,IReadOnlyList<SoulBoostId> soulBoosts=null,int? inheritedSoulTotal=null,CareerSignatureLegacyId? signatureLegacyId=null,int? inheritanceRulesVersion=null)
        {Seed=seed;PresetId=presetId;LifeNumber=lifeNumber;CreationAllocation=creationAllocation??CreationAllocationSnapshot.Balanced;InheritedSoulPoints=inheritedSoulPoints;InheritedSoulDomain=inheritedSoulDomain;InheritedMemories=inheritedMemories??new MemoryCardId[0];Identity=identity??PlayerIdentitySnapshot.DefaultPitcher;Difficulty=difficulty??CareerDifficultySnapshot.Standard;Karmas=karmas??new KarmaId[0];SoulBoosts=soulBoosts;InheritedSoulTotal=inheritedSoulTotal;SignatureLegacyId=signatureLegacyId;InheritanceRulesVersion=inheritanceRulesVersion;}
        public string Seed{get;}public string PresetId{get;}public int LifeNumber{get;}public CreationAllocationSnapshot CreationAllocation{get;}public int InheritedSoulPoints{get;}public SoulDomain? InheritedSoulDomain{get;}public IReadOnlyList<MemoryCardId> InheritedMemories{get;}public PlayerIdentitySnapshot Identity{get;}public CareerDifficultySnapshot Difficulty{get;}public IReadOnlyList<KarmaId> Karmas{get;}public IReadOnlyList<SoulBoostId> SoulBoosts{get;}public int? InheritedSoulTotal{get;}public CareerSignatureLegacyId? SignatureLegacyId{get;}public int? InheritanceRulesVersion{get;}
    }
    public sealed class ChooseSchoolParams { public ChooseSchoolParams(string seed,HighSchoolCareerSnapshot state,SchoolId schoolId){Seed=seed;State=state;SchoolId=schoolId;}public string Seed{get;}public HighSchoolCareerSnapshot State{get;}public SchoolId SchoolId{get;} }
    public sealed class CommitCareerTrainingParams
    {
        public CommitCareerTrainingParams(
            string seed,
            HighSchoolCareerSnapshot state,
            TrainingFocus focus,
            TrainingIntensity intensity,
            PitchType? targetPitch = null)
        {
            Seed = seed;
            State = state;
            Focus = focus;
            Intensity = intensity;
            TargetPitch = targetPitch;
        }

        public string Seed { get; }
        public HighSchoolCareerSnapshot State { get; }
        public TrainingFocus Focus { get; }
        public TrainingIntensity Intensity { get; }
        public PitchType? TargetPitch { get; }
    }

    public sealed class CommitCareerTrainingBlockParams
    {
        public CommitCareerTrainingBlockParams(
            string seed,
            HighSchoolCareerSnapshot state,
            TrainingFocus focus,
            TrainingIntensity intensity,
            PitchType? targetPitch = null,
            int maximumSessions = 3)
        {
            Seed = seed;
            State = state;
            Focus = focus;
            Intensity = intensity;
            TargetPitch = targetPitch;
            MaximumSessions = maximumSessions;
        }

        public string Seed { get; }
        public HighSchoolCareerSnapshot State { get; }
        public TrainingFocus Focus { get; }
        public TrainingIntensity Intensity { get; }
        public PitchType? TargetPitch { get; }
        public int MaximumSessions { get; }
    }

    public sealed class HighSchoolTrainingBlockResult
    {
        public HighSchoolTrainingBlockResult(
            HighSchoolCareerResult career,
            CareerTrainingBlockSnapshot block)
        {
            Career = career;
            Block = block;
        }

        public HighSchoolCareerResult Career { get; }
        public CareerTrainingBlockSnapshot Block { get; }
    }
    public sealed class ResolveCareerRelationshipParams { public ResolveCareerRelationshipParams(string seed,HighSchoolCareerSnapshot state,RelationshipResponse response){Seed=seed;State=state;Response=response;}public string Seed{get;}public HighSchoolCareerSnapshot State{get;}public RelationshipResponse Response{get;} }
    public sealed class RecordCareerGameParams { public RecordCareerGameParams(string seed,HighSchoolCareerSnapshot state,ImportantInningReport report){Seed=seed;State=state;Report=report;}public string Seed{get;}public HighSchoolCareerSnapshot State{get;}public ImportantInningReport Report{get;} }
    public sealed class ChooseCareerAwakeningParams { public ChooseCareerAwakeningParams(string seed,HighSchoolCareerSnapshot state,AwakeningId awakening){Seed=seed;State=state;Awakening=awakening;}public string Seed{get;}public HighSchoolCareerSnapshot State{get;}public AwakeningId Awakening{get;} }
    public sealed class AdvanceCareerChapterParams { public AdvanceCareerChapterParams(string seed,HighSchoolCareerSnapshot state){Seed=seed;State=state;}public string Seed{get;}public HighSchoolCareerSnapshot State{get;} }
    public sealed class ResolveDraftParams { public ResolveDraftParams(string seed,HighSchoolCareerSnapshot state){Seed=seed;State=state;}public string Seed{get;}public HighSchoolCareerSnapshot State{get;} }
    public sealed class SelectCareerLegacyParams { public SelectCareerLegacyParams(string seed,HighSchoolCareerSnapshot state,IReadOnlyList<MemoryCardId> memoryCards,CareerSignatureLegacyId? signatureLegacyId=null){Seed=seed;State=state;MemoryCards=memoryCards;SignatureLegacyId=signatureLegacyId;}public string Seed{get;}public HighSchoolCareerSnapshot State{get;}public IReadOnlyList<MemoryCardId> MemoryCards{get;}public CareerSignatureLegacyId? SignatureLegacyId{get;} }
    public sealed class HighSchoolCareerEvent { public HighSchoolCareerEvent(string eventType,int sequence=0,IReadOnlyList<string> reasonCodes=null){EventType=eventType;Sequence=sequence;ReasonCodes=reasonCodes??new string[0];}public string EventType{get;}public int Sequence{get;}public IReadOnlyList<string> ReasonCodes{get;} }
    public sealed class HighSchoolCareerResult { public HighSchoolCareerResult(ulong revision,string nextSeed,IReadOnlyList<HighSchoolCareerEvent> events,HighSchoolCareerSnapshot snapshot,string eventHash){Revision=revision;NextSeed=nextSeed;Events=events;Snapshot=snapshot;EventHash=eventHash;}public ulong Revision{get;}public string NextSeed{get;}public IReadOnlyList<HighSchoolCareerEvent> Events{get;}public HighSchoolCareerSnapshot Snapshot{get;}public string EventHash{get;} }
    public sealed class DraftEvaluationComponents { public DraftEvaluationComponents(int ratingScore,int performanceScore,int processBonus,int awakeningScore,int relationshipScore,int seasonTerm,int karmaPenalty,int overusePenalty,int fanTerm,int windDelta){RatingScore=ratingScore;PerformanceScore=performanceScore;ProcessBonus=processBonus;AwakeningScore=awakeningScore;RelationshipScore=relationshipScore;SeasonTerm=seasonTerm;KarmaPenalty=karmaPenalty;OverusePenalty=overusePenalty;FanTerm=fanTerm;WindDelta=windDelta;}public int RatingScore{get;}public int PerformanceScore{get;}public int ProcessBonus{get;}public int AwakeningScore{get;}public int RelationshipScore{get;}public int SeasonTerm{get;}public int KarmaPenalty{get;}public int OverusePenalty{get;}public int FanTerm{get;}public int WindDelta{get;}public int Total=>RatingScore+PerformanceScore+ProcessBonus+AwakeningScore+RelationshipScore+SeasonTerm+FanTerm+WindDelta-KarmaPenalty-OverusePenalty; }
    public sealed class DraftForecastSnapshot { public DraftForecastSnapshot(int score,int threshold,string band,string interestedTeam){Score=score;Threshold=threshold;Band=band;InterestedTeam=interestedTeam;}public int Score{get;}public int Threshold{get;}public string Band{get;}public string InterestedTeam{get;} }
    public enum TrainingGrowthOutlook { Wall, None, ZeroOrOne, One, OneOrTwo, Two }
}
