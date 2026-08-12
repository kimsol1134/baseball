import Foundation

/// 경기 뒤 익명 야구 커뮤니티의 반응.
///
/// 기사와 능력치는 공식 세계의 언어다. 애착은 비공식 세계에서 완성된다 —
/// 어딘가의 게시판에서 모르는 사람들이 내 선수 얘기를 하고 있다는 감각.
/// 잘 던지면 감탄하고, 볼넷이 쌓이면 냉정하게 놀린다. 그 냉정함까지가 세상이다.
///
/// 결정론: careerID와 경기 번호로 시드를 만들므로 같은 회차의 같은 경기는
/// 언제 다시 봐도 같은 반응이다. 커널 난수 경로와는 완전히 분리돼 있다.
public enum CommunityBuzz {
    /// 방금 경기에 대한 반응 3줄. 경기 내용에 맞는 풀에서 뽑는다.
    public static func reactions(
        careerID: String,
        gameNumber: Int,
        strikeouts: Int,
        walks: Int,
        runsAllowed: Int,
        newNickname: String? = nil
    ) -> [String] {
        selectedReactionLines(
            careerID: careerID,
            gameNumber: gameNumber,
            strikeouts: strikeouts,
            walks: walks,
            runsAllowed: runsAllowed,
            includeNickname: newNickname != nil,
            nicknameID: nil
        ).map { $0.koreanText(nicknameTitle: newNickname) }
    }

    /// Typed, ephemeral reaction values for localized clients. The selection path is shared with
    /// `reactions`, including its seed, pool order, and duplicate filtering.
    public static func reactionLines(
        careerID: String,
        gameNumber: Int,
        strikeouts: Int,
        walks: Int,
        runsAllowed: Int,
        newNickname: Nickname? = nil
    ) -> [CommunityBuzzReactionLine] {
        selectedReactionLines(
            careerID: careerID,
            gameNumber: gameNumber,
            strikeouts: strikeouts,
            walks: walks,
            runsAllowed: runsAllowed,
            includeNickname: newNickname != nil,
            nicknameID: newNickname?.id
        )
    }

    private static func selectedReactionLines(
        careerID: String,
        gameNumber: Int,
        strikeouts: Int,
        walks: Int,
        runsAllowed: Int,
        includeNickname: Bool,
        nicknameID: String?
    ) -> [CommunityBuzzReactionLine] {
        var generator = SplitMix64(
            seed: StableHash.fnv1a64Value("buzz|\(careerID)|\(gameNumber)")
        )

        var picked: [CommunityBuzzReactionLine] = []
        // 별명이 붙은 날은 그 얘기부터 나온다.
        if includeNickname {
            picked.append(pick(&generator, [
                CommunityBuzzReactionLine(
                    templateID: .nicknameQuestion,
                    nicknameID: nicknameID
                ),
                CommunityBuzzReactionLine(
                    templateID: .nicknameCalling,
                    nicknameID: nicknameID
                ),
                CommunityBuzzReactionLine(
                    templateID: .nicknameHighSchoolReal,
                    nicknameID: nicknameID
                ),
            ]))
        }

        if runsAllowed == 0, strikeouts >= 5 {
            picked.append(pick(&generator, [
                CommunityBuzzReactionLine(templateID: .dominantShutoutNeverSawIt),
                CommunityBuzzReactionLine(
                    templateID: .dominantShutoutLevel,
                    numericArgument: strikeouts
                ),
                CommunityBuzzReactionLine(templateID: .dominantShutoutAge),
                CommunityBuzzReactionLine(templateID: .dominantShutoutScouts),
            ]))
        } else if runsAllowed == 0 {
            picked.append(pick(&generator, [
                CommunityBuzzReactionLine(templateID: .shutoutQuiet),
                CommunityBuzzReactionLine(templateID: .shutoutConsistent),
                CommunityBuzzReactionLine(templateID: .shutoutStands),
            ]))
        } else if walks >= 3 {
            picked.append(pick(&generator, [
                CommunityBuzzReactionLine(
                    templateID: .wildnessWalks,
                    numericArgument: walks
                ),
                CommunityBuzzReactionLine(templateID: .wildnessFrustrated),
                CommunityBuzzReactionLine(templateID: .wildnessStuff),
            ]))
        } else if runsAllowed >= 4 {
            picked.append(pick(&generator, [
                CommunityBuzzReactionLine(templateID: .roughOutingMisses),
                CommunityBuzzReactionLine(
                    templateID: .roughOutingNextTest,
                    numericArgument: runsAllowed
                ),
                CommunityBuzzReactionLine(templateID: .roughOutingWatch),
            ]))
        } else if strikeouts >= 4 {
            picked.append(pick(&generator, [
                CommunityBuzzReactionLine(
                    templateID: .strikeoutShow,
                    numericArgument: strikeouts
                ),
                CommunityBuzzReactionLine(templateID: .strikeoutPitch),
                CommunityBuzzReactionLine(templateID: .strikeoutRhythm),
            ]))
        }

        // 일반 궁금증 — 세상이 이 선수의 '사람'을 궁금해하기 시작했다는 신호.
        let general: [CommunityBuzzReactionLine] = [
            .init(templateID: .generalGrade),
            .init(templateID: .generalNextGame),
            .init(templateID: .generalTraining),
            .init(templateID: .generalPro),
            .init(templateID: .generalOffField),
            .init(templateID: .generalHealth),
            .init(templateID: .generalLastYear),
            .init(templateID: .generalSchool),
        ]
        while picked.count < 3 {
            let line = pick(&generator, general)
            if !picked.contains(line) { picked.append(line) }
        }
        return picked
    }

