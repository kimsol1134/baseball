import XCTest
import AVFoundation
@testable import BaseballIOS

/// 홍보 영상의 소리를 게임의 합성기로 직접 뽑는다.
///
/// 시뮬레이터 화면 녹화(`simctl io recordVideo`)는 앱 오디오를 담지 못한다. 그렇다고 다른 데서
/// 구한 효과음을 얹으면 스토어에서 들은 소리와 앱에서 나는 소리가 달라진다 — 산 사람이 가장
/// 먼저 알아채는 종류의 거짓말이다. 이 게임의 소리는 전부 절차 합성이라(GameAudio.swift),
/// 같은 `VoiceBank`·`CrowdBed`를 오프라인으로 돌리면 실제로 나는 소리 그대로가 나온다.
///
/// 결과는 앱 컨테이너 Documents/promo-audio/*.wav.
final class PromoAudioExportTests: XCTestCase {

    private static let sampleRate = 44_100.0

    /// 언제 어떤 소리가 나는지. 초 단위이며 영상 편집점과 손으로 맞춘다.
    private struct Beat {
        let at: Double
        let cue: GameAudioCue
    }

    /// 관중 두께 변화. 승부에서 두꺼워지고 화면이 바뀌면 잦아든다.
    private struct CrowdChange {
        let at: Double
        let intensity: Double
    }

    // MARK: - 렌더

