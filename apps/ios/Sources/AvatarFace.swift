import SwiftUI

/// 이름에서 얼굴을 만든다.
///
/// 이 게임은 3년 동안 같은 감독·포수·라이벌과 지낸다. 그런데 iOS에서 그들은 전부
/// `Text(name)`이었다 — 관계 시스템 전체가 스프레드시트로 읽혔다. 사쿠세스·파워프로·RTTS
/// 등 이 장르의 모든 경쟁작이 얼굴을 갖는다.
///
/// 사진을 쓰지 않는 이유는 두 가지다. 절차 생성 인물에 사진을 붙이면 **같은 사진이 계속
/// 반복되고**, 실존 인물처럼 보이는 이미지는 IP 위생 문제를 만든다. 대신 이름을 시드로
/// 파츠를 조합한다 — 같은 이름은 언제나 같은 얼굴, 다른 이름은 다른 얼굴이다.
///
/// 데스크톱 `AvatarFace.tsx`의 포팅이고 **같은 해시·같은 파츠 표를 쓴다.** 두 플랫폼에서
/// 같은 사람이 다르게 생기면 그건 같은 사람이 아니다.
struct AvatarFace: View {
    enum Role: String {
        case player, coach, catcher, rival
    }

    let seed: String
    var role: Role = .player
    var size: CGFloat = 58

    /// 원본 SVG의 좌표계. 모든 파츠 좌표가 이 안에서 정의된다.
    private static let designWidth: CGFloat = 58
    private static let designHeight: CGFloat = 76

    var body: some View {
        Canvas { context, canvasSize in
            let scale = min(canvasSize.width / Self.designWidth, canvasSize.height / Self.designHeight)
            context.scaleBy(x: scale, y: scale)
            AvatarParts(seed: seed, role: role).draw(in: &context)
        }
        .frame(width: size, height: size * Self.designHeight / Self.designWidth)
        .accessibilityHidden(true)
    }
}

/// 시드에서 파츠를 고르고 그리는 순수 값. 뷰와 분리해 결정론을 테스트할 수 있게 한다.
struct AvatarParts: Hashable {
    let skinIndex: Int
    let hairColorIndex: Int
    let jerseyIndex: Int
    let faceShape: Int
    let eyeStyle: Int
    let browStyle: Int
    let mouthStyle: Int
    let hairStyle: Int
    let cheekMark: Bool
    let agedCoach: Bool
    let showHat: Bool
    let role: AvatarFace.Role

    /// FNV-1a 32비트. 데스크톱의 `hashSeed`와 같은 상수·같은 곱셈 순서를 쓴다.
    static func hash(_ seed: String) -> UInt32 {
        var hash: UInt32 = 0x811c_9dc5
        for byte in Array(seed.utf8) {
            hash ^= UInt32(byte)
            hash = hash &* 0x0100_0193
        }
        return hash
    }

    init(seed: String, role: AvatarFace.Role) {
        let hash = Self.hash("\(role.rawValue):\(seed)")
        func pick(_ shift: UInt32, _ count: Int) -> Int { Int((hash >> shift) % UInt32(count)) }

        self.role = role
        skinIndex = pick(0, 5)
        agedCoach = role == .coach && pick(21, 3) > 0
        hairColorIndex = agedCoach ? 3 : pick(3, 3)
        jerseyIndex = pick(6, 5)
        faceShape = pick(9, 3)
        eyeStyle = pick(11, 3)
        browStyle = pick(13, 3)
        mouthStyle = pick(15, 4)
        hairStyle = pick(17, 5)
        cheekMark = pick(19, 4) == 0
        showHat = role == .player || role == .rival || (role == .coach && pick(20, 2) == 0)
    }

    var faceRadiusX: CGFloat { faceShape == 0 ? 13.5 : faceShape == 1 ? 12.2 : 14.5 }
    var faceRadiusY: CGFloat { faceShape == 1 ? 15.8 : 14.6 }