    /// 챕터가 넘어갈 때 세계가 혼자 만든 사건들. 내 서사가 아니라 세계의 서사 —
    /// 라이벌들이 저희끼리 이기고 지고 다치고 돌아온다. 이 소음이 있어야
    /// 유망주 랭킹이 종이가 아니라 전장이 된다.
    public static func rivalNews(careerID: String, chapterNumber: Int) -> [String] {
        rivalNewsLines(careerID: careerID, chapterNumber: chapterNumber).map { $0.koreanText() }
    }

    /// Typed, ephemeral world-news values for localized clients. Numeric arguments are the
    /// original generated values; the prospect is carried by stable presentation identity.
    public static func rivalNewsLines(
        careerID: String,
        chapterNumber: Int
    ) -> [CommunityBuzzRivalNewsLine] {
        var generator = SplitMix64(
            seed: StableHash.fnv1a64Value("rival-news|\(careerID)|\(chapterNumber)")
        )
        // 랭킹 명단과 같은 시드 구성이라 같은 회차에서는 같은 인물들이 움직인다.
        let board = ProspectRanking.board(
            careerID: careerID, playerName: "", playerSchool: "",
            performance: CareerPerformanceSnapshot()
        ).filter { !$0.isPlayer }
        guard board.count >= 4 else { return [] }
        // 인물과 템플릿 모두 같은 챕터 안에서 중복 금지 — 이름만 바꾼 같은 문장이
        // 아래위로 붙는 순간 "세계"가 아니라 문자열 치환이 보인다. 수치도 변주한다.
        let strikeoutCount = 10 + generator.nextInt(upperBound: 5)
        let speedGain = 2 + generator.nextInt(upperBound: 4)
        var lines: [CommunityBuzzRivalNewsLine] = []
        var usedPeople = Set<Int>()
        var usedTemplates = Set<Int>()
        while lines.count < 2 {
            let who = generator.nextInt(upperBound: min(8, board.count))
            let template = generator.nextInt(
                upperBound: CommunityBuzzRivalNewsTemplateID.allCases.count
            )
            guard !usedPeople.contains(who), !usedTemplates.contains(template) else { continue }
            guard let prospect = board[who].presentationIdentity else { continue }
            usedPeople.insert(who)
            usedTemplates.insert(template)
            let templateID = CommunityBuzzRivalNewsTemplateID.allCases[template]
            let numericArgument: Int? = switch templateID {
            case .strikeoutRecord: strikeoutCount
            case .velocityGain: speedGain
            case .regionalFinalShutout, .elbowPain, .rotationReset: nil
            }
            lines.append(CommunityBuzzRivalNewsLine(
                templateID: templateID,
                prospect: prospect,
                numericArgument: numericArgument
            ))
        }
        return lines
    }

    private static func pick<T: Equatable>(_ generator: inout SplitMix64, _ pool: [T]) -> T {
        pool[generator.nextInt(upperBound: pool.count)]
    }
}
