import XCTest
import AVFoundation
@testable import BaseballIOS

/// 메뉴 음악 패드가 "음악처럼" 존재하는지 신호로 확인한다.
final class PadBedTests: XCTestCase {
    private let sampleRate = 44_100.0

    private func render(seconds: Double, intensity: Double = 0.5) -> [Double] {
        let pad = PadBed()
        pad.setTarget(intensity: intensity)
        let block = 512
        let total = Int(sampleRate * seconds)
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(block))!
        var out: [Double] = []
        out.reserveCapacity(total)
        var rendered = 0
        while rendered < total {
            buffer.frameLength = AVAudioFrameCount(block)
            pad.render(frameCount: block, into: UnsafeMutableAudioBufferListPointer(buffer.mutableAudioBufferList))
            let left = buffer.floatChannelData![0]
            let right = buffer.floatChannelData![1]
            for index in 0..<block { out.append(Double(left[index] + right[index]) * 0.5) }
            rendered += block
        }
        return out
    }

    /// 소리가 나야 하고, 그러나 **배경**이어야 한다. 피크가 크면 음악이 아니라 소음이다.
    func testPadIsAudibleButQuiet() {
        let samples = render(seconds: 6)
        let tail = samples.suffix(Int(sampleRate * 2))
        let rms = (tail.reduce(0) { $0 + $1 * $1 } / Double(tail.count)).squareRoot()
        XCTAssertGreaterThan(rms, 0.003, "패드가 사실상 무음입니다")
        let peak = tail.map(abs).max() ?? 0
        XCTAssertLessThan(peak, 0.3, "패드가 배경이 아니라 전경입니다(피크 \(peak))")
    }

    /// 꺼짐 목표(0)로 두면 실제로 조용하다. 설정 토글의 계약이다.
    func testZeroTargetStaysSilent() {
        let pad = PadBed()
        pad.setTarget(intensity: 0)
        let block = 512
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(block))!
        var energy = 0.0
        for _ in 0..<40 {
            buffer.frameLength = AVAudioFrameCount(block)
            pad.render(frameCount: block, into: UnsafeMutableAudioBufferListPointer(buffer.mutableAudioBufferList))
            let left = buffer.floatChannelData![0]
            for index in 0..<block { energy += Double(left[index] * left[index]) }
        }
        XCTAssertLessThan(energy, 0.001, "목표 0인데 소리가 납니다")
    }

    /// 화음이 넘어가는 자리에 급격한 진폭 변화(클릭)가 없어야 한다.
    ///
    /// 위상 복사 이음이 깨지면 여기서 잡힌다 — 18초마다 딱 소리가 나는 음악은 못 쓴다.
    func testChordTransitionHasNoClick() {
        // 클릭은 **샘플 미분의 이상치**다. 창 RMS로 재면 화음 자체의 맥놀이(성부 간
        // 56~91Hz 차이)가 창 크기와 얽혀 가짜 실패가 난다 — 실제로 두 번 속았다.
        // 경계 구간의 최대 |Δx|가 평상 구간의 최대 |Δx|와 같은 수준이면 클릭이 없다.
        let samples = render(seconds: 20)
        func maxDelta(_ from: Double, _ to: Double) -> Double {
            let start = Int(sampleRate * from)
            let end = min(Int(sampleRate * to), samples.count)
            var maxValue = 0.0
            for index in (start + 1)..<end {
                maxValue = max(maxValue, abs(samples[index] - samples[index - 1]))
            }
            return maxValue
        }
        let boundary = maxDelta(17.5, 18.5)   // 화음 경계
        let reference = maxDelta(10.0, 11.0)  // 평상 구간
        XCTAssertLessThan(
            boundary, reference * 2 + 0.0005,
            "경계의 샘플 미분(\(boundary))이 평상(\(reference))의 두 배를 넘습니다 — 클릭으로 들립니다"
        )
    }

    /// 들어 보라고 파일로 내보낸다. 40초 — 화음 두 번이 넘어가는 길이다.
    func testExportPadForListening() throws {
        let samples = render(seconds: 40)
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
            append16(UInt16(bitPattern: Int16(max(-1, min(1, sample * 4)) * 24_000)))
        }
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("menu-pad.wav")
        try data.write(to: url)
        print("AUDIO_EXPORT \(url.path)")
    }
}
