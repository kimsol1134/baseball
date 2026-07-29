import AVFoundation
import Foundation
import Observation

/// 화면이 요청하는 소리의 종류. 합성 방식이 바뀌어도 호출부는 이 목록만 안다.
enum GameAudioCue: Equatable {
    case pitchRelease
    case gloveCatch
    case swingMiss
    /// 타구 세기 0~1. 잘 맞을수록 낮고 두꺼운 소리가 난다.
    case batContact(power: Double)
    case batFoul
    case umpireStrike
    case umpireBall
    case umpireStrikeout
    case crowdCheer
    case crowdGroan
    case growth
    case milestone
    case uiSelect
}

/// 게임 오디오. 녹음 음원이 있으면 그것을, 없으면 절차 합성을 쓴다.
///
/// 두 벌인 이유는 서로 잘하는 것이 다르기 때문이다. 관중 웅성거림처럼 사람 목소리가 겹치는
/// 소리는 합성으로 흉내 낼 수 없고, 반대로 합성은 용량이 0이고 타구 세기·레버리지 같은 게임
/// 상태에 연속적으로 반응한다. 그래서 큐 단위로 갈린다 — `Audio/`에 음원을 한 장 넣을 때마다
/// 그 소리만 조용히 좋아지고, 한 장도 없으면 지금처럼 전부 합성으로 난다(SoundBank.swift).
///
/// 시스템 예절: `.ambient` + `.mixWithOthers`라 사용자가 듣던 음악을 끊지 않고 무음 스위치를
/// 존중한다. 게임이 남의 음악을 멈추는 것은 유료앱에서 즉시 별점 1점짜리 결함이다.
@MainActor
@Observable
final class GameAudio {
    static let shared = GameAudio()

    private(set) var isRunning = false

    /// 관중 밀도 0~1. 레버리지가 높을수록 웅성거림이 두꺼워진다.
    var crowdIntensity: Double = 0.25 {
        didSet {
            crowd.setTarget(intensity: crowdIntensity)
            // 녹음 음원을 쓰는 중이면 볼륨으로 밀도를 표현한다. 0.35를 곱하는 이유는
            // 관중은 배경이지 주인공이 아니기 때문이다.
            crowdPlayer?.volume = Float(min(1, max(0, crowdIntensity))) * 0.35
        }
    }

    var soundEnabled: Bool {
        didSet {
            UserDefaults.standard.set(soundEnabled, forKey: Self.soundKey)
            soundEnabled ? start() : stop()
        }
    }

    /// 음악 0~1. 메뉴·커리어 화면에서 깔리고 승부 중에는 0으로 내린다 —
    /// 마운드에서는 관중과 심판이 음악이다.
    var musicIntensity: Double = 0.5 {
        didSet { applyMusicVolume() }
    }

    /// 음악만 따로 끌 수 있다. 소리는 좋은데 음악은 싫은 사람이 실제로 있다.
    var musicEnabled: Bool {
        didSet {
            UserDefaults.standard.set(musicEnabled, forKey: Self.musicKey)
            applyMusicVolume()
        }
    }

    private func applyMusicVolume() {
        let effective = musicEnabled ? min(1, max(0, musicIntensity)) : 0
        pad.setTarget(intensity: effective)
        // 녹음 음원을 쓰는 중이면 볼륨으로. 0.28은 음악이 배경이라는 뜻이다.
        musicPlayer?.volume = Float(effective) * 0.28
    }

    var hapticsEnabled: Bool {
        didSet { UserDefaults.standard.set(hapticsEnabled, forKey: Self.hapticsKey) }
    }

    private static let soundKey = "baseball.audio.sound"
    private static let hapticsKey = "baseball.audio.haptics"
    private static let musicKey = "baseball.audio.music"
    private static let sampleRate: Double = 44_100

    private let engine = AVAudioEngine()
    private let voices = VoiceBank()
    private let crowd = CrowdBed()
    private let pad = PadBed()
    private var attached = false

    /// 번들에 실린 녹음 음원. 있으면 합성보다 먼저 쓴다.
    private let bank = SoundBank()
    /// 단발 음원 재생기. 한 노드로 돌리면 앞선 소리가 끊기므로 돌아가며 쓴다.
    private var samplePlayers: [AVAudioPlayerNode] = []
    private var nextPlayer = 0
    /// 이어 도는 관중 음원. 있으면 CrowdBed 대신 이걸 튼다.
    private var crowdPlayer: AVAudioPlayerNode?
    /// 이어 도는 음악 음원. 있으면 합성 패드 대신 이걸 튼다.
    private var musicPlayer: AVAudioPlayerNode?

    private init() {
        let defaults = UserDefaults.standard
        defaults.register(defaults: [Self.soundKey: true, Self.hapticsKey: true])
        defaults.register(defaults: [Self.musicKey: true])
        soundEnabled = defaults.bool(forKey: Self.soundKey)
        hapticsEnabled = defaults.bool(forKey: Self.hapticsKey)
        musicEnabled = defaults.bool(forKey: Self.musicKey)
    }

    // MARK: - 수명 주기

