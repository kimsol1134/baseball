using System;
using System.Collections.Generic;

namespace Baseball.Presentation.Shell
{
    /// <summary>Copy/layout template. Production projections replace rows with saved domain values.</summary>
    public sealed class BaseballScreenTemplateReadModel : IBaseballCareerReadModel
    {
        private readonly IKoreanUiCopyCatalog _copy;
        private readonly Dictionary<ShellRoute, BaseballScreenViewModel> _screens;
        private readonly List<ShellRoute> _routes;

        public IReadOnlyList<ShellRoute> Routes => _routes;

        public BaseballScreenTemplateReadModel(IKoreanUiCopyCatalog copy)
        {
            _copy = copy ?? throw new ArgumentNullException(nameof(copy));
            _screens = BuildScreens();
            _routes = new List<ShellRoute>();
            foreach (ShellRoute route in (ShellRoute[])Enum.GetValues(typeof(ShellRoute)))
            {
                if (route == ShellRoute.Daily) continue;
                if (!_screens.ContainsKey(route)) throw new InvalidOperationException($"화면 계약이 없습니다: {route}");
                _routes.Add(route);
            }
        }

        public BaseballScreenViewModel Read(ShellRoute route)
        {
            if (!_screens.TryGetValue(route, out BaseballScreenViewModel screen)) throw new ArgumentOutOfRangeException(nameof(route), route, null);
            return screen;
        }

