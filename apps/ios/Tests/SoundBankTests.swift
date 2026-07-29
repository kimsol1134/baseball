import XCTest
import AVFoundation
@testable import BaseballIOS

/// 번들 음원이 실제로 실려서 읽히는지 본다.
///
/// 이 검사가 없으면 파일 이름을 한 글자 틀리거나 Xcode 프로젝트에서 리소스가 빠져도 아무 일도
/// 일어나지 않는다 — 조용히 합성음으로 되돌아가고, 그걸 알아채는 사람은 아무도 없다.
final class SoundBankTests: XCTestCase {

    func testCrowdLoopIsBundledAndReadable() throws {
        let bank = SoundBank()
        bank.load(bundle: Bundle(for: SoundBankTests.self))
        // 유닛 테스트 번들에는 앱 리소스가 없을 수 있으므로 앱 번들도 함께 본다.
        let appBank = SoundBank()
        appBank.load()

        let loaded = bank.loadedAssets.union(appBank.loadedAssets)
        XCTAssertTrue(
            loaded.contains(.crowdLoop),
            "관중 루프가 번들에 없습니다. apps/ios/Audio/crowd-loop.* 와 project.yml의 Audio 폴더를 확인하세요."
        )

        let buffer = bank.buffer(for: .crowdLoop) ?? appBank.buffer(for: .crowdLoop)
        let unwrapped = try XCTUnwrap(buffer, "관중 루프를 PCM으로 읽지 못했습니다.")
        XCTAssertEqual(unwrapped.format.channelCount, 2, "관중 소리는 스테레오여야 좌우가 살아난다.")
        XCTAssertGreaterThan(unwrapped.frameLength, AVAudioFrameCount(unwrapped.format.sampleRate * 8),
                             "루프가 너무 짧으면 반복이 금방 티가 난다.")
    }

    /// 타격음과 포구음이 실제로 실려서 읽히는지 본다.
    ///
    /// 이 둘이 야구 손맛의 본체다. 파일이 빠지면 조용히 합성 노이즈로 되돌아가고, 소리만으로는
    /// 이 게임이 야구인지 알 수 없게 된다.
    func testImpactRecordingsAreBundled() throws {
        let bank = SoundBank()
        bank.load()
        for asset in [
            SoundAsset.batContactHard, .batContactWeak, .batFoul, .gloveCatch,
            .umpireStrike, .swingMiss, .crowdCheer, .crowdGroan,
        ] {
            XCTAssertTrue(
                bank.loadedAssets.contains(asset),
                "\(asset.rawValue) 음원이 번들에 없습니다. apps/ios/Audio/를 확인하세요."
            )
            let buffer = try XCTUnwrap(bank.buffer(for: asset), "\(asset.rawValue)을 PCM으로 읽지 못했습니다.")
            let seconds = Double(buffer.frameLength) / buffer.format.sampleRate
            // 한 방 소리는 짧아야 한다. 길면 판정과 소리가 어긋나고 다음 큐를 덮는다.
            // 관중 반응만은 예외 — 함성·탄식은 붓듯이 일어났다 가라앉는 소리라 1초로
            // 자르면 뚝 끊긴 티가 난다. 파울 팁은 스치는 소리라 0.1초보다 짧을 수 있다.
            let bounds: ClosedRange<Double> = switch asset {
            case .crowdCheer, .crowdGroan: 1.0...5.0
            case .batFoul: 0.03...0.5
            default: 0.1...1.0
            }
            XCTAssertTrue(
                bounds.contains(seconds),
                "\(asset.rawValue)이 \(seconds)초 — 기대 범위 \(bounds)를 벗어났습니다."
            )
            // **들리는 소리인지도 본다.** 파일이 실려 있고 길이가 맞아도 내용이 디지털
            // 무음일 수 있다 — 실제로 잘림 명령의 페이드 버그로 무음 심판 콜을 번들에
            // 넣을 뻔했다. 길이·존재 검사만으로는 그걸 절대 못 잡는다.
            var peak: Float = 0
            if let data = buffer.floatChannelData {
                for channel in 0..<Int(buffer.format.channelCount) {
                    for frame in 0..<Int(buffer.frameLength) {
                        peak = max(peak, abs(data[channel][frame]))
                    }
                }
            }
            XCTAssertGreaterThan(peak, 0.05, "\(asset.rawValue)이 사실상 무음입니다(피크 \(peak)).")
        }
    }

    /// 이음매가 들리지 않으려면 루프의 시작과 끝의 크기가 비슷해야 한다. 파일을 갈아 끼울 때
    /// 이 검사가 실패하면 크로스페이드를 다시 걸어야 한다는 뜻이다.
    func testCrowdLoopEndsWhereItBegins() throws {
        let bank = SoundBank()
        bank.load()
        guard let buffer = bank.buffer(for: .crowdLoop), let data = buffer.floatChannelData else {
            throw XCTSkip("관중 루프가 없어 건너뜁니다.")
        }
        let frames = Int(buffer.frameLength)
        let window = Int(buffer.format.sampleRate * 0.5)
        guard frames > window * 4 else { throw XCTSkip("루프가 너무 짧습니다.") }

        func rms(from start: Int) -> Double {
            var sum = 0.0
            for index in start..<(start + window) {
                let value = Double(data[0][index])
                sum += value * value
            }
            return (sum / Double(window)).squareRoot()
        }

        let head = rms(from: 0)
        let tail = rms(from: frames - window)
        let ratio = max(head, tail) / max(1e-6, min(head, tail))
        XCTAssertLessThan(ratio, 1.6, "루프의 처음과 끝 크기가 \(ratio)배 차이납니다. 반복할 때 튑니다.")
    }

    /// 소리 종류마다 음원이 있으면 쓰고 없으면 합성으로 간다. 그 갈림이 실제로 작동하는지 본다.
    func testAssetMappingCoversPlayableCues() {
        XCTAssertEqual(SoundAsset.asset(for: .batContact(power: 0.9)), .batContactHard)
        XCTAssertEqual(SoundAsset.asset(for: .batContact(power: 0.2)), .batContactWeak)
        XCTAssertEqual(SoundAsset.asset(for: .gloveCatch), .gloveCatch)
        // 화면 피드백 음은 녹음을 쓰지 않는다.
        XCTAssertNil(SoundAsset.asset(for: .uiSelect))
        XCTAssertNil(SoundAsset.asset(for: .growth))
        XCTAssertNil(SoundAsset.asset(for: .milestone))
    }
}
