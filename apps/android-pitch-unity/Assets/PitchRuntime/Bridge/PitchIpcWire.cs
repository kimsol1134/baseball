using System;
using System.Globalization;
using System.Security.Cryptography;
using System.Text;
using UnityEngine;

namespace Baseball.PitchRuntime
{
    [Serializable]
    internal sealed class PitchCommandWire
    {
        public string schema;
        public int schemaVersion;
        public string messageId;
        public string sessionId;
        public string presentationSeed;
        public string command;
        public PitchPresentationWire request;
        public string qualityTier;
        public string reason;
    }

    [Serializable]
    internal sealed class PitchPresentationWire
    {
        public string requestId;
        public string pitchId;
        public int sequence;
        public string pitchType;
        public int flightDurationMs;
        public int plateXMm;
        public int plateYMm;
        public int velocityDeciKph;
        public PitchTrajectoryPointWire[] trajectory;
        public string presentationSeed;
        public PitchVisualWire visual;
        public string requestSha256;
    }

    [Serializable]
    internal sealed class PitchTrajectoryPointWire
    {
        public int timePermille;
        public int xMm;
        public int yMm;
        public int zMm;
    }

    [Serializable]
    internal sealed class PitchVisualWire
    {
        public string trailKind;
        public string impactKind;
        public bool reducedMotion;
        public string qualityTier;
    }

    internal static class PitchIpcWire
    {
        internal const string Schema = "baseball-pitch-ipc-v1";
        internal const int SchemaVersion = 1;
        internal const int MaxMessageBytes = 64 * 1024;
        internal const int MaxTrajectoryPoints = 64;

        internal static bool TryValidateCommand(
            PitchCommandWire command,
            string expectedSessionId,
            bool hasRequestField,
            bool hasQualityTierField,
            out string reason)
        {
            reason = null;
            if (command == null)
                return Fail("command.null", out reason);
            if (Encoding.UTF8.GetByteCount(JsonUtility.ToJson(command)) > MaxMessageBytes)
                return Fail("message.bytes_limit", out reason);
            if (command.schema != Schema || command.schemaVersion != SchemaVersion)
                return Fail("schema.invalid", out reason);
            if (!IsIdentifier(command.messageId, 128) ||
                !IsIdentifier(command.sessionId, 128) ||
                !IsIdentifier(command.presentationSeed, 128))
                return Fail("envelope.invalid", out reason);
            if (command.sessionId != expectedSessionId)
                return Fail("stale_session", out reason);
            if (command.reason != null && !IsIdentifier(command.reason, 64))
                return Fail("reason.invalid", out reason);

            switch (command.command)
            {
                case "initializeBridge":
                    if (hasRequestField || hasQualityTierField)
                        return Fail("initialize.payload", out reason);
                    return true;

                case "playPresentation":
                    if (!hasRequestField || command.request == null || hasQualityTierField)
                        return Fail("play.payload", out reason);
                    if (command.request.presentationSeed != command.presentationSeed)
                        return Fail("presentationSeed.mismatch", out reason);
                    if (!TryValidateRequest(command.request, out reason))
                        return false;
                    if (CanonicalRequestSha256(command.request) != command.CommandRequestSha())
                        return Fail("requestSha256.mismatch", out reason);
                    return true;

                case "pausePresentation":
                case "resumePresentation":
                case "cancelPresentation":
                    if (hasRequestField || hasQualityTierField)
                        return Fail("lifecycle.payload", out reason);
                    return true;

                case "setQualityTier":
                    if (hasRequestField || !hasQualityTierField ||
                        (command.qualityTier != "high" && command.qualityTier != "low"))
                        return Fail("quality.payload", out reason);
                    return true;

                default:
                    return Fail("command.unknown", out reason);
            }
        }

        internal static bool TryValidateRequest(PitchPresentationWire request, out string reason)
        {
            reason = null;
            if (request == null ||
                !IsIdentifier(request.requestId, 128) ||
                !IsIdentifier(request.pitchId, 128) ||
                !IsIdentifier(request.presentationSeed, 128))
                return Fail("request.identity", out reason);
            if (request.sequence < 0 || request.sequence > 1000000)
                return Fail("sequence.bounds", out reason);
            if (request.flightDurationMs < 150 || request.flightDurationMs > 3000)
                return Fail("flightDurationMs.bounds", out reason);
            if (request.plateXMm < -50000 || request.plateXMm > 50000 ||
                request.plateYMm < -50000 || request.plateYMm > 50000 ||
                request.velocityDeciKph < 0 || request.velocityDeciKph > 5000)
                return Fail("request.value.bounds", out reason);
            if (request.trajectory == null ||
                request.trajectory.Length < 2 ||
                request.trajectory.Length > MaxTrajectoryPoints)
                return Fail("trajectory.count", out reason);

            var previous = -1;
            foreach (var point in request.trajectory)
            {
                if (point == null || point.timePermille < 0 || point.timePermille > 1000 ||
                    point.timePermille <= previous)
                    return Fail("trajectory.time", out reason);
                previous = point.timePermille;
                if (point.xMm < -100000 || point.xMm > 100000 ||
                    point.yMm < -100000 || point.yMm > 100000 ||
                    point.zMm < -100000 || point.zMm > 100000)
                    return Fail("trajectory.value.bounds", out reason);
            }

            if (request.visual == null ||
                !IsOneOf(request.pitchType, "fourSeam", "slider", "curveball", "changeup") ||
                !IsOneOf(request.visual.trailKind, "straight", "breaking", "dropping", "fade") ||
                !IsOneOf(request.visual.impactKind, "glove", "plate", "miss") ||
                !IsOneOf(request.visual.qualityTier, "high", "low") ||
                !IsSha256(request.requestSha256))
                return Fail("request.visual", out reason);
            return true;
        }

