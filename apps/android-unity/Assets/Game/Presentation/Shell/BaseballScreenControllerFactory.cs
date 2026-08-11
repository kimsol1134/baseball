using System;
using Baseball.Presentation.HighSchool;
using Baseball.Presentation.Meta;
using Baseball.Presentation.Opening;
using Baseball.Presentation.Pro;
using Baseball.Presentation.Records;
using Baseball.Presentation.Settings;
using Baseball.Presentation.Setup;

namespace Baseball.Presentation.Shell
{
    public static class BaseballScreenControllerFactory
    {
        public static IBaseballScreenController Create(ShellRoute route)
        {
            switch (route)
            {
                case ShellRoute.Opening:
                    return new OpeningScreenController();
                case ShellRoute.Setup:
                    return new SetupScreenController();
                case ShellRoute.Prologue:
                case ShellRoute.HighSchoolOverview:
                case ShellRoute.Training:
                case ShellRoute.Relationship:
                case ShellRoute.ImportantGame:
                case ShellRoute.PitchHandoff:
                case ShellRoute.Awakening:
                case ShellRoute.Draft:
                case ShellRoute.RunRecap:
                    return new HighSchoolScreenController(route);
                case ShellRoute.ProContract:
                case ShellRoute.ProWeek:
                case ShellRoute.ProSeason:
                case ShellRoute.ProRetirement:
                    return new ProScreenController(route);
                case ShellRoute.Weekly:
                    return new MetaScreenController(route);
                case ShellRoute.Records:
                case ShellRoute.League:
                case ShellRoute.Achievements:
                case ShellRoute.LifeArchive:
                case ShellRoute.LifeCard:
                    return new RecordsScreenController(route);
                case ShellRoute.Settings:
                    return new SettingsScreenController();
                default:
                    throw new ArgumentOutOfRangeException(nameof(route), route, null);
            }
        }
    }
}
