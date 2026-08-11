import SwiftUI
import UIKit

/// 이 파일은 iOS 앱의 **유일한** 색 원본이다. 다른 Swift 파일에서 hex 리터럴이나
/// `Color(red:green:blue:)`를 쓰면 `npm run check:design-system`이 실패한다.
///
/// **다크 전용이다.** `apps/windows/src/design-system.css`의 첫 줄이 `color-scheme: dark`이고
/// 라이트 팔레트는 존재하지 않는다. DOC-19의 "Midnight Dugout"은 야간 경기 직전의 더그아웃이
/// 기준 장면이라, 라이트 모드로 렌더하면 그 방향 자체가 사라진다. 값은 전부 데스크톱
/// `:root` 블록에서 그대로 가져왔고, 고대비 모드만 별도 값을 갖는다.
enum BaseballTheme {
    static let canvas = fixed(0x080D0B, highContrast: 0x020503)
    static let surface = fixed(0x101815, highContrast: 0x070B09)
    static let surfaceRaised = fixed(0x17231E, highContrast: 0x0B120E)
    static let surfaceSoft = fixed(0x1E2B25, highContrast: 0x111A15)
    static let border = fixed(0x3F554B, highContrast: 0xC1CEC7)
    static let borderStrong = fixed(0x5F736A, highContrast: 0xE2E8E4)
    static let textPrimary = fixed(0xF1F4EE, highContrast: 0xFFFFFF)
    static let textSecondary = fixed(0xB4C1BB, highContrast: 0xE2E8E4)
    static let textTertiary = fixed(0x84968E, highContrast: 0xC8D2CC)

    /// 브랜드 라임. 전광판과 행동을 나타낸다. 아껴 쓰지 말 것 — 이 색이 정체성이다.
    static let action = fixed(0xB7F36B, highContrast: 0xD3FF82)
    static let actionStrong = fixed(0x96DC4E, highContrast: 0xB7F36B)
    static let actionSoft = fixed(0x243A20, highContrast: 0x16240F)
    /// 라임 위에 얹는 글자색. 라임 버튼에 흰 글자를 쓰면 대비가 무너진다.
    static let actionInk = fixed(0x10200D, highContrast: 0x000000)

    static let selection = fixed(0x86C96A, highContrast: 0xB9ED8D)
    static let selectionSoft = fixed(0x1B2F20, highContrast: 0x0E1C11)
    static let milestone = fixed(0xD8B565, highContrast: 0xFFE08A)
    static let milestoneSoft = fixed(0x211D14, highContrast: 0x14110A)
    static let positive = fixed(0x55C58A, highContrast: 0x78E6AB)
    static let positiveSoft = fixed(0x14271D, highContrast: 0x0A1710)
    static let warning = fixed(0xF0A94A, highContrast: 0xFFC66D)
    static let warningSoft = fixed(0x251D12, highContrast: 0x17110A)
    static let negative = fixed(0xEF746A, highContrast: 0xFF9A91)
    static let negativeSoft = fixed(0x261816, highContrast: 0x180D0C)
    static let information = fixed(0x67B6C1, highContrast: 0x8ED9E2)
    static let informationSoft = fixed(0x163036, highContrast: 0x0B1E22)

    /// 구장·리플레이 전용. 상태 의미를 갖지 않는다.
    static let fieldNight = fixed(0x050A15, highContrast: 0x000000)
    static let fieldDirt = fixed(0x6B5236, highContrast: 0xC7A87E)
    static let fieldChalk = fixed(0xDCE5DE, highContrast: 0xFFFFFF)

    static let teamBlue = fixed(0x5D8FD7, highContrast: 0x8FBAFF)
    static let teamNavy = fixed(0x7189A2, highContrast: 0xA8BDD2)
    static let teamGold = fixed(0xD3A64C, highContrast: 0xFFD36D)
    static let teamRed = fixed(0xD76C68, highContrast: 0xFF9691)
    static let teamTeal = fixed(0x52AA9E, highContrast: 0x7EE0D0)
    static let teamOrange = fixed(0xD8894E, highContrast: 0xFFB477)
    static let teamViolet = fixed(0x9A82D2, highContrast: 0xC4A9FF)
    static let teamSilver = fixed(0xAAB5B0, highContrast: 0xD7E0DC)