    func start() {
        guard soundEnabled, !isRunning else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            attachNodesIfNeeded()
            try engine.start()
            // 루프는 엔진이 돌기 시작한 뒤에 재생을 걸어야 한다.
            if let player = crowdPlayer, !player.isPlaying { player.play() }
            if let player = musicPlayer, !player.isPlaying { player.play() }
            isRunning = true
        } catch {
            // 오디오는 게임 진행의 전제 조건이 아니다. 실패하면 조용히 무음으로 간다.
            isRunning = false
        }
    }

    func stop() {
        guard isRunning else { return }
        crowdPlayer?.pause()
        for player in samplePlayers { player.stop() }
        engine.pause()
        voices.reset()
        isRunning = false
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }

    func play(_ cue: GameAudioCue) {
        guard soundEnabled else { return }
        if !isRunning { start() }
        guard isRunning else { return }
        // 엔진은 우리 플래그와 무관하게 밖에서 멈출 수 있다 — 오디오 서버 리셋, 인터럽션,
        // 출력 장치 변경(이어폰 분리). 멈춘 엔진의 플레이어에 버퍼를 걸면 NSException으로
        // 앱이 통째로 죽는다. 소리는 게임의 전제 조건이 아니므로, 되살리지 못하면 조용히 접는다.
        if !engine.isRunning {
            isRunning = false
            start()
            guard isRunning, engine.isRunning else { return }
        }
        // 녹음 음원이 있으면 그것을, 없으면 합성으로. 큐 단위로 갈리므로 음원을 하나씩
        // 채워 넣을 수 있고, 하나도 없어도 지금과 똑같이 들린다.
        if let asset = SoundAsset.asset(for: cue), let buffer = bank.buffer(for: asset) {
            playSample(buffer, gain: Self.sampleGain(for: cue))
            return
        }
        for voice in Self.voices(for: cue) { self.voices.add(voice) }
    }

    /// 음원마다 녹음 레벨이 제각각이라 큐별로 한 번 더 눌러 준다. 합성음과 크기가 맞아야
    /// 두 벌이 섞여 있어도 어색하지 않다.
    private static func sampleGain(for cue: GameAudioCue) -> Float {
        switch cue {
        case .batContact(let power): 0.7 + 0.3 * Float(min(1, max(0, power)))
        case .crowdCheer, .crowdGroan: 0.8
        case .pitchRelease: 0.5
        default: 0.85
        }
    }

    private func playSample(_ buffer: AVAudioPCMBuffer, gain: Float) {
        guard !samplePlayers.isEmpty else { return }
        let player = samplePlayers[nextPlayer]
        nextPlayer = (nextPlayer + 1) % samplePlayers.count
        player.volume = gain
        // 이미 무언가 울리고 있으면 멈추고 새로 건다. 미트 소리가 겹쳐 뭉치는 것보다 낫다.
        player.stop()
        player.scheduleBuffer(buffer, at: nil, options: [.interrupts], completionHandler: nil)
        player.play()
    }

    private func attachNodesIfNeeded() {
        guard !attached else { return }
        attached = true
        let format = AVAudioFormat(standardFormatWithSampleRate: Self.sampleRate, channels: 2)!

        // 번들 음원을 먼저 읽는다. 무엇이 실려 있는지에 따라 아래에서 붙일 노드가 달라진다.
        bank.load()

        let cueNode = Self.makeSourceNode(format: format, renderer: voices)
        engine.attach(cueNode)
        engine.connect(cueNode, to: engine.mainMixerNode, format: format)

        // 관중: 녹음 루프가 있으면 그것을, 없으면 합성 베드를.
        if let loop = bank.buffer(for: .crowdLoop) {
            let player = AVAudioPlayerNode()
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: loop.format)
            player.volume = Float(crowdIntensity) * 0.35
            player.scheduleBuffer(loop, at: nil, options: [.loops], completionHandler: nil)
            crowdPlayer = player
        } else {
            let crowdNode = Self.makeSourceNode(format: format, renderer: crowd)
            engine.attach(crowdNode)
            engine.connect(crowdNode, to: engine.mainMixerNode, format: format)
        }

        // 음악: 녹음 루프가 있으면 그것을, 없으면 합성 패드를.
        //
        // "유료 게임의 첫 30초에 음악이 없으면 미완성 앱으로 읽힌다"는 지적에 대한 답이다.
        // 관중 루프와 같은 두 벌 구조라, 나중에 실제 곡을 `menu-theme`로 넣으면 코드 변경
        // 없이 교체된다.
        if let theme = bank.buffer(for: .menuTheme) {
            let player = AVAudioPlayerNode()
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: theme.format)
            player.volume = Float(musicEnabled ? musicIntensity : 0) * 0.28
            player.scheduleBuffer(theme, at: nil, options: [.loops], completionHandler: nil)
            musicPlayer = player
        } else {
            let padNode = Self.makeSourceNode(format: format, renderer: pad)
            engine.attach(padNode)
            engine.connect(padNode, to: engine.mainMixerNode, format: format)
            pad.setTarget(intensity: musicEnabled ? musicIntensity : 0)
        }

        // 단발 음원 재생기. 미트 소리와 관중 반응이 겹치는 순간이 있어 여러 장이 필요하다.
        if !bank.isEmpty {
            for _ in 0..<4 {
                let player = AVAudioPlayerNode()
                engine.attach(player)
                engine.connect(player, to: engine.mainMixerNode, format: nil)
                samplePlayers.append(player)
            }
        }

        engine.mainMixerNode.outputVolume = 0.85
    }

    /// 렌더 콜백을 **반드시 nonisolated로** 만든다.
    ///
    /// `AVAudioSourceNode`의 블록은 실시간 오디오 스레드에서 불린다. `@MainActor` 클래스 안에서
    /// 클로저를 그대로 만들면 Swift가 메인 액터 격리 검사를 끼워 넣고, 오디오 스레드에서
    /// `dispatch_assert_queue`가 실패해 앱이 SIGTRAP으로 죽는다. 여기서 액터 밖으로 빼낸다.
    private nonisolated static func makeSourceNode(
        format: AVAudioFormat,
        renderer: some AudioRenderer
    ) -> AVAudioSourceNode {
        AVAudioSourceNode(format: format) { _, _, frameCount, buffers in
            renderer.render(
                frameCount: Int(frameCount),
                into: UnsafeMutableAudioBufferListPointer(buffers)
            )
            return noErr
        }
    }

    // MARK: - 큐 → 보이스

    /// 각 큐를 프리미티브 보이스의 조합으로 옮긴다. 순수 함수라 테스트할 수 있다.
    ///
    /// 소리마다 좌우 위치(`pan`)를 준다. 전부 가운데서 나면 한 점에서 삐 소리가 나는 것처럼
    /// 들리고, 마운드에서 홈플레이트를 보는 시점이 만들어지지 않는다.
    nonisolated static func voices(for cue: GameAudioCue) -> [Voice] {
        switch cue {
        case .pitchRelease:
            // 유니폼이 스치고 공이 손을 떠난다. 손이 몸 옆에 있으니 살짝 오른쪽.
            return [
                .noise(duration: 0.11, attack: 0.006, gain: 0.062, centerHz: 1_900, bandwidth: 1.4, pan: 0.22),
                .sweep(duration: 0.09, attack: 0.004, gain: 0.03, fromHz: 260, toHz: 150, pan: 0.22),
            ]

        case .gloveCatch:
            // 가죽 미트는 "퍽"이다. 짧고 밝은 어택 + 아래로 떨어지는 몸통.
            // 예전에는 노이즈 한 겹에 180Hz 삼각파여서 종이 치는 소리에 가까웠다.
            return [
                .noise(duration: 0.045, attack: 0.0005, gain: 0.16, centerHz: 2_600, bandwidth: 2.4, curve: 3.4),
                .noise(duration: 0.09, attack: 0.001, gain: 0.11, centerHz: 620, bandwidth: 1.0, curve: 2.6),
                .sweep(duration: 0.1, attack: 0.0008, gain: 0.077, fromHz: 210, toHz: 78),
            ]

        case .swingMiss:
            // 배트가 공기를 가르며 소리가 위에서 아래로 지나간다. 포구음이 뒤따른다.
            return [
                .noise(duration: 0.16, attack: 0.03, gain: 0.055, centerHz: 2_800, bandwidth: 3.0, pan: -0.35),
                .sweep(duration: 0.14, attack: 0.02, gain: 0.03, fromHz: 900, toHz: 240, pan: -0.2),
            ] + voices(for: .gloveCatch).map { $0.delayed(by: 0.11) }

        case .batContact(let power):
            // 방망이 소리는 "딱" 하는 순간의 고역과 뒤따르는 몸통으로 갈린다.
            // 잘 맞을수록 몸통이 낮고 두꺼워지고, 빗맞으면 고역만 남아 얇다.
            let hit = min(1, max(0, power))
            return [
                .noise(duration: 0.03, attack: 0.0003, gain: 0.14 + 0.08 * hit,
                       centerHz: 4_200 - 1_400 * hit, bandwidth: 2.8, curve: 4.0),
                .sweep(duration: 0.11 + 0.07 * hit, attack: 0.0005, gain: 0.08 + 0.1 * hit,
                       fromHz: 300 - 110 * hit, toHz: 110 - 45 * hit),
                .noise(duration: 0.07, attack: 0.001, gain: 0.05 + 0.056 * hit,
                       centerHz: 800 - 260 * hit, bandwidth: 1.2),
            ]

        case .batFoul:
            // 빗맞은 파울. 고역만 짧게.
            return [
                .noise(duration: 0.035, attack: 0.0004, gain: 0.16, centerHz: 4_800, bandwidth: 3.2, curve: 4.0, pan: 0.3),
                .sweep(duration: 0.05, attack: 0.0005, gain: 0.057, fromHz: 340, toHz: 200, pan: 0.3),
            ]

        case .umpireStrike:
            // 심판의 외침. **목소리로 합성한다.**
            //
            // 예전에는 목소리 대역의 밴드패스 노이즈였다. 대역을 아무리 맞춰도 음정이 없어서
            // "쉬" 소리로 남았고, 야구장이 아니라 메뉴에서 나는 소리로 들렸다.
            //
            // 스트라이크 콜은 두 박이다 — 짧게 끊고("스트라") 길게 지른다("이크"). 두 번째가
            // 더 높고 길다. 그래서 첫 박은 짧고 낮게, 둘째 박은 음정이 올라갔다 떨어지게 잡았다.
            // 모음은 "아"(700·1150·2500) → "이"에 가까운 밝은 쪽(520·1800·2600)으로 옮긴다.
            //
            // 마지막 한 겹은 **반사음**이다. 심판은 포수 뒤에 있고 그 소리는 백스톱을 때리고
            // 돌아온다. 이 겹이 없으면 소리가 머릿속에서 나고, 있으면 구장에서 난다.
            return [
                .shout(duration: 0.11, attack: 0.008, gain: 0.115,
                       pitchHz: 138, glide: 1.06, formants: (700, 1_150, 2_500),
                       breath: 0.10, curve: 2.4, pan: -0.45),
                .shout(duration: 0.30, attack: 0.010, gain: 0.135,
                       pitchHz: 152, glide: 1.28, formants: (520, 1_800, 2_600),
                       breath: 0.14, curve: 1.5, delay: 0.11, pan: -0.45),
                .noise(duration: 0.07, attack: 0.004, gain: 0.030, centerHz: 3_400, bandwidth: 1.6,
                       curve: 3.0, delay: 0.38, pan: -0.4),
                .shout(duration: 0.20, attack: 0.02, gain: 0.030,
                       pitchHz: 152, glide: 1.28, formants: (520, 1_800, 2_600),
                       breath: 0.2, curve: 2.2, delay: 0.17, pan: 0.35),
            ]

        case .umpireStrikeout:
            // 삼진 풀콜("스트라이크 쓰리, 유어 아웃"). 스트라이크 콜과 같은 목소리로
            // 시작해 한 박 쉬고 "아웃"에 힘이 실린다. 파일이 있으면 실제 심판의 이어지는
            // 한 호흡이 나가고, 이 합성은 파일이 빠졌을 때의 안전망이다.
            return [
                .shout(duration: 0.11, attack: 0.008, gain: 0.11,
                       pitchHz: 138, glide: 1.06, formants: (700, 1_150, 2_500),
                       breath: 0.10, curve: 2.4, pan: -0.45),
                .shout(duration: 0.24, attack: 0.010, gain: 0.125,
                       pitchHz: 150, glide: 1.22, formants: (520, 1_800, 2_600),
                       breath: 0.14, curve: 1.6, delay: 0.11, pan: -0.45),
                .shout(duration: 0.10, attack: 0.008, gain: 0.10,
                       pitchHz: 128, glide: 1.02, formants: (450, 1_000, 2_400),
                       breath: 0.12, curve: 2.6, delay: 0.52, pan: -0.45),
                .shout(duration: 0.34, attack: 0.012, gain: 0.14,
                       pitchHz: 146, glide: 1.22, formants: (640, 1_050, 2_450),
                       breath: 0.14, curve: 1.6, delay: 0.62, pan: -0.45),
                .noise(duration: 0.07, attack: 0.004, gain: 0.028, centerHz: 3_200, bandwidth: 1.6,
                       curve: 3.0, delay: 0.92, pan: -0.4),
            ]

        case .umpireBall:
            // **볼 콜은 소리가 없다.** 실제 심판은 볼을 외치지 않는다 — 스트라이크만 지르고
            // 볼은 자세로만 표시하거나 낮게 말한다. 합성 목소리로 두 콜을 다 내 봤지만
            // "볼이 이상하다"는 실기기 피드백이 맞았다. 미트 소리가 이미 공 하나를 표시하므로
            // 볼에는 콜을 얹지 않는 쪽이 오히려 야구답다. (음원 슬롯 `umpire-ball`은 남겨 둔다 —
            // 파일을 넣으면 그때부터 난다.)
            return []

        case .crowdCheer:
            // 함성은 한 번에 터지지 않는다. 웅성거림이 부풀고 위쪽 대역이 뒤늦게 따라온다.
            return [
                .noise(duration: 1.5, attack: 0.16, gain: 0.168, centerHz: 620, bandwidth: 2.2, curve: 1.3, pan: -0.45),
                .noise(duration: 1.3, attack: 0.22, gain: 0.133, centerHz: 1_500, bandwidth: 2.6, curve: 1.4,
                       delay: 0.09, pan: 0.45),
                .noise(duration: 1.0, attack: 0.3, gain: 0.07, centerHz: 3_000, bandwidth: 3.2, curve: 1.6, delay: 0.18),
            ]

        case .crowdGroan:
            // 탄식은 낮게 깔렸다가 천천히 빠진다.
            return [
                .noise(duration: 1.7, attack: 0.28, gain: 0.154, centerHz: 340, bandwidth: 1.8, curve: 1.2, pan: -0.4),
                .noise(duration: 1.4, attack: 0.34, gain: 0.092, centerHz: 700, bandwidth: 2.0, curve: 1.3,
                       delay: 0.1, pan: 0.4),
            ]

        case .growth:
            // 능력이 올랐다는 신호. 이건 게임 안의 소리가 아니라 UI 피드백이라 맑은 음이 맞다.
            return [
                .tone(duration: 0.13, attack: 0.005, gain: 0.25, frequencyHz: 523, shape: .sine),
                .tone(duration: 0.13, attack: 0.005, gain: 0.25, frequencyHz: 659, shape: .sine, delay: 0.1),
                .tone(duration: 0.3, attack: 0.005, gain: 0.27, frequencyHz: 784, shape: .sine, delay: 0.2),
                .tone(duration: 0.3, attack: 0.008, gain: 0.1, frequencyHz: 1_568, shape: .sine, delay: 0.2),
            ]

        case .milestone:
            return [
                .tone(duration: 0.17, attack: 0.006, gain: 0.21, frequencyHz: 659, shape: .sine),
                .tone(duration: 0.17, attack: 0.006, gain: 0.21, frequencyHz: 988, shape: .sine, delay: 0.13),
                .tone(duration: 0.5, attack: 0.006, gain: 0.25, frequencyHz: 1_319, shape: .sine, delay: 0.26),
                .tone(duration: 0.5, attack: 0.01, gain: 0.095, frequencyHz: 1_976, shape: .sine, delay: 0.26),
            ]

        case .uiSelect:
            return [.tone(duration: 0.03, attack: 0.001, gain: 0.1, frequencyHz: 1_180, shape: .sine)]
        }
    }

    // MARK: - 합성 프리미티브

    enum Shape { case sine, triangle }

    /// 단발 소리 하나.
    struct Voice: Equatable {
        enum Source: Equatable {
            // 튜플 연관값이 있어 Equatable이 자동 합성되지 않는다. 손으로 적는다.
            static func == (lhs: Source, rhs: Source) -> Bool {
                switch (lhs, rhs) {
                case (.noise(let a, let b), .noise(let c, let d)): (a, b) == (c, d)
                case (.tone(let a, let b), .tone(let c, let d)): a == c && b == d
                case (.sweep(let a, let b), .sweep(let c, let d)): (a, b) == (c, d)
                case (.shout(let a, let b, let c, let d), .shout(let e, let f, let g, let h)):
                    a == e && b == f && c == g && d == h
                default: false
                }
            }

            case noise(centerHz: Double, bandwidth: Double)
            case tone(frequencyHz: Double, shape: Shape)
            /// 아래로(또는 위로) 미끄러지는 음. 미트에 꽂히는 소리와 방망이 소리의 몸통이다.
            case sweep(fromHz: Double, toHz: Double)
            /// 사람의 외침.
            ///
            /// 밴드패스 노이즈로는 목소리가 되지 않는다 — 아무리 목소리 대역에 맞춰도 음정이
            /// 없어서 "쉬" 소리로 남는다. 사람 소리로 들리려면 셋이 필요하다:
            /// **음정이 있는 성대 파형**(톱니), **모음을 정하는 공명점 세 개**(포먼트),
            /// 그리고 **음정의 오르내림**. 여기서 그 셋을 만든다.
            ///
            /// - Parameters:
            ///   - pitchHz: 시작 기본 주파수. 성인 남성이 지르면 130~190Hz 근처다.
            ///   - glide: 소리가 끝날 때의 음정 배율. 1보다 크면 올라가고 작으면 내려간다.
            ///   - formants: 공명점 셋(F1·F2·F3). 이 조합이 곧 모음이다 —
            ///     "아"는 대략 (700, 1150, 2500), "오"는 (480, 850, 2400).
            ///   - breath: 섞을 숨소리 양(0~1). 지르는 소리에는 항상 조금 있다.
            case shout(pitchHz: Double, glide: Double, formants: (Double, Double, Double), breath: Double)
        }
        let source: Source
        let duration: Double
        let attack: Double
        let gain: Double
        let delay: Double
        /// 감쇠 기울기. 클수록 빨리 죽는다(타격음), 작을수록 길게 남는다(함성).
        let curve: Double
        /// 좌우 위치 -1(왼쪽)~1(오른쪽).
        let pan: Double

        func delayed(by seconds: Double) -> Voice {
            Voice(source: source, duration: duration, attack: attack, gain: gain,
                  delay: delay + seconds, curve: curve, pan: pan)
        }

        static func noise(
            duration: Double, attack: Double, gain: Double,
            centerHz: Double, bandwidth: Double,
            curve: Double = 2.2, delay: Double = 0, pan: Double = 0
        ) -> Voice {
            Voice(source: .noise(centerHz: centerHz, bandwidth: bandwidth),
                  duration: duration, attack: attack, gain: gain, delay: delay, curve: curve, pan: pan)
        }

        static func tone(
            duration: Double, attack: Double, gain: Double,
            frequencyHz: Double, shape: Shape,
            curve: Double = 2.2, delay: Double = 0, pan: Double = 0
        ) -> Voice {
            Voice(source: .tone(frequencyHz: frequencyHz, shape: shape),
                  duration: duration, attack: attack, gain: gain, delay: delay, curve: curve, pan: pan)
        }

        static func shout(
            duration: Double, attack: Double, gain: Double,
            pitchHz: Double, glide: Double, formants: (Double, Double, Double),
            breath: Double = 0.12,
            curve: Double = 1.6, delay: Double = 0, pan: Double = 0
        ) -> Voice {
            Voice(source: .shout(pitchHz: pitchHz, glide: glide, formants: formants, breath: breath),
                  duration: duration, attack: attack, gain: gain, delay: delay, curve: curve, pan: pan)
        }

        static func sweep(
            duration: Double, attack: Double, gain: Double,
            fromHz: Double, toHz: Double,
            curve: Double = 2.6, delay: Double = 0, pan: Double = 0
        ) -> Voice {
            Voice(source: .sweep(fromHz: fromHz, toHz: toHz),
                  duration: duration, attack: attack, gain: gain, delay: delay, curve: curve, pan: pan)
        }
    }
}

