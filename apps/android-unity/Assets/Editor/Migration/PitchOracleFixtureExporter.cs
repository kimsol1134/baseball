using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Security.Cryptography;
using System.Text;
using Baseball.Core.Domain;
using Baseball.Core.Pitching;
using Baseball.Core.Random;
using UnityEditor;

namespace Baseball.Editor.Migration
{
    /// <summary>
    /// Additive, editor-only exporter for the approved C# pitch oracle.
    ///
    /// This never runs in a player build and deliberately uses the same fixture input as
    /// PitchKernelTranslationTests. It exists so the Kotlin port can consume the complete
    /// 128-row oracle output instead of treating a summary hash as if it were row data.
    /// </summary>
    public static class PitchOracleFixtureExporter
    {
        private const string FixtureSchema = "baseball-cross-runtime-fixture-v1";
        private const string SourceCommit = "23acbb8ec233836e802009c8852c430e08075d3c";
        private const string OracleSourceSetSha256 =
            "bdf4288abbc6dc81e96f8c725202af4e764bb293640e3fb0e3571abef182c76b";

        [MenuItem("Baseball/Migration/Export Pitch Oracle Fixture")]
        public static void ExportPitchOracleFixture()
        {
            var output = Environment.GetEnvironmentVariable("BASEBALL_PITCH_ORACLE_OUTPUT");
            if (string.IsNullOrWhiteSpace(output))
            {
                output = Path.Combine("artifacts", "android-compose", "fixtures", "csharp-pitch-oracle-v1.json");
            }

            var directory = Path.GetDirectoryName(Path.GetFullPath(output));
            if (!string.IsNullOrEmpty(directory)) Directory.CreateDirectory(directory);

            var rows = new List<OracleRow>(128);
            var outcomes = new Dictionary<string, int>(StringComparer.Ordinal);
            var engine = new PitchKernelEngine();
            var canonicalRows = new StringBuilder(12_000);
            for (var seed = 1; seed <= 10_000; seed++)
            {
                var input = FixtureInput(seed.ToString(CultureInfo.InvariantCulture));
                var preparation = engine.PreparePitch(input);
                var result = engine.SubmitPitch(Submit(input, preparation));
                var outcome = result.Snapshot.Outcome.Value();
                outcomes[outcome] = outcomes.TryGetValue(outcome, out var count) ? count + 1 : 1;

                if (seed <= 128)
                {
                    var execution = result.Snapshot.Execution;
                    var row = new OracleRow(
                        seed.ToString(CultureInfo.InvariantCulture),
                        outcome,
                        execution.ActualX,
                        execution.ActualY,
                        execution.VelocityTenthsKph,
                        result.EventHash);
                    rows.Add(row);
                    canonicalRows
                        .Append(row.Seed).Append('|')
                        .Append(row.Outcome).Append('|')
                        .Append(row.ActualX).Append('|')
                        .Append(row.ActualY).Append('|')
                        .Append(row.VelocityTenthsKph).Append('|')
                        .Append(row.EventHash).Append('\n');
                }
            }

            var inputCanonical = string.Join("|", new[]
            {
                "PitchKernelTranslationTests.FixtureInput",
                "pitcher-1", "62", "54", "58", "60",
                "batter-1", "56", "52", "58",
                "hot:1:1", "cold:2:0", "strength:four_seam", "weakness:slider", "chase:48",
                "pa-1", "revision:0", "inning:7", "outs:0", "balls:1", "strikes:1",
                "pitchNumber:1", "scoreDifferential:0", "leverage:600", "fatigue:12",
                "seed:1..10000"
            });
            var outputCanonical = canonicalRows + "distribution|" + string.Join(",", outcomes
                .OrderBy(item => item.Key, StringComparer.Ordinal)
                .Select(item => item.Key + ":" + item.Value.ToString(CultureInfo.InvariantCulture)));
            var inputSha256 = Sha256(inputCanonical);
            var outputSha256 = Sha256(outputCanonical);

            var json = new StringBuilder(32_000);
            json.AppendLine("{");
            AppendProperty(json, "fixtureSchema", FixtureSchema, true, 1);
            AppendProperty(json, "sourceRuntime", "csharp", true, 1);
            AppendProperty(json, "sourceCommit", SourceCommit, true, 1);
            AppendProperty(json, "inputSha256", inputSha256, true, 1);
            AppendProperty(json, "outputSha256", outputSha256, true, 1);
            json.AppendLine("  \"input\": {");
            AppendProperty(json, "fixture", "PitchKernelTranslationTests.FixtureInput", true, 2);
            AppendProperty(json, "seedRange", "1..10000", true, 2);
            AppendProperty(json, "oracleSourceSetSha256", OracleSourceSetSha256, true, 2);
            json.AppendLine("    \"pitcher\": {\"id\": \"pitcher-1\", \"stuff\": 62, \"command\": 54, \"movement\": 58, \"stamina\": 60},");
            json.AppendLine("    \"batter\": {\"id\": \"batter-1\", \"contact\": 56, \"discipline\": 52, \"power\": 58},");
            json.AppendLine("    \"scouting\": {\"hotZone\": [1, 1], \"coldZone\": [2, 0], \"pitchStrength\": \"four_seam\", \"pitchWeakness\": \"slider\", \"chaseTendency\": 48},");
            json.AppendLine("    \"context\": {\"plateAppearanceId\": \"pa-1\", \"revision\": \"0\", \"inning\": 7, \"outs\": 0, \"balls\": 1, \"strikes\": 1, \"pitchNumber\": 1, \"scoreDifferential\": 0, \"leverage\": 600, \"fatigue\": 12}");
            json.AppendLine("  },");
            json.AppendLine("  \"expected\": {");
            AppendProperty(json, "exactRuns", "128", false, 2);
            AppendProperty(json, "canonicalRow", "seed|outcomeWire|actualX|actualY|velocityTenthsKph|eventHash\\n", true, 2);
            AppendProperty(json, "canonicalRowsFnv1a64", StableHash.Fnv1A64(canonicalRows.ToString()), true, 2);
            json.AppendLine("    \"rows\": [");
            for (var index = 0; index < rows.Count; index++)
            {
                var row = rows[index];
                json.Append("      {\"seed\":").Append(Json(row.Seed))
                    .Append(",\"outcome\":").Append(Json(row.Outcome))
                    .Append(",\"actualX\":").Append(row.ActualX.ToString(CultureInfo.InvariantCulture))
                    .Append(",\"actualY\":").Append(row.ActualY.ToString(CultureInfo.InvariantCulture))
                    .Append(",\"velocityTenthsKph\":").Append(row.VelocityTenthsKph.ToString(CultureInfo.InvariantCulture))
                    .Append(",\"eventHash\":").Append(Json(row.EventHash)).Append('}');
                if (index < rows.Count - 1) json.Append(',');
                json.AppendLine();
            }
            json.AppendLine("    ],");
            json.AppendLine("    \"distribution\": {");
            var ordered = outcomes.OrderBy(item => item.Key, StringComparer.Ordinal).ToArray();
            for (var index = 0; index < ordered.Length; index++)
            {
                json.Append("      ").Append(Json(ordered[index].Key)).Append(": ")
                    .Append(ordered[index].Value.ToString(CultureInfo.InvariantCulture));
                if (index < ordered.Length - 1) json.Append(',');
                json.AppendLine();
            }
            json.AppendLine("    }");
            json.AppendLine("  }");
            json.AppendLine("}");
            File.WriteAllText(output, json.ToString(), new UTF8Encoding(false));
            UnityEngine.Debug.Log($"Pitch oracle fixture exported: {output} inputSha256={inputSha256} outputSha256={outputSha256}");
        }