    static func teamDecoration(_ id: String) -> Color {
        switch id {
        case "busan_marines": teamGold
        case "daegu_forge", "jeonju_hanok": teamTeal
        case "daejeon_rockets": teamOrange
        case "gwangju_phoenix": teamRed
        case "suwon_guardians": teamNavy
        case "changwon_meteors": teamViolet
        case "jeju_storm": teamSilver
        default: teamBlue
        }
    }

    /// 초상 전용 팔레트. 데스크톱 `design-system.css`의 `--avatar-*`와 같은 값이다.
    ///
    /// 의미색이 아니라 **그림 재료**다. 상태를 나타내지 않으므로 고대비 모드에서도 바꾸지
    /// 않는다 — 피부색을 대비 규칙으로 밀면 사람이 사람으로 안 보인다. 대신 초상은 언제나
    /// 글자와 함께 나오고, 글자 쪽이 대비를 책임진다.
    enum Avatar {
        static let skin: [Color] = [
            plain(0xF2CFA5), plain(0xE8BD8F), plain(0xD9A878), plain(0xC98E5F), plain(0xB97A4E),
        ]
        static let hair: [Color] = [plain(0x20242B), plain(0x3A2D22), plain(0x54402C)]
        static let hairGray = plain(0x6D6F76)
        static let jersey: [Color] = [
            plain(0x3D5A44), plain(0x2F4858), plain(0x5A4632), plain(0x44415A), plain(0x5C3A3A),
        ]
        static let cap = plain(0x274232)
        static let capBrim = plain(0x1C3125)
        static let helmet = plain(0x32405C)
        static let mask = plain(0x8B93A1)
        static let line = plain(0x1A1D22)
        static let highlight = plain(0xFFFFFF)
    }

    private static func plain(_ hex: UInt32) -> Color { Color(uiColor: platformColor(hex)) }