        private Dictionary<ShellRoute, BaseballScreenViewModel> BuildScreens()
        {
            var screens = new Dictionary<ShellRoute, BaseballScreenViewModel>();

            screens.Add(ShellRoute.Opening, Screen(Activate(ShellRoute.Opening), "opening", false,
                Sections(Section("promise", ScreenSectionTone.Information,
                    Row("detail"))),
                Actions(Primary("start", ShellRoute.Setup))));

            screens.Add(ShellRoute.Setup, Screen(Activate(ShellRoute.Setup), "setup", false,
                Sections(
                    Section("name", ScreenSectionTone.Plain, Row("name_value"), Row("name_detail")),
                    Section("region", ScreenSectionTone.Plain, Row("region_value"), Row("region_detail")),
                    Section("preset", ScreenSectionTone.Plain, Row("preset_value"), Row("preset_detail")),
                    Section("difficulty", ScreenSectionTone.Warning, Row("difficulty_value"), Row("handicap"))),
                Actions(Primary("continue", ShellRoute.Prologue), Secondary("direct_pro", ShellRoute.ProContract))));

            screens.Add(ShellRoute.Prologue, Screen(Activate(ShellRoute.Prologue), "highschool", false,
                Sections(
                    Section("arrival", ScreenSectionTone.Information, Row("arrival_detail")),
                    Section("ability", ScreenSectionTone.Plain, Row("fastball"), Row("control"), Row("stamina")),
                    Section("school", ScreenSectionTone.Milestone, Row("school_choice"), Row("school_detail"))),
                Actions(Primary("choose_school", ShellRoute.HighSchoolOverview), Secondary("reselect", ShellRoute.Setup))));

            screens.Add(ShellRoute.HighSchoolOverview, Screen(Activate(ShellRoute.HighSchoolOverview), "highschool", true,
                Sections(
                    Section("status", ScreenSectionTone.Plain, Row("chapter"), Row("health"), Row("opportunity")),
                    Section("next", ScreenSectionTone.Information, Row("next_detail")),
                    Section("record", ScreenSectionTone.Plain, Row("games"), Row("strikeouts"), Row("walks"))),
                Actions(Primary("train", ShellRoute.Training), Secondary("relationship", ShellRoute.Relationship))));

            screens.Add(ShellRoute.Training, Screen(Activate(ShellRoute.Training), "highschool", true,
                Sections(
                    Section("condition", ScreenSectionTone.Plain, Row("health"), Row("opportunity")),
                    Section("program", ScreenSectionTone.Information, Row("program_value"), Row("intensity"), Row("repeat"))),
                Actions(Primary("complete", ShellRoute.Relationship), Secondary("overview", ShellRoute.HighSchoolOverview))));

            screens.Add(ShellRoute.Relationship, Screen(Activate(ShellRoute.Relationship), "highschool", true,
                Sections(
                    Section("character", ScreenSectionTone.Information, Row("character_name"), Row("character_detail")),
                    Section("choice", ScreenSectionTone.Plain, Row("answer_one"), Row("answer_two"))),
                Actions(Primary("answer", ShellRoute.ImportantGame), Secondary("overview", ShellRoute.HighSchoolOverview))));

            screens.Add(ShellRoute.ImportantGame, Screen(Activate(ShellRoute.ImportantGame), "highschool", true,
                Sections(
                    Section("match", ScreenSectionTone.Warning, Row("opponent"), Row("situation"), Row("rival")),
                    Section("condition", ScreenSectionTone.Plain, Row("pitch_count"), Row("stamina"))),
                Actions(Primary("mound", ShellRoute.PitchHandoff), Secondary("overview", ShellRoute.HighSchoolOverview))));

            screens.Add(ShellRoute.PitchHandoff, Screen(Activate(ShellRoute.PitchHandoff), "highschool", false,
                Sections(
                    Section("handoff", ScreenSectionTone.Information, Row("handoff_detail")),
                    Section("durable", ScreenSectionTone.Positive, Row("commit_status"), Row("resume_detail"))),
                Actions(Primary("resume", ShellRoute.PitchHandoff), Secondary("back", ShellRoute.ImportantGame))));

            screens.Add(ShellRoute.Awakening, Screen(Activate(ShellRoute.Awakening), "highschool", true,
                Sections(
                    Section("count", ScreenSectionTone.Milestone, Row("remaining")),
                    Section("branch", ScreenSectionTone.Plain, Row("branch_value"), Row("branch_detail"))),
                Actions(Primary("confirm", ShellRoute.Draft), Secondary("reselect", ShellRoute.Awakening))));

            screens.Add(ShellRoute.Draft, Screen(Activate(ShellRoute.Draft), "highschool", false,
                Sections(
                    Section("evaluation", ScreenSectionTone.Milestone, Row("evaluation_detail"), Row("forecast")),
                    Section("record", ScreenSectionTone.Plain, Row("games"), Row("strikeouts"), Row("runs")),
                    Section("result", ScreenSectionTone.Positive, Row("result_detail"))),
                Actions(Primary("result", ShellRoute.RunRecap))));

            screens.Add(ShellRoute.RunRecap, Screen(Activate(ShellRoute.RunRecap), "highschool", false,
                Sections(
                    Section("growth", ScreenSectionTone.Positive, Row("fastball"), Row("control"), Row("movement"), Row("stamina")),
                    Section("legacy", ScreenSectionTone.Milestone, Row("legacy_value"), Row("legacy_detail")),
                    Section("memory", ScreenSectionTone.Information, Row("memory_detail"))),
                Actions(Primary("pro", ShellRoute.ProContract), Secondary("card", ShellRoute.LifeCard), Secondary("archive", ShellRoute.LifeArchive))));

            screens.Add(ShellRoute.ProContract, Screen(Activate(ShellRoute.ProContract), "pro", false,
                Sections(
                    Section("contract", ScreenSectionTone.Milestone, Row("club"), Row("role"), Row("contract_detail")),
                    Section("type", ScreenSectionTone.Plain, Row("type_value"), Row("type_detail"))),
                Actions(Primary("sign", ShellRoute.ProWeek))));

            screens.Add(ShellRoute.ProWeek, Screen(Activate(ShellRoute.ProWeek), "pro", true,
                Sections(
                    Section("todo", ScreenSectionTone.Information, Row("training"), Row("match"), Row("decision")),
                    Section("status", ScreenSectionTone.Plain, Row("week"), Row("condition"), Row("role")),
                    Section("recent", ScreenSectionTone.Plain, Row("recent_result"), Row("news"))),
                Actions(ConfirmPrimary("advance", ShellRoute.ProSeason), Secondary("league", ShellRoute.League))));

            screens.Add(ShellRoute.ProSeason, Screen(Activate(ShellRoute.ProSeason), "pro", true,
                Sections(
                    Section("season", ScreenSectionTone.Milestone, Row("season_record"), Row("award")),
                    Section("career", ScreenSectionTone.Plain, Row("career_games"), Row("career_strikeouts"), Row("hall"))),
                Actions(Primary("next", ShellRoute.ProRetirement), Secondary("week", ShellRoute.ProWeek))));

            screens.Add(ShellRoute.ProRetirement, Screen(Activate(ShellRoute.ProRetirement), "pro", false,
                Sections(
                    Section("retire", ScreenSectionTone.Warning, Row("retire_detail")),
                    Section("summary", ScreenSectionTone.Milestone, Row("seasons"), Row("career_record"), Row("hall"))),
                Actions(Destructive("retire", ShellRoute.Records, true), Secondary("continue", ShellRoute.ProWeek))));

            screens.Add(ShellRoute.Weekly, Screen(Activate(ShellRoute.Weekly), "meta", true,
                Sections(
                    Section("goals", ScreenSectionTone.Information, Row("goal_one"), Row("goal_two"), Row("goal_three")),
                    Section("rule", ScreenSectionTone.Plain, Row("rule_detail")),
                    Section("stamp", ScreenSectionTone.Positive, Row("stamp_status"))),
                Actions(Primary("claim", ShellRoute.Weekly))));

            screens.Add(ShellRoute.Records, Screen(Activate(ShellRoute.Records), "records", true,
                Sections(
                    Section("ability", ScreenSectionTone.Plain, Row("fastball"), Row("control"), Row("stamina")),
                    Section("scout", ScreenSectionTone.Information, Row("personality"), Row("forecast")),
                    Section("games", ScreenSectionTone.Plain, Row("record"), Row("awakenings"), Row("news"))),
                Actions(
                    Secondary("weekly", ShellRoute.Weekly),
                    Secondary("league", ShellRoute.League),
                    Secondary("achievements", ShellRoute.Achievements),
                    Secondary("archive", ShellRoute.LifeArchive))));

            screens.Add(ShellRoute.League, Screen(Activate(ShellRoute.League), "records", true,
                Sections(
                    Section("standings", ScreenSectionTone.Plain, Row("first"), Row("second"), Row("third")),
                    Section("pitchers", ScreenSectionTone.Information, Row("pitcher_one"), Row("pitcher_two")),
                    Section("rule", ScreenSectionTone.Plain, Row("rule_detail"))),
                Actions(Secondary("records", ShellRoute.Records))));

            screens.Add(ShellRoute.Achievements, Screen(Activate(ShellRoute.Achievements), "records", true,
                Sections(
                    Section("progress", ScreenSectionTone.Milestone, Row("unlocked")),
                    Section("list", ScreenSectionTone.Plain, Row("first_win"), Row("ace"), Row("legend"))),
                Actions(Secondary("records", ShellRoute.Records))));

            screens.Add(ShellRoute.LifeArchive, Screen(Activate(ShellRoute.LifeArchive), "records", true,
                Sections(
                    Section("totals", ScreenSectionTone.Milestone, Row("players"), Row("drafted"), Row("legacies")),
                    Section("player", ScreenSectionTone.Plain, Row("player_name"), Row("player_detail")),
                    Section("legacy", ScreenSectionTone.Information, Row("legacy_value"), Row("legacy_detail"))),
                Actions(Secondary("card", ShellRoute.LifeCard), Secondary("records", ShellRoute.Records))));

            screens.Add(ShellRoute.LifeCard, Screen(Activate(ShellRoute.LifeCard), "records", false,
                Sections(
                    Section("identity", ScreenSectionTone.Milestone, Row("player"), Row("scout")),
                    Section("growth", ScreenSectionTone.Positive, Row("fastball"), Row("control"), Row("movement"), Row("stamina")),
                    Section("record", ScreenSectionTone.Plain, Row("games"), Row("strikeouts"), Row("runs")),
                    Section("legacy", ScreenSectionTone.Information, Row("legacy_value"))),
                Actions(Secondary("share", ShellRoute.LifeCard), Primary("archive", ShellRoute.LifeArchive))));

            screens.Add(ShellRoute.Settings, Screen(Activate(ShellRoute.Settings), "settings", true,
                Sections(
                    Section("play", ScreenSectionTone.Plain, Row("auto_release"), Row("auto_release_detail")),
                    Section("sound", ScreenSectionTone.Plain, Row("sound_effect"), Row("music"), Row("vibration")),
                    Section("accessibility", ScreenSectionTone.Information, Row("high_contrast"), Row("reduced_motion"), Row("font_scale")),
                    Section("return", ScreenSectionTone.Plain, Row("reminder"), Row("progress"), Row("share_code")),
                    Section("reset", ScreenSectionTone.Warning, Row("reset_detail"))),
                Actions(Destructive("reset", ShellRoute.Opening, true))));

            return screens;
        }

