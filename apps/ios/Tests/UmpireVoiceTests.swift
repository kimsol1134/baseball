import XCTest
import AVFoundation
@testable import BaseballIOS

/// 심판 콜이 **목소리처럼 들리는가**를 신호로 확인한다.
///
/// 귀로 듣는 것을 테스트가 대신할 수는 없다. 하지만 "목소리가 아닌 것"은 잡을 수 있다 —
/// 예전 구현은 밴드패스 노이즈라 음정이 없었고, 그래서 어떤 대역을 줘도 "쉬" 소리였다.
/// 사람의 외침에는 **기본 주파수의 배음 구조**가 있고 그것이 노이즈와 갈리는 지점이다.
final class UmpireVoiceTests: XCTestCase {
    private let sampleRate = 44_100.0

    /// 큐 하나를 오프라인으로 렌더해 모노 샘플로 돌려준다.
    private func render(_ cue: GameAudioCue, seconds: Double = 0.8) -> [Double] {
        let voices = VoiceBank()
        for voice in GameAudio.voices(for: cue) { voices.add(voice) }
        let total = Int(sampleRate * seconds)
        let block = 512
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(block))!
        var out: [Double] = []
        out.reserveCapacity(total)
        var rendered = 0
        while rendered < total {
            buffer.frameLength = AVAudioFrameCount(block)
            voices.render(frameCount: block, into: UnsafeMutableAudioBufferListPointer(buffer.mutableAudioBufferList))
            let left = buffer.floatChannelData![0]
            let right = buffer.floatChannelData![1]
            for index in 0..<block { out.append(Double(left[index] + right[index])) }
            rendered += block
        }
        return out
    }

    /// 자기상관으로 기본 주파수를 찾는다. 주기가 뚜렷하면 음정이 있는 소리다.
    private func periodicity(_ samples: [Double], minHz: Double, maxHz: Double) -> (hz: Double, strength: Double) {
        // 가장 큰 소리가 나는 구간만 본다. 앞뒤 무음이 섞이면 상관이 흐려진다.
        let window = Int(sampleRate * 0.06)
        var best = 0
        var bestEnergy = 0.0
        var index = 0
        while index + window < samples.count {
            let energy = samples[index..<(index + window)].reduce(0) { $0 + $1 * $1 }
            if energy > bestEnergy { bestEnergy = energy; best = index }
            index += window / 2
        }
        let slice = Array(samples[best..<min(samples.count, best + window)])
        let zeroLag = slice.reduce(0) { $0 + $1 * $1 }
        guard zeroLag > 0 else { return (0, 0) }
        var peak = 0.0
        var peakLag = 0
        for lag in Int(sampleRate / maxHz)...Int(sampleRate / minHz) where lag < slice.count {
            var sum = 0.0
            for i in 0..<(slice.count - lag) { sum += slice[i] * slice[i + lag] }
            let value = sum / zeroLag
            if value > peak { peak = value; peakLag = lag }
        }
        return (peakLag > 0 ? sampleRate / Double(peakLag) : 0, peak)
    }

    /// 스트라이크 콜에는 사람 목소리의 음정이 있어야 한다.
    ///
    /// 노이즈는 자기상관 봉우리가 서지 않는다. 이 검사가 예전 구현이었다면 실패한다.
    func testStrikeCallIsVoicedNotNoise() {
        let (hz, strength) = periodicity(render(.umpireStrike), minHz: 90, maxHz: 320)
        XCTAssertGreaterThan(strength, 0.35, "음정이 없습니다 — 노이즈로 들립니다(자기상관 \(strength))")
        XCTAssertTrue((100...260).contains(hz), "기본 주파수 \(hz)Hz는 사람이 지르는 소리의 범위가 아닙니다")
    }

    /// 볼 콜은 **무음**이다. 실제 심판은 볼을 외치지 않고, 미트 소리가 이미 공 하나를
    /// 표시한다. 실기기 피드백("볼이 이상하다")이 맞았다.
    func testBallCallIsSilent() {
        XCTAssertTrue(GameAudio.voices(for: .umpireBall).isEmpty, "볼에 목소리가 다시 붙었습니다")
    }

    /// 스트라이크는 두 박. 합성 폴백의 계약이다(번들에 실녹음이 있으면 그쪽이 먼저 난다).
    func testStrikeHasTwoBeatsAndBallHasOne() {
        func beats(_ cue: GameAudioCue) -> Int {
            let samples = render(cue)
            let window = Int(sampleRate * 0.02)
            var envelope: [Double] = []
            var index = 0
            while index + window < samples.count {
                let slice = samples[index..<(index + window)]
                envelope.append((slice.reduce(0) { $0 + $1 * $1 } / Double(window)).squareRoot())
                index += window
            }
            let peak = envelope.max() ?? 0
            guard peak > 0 else { return 0 }
            // 최대의 25%를 넘는 구간이 몇 덩어리인가.
            var count = 0
            var inside = false
            for value in envelope {
                if value > peak * 0.25, !inside { count += 1; inside = true }
                if value < peak * 0.12 { inside = false }
            }
            return count
        }
        XCTAssertGreaterThanOrEqual(beats(.umpireStrike), 2, "스트라이크 콜이 한 박으로 들립니다")
    }

    /// 들어 보라고 파일로 내보낸다.
    ///
    /// 신호 검사는 "목소리가 아닌 것"만 잡는다. 만족스러운지는 사람이 들어야 안다.
    /// `-baseball.audio.export <디렉터리>`를 주면 그 자리에 WAV를 쓴다.
    func testExportCallsForListening() throws {
        let directory = NSTemporaryDirectory()
        for (cue, name) in [(GameAudioCue.umpireStrike, "umpire-strike"),
                            (.crowdCheer, "crowd-cheer"), (.crowdGroan, "crowd-groan")] {
            let samples = render(cue, seconds: 2.0)
            var data = Data()
            func append(_ text: String) { data.append(contentsOf: Array(text.utf8)) }
            func append32(_ value: UInt32) { withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) } }
            func append16(_ value: UInt16) { withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) } }
            let dataSize = samples.count * 2
            append("RIFF"); append32(UInt32(36 + dataSize)); append("WAVE")
            append("fmt "); append32(16); append16(1); append16(1)
            append32(UInt32(sampleRate)); append32(UInt32(sampleRate) * 2); append16(2); append16(16)
            append("data"); append32(UInt32(dataSize))
            for sample in samples {
                append16(UInt16(bitPattern: Int16(max(-1, min(1, sample * 0.8)) * 32_000)))
            }
            let url = URL(fileURLWithPath: directory).appendingPathComponent("\(name).wav")
            try data.write(to: url)
            print("AUDIO_EXPORT \(url.path)")
        }
    }

    /// 콜이 길면 다음 투구를 덮는다. 심판은 짧게 외친다.
    func testCallsStayShort() {
        for cue in [GameAudioCue.umpireStrike] {
            let longest = GameAudio.voices(for: cue).map { $0.delay + $0.duration }.max() ?? 0
            XCTAssertLessThan(longest, 0.6, "\(cue) 콜이 \(longest)초로 너무 깁니다")
        }
    }
}
