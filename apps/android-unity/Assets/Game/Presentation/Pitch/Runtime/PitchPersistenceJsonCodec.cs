using System;
using System.Globalization;
using Baseball.Core.Pitching;
using Newtonsoft.Json;
using Newtonsoft.Json.Converters;
using Newtonsoft.Json.Serialization;

namespace Baseball.Presentation.Pitch
{
    /// <summary>
    /// Versioned JSON boundary for process-death pitch recovery. These payloads contain only
    /// deterministic Core inputs/results; no Unity object or presentation controller state enters
    /// the save file.
    /// </summary>
    public static class PitchPersistenceJsonCodec
    {
        private static readonly JsonSerializerSettings Settings = CreateSettings();

        public static string SerializeRequest(PitchPlayRequest request) =>
            Serialize(request ?? throw new ArgumentNullException(nameof(request)));

        public static PitchPlayRequest DeserializeRequest(string json) =>
            Deserialize<PitchPlayRequest>(json);

        public static string SerializeKernelResult(PitchKernelResult result) =>
            Serialize(result ?? throw new ArgumentNullException(nameof(result)));

        public static PitchKernelResult DeserializeKernelResult(string json) =>
            Deserialize<PitchKernelResult>(json);

        public static string SerializePresentation(PitchPresentationSnapshot presentation) =>
            Serialize(presentation ?? throw new ArgumentNullException(nameof(presentation)));

        public static PitchPresentationSnapshot DeserializePresentation(string json) =>
            Deserialize<PitchPresentationSnapshot>(json);

        public static string SerializeCheckpoint(PitchPlayRequest request, bool terminal)
        {
            if (!terminal && request == null) throw new ArgumentNullException(nameof(request));
            return Serialize(new PitchCheckpointEnvelope(
                1,
                terminal ? "terminal" : "request",
                terminal ? null : request));
        }

        public static PitchSessionCheckpoint DeserializeCheckpoint(string json)
        {
            PitchCheckpointEnvelope envelope = Deserialize<PitchCheckpointEnvelope>(json);
            if (envelope.Schema != 1) throw new InvalidOperationException("pitch.checkpoint_schema_unsupported");
            if (string.Equals(envelope.Kind, "terminal", StringComparison.Ordinal))
                return new PitchSessionCheckpoint(true, null);
            if (!string.Equals(envelope.Kind, "request", StringComparison.Ordinal) || envelope.Request == null)
                throw new InvalidOperationException("pitch.checkpoint_kind_invalid");
            return new PitchSessionCheckpoint(false, envelope.Request);
        }

        private static string Serialize(object value) => JsonConvert.SerializeObject(value, Settings);

        private static T Deserialize<T>(string json)
        {
            if (string.IsNullOrWhiteSpace(json))
                throw new InvalidOperationException("pitch.persistence_json_missing");
            T value = JsonConvert.DeserializeObject<T>(json, Settings);
            return value == null
                ? throw new InvalidOperationException("pitch.persistence_json_invalid")
                : value;
        }

        private static JsonSerializerSettings CreateSettings()
        {
            var settings = new JsonSerializerSettings
            {
                ContractResolver = new CamelCasePropertyNamesContractResolver(),
                Culture = CultureInfo.InvariantCulture,
                DateParseHandling = DateParseHandling.None,
                FloatParseHandling = FloatParseHandling.Double,
                Formatting = Formatting.None,
                MetadataPropertyHandling = MetadataPropertyHandling.Ignore,
                MissingMemberHandling = MissingMemberHandling.Error,
                NullValueHandling = NullValueHandling.Include,
                ObjectCreationHandling = ObjectCreationHandling.Replace,
                TypeNameHandling = TypeNameHandling.None,
            };
            settings.Converters.Add(new StringEnumConverter(new CamelCaseNamingStrategy(), false));
            return settings;
        }

        private sealed class PitchCheckpointEnvelope
        {
            public PitchCheckpointEnvelope(int schema, string kind, PitchPlayRequest request)
            {
                Schema = schema;
                Kind = kind;
                Request = request;
            }

            public int Schema { get; }
            public string Kind { get; }
            public PitchPlayRequest Request { get; }
        }
    }

    public readonly struct PitchSessionCheckpoint
    {
        public PitchSessionCheckpoint(bool terminal, PitchPlayRequest request)
        {
            IsTerminal = terminal;
            Request = request;
        }

        public bool IsTerminal { get; }
        public PitchPlayRequest Request { get; }
    }
}
