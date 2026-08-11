using Baseball.Core.Domain;
using Baseball.Core.Pitching;

namespace Baseball.Presentation.Pitch
{
    /// <summary>Deterministic request fixture. This file is compiled only into EditMode tests.</summary>
    public static class PitchDemoRequestFactory
    {
        public static PitchPlayRequest Create(bool daily)
        {
            return Create(
                daily,
                daily ? "2026081109" : "2026081108",
                daily ? "daily-game" : "highschool-game",
                "한결",
                62,
                56,
                58,
                60);
        }

        public static PitchPlayRequest Create(
            bool daily,
            string seed,
            string gameId,
            string pitcherName,
            int stuff,
            int command,
            int movement,
            int stamina)
        {
            return new PitchPlayRequest(
                seed,
                Pitcher(pitcherName, stuff, command, movement, stamina),
                new BatterSnapshot("batter-doyun", "도윤", 57, 54, 61, BatSide.Right),
                new BatterScoutingSnapshot(
                    new PitchZone(1, 1),
                    new PitchZone(2, 0),
                    PitchType.FourSeam,
                    PitchType.Slider,
                    48),
                new PlateAppearanceContext(
                    daily ? "daily-pa-20260811" : "highschool-pa-1",
                    0,
                    daily ? 9 : 8,
                    daily ? 0 : 1,
                    0,
                    0,
                    1,
                    1,
                    daily ? 920 : 810,
                    daily ? 28 : 42),
                gameState: GameStateSnapshot.Standard,
                gameLog: new GameLogSnapshot(gameId, 0, 0, System.Array.Empty<PitchAnalysisEntry>()));
        }

        private static PitcherSnapshot Pitcher(
            string name,
            int stuff,
            int command,
            int movement,
            int stamina)
        {
            return new PitcherSnapshot(
                "pitcher-hangyeol",
                string.IsNullOrWhiteSpace(name) ? "투수" : name,
                stuff,
                command,
                movement,
                stamina,
                new[]
                {
                    new PitchProfileSnapshot(PitchType.FourSeam, PitchUsageRole.Primary, 1450, 59, 58, 55, 62, 55, 1),
                    new PitchProfileSnapshot(PitchType.Slider, PitchUsageRole.Secondary, 1320, 57, 56, 63, 64, 61, 1),
                    new PitchProfileSnapshot(PitchType.Curveball, PitchUsageRole.Secondary, 1210, 55, 54, 65, 57, 62, 1),
                    new PitchProfileSnapshot(PitchType.Changeup, PitchUsageRole.Development, 1280, 52, 51, 57, 55, 60, 1),
                });
        }
    }
}