        private BaseballScreenViewModel Screen(
            ShellRoute route,
            string feature,
            bool showsBottomNavigation,
            IReadOnlyList<ScreenSectionViewModel> sections,
            IReadOnlyList<ScreenActionViewModel> actions)
        {
            string prefix = RouteKey(route);
            return new BaseballScreenViewModel(
                route,
                feature,
                _copy.Get(prefix + ".appbar"),
                _copy.Get(prefix + ".eyebrow"),
                _copy.Get(prefix + ".title"),
                _copy.Get(prefix + ".lead"),
                sections,
                actions,
                showsBottomNavigation);
        }

        private ScreenSectionViewModel Section(string id, ScreenSectionTone tone, params ScreenRowViewModel[] rows)
        {
            return new ScreenSectionViewModel(id, _copy.Get(_activeRoute + ".section." + id), tone, rows);
        }

        private ScreenRowViewModel Row(string id)
        {
            string prefix = _activeRoute + ".row." + id;
            string valueKey = prefix + ".value";
            string detailKey = prefix + ".detail";
            return new ScreenRowViewModel(
                id,
                _copy.Get(prefix + ".label"),
                _copy.Contains(valueKey) ? _copy.Get(valueKey) : null,
                _copy.Contains(detailKey) ? _copy.Get(detailKey) : null);
        }