    private var skin: Color { BaseballTheme.Avatar.skin[skinIndex] }
    private var hairColor: Color {
        hairColorIndex == 3 ? BaseballTheme.Avatar.hairGray : BaseballTheme.Avatar.hair[hairColorIndex]
    }
    private var jersey: Color { BaseballTheme.Avatar.jersey[jerseyIndex] }
    private var line: Color { BaseballTheme.Avatar.line }

    func draw(in context: inout GraphicsContext) {
        let rx = faceRadiusX
        let ry = faceRadiusY

        // 배경 판 — 카드 위에 얹었을 때 인물이 떠 보이게 한다.
        context.fill(
            Path(roundedRect: CGRect(x: 0, y: 0, width: 58, height: 76), cornerRadius: 9),
            with: .color(jersey.opacity(0.28))
        )

        // 어깨·유니폼
        var shoulders = Path()
        shoulders.move(to: CGPoint(x: 9, y: 76))
        shoulders.addQuadCurve(to: CGPoint(x: 29, y: 57), control: CGPoint(x: 9, y: 58))
        shoulders.addQuadCurve(to: CGPoint(x: 49, y: 76), control: CGPoint(x: 49, y: 58))
        shoulders.closeSubpath()
        context.fill(shoulders, with: .color(jersey))

        var collar = Path()
        collar.move(to: CGPoint(x: 25, y: 60))
        collar.addLine(to: CGPoint(x: 29, y: 66))
        collar.addLine(to: CGPoint(x: 33, y: 60))
        collar.addLine(to: CGPoint(x: 33, y: 57))
        collar.addLine(to: CGPoint(x: 25, y: 57))
        collar.closeSubpath()
        context.fill(collar, with: .color(skin.opacity(0.9)))

        // 목
        context.fill(
            Path(roundedRect: CGRect(x: 25.4, y: 49, width: 7.2, height: 9), cornerRadius: 3),
            with: .color(skin)
        )

        // 얼굴과 귀
        context.fill(
            Path(ellipseIn: CGRect(x: 29 - rx, y: 36 - ry, width: rx * 2, height: ry * 2)),
            with: .color(skin)
        )
        for earX in [29 - rx, 29 + rx] {
            context.fill(
                Path(ellipseIn: CGRect(x: earX - 2.4, y: 36.5 - 2.4, width: 4.8, height: 4.8)),
                with: .color(skin)
            )
        }

        if !showHat { drawHair(in: &context, rx: rx, ry: ry) }

        if agedCoach {
            var wrinkle = Path()
            wrinkle.move(to: CGPoint(x: 22, y: 40.5))
            wrinkle.addQuadCurve(to: CGPoint(x: 24.8, y: 40.5), control: CGPoint(x: 23.4, y: 41.6))
            context.stroke(wrinkle, with: .color(line.opacity(0.55)), lineWidth: 0.9)
        }
        if cheekMark {
            context.fill(
                Path(ellipseIn: CGRect(x: 29 + rx - 4.8, y: 39.2, width: 1.6, height: 1.6)),
                with: .color(line.opacity(0.45))
            )
        }

        drawBrows(in: &context)
        drawEyes(in: &context)

        var nose = Path()
        nose.move(to: CGPoint(x: 28.4, y: 36.5))
        nose.addQuadCurve(to: CGPoint(x: 28.6, y: 39.6), control: CGPoint(x: 27.7, y: 38.8))
        context.stroke(nose, with: .color(line.opacity(0.7)), style: StrokeStyle(lineWidth: 1.1, lineCap: .round))

        drawMouth(in: &context)
        drawRoleProp(in: &context, rx: rx, ry: ry)
    }

    // MARK: - 파츠

