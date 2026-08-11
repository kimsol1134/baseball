using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Security.Cryptography;
using System.Text;
using Newtonsoft.Json;
using Newtonsoft.Json.Converters;
using Newtonsoft.Json.Linq;
using Newtonsoft.Json.Serialization;

namespace Baseball.Application.Persistence
{
    internal sealed class SaveJsonCodec<TPayload>
    {
        private readonly JsonSerializer _serializer;
        private readonly ISavePayloadValidator<TPayload> _validator;

        public SaveJsonCodec(ISavePayloadValidator<TPayload> validator)
        {
            _validator = validator ?? throw new ArgumentNullException(nameof(validator));
            _serializer = JsonSerializer.Create(CreateSettings());
        }

        public SaveCandidate<TPayload> CreateCandidate(
            TPayload payload,
            ulong revision,
            DateTimeOffset writtenAtUtc)
        {
            ValidatePayload(payload);

            JToken payloadToken;
            try
            {
                payloadToken = JToken.FromObject(payload, _serializer);
            }
            catch (Exception exception)
            {
                throw new SavePersistenceException(
                    SaveFailureCode.SerializationFailed,
                    "The save payload could not be serialized.",
                    exception);
            }

            if (payloadToken.Type != JTokenType.Object)
            {
                throw new SavePersistenceException(
                    SaveFailureCode.CandidateInvalid,
                    "The top-level save payload must serialize as a JSON object.");
            }

            var roundTrippedPayload = DeserializePayload(payloadToken);
            ValidatePayload(roundTrippedPayload);

            var payloadChecksum = ComputeSha256(CanonicalBytes(payloadToken));
            var envelopeObject = new JObject
            {
                ["schema"] = SaveSchema.Name,
                ["schemaVersion"] = SaveSchema.Version,
                ["revision"] = revision.ToString(CultureInfo.InvariantCulture),
                ["writtenAtUtc"] = writtenAtUtc.UtcDateTime.ToString(
                    "yyyy-MM-dd'T'HH:mm:ss.fff'Z'",
                    CultureInfo.InvariantCulture),
                ["payloadSha256"] = payloadChecksum,
                ["payload"] = payloadToken
            };

            var bytes = Encoding.UTF8.GetBytes(envelopeObject.ToString(Formatting.Indented));
            return new SaveCandidate<TPayload>(
                bytes,
                new SaveEnvelope<TPayload>(
                    SaveSchema.Name,
                    SaveSchema.Version,
                    revision,
                    writtenAtUtc.ToUniversalTime(),
                    payloadChecksum,
                    roundTrippedPayload));
        }