/// 오디오 스레드에서 불리는 렌더러. 메인 액터와 무관해야 한다.
protocol AudioRenderer: Sendable {
    func render(frameCount: Int, into buffers: UnsafeMutableAudioBufferListPointer)
}

/// 오디오 스레드용 난수.
///
/// `SystemRandomNumberGenerator`는 내부적으로 시스템 호출을 할 수 있어 실시간 렌더 콜백에서
/// 쓰면 안 된다. 한 번 튀면 바로 끊김으로 들린다. xorshift는 곱셈·시프트 몇 번이라 안전하다.
private struct FastNoise {
    private var state: UInt64

    init(seed: UInt64) { state = seed | 1 }

    /// -1 ~ 1 백색 잡음.
    mutating func next() -> Double {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        // 상위 24비트만 쓰면 하위 비트의 주기성이 소리에 섞이지 않는다.
        return Double(state >> 40) / 8_388_608.0 - 1.0
    }
}

/// 2극 상태 변수 밴드패스. 예전에는 로우패스 두 개의 차로 흉내 냈는데, 그러면 통과 대역이
/// 뭉개져 어떤 중심 주파수를 줘도 비슷한 "쉬" 소리가 났다.
private struct BandPass {
    var low = 0.0
    var band = 0.0

    /// 중심 주파수와 Q로 한 샘플 통과시킨다.
    mutating func process(_ input: Double, f: Double, q: Double) -> Double {
        let high = input - low - q * band
        band += f * high
        low += f * band
        return band
    }
}