        private ScreenActionViewModel Primary(string id, ShellRoute target) => Action(id, target, ScreenActionStyle.Primary, false);
        private ScreenActionViewModel ConfirmPrimary(string id, ShellRoute target) => Action(id, target, ScreenActionStyle.Primary, true);
        private ScreenActionViewModel Secondary(string id, ShellRoute target) => Action(id, target, ScreenActionStyle.Secondary, false);
        private ScreenActionViewModel Destructive(string id, ShellRoute target, bool confirm) => Action(id, target, ScreenActionStyle.Destructive, confirm);

        private ScreenActionViewModel Action(string id, ShellRoute target, ScreenActionStyle style, bool confirm)
        {
            string prefix = _activeRoute + ".action." + id;
            string hintKey = prefix + ".hint";
            return new ScreenActionViewModel(
                id,
                _copy.Get(prefix + ".label"),
                target,
                style,
                _copy.Contains(hintKey) ? _copy.Get(hintKey) : null,
                confirm);
        }

        private IReadOnlyList<ScreenSectionViewModel> Sections(params ScreenSectionViewModel[] sections) => sections;
        private IReadOnlyList<ScreenActionViewModel> Actions(params ScreenActionViewModel[] actions) => actions;

        private string _activeRoute;

        private ShellRoute Activate(ShellRoute route)
        {
            RouteKey(route);
            return route;
        }

        private string RouteKey(ShellRoute route)
        {
            _activeRoute = route.ToString().ToLowerInvariant();
            return _activeRoute;
        }
    }
}
