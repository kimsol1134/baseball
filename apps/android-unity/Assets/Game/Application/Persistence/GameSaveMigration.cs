using System;
using Baseball.Application.Meta;

namespace Baseball.Application.Persistence
{
    public sealed class GameSaveMigrationResult
    {
        public GameSaveMigrationResult(GameSaveAggregate aggregate, bool migrated)
        {
            Aggregate = aggregate ?? throw new ArgumentNullException(nameof(aggregate));
            Migrated = migrated;
        }

        public GameSaveAggregate Aggregate { get; }
        public bool Migrated { get; }
    }

    public static class GameSaveMigration
    {
        public const string VersionZeroReceipt = "__migration:aggregate-v0-v1";
        public const string VersionOneSettingsReceipt = "__migration:aggregate-v1-v2-settings";
        public const string VersionTwoAnalyticsReceipt = "__migration:aggregate-v2-v3-analytics";

        public static GameSaveMigrationResult Upgrade(GameSaveAggregate loaded)
        {
            if (loaded == null) throw new ArgumentNullException(nameof(loaded));
            if (loaded.AggregateVersion == GameSaveAggregate.CurrentAggregateVersion)
            {
                return new GameSaveMigrationResult(loaded, false);
            }
            if (loaded.AggregateVersion < 0 || loaded.AggregateVersion > 2)
            {
                throw new InvalidOperationException("save.aggregate_version_unsupported");
            }

            var migrated = loaded;
            if (migrated.AggregateVersion == 0)
            {
                // v0 kept only wallet balance. Preserve it as both historical totals rather than
                // letting the first reward collapse lifetime accounting back to zero.
                var meta = migrated.Meta ?? MetaProgressState.Initial;
                meta = meta.With(
                    soulLifetimeEarned: Math.Max(meta.SoulLifetimeEarned, meta.SoulBalance),
                    automaticSoulEarned: Math.Max(meta.AutomaticSoulEarned, meta.SoulBalance));
                migrated = migrated.Commit(
                    VersionZeroReceipt,
                    meta: meta,
                    aggregateVersion: 1);
            }

            if (migrated.AggregateVersion == 1)
            {
                migrated = migrated.Commit(
                    VersionOneSettingsReceipt,
                    settings: GameSettingsState.Default,
                    aggregateVersion: 2);
            }

            if (migrated.AggregateVersion == 2)
            {
                migrated = migrated.Commit(
                    VersionTwoAnalyticsReceipt,
                    analyticsReceipts: AnalyticsReceiptState.Empty,
                    aggregateVersion: GameSaveAggregate.CurrentAggregateVersion);
            }
            return new GameSaveMigrationResult(migrated, true);
        }
    }
}