        private static PreparePitchParams FixtureInput(string seed)
        {
            return new PreparePitchParams(seed,
                new PitcherSnapshot("pitcher-1", "테스트투수", 62, 54, 58, 60),
                new BatterSnapshot("batter-1", "이준호", 56, 52, 58),
                new BatterScoutingSnapshot(new PitchZone(1, 1), new PitchZone(2, 0),
                    PitchType.FourSeam, PitchType.Slider, 48),
                new PlateAppearanceContext("pa-1", 0, 7, 0, 1, 1, 1, 0, 600, 12));
        }

        private static SubmitPitchParams Submit(PreparePitchParams input, PitchPreparation preparation)
        {
            return new SubmitPitchParams(input.Seed, input.Pitcher, input.Batter, input.Scouting,
                input.Context, preparation.PreparationToken, preparation.PrimaryRecommendation.Call);
        }

        private static string Sha256(string value)
        {
            using (var sha = SHA256.Create())
            {
                return BitConverter.ToString(sha.ComputeHash(Encoding.UTF8.GetBytes(value)))
                    .Replace("-", string.Empty, StringComparison.Ordinal).ToLowerInvariant();
            }
        }

        private static string Json(string value)
        {
            return "\"" + value.Replace("\\", "\\\\", StringComparison.Ordinal)
                .Replace("\"", "\\\"", StringComparison.Ordinal)
                .Replace("\n", "\\n", StringComparison.Ordinal)
                .Replace("\r", "\\r", StringComparison.Ordinal) + "\"";
        }

        private static void AppendProperty(StringBuilder json, string name, string value, bool quoted, int indent)
        {
            json.Append(' ', indent * 2).Append(Json(name)).Append(": ")
                .Append(quoted ? Json(value) : value);
            json.AppendLine(",");
        }

        private readonly struct OracleRow
        {
            public OracleRow(string seed, string outcome, int actualX, int actualY, int velocityTenthsKph, string eventHash)
            {
                Seed = seed;
                Outcome = outcome;
                ActualX = actualX;
                ActualY = actualY;
                VelocityTenthsKph = velocityTenthsKph;
                EventHash = eventHash;
            }

            public string Seed { get; }
            public string Outcome { get; }
            public int ActualX { get; }
            public int ActualY { get; }
            public int VelocityTenthsKph { get; }
            public string EventHash { get; }
        }
    }
}