    /// 명암 모드와 무관하게 같은 색. 고대비 설정만 반영한다.
    private static func fixed(_ value: UInt32, highContrast: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            platformColor(traits.accessibilityContrast == .high ? highContrast : value)
        })
    }

    private static func platformColor(_ hex: UInt32) -> UIColor {
        UIColor(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

/// 타이포 역할. 데스크톱의 `--font-family-scoreboard` + `tabular-nums slashed-zero` 계약을
/// iOS 쪽에서 대응시킨다. 숫자는 이 게임의 주인공이라 별도 취급한다.
enum BaseballType {
    /// 카드 위의 작은 분류 라벨. 대문자·자간으로 중계 그래픽의 결을 만든다.
    static let eyebrow = Font.caption2.weight(.bold)
    static let sectionTitle = Font.headline
    /// 화면의 주제목.
    static let display = Font.system(.largeTitle, design: .default, weight: .heavy)
    /// 스탯 타일의 큰 숫자. 이 숫자가 곧 디자인이다.
    static let heroNumeral = Font.system(.largeTitle, design: .monospaced, weight: .bold)
    static let statNumeral = Font.system(.title, design: .monospaced, weight: .bold)
    /// 스코어보드 줄의 숫자.
    static let scoreboard = Font.system(.subheadline, design: .monospaced, weight: .bold)
    static let scoreboardLabel = Font.system(.caption2, design: .monospaced, weight: .semibold)
    /// 삼진 현수막의 K. 고정 포인트 크기를 쓰지 않고 Dynamic Type을 따른다.
    static let strikeoutMark = Font.system(.subheadline, design: .rounded, weight: .black)
}

extension View {
    /// 대문자·자간을 붙인 눈썹 라벨. 중계 그래픽의 첫인상을 만든다.
    func eyebrowStyle(_ color: Color = BaseballTheme.action) -> some View {
        font(BaseballType.eyebrow)
            .textCase(.uppercase)
            .tracking(1.4)
            .foregroundStyle(color)
    }
}

/// 여백·모서리 반경의 단일 눈금.
enum BaseballMetrics {
    static let gutter: CGFloat = 16
    static let stackSpacing: CGFloat = 14
    static let tightSpacing: CGFloat = 8
    static let cardRadius: CGFloat = 14
    static let controlRadius: CGFloat = 10
    /// HIG 최소 조작 영역.
    static let minimumTapTarget: CGFloat = 44
    /// 화면당 하나뿐인 큰 키아트의 높이.
    static let keyArtHeight: CGFloat = 190
    /// 떠 있는 탭 바 아래로 스크롤 콘텐츠가 숨지 않게 비워 두는 높이.
    ///
    /// iOS 26의 탭 바는 화면 위에 떠 있고, 이 앱은 국면에 따라 탭 바를 숨겼다 보였다 하므로
    /// (`AppShell.hidesHighSchoolTabBar`) 스크롤뷰가 자동 하단 인셋을 항상 받지는 못한다.
    /// 실제로 드래프트를 통과한 완료 화면에서 마지막 버튼("N번째 선수로 다시 시작")과
    /// 선수의 속마음이 탭 바 뒤에 깔려 **스크롤 끝까지 내려도 닿을 수 없었다.**
    /// 탭 바 높이(49) + 떠 있는 여백 + 손가락이 닿을 여유를 합친 값이다.
    static let floatingTabBarClearance: CGFloat = 96
}

enum BaseballCardTone {
    case standard, raised, milestone, positive, warning, negative

    /// 의미색이 붙은 톤만 면을 갖는다. 중립 정보는 타이포와 괘선으로만 선다(A안).
    var carriesSurface: Bool {
        switch self {
        case .standard, .raised: false
        case .milestone, .positive, .warning, .negative: true
        }
    }

    var accent: Color {
        switch self {
        case .standard: BaseballTheme.textSecondary
        case .raised: BaseballTheme.information
        case .milestone: BaseballTheme.milestone
        case .positive: BaseballTheme.positive
        case .warning: BaseballTheme.warning
        case .negative: BaseballTheme.negative
        }
    }

    /// 다크 팔레트에서는 흰 카드를 쌓는 대신 어두운 면에 의미색 soft를 깐다.
    var background: Color {
        switch self {
        case .standard: BaseballTheme.surface
        case .raised: BaseballTheme.surfaceRaised
        case .milestone: BaseballTheme.milestoneSoft
        case .positive: BaseballTheme.positiveSoft
        case .warning: BaseballTheme.warningSoft
        case .negative: BaseballTheme.negativeSoft
        }
    }
}

/// 화면의 정보 한 덩어리.
///
/// **A안 — 눈썹 + 헤어라인.** 중립 정보는 상자를 갖지 않는다. 라벨은 대문자·자간을 준 눈썹으로
/// 바깥에 두고, 내용은 캔버스 위에 직접 놓이며, 구분은 1px 괘선 하나로만 한다. 데스크톱
/// GameCast 사이드바가 쓰는 언어다.
///
/// 의미색(milestone·positive·warning·negative)이 붙은 것만 면을 갖는다. 상태가 바뀐 순간
/// —기회, 경고, 성장, 결과— 은 화면에 드물게 나타나므로, 이 규칙만으로 "강조는 화면당 한 곳"이
/// 저절로 지켜진다. 좌측 강조 레일은 쓰지 않는다: 데스크톱 원본도 GameCast의 존 판정 한 곳에만
/// 쓰는 장치이고, 모든 카드가 반복하면 신호가 아니라 배경이 된다.
struct BaseballCard<Content: View>: View {
    let title: String
    var tone: BaseballCardTone = .standard
    let content: Content

    init(title: String, tone: BaseballCardTone = .standard, @ViewBuilder content: () -> Content) {
        self.title = title
        self.tone = tone
        self.content = content()
    }

    var body: some View {
        if tone.carriesSurface {
            callout
        } else {
            section
        }
    }

    /// 중립 정보. 상자 없이 눈썹과 괘선만.
    private var section: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).eyebrowStyle(tone == .raised ? BaseballTheme.information : BaseballTheme.textTertiary)
            content
            Rectangle()
                .fill(BaseballTheme.border.opacity(0.45))
                .frame(height: 1)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 상태가 바뀐 순간. 테두리도 레일도 없이 의미색 면으로만 구분한다.
    private var callout: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).eyebrowStyle(tone.accent)
            content
        }
        .padding(BaseballMetrics.gutter)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tone.background, in: RoundedRectangle(cornerRadius: BaseballMetrics.cardRadius))
    }
}

