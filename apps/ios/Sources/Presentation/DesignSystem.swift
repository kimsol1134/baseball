import SwiftUI
import UIKit
import BaseballIOSDomain

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

    // MARK: 읽는 글의 역할 (1.2.9 가독성 교정)
    //
    // 스토어 리뷰가 말한 "글씨가 많아 안 읽힌다"의 실체는 긴 문장이 아니라, 12~15pt 글이
    // 행간 보정 없이 여러 층으로 쌓인 것이었다(폰트 호출의 90%가 caption·footnote·subheadline).
    // 규칙은 셋이다. **사용자가 읽어야 하는 문장은 `prose` 아래로 내려가지 않는다.**
    // `detail`은 효과·비용 같은 보조 한 줄의 하한이다. `annotation`은 라벨·단위·타임스탬프에만 쓴다.

    /// 서사·설명 본문. HIG Body(17pt). 한글 권장 행간 150~160%는 `proseStyle()`이 붙인다.
    static let prose = Font.body
    /// 결과 한 줄(요약 리드). 훑는 독자가 이 줄만 봐도 상태를 알아야 한다.
    static let proseLead = Font.body.weight(.semibold)
    /// 효과·비용·보조 설명의 하한. HIG Subheadline(15pt).
    static let detail = Font.subheadline
    /// 눈썹·단위·타임스탬프처럼 읽지 않고 훑는 짧은 표기에만. 문장에는 쓰지 않는다.
    static let annotation = Font.caption
}

extension View {
    /// 대문자·자간을 붙인 눈썹 라벨. 중계 그래픽의 첫인상을 만든다.
    func eyebrowStyle(_ color: Color = BaseballTheme.action) -> some View {
        font(BaseballType.eyebrow)
            .textCase(.uppercase)
            .tracking(1.4)
            .foregroundStyle(color)
    }