/// 부드러운 포화. 여러 보이스가 겹쳐 1을 넘을 때 딱딱하게 잘리면 지직거린다.
@inline(__always)
private func softClip(_ value: Double) -> Double {
    if value > 1.2 { return 1.0 }
    if value < -1.2 { return -1.0 }
    return value - (value * value * value) / 3.6
}

/// 동시에 울리는 단발 보이스들을 섞는다. 오디오 스레드에서 호출되므로 잠금을 짧게 유지하고
/// 렌더 경로에서 메모리를 할당하지 않는다.
///
/// `private`가 아닌 이유: 홍보 영상의 소리를 이 합성기로 직접 뽑는다(PromoAudioExportTests).
/// 따로 만든 음원을 얹으면 스토어에서 들리는 소리와 게임에서 나는 소리가 달라진다.
final class VoiceBank: AudioRenderer, @unchecked Sendable {
    private struct Live {
        var voice: GameAudio.Voice
        var frame: Int
        var phase: Double
        var filter: BandPass
        /// 사람 목소리는 공명점이 셋이라야 모음으로 들린다. 하나로는 어떤 값을 줘도 "쉬" 소리다.
        var formant2: BandPass
        var formant3: BandPass
        var noise: FastNoise
    }

    private let lock = NSLock()
    private var live: [Live] = []
    private var seedCounter: UInt64 = 0x9E37_79B9_7F4A_7C15
    private static let maximumVoices = 24
    private static let sampleRate = 44_100.0

