namespace Baseball.Application.HighSchool
{
    /// <summary>
    /// Application-owned phases. They deliberately do not serialize the evolving Core snapshot.
    /// A Core adapter may translate these values while saves remain stable across engine changes.
    /// </summary>
    public enum HighSchoolPhase
    {
        Prologue,
        SchoolSelection,
        Training,
        Relationship,
        ImportantGame,
        Awakening,
        ChapterReview,
        Draft,
        Legacy,
        Completed
    }

    public enum LegacySelectionMode
    {
        Memories,
        SignatureLegacy
    }
}
