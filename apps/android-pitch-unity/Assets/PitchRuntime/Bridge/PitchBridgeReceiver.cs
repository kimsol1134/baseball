using System;
using System.Collections.Generic;
using System.Text;
using UnityEngine;
using UnityEngine.Scripting;

namespace Baseball.PitchRuntime
{
    /** Receives only versioned presentation commands; gameplay authority stays in Kotlin. */
    [Preserve]
    public sealed class PitchBridgeReceiver : MonoBehaviour
    {
        private readonly Dictionary<string, string> _messageFingerprints = new Dictionary<string, string>();

        private PitchTrajectoryRenderer _renderer;
        private string _sessionId;
        private string _bridgePresentationSeed;
        private bool _initialized;
        private bool _unityReady;
        private bool _unloaded;
        private bool _active;
        private bool _activeStarted;
        private bool _activeTerminal;
        private PitchPresentationWire _activeRequest;
        private int _ackSequence;

        private void Awake()
        {
            _renderer = GetComponent<PitchTrajectoryRenderer>();
            if (_renderer == null) _renderer = gameObject.AddComponent<PitchTrajectoryRenderer>();
        }

        [Preserve]
        public void ReceiveCommand(string json)
        {
            if (_unloaded || string.IsNullOrEmpty(json))
            {
                Debug.LogWarning("Pitch bridge rejected a command after unload or with an empty body.");
                return;
            }

            if (TryFindTopLevelFieldError(json, out var fieldError))
            {
                Debug.LogWarning("Pitch bridge rejected envelope fields: " + fieldError);
                return;
            }

            PitchCommandWire command;
            try
            {
                command = JsonUtility.FromJson<PitchCommandWire>(json);
            }
            catch (Exception exception)
            {
                Debug.LogWarning("Pitch bridge rejected malformed JSON: " + exception.GetType().Name);
                return;
            }

            var canStartNextSession = command != null &&
                                      command.command == "initializeBridge" &&
                                      (!_active || _activeTerminal);
            var expectedSession = canStartNextSession ? command.sessionId : _sessionId ?? command?.sessionId;
            var hasRequestField = HasTopLevelField(json, "request");
            var hasQualityTierField = HasTopLevelField(json, "qualityTier");
            if (!PitchIpcWire.TryValidateCommand(
                    command,
                    expectedSession,
                    hasRequestField,
                    hasQualityTierField,
                    out var validationError))
            {
                Debug.LogWarning("Pitch bridge rejected command: " + validationError);
                return;
            }

            var fingerprint = Fingerprint(command);
            if (_messageFingerprints.TryGetValue(command.messageId, out var previous))
            {
                if (previous == fingerprint) return;
                Debug.LogWarning("Pitch bridge rejected message_id reuse: " + command.messageId);
                return;
            }
            switch (command.command)
            {
                case "initializeBridge":
                    Initialize(command);
                    break;
                case "setQualityTier":
                    if (!_initialized) Debug.LogWarning("Pitch bridge rejected quality before initialize.");
                    break;
                case "playPresentation":
                    Play(command);
                    break;
                case "pausePresentation":
                    Pause(command);
                    break;
                case "resumePresentation":
                    Resume(command);
                    break;
                case "cancelPresentation":
                    Cancel(command);
                    break;
            }
            _messageFingerprints[command.messageId] = fingerprint;
        }

        private void Initialize(PitchCommandWire command)
        {
            if (_initialized)
            {
                if (_active && !_activeTerminal)
                {
                    Debug.LogWarning("Pitch bridge rejected a second session while a presentation is active.");
                    return;
                }

                // A persistent pitch root can receive a new saved session after the prior
                // terminal presentation. Clear only the bridge session ledger; gameplay and
                // result authority remain in the native Kotlin store.
                _messageFingerprints.Clear();
                _activeRequest = null;
                _activeStarted = false;
                _activeTerminal = false;
                _active = false;
                _unloaded = false;
                _unityReady = false;
            }

            _sessionId = command.sessionId;
            _bridgePresentationSeed = command.presentationSeed;
            _initialized = true;
            _unityReady = true;
            EmitAcknowledgement(_bridgePresentationSeed, "unityReady");
        }