    func add(_ voice: GameAudio.Voice) {
        lock.lock()
        if live.count < Self.maximumVoices {
            seedCounter = seedCounter &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            live.append(
                Live(voice: voice, frame: 0, phase: 0, filter: BandPass(),
                     formant2: BandPass(), formant3: BandPass(), noise: FastNoise(seed: seedCounter))
            )
        }
        lock.unlock()
    }

    func reset() {
        lock.lock()
        live.removeAll(keepingCapacity: true)
        lock.unlock()
    }

    func render(frameCount: Int, into buffers: UnsafeMutableAudioBufferListPointer) {
        for buffer in buffers {
            memset(buffer.mData, 0, Int(buffer.mDataByteSize))
        }
        lock.lock()
        defer { lock.unlock() }
        guard !live.isEmpty else { return }

        let sampleRate = Self.sampleRate
        let channels = buffers.count
        // 좌우로 나누기 전에 한 번 섞을 자리. 채널마다 따로 포화시키면 위치가 흔들린다.
        for index in live.indices {
            var voice = live[index]
            let delayFrames = Int(voice.voice.delay * sampleRate)
            let totalFrames = Int(voice.voice.duration * sampleRate)
            let attackFrames = max(1, Int(voice.voice.attack * sampleRate))
            let curve = voice.voice.curve

            // 등파워 패닝. 가운데에서 좌우로 갈 때 소리 크기가 유지된다.
            let pan = min(1, max(-1, voice.voice.pan))
            let leftGain = ((1 - pan) / 2).squareRoot()
            let rightGain = ((1 + pan) / 2).squareRoot()

            for frame in 0..<frameCount {
                let position = voice.frame + frame - delayFrames
                guard position >= 0, position < totalFrames else { continue }

                let envelope: Double
                if position < attackFrames {
                    envelope = Double(position) / Double(attackFrames)
                } else {
                    let decayProgress = Double(position - attackFrames) / Double(max(1, totalFrames - attackFrames))
                    envelope = pow(1 - decayProgress, curve)
                }
                // 소리 길이 안에서의 진행도. 스윕이 이 값을 쓴다.
                let progress = Double(position) / Double(totalFrames)

                var sample: Double
                switch voice.voice.source {
                case .noise(let centerHz, let bandwidth):
                    let white = voice.noise.next()
                    let f = min(0.9, 2 * sin(.pi * min(centerHz, sampleRate * 0.45) / sampleRate))
                    let q = min(1.6, max(0.05, bandwidth * 0.22))
                    // 대역이 좁을수록 출력이 작아지므로 Q로 되돌려 준다.
                    sample = voice.filter.process(white, f: f, q: q) * (1.4 / max(0.3, q))
                case .tone(let frequencyHz, let shape):
                    voice.phase += frequencyHz / sampleRate
                    if voice.phase > 1 { voice.phase -= 1 }
                    switch shape {
                    case .sine: sample = sin(voice.phase * 2 * .pi)
                    case .triangle: sample = 4 * abs(voice.phase - 0.5) - 1
                    }
                case .sweep(let fromHz, let toHz):
                    // 주파수는 지수적으로 미끄러져야 사람 귀에 고르게 떨어지는 것으로 들린다.
                    let frequency = fromHz * pow(max(0.02, toHz / fromHz), progress)
                    voice.phase += frequency / sampleRate
                    if voice.phase > 1 { voice.phase -= 1 }
                    sample = sin(voice.phase * 2 * .pi)
                case .shout(let pitchHz, let glide, let formants, let breath):
                    // 성대: 톱니파. 배음이 촘촘해야 공명점이 걸릴 것이 있다.
                    let frequency = pitchHz * pow(max(0.2, glide), progress)
                    voice.phase += frequency / sampleRate
                    if voice.phase > 1 { voice.phase -= 1 }
                    let glottal = 2 * voice.phase - 1
                    let source = glottal * (1 - breath) + voice.noise.next() * breath
                    // 성도: 공명점 셋. 위로 갈수록 약해지는 것이 실제 목소리의 기울기다.
                    func resonate(_ filter: inout BandPass, _ hz: Double, _ weight: Double) -> Double {
                        let f = min(0.9, 2 * sin(.pi * min(hz, sampleRate * 0.45) / sampleRate))
                        return filter.process(source, f: f, q: 0.16) * weight
                    }
                    sample = resonate(&voice.filter, formants.0, 1.0)
                        + resonate(&voice.formant2, formants.1, 0.62)
                        + resonate(&voice.formant3, formants.2, 0.28)
                    sample = tanh(sample * 1.7) * 0.5
                }

                let value = sample * envelope * voice.voice.gain
                if channels >= 2 {
                    buffers[0].mData!.assumingMemoryBound(to: Float.self)[frame] += Float(value * leftGain)
                    buffers[1].mData!.assumingMemoryBound(to: Float.self)[frame] += Float(value * rightGain)
                } else {
                    for buffer in buffers {
                        buffer.mData!.assumingMemoryBound(to: Float.self)[frame] += Float(value)
                    }
                }
            }
            voice.frame += frameCount
            live[index] = voice
        }

        // 겹친 보이스가 1을 넘으면 딱딱하게 잘려 지직거린다. 부드럽게 눌러 준다.
        for buffer in buffers {
            let pointer = buffer.mData!.assumingMemoryBound(to: Float.self)
            for frame in 0..<frameCount {
                pointer[frame] = Float(softClip(Double(pointer[frame])))
            }
        }

        let sampleRateInt = Int(sampleRate)
        live.removeAll { $0.frame > Int(($0.voice.duration + $0.voice.delay) * Double(sampleRateInt)) + 128 }
    }
}

