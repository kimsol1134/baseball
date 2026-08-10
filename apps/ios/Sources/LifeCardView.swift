import SwiftUI

/// 회차 카드 — 한 회차의 일생을 이미지 한 장으로.
///
/// 완주의 보상이 숫자 화면이면 그 화면은 닫히는 순간 사라진다. 카드 한 장이면
/// 저장되고, 공유되고, 자랑이 된다 — "3회차 만에 1라운드"는 캡처가 아니라
/// 카드로 도는 이야기다. 이 카드가 이 게임의 바깥 얼굴이므로 여기서만큼은
/// 정보를 아끼지 않는다: 이름·별명·결과·통산·그 회차의 이야기까지.
struct LifeCardView: View {
    let record: HighSchoolCareerStore.LifeRecord

    static let size = CGSize(width: 360, height: 600)

    private var latestNickname: String? { record.nicknames?.last }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("\(record.lifeNumber)번째 선수의 기록")
                    .eyebrowStyle(BaseballTheme.milestone)
                Spacer()
                Text(record.drafted ? "지명" : "미지명")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(record.drafted ? BaseballTheme.action : BaseballTheme.textTertiary)
            }

            HStack(alignment: .center, spacing: 14) {
                // 지명된 회차는 프로 유니폼의 얼굴로 남는다 — 카드가 그 회차의 결말이다.
                // size는 폭이다(높이 = 폭×76/58). 카드는 600pt 고정이라 초상 높이를
                // 예전 아바타(76pt)와 같게 맞춰야 아래 연대기·푸터가 밀리지 않는다.
                PortraitView(seed: record.playerName, role: .player, size: 58,
                             playerStage: record.drafted ? .pro : .ace)
                VStack(alignment: .leading, spacing: 3) {
                    if let nickname = latestNickname {
                        Text("'\(nickname)'")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(BaseballTheme.milestone)
                    }
                    Text(record.playerName)
                        .font(BaseballType.display)
                        .foregroundStyle(BaseballTheme.textPrimary)
                    Text([record.schoolName ?? "학교 미정", record.personality.map { "'\($0)'" },
                          record.windTitle.map { "바람 · \($0)" }]
                        .compactMap { $0 }.joined(separator: " · "))
                        .font(.footnote)
                        .foregroundStyle(BaseballTheme.textSecondary)
                }
                Spacer(minLength: 0)
            }

            // 결과 — 이 카드의 헤드라인.
            VStack(alignment: .leading, spacing: 4) {
                Text(record.drafted
                     ? "\(record.teamName ?? "프로 구단") 지명"
                     : "드래프트 미지명")
                    .font(.title3.weight(.heavy))
                    .foregroundStyle(record.drafted ? BaseballTheme.action : BaseballTheme.textPrimary)
                Text("스카우트 평가 \(record.evaluationScore)점")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(BaseballTheme.textTertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(
                record.drafted ? BaseballTheme.actionSoft : BaseballTheme.surfaceSoft,
                in: RoundedRectangle(cornerRadius: 12)
            )

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 0) {
                    stat("경기", record.games)
                    stat("탈삼진", record.strikeouts)
                    stat("볼넷", record.walks)
                    stat("실점", record.runsAllowed)
                }
                // 기록 탭의 통산 지표는 팀 자동 경기까지 합친다 — 기준을 안 적으면
                // 같은 회차에 서로 다른 "탈삼진"이 존재하게 된다(QA P1-5).
                Text("직접 등판 기준")
                    .font(.caption2)
                    .foregroundStyle(BaseballTheme.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            if let nicknames = record.nicknames, !nicknames.isEmpty {
                Text(nicknames.map { "'\($0)'" }.joined(separator: "  "))
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(BaseballTheme.milestone)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let signature = record.signatureLegacy {
                Label("대표 유산 · \(signature.title)", systemImage: "seal.fill")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(BaseballTheme.milestone)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel("대표 유산 \(signature.title)")
            }

            // 함께한 사람들 — 이 회차를 사람 이름으로 기억하게 한다.
            if record.coachName != nil || record.rivalName != nil {
                Text([record.coachName.map { "\($0) 감독" },
                      record.catcherName.map { "\($0) 포수" },
                      record.rivalName.map { "숙적 \($0)" }]
                    .compactMap { $0 }.joined(separator: " · "))
                    .font(.caption2)
                    .foregroundStyle(BaseballTheme.textSecondary)
            }

            if let chronicle = record.chronicle, !chronicle.isEmpty {
                // 카드는 600pt 고정인데 연대기는 회차마다 길이가 다르다. 다 넣으려 들면
                // VStack이 남은 높이에 맞춰 각 줄을 **한 줄로 눌러 버리고**, 문장이
                // 단어 중간에서 "…"로 끊긴다("끝까지…", "더 꾸…") — 공유된 카드가
                // 깨져 보인다는 제보의 실체다. 대표 유산·사람들 줄이 함께 있는 회차에서
                // 특히 그랬다.
                //
                // 그래서 줄 수를 미리 정하지 않고, **들어가는 만큼만** 넣는다.
                ViewThatFits(in: .vertical) {
                    chronicleBlock(lines(5))
                    chronicleBlock(lines(4))
                    chronicleBlock(lines(3))
                    chronicleBlock(lines(2))
                    chronicleBlock(lines(1))
                    // 마지막 보루 — 한 줄짜리 연대기도 안 들어가는 극단(초대형 글꼴)에서만.
                    chronicleBlock(lines(1), lineLimit: 3)
                }
            }

            Spacer(minLength: 0)

            HStack {
                Text("야구 못하면 또 환생함")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(BaseballTheme.textTertiary)
                Spacer()
                VStack(alignment: .trailing, spacing: 1) {
                    Text("\(record.lifeNumber)번째 선수 완주")
                        .font(.caption2)
                        .foregroundStyle(BaseballTheme.textTertiary)
                    // 시드 각인 — 카드를 본 사람이 같은 판에 도전할 수 있는 입구.
                    // 회차를 함께 적는다: 재능·바람·일정은 시드+회차의 함수라, 회차가
                    // 다르면 같은 시드도 다른 판이다(3차 패널 P1 — 거짓 약속 방지).
                    if let seed = Self.seedText(record.careerID) {
                        Text("도전 \(seed)-\(record.lifeNumber)")
                            .font(BaseballType.scoreboardLabel)
                            .foregroundStyle(BaseballTheme.textTertiary)
                    }
                }
            }
        }
        .padding(20)
        .frame(width: Self.size.width, height: Self.size.height, alignment: .top)
        .background {
            // 밤 구장 배경이 번들에 있으면 깔린다. 글자가 주인공이라 어둡게 눌러 쓴다.
            if UIImage(named: "LifeCardBackdrop") != nil {
                Image("LifeCardBackdrop")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .overlay(BaseballTheme.fieldNight.opacity(0.72))
            } else {
                BaseballTheme.fieldNight
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(BaseballTheme.border.opacity(0.6), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    /// careerID("career-시드-life-N")에서 시드만 뽑는다.
    static func seedText(_ careerID: String?) -> String? {
        guard let careerID, careerID.hasPrefix("career-") else { return nil }
        let parts = careerID.split(separator: "-")
        guard parts.count >= 2 else { return nil }
        return String(parts[1])
    }

    private var highlightLines: [String] {
        guard let chronicle = record.chronicle else { return [] }
        if chronicle.count <= 5 { return chronicle }
        return [chronicle[0]] + chronicle.suffix(4)
    }

    /// 줄 수를 줄일 때 무엇을 버릴 것인가 — 입학(처음)과 결말(마지막)은 남기고
    /// 가운데를 덜어낸다. 3년의 시작과 끝이 카드의 이야기이기 때문이다.
    private func lines(_ count: Int) -> [String] {
        let all = highlightLines
        guard count < all.count else { return all }
        guard count > 1 else { return Array(all.suffix(1)) }
        return [all[0]] + all.suffix(count - 1)
    }

    /// 기본은 줄 수 제한 없음 — 한 문장을 두 줄로 자르면 "…"가 단어 한가운데를 끊는다.
    /// 대신 **줄 수가 아니라 항목 수**로 분량을 맞춘다(위의 `ViewThatFits`).
    private func chronicleBlock(_ lines: [String], lineLimit: Int? = nil) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            // 처음과 마지막 — 시작한 아이와 끝낸 선수를 함께 담는다.
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                Text(line)
                    .font(.caption)
                    .foregroundStyle(BaseballTheme.textSecondary)
                    .lineLimit(lineLimit)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func stat(_ title: String, _ value: Int) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.title3.weight(.bold).monospacedDigit())
                .foregroundStyle(BaseballTheme.textPrimary)
            Text(title)
                .font(.caption2)
                .foregroundStyle(BaseballTheme.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }
}

/// 카드를 공유 가능한 이미지로. 렌더 실패 시 버튼 자체가 숨는다 — 깨진 카드를
/// 공유시키는 것보다 낫다.
enum LifeCardRenderer {
    @MainActor
    static func image(for record: HighSchoolCareerStore.LifeRecord) -> UIImage? {
        let renderer = ImageRenderer(content: LifeCardView(record: record))
        renderer.scale = 3
        renderer.isOpaque = true
        return renderer.uiImage
    }
}

/// 아카이브·회차 마감 화면에서 쓰는 공유 버튼. 카드 미리보기와 함께 놓는다.
struct LifeCardShareButton: View {
    let record: HighSchoolCareerStore.LifeRecord

    var body: some View {
        if let image = LifeCardRenderer.image(for: record) {
            ActivityShareButton(
                items: [image],
                subject: "\(record.playerName) · \(record.lifeNumber)번째 선수",
                onTapped: {
                    let properties: [String: Any] = ["life_number": record.lifeNumber]
                    GameAnalytics.log(.lifeCardShareTapped, properties)
                    // One-version dashboard compatibility. This legacy event is removed after 1.0.2.
                    GameAnalytics.log(.lifeCardShared, properties)
                },
                onCompleted: {
                    GameAnalytics.log(.lifeCardShareCompleted, ["life_number": record.lifeNumber])
                }
            ) {
                Label("선수 카드 공유", systemImage: "square.and.arrow.up")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(BaseballTheme.action)
            }
            .accessibilityIdentifier("life.card.share")
        }
    }
}
