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
            let url = directory.appendingPathComponent("\(model.kind.rawValue).png")
            try data.write(to: url)
            print("SHARE_CARD \(url.path) px=\(pixelWidth)x\(pixelHeight)")
        }
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
                body.contains("도전 코드")
                    || body.contains("Challenge code")
                    || body.contains("チャレンジコード"),
                "\(language): \(body)"
            )
        }
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

    private func shareDirectory() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("releases/qa-1.2.9/share", isDirectory: true)
    }
}