/// 지속되는 관중 웅성거림. 레버리지에 따라 두께가 달라진다. 공개 이유는 `VoiceBank`와 같다.
///
/// 예전에는 백색 잡음에 원폴 로우패스(약 140Hz) 하나만 걸었다. 그러면 관중이 아니라 저역 잡음
/// 소리가 났다. 사람의 웅성거림은 (1) 몸통이 되는 낮은 대역과 (2) 목소리 대역이 함께 있고,
/// (3) 크기가 여러 주기로 느리게 출렁이며, (4) 좌우가 서로 다르다. 넷을 모두 만든다.
final class CrowdBed: AudioRenderer, @unchecked Sendable {
    private let lock = NSLock()
    private var target: Double = 0.25
    private var current: Double = 0

    /// 채널마다 다른 잡음과 필터를 쓴다. 같은 신호를 양쪽에 넣으면 머리 한가운데서 나는
    /// 모노 잡음으로 들린다.
    private struct Channel {
        var noise: FastNoise
        var body = BandPass()
        var voice = BandPass()
    }
    private var channels: [Channel] = [
        Channel(noise: FastNoise(seed: 0x2545_F491_4F6C_DD1D)),
        Channel(noise: FastNoise(seed: 0x9E37_79B9_7F4A_7C15)),
    ]

