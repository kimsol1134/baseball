import SwiftUI

/// 회차 카드 — 한 회차의 일생을 이미지 한 장으로.
///
/// 완주의 보상이 숫자 화면이면 그 화면은 닫히는 순간 사라진다. 카드 한 장이면
/// 저장되고, 공유되고, 자랑이 된다 — "3회차 만에 1라운드"는 캡처가 아니라
/// 카드로 도는 이야기다. 이 카드가 이 게임의 바깥 얼굴이므로 여기서만큼은
/// 정보를 아끼지 않는다: 이름·별명·결과·통산·그 회차의 이야기까지.
struct LifeCardView: View {
    let record: HighSchoolCareerStore.LifeRecord

    @Environment(\.gameCopyResolver) private var copyResolver

    /// 능력 성장 줄이 들어오면서 600으로는 연대기가 한 줄까지 밀렸다. 공유물은 세로로
    /// 길어도 손해가 없다 — 카톡·트위터 모두 세로 카드를 그대로 보여 준다.
    static let size = CGSize(width: 360, height: 680)

    private var latestNickname: String? { record.nicknames?.last }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(copyResolver.resolve(
                    AppCopyKey.conclusionLifeCardHeader,
                    arguments: [.integer(record.lifeNumber)]
                ))
                    .eyebrowStyle(BaseballTheme.milestone)
                Spacer()
                Text(copyResolver.resolve(
                    record.drafted ? AppCopyKey.conclusionLifeCardDrafted : AppCopyKey.conclusionLifeCardUndrafted
                ))
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(record.drafted ? BaseballTheme.action : BaseballTheme.textTertiary)
            }

            HStack(alignment: .center, spacing: 14) {
                // 지명된 회차는 프로 유니폼의 얼굴로 남는다 — 카드가 그 회차의 결말이다.
                // size는 폭이다(높이 = 폭×76/58). 카드는 600pt 고정이라 초상 높이를
                // 예전 아바타(76pt)와 같게 맞춰야 아래 연대기·푸터가 밀리지 않는다.
                    PortraitView(seed: record.portraitSeed, role: .player, size: 58,
                                 playerStage: record.drafted ? .pro : .ace)
                VStack(alignment: .leading, spacing: 3) {
                    if let nickname = latestNickname {
                        let nicknameTitle = HighSchoolConclusionPresentation.localizedNicknameTitle(
                            nickname, resolver: copyResolver
                        )
                        Text("'\(nicknameTitle)'")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(BaseballTheme.milestone)
                    }
                    // localization-safe: user-input
                    Text(record.playerName)
                        .font(BaseballType.display)
                        .foregroundStyle(BaseballTheme.textPrimary)
                    // localization-safe: resolved-copy
                    Text(identityLine)
                        .font(.footnote)
                        .foregroundStyle(BaseballTheme.textSecondary)
                        // 카드가 빡빡해지면 SwiftUI가 이 줄부터 눌러 "…무…"로 끊는다.
                        // 학교·성격·바람은 이 선수가 누구였는지라 잘리면 안 된다.
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }

            // 결과 — 이 카드의 헤드라인.
            VStack(alignment: .leading, spacing: 4) {
                Text(record.drafted ? draftedResult : copyResolver.resolve(AppCopyKey.conclusionLifeCardResultUndrafted))
                    .font(.title3.weight(.heavy))
                    .foregroundStyle(record.drafted ? BaseballTheme.action : BaseballTheme.textPrimary)
                Text(copyResolver.resolve(
                    AppCopyKey.conclusionLifeCardScoutScore,
                    arguments: [.integer(record.evaluationScore)]
                ))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(BaseballTheme.textTertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(
                record.drafted ? BaseballTheme.actionSoft : BaseballTheme.surfaceSoft,
                in: RoundedRectangle(cornerRadius: 12)
            )

            // 3년 동안 키운 것 — 이 카드의 진짜 자랑거리.
            //
            // 예전 카드는 경기·탈삼진·볼넷·실점 네 숫자만 있었다. 그건 "무슨 일이
            // 있었나"이지 "내가 무엇을 해냈나"가 아니다. 육성 게임의 자랑은 키운
            // 폭이므로 시작과 끝을 나란히 두고 오른 만큼을 굵게 적는다.
            if let start = record.abilityStart, let end = record.abilityFinal {
                VStack(alignment: .leading, spacing: 7) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(copyResolver.resolve(AppCopyKey.conclusionLifeCardGrowthTitle))
                            .eyebrowStyle(BaseballTheme.action)
                        Spacer(minLength: 0)
                        let delta = end.total - start.total
                        // localization-safe: numeric
                        Text(delta > 0 ? "+\(delta)" : "\(delta)")
                            .font(.title3.weight(.black).monospacedDigit())
                            .foregroundStyle(delta > 0 ? BaseballTheme.action : BaseballTheme.textTertiary)
                        Text(copyResolver.resolve(
                            AppCopyKey.conclusionLifeCardGrowthTotal,
                            arguments: [.integer(start.total), .integer(end.total)]
                        ))
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(BaseballTheme.textTertiary)
                    }
                    VStack(spacing: 5) {
                        growth(AppCopyKey.conclusionLifeCardGrowthStuff, start.stuff, end.stuff)
                        growth(AppCopyKey.conclusionLifeCardGrowthCommand, start.command, end.command)
                        growth(AppCopyKey.conclusionLifeCardGrowthMovement, start.movement, end.movement)
                        growth(AppCopyKey.conclusionLifeCardGrowthStamina, start.stamina, end.stamina)
                    }
                }
                .padding(10)
                .background(BaseballTheme.actionSoft, in: RoundedRectangle(cornerRadius: 12))
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(copyResolver.resolve(AppCopyKey.conclusionLifeCardStatsTitle))
                    .eyebrowStyle(BaseballTheme.textTertiary)
                // 야구를 아는 사람이 먼저 보는 줄. 이닝이 있어야 방어율·WHIP이 성립한다.
                if let rate = rateLine {
                    HStack(spacing: 0) {
                        rateStat(AppCopyKey.conclusionLifeCardInnings, rate.innings)
                        rateStat(AppCopyKey.conclusionLifeCardRA9, rate.ra9)
                        rateStat(AppCopyKey.conclusionLifeCardWHIP, rate.whip)
                        rateStat(AppCopyKey.conclusionLifeCardK9, rate.strikeoutsPerNine)
                    }
                }
                HStack(spacing: 0) {
                    stat(AppCopyKey.conclusionLifeCardGames, record.games)
                    stat(AppCopyKey.conclusionLifeCardStrikeouts, record.strikeouts)
                    stat(AppCopyKey.conclusionLifeCardHits, record.hits ?? 0)
                    stat(AppCopyKey.conclusionLifeCardWalks, record.walks)
                    stat(AppCopyKey.conclusionLifeCardRuns, record.runsAllowed)
                }
                // 던진 공 수와 탈삼진/볼넷은 "얼마나 잘 던졌나"를 한 줄로 말한다.
                // 기록 탭의 통산 지표는 팀 자동 경기까지 합치므로 기준을 함께 적는다(QA P1-5).
                // localization-safe: resolved-copy
                Text(seasonLine)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(BaseballTheme.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            if let nicknames = record.nicknames, !nicknames.isEmpty {
                Text(nicknames.map {
                    "'\(HighSchoolConclusionPresentation.localizedNicknameTitle($0, resolver: copyResolver))'"
                }.joined(separator: "  "))
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(BaseballTheme.milestone)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let signature = record.signatureLegacy {
                let localized = HighSchoolConclusionPresentation.localizedSignature(
                    signature, resolver: copyResolver
                )
                Label(
                    copyResolver.resolve(
                        AppCopyKey.conclusionLifeCardSignature,
                        arguments: [.userText(localized.title)]
                    ),
                    systemImage: "seal.fill"
                )
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(BaseballTheme.milestone)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel(copyResolver.resolve(
                        AppCopyKey.conclusionLifeCardSignatureAccessibility,
                        arguments: [.userText(localized.title)]
                    ))
            }

            // 함께한 사람들 — 이 회차를 사람 이름으로 기억하게 한다.
            if record.coachName != nil || record.rivalName != nil {
                // localization-safe: resolved-copy
                Text(castLine)
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
                Text(copyResolver.resolve(AppCopyKey.conclusionLifeCardFooter))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(BaseballTheme.textTertiary)
                Spacer()
                VStack(alignment: .trailing, spacing: 1) {
                    Text(copyResolver.resolve(
                        AppCopyKey.conclusionLifeCardComplete,
                        arguments: [.integer(record.lifeNumber)]
                    ))
                        .font(.caption2)
                        .foregroundStyle(BaseballTheme.textTertiary)
                    // 시드 각인 — 카드를 본 사람이 같은 판에 도전할 수 있는 입구.
                    // 회차를 함께 적는다: 재능·바람·일정은 시드+회차의 함수라, 회차가
                    // 다르면 같은 시드도 다른 판이다(3차 패널 P1 — 거짓 약속 방지).
                    if let seed = Self.seedText(record.careerID) {
                        Text(copyResolver.resolve(
                            AppCopyKey.conclusionLifeCardChallenge,
                            arguments: [.userText(seed), .integer(record.lifeNumber)]
                        ))
                            .font(BaseballType.scoreboardLabel)
                            .foregroundStyle(BaseballTheme.textTertiary)
                    }
                }
            }
        }
        .padding(20)
        // 높이를 못 박으면 내용이 넘칠 때 **푸터가 밖으로 밀려 잘린다** — 성장 막대와
        // 투구 지표를 넣자마자 실제로 그렇게 됐다. 공유물은 세로로 길어도 손해가 없으므로
        // 최소 높이만 정하고 내용에 맞춰 늘어나게 둔다. 미리보기는 굽힌 이미지의 실제
        // 비율을 그대로 쓰므로 카드가 길어져도 어긋나지 않는다.
        .frame(width: Self.size.width)
        .frame(minHeight: Self.size.height, alignment: .top)
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
    nonisolated static func seedText(_ careerID: String?) -> String? {
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

    private var identityLine: String {
        let school = HighSchoolConclusionPresentation.localizedSchoolName(
            record.schoolName, resolver: copyResolver
        )
        let personality = record.personality.map {
            "'\(HighSchoolConclusionPresentation.localizedLifePersonality($0, resolver: copyResolver) ?? GameCopyResolver.unavailableText)'"
        }
        let wind = HighSchoolConclusionPresentation.localizedLifeWind(
            id: record.windID, rawTitle: record.windTitle, resolver: copyResolver
        ).map { copyResolver.resolve(AppCopyKey.conclusionLifeCardWind, arguments: [.userText($0)]) }
        return [school, personality, wind].compactMap { $0 }.joined(separator: " · ")
    }

    private var draftedResult: String {
        let team = HighSchoolConclusionPresentation.localizedLifeTeamName(
            record.teamName, resolver: copyResolver
        ) ?? copyResolver.resolve(AppCopyKey.conclusionLifeCardSchoolUnknown)
        return copyResolver.resolve(
            AppCopyKey.conclusionLifeCardResultDrafted,
            arguments: [.userText(team)]
        )
    }

    private var castLine: String {
        let coach = HighSchoolConclusionPresentation.localizedLifeCastName(
            rawName: record.coachName, schoolName: record.schoolName, role: .coach, resolver: copyResolver
        ).map { copyResolver.resolve(AppCopyKey.conclusionLifeCardCoach, arguments: [.userText($0)]) }
        let catcher = HighSchoolConclusionPresentation.localizedLifeCastName(
            rawName: record.catcherName, schoolName: record.schoolName, role: .catcher, resolver: copyResolver
        ).map { copyResolver.resolve(AppCopyKey.conclusionLifeCardCatcher, arguments: [.userText($0)]) }
        let rival = HighSchoolConclusionPresentation.localizedLifeRivalName(
            record.rivalName, resolver: copyResolver
        ).map { copyResolver.resolve(AppCopyKey.conclusionLifeCardRival, arguments: [.userText($0)]) }
        return [coach, catcher, rival].compactMap { $0 }.joined(separator: " · ")
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
                Text(HighSchoolConclusionPresentation.localizedChronicleLine(
                    line, resolver: copyResolver
                ))
                    .font(.caption)
                    .foregroundStyle(BaseballTheme.textSecondary)
                    .lineLimit(lineLimit)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// 이닝이 있어야 만들어지는 지표들. 아웃 수를 남기지 않던 옛 기록에서는 nil이라
    /// 이 줄이 통째로 접힌다 — 이닝을 투구수로 어림해서 방어율을 지어내지 않는다.
    private var rateLine: HighSchoolConclusionPresentation.RateLine? {
        HighSchoolConclusionPresentation.localizedLifeRateLine(
            outs: record.outs,
            runsAllowed: record.runsAllowed,
            walks: record.walks,
            hits: record.hits,
            strikeouts: record.strikeouts,
            resolver: copyResolver
        )
    }

    /// "132구 · 탈삼진/볼넷 3.1 · 직접 등판 기준". 숫자 넉 줄만으로는 잘 던졌는지가
    /// 안 잡힌다 — 비율 하나가 그것을 말해 준다.
    private var seasonLine: String {
        HighSchoolConclusionPresentation.localizedLifeSeasonLine(
            pitches: record.pitches,
            strikeouts: record.strikeouts,
            walks: record.walks,
            resolver: copyResolver
        )
    }

    /// 비율 지표는 값이 주인공이다 — 이름은 작게 아래에 둔다.
    private func rateStat(_ title: GameCopyKey, _ value: String) -> some View {
        VStack(spacing: 1) {
            // localization-safe: numeric
            Text(value)
                .font(.title3.weight(.heavy).monospacedDigit())
                .foregroundStyle(BaseballTheme.milestone)
            Text(copyResolver.resolve(title))
                .font(.caption2)
                .foregroundStyle(BaseballTheme.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }

    /// 한 줄짜리 성장 막대. 숫자 넉 줄보다 **길이**가 먼저 읽힌다 — 흐린 막대가
    /// 시작점이고, 그 위에 덧칠된 밝은 막대가 3년 동안 늘린 만큼이다.
    private func growth(_ title: GameCopyKey, _ start: Int, _ end: Int) -> some View {
        let delta = end - start
        let scale = 99.0
        return HStack(spacing: 8) {
            Text(copyResolver.resolve(title))
                .font(.caption2.weight(.bold))
                .foregroundStyle(BaseballTheme.textSecondary)
                .frame(width: 26, alignment: .leading)
            GeometryReader { proxy in
                let width = proxy.size.width
                ZStack(alignment: .leading) {
                    Capsule().fill(BaseballTheme.surfaceRaised)
                    // 시작 구간 — 물려받아 출발한 자리.
                    Capsule()
                        .fill(BaseballTheme.textTertiary.opacity(0.55))
                        .frame(width: width * min(1, Double(start) / scale))
                    // 늘린 구간은 시작 위에서 이어 그린다. 겹치지 않게 시작만큼 밀어 둔다.
                    Capsule()
                        .fill(BaseballTheme.action)
                        .frame(width: width * min(1, Double(max(0, delta)) / scale))
                        .offset(x: width * min(1, Double(start) / scale))
                }
            }
            .frame(height: 10)
            Text("\(end)")
                .font(.subheadline.weight(.heavy).monospacedDigit())
                .foregroundStyle(BaseballTheme.textPrimary)
                .frame(width: 26, alignment: .trailing)
            // localization-safe: numeric
            Text(delta > 0 ? "+\(delta)" : "±0")
                .font(.caption2.weight(.heavy).monospacedDigit())
                .foregroundStyle(delta > 0 ? BaseballTheme.action : BaseballTheme.textTertiary)
                .frame(width: 28, alignment: .trailing)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(growthAccessibility(title: title, start: start, end: end, delta: delta))
    }

    private func growthAccessibility(
        title: GameCopyKey,
        start: Int,
        end: Int,
        delta: Int
    ) -> String {
        let baseArguments: [LocalizedCopyArgument] = [
            .userText(copyResolver.resolve(title)), .integer(start), .integer(end),
        ]
        if delta > 0 {
            return copyResolver.resolve(
                AppCopyKey.conclusionLifeCardGrowthAccessibilityUp,
                arguments: baseArguments + [.integer(delta)]
            )
        }
        return copyResolver.resolve(
            AppCopyKey.conclusionLifeCardGrowthAccessibilityNoChange,
            arguments: baseArguments
        )
    }

    private func stat(_ title: GameCopyKey, _ value: Int) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.title3.weight(.bold).monospacedDigit())
                .foregroundStyle(BaseballTheme.textPrimary)
            Text(copyResolver.resolve(title))
                .font(.caption2)
                .foregroundStyle(BaseballTheme.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }
}

/// 카드를 공유 가능한 이미지로. 렌더 실패 시 버튼 자체가 숨는다 — 깨진 카드를
/// 공유시키는 것보다 낫다.
enum LifeCardRenderer {
    /// 굽는 값은 기록에만 달려 있다 — 같은 기록이면 같은 그림이다.
    ///
    /// 캐시가 없을 때는 `body`가 평가될 때마다 1080×2040 @3x 비트맵을 메인 스레드에서
    /// 다시 구웠다. 기억을 고르는 화면은 미리보기와 공유 버튼이 나란히 있어 한 번의
    /// 평가에 두 번 돌았고, 체크박스를 누를 때마다 그게 반복됐다 — 감정이 가장 높은
    /// 화면이 가장 끊겼다.
    @MainActor private static var cache: (key: String, image: UIImage)?

    @MainActor
    static func image(for record: HighSchoolCareerStore.LifeRecord) -> UIImage? {
        image(for: record, resolver: GameCopyResolver())
    }

    @MainActor
    static func image(
        for record: HighSchoolCareerStore.LifeRecord,
        resolver: GameCopyResolver
    ) -> UIImage? {
        let key = cacheKey(for: record, language: resolver.language)
        if let cache, cache.key == key { return cache.image }
        let renderer = ImageRenderer(
            content: LifeCardView(record: record).environment(\.gameCopyResolver, resolver)
        )
        renderer.scale = 3
        renderer.isOpaque = true
        guard let image = renderer.uiImage else { return nil }
        cache = (key, image)
        return image
    }

    /// 카드에 그려지는 것이 바뀌면 달라져야 하고, 그 외에는 같아야 한다.
    @MainActor
    private static func cacheKey(
        for record: HighSchoolCareerStore.LifeRecord,
        language: AppLanguage
    ) -> String {
        let abilities = [record.abilityStart?.total, record.abilityFinal?.total]
            .map { $0.map(String.init) ?? "-" }.joined(separator: "/")
        return [
            language.rawValue,
            record.careerID ?? "", String(record.lifeNumber), record.playerName,
            String(record.evaluationScore), String(record.drafted), record.teamName ?? "",
            String(record.games), String(record.strikeouts), String(record.walks),
            String(record.runsAllowed), String(record.outs ?? -1), String(record.hits ?? -1),
            abilities, record.signatureLegacy?.title ?? "",
            (record.nicknames ?? []).joined(separator: ","),
            String((record.chronicle ?? []).count),
        ].joined(separator: "|")
    }
}

/// 공유되는 물건이 앱으로 돌아오는 길.
///
/// 예전에는 공유 아이템이 이미지 한 장뿐이라, 카드가 아무리 돌아도 그것을 본 사람이
/// 앱에 닿을 방법이 없었다 — 저장소 어디에도 스토어 주소가 없었다. 카드에 도전 시드를
/// 각인해 두고 "같은 판에 도전할 수 있는 입구"라고 적어 놓고는, 정작 그 입구를 열어 줄
/// 문장을 함께 보내지 않고 있었다.
enum LifeCardShareText {
    static let storeURL = "https://apps.apple.com/kr/app/id6794754217"

    static func body(for record: HighSchoolCareerStore.LifeRecord) -> String {
        body(for: record, resolver: GameCopyResolver())
    }

    static func body(
        for record: HighSchoolCareerStore.LifeRecord,
        resolver: GameCopyResolver
    ) -> String {
        var lines = [resolver.resolve(
            AppCopyKey.conclusionLifeCardShareBodyHeader,
            arguments: [.userText(record.playerName), .integer(record.lifeNumber)]
        )]
        if record.drafted, let team = record.teamName {
            let localizedTeam = HighSchoolConclusionPresentation.localizedLifeTeamName(
                team, resolver: resolver
            ) ?? resolver.resolve(AppCopyKey.conclusionLifeCardSchoolUnknown)
            lines.append(resolver.resolve(
                AppCopyKey.conclusionLifeCardResultDrafted,
                arguments: [.userText(localizedTeam)]
            ) + " · " + resolver.resolve(
                AppCopyKey.conclusionLifeCardScoutScore,
                arguments: [.integer(record.evaluationScore)]
            ))
        } else {
            lines.append(resolver.resolve(AppCopyKey.conclusionLifeCardResultUndrafted) + " · " + resolver.resolve(
                AppCopyKey.conclusionLifeCardScoutScore,
                arguments: [.integer(record.evaluationScore)]
            ))
        }
        // 시드는 "같은 판"을 여는 열쇠다. 카드에 각인된 문자열과 같은 형식으로 적는다.
        if let seed = LifeCardView.seedText(record.careerID) {
            lines.append(resolver.resolve(
                AppCopyKey.conclusionLifeCardShareBodyChallenge,
                arguments: [.userText(seed), .integer(record.lifeNumber)]
            ))
        }
        lines.append(storeURL)
        return lines.joined(separator: "\n")
    }
}

/// 화면에 보이는 미리보기 = 실제로 공유되는 이미지.
///
/// 예전에는 `LifeCardView`를 그대로 놓고 `scaleEffect` 뒤에 `frame(height:)`를 걸었다.
/// `scaleEffect`는 레이아웃 크기를 바꾸지 않으므로 600pt짜리 뷰가 432pt 상자 안에서
/// **세로 가운데로 정렬**됐고, 축소는 위(anchor: .top) 기준이라 카드가 84pt 위로 밀려
/// 잘렸다 — "삐뚤어져 보인다"의 실체다. 굽힌 이미지를 그대로 보여 주면 그 어긋남이
/// 원천적으로 없고, 공유 전에 무엇이 나갈지 정확히 보인다.
struct LifeCardPreview: View {
    let record: HighSchoolCareerStore.LifeRecord
    var maximumWidth: CGFloat = LifeCardView.size.width

    @Environment(\.gameCopyResolver) private var copyResolver

    var body: some View {
        if let image = LifeCardRenderer.image(for: record, resolver: copyResolver) {
            // 비율은 이미지 자신의 것을 쓴다. 카드 크기 상수로 계산해 넘기면 굽힌 결과와
            // 1pt만 어긋나도 아래쪽(푸터)이 잘린다 — 실제로 그렇게 잘렸다.
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: maximumWidth)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .frame(maxWidth: .infinity)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel(copyResolver.resolve(
                    AppCopyKey.conclusionLifeCardPreviewAccessibility,
                    arguments: [.userText(record.playerName)]
                ))
        }
    }
}

/// 아카이브·회차 마감 화면에서 쓰는 공유 버튼. 카드 미리보기와 함께 놓는다.
struct LifeCardShareButton: View {
    let record: HighSchoolCareerStore.LifeRecord

    @Environment(\.gameCopyResolver) private var copyResolver

    var body: some View {
        if let image = LifeCardRenderer.image(for: record, resolver: copyResolver) {
            ActivityShareButton(
                items: [image, LifeCardShareText.body(for: record, resolver: copyResolver)],
                subject: copyResolver.resolve(
                    AppCopyKey.conclusionLifeCardShareSubject,
                    arguments: [.userText(record.playerName), .integer(record.lifeNumber)]
                ),
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
                Label(
                    copyResolver.resolve(AppCopyKey.conclusionLifeCardShare),
                    systemImage: "square.and.arrow.up"
                )
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(BaseballTheme.action)
            }
            .accessibilityIdentifier("life.card.share")
        }
    }
}
