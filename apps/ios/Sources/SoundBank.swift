import AVFoundation
import Foundation

/// 번들에 들어 있는 녹음 음원. 있으면 합성 대신 이걸 쓴다.
///
/// 왜 두 벌인가: 관중 웅성거림처럼 여러 사람의 목소리가 겹치는 소리는 합성으로 흉내 낼 수 없다.
/// 반대로 실제 녹음은 용량을 먹고 라이선스가 붙는다. 그래서 **샘플이 있으면 샘플, 없으면 합성**으로
/// 자동으로 갈린다. 음원을 한 장씩 넣을 때마다 그 큐만 조용히 좋아지고, 하나도 없어도 게임은
/// 지금과 똑같이 돌아간다.
///
/// 음원을 추가하려면 `apps/ios/Resources/Audio/`에 아래 이름으로 넣고 `CREDITS.md`에 출처와
/// 라이선스를 적는다. 적지 않은 파일은 쓰지 않는다 — 유료 앱에서 출처 불명 음원은 그 자체가 위험이다.
enum SoundAsset: String, CaseIterable {
    case pitchRelease = "pitch-release"
    case gloveCatch = "glove-catch"
    case swingMiss = "swing-miss"
    case batContactHard = "bat-contact-hard"
    case batContactWeak = "bat-contact-weak"
    case batFoul = "bat-foul"
    case umpireStrike = "umpire-strike"
    case umpireBall = "umpire-ball"
    case crowdCheer = "crowd-cheer"
    case crowdGroan = "crowd-groan"
    /// 이어서 도는 관중 웅성거림. 이 하나만 넣어도 체감이 가장 크게 바뀐다.
    case crowdLoop = "crowd-loop"
    /// 메뉴·커리어 화면 아래 이어 도는 음악. 파일이 없으면 합성 패드가 대신 깔린다.
    /// 이어 붙는 루프이므로 무손실(wav/aiff/caf/ALAC)이어야 한다 — 손실 압축은 이음매에 틈이 생긴다.
    case menuTheme = "menu-theme"

    /// 큐를 음원으로 옮긴다. 타격은 세기에 따라 두 장으로 갈린다.
    static func asset(for cue: GameAudioCue) -> SoundAsset? {
        switch cue {
        case .pitchRelease: .pitchRelease
        case .gloveCatch: .gloveCatch
        case .swingMiss: .swingMiss
        case .batContact(let power): power >= 0.55 ? .batContactHard : .batContactWeak
        case .batFoul: .batFoul
        case .umpireStrike: .umpireStrike
        case .umpireBall: .umpireBall
        case .crowdCheer: .crowdCheer
        case .crowdGroan: .crowdGroan
        // 성장·기념·UI 음은 게임 안의 소리가 아니라 화면 피드백이다. 맑은 합성음이 더 맞고,
        // 녹음을 넣으면 오히려 다른 앱에서 들어 본 소리처럼 들린다.
        case .growth, .milestone, .uiSelect: nil
        }
    }
}

/// 번들 음원을 미리 읽어 두는 창고. 재생 시점에 디스크를 읽으면 첫 소리가 늦게 난다.
final class SoundBank: @unchecked Sendable {
    private var buffers: [SoundAsset: AVAudioPCMBuffer] = [:]
    private let lock = NSLock()

    /// 지원 확장자. 무압축이 가장 빠르지만 용량이 커서 m4a도 받는다.
    private static let extensions = ["wav", "m4a", "caf", "aiff", "mp3"]

    /// 번들에서 찾을 수 있는 것을 모두 읽는다. 없는 것은 조용히 건너뛴다.
    func load(bundle: Bundle = .main) {
        var loaded: [SoundAsset: AVAudioPCMBuffer] = [:]
        for asset in SoundAsset.allCases {
            guard let url = Self.url(for: asset, in: bundle) else { continue }
            guard let file = try? AVAudioFile(forReading: url) else { continue }
            let frames = AVAudioFrameCount(file.length)
            guard frames > 0,
                  let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: frames),
                  (try? file.read(into: buffer)) != nil else { continue }
            loaded[asset] = buffer
        }
        lock.lock()
        buffers = loaded
        lock.unlock()
    }

    private static func url(for asset: SoundAsset, in bundle: Bundle) -> URL? {
        for ext in extensions {
            if let url = bundle.url(forResource: asset.rawValue, withExtension: ext, subdirectory: "Audio") {
                return url
            }
            if let url = bundle.url(forResource: asset.rawValue, withExtension: ext) {
                return url
            }
        }
        return nil
    }

    func buffer(for asset: SoundAsset) -> AVAudioPCMBuffer? {
        lock.lock()
        defer { lock.unlock() }
        return buffers[asset]
    }

    var isEmpty: Bool {
        lock.lock()
        defer { lock.unlock() }
        return buffers.isEmpty
    }

    /// 어떤 음원이 실제로 실렸는지. 테스트와 진단에서 쓴다.
    var loadedAssets: Set<SoundAsset> {
        lock.lock()
        defer { lock.unlock() }
        return Set(buffers.keys)
    }
}