    /// 서로 나누어떨어지지 않는 세 주기로 출렁이게 한다. 하나만 쓰면 기계적으로 들린다.
    private var swayA = 0.0
    private var swayB = 0.37
    private var swayC = 0.81

    private static let sampleRate = 44_100.0

    func setTarget(intensity: Double) {
        lock.lock()
        target = min(1, max(0, intensity))
        lock.unlock()
    }

    func render(frameCount: Int, into buffers: UnsafeMutableAudioBufferListPointer) {
        for buffer in buffers {
            memset(buffer.mData, 0, Int(buffer.mDataByteSize))
        }
        lock.lock()
        let goal = target
        lock.unlock()

        let sampleRate = Self.sampleRate
        // 출렁임은 블록마다 한 번만 계산한다. 512샘플은 12밀리초라 귀에는 이어져 들린다.
        swayA += 0.13 * Double(frameCount) / sampleRate
        swayB += 0.071 * Double(frameCount) / sampleRate
        swayC += 0.29 * Double(frameCount) / sampleRate
        if swayA > 1 { swayA -= 1 }
        if swayB > 1 { swayB -= 1 }
        if swayC > 1 { swayC -= 1 }
        let sway = 0.66
            + 0.2 * sin(swayA * 2 * .pi)
            + 0.1 * sin(swayB * 2 * .pi)
            + 0.06 * sin(swayC * 2 * .pi)

        // 목표까지 약 0.4초에 걸쳐 미끄러진다. 예전 계수는 1초가 넘어 승부가 끝난 뒤에야
        // 관중이 커지는 일이 있었다.
        let glide = 1 - exp(-Double(frameCount) / (0.4 * sampleRate))
        current += (goal - current) * glide

        guard current > 0.001 else { return }

        // 밀도가 높을수록 목소리 대역이 살아난다. 조용할 때는 먼 웅성거림만 남는다.
        let bodyGain = 0.13 * current
        let voiceGain = 0.1 * current * current
        let bodyF = 2 * sin(.pi * 260 / sampleRate)
        let voiceF = 2 * sin(.pi * 1_050 / sampleRate)

        let channelCount = min(buffers.count, channels.count)
        for channel in 0..<channelCount {
            var state = channels[channel]
            let pointer = buffers[channel].mData!.assumingMemoryBound(to: Float.self)
            for frame in 0..<frameCount {
                let white = state.noise.next()
                let body = state.body.process(white, f: bodyF, q: 0.9)
                let voice = state.voice.process(white, f: voiceF, q: 1.25)
                let value = (body * bodyGain + voice * voiceGain) * sway
                pointer[frame] = Float(softClip(value))
            }
            channels[channel] = state
        }
        // 모노 출력이면 왼쪽 신호를 그대로 쓴다.
        if buffers.count > channelCount, channelCount > 0 {
            let source = buffers[0].mData!.assumingMemoryBound(to: Float.self)
            for extra in channelCount..<buffers.count {
                let pointer = buffers[extra].mData!.assumingMemoryBound(to: Float.self)
                for frame in 0..<frameCount { pointer[frame] = source[frame] }
            }
        }
    }
}

/// 메뉴와 커리어 화면 아래 조용히 깔리는 음악.
///
/// 작곡된 트랙이 아니라 **밤 구장의 무드 패드**다. 느린 화음 세 개가 18초씩 머물다
/// 서로에게 건너가고, 숨 쉬듯 커졌다 작아진다. 목표는 "음악이 나온다"가 아니라
/// "조용하지 않다"이다 — 유료 게임의 첫 30초가 무음이면 미완성으로 읽힌다.
///
/// `menu-theme` 음원이 번들에 있으면 이 렌더러 대신 그 파일이 돈다(두 벌 구조).
final class PadBed: AudioRenderer, @unchecked Sendable {
    private let lock = NSLock()
    private var target: Double = 0
    private var current: Double = 0