/// 큰 숫자가 주인공인 타일. 데스크톱 훈련 결과 화면(`35 → 35`, `8 → 19`)의 대응물이다.
/// A안이라 상자를 두르지 않는다 — 눈썹과 숫자만으로 선다.
struct StatTile: View {
    let label: String
    let value: String
    /// 지정하면 `이전 → 현재`로 보여 준다.
    var previousValue: String?
    var caption: String?
    var tone: Color = BaseballTheme.textPrimary

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).eyebrowStyle(BaseballTheme.textTertiary)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                if let previousValue {
                    Text(previousValue)
                        .font(BaseballType.statNumeral)
                        .foregroundStyle(BaseballTheme.textTertiary)
                    Image(systemName: "arrow.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(BaseballTheme.textTertiary)
                }
                Text(value)
                    .font(previousValue == nil ? BaseballType.heroNumeral : BaseballType.statNumeral)
                    .foregroundStyle(tone)
                    .monospacedDigit()
            }
            .minimumScaleFactor(0.6)
            .lineLimit(1)
            if let caption {
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(BaseballTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            previousValue.map { "\(label) \($0)에서 \(value)" } ?? "\(label) \(value)"
                + (caption.map { ". \($0)" } ?? "")
        )
    }
}

/// 화면 하나에 하나뿐인 주 행동. 라임 알약에 어두운 잉크 — 데스크톱 CTA와 같은 계약이다.
struct PrimaryPill: View {
    let title: String
    var identifier: String?
    var enabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundStyle(BaseballTheme.actionInk)
                .frame(maxWidth: .infinity, minHeight: 52)
        }
        .background(
            enabled ? BaseballTheme.action : BaseballTheme.actionSoft,
            in: Capsule()
        )
        .opacity(enabled ? 1 : 0.6)
        .disabled(!enabled)
        .accessibilityIdentifier(identifier ?? title)
    }
}

struct ScoreboardValue: View {
    let value: String
    var body: some View {
        Text(value).font(BaseballType.statNumeral).foregroundStyle(BaseballTheme.textPrimary).monospacedDigit()
    }
}

/// DOC-19 §4: 화면당 큰 키아트는 하나. 고대비 모드에서는 이미지를 없애고 단색으로 돌아간다.
/// 한국어 조사·금액 표기. 받침을 안 보고 "서울덕성고으로"라고 쓰면
/// 그 순간 "기계가 쓴 글"이 된다 — 하필 가장 집중해서 읽는 화면들에서.
enum KoreanCopy {
    /// 받침 유무로 조사를 고른다. "\(name)\(KoreanCopy.ro(name))" → 서울덕성고로.
    static func particle(_ word: String, final withFinal: String, open withoutFinal: String) -> String {
        guard let scalar = lastHangulScalar(word) else { return withoutFinal }
        let jong = (Int(scalar.value) - 0xAC00) % 28
        return jong == 0 ? withoutFinal : withFinal
    }

    /// 으로/로 — ㄹ 받침은 예외로 '로'를 쓴다(서울로).
    static func ro(_ word: String) -> String {
        guard let scalar = lastHangulScalar(word) else { return "로" }
        let jong = (Int(scalar.value) - 0xAC00) % 28
        return (jong == 0 || jong == 8) ? "로" : "으로"
    }