    private func render(
        seconds: Double,
        beats: [Beat],
        crowd crowdChanges: [CrowdChange],
        to name: String
    ) throws {
        let sampleRate = Self.sampleRate
        let totalFrames = Int(seconds * sampleRate)
        let block = 512

        let voices = VoiceBank()
        let crowd = CrowdBed()

        // 오디오 스레드가 쓰는 것과 같은 버퍼 모양을 만든다.
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!
        guard let voiceBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(block)),
              let crowdBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(block)) else {
            return XCTFail("버퍼를 만들지 못했습니다.")
        }
        voiceBuffer.frameLength = AVAudioFrameCount(block)
        crowdBuffer.frameLength = AVAudioFrameCount(block)

        var mixed = [Float](repeating: 0, count: totalFrames * 2)
        var pendingBeats = beats.sorted { $0.at < $1.at }
        var pendingCrowd = crowdChanges.sorted { $0.at < $1.at }

        var frame = 0
        while frame < totalFrames {
            let now = Double(frame) / sampleRate

            while let next = pendingCrowd.first, next.at <= now {
                crowd.setTarget(intensity: next.intensity)
                pendingCrowd.removeFirst()
            }
            while let next = pendingBeats.first, next.at <= now {
                for voice in GameAudio.voices(for: next.cue) { voices.add(voice) }
                pendingBeats.removeFirst()
            }

            voices.render(frameCount: block, into: UnsafeMutableAudioBufferListPointer(voiceBuffer.mutableAudioBufferList))
            crowd.render(frameCount: block, into: UnsafeMutableAudioBufferListPointer(crowdBuffer.mutableAudioBufferList))

            let voiceChannels = voiceBuffer.floatChannelData!
            let crowdChannels = crowdBuffer.floatChannelData!
            let count = min(block, totalFrames - frame)
            for offset in 0..<count {
                for channel in 0..<2 {
                    // 게임의 mainMixerNode.outputVolume과 같은 0.85를 건다.
                    let value = (voiceChannels[channel][offset] + crowdChannels[channel][offset]) * 0.85
                    mixed[(frame + offset) * 2 + channel] = max(-1, min(1, value))
                }
            }
            frame += block
        }

        try writeWave(mixed, frames: totalFrames, to: name)
    }

    /// 16비트 PCM WAV. ffmpeg가 그대로 먹는다.
    private func writeWave(_ samples: [Float], frames: Int, to name: String) throws {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let directory = documents.appendingPathComponent("promo-audio", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let channels = 2
        let bytesPerSample = 2
        let dataSize = frames * channels * bytesPerSample
        var data = Data(capacity: 44 + dataSize)

        func append(_ string: String) { data.append(contentsOf: Array(string.utf8)) }
        func append32(_ value: UInt32) { withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) } }
        func append16(_ value: UInt16) { withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) } }

        append("RIFF"); append32(UInt32(36 + dataSize)); append("WAVE")
        append("fmt "); append32(16); append16(1); append16(UInt16(channels))
        append32(UInt32(Self.sampleRate))
        append32(UInt32(Self.sampleRate) * UInt32(channels * bytesPerSample))
        append16(UInt16(channels * bytesPerSample)); append16(16)
        append("data"); append32(UInt32(dataSize))

        for index in 0..<(frames * channels) {
            let clamped = max(-1, min(1, samples[index]))
            append16(UInt16(bitPattern: Int16(clamped * 32_600)))
        }

        let url = directory.appendingPathComponent(name)
        try data.write(to: url)
        print("PROMO_AUDIO \(name) \(url.path)")
    }

    // MARK: - 타임라인

    /// 세로 앱 미리보기(26.3초). 컷 시작 시각은 AppPreview.tsx의 PREVIEW_BEATS를 30으로 나눈 값이다.
    func testExportAppPreviewAudio() throws {
        let choose = 46.0 / 30
        let moment = (46.0 + 124) / 30
        // 세 구가 이어진다(AppPreview.tsx PITCHES: 54 / 54 / 108프레임).
        let secondPitch = moment + 54.0 / 30
        let thirdPitch = moment + 108.0 / 30
        // 공이 홈플레이트에 닿는 순간. 재생을 0.3초부터 시작하므로 그만큼 당겨진다.
        let arrival = 0.44
        let train = (46.0 + 124 + 216) / 30
        let school = train + 118.0 / 30
        let rebirth = school + 100.0 / 30
        let closing = rebirth + 118.0 / 30
        let total = (46.0 + 124 + 216 + 118 + 100 + 118 + 66) / 30

        try render(
            seconds: total,
            beats: [
                Beat(at: choose + 0.7, cue: .uiSelect),
                Beat(at: choose + 1.6, cue: .uiSelect),
                Beat(at: choose + 2.6, cue: .uiSelect),

                // 1구: 루킹 스트라이크. 미트 소리 뒤에 심판 콜.
                Beat(at: moment, cue: .pitchRelease),
                Beat(at: moment + arrival, cue: .gloveCatch),
                Beat(at: moment + arrival + 0.18, cue: .umpireStrike),

                // 2구: 헛스윙. 배트가 공기를 가르고 포구음이 따라온다.
                Beat(at: secondPitch, cue: .pitchRelease),
                Beat(at: secondPitch + arrival, cue: .swingMiss),
                Beat(at: secondPitch + arrival + 0.18, cue: .umpireStrike),
                Beat(at: secondPitch + arrival + 0.5, cue: .crowdCheer),

                // 3구: 홈런. 투수 쪽 이야기라 환호가 아니라 탄식이다.
                Beat(at: thirdPitch, cue: .pitchRelease),
                Beat(at: thirdPitch + arrival, cue: .batContact(power: 0.95)),
                Beat(at: thirdPitch + 1.2, cue: .crowdGroan),

                Beat(at: train + 0.9, cue: .uiSelect),
                Beat(at: train + 1.9, cue: .uiSelect),
                Beat(at: train + 2.8, cue: .growth),

                Beat(at: school + 0.8, cue: .uiSelect),
                Beat(at: school + 1.9, cue: .uiSelect),

                Beat(at: rebirth + 0.8, cue: .uiSelect),
                Beat(at: rebirth + 1.6, cue: .uiSelect),
                Beat(at: rebirth + 2.4, cue: .uiSelect),

                Beat(at: closing + 0.3, cue: .milestone),
            ],
            crowd: [
                CrowdChange(at: 0, intensity: 0.18),
                CrowdChange(at: moment - 0.6, intensity: 0.72),
                CrowdChange(at: train - 0.4, intensity: 0.16),
                CrowdChange(at: closing, intensity: 0.3),
            ],
            to: "app-preview.wav"
        )
    }

    /// 가로 트레일러(27.3초). 컷 시작 시각은 Trailer.tsx의 BEATS를 30으로 나눈 값이다.
    func testExportTrailerAudio() throws {
        let choose = 86.0 / 30
        let moment = (86.0 + 140) / 30
        let secondPitch = moment + 108.0 / 30
        let grow = (86.0 + 140 + 212) / 30
        let rebirth = grow + 140.0 / 30
        let closing = rebirth + 126.0 / 30
        let total = (86.0 + 140 + 212 + 140 + 126 + 116) / 30

        try render(
            seconds: total,
            beats: [
                Beat(at: 0.5, cue: .uiSelect),
                Beat(at: choose + 0.9, cue: .uiSelect),
                Beat(at: choose + 2.0, cue: .uiSelect),

                Beat(at: moment, cue: .pitchRelease),
                Beat(at: moment + 0.34, cue: .swingMiss),
                Beat(at: moment + 0.52, cue: .umpireStrike),
                Beat(at: moment + 0.85, cue: .crowdCheer),

                Beat(at: secondPitch, cue: .pitchRelease),
                Beat(at: secondPitch + 0.34, cue: .batContact(power: 0.95)),
                Beat(at: secondPitch + 1.1, cue: .crowdGroan),

                Beat(at: grow + 1.0, cue: .uiSelect),
                Beat(at: grow + 2.1, cue: .growth),

                Beat(at: rebirth + 0.9, cue: .uiSelect),
                Beat(at: rebirth + 1.8, cue: .uiSelect),
                Beat(at: rebirth + 2.7, cue: .uiSelect),

                Beat(at: closing + 0.4, cue: .milestone),
            ],
            crowd: [
                CrowdChange(at: 0, intensity: 0.2),
                CrowdChange(at: moment - 0.6, intensity: 0.72),
                CrowdChange(at: grow - 0.4, intensity: 0.16),
                CrowdChange(at: closing, intensity: 0.32),
            ],
            to: "trailer.wav"
        )
    }

    /// 큐를 하나씩 따로 뽑는다. 영상에 섞여 들어가면 어느 소리가 이상한지 알 수 없다.
    /// 소리를 고칠 때 이걸 돌려 놓고 하나씩 듣는다.
    func testExportEachCueForListening() throws {
        let cues: [(String, GameAudioCue)] = [
            ("01-release", .pitchRelease),
            ("02-glove", .gloveCatch),
            ("03-swing-miss", .swingMiss),
            ("04-contact-hard", .batContact(power: 0.95)),
            ("05-contact-weak", .batContact(power: 0.2)),
            ("06-foul", .batFoul),
            ("07-umpire-strike", .umpireStrike),
            ("08-umpire-ball", .umpireBall),
            ("09-cheer", .crowdCheer),
            ("10-groan", .crowdGroan),
            ("11-growth", .growth),
            ("12-milestone", .milestone),
            ("13-ui", .uiSelect),
        ]
        for (name, cue) in cues {
            try render(seconds: 2.2, beats: [Beat(at: 0.15, cue: cue)],
                       crowd: [CrowdChange(at: 0, intensity: 0)], to: "cue-\(name).wav")
        }
        // 관중만 따로. 밀도를 올려 가며 듣는다.
        try render(seconds: 9, beats: [], crowd: [
            CrowdChange(at: 0, intensity: 0.15),
            CrowdChange(at: 3, intensity: 0.5),
            CrowdChange(at: 6, intensity: 0.9),
        ], to: "cue-00-crowd.wav")
    }

    /// 실제로 앱이 내는 소리를 그대로 만든다 — 번들의 관중 루프 위에 승부 효과음이 얹힌다.
    /// 합성 관중 베드를 쓰던 때와 달리, 이제 바탕은 녹음이고 위에 얹히는 것만 합성이다.
    func testExportRealMixForListening() throws {
        let bank = SoundBank()
        bank.load()
        guard let loop = bank.buffer(for: .crowdLoop), let loopData = loop.floatChannelData else {
            throw XCTSkip("관중 루프가 없습니다.")
        }

        // 한 타석: 루킹 스트라이크 → 헛스윙 → 홈런.
        let seconds = 16.0
        let arrival = 0.45
        try render(
            seconds: seconds,
            beats: [
                Beat(at: 2.0, cue: .pitchRelease),
                Beat(at: 2.0 + arrival, cue: .gloveCatch),
                Beat(at: 2.0 + arrival + 0.18, cue: .umpireStrike),
                Beat(at: 6.0, cue: .pitchRelease),
                Beat(at: 6.0 + arrival, cue: .swingMiss),
                Beat(at: 6.0 + arrival + 0.18, cue: .umpireStrike),
                Beat(at: 6.0 + arrival + 0.6, cue: .crowdCheer),
                Beat(at: 11.0, cue: .pitchRelease),
                Beat(at: 11.0 + arrival, cue: .batContact(power: 0.95)),
                Beat(at: 11.0 + arrival + 1.1, cue: .crowdGroan),
            ],
            // 바탕은 아래에서 녹음으로 깔 것이므로 합성 베드는 끈다.
            crowd: [CrowdChange(at: 0, intensity: 0)],
            to: "real-cues-only.wav"
        )

        // 녹음 루프를 앱과 같은 볼륨(밀도 0.7 × 0.35)으로 깔고 효과음을 더한다.
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let cuesURL = documents.appendingPathComponent("promo-audio/real-cues-only.wav")
        let cueFile = try AVAudioFile(forReading: cuesURL)
        guard let cues = AVAudioPCMBuffer(pcmFormat: cueFile.processingFormat,
                                          frameCapacity: AVAudioFrameCount(cueFile.length)) else {
            return XCTFail("효과음을 읽지 못했습니다.")
        }
        try cueFile.read(into: cues)
        guard let cueData = cues.floatChannelData else { return XCTFail("채널이 없습니다.") }

        let total = Int(seconds * Self.sampleRate)
        let crowdGain: Float = 0.7 * 0.35
        var mixed = [Float](repeating: 0, count: total * 2)
        for frame in 0..<total {
            for channel in 0..<2 {
                let loopFrame = frame % Int(loop.frameLength)
                let loopChannel = min(channel, Int(loop.format.channelCount) - 1)
                let bed = loopData[loopChannel][loopFrame] * crowdGain
                let cue = frame < Int(cues.frameLength) ? cueData[min(channel, Int(cues.format.channelCount) - 1)][frame] : 0
                mixed[frame * 2 + channel] = max(-1, min(1, (bed + cue) * 0.85))
            }
        }
        try writeWave(mixed, frames: total, to: "real-mix.wav")
    }
}