    /// 밤 구장의 화음 셋. 라단조 어귀를 돈다 — 어둡지만 가라앉지는 않는 자리다.
    /// 전화기 스피커는 200Hz 아래가 거의 안 나오므로 중음역에 둔다.
    private static let chords: [[Double]] = [
        [293.66, 349.23, 440.00, 659.26],   // 레 단조 add9
        [233.08, 293.66, 349.23, 440.00],   // 시플랫 장7
        [220.00, 261.63, 329.63, 440.00],   // 라 단조
        [233.08, 293.66, 349.23, 523.25],   // 시플랫 장조, 꼭대기만 도로
    ]
    /// 화음 하나가 머무는 시간(초). 마지막 22%에서 다음 화음으로 건너간다.
    private static let segmentSeconds = 18.0
    private static let sampleRate = 44_100.0

    /// 두 뱅크 × 화음 4성.
    ///
    /// 처음에는 성부마다 디튠 짝(+0.15%)을 겹쳤는데, 같은 크기의 두 진동이 2초마다
    /// 완전히 상쇄돼 **맥놀이로 출렁였다** — 클릭 검사가 그걸 잡아냈다. 대신 성부마다
    /// 아주 느린 비브라토(±0.08%, 성부별로 다른 주기)를 준다. 폭은 생기고 맥놀이는 없다.
    private var phasesA = [Double](repeating: 0, count: 4)
    private var phasesB = [Double](repeating: 0, count: 4)
    private var vibratoPhases: [Double] = [0.0, 0.31, 0.62, 0.87]
    private static let vibratoRates: [Double] = [0.11, 0.073, 0.127, 0.091]
    private var lastIndex = -1
    private var clock = 0
    /// 숨. 서로 나누어떨어지지 않는 두 주기.
    private var breathA = 0.0
    private var breathB = 0.53

    func setTarget(intensity: Double) {
        lock.lock()
        target = min(1, max(0, intensity))
        lock.unlock()
    }

    func render(frameCount: Int, into buffers: UnsafeMutableAudioBufferListPointer) {
        for buffer in buffers {
            memset(buffer.mData, 0, Int(buffer.mDataByteSize))
        }
        lock.lock()
        let goal = target
        lock.unlock()

        // 목표까지 약 1.2초. 화면 전환마다 음악이 홱 커지면 안 된다.
        let glide = 1 - exp(-Double(frameCount) / (1.2 * Self.sampleRate))
        current += (goal - current) * glide
        guard current > 0.001 else {
            clock += frameCount
            return
        }

        let segment = Int(Self.segmentSeconds * Self.sampleRate)
        let count = Self.chords.count
        let position = Double(clock % (segment * count)) / Double(segment)
        let index = Int(position) % count
        let next = (index + 1) % count
        let fraction = position - floor(position)
        // 마지막 22%에서 다음 화음으로. smoothstep이라 귀에 모서리가 없다.
        let raw = max(0, (fraction - 0.78) / 0.22)
        let crossfade = raw * raw * (3 - 2 * raw)

        if index != lastIndex {
            // 화음이 넘어간 순간, 방금까지 뱅크 B가 내던 소리를 뱅크 A가 이어받는다.
            // 위상을 그대로 복사하면 같은 파형이 이어져 이음매가 들리지 않는다.
            phasesA = phasesB
            lastIndex = index
        }

        breathA += 0.047 * Double(frameCount) / Self.sampleRate
        breathB += 0.031 * Double(frameCount) / Self.sampleRate
        if breathA > 1 { breathA -= 1 }
        if breathB > 1 { breathB -= 1 }
        let breath = 0.72 + 0.2 * sin(breathA * 2 * .pi) + 0.08 * sin(breathB * 2 * .pi)
        // 음악은 배경이다. 관중 웅성거림보다 뒤에 있어야 한다.
        let gain = current * 0.042 * breath

        let chordA = Self.chords[index]
        let chordB = Self.chords[next]
        let channels = buffers.count
        // 낮은 성부가 조금 크다. 위로 갈수록 물러난다.
        let weights: [Double] = [1.0, 0.8, 0.62, 0.4]

        // 비브라토는 블록마다 한 번 계산한다. 12밀리초 안에서는 귀에 이어져 들린다.
        var vibrato = [Double](repeating: 1, count: 4)
        for voice in 0..<4 {
            vibratoPhases[voice] += Self.vibratoRates[voice] * Double(frameCount) / Self.sampleRate
            if vibratoPhases[voice] > 1 { vibratoPhases[voice] -= 1 }
            vibrato[voice] = 1 + 0.0008 * sin(vibratoPhases[voice] * 2 * .pi)
        }

        for frame in 0..<frameCount {
            var left = 0.0
            var right = 0.0
            for voice in 0..<4 {
                let weight = weights[voice]
                phasesA[voice] += chordA[voice] * vibrato[voice] / Self.sampleRate
                if phasesA[voice] > 1 { phasesA[voice] -= 1 }
                let sampleA = sin(phasesA[voice] * 2 * .pi)
                phasesB[voice] += chordB[voice] * vibrato[voice] / Self.sampleRate
                if phasesB[voice] > 1 { phasesB[voice] -= 1 }
                let sampleB = sin(phasesB[voice] * 2 * .pi)
                let mixed = (sampleA * (1 - crossfade) + sampleB * crossfade) * weight
                // 성부를 좌우로 살짝 벌린다. 가운데 뭉치면 좁게 들린다.
                if voice % 2 == 0 {
                    left += mixed * 0.62; right += mixed * 0.38
                } else {
                    left += mixed * 0.38; right += mixed * 0.62
                }
            }
            let l = Float(left * gain)
            let r = Float(right * gain)
            if channels >= 2 {
                buffers[0].mData!.assumingMemoryBound(to: Float.self)[frame] += l
                buffers[1].mData!.assumingMemoryBound(to: Float.self)[frame] += r
            } else {
                for buffer in buffers {
                    buffer.mData!.assumingMemoryBound(to: Float.self)[frame] += Float((left + right) * 0.5 * gain)
                }
            }
        }
        clock += frameCount
    }
}
