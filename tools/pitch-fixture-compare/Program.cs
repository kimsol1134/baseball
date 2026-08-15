using System.Text.Json;

const string defaultFixture = "apps/android/game-core/src/test/resources/fixtures/csharp-pitch-oracle-v1.json";
var oraclePath = args.Length > 0 ? args[0] : defaultFixture;
var candidatePath = args.Length > 1 ? args[1] : null;

using var oracle = JsonDocument.Parse(File.ReadAllText(oraclePath));
var oracleSummary = ValidateFixture(oracle.RootElement, "oracle");
Console.WriteLine($"C# fixture: {oracleSummary.SourceRuntime} {oracleSummary.SourceCommit}");
Console.WriteLine($"Exact rows: {oracleSummary.Rows}; FNV: {oracleSummary.RowsFnv}");
Console.WriteLine($"Distribution: {string.Join(", ", oracleSummary.Distribution.Select(item => $"{item.Key}={item.Value}"))}");

if (candidatePath is not null)
{
    using var candidate = JsonDocument.Parse(File.ReadAllText(candidatePath));
    var candidateSummary = ValidateFixture(candidate.RootElement, "candidate");
    if (candidateSummary.RowsFnv != oracleSummary.RowsFnv)
    {
        throw new InvalidDataException($"candidate exact-row FNV {candidateSummary.RowsFnv} != oracle {oracleSummary.RowsFnv}");
    }
    if (!candidateSummary.Distribution.SequenceEqual(oracleSummary.Distribution))
    {
        throw new InvalidDataException("candidate 10,000-run distribution differs from the C# oracle");
    }
    Console.WriteLine("Candidate exact rows and 10,000-run distribution match the C# oracle.");
}

static FixtureSummary ValidateFixture(JsonElement root, string label)
{
    RequireCondition(Require(root, "fixtureSchema").GetString() == "baseball-cross-runtime-fixture-v1", $"{label} fixtureSchema is unsupported");
    var runtime = Require(root, "sourceRuntime").GetString() ?? throw new InvalidDataException($"{label} sourceRuntime missing");
    RequireCondition(runtime is "csharp" or "swift", $"{label} sourceRuntime is unsupported");
    var sourceCommit = Require(root, "sourceCommit").GetString() ?? throw new InvalidDataException($"{label} sourceCommit missing");
    RequireCondition(sourceCommit.Length == 40 && sourceCommit.All(IsHex), $"{label} sourceCommit is malformed");
    foreach (var field in new[] { "inputSha256", "outputSha256" })
    {
        var value = Require(root, field).GetString();
        RequireCondition(value is not null && value.Length == 64 && value.All(IsHex), $"{label} {field} is malformed");
    }
    var expected = Require(root, "expected");
    var rows = Require(expected, "rows");
    RequireCondition(rows.ValueKind == JsonValueKind.Array && rows.GetArrayLength() == 128, $"{label} exact row count is not 128");
    var rowsFnv = Require(expected, "canonicalRowsFnv1a64").GetString() ?? throw new InvalidDataException($"{label} FNV missing");
    RequireCondition(rowsFnv.Length == 16 && rowsFnv.All(IsHex), $"{label} FNV is malformed");
    var distribution = Require(expected, "distribution").EnumerateObject()
        .OrderBy(property => property.Name, StringComparer.Ordinal)
        .ToDictionary(property => property.Name, property => property.Value.GetInt32(), StringComparer.Ordinal);
    RequireCondition(distribution.Values.Sum() == 10_000, $"{label} distribution does not total 10,000");
    return new FixtureSummary(runtime, sourceCommit, rows.GetArrayLength(), rowsFnv, distribution);
}

static JsonElement Require(JsonElement parent, string name)
{
    if (!parent.TryGetProperty(name, out var value)) throw new InvalidDataException($"missing property '{name}'");
    return value;
}

static void RequireCondition(bool condition, string message)
{
    if (!condition) throw new InvalidDataException(message);
}

static bool IsHex(char value) => value is >= '0' and <= '9' or >= 'a' and <= 'f';

readonly record struct FixtureSummary(
    string SourceRuntime,
    string SourceCommit,
    int Rows,
    string RowsFnv,
    IReadOnlyDictionary<string, int> Distribution);