    /// 읽는 본문. 17pt에 한글 행간(약 155%)과 살짝 좁힌 자간을 붙이고 세로로만 늘어나게 한다.
    /// 시스템 기본 행간(약 130%)은 라틴 기준이라 한글 문단이 빽빽해 보인다.
    func proseStyle(_ color: Color = BaseballTheme.textPrimary) -> some View {
        font(BaseballType.prose)
            .lineSpacing(BaseballMetrics.proseLineSpacing)
            .kerning(-0.2)
            .foregroundStyle(color)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// 결과 한 줄. 카드의 첫 줄이며 굵게 선다.
    func proseLeadStyle(_ color: Color = BaseballTheme.textPrimary) -> some View {
        font(BaseballType.proseLead)
            .lineSpacing(BaseballMetrics.proseLineSpacing)
            .kerning(-0.2)
            .foregroundStyle(color)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// 효과·비용·보조 설명. 15pt에 행간 보정. 문장이 이보다 작아지면 안 된다.
    func detailStyle(_ color: Color = BaseballTheme.textSecondary) -> some View {
        font(BaseballType.detail)
            .lineSpacing(BaseballMetrics.detailLineSpacing)
            .foregroundStyle(color)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// 떠 있는 탭 바 뒤로 마지막 카드·경고가 숨지 않도록 스크롤 콘텐츠 아래를 비운다.
    /// 화면마다 하드코딩된 `Spacer`·`padding(.bottom, 120)`을 이 한 줄로 통일한다.
    func floatingTabBarClearance() -> some View {
        safeAreaPadding(.bottom, BaseballMetrics.floatingTabBarClearance)
    }
}

/// 내비게이션 바를 숨긴 화면에서 스크롤 콘텐츠가 시계·배터리 뒤로 올라올 때 글자가
/// 겹치지 않게 상태 막대 높이만큼 캔버스색을 얹는다. 탭·스크롤은 통과시킨다.
///
/// overlay 안의 GeometryReader는 이미 세이프 에어리어 *안*에 놓여 `safeAreaInsets.top`이
/// 0이 된다. 높이 0 띠는 시계 왼쪽의 글자를 그대로 통과시켜, "왼쪽 화면이 잘려 글씨가
/// 안 보인다"로 읽혔다. 세이프 에어리어를 무시하는 배경으로 상태 막대 자리를 채운다.
struct StatusBarScrim: View {
    var body: some View {
        Color.clear
            .frame(height: 0)
            .frame(maxWidth: .infinity)
            .background(alignment: .top) {
                BaseballTheme.canvas.opacity(0.94)
                    .ignoresSafeArea(edges: .top)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// 이득·비용·위험을 문장 대신 보여 주는 작은 칩. "구위·포심 구속·헛스윙 성장 · 현재 0/4 ·
/// 게이지를 채우면 능력 +1" 같은 네 줄짜리 효과 문장을 칩 셋으로 바꾸기 위한 부품이다.
/// 색은 의미에만 쓴다 — 이득은 positive, 비용·경고는 warning, 중립은 textSecondary.
struct EffectChip: View {
    enum Tone { case gain, cost, neutral, risk }

    let text: String
    var tone: Tone = .neutral
    var systemImage: String?

    var body: some View {
        HStack(spacing: 4) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.caption2.weight(.bold))
                    .accessibilityHidden(true)
            }
            // localization-safe: resolved-copy
            Text(text)
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
        }
        .foregroundStyle(foreground)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(background, in: Capsule())
        .fixedSize(horizontal: true, vertical: false)
    }

    private var foreground: Color {
        switch tone {
        case .gain: BaseballTheme.positive
        case .cost: BaseballTheme.warning
        case .risk: BaseballTheme.negative
        case .neutral: BaseballTheme.textSecondary
        }
    }

    private var background: Color {
        switch tone {
        case .gain: BaseballTheme.positiveSoft
        case .cost: BaseballTheme.warningSoft
        case .risk: BaseballTheme.negativeSoft
        case .neutral: BaseballTheme.surfaceRaised
        }
    }
}

/// 칩을 줄바꿈하며 흘리는 컨테이너. 칩 3~5개가 한 줄에 안 들어가면 다음 줄로 내린다.
struct EffectChipFlow<Content: View>: View {
    var spacing: CGFloat = 6
    @ViewBuilder let content: Content

    var body: some View {
        FlowLayout(spacing: spacing) { content }
    }
}

/// 가장 단순한 흐름 레이아웃. 칩·태그처럼 폭이 제각각인 작은 요소를 왼쪽 정렬로 흘린다.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, maxX: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            maxX = max(maxX, x - spacing)
        }
        return CGSize(width: width == .infinity ? maxX : width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
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
    /// 훈련 루프처럼 같은 그림이 반복될 때의 낮은 키아트.
    static let keyArtHeightCompact: CGFloat = 140
    /// 떠 있는 탭 바 아래로 스크롤 콘텐츠가 숨지 않게 비워 두는 높이.
    ///
    /// iOS 26의 탭 바는 화면 위에 떠 있고, 이 앱은 국면에 따라 탭 바를 숨겼다 보였다 하므로
    /// (`AppShell.hidesHighSchoolTabBar`) 스크롤뷰가 자동 하단 인셋을 항상 받지는 못한다.
    /// 실제로 드래프트를 통과한 완료 화면에서 마지막 버튼("N번째 선수로 다시 시작")과
    /// 선수의 속마음이 탭 바 뒤에 깔려 **스크롤 끝까지 내려도 닿을 수 없었다.**
    /// 탭 바 높이(49) + 떠 있는 여백 + 손가락이 닿을 여유를 합친 값이다.
    static let floatingTabBarClearance: CGFloat = 120
    /// 17pt 본문의 한글 행간 보정. 시스템 기본(약 22pt)에 6을 더해 약 155%가 된다.
    static let proseLineSpacing: CGFloat = 6
    /// 15pt 보조 설명의 행간 보정.
    static let detailLineSpacing: CGFloat = 4
    /// 큰 한글 제목의 윗획이 ScrollView·clip 경계에 먹히지 않게 비우는 높이.
    /// `title.bold()` / `largeTitle.heavy` 한글은 타이포 박스보다 위로 나간다.
    static let titleAscentClearance: CGFloat = 6
    /// 큰 한글 제목 첫째 글자의 왼쪽 획이 clip 경계에 먹히지 않게 비우는 너비.
    static let titleLeadingClearance: CGFloat = 8
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
            // 눈썹 색은 하나다. raised에 청록을 주던 규칙은 화면당 색 의미를 5개로 늘려
            // "링크"와 혼동됐다(1.2.9 가독성 교정). 청록은 용어 사전 링크에만 남긴다.
            Text(verbatim: title).eyebrowStyle(BaseballTheme.textTertiary)
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
            Text(verbatim: title).eyebrowStyle(tone.accent)
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
    var animatesChange = false

    @Environment(\.gameCopyResolver) private var copyResolver
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var displayedValue: String
    @State private var glow = false
    @State private var bump = false

    init(
        label: String,
        value: String,
        previousValue: String? = nil,
        caption: String? = nil,
        tone: Color = BaseballTheme.textPrimary,
        animatesChange: Bool = false
    ) {
        self.label = label
        self.value = value
        self.previousValue = previousValue
        self.caption = caption
        self.tone = tone
        self.animatesChange = animatesChange
        _displayedValue = State(initialValue: animatesChange ? (previousValue ?? value) : value)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // localization-safe: resolved-copy
            Text(label).eyebrowStyle(BaseballTheme.textTertiary)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                if let previousValue {
                    // localization-safe: numeric
                    Text(previousValue)
                        .font(BaseballType.statNumeral)
                        .foregroundStyle(BaseballTheme.textTertiary)
                    Image(systemName: "arrow.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(BaseballTheme.textTertiary)
                }
                // localization-safe: numeric
                Text(displayedValue)
                    .font(previousValue == nil ? BaseballType.heroNumeral : BaseballType.statNumeral)
                    .foregroundStyle(tone)
                    .monospacedDigit()
            }
            .minimumScaleFactor(0.6)
            .lineLimit(1)
            if let caption {
                // localization-safe: resolved-copy
                Text(caption)
                    .detailStyle()
            }
        }
        .padding(glow ? 6 : 0)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(glow ? BaseballTheme.positiveSoft : Color.clear, in: RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityCopy)
        .sensoryFeedback(.impact(weight: .medium), trigger: bump)
        .onAppear { runChangeAnimationIfNeeded() }
    }

    private func runChangeAnimationIfNeeded() {
        guard animatesChange, let previousValue, previousValue != value else {
            displayedValue = value
            return
        }
        if reduceMotion {
            displayedValue = value
            return
        }
        displayedValue = previousValue
        let start = Int(previousValue) ?? 0
        let end = Int(value) ?? start
        let steps = max(1, abs(end - start))
        let stepDuration = 0.4 / Double(steps)
        for step in 1...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + stepDuration * Double(step)) {
                let next = start + (end - start) * step / steps
                displayedValue = "\(next)"
                if next == end {
                    bump = true
                    withAnimation(.easeOut(duration: 0.3)) { glow = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        withAnimation(.easeOut(duration: 0.2)) { glow = false }
                    }
                }
            }
        }
    }

    private var accessibilityCopy: String {
        switch (previousValue, caption) {
        case let (previous?, caption?):
            copyResolver.resolve(
                .statTileChangedCaptionAccessibility,
                arguments: [.userText(label), .userText(previous), .userText(value), .userText(caption)]
            )
        case let (previous?, nil):
            copyResolver.resolve(
                .statTileChangedAccessibility,
                arguments: [.userText(label), .userText(previous), .userText(value)]
            )
        case let (nil, caption?):
            copyResolver.resolve(
                .statTileCurrentCaptionAccessibility,
                arguments: [.userText(label), .userText(value), .userText(caption)]
            )
        case (nil, nil):
            copyResolver.resolve(
                .statTileCurrentAccessibility,
                arguments: [.userText(label), .userText(value)]
            )
        }
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
            Text(verbatim: title)
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
        // localization-safe: numeric
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
        let safe = max(0, won)
        if safe < 10_000 {
            return "\(formatted(safe))원"
        }
        let man = safe / 10_000
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
    var height: CGFloat = BaseballMetrics.keyArtHeight
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        // 글이 크기를 정하고 그림은 그 뒤를 채운다. 그림을 ZStack의 형제로 두면 스크롤뷰 안에서
        // 무한 높이를 제안받아 화면을 통째로 덮었고(3차 검수), 고정 높이로 두면 긴 제목이
        // 아래 콘텐츠 위로 겹쳤다. 최소 높이 + 배경 그림이 둘 다 푼다.
        ZStack(alignment: .bottomLeading) {
            Color.clear.frame(height: height)
            VStack(alignment: .leading, spacing: 6) {
                // localization-safe: resolved-copy
                Text(eyebrow).eyebrowStyle(accent)
                // localization-safe: resolved-copy
                Text(title)
                    .font(BaseballType.display)
                    .foregroundStyle(BaseballTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            // heavy 한글 첫째 글자의 왼쪽 획이 clip 경계에 먹히지 않게 안쪽으로 들인다.
            .padding(.horizontal, BaseballMetrics.titleLeadingClearance)
            .padding(.top, BaseballMetrics.titleAscentClearance)
            .padding(.bottom, 2)
        }
        .frame(maxWidth: .infinity)
        .background {
            if contrast == .standard {
                GeometryReader { proxy in
                    Image(art.rawValue)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                        .accessibilityHidden(true)
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
                }
                .allowsHitTesting(false)
            } else {
                Rectangle().fill(BaseballTheme.surfaceRaised)
            }
        }
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