        public ParsedSaveCandidate<TPayload> Parse(byte[] bytes)
        {
            if (bytes == null || bytes.Length == 0)
            {
                return ParsedSaveCandidate<TPayload>.Invalid("file.empty");
            }

            JObject root;
            try
            {
                root = ParseStrictObject(bytes);
            }
            catch (Exception exception)
            {
                return ParsedSaveCandidate<TPayload>.Invalid("json.invalid:" + exception.GetType().Name);
            }

            var schema = ReadString(root, "schema");
            if (!string.Equals(schema, SaveSchema.Name, StringComparison.Ordinal))
            {
                return ParsedSaveCandidate<TPayload>.Invalid("schema.unknown");
            }

            if (!TryReadInt32(root, "schemaVersion", out var schemaVersion))
            {
                return ParsedSaveCandidate<TPayload>.Invalid("schemaVersion.invalid");
            }

            if (schemaVersion > SaveSchema.Version)
            {
                return ParsedSaveCandidate<TPayload>.FutureVersion(schemaVersion);
            }

            if (schemaVersion < SaveSchema.Version)
            {
                return ParsedSaveCandidate<TPayload>.MigrationRequired(schemaVersion);
            }

            var revisionText = ReadString(root, "revision");
            if (!ulong.TryParse(
                    revisionText,
                    NumberStyles.None,
                    CultureInfo.InvariantCulture,
                    out var revision))
            {
                return ParsedSaveCandidate<TPayload>.Invalid("revision.invalid");
            }

            var writtenAtText = ReadString(root, "writtenAtUtc");
            if (!DateTimeOffset.TryParseExact(
                    writtenAtText,
                    "yyyy-MM-dd'T'HH:mm:ss.fff'Z'",
                    CultureInfo.InvariantCulture,
                    DateTimeStyles.AssumeUniversal | DateTimeStyles.AdjustToUniversal,
                    out var writtenAtUtc))
            {
                return ParsedSaveCandidate<TPayload>.Invalid("writtenAtUtc.invalid");
            }

            var payloadChecksum = ReadString(root, "payloadSha256");
            if (!IsSha256(payloadChecksum))
            {
                return ParsedSaveCandidate<TPayload>.Invalid("payloadSha256.invalid");
            }

            var payloadToken = root["payload"];
            if (payloadToken == null || payloadToken.Type != JTokenType.Object)
            {
                return ParsedSaveCandidate<TPayload>.Invalid("payload.invalid");
            }

            var actualChecksum = ComputeSha256(CanonicalBytes(payloadToken));
            if (!string.Equals(actualChecksum, payloadChecksum, StringComparison.OrdinalIgnoreCase))
            {
                return ParsedSaveCandidate<TPayload>.Invalid("payloadSha256.mismatch");
            }

            TPayload payload;
            try
            {
                payload = DeserializePayload(payloadToken);
                ValidatePayload(payload);
            }
            catch (SavePersistenceException exception)
            {
                return ParsedSaveCandidate<TPayload>.Invalid("payload.semantic:" + exception.Message);
            }
            catch (Exception exception)
            {
                return ParsedSaveCandidate<TPayload>.Invalid("payload.deserialize:" + exception.GetType().Name);
            }

            return ParsedSaveCandidate<TPayload>.Valid(
                bytes,
                new SaveEnvelope<TPayload>(
                    schema,
                    schemaVersion,
                    revision,
                    writtenAtUtc,
                    payloadChecksum.ToLowerInvariant(),
                    payload));
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
                TypeNameHandling = TypeNameHandling.None
            };
            settings.Converters.Add(new StringEnumConverter(new CamelCaseNamingStrategy(), false));
            return settings;
        }

        private TPayload DeserializePayload(JToken payloadToken)
        {
            try
            {
                var payload = payloadToken.ToObject<TPayload>(_serializer);
                if (payload == null)
                {
                    throw new SavePersistenceException(
                        SaveFailureCode.CandidateInvalid,
                        "The save payload deserialized to null.");
                }

                return payload;
            }
            catch (SavePersistenceException)
            {
                throw;
            }
            catch (Exception exception)
            {
                throw new SavePersistenceException(
                    SaveFailureCode.SerializationFailed,
                    "The save payload could not be deserialized.",
                    exception);
            }
        }

        private void ValidatePayload(TPayload payload)
        {
            SaveValidationResult validation;
            try
            {
                validation = _validator.Validate(payload);
            }
            catch (Exception exception)
            {
                throw new SavePersistenceException(
                    SaveFailureCode.CandidateInvalid,
                    "The save payload validator threw an exception.",
                    exception);
            }

            if (validation == null || !validation.IsValid)
            {
                var errors = validation?.Errors == null
                    ? "validation.null"
                    : string.Join(",", validation.Errors);
                throw new SavePersistenceException(
                    SaveFailureCode.CandidateInvalid,
                    "The save payload is invalid: " + errors);
            }
        }

        private static JObject ParseStrictObject(byte[] bytes)
        {
            var json = new UTF8Encoding(false, true).GetString(bytes);
            using (var stringReader = new StringReader(json))
            using (var reader = new JsonTextReader(stringReader)
                   {
                       Culture = CultureInfo.InvariantCulture,
                       DateParseHandling = DateParseHandling.None,
                       FloatParseHandling = FloatParseHandling.Double,
                       MaxDepth = 128,
                       SupportMultipleContent = false
                   })
            {
                var root = JObject.Load(
                    reader,
                    new JsonLoadSettings
                    {
                        CommentHandling = CommentHandling.Ignore,
                        DuplicatePropertyNameHandling = DuplicatePropertyNameHandling.Error,
                        LineInfoHandling = LineInfoHandling.Ignore
                    });
                while (reader.Read())
                {
                    if (reader.TokenType != JsonToken.Comment)
                    {
                        throw new JsonReaderException("Trailing JSON content is not allowed.");
                    }
                }

                return root;
            }
        }