    /// 숫자 뒤 조사 — 마지막 자릿수의 한글 읽기로 판별한다(22 → 이 → 를).
    static func objectParticle(number: Int) -> String {
        let last = abs(number) % 10
        return [0, 1, 3, 6, 7, 8].contains(last) ? "을" : "를"
    }

    /// 원화 표기 — "12,000만 원"이 아니라 "1억 2,000만 원"이라고 쓴다.
    static func money(won: Int) -> String {
        let man = won / 10_000
        let eok = man / 10_000
        let rest = man % 10_000
        if eok > 0 {
            return rest > 0 ? "\(eok)억 \(formatted(rest))만 원" : "\(eok)억 원"
        }
        return "\(formatted(man))만 원"
    }

    private static func formatted(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private static func lastHangulScalar(_ word: String) -> Unicode.Scalar? {
        for scalar in word.unicodeScalars.reversed() {
            if (0xAC00...0xD7A3).contains(scalar.value) { return scalar }
            // 숫자로 끝나면 숫자 읽기의 받침을 따른다.
            if (0x30...0x39).contains(scalar.value) {
                let digit = Int(scalar.value) - 0x30
                let readings: [Unicode.Scalar?] = ["영", "일", "이", "삼", "사", "오", "육", "칠", "팔", "구"].map { $0.unicodeScalars.first }
                return readings[digit]
            }
        }
        return nil
    }
}

enum KeyArt: String {
    case proStadiumTunnel = "KeyArtProStadiumTunnel"
    case stadiumNight = "KeyArtStadiumNight"
    case careerIntro = "KeyArtCareerIntro"
    /// 되돌릴 수 없는 갈림길에 서는 순간들. 화면당 하나만 쓴다 — 그림이 흔하면 아무 데도
    /// 무게가 실리지 않는다(DOC-19 §7.5).
    case schoolCrossroads = "KeyArtSchoolCrossroads"
    case draftDay = "KeyArtDraftDay"
    case majorDebut = "KeyArtMajorDebut"
    case retirement = "KeyArtRetirement"
    case reincarnation = "KeyArtReincarnation"
    case awakening = "KeyArtAwakening"
}

struct KeyArtHeader: View {
    let art: KeyArt
    let eyebrow: String
    let title: String
    var accent: Color = BaseballTheme.action
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if contrast == .standard {
                Image(art.rawValue)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: BaseballMetrics.keyArtHeight)
                    .clipped()
                    .overlay {
                        // 캔버스와 같은 색으로 아래를 덮어 이미지가 화면에 녹아들게 한다.
                        // 밝은 카드 위에 사진을 얹으면 배너처럼 떠 보인다.
                        LinearGradient(
                            colors: [
                                BaseballTheme.canvas.opacity(0.1),
                                BaseballTheme.canvas.opacity(0.72),
                                BaseballTheme.canvas
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
            } else {
                Rectangle()
                    .fill(BaseballTheme.surfaceRaised)
                    .frame(height: BaseballMetrics.keyArtHeight)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(eyebrow).eyebrowStyle(accent)
                Text(title)
                    .font(BaseballType.display)
                    .foregroundStyle(BaseballTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 2)
            .padding(.bottom, 2)
        }
        .frame(height: BaseballMetrics.keyArtHeight)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

/// 기억 카드·장면의 작은 그림. 번들에 파일이 없으면 아무것도 그리지 않는다 —
/// 아트가 아직 없는 카드가 레이아웃을 깨뜨리지 않게 하는 안전판이다.
struct ArtThumb: View {
    let assetName: String
    var size: CGFloat = 56
    var cornerRadius: CGFloat = 10

    var body: some View {
        if UIImage(named: assetName) != nil {
            Image(assetName)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .strokeBorder(BaseballTheme.border.opacity(0.5), lineWidth: 1)
                )
        }
    }
}
