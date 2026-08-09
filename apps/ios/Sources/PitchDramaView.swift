import SwiftUI
import SimulationCore

/// 승부의 5초.
///
/// 이전에는 던진 결과가 궤적 선 하나와 텍스트 카드로 돌아왔다. 입력(와인드업 제스처)만 게임이
/// 됐고 출력은 설문지 응답지였다. 유료 게임에서 스크린샷·클립·기억에 남는 순간은 전부 이
/// 5초에서 나온다.
///
/// **연출 방식: 카메라 두 컷.** 타자 캐릭터를 그리는 대신 카메라를 쓴다.
/// 캔버스 패스로 사람을 그려 봤더니 막대 인간이 되어 추상 화면보다 싸구려로 읽혔다.
/// 사람이 없어도 결과는 보인다 — 공이 어디로 갔고 누가 따라갔는지를 보여 주면 된다.
///
///  1컷 (포수 시점): 공이 커지며 날아온다 → 미트에 꽂히거나 배트에 맞아 섬광이 터진다
///  2컷 (탑다운):    맞은 공만. 타구가 실제 낙하 지점까지 날아가고 수비수가 수렴한다
///
/// **없는 정보를 지어내지 않는다.** 타구 속도·발사각·방향·낙하 거리·체공 시간·담당 수비수는
/// 전부 코어가 준 값이다. 연출은 코어 판정을 보여 줄 뿐 바꾸지 않는다.
struct PitchDramaView: View {
    let execution: PitchExecution
    let outcome: PitchOutcome
    let battedBall: BattedBall?
    let fielding: FieldingResolutionSnapshot?
    /// 결과 판정 뒤에 붙는 수싸움 적중 한 건. 한 공에 최대 하나만 들어온다.
    let sequenceMoment: PitchSequenceMoment?
    /// 재생 진행도 0~1. 밖에서 애니메이션한다.
    var progress: Double

    init(
        execution: PitchExecution,
        outcome: PitchOutcome,
        battedBall: BattedBall?,
        fielding: FieldingResolutionSnapshot?,
        sequenceMoment: PitchSequenceMoment? = nil,
        progress: Double
    ) {
        self.execution = execution
        self.outcome = outcome
        self.battedBall = battedBall
        self.fielding = fielding
        self.sequenceMoment = sequenceMoment
        self.progress = progress
    }

    private static let releasePoint = CGPoint(x: 160, y: 116)
    private static let platePlaneY: Double = 205
    private static let pitchBox = CGRect(x: 46, y: 62, width: 228, height: 246)

    /// 공이 홈플레이트에 닿는 시점. 여기서 판정이 갈린다.
    private static let contact = 0.46
    /// 카메라가 탑다운으로 넘어가는 시점. 맞은 공에서만 쓴다.
    private static let cut = 0.56

    /// 배트에 맞았는가. 임팩트 섬광이 뜨고 미트 포구는 그리지 않는다.
    private var isBatted: Bool {
        switch outcome {
        case .foul, .inPlayOut, .single, .double, .triple, .homeRun: true
        default: false
        }
    }

    /// 페어 지역으로 날아갔는가 — 여기서만 탑다운 필드 카메라로 넘어간다.
    ///
    /// **파울은 제외한다.** 파울은 정의상 페어 지역에 떨어지지 않는데, 예전에는 여기 포함돼
    /// 있어서 방향이 ±48°로 잘린 채 한가운데 40m 낙구처럼 그려졌다. 게다가 파울은 자주 나와서
    /// 매번 카메라가 넘어가면 승부의 호흡이 끊긴다. 파울은 홈플레이트 화면에 남는다.
    private var isFairBall: Bool {
        switch outcome {
        case .inPlayOut, .single, .double, .triple, .homeRun: true
        default: false
        }
    }

