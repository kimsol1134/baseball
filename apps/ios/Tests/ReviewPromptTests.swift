import XCTest
@testable import BaseballIOS

/// 별점 관문의 규칙을 고정한다. 시스템이 연 3회만 실제로 띄우므로,
/// "이유 하나는 한 번만 · 요청 사이 24시간"이 깨지면 리뷰 창을 낭비한다.
@MainActor
final class ReviewPromptTests: XCTestCase {

    private var defaults: UserDefaults!
    private let suiteName = "baseball.review.tests"

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    private var now: Date { Date(timeIntervalSince1970: 1_770_000_000) }

    /// 같은 이유는 평생 한 번. 두 번째 무실점 이닝은 감흥이 없다.
    func testReasonIsConsumedOnce() {
        XCTAssertTrue(ReviewPrompt.shouldAsk(.cleanInning, now: now, defaults: defaults))
        XCTAssertFalse(ReviewPrompt.shouldAsk(.cleanInning, now: now, defaults: defaults))
    }

    /// 다른 이유라도 24시간 안에는 열리지 않는다 — 시스템이 버리면 이유만 소진된다.
    func testDifferentReasonWaitsOutTheInterval() {
        XCTAssertTrue(ReviewPrompt.shouldAsk(.cleanInning, now: now, defaults: defaults))
        let sameDay = now.addingTimeInterval(ReviewPrompt.minimumInterval - 60)
        XCTAssertFalse(ReviewPrompt.shouldAsk(.goodRecap, now: sameDay, defaults: defaults))
        let nextDay = now.addingTimeInterval(ReviewPrompt.minimumInterval + 60)
        XCTAssertTrue(ReviewPrompt.shouldAsk(.goodRecap, now: nextDay, defaults: defaults))
    }

    /// 간격에 막힌 이유는 **소진되지 않아야** 한다. 소진되면 그 순간은 영영 사라진다.
    func testBlockedReasonSurvivesForLater() {
        _ = ReviewPrompt.shouldAsk(.cleanInning, now: now, defaults: defaults)
        _ = ReviewPrompt.shouldAsk(.dailyBest, now: now, defaults: defaults)
        let nextDay = now.addingTimeInterval(ReviewPrompt.minimumInterval + 60)
        XCTAssertTrue(ReviewPrompt.shouldAsk(.dailyBest, now: nextDay, defaults: defaults))
    }

    /// "모든 진행 삭제"는 별점 흔적까지 지운다.
    func testResetClearsEveryReason() {
        for reason in ReviewPrompt.Reason.allCases {
            let day = now.addingTimeInterval(Double(reason.hashValue % 1) + ReviewPrompt.minimumInterval * 10)
            _ = ReviewPrompt.shouldAsk(reason, now: day, defaults: defaults)
        }
        ReviewPrompt.reset(defaults: defaults)
        XCTAssertTrue(ReviewPrompt.shouldAsk(.drafted, now: now, defaults: defaults))
    }

    // MARK: - 어떤 정산이 물어도 되는 정산인가

    /// 미지명이어도 세상이 이름을 붙여 줬으면 만족한 상태다 — 여기서 물어야 한다.
    /// 예전 규칙(지명만)이 리뷰 유입을 사실상 0으로 만든 지점이다.
    func testUndraftedRunWithNicknameStillDeservesReview() {
        let record = Self.record(drafted: false, evaluation: 40, nicknames: ["불꽃"])
        XCTAssertTrue(HighSchoolCareerStore.recapDeservesReview(
            record, pledgeAchieved: false, previousBestEvaluation: 90
        ))
    }

    /// 지난 회차 최고 평가를 넘었으면 성장한 회차다.
    func testBeatingPreviousBestEvaluationDeservesReview() {
        let record = Self.record(drafted: false, evaluation: 71, nicknames: nil)
        XCTAssertTrue(HighSchoolCareerStore.recapDeservesReview(
            record, pledgeAchieved: false, previousBestEvaluation: 70
        ))
    }

    /// 아무것도 없이 망한 회차에서는 묻지 않는다.
    func testFlatFailedRunDoesNotDeserveReview() {
        let record = Self.record(drafted: false, evaluation: 30, nicknames: [])
        XCTAssertFalse(HighSchoolCareerStore.recapDeservesReview(
            record, pledgeAchieved: false, previousBestEvaluation: 70
        ))
    }

    /// 약속을 지켰으면 결과와 무관하게 만족 지점이다.
    func testKeptPledgeDeservesReview() {
        let record = Self.record(drafted: false, evaluation: 30, nicknames: [])
        XCTAssertTrue(HighSchoolCareerStore.recapDeservesReview(
            record, pledgeAchieved: true, previousBestEvaluation: 70
        ))
    }

    private static func record(
        drafted: Bool, evaluation: Int, nicknames: [String]?
    ) -> HighSchoolCareerStore.LifeRecord {
        var record = HighSchoolCareerStore.LifeRecord(
            lifeNumber: 2,
            playerName: "테스트",
            schoolName: "테스트고",
            drafted: drafted,
            evaluationScore: evaluation,
            teamName: drafted ? "테스트 구단" : nil,
            memories: [],
            games: 6,
            strikeouts: 30,
            walks: 8,
            runsAllowed: 5,
            soulPoints: 40
        )
        record.nicknames = nicknames
        return record
    }
}
