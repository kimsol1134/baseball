using System;

namespace Baseball.Presentation.Pitch
{
    /// <summary>Pure address and portrait-cover rules for the production pitch stage artwork.</summary>
    public static class PitchStageVisualPolicy
    {
        public const string StadiumAddress = "baseball/highschool/KeyArtStadiumNight";
        public const string BatterAddress = "baseball/pitch/BatterStance";
        public const string CatcherAddress = "baseball/pitch/CatcherStance";

        public static bool HasRequiredSprites(bool stadium, bool batter, bool catcher) =>
            stadium && batter && catcher;

        public static float CoverScale(
            float spriteWidth,
            float spriteHeight,
            float cameraDistance,
            float verticalFieldOfViewDegrees,
            float aspectRatio)
        {
            if (spriteWidth <= 0f || spriteHeight <= 0f || cameraDistance <= 0f ||
                verticalFieldOfViewDegrees <= 0f || verticalFieldOfViewDegrees >= 179f ||
                aspectRatio <= 0f)
            {
                throw new ArgumentOutOfRangeException(nameof(spriteWidth));
            }
            double radians = verticalFieldOfViewDegrees * Math.PI / 180d;
            double viewportHeight = 2d * cameraDistance * Math.Tan(radians * 0.5d);
            double viewportWidth = viewportHeight * aspectRatio;
            return (float)Math.Max(viewportWidth / spriteWidth, viewportHeight / spriteHeight);
        }
    }
}