        private void Play(PitchCommandWire command)
        {
            if (!_initialized || !_unityReady)
            {
                Debug.LogWarning("Pitch bridge rejected play before ready.");
                return;
            }
            if (_active && !_activeTerminal)
            {
                Debug.LogWarning("Pitch bridge rejected a second active presentation.");
                return;
            }

            _active = true;
            _activeStarted = false;
            _activeTerminal = false;
            _activeRequest = command.request;
            _renderer.Play(command.request, OnPresentationStarted, OnMarker, OnTerminal);
        }

        private void Pause(PitchCommandWire command)
        {
            if (!_active || _activeTerminal || !_activeStarted) return;
            _renderer.Pause();
            EmitPresentationAcknowledgement("presentationPaused", _activeRequest);
        }

        private void Resume(PitchCommandWire command)
        {
            if (!_active || _activeTerminal || !_activeStarted) return;
            _renderer.Resume();
            EmitPresentationAcknowledgement("presentationResumed", _activeRequest);
        }

        private void Cancel(PitchCommandWire command)
        {
            if (!_active || _activeTerminal) return;
            _renderer.Cancel();
        }

        private void OnPresentationStarted(PitchPresentationWire request)
        {
            _activeStarted = true;
            EmitPresentationAcknowledgement("presentationStarted", request);
        }

        private void OnMarker(PitchPresentationWire request, string marker)
        {
            EmitPresentationAcknowledgement("presentationMarker", request, marker);
        }

        private void OnTerminal(PitchPresentationWire request, string status, string errorCode)
        {
            if (_activeTerminal) return;
            _activeTerminal = true;
            if (status == "cancelled")
                EmitPresentationAcknowledgement("presentationCancelled", request, errorCode: errorCode);

            var acknowledgement = status == "failed" ? "presentationFailed" : "presentationCompleted";
            EmitTerminalAcknowledgement(acknowledgement, request, status, errorCode);
            _active = false;
        }

        private void EmitPresentationAcknowledgement(
            string acknowledgement,
            PitchPresentationWire request,
            string marker = null,
            string errorCode = null)
        {
            EmitAcknowledgement(
                request.presentationSeed,
                acknowledgement,
                request.pitchId,
                request.requestSha256,
                marker,
                null,
                errorCode);
        }

        private void EmitTerminalAcknowledgement(
            string acknowledgement,
            PitchPresentationWire request,
            string status,
            string errorCode)
        {
            EmitAcknowledgement(
                request.presentationSeed,
                acknowledgement,
                request.pitchId,
                request.requestSha256,
                null,
                status,
                errorCode);
        }

        private void EmitAcknowledgement(
            string presentationSeed,
            string acknowledgement,
            string pitchId = null,
            string requestSha256 = null,
            string marker = null,
            string terminalStatus = null,
            string errorCode = null)
        {
            var messageId = "unity-ack-" + (++_ackSequence).ToString();
            var builder = new StringBuilder(512);
            builder.Append("{\"schema\":\"").Append(PitchIpcWire.Schema).Append("\"");
            builder.Append(",\"schemaVersion\":").Append(PitchIpcWire.SchemaVersion);
            builder.Append(",\"messageId\":\"").Append(PitchIpcWire.Escape(messageId)).Append("\"");
            builder.Append(",\"sessionId\":\"").Append(PitchIpcWire.Escape(_sessionId ?? string.Empty)).Append("\"");
            builder.Append(",\"presentationSeed\":\"").Append(PitchIpcWire.Escape(presentationSeed)).Append("\"");
            builder.Append(",\"acknowledgement\":\"").Append(PitchIpcWire.Escape(acknowledgement)).Append("\"");
            if (pitchId != null)
                builder.Append(",\"pitchId\":\"").Append(PitchIpcWire.Escape(pitchId)).Append("\"");
            if (requestSha256 != null)
                builder.Append(",\"requestSha256\":\"").Append(PitchIpcWire.Escape(requestSha256)).Append("\"");
            if (marker != null)
                builder.Append(",\"marker\":\"").Append(PitchIpcWire.Escape(marker)).Append("\"");
            if (terminalStatus != null)
            {
                builder.Append(",\"terminal\":{\"status\":\"")
                    .Append(PitchIpcWire.Escape(terminalStatus))
                    .Append("\",\"pitchId\":\"")
                    .Append(PitchIpcWire.Escape(pitchId))
                    .Append("\",\"requestSha256\":\"")
                    .Append(PitchIpcWire.Escape(requestSha256))
                    .Append("\"");
                if (errorCode != null)
                    builder.Append(",\"errorCode\":\"").Append(PitchIpcWire.Escape(errorCode)).Append("\"");
                builder.Append('}');
            }
            if (errorCode != null && terminalStatus == null)
                builder.Append(",\"errorCode\":\"").Append(PitchIpcWire.Escape(errorCode)).Append("\"");
            builder.Append('}');
            SendToHost(builder.ToString());
        }

