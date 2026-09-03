import SimulationCore
import SwiftUI
import XCTest
@testable import BaseballIOS
import BaseballIOSDomain

@MainActor
final class CareerShareCardTests: XCTestCase {
    func testFourKindsRenderAt1080By1350() throws {
        let stamp = CareerDisplayRules.ChallengeStamp(seed: "20260723", lifeNumber: 1)
        let models = [
            sample(kind: .retirement, stamp: stamp, hasMedal: true),
            sample(kind: .draft, stamp: stamp, hasMedal: false),
            sample(kind: .record, stamp: stamp, hasMedal: false),
            sample(kind: .national, stamp: stamp, hasMedal: true),
        ]
        let directory = shareDirectory()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        for model in models {
            let image = try XCTUnwrap(
                CareerShareCardRenderer.image(for: model),
                "\(model.kind.rawValue) card did not render"
            )
            let pixelWidth = image.size.width * image.scale
            let pixelHeight = image.size.height * image.scale
            XCTAssertEqual(pixelWidth, CareerShareCardLayout.pixelWidth, accuracy: 0)
            XCTAssertEqual(pixelHeight, CareerShareCardLayout.pixelHeight, accuracy: 0)
            let data = try XCTUnwrap(image.pngData())
            XCTAssertFalse(data.isEmpty)
            let url = directory.appendingPathComponent("sample-\(model.kind.rawValue).png")
            try data.write(to: url)
            print("SHARE_CARD \(url.path) px=\(pixelWidth)x\(pixelHeight)")
        }
    }

    func testMaximalContentFits1080By1350Canvas() throws {
        let stamp = CareerDisplayRules.ChallengeStamp(seed: "20260723", lifeNumber: 1)
        let directory = shareDirectory()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for kind in CareerShareCardKind.allCases {
            let model = maximal(kind: kind, stamp: stamp)
            XCTAssertEqual(CareerShareCardLayout.gridStats(model.stats).count, 4)
            XCTAssertNotNil(CareerShareCardLayout.fifthStat(model.stats))
            XCTAssertEqual(CareerShareCardLayout.visibleBadges(model.badges).count, 4)
            XCTAssertEqual(CareerShareCardLayout.visibleBadges(model.badges).last, "+1")

            let unconstrained = try XCTUnwrap(
                CareerShareCardRenderer.unconstrainedPixelSize(for: model),
                "\(kind.rawValue) unconstrained render failed"
            )
            XCTAssertLessThanOrEqual(
                unconstrained.width,
                CareerShareCardLayout.pixelWidth,
                "\(kind.rawValue) width \(unconstrained.width) exceeds canvas"
            )
            XCTAssertLessThanOrEqual(
                unconstrained.height,
                CareerShareCardLayout.pixelHeight,
                "\(kind.rawValue) height \(unconstrained.height) exceeds canvas"
            )

            let image = try XCTUnwrap(
                CareerShareCardRenderer.image(for: model),
                "\(kind.rawValue) maximal card did not render"
            )
            let pixelWidth = image.size.width * image.scale
            let pixelHeight = image.size.height * image.scale
            XCTAssertEqual(pixelWidth, CareerShareCardLayout.pixelWidth, accuracy: 0)
            XCTAssertEqual(pixelHeight, CareerShareCardLayout.pixelHeight, accuracy: 0)
            let data = try XCTUnwrap(image.pngData())
            try data.write(to: directory.appendingPathComponent("maximal-\(kind.rawValue).png"))
            print(
                "SHARE_CARD_MAX \(kind.rawValue) unconstrained=\(unconstrained.width)x\(unconstrained.height)"
            )
        }
    }