    /// 2컷으로 넘어갔는가.
    private var inFieldShot: Bool { isFairBall && progress >= Self.cut }

    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(BaseballTheme.fieldNight))
            if inFieldShot {
                drawFieldShot(context: context, size: size)
            } else {
                drawPitchShot(context: context, size: size)
            }
            drawVerdict(context: context, size: size)
        }
        .overlay(alignment: .bottomLeading) {
            if let sequenceMoment {
                Label(sequenceMoment.headline, systemImage: "brain.head.profile")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(BaseballTheme.information)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(BaseballTheme.canvas.opacity(0.9), in: Capsule())
                    .overlay(Capsule().stroke(BaseballTheme.information, lineWidth: 1))
                    .padding(10)
                    // 숙련 배지는 결과가 나온 뒤 페이드만 한다. 모션 축소에서는
                    // PitchView가 progress를 곧바로 1로 두므로 즉시 완성 상태다.
                    .opacity(sequenceBadgeOpacity)
                    .accessibilityHidden(true)
                    .accessibilityIdentifier("pitch.sequence.badge")
            }
        }
        .accessibilityElement()
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        let speed = String(format: "%.1f", Double(execution.velocityTenthsKPH) / 10)
        var text = "\(PitchCopy.outcome(outcome, battedBall: battedBall)). 시속 \(speed)킬로미터."
        if let fielding, let name = fielding.fielderName {
            let distance = Double(fielding.landingDistanceTenthsMeters ?? 0) / 10
            text += " 타구 \(Int(distance))미터, \(name)."
        }
        if let sequenceMoment {
            // VoiceOver 순서는 판정 → 배합 이유다.
            text += " 수싸움 적중. \(sequenceMoment.headline). \(sequenceMoment.detail)"
        }
        return text
    }

    private var sequenceBadgeOpacity: Double {
        min(1, max(0, (progress - 0.62) / 0.14))
    }

    // MARK: - 1컷 · 포수 시점

    private func drawPitchShot(context: GraphicsContext, size: CGSize) {
        let scale = min(size.width / Self.pitchBox.width, size.height / Self.pitchBox.height)
        let shake = shakeOffset(scale: scale)
        let offset = CGPoint(
            x: (size.width - Self.pitchBox.width * scale) / 2 - Self.pitchBox.minX * scale + shake.x,
            y: (size.height - Self.pitchBox.height * scale) / 2 - Self.pitchBox.minY * scale + shake.y
        )
        func place(_ point: CGPoint) -> CGPoint {
            CGPoint(x: offset.x + point.x * scale, y: offset.y + point.y * scale)
        }

        drawLight(context: context, size: size)
        drawFigures(context: context, place: place, scale: scale)
        drawZone(context: context, place: place, scale: scale)
        drawMitt(context: context, place: place, scale: scale)
        drawIncomingBall(context: context, place: place, scale: scale)
        drawImpact(context: context, place: place, scale: scale)
    }

    /// 타자·포수 실루엣. 존 그리드만 있으면 계측 그래픽이고, 사람의 윤곽이 서는
    /// 순간 야구가 된다(QA P1-8). 디테일은 넣지 않는다 — 무대는 어두운 배경이다.
    private func drawFigures(context: GraphicsContext, place: (CGPoint) -> CGPoint, scale: Double) {
        let zoneTopLeft = place(Self.platePoint(x: -500, y: 500))
        let zoneBottomRight = place(Self.platePoint(x: 500, y: -500))
        let zone = CGRect(x: zoneTopLeft.x, y: zoneTopLeft.y,
                          width: zoneBottomRight.x - zoneTopLeft.x,
                          height: zoneBottomRight.y - zoneTopLeft.y)
        let ink = BaseballTheme.fieldChalk.opacity(0.09)

        // 타자 — 존 왼쪽(우타 기준). 머리·몸통·다리의 큰 덩어리만.
        let batterX = zone.minX - zone.width * 0.34
        let headRadius = zone.width * 0.09
        context.fill(
            Path(ellipseIn: CGRect(x: batterX - headRadius, y: zone.minY - headRadius * 2.6,
                                   width: headRadius * 2, height: headRadius * 2)),
            with: .color(ink)
        )
        var torso = Path()
        torso.move(to: CGPoint(x: batterX - headRadius * 1.2, y: zone.minY - headRadius * 0.4))
        torso.addQuadCurve(to: CGPoint(x: batterX - headRadius * 1.6, y: zone.maxY + headRadius * 1.5),
                           control: CGPoint(x: batterX - headRadius * 2.2, y: zone.midY))
        torso.addLine(to: CGPoint(x: batterX + headRadius * 1.4, y: zone.maxY + headRadius * 1.5))
        torso.addQuadCurve(to: CGPoint(x: batterX + headRadius * 1.1, y: zone.minY - headRadius * 0.4),
                           control: CGPoint(x: batterX + headRadius * 1.8, y: zone.midY))
        torso.closeSubpath()
        context.fill(torso, with: .color(ink))
        // 들어 올린 배트 — 어깨 뒤로 비스듬히.
        var bat = Path()
        bat.move(to: CGPoint(x: batterX + headRadius * 0.8, y: zone.minY - headRadius * 0.6))
        bat.addLine(to: CGPoint(x: batterX + headRadius * 3.2, y: zone.minY - headRadius * 3.4))
        context.stroke(bat, with: .color(ink), style: StrokeStyle(lineWidth: max(2, 3.4 * scale), lineCap: .round))

        // 포수 — 존 아래 웅크린 덩어리.
        let catcherWidth = zone.width * 0.5
        context.fill(
            Path(ellipseIn: CGRect(x: zone.midX - catcherWidth / 2, y: zone.maxY + zone.height * 0.06,
                                   width: catcherWidth, height: zone.height * 0.34)),
            with: .color(ink)
        )
    }

    /// 야간 구장 조명. 부드러운 타원 하나로 무대를 만든다. 각진 삼각형은 오려 붙인 티가 난다.
    private func drawLight(context: GraphicsContext, size: CGSize) {
        let center = CGPoint(x: size.width / 2, y: size.height * 0.16)
        let radius = size.height * 0.9
        context.fill(
            Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius * 0.7, width: radius * 2, height: radius * 1.7)),
            with: .radialGradient(
                Gradient(colors: [BaseballTheme.action.opacity(0.085), .clear]),
                center: center, startRadius: 0, endRadius: radius
            )
        )
    }

    private func drawZone(context: GraphicsContext, place: (CGPoint) -> CGPoint, scale: Double) {
        let topLeft = place(Self.platePoint(x: -500, y: 500))
        let bottomRight = place(Self.platePoint(x: 500, y: -500))
        let rect = CGRect(x: topLeft.x, y: topLeft.y, width: bottomRight.x - topLeft.x, height: bottomRight.y - topLeft.y)

        // 스트라이크 판정이면 존이 라임으로 한 번 밝아진다.
        let flash = (outcome == .calledStrike || outcome == .swingingStrike) ? verdictFlash : 0
        if flash > 0 {
            context.fill(Path(roundedRect: rect, cornerRadius: 3), with: .color(BaseballTheme.action.opacity(flash * 0.18)))
        }
        context.stroke(
            Path(roundedRect: rect, cornerRadius: 3),
            with: .color(BaseballTheme.fieldChalk.opacity(0.5 + flash * 0.5)),
            lineWidth: max(1, (1.3 + flash * 1.8) * scale)
        )

        var grid = Path()
        for step in 1...2 {
            let ratio = Double(step) / 3
            grid.move(to: CGPoint(x: rect.minX + rect.width * ratio, y: rect.minY))
            grid.addLine(to: CGPoint(x: rect.minX + rect.width * ratio, y: rect.maxY))
            grid.move(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * ratio))
            grid.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * ratio))
        }
        context.stroke(grid, with: .color(BaseballTheme.fieldChalk.opacity(0.16)), lineWidth: max(0.5, scale))

        let plateY = rect.maxY + 30 * scale
        let half = rect.width * 0.46
        var plate = Path()
        plate.move(to: CGPoint(x: rect.midX - half, y: plateY))
        plate.addLine(to: CGPoint(x: rect.midX + half, y: plateY))
        plate.addLine(to: CGPoint(x: rect.midX + half * 0.72, y: plateY + 11 * scale))
        plate.addLine(to: CGPoint(x: rect.midX, y: plateY + 19 * scale))
        plate.addLine(to: CGPoint(x: rect.midX - half * 0.72, y: plateY + 11 * scale))
        plate.closeSubpath()
        context.fill(plate, with: .color(BaseballTheme.fieldChalk.opacity(0.42)))
    }

    /// 포수 미트. 공이 오기 전에는 목표 지점에 얇은 링으로만 있다가 포구하면 채운다.
    /// 예전처럼 처음부터 꽉 찬 갈색 원을 두면 공과 헷갈린다.
    private func drawMitt(context: GraphicsContext, place: (CGPoint) -> CGPoint, scale: Double) {
        guard !isBatted else { return }
        let caught = progress >= Self.contact
        let target = place(Self.platePoint(x: Double(execution.actualX), y: Double(execution.actualY)))
        let radius = (caught ? 15.0 : 11.0) * scale
        let rect = CGRect(x: target.x - radius, y: target.y - radius, width: radius * 2, height: radius * 2)
        // 채운 원을 두면 공과 구별이 안 된다. 링으로만 그리고, 포구하면 링이 두꺼워지며 조인다.
        context.stroke(
            Path(ellipseIn: rect),
            with: .color(BaseballTheme.fieldDirt.opacity(caught ? 0.95 : 0.35)),
            style: StrokeStyle(
                lineWidth: max(1, (caught ? 3.4 : 1.4) * scale),
                dash: caught ? [] : [4 * scale, 4 * scale]
            )
        )
    }

    private func drawIncomingBall(context: GraphicsContext, place: (CGPoint) -> CGPoint, scale: Double) {
        let points = replayPoints
        guard points.count >= 2 else { return }
        let flight = min(1, max(0, progress / Self.contact))
        let shown = max(2, Int((Double(points.count) * flight).rounded()))

        var trail = Path()
        trail.move(to: place(points[0]))
        for point in points.prefix(shown).dropFirst() { trail.addLine(to: place(point)) }
        context.stroke(
            trail,
            with: .linearGradient(
                Gradient(colors: [tone.opacity(0.05), tone.opacity(0.8)]),
                startPoint: place(points[0]),
                endPoint: place(points[min(shown - 1, points.count - 1)])
            ),
            style: StrokeStyle(lineWidth: max(1.5, 2.8 * scale), lineCap: .round, lineJoin: .round)
        )

        guard let head = points.prefix(shown).last else { return }
        let center = place(head)
        // 미트에 들어간 뒤에는 공을 줄인다. 흰 원 두 개가 나란히 있으면 어느 쪽이 공인지 흐려진다.
        let caught = !isBatted && progress >= Self.contact
        let radius = (caught ? 3.2 : 2.2 + 5.4 * flight) * scale
        // 다가올수록 공 주변이 살짝 빛난다. 속도감을 만드는 값싼 장치다.
        context.fill(
            Path(ellipseIn: CGRect(x: center.x - radius * 2, y: center.y - radius * 2, width: radius * 4, height: radius * 4)),
            with: .radialGradient(
                Gradient(colors: [BaseballTheme.fieldChalk.opacity(0.22 * flight), .clear]),
                center: center, startRadius: 0, endRadius: radius * 2
            )
        )
        context.fill(
            Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)),
            with: .color(BaseballTheme.fieldChalk)
        )
    }

    /// 배트에 맞은 순간의 섬광. 컨택 품질이 좋을수록 크고 밝다.
    private func drawImpact(context: GraphicsContext, place: (CGPoint) -> CGPoint, scale: Double) {
        guard impactPulse > 0 else { return }
        let target = place(Self.platePoint(x: Double(execution.actualX), y: Double(execution.actualY)))
        let quality = Double(battedBall?.contactQuality ?? 400) / 1_000
        // 파울은 스친 것이라 정타와 같은 크기로 터지면 결과를 잘못 읽는다.
        let burst: Double = if outcome == .foul { 22 } else if isBatted { 30 + 46 * quality } else { 20 }
        let radius = burst * scale * impactPulse
        context.fill(
            Path(ellipseIn: CGRect(x: target.x - radius, y: target.y - radius, width: radius * 2, height: radius * 2)),
            with: .radialGradient(
                Gradient(colors: [
                    BaseballTheme.fieldChalk.opacity(0.9 * impactPulse),
                    tone.opacity(0.4 * impactPulse),
                    .clear,
                ]),
                center: target, startRadius: 0, endRadius: radius
            )
        )
    }

    // MARK: - 2컷 · 탑다운 타구

    /// 맞은 공만 보여 준다. 코어가 준 낙하 거리·방향으로 실제 지점까지 날아가고,
    /// 담당 수비수가 그 지점으로 수렴한다.
    private func drawFieldShot(context: GraphicsContext, size: CGSize) {
        let space = CGSize(width: 320, height: 300)
        let scale = min(size.width / space.width, size.height / space.height)
        let offset = CGPoint(
            x: (size.width - space.width * scale) / 2,
            y: (size.height - space.height * scale) / 2
        )
        func place(_ point: CGPoint) -> CGPoint {
            CGPoint(x: offset.x + point.x * scale, y: offset.y + point.y * scale)
        }
        let home = CGPoint(x: 160, y: 268)
        let metersToPoints = 1.75

        func point(distance: Double, degrees: Double) -> CGPoint {
            let clamped = min(48, max(-48, degrees))
            let radians = clamped * .pi / 180
            let length = min(125, max(0, distance)) * metersToPoints
            return CGPoint(x: home.x + sin(radians) * length, y: home.y - cos(radians) * length)
        }

        // 페어 구역과 펜스
        var fair = Path()
        fair.move(to: place(home))
        fair.addLine(to: place(point(distance: 118, degrees: -48)))
        fair.addArc(
            center: place(home), radius: 118 * metersToPoints * scale,
            startAngle: .degrees(222), endAngle: .degrees(318), clockwise: false
        )
        fair.closeSubpath()
        context.fill(fair, with: .color(BaseballTheme.canvas.opacity(0.55)))
        context.stroke(fair, with: .color(BaseballTheme.fieldChalk.opacity(0.32)), lineWidth: max(1, scale))

        // 내야 다이아몬드
        var diamond = Path()
        diamond.move(to: place(home))
        diamond.addLine(to: place(point(distance: 27.4, degrees: 45)))
        diamond.addLine(to: place(point(distance: 38.8, degrees: 0)))
        diamond.addLine(to: place(point(distance: 27.4, degrees: -45)))
        diamond.closeSubpath()
        context.fill(diamond, with: .color(BaseballTheme.fieldDirt.opacity(0.22)))
        context.stroke(diamond, with: .color(BaseballTheme.fieldChalk.opacity(0.5)), lineWidth: max(1, scale))

        // 타구. 컷 이후 진행도로 날아간다.
        let after = min(1, (progress - Self.cut) / (1 - Self.cut))
        let direction = Double(battedBall?.directionTenthsDegrees ?? 0) / 10
        let landing = Double(fielding?.landingDistanceTenthsMeters ?? 400) / 10
        let travelled = landing * after
        let ballPoint = point(distance: travelled, degrees: direction)

        var flight = Path()
        flight.move(to: place(home))
        flight.addLine(to: place(ballPoint))
        context.stroke(
            flight,
            with: .color(tone.opacity(0.85)),
            style: StrokeStyle(lineWidth: max(1.5, 2.6 * scale), lineCap: .round)
        )

        // 낙하 예정 지점을 미리 표시해 긴장을 만든다.
        let target = place(point(distance: landing, degrees: direction))
        let ring = 12.0 * scale
        context.stroke(
            Path(ellipseIn: CGRect(x: target.x - ring, y: target.y - ring, width: ring * 2, height: ring * 2)),
            with: .color(tone.opacity(0.35 + 0.4 * after)),
            style: StrokeStyle(lineWidth: max(1, 1.6 * scale), dash: [5 * scale, 4 * scale])
        )

        // 공. 정점에서 커졌다가 낙하하며 작아진다.
        let arc = sin(after * .pi)
        let ballRadius = (3.4 + 3.2 * arc) * scale
        let center = place(ballPoint)
        context.fill(
            Path(ellipseIn: CGRect(x: center.x - ballRadius, y: center.y - ballRadius, width: ballRadius * 2, height: ballRadius * 2)),
            with: .color(BaseballTheme.fieldChalk)
        )

        // 담당 수비수가 낙하 지점으로 달려온다.
        if let fielding, let name = fielding.fielderName {
            let start = Self.fielderHome(fielding.fielderPosition)
            let startPoint = point(distance: start.distance, degrees: start.degrees)
            let landingPoint = point(distance: landing, degrees: direction)
            let chase = min(1, after * 1.15)
            let current = CGPoint(
                x: startPoint.x + (landingPoint.x - startPoint.x) * chase,
                y: startPoint.y + (landingPoint.y - startPoint.y) * chase
            )
            let marker = place(current)
            let size = 6.0 * scale
            context.fill(
                Path(ellipseIn: CGRect(x: marker.x - size, y: marker.y - size, width: size * 2, height: size * 2)),
                with: .color(BaseballTheme.information)
            )
            if after > 0.55 {
                let label = Text(name)
                    .font(.system(size: 13 * scale, weight: .bold))
                    .foregroundStyle(BaseballTheme.information)
                context.draw(context.resolve(label), at: CGPoint(x: marker.x, y: marker.y - 18 * scale), anchor: .center)
            }
        }

        // 비거리 숫자. 클립에서 가장 먼저 읽히는 값이다.
        if after > 0.35 {
            let distanceText = Text("\(Int(landing))m")
                .font(.system(size: 26 * scale, weight: .heavy, design: .monospaced))
                .foregroundStyle(tone)
            context.draw(
                context.resolve(distanceText),
                at: CGPoint(
                    x: offset.x + space.width * scale - 20 * scale,
                    y: offset.y + space.height * scale - 18 * scale
                ),
                anchor: .bottomTrailing
            )
        }
    }

    /// 수비 위치의 대략적 출발점. 코어는 담당 수비수만 알려 주므로 그 자리에서 출발시킨다.
    private static func fielderHome(_ position: FielderPosition?) -> (distance: Double, degrees: Double) {
        switch position {
        case .pitcher: (18.4, 0)
        case .catcher: (2, 0)
        case .firstBase: (26, 38)
        case .secondBase: (38, 20)
        case .thirdBase: (26, -38)
        case .shortstop: (38, -20)
        case .leftField: (88, -32)
        case .centerField: (96, 0)
        case .rightField: (88, 32)
        case .none: (60, 0)
        }
    }

    // MARK: - 공통

    private var impactPulse: Double {
        let window = 0.12
        guard progress >= Self.contact, progress < Self.contact + window else { return 0 }
        return 1 - (progress - Self.contact) / window
    }

    private var verdictFlash: Double {
        let start = Self.contact + 0.04
        guard progress >= start else { return 0 }
        return min(1, (progress - start) / 0.1)
    }

    private func shakeOffset(scale: Double) -> CGPoint {
        guard isBatted, impactPulse > 0 else { return .zero }
        let quality = Double(battedBall?.contactQuality ?? 500) / 1_000
        let amount = 5.5 * quality * impactPulse * scale
        // 결정론적 흔들림. 같은 결과는 항상 같은 화면을 만든다.
        return CGPoint(x: sin(progress * 92) * amount, y: cos(progress * 71) * amount * 0.6)
    }

    /// 결과 한 단어. 이 장면이 무엇이었는지 3초 안에 읽히게 한다.
    private func drawVerdict(context: GraphicsContext, size: CGSize) {
        guard verdictFlash > 0 else { return }
        let scale = min(size.width / Self.pitchBox.width, size.height / Self.pitchBox.height)
        let text = Text(PitchCopy.outcome(outcome, battedBall: battedBall))
            .font(.system(size: 32 * scale, weight: .heavy))
            .foregroundStyle(tone)
        var resolved = context.resolve(text)
        resolved.shading = .color(tone.opacity(verdictFlash))
        let rise = (1 - verdictFlash) * 16 * scale
        context.draw(resolved, at: CGPoint(x: size.width / 2, y: size.height * 0.12 + rise), anchor: .center)
    }

    private var tone: Color {
        switch outcome {
        case .swingingStrike, .calledStrike, .inPlayOut: BaseballTheme.action
        case .ball, .foul, .hitByPitch: BaseballTheme.warning
        case .single, .double, .triple, .homeRun: BaseballTheme.negative
        }
    }

    private static func platePoint(x: Double, y: Double) -> CGPoint {
        // 0.08 스케일에서 존이 패널 폭의 35%였다 — 한 회차에 수백 번 보는 화면의
        // 실질 그림이 우표 크기였다는 뜻이다(QA P1-8). 0.15로 폭 66%.
        CGPoint(
            x: min(272, max(48, 160 + x * 0.15)),
            y: min(292, max(48, platePlaneY - y * 0.15))
        )
    }

    private var replayPoints: [CGPoint] {
        let samples = TrajectorySample.decode(execution.trajectorySeries)
        guard samples.count >= 2, let first = samples.first, let last = samples.last else {
            let actual = Self.platePoint(x: Double(execution.actualX), y: Double(execution.actualY))
            return (0...24).map { step in
                let t = Double(step) / 24
                return CGPoint(
                    x: Self.releasePoint.x + (actual.x - Self.releasePoint.x) * t,
                    y: Self.releasePoint.y + (actual.y - Self.releasePoint.y) * t
                )
            }
        }
        let forwardSpan = max(1, first.forwardMeters - last.forwardMeters)
        let projected = samples.map { sample -> CGPoint in
            let progress = min(1, max(0, (first.forwardMeters - sample.forwardMeters) / forwardSpan))
            let cameraScale = 35 + (93 - 35) * progress
            let referenceHeight = first.heightMeters + (0.75 - first.heightMeters) * progress
            let verticalScale = 70 + (160 - 70) * progress
            return CGPoint(
                x: 160 + sample.lateralMeters * cameraScale,
                y: (116 + (Self.platePlaneY - 116) * progress) - (sample.heightMeters - referenceHeight) * verticalScale
            )
        }
        // 마지막 점을 실제 판정 좌표로 맞춘다. 궤적과 미트가 다른 자리에 있으면 화면이 판정과
        // 다른 이야기를 하게 된다. 어긋난 양을 뒤로 갈수록 크게 나눠 흡수시킨다.
        guard let tail = projected.last else { return projected }
        let plate = Self.platePoint(x: Double(execution.actualX), y: Double(execution.actualY))
        let dx = plate.x - tail.x
        let dy = plate.y - tail.y
        return projected.enumerated().map { index, point in
            let weight = Double(index) / Double(max(1, projected.count - 1))
            return CGPoint(x: point.x + dx * weight, y: point.y + dy * weight)
        }
    }
}