    private func drawHair(in context: inout GraphicsContext, rx: CGFloat, ry: CGFloat) {
        var path = Path()
        switch hairStyle {
        case 0:
            path.move(to: CGPoint(x: 29 - rx, y: 32))
            path.addQuadCurve(to: CGPoint(x: 29, y: 30 - ry), control: CGPoint(x: 29 - rx, y: 30 - ry))
            path.addQuadCurve(to: CGPoint(x: 29 + rx, y: 32), control: CGPoint(x: 29 + rx, y: 30 - ry))
            path.addLine(to: CGPoint(x: 29 + rx, y: 29))
            path.addQuadCurve(to: CGPoint(x: 29 - rx, y: 29), control: CGPoint(x: 29, y: 24 - ry))
            path.closeSubpath()
        case 1:
            path.move(to: CGPoint(x: 29 - rx - 1, y: 33))
            path.addQuadCurve(to: CGPoint(x: 33, y: 28.5 - ry), control: CGPoint(x: 29 - rx, y: 28 - ry))
            path.addQuadCurve(to: CGPoint(x: 29 + rx + 1, y: 33), control: CGPoint(x: 29 + rx + 1, y: 30 - ry))
            path.addQuadCurve(to: CGPoint(x: 24, y: 31 - ry), control: CGPoint(x: 29 + rx - 4, y: 31 - ry))
            path.addQuadCurve(to: CGPoint(x: 29 - rx - 1, y: 33), control: CGPoint(x: 29 - rx + 1, y: 32 - ry))
            path.closeSubpath()
        case 2:
            for (cx, cy, r) in [(20.0, 24.0, 4.6), (26.0, 21.5, 4.9), (32.5, 21.5, 4.9), (38.0, 24.0, 4.6)] {
                path.addEllipse(in: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))
            }
        case 3:
            path.move(to: CGPoint(x: 29 - rx, y: 30))
            path.addQuadCurve(to: CGPoint(x: 29 + rx, y: 30), control: CGPoint(x: 29, y: 26.5 - ry))
            path.addLine(to: CGPoint(x: 29 + rx, y: 27.5))
            path.addQuadCurve(to: CGPoint(x: 29 - rx, y: 27.5), control: CGPoint(x: 29, y: 23.8 - ry))
            path.closeSubpath()
        default:
            path.move(to: CGPoint(x: 29 - rx - 0.5, y: 34))
            path.addQuadCurve(to: CGPoint(x: 29, y: 26 - ry), control: CGPoint(x: 29 - rx - 0.5, y: 26 - ry))
            path.addQuadCurve(to: CGPoint(x: 29 + rx + 0.5, y: 34), control: CGPoint(x: 29 + rx + 0.5, y: 26 - ry))
            path.addLine(to: CGPoint(x: 29 + rx - 3, y: 30))
            path.addQuadCurve(to: CGPoint(x: 29 - rx + 3, y: 30), control: CGPoint(x: 29, y: 29.5 - ry))
            path.closeSubpath()
        }
        context.fill(path, with: .color(hairColor.opacity(hairStyle == 3 ? 0.85 : 1)))
    }

    private func drawEyes(in context: inout GraphicsContext) {
        switch eyeStyle {
        case 0:
            for x in [23.0, 35.0] {
                context.fill(Path(ellipseIn: CGRect(x: x - 1.7, y: 34 - 1.7, width: 3.4, height: 3.4)), with: .color(line))
            }
        case 1:
            for (x1, x2) in [(21.0, 25.0), (33.0, 37.0)] {
                var path = Path()
                path.move(to: CGPoint(x: x1, y: 34))
                path.addLine(to: CGPoint(x: x2, y: 34))
                context.stroke(path, with: .color(line), style: StrokeStyle(lineWidth: 1.7, lineCap: .round))
            }
        default:
            for x in [23.0, 35.0] {
                context.fill(Path(ellipseIn: CGRect(x: x - 2.1, y: 34 - 2.1, width: 4.2, height: 4.2)), with: .color(line))
                context.fill(
                    Path(ellipseIn: CGRect(x: x + 0.7 - 0.6, y: 33.3 - 0.6, width: 1.2, height: 1.2)),
                    with: .color(BaseballTheme.Avatar.highlight)
                )
            }
        }
    }

    private func drawBrows(in context: inout GraphicsContext) {
        switch browStyle {
        case 0:
            stroke(in: &context, from: (20.5, 29.5), to: (25.5, 29), width: 1.6)
            stroke(in: &context, from: (32.5, 29), to: (37.5, 29.5), width: 1.6)
        case 1:
            stroke(in: &context, from: (20.5, 30), to: (25.5, 28.6), width: 1.9)
            stroke(in: &context, from: (32.5, 28.6), to: (37.5, 30), width: 1.9)
        default:
            var left = Path()
            left.move(to: CGPoint(x: 20.5, y: 29.6))
            left.addQuadCurve(to: CGPoint(x: 25.5, y: 29.4), control: CGPoint(x: 23, y: 28.2))
            var right = Path()
            right.move(to: CGPoint(x: 32.5, y: 29.4))
            right.addQuadCurve(to: CGPoint(x: 37.5, y: 29.6), control: CGPoint(x: 35, y: 28.2))
            for path in [left, right] {
                context.stroke(path, with: .color(line), style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
            }
        }
    }

    private func drawMouth(in context: inout GraphicsContext) {
        switch mouthStyle {
        case 0:
            var path = Path()
            path.move(to: CGPoint(x: 25.5, y: 43.5))
            path.addQuadCurve(to: CGPoint(x: 32.5, y: 43.5), control: CGPoint(x: 29, y: 45.2))
            context.stroke(path, with: .color(line), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
        case 1:
            stroke(in: &context, from: (25.5, 44), to: (32.5, 44), width: 1.6)
        case 2:
            var path = Path()
            path.move(to: CGPoint(x: 25.5, y: 44.5))
            path.addQuadCurve(to: CGPoint(x: 32.5, y: 44.5), control: CGPoint(x: 29, y: 42.8))
            context.stroke(path, with: .color(line), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
        default:
            context.fill(Path(ellipseIn: CGRect(x: 26.4, y: 42.4, width: 5.2, height: 3.2)), with: .color(line))
        }
    }

    private func drawRoleProp(in context: inout GraphicsContext, rx: CGFloat, ry: CGFloat) {
        switch role {
        case .rival:
            var shell = Path()
            shell.move(to: CGPoint(x: 29 - rx - 1.5, y: 30))
            shell.addQuadCurve(to: CGPoint(x: 29 + rx + 1.5, y: 30), control: CGPoint(x: 29, y: 26.5 - ry))
            shell.addLine(to: CGPoint(x: 29 + rx + 1.5, y: 26))
            shell.addQuadCurve(to: CGPoint(x: 29 - rx - 1.5, y: 26), control: CGPoint(x: 29, y: 21.5 - ry))
            shell.closeSubpath()
            context.fill(shell, with: .color(BaseballTheme.Avatar.helmet))
            context.fill(
                Path(ellipseIn: CGRect(x: 29 - rx - 1.6, y: 35.4 - ry - 4.6, width: (rx + 1.6) * 2, height: 9.2)),
                with: .color(BaseballTheme.Avatar.helmet)
            )
            context.fill(
                Path(roundedRect: CGRect(x: 29 + rx - 3, y: 29, width: 7.5, height: 3.4), cornerRadius: 1.7),
                with: .color(BaseballTheme.Avatar.helmet)
            )
        case .catcher:
            context.fill(
                Path(roundedRect: CGRect(x: 29 - rx - 1, y: 22.5, width: rx * 2 + 2, height: 3), cornerRadius: 1.5),
                with: .color(BaseballTheme.Avatar.mask)
            )
            var cage = Path()
            cage.move(to: CGPoint(x: 20, y: 17.5))
            cage.addQuadCurve(to: CGPoint(x: 38, y: 17.5), control: CGPoint(x: 29, y: 12.5))
            cage.addLine(to: CGPoint(x: 38, y: 23))
            cage.addLine(to: CGPoint(x: 20, y: 23))
            cage.closeSubpath()
            context.fill(cage, with: .color(BaseballTheme.Avatar.mask.opacity(0.9)))
            for (x, top) in [(23.0, 15.5), (29.0, 14.0), (35.0, 15.5)] {
                var bar = Path()
                bar.move(to: CGPoint(x: x, y: top))
                bar.addLine(to: CGPoint(x: x, y: 22.5))
                context.stroke(bar, with: .color(line.opacity(0.6)), lineWidth: 0.8)
            }
        case .coach where !showHat:
            var towel = Path()
            towel.move(to: CGPoint(x: 17, y: 57))
            for point in [(23.0, 52.0), (29.0, 58.0), (35.0, 52.0), (41.0, 57.0), (41.0, 62.0), (17.0, 62.0)] {
                towel.addLine(to: CGPoint(x: point.0, y: point.1))
            }
            towel.closeSubpath()
            context.fill(towel, with: .color(jersey.opacity(0.95)))
            context.stroke(towel, with: .color(line), lineWidth: 0.8)
        default:
            break
        }

        guard showHat, role != .rival else { return }
        context.fill(
            Path(ellipseIn: CGRect(x: 29 - rx - 0.9, y: 36.2 - ry - 5.2, width: (rx + 0.9) * 2, height: 10.4)),
            with: .color(BaseballTheme.Avatar.cap)
        )
        var crown = Path()
        crown.move(to: CGPoint(x: 29 - rx - 0.9, y: 36.6 - ry))
        crown.addQuadCurve(to: CGPoint(x: 29 + rx + 0.9, y: 36.6 - ry), control: CGPoint(x: 29, y: 29 - ry))
        crown.addLine(to: CGPoint(x: 29 + rx + 0.9, y: 38.6 - ry))
        crown.addLine(to: CGPoint(x: 29 - rx - 0.9, y: 38.6 - ry))
        crown.closeSubpath()
        context.fill(crown, with: .color(BaseballTheme.Avatar.cap))
        context.fill(
            Path(roundedRect: CGRect(x: 20, y: 37.4 - ry, width: 18, height: 2.6), cornerRadius: 1.3),
            with: .color(BaseballTheme.Avatar.capBrim)
        )
    }

    private func stroke(
        in context: inout GraphicsContext,
        from start: (CGFloat, CGFloat),
        to end: (CGFloat, CGFloat),
        width: CGFloat
    ) {
        var path = Path()
        path.move(to: CGPoint(x: start.0, y: start.1))
        path.addLine(to: CGPoint(x: end.0, y: end.1))
        context.stroke(path, with: .color(line), style: StrokeStyle(lineWidth: width, lineCap: .round))
    }
}

/// 실사 초상이 번들에 있으면 그것을, 없으면 캔버스 아바타를 그린다 — 소리와 같은 두 벌 구조.
///
/// 모든 역할이 시네마틱 초상(키아트와 같은 결)을 쓴다. 주인공은 20장 풀에서
/// 이름 해시로 배정한다 — 같은 이름은 언제나 같은 얼굴이라 회차 카드·아카이브의
/// 정체성이 이어지고, 풀이 넉넉해서 다른 이름이 같은 얼굴을 받는 일이 드물다.
struct PortraitView: View {
    /// 주인공의 성장 단계. 같은 이름(해시)이 같은 계보를 고르고, 단계는
    /// 그 계보 안에서 나이만 바꾼다 — "같은 사람이 자란다"가 규칙이다.
    enum PlayerStage {
        /// 고1 (챕터 1~3) — 앳된 얼굴, 큰 유니폼.
        case freshman
        /// 고2~3 (챕터 4~8) — 기본 20장 풀.
        case ace
        /// 지명 후 프로 — 성인, 프로 유니폼.
        case pro

        var assetPrefix: String {
            switch self {
            case .freshman: return "PortraitPlayerYoung"
            case .ace: return "PortraitPlayer"
            case .pro: return "PortraitPlayerPro"
            }
        }
    }

    let seed: String
    let role: AvatarFace.Role
    var size: CGFloat = 46
    var playerStage: PlayerStage = .ace
    /// 학교 선택처럼 같은 역할이 나란한 화면도 사진을 쓴다. 카탈로그의 네 학교
    /// 인물은 아래 고정표가 변주를 하나씩 배정해 중복이 없고, 그 밖의 시드는
    /// 해시로 고른다. 목록과 1:1 장면이 같은 시드(이름)를 쓰므로 얼굴이 이어진다.
    var usesPhoto = true

    /// 역할별 사진 변주 수. 학교가 넷이라 감독·포수는 4장이 하한이고,
    /// 주인공은 이름이 무한하므로 풀을 넉넉히 둔다.
    private static func variants(for role: AvatarFace.Role) -> Int {
        switch role {
        case .coach, .catcher: return 4
        case .rival: return 3
        case .player: return 20
        }
    }

    /// 카탈로그 인물의 고정 배정. 해시에 맡기면 넷 중 둘이 같은 얼굴을 받는
    /// 충돌이 생길 수 있어서, 나란히 보이는 인물은 표로 못 박는다.
    private static let fixedVariants: [String: Int] = [
        "윤태문": 1, "노재형": 2, "오승렬": 3, "배도환": 4,
        "서준호": 1, "한도윤": 2, "차민석": 3, "문하진": 4,
    ]

    private var assetName: String? {
        guard usesPhoto else { return nil }
        let count = Self.variants(for: role)
        guard count > 0 else { return nil }
        let index = Self.fixedVariants[seed]
            ?? 1 + Int(AvatarParts.hash("portrait:\(seed)") % UInt32(count))
        switch role {
        case .coach: return "PortraitCoach\(index)"
        case .catcher: return "PortraitCatcher\(index)"
        case .rival: return "PortraitRival\(index)"
        case .player: return "\(playerStage.assetPrefix)\(index)"
        }
    }

    /// 단계 사진이 아직 없는 계보는 에이스(기본) 사진으로 대신한다 — 사진이 있는데
    /// 그림 아바타로 떨어지는 것보다, 성장 변화 없이 같은 얼굴이 낫다.
    private var resolvedAssetName: String? {
        guard let name = assetName else { return nil }
        if UIImage(named: name) != nil { return name }
        if role == .player, playerStage != .ace {
            let fallback = "\(PlayerStage.ace.assetPrefix)\(name.drop(while: { !$0.isNumber }))"
            if UIImage(named: fallback) != nil { return fallback }
        }
        return nil
    }

    var body: some View {
        if let name = resolvedAssetName {
            Image(name)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: size, height: size * 76 / 58)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.16))
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.16)
                        .strokeBorder(BaseballTheme.border.opacity(0.5), lineWidth: 1)
                )
        } else {
            AvatarFace(seed: seed, role: role, size: size)
        }
    }
}

/// 얼굴 + 이름 + 역할을 한 덩어리로 읽히게 묶는다. 관계 카드·학교 선택·라이벌 카드가 공유한다.
struct AvatarRow<Trailing: View>: View {
    let seed: String
    let role: AvatarFace.Role
    let name: String
    let caption: String?
    var size: CGFloat = 46
    var usesPhoto = true
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            PortraitView(seed: seed, role: role, size: size, usesPhoto: usesPhoto)
            VStack(alignment: .leading, spacing: 1) {
                Text(verbatim: name).font(.subheadline.weight(.bold))
                if let caption {
                    Text(verbatim: caption).font(.caption).foregroundStyle(BaseballTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
            trailing()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(verbatim: caption.map { "\(name), \($0)" } ?? name))
    }
}

extension AvatarRow where Trailing == EmptyView {
    init(seed: String, role: AvatarFace.Role, name: String, caption: String? = nil, size: CGFloat = 46, usesPhoto: Bool = true) {
        self.init(seed: seed, role: role, name: name, caption: caption, size: size, usesPhoto: usesPhoto) { EmptyView() }
    }
}