    func testShareCardsFromRealisticModelsWritePNGs() throws {
        let resolver = GameCopyResolver(language: .korean, policy: .releaseSafe)
        let directory = shareDirectory()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let highSchool = HighSchoolCareerStore(saveWriter: { _ in true })
        XCTAssertTrue(highSchool.installDraftShareFixtureForUITesting())
        let draftState = try XCTUnwrap(highSchool.state)
        let draftResult = try XCTUnwrap(draftState.draftResult)
        let draft = CareerSharePresentation.draft(
            result: draftResult,
            state: draftState,
            resolver: resolver
        )
        XCTAssertEqual(draft.playerName, "박하준")
        XCTAssertEqual(draft.headline, resolver.resolve(ShareUICopyKey.headlineDraft))
        XCTAssertNotEqual(draft.headline, CareerShareCardKind.draft.rawValue)
        XCTAssertEqual(draftResult.round, 1)
        XCTAssertEqual(draftResult.overallPick, 4)
        XCTAssertEqual(draftResult.team?.id, "busan_marines")
        XCTAssertLessThanOrEqual(draft.stats.count, CareerShareCardLayout.maxStats)
        XCTAssertTrue(draft.badges.contains { $0.contains("84") })
        XCTAssertFalse(draft.stats.contains { $0.label == "승-패-세이브" })
        try writeSharePNG(draft, to: directory.appendingPathComponent("draft.png"))

        let recordStore = MobileCareerStore(saveWriter: { _ in true }, configuration: .journeyV1Tests)
        XCTAssertTrue(recordStore.installRecordShareFixtureForUITesting())
        XCTAssertEqual(recordStore.state?.phase, .weeklyPlan)
        let recordState = try XCTUnwrap(recordStore.state)
        let stamp = CareerDisplayRules.challengeStamp(
            highSchoolCareerID: "career-20260723-life-1"
        )
        let milestone = try XCTUnwrap(
            CareerSharePresentation.recordMilestone(
                state: recordState,
                stamp: stamp,
                resolver: resolver
            )
        )
        XCTAssertEqual(milestone.playerName, "김도윤")
        XCTAssertEqual(milestone.headline, resolver.resolve(ShareUICopyKey.headlineRecord))
        XCTAssertNotEqual(milestone.headline, CareerShareCardKind.record.rawValue)
        XCTAssertTrue(milestone.detail.contains("200") || milestone.badges.contains { $0.contains("200") })
        try writeSharePNG(milestone, to: directory.appendingPathComponent("record.png"))

        let followUp = try XCTUnwrap(recordState.resolvedFollowUps?.first)
        let qs = try XCTUnwrap(
            CareerSharePresentation.recordQS(
                followUp: followUp,
                state: recordState,
                stamp: stamp,
                resolver: resolver
            )
        )
        XCTAssertEqual(qs.headline, resolver.resolve(ShareUICopyKey.headlineRecord))
        XCTAssertEqual(qs.stats.first?.value, "3")

        let nationalStore = MobileCareerStore(saveWriter: { _ in true }, configuration: .journeyV1Tests)
        XCTAssertTrue(nationalStore.installNationalShareFixtureForUITesting())
        let nationalState = try XCTUnwrap(nationalStore.state)
        let tournament = try XCTUnwrap(nationalState.nationalTournament)
        let national = CareerSharePresentation.national(
            state: nationalState,
            tournament: tournament,
            stamp: stamp,
            resolver: resolver
        )
        XCTAssertEqual(national.playerName, "이시우")
        XCTAssertEqual(national.headline, resolver.resolve(ShareUICopyKey.headlineNational))
        XCTAssertNotEqual(national.headline, CareerShareCardKind.national.rawValue)
        XCTAssertTrue(national.hasMedal)
        XCTAssertTrue(tournament.exempted)
        XCTAssertFalse(national.stats.contains { $0.label.contains("처리됐습니다") })
        XCTAssertTrue(national.stats.contains { $0.label == resolver.resolve(ShareUICopyKey.nationalExempted) })
        try writeSharePNG(national, to: directory.appendingPathComponent("national.png"))
    }