        private static string ReadString(JObject root, string name)
        {
            return root[name]?.Type == JTokenType.String
                ? root[name].Value<string>()
                : null;
        }

        private static bool TryReadInt32(JObject root, string name, out int value)
        {
            value = default;
            var token = root[name];
            if (token == null || token.Type != JTokenType.Integer)
            {
                return false;
            }

            try
            {
                value = token.Value<int>();
                return true;
            }
            catch (Exception)
            {
                return false;
            }
        }

        private static bool IsSha256(string value)
        {
            return value != null &&
                   value.Length == 64 &&
                   value.All(character =>
                       (character >= '0' && character <= '9') ||
                       (character >= 'a' && character <= 'f') ||
                       (character >= 'A' && character <= 'F'));
        }

        private static byte[] CanonicalBytes(JToken token)
        {
            var canonicalToken = SortToken(token);
            return Encoding.UTF8.GetBytes(canonicalToken.ToString(Formatting.None));
        }

        private static JToken SortToken(JToken token)
        {
            if (token is JObject jsonObject)
            {
                var sortedObject = new JObject();
                foreach (var property in jsonObject.Properties().OrderBy(
                             property => property.Name,
                             StringComparer.Ordinal))
                {
                    sortedObject.Add(property.Name, SortToken(property.Value));
                }

                return sortedObject;
            }

            if (token is JArray jsonArray)
            {
                return new JArray(jsonArray.Select(SortToken));
            }

            return token.DeepClone();
        }

        private static string ComputeSha256(byte[] bytes)
        {
            using (var algorithm = SHA256.Create())
            {
                var hash = algorithm.ComputeHash(bytes);
                var builder = new StringBuilder(hash.Length * 2);
                foreach (var value in hash)
                {
                    builder.Append(value.ToString("x2", CultureInfo.InvariantCulture));
                }

                return builder.ToString();
            }
        }
    }

    internal sealed class SaveCandidate<TPayload>
    {
        public SaveCandidate(byte[] bytes, SaveEnvelope<TPayload> envelope)
        {
            Bytes = bytes;
            Envelope = envelope;
        }

        public byte[] Bytes { get; }

        public SaveEnvelope<TPayload> Envelope { get; }
    }

    internal enum ParsedSaveKind
    {
        Valid,
        Invalid,
        FutureVersion,
        MigrationRequired
    }

    internal sealed class ParsedSaveCandidate<TPayload>
    {
        private ParsedSaveCandidate(
            ParsedSaveKind kind,
            byte[] bytes,
            SaveEnvelope<TPayload> envelope,
            int schemaVersion,
            string diagnostic)
        {
            Kind = kind;
            Bytes = bytes;
            Envelope = envelope;
            SchemaVersion = schemaVersion;
            Diagnostic = diagnostic;
        }

        public ParsedSaveKind Kind { get; }

        public byte[] Bytes { get; }

        public SaveEnvelope<TPayload> Envelope { get; }

        public int SchemaVersion { get; }

        public string Diagnostic { get; }

        public static ParsedSaveCandidate<TPayload> Valid(
            byte[] bytes,
            SaveEnvelope<TPayload> envelope)
        {
            return new ParsedSaveCandidate<TPayload>(
                ParsedSaveKind.Valid,
                bytes,
                envelope,
                envelope.SchemaVersion,
                null);
        }

        public static ParsedSaveCandidate<TPayload> Invalid(string diagnostic)
        {
            return new ParsedSaveCandidate<TPayload>(
                ParsedSaveKind.Invalid,
                null,
                null,
                0,
                diagnostic);
        }

        public static ParsedSaveCandidate<TPayload> FutureVersion(int schemaVersion)
        {
            return new ParsedSaveCandidate<TPayload>(
                ParsedSaveKind.FutureVersion,
                null,
                null,
                schemaVersion,
                "schemaVersion.future");
        }

        public static ParsedSaveCandidate<TPayload> MigrationRequired(int schemaVersion)
        {
            return new ParsedSaveCandidate<TPayload>(
                ParsedSaveKind.MigrationRequired,
                null,
                null,
                schemaVersion,
                "schemaVersion.old");
        }
    }
}