        private static string Fingerprint(PitchCommandWire command)
        {
            var request = command.request;
            return command.command + "|" + command.sessionId + "|" + command.presentationSeed + "|" +
                   (request == null ? string.Empty : request.requestSha256) + "|" + (command.qualityTier ?? string.Empty);
        }

        private static bool HasTopLevelField(string json, string fieldName)
        {
            if (string.IsNullOrEmpty(json)) return false;
            var depth = 0;
            for (var index = 0; index < json.Length; index++)
            {
                if (json[index] == '"')
                {
                    var start = ++index;
                    var escaped = false;
                    for (; index < json.Length; index++)
                    {
                        var character = json[index];
                        if (character == '"' && !escaped) break;
                        escaped = character == '\\' && !escaped;
                        if (character != '\\') escaped = false;
                    }

                    if (depth == 1 && json.Substring(start, index - start) == fieldName)
                    {
                        var next = index + 1;
                        while (next < json.Length && char.IsWhiteSpace(json[next])) next++;
                        if (next < json.Length && json[next] == ':') return true;
                    }
                    continue;
                }

                if (json[index] == '{') depth++;
                else if (json[index] == '}') depth--;
            }
            return false;
        }

        private static bool TryFindTopLevelFieldError(string json, out string reason)
        {
            var fields = new HashSet<string>();
            var depth = 0;
            for (var index = 0; index < json.Length; index++)
            {
                if (json[index] == '"')
                {
                    var start = ++index;
                    var escaped = false;
                    for (; index < json.Length; index++)
                    {
                        var character = json[index];
                        if (character == '"' && !escaped) break;
                        escaped = character == '\\' && !escaped;
                        if (character != '\\') escaped = false;
                    }

                    if (depth == 1)
                    {
                        var field = json.Substring(start, index - start);
                        var next = index + 1;
                        while (next < json.Length && char.IsWhiteSpace(json[next])) next++;
                        if (next < json.Length && json[next] == ':')
                        {
                            if (!IsAllowedTopLevelField(field))
                            {
                                reason = "field.unknown:" + field;
                                return true;
                            }
                            if (!fields.Add(field))
                            {
                                reason = "field.duplicate:" + field;
                                return true;
                            }
                        }
                    }
                    continue;
                }

                if (json[index] == '{') depth++;
                else if (json[index] == '}') depth--;
            }

            reason = null;
            return false;
        }

        private static bool IsAllowedTopLevelField(string field)
        {
            switch (field)
            {
                case "schema":
                case "schemaVersion":
                case "messageId":
                case "sessionId":
                case "presentationSeed":
                case "command":
                case "request":
                case "qualityTier":
                case "reason":
                    return true;
                default:
                    return false;
            }
        }

        private static void SendToHost(string json)
        {
#if UNITY_ANDROID && !UNITY_EDITOR
            try
            {
                using (var callbacks = new AndroidJavaClass("com.solkim.baseball.android.UnityBridgeCallbacks"))
                    callbacks.CallStatic("onBridgeAcknowledgement", json);
            }
            catch (Exception exception)
            {
                Debug.LogWarning("Pitch bridge callback failed: " + exception.GetType().Name);
            }
#else
            Debug.Log("Pitch bridge acknowledgement: " + json);
#endif
        }

        private void OnDestroy()
        {
            if (_initialized && !_unloaded)
            {
                _unloaded = true;
                EmitAcknowledgement(_bridgePresentationSeed, "unityUnloaded");
            }
        }
    }
}