    func testRetirementCardTitleIsPlayerNameNotKindLabel() throws {
        let result = try CareerBootstrap.startCareer(
            preset: PitcherPresetCatalog.all[0],
            playerName: "민서준",
            seed: 202_607_23
        )
        let resolver = GameCopyResolver(language: .korean, policy: .releaseSafe)
        let model = CareerSharePresentation.retirement(
            state: result.snapshot,
            stamp: CareerDisplayRules.ChallengeStamp(seed: "20260723", lifeNumber: 1),
            resolver: resolver
        )
        XCTAssertEqual(model.playerName, result.snapshot.identity.name)
        XCTAssertEqual(model.playerName, "민서준")
        XCTAssertEqual(model.headline, resolver.resolve(ShareUICopyKey.headlineRetirement))
        XCTAssertEqual(model.headline, "은퇴")
        XCTAssertEqual(model.stats.count, 5)
        XCTAssertEqual(model.stats[4].label, resolver.resolve(ShareUICopyKey.retirementSeasonsWARLabel))
        XCTAssertTrue(model.stats[4].value.contains("·"))
        XCTAssertNotEqual(model.playerName, model.headline)
        XCTAssertNotEqual(model.playerName, resolver.resolve(ShareUICopyKey.previewTitle))
        XCTAssertNotEqual(model.playerName, resolver.resolve(ShareUICopyKey.action))
    }

    func testShareTextIncludesChallengeCodeAndStoreLinkInEveryLanguage() {
        let stamp = CareerDisplayRules.ChallengeStamp(seed: "20260723", lifeNumber: 2)
        let model = sample(kind: .retirement, stamp: stamp, hasMedal: true)
        for language in AppLanguage.allCases {
            let resolver = GameCopyResolver(language: language, policy: .releaseSafe)
            let body = CareerShareCopy.body(for: model, resolver: resolver)
            XCTAssertTrue(body.contains("20260723-2"), "\(language): \(body)")
            XCTAssertTrue(body.contains(CareerShareCopy.storeURL), "\(language): \(body)")
            XCTAssertTrue(
                body.contains("yagurebirth://challenge/20260723-2")
                    || body.contains("https://"),
                "\(language): \(body)"
            )
            XCTAssertTrue(
                body.contains("도전 코드")
                    || body.contains("Challenge code")
                    || body.contains("チャレンジコード"),
                "\(language): \(body)"
            )
            XCTAssertTrue(
                body.contains("도전 링크")
                    || body.contains("Challenge link")
                    || body.contains("チャレンジリンク"),
                "\(language): \(body)"
            )
        }
    }

    func testShareTextUsesSchemeLinkWhenChallengeHostIsEmpty() {
        let stamp = CareerDisplayRules.ChallengeStamp(seed: "20260723", lifeNumber: 2)
        let model = sample(kind: .retirement, stamp: stamp, hasMedal: true)
        let resolver = GameCopyResolver(language: .korean, policy: .releaseSafe)
        let emptyHost = CareerSharePresentation.shareText(
            for: model,
            resolver: resolver,
            host: nil
        )
        XCTAssertTrue(emptyHost.contains("20260723-2"), emptyHost)
        XCTAssertTrue(emptyHost.contains("yagurebirth://challenge/20260723-2"), emptyHost)
        XCTAssertTrue(emptyHost.contains(CareerShareCopy.storeURL), emptyHost)

        let blankHost = CareerSharePresentation.shareText(
            for: model,
            resolver: resolver,
            host: ""
        )
        XCTAssertTrue(blankHost.contains("yagurebirth://challenge/20260723-2"), blankHost)
    }