        internal static string CanonicalRequestSha256(PitchPresentationWire request)
        {
            var builder = new StringBuilder(1024);
            builder.Append('{');
            AppendNumberField(builder, "flightDurationMs", request.flightDurationMs);
            AppendStringField(builder, "pitchId", request.pitchId);
            AppendStringField(builder, "pitchType", request.pitchType);
            AppendNumberField(builder, "plateXMm", request.plateXMm);
            AppendNumberField(builder, "plateYMm", request.plateYMm);
            AppendStringField(builder, "presentationSeed", request.presentationSeed);
            AppendStringField(builder, "requestId", request.requestId);
            AppendNumberField(builder, "sequence", request.sequence);
            builder.Append("\"trajectory\":[");
            for (var index = 0; index < request.trajectory.Length; index++)
            {
                if (index > 0) builder.Append(',');
                var point = request.trajectory[index];
                builder.Append('{');
                AppendNumberField(builder, "timePermille", point.timePermille);
                AppendNumberField(builder, "xMm", point.xMm);
                AppendNumberField(builder, "yMm", point.yMm);
                AppendNumberField(builder, "zMm", point.zMm);
                RemoveTrailingComma(builder);
                builder.Append('}');
            }
            builder.Append("],");
            builder.Append("\"velocityDeciKph\":").Append(request.velocityDeciKph.ToString(CultureInfo.InvariantCulture)).Append(',');
            builder.Append("\"visual\":{");
            AppendStringField(builder, "impactKind", request.visual.impactKind);
            AppendStringField(builder, "qualityTier", request.visual.qualityTier);
            builder.Append("\"reducedMotion\":").Append(request.visual.reducedMotion ? "true" : "false").Append(',');
            AppendStringField(builder, "trailKind", request.visual.trailKind);
            RemoveTrailingComma(builder);
            builder.Append('}');
            RemoveTrailingComma(builder);
            builder.Append('}');
            using (var algorithm = SHA256.Create())
            {
                var bytes = algorithm.ComputeHash(Encoding.UTF8.GetBytes(builder.ToString()));
                var hex = new StringBuilder(bytes.Length * 2);
                foreach (var value in bytes) hex.Append(value.ToString("x2", CultureInfo.InvariantCulture));
                return hex.ToString();
            }
        }

        internal static bool IsSha256(string value)
        {
            if (value == null || value.Length != 64) return false;
            foreach (var character in value)
            {
                if (!((character >= '0' && character <= '9') ||
                      (character >= 'a' && character <= 'f')))
                    return false;
            }
            return true;
        }

        internal static string Escape(string value)
        {
            if (value == null) return string.Empty;
            var builder = new StringBuilder(value.Length + 8);
            foreach (var character in value)
            {
                switch (character)
                {
                    case '\\': builder.Append("\\\\"); break;
                    case '"': builder.Append("\\\""); break;
                    case '\b': builder.Append("\\b"); break;
                    case '\f': builder.Append("\\f"); break;
                    case '\n': builder.Append("\\n"); break;
                    case '\r': builder.Append("\\r"); break;
                    case '\t': builder.Append("\\t"); break;
                    default:
                        if (character < 0x20)
                            builder.Append("\\u").Append(((int)character).ToString("x4", CultureInfo.InvariantCulture));
                        else
                            builder.Append(character);
                        break;
                }
            }
            return builder.ToString();
        }

        private static string CommandRequestSha(this PitchCommandWire command)
        {
            return command.request == null ? string.Empty : command.request.requestSha256;
        }

        private static bool IsIdentifier(string value, int maxLength)
        {
            if (string.IsNullOrWhiteSpace(value) || value.Length > maxLength) return false;
            foreach (var character in value)
                if (character < 0x20) return false;
            return true;
        }

        private static bool IsOneOf(string value, params string[] choices)
        {
            foreach (var choice in choices) if (value == choice) return true;
            return false;
        }

        private static bool Fail(string value, out string reason)
        {
            reason = value;
            return false;
        }

        private static void AppendStringField(StringBuilder builder, string name, string value)
        {
            builder.Append('"').Append(name).Append("\":\"").Append(Escape(value)).Append("\",");
        }

        private static void AppendNumberField(StringBuilder builder, string name, int value)
        {
            builder.Append('"').Append(name).Append("\":").Append(value.ToString(CultureInfo.InvariantCulture)).Append(',');
        }

        private static void RemoveTrailingComma(StringBuilder builder)
        {
            if (builder.Length > 0 && builder[builder.Length - 1] == ',') builder.Length--;
        }
    }
}