    func testShareTextUsesUniversalLinkWhenChallengeHostIsSet() {
        let stamp = CareerDisplayRules.ChallengeStamp(seed: "20260723", lifeNumber: 2)
        let model = sample(kind: .retirement, stamp: stamp, hasMedal: true)
        let resolver = GameCopyResolver(language: .english, policy: .releaseSafe)
        let body = CareerSharePresentation.shareText(
            for: model,
            resolver: resolver,
            host: "play.example.com"
        )
        XCTAssertTrue(body.contains("20260723-2"), body)
        XCTAssertTrue(body.contains("https://play.example.com/challenge/20260723-2"), body)
        XCTAssertTrue(body.contains(CareerShareCopy.storeURL), body)
        XCTAssertFalse(body.contains("yagurebirth://"), body)
    }

    func testChallengeStampUsesExistingSeedLifeImprint() {
        let fromCareerID = CareerDisplayRules.challengeStamp(
            highSchoolCareerID: "career-20260723-life-3"
        )
        XCTAssertEqual(fromCareerID?.code, "20260723-3")
        let fallback = CareerDisplayRules.challengeStamp(
            highSchoolCareerID: nil,
            fallbackSeed: "424242"
        )
        XCTAssertEqual(fallback?.code, "424242-1")
    }

    func testAnalyticsEventNameIsStable() {
        XCTAssertEqual(GameAnalytics.Event.careerCardShared.rawValue, "career_card_shared")
    }

    private func sample(
        kind: CareerShareCardKind,
        stamp: CareerDisplayRules.ChallengeStamp,
        hasMedal: Bool
    ) -> CareerShareCardModel {
        CareerShareCardModel(
            kind: kind,
            playerName: "민서준",
            portraitSeed: "민서준",
            throwingHand: "우완",
            isPro: kind != .draft,
            headline: kind.rawValue,
            detail: "sample",
            stats: [
                CareerShareStat(label: "W-L", value: "12-8"),
                CareerShareStat(label: "K", value: "142"),
            ],
            badges: hasMedal ? ["금"] : [],
            stamp: stamp,
            summary: "민서준 sample",
            season: 8,
            hasMedal: hasMedal
        )
    }

    private func maximal(
        kind: CareerShareCardKind,
        stamp: CareerDisplayRules.ChallengeStamp
    ) -> CareerShareCardModel {
        CareerShareCardModel(
            kind: kind,
            playerName: "민서준",
            portraitSeed: "민서준",
            throwingHand: "우완",
            isPro: kind != .draft,
            headline: kind.rawValue,
            detail: "부산 블루웨일스 · 20시즌 · 결승 상대 점수 라인",
            stats: [
                CareerShareStat(label: "승-패-세이브", value: "312-198-24"),
                CareerShareStat(label: "9이닝당 실점", value: "3.00"),
                CareerShareStat(label: "탈삼진", value: "2840"),
                CareerShareStat(label: "WHIP", value: "1.06"),
                CareerShareStat(label: "시즌", value: "20"),
                CareerShareStat(label: "extra", value: "drop"),
            ],
            badges: [
                "영구결번",
                "명예의 전당",
                "국가대표 금",
                "전력의 한 축",
            ],
            stamp: stamp,
            summary: "민서준, 프로 20시즌 은퇴",
            season: 20,
            hasMedal: true
        )
    }

    private func writeSharePNG(_ model: CareerShareCardModel, to url: URL) throws {
        let image = try XCTUnwrap(
            CareerShareCardRenderer.image(for: model),
            "\(model.kind.rawValue) realistic card did not render"
        )
        let pixelWidth = image.size.width * image.scale
        let pixelHeight = image.size.height * image.scale
        XCTAssertEqual(pixelWidth, CareerShareCardLayout.pixelWidth, accuracy: 0)
        XCTAssertEqual(pixelHeight, CareerShareCardLayout.pixelHeight, accuracy: 0)
        let data = try XCTUnwrap(image.pngData())
        try data.write(to: url)
        print("SHARE_CARD_REAL \(url.path) px=\(pixelWidth)x\(pixelHeight) headline=\(model.headline)")
    }

    private func shareDirectory() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("releases/qa-1.2.9/share", isDirectory: true)
    }
}
