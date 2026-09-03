import XCTest
import SimulationCore
@testable import BaseballIOS

/// 프로 화면은 인자를 직접 넘기지 않고 Presentation 헬퍼만 부른다.
/// 카탈로그 placeholder와의 맞춤은 헬퍼를 실제로 호출해 지킨다.
final class CopyCallerContractTests: XCTestCase {
    private var catalogs: [AppLanguage: [String: String]] = [:]

    override func setUpWithError() throws {
        catalogs = try loadProductionCatalogs()
    }

    func testSettlementTitlesMatchCatalogPlaceholdersInEveryLanguage() throws {
        for language in AppLanguage.allCases {
            let resolver = resolver(language: language)
            XCTAssertEqual(
                GameCopyResolver.placeholderKinds(in: catalogs[language]?["pro.settlement.title"] ?? ""),
                ["integer"]
            )
            XCTAssertNotEqual(
                ProSeasonSettlementCopy.title(arcTitleID: nil, season: 1, resolver: resolver),
                GameCopyResolver.unavailableText
            )

            for arcID in [
                "pro.arc.first_half_ace",
                "pro.arc.dominant",
                "pro.arc.long_tunnel",
                "pro.arc.late_recovery",
                "pro.arc.autumn_door_closed",
                "pro.arc.autumn_champion",
                "pro.arc.autumn_runner_up",
                "pro.arc.autumn_eliminated",
                "pro.arc.autumn_unavailable",
                "pro.arc.quiet",
            ] {
                let key = try XCTUnwrap(ProSeasonSettlementCopy.arcTitleKey(arcID))
                XCTAssertEqual(
                    GameCopyResolver.placeholderKinds(in: catalogs[language]?[key.rawValue] ?? ""),
                    [],
                    "\(language) \(key.rawValue) must stay a finished sentence"
                )
                let title = ProSeasonSettlementCopy.title(arcTitleID: arcID, season: 1, resolver: resolver)
                XCTAssertNotEqual(title, GameCopyResolver.unavailableText, "\(language) \(arcID)")
                XCTAssertNotEqual(
                    title,
                    ProSeasonSettlementCopy.title(arcTitleID: nil, season: 1, resolver: resolver),
                    "아크 제목이 기본 시즌 결산 문구로 떨어지면 안 된다: \(title)"
                )
            }
        }
    }

    func testProFeatureHelpersResolveDeclaredArgumentsInEveryLanguage() {
        let settlement = ProSeasonSettlement(
            id: "settlement-contract",
            season: 1,
            teamID: "daegu-forge",
            stats: ProSeasonStats(season: 1, teamID: "daegu-forge", games: 20, inningsOuts: 18, strikeouts: 80),
            salaryIncome: 60_000_000,
            merchandiseIncome: 12_000_000,
            fanBefore: 40,
            fanAfter: 48,
            teamLegacyBefore: 10,
            teamLegacyAfter: 14,
            hallOfFameBefore: 20,
            hallOfFameAfter: 24,
            contractYearsBefore: 3,
            contractYearsAfter: 2,
            nextRoute: .underContract
        )

        for language in AppLanguage.allCases {
            let resolver = resolver(language: language)
            let resolved = [
                ProSeasonSettlementCopy.title(arcTitleID: nil, season: 1, resolver: resolver),
                ProSeasonSettlementCopy.stats(settlement, resolver: resolver),
                ProSeasonSettlementCopy.saber(settlement, resolver: resolver),
                ProSeasonSettlementCopy.legacy(settlement, resolver: resolver),
                ProSeasonSettlementCopy.hallOfFame(settlement, resolver: resolver),
                ProSeasonSettlementCopy.contract(settlement, resolver: resolver),
                ProSeasonSettlementCopy.nextRoute(.underContract, resolver: resolver),
                ProSeasonSettlementCopy.salary(amount: settlement.salaryIncome, resolver: resolver),
                ProSeasonSettlementCopy.fan(settlement, resolver: resolver),
                ProSeasonSettlementCopy.fanDelta(settlement.fanDelta, resolver: resolver),
                ProSeasonSettlementCopy.merchandise(amount: settlement.merchandiseIncome, resolver: resolver),
                ProSeasonSettlementCopy.merchandiseTier("regular", resolver: resolver),
                ProContractCopy.team("대구 포지", resolver: resolver),
                ProContractCopy.draftRound(2, resolver: resolver),
                ProContractCopy.draftPick(18, resolver: resolver),
                ProContractCopy.duration(years: 3, resolver: resolver),
                ProContractCopy.rolePromise("선발", resolver: resolver),
                ProContractCopy.expectation(kindName: "이닝", target: 140, difficultyName: "표준", resolver: resolver),
                ProContractCopy.outlook("기회", resolver: resolver),
                ProContractCopy.legacyImpact("유지", resolver: resolver),
                ProContractCopy.remaining(years: 2, resolver: resolver),
                ProContractCopy.confirmation(teamName: "대구 포지", years: 3, isTransfer: false, resolver: resolver),
                ProWeeklyCopy.blueprint("강속구", resolver: resolver),
                ProWeeklyCopy.rolePromise("선발", resolver: resolver),
                ProWeeklyCopy.standingSchedule(roleName: "선발", remainingOutings: 8, resolver: resolver),
                ProWeeklyCopy.routine(arcName: "신인", roleName: "선발", resolver: resolver),
                ProWeeklyCopy.pitchLearningTitle("슬라이더", resolver: resolver),
                ProWeeklyCopy.pitchLearningProgress(practiceCredits: 1, qualityUses: 2, resolver: resolver),
                ProWeeklyCopy.planUntil("전반기", resolver: resolver),
                ProOffseasonCopy.openMarketServiceLocked(service: 3, resolver: resolver),
                ProOffseasonCopy.eyebrow(season: 2, age: 21, resolver: resolver),
                ProOffseasonCopy.years(3, resolver: resolver),
                ProOffseasonCopy.seasons(2, resolver: resolver),
                ProOffseasonCopy.renewalDetail(teamName: "대구 포지", resolver: resolver),
                ProOffseasonCopy.activeContractDetail(teamName: "대구 포지", years: 2, resolver: resolver),
                ProOffseasonCopy.continueDetail(teamName: "대구 포지", resolver: resolver),
                ProOffseasonCopy.confirmRetireMessage(seasons: 8, resolver: resolver),
                ProOffseasonCopy.confirmMilitaryMessage(ageAfter: 23, resolver: resolver),
                ProOffseasonCopy.confirmContinueMessage(teamName: "대구 포지", nextSeason: 3, resolver: resolver),
                ProOffseasonCopy.investmentDetail(nextSeason: 3, resolver: resolver),
                ProOffseasonCopy.investmentFunds(available: 80_000_000, resolver: resolver),
                ProOffseasonCopy.investmentCost(amount: 20_000_000, resolver: resolver),
                ProOffseasonCopy.investmentBenefit("회복", resolver: resolver),
                ProOffseasonCopy.investmentDuration("한 시즌", resolver: resolver),
                ProOffseasonCopy.investmentConfirmMessage(choice: "불펜", benefit: "회복", resolver: resolver),
                ProOffseasonCopy.pitchLabBenefit(focusTitle: "구위", resolver: resolver),
                ProInjuryCopy.title(recoveryWeeks: 3, resolver: resolver),
                ProInjuryCopy.body(season: 2, week: 8, resolver: resolver),
                ProInjuryCopy.plan("회복", resolver: resolver),
                ProInjuryCopy.evidence(rawFatigue: 70, effectiveFatigue: 64, pitches: 28, resolver: resolver),
                ProRetirementCopy.eyebrow(age: 36, seasons: 14, resolver: resolver),
                ProRetirementCopy.confirmMessage(seasons: 14, resolver: resolver),
                ProRetirementCopy.previewScore(88, resolver: resolver),
                ProRetirementCopy.previewRetiredNumber(lastTeamSeasons: 8, lastTeamLegacy: 40, fanSupport: 70, resolver: resolver),
                ProRetirementCopy.retiredTitle(name: "김솔", resolver: resolver),
                ProRetirementCopy.identityLine(teamName: "대구 포지", seasons: 14, resolver: resolver),
                ProRetirementCopy.finalScore(91, resolver: resolver),
                ProRetirementCopy.soulPoints(12, resolver: resolver),
                ProRetirementCopy.confirmNewPlayer(name: "김솔", isLegacy: false, resolver: resolver),
                ProRetirementCopy.honorScore(91, resolver: resolver),
                ProRetirementCopy.honorTeam("대구 포지", resolver: resolver),
                ProRetirementCopy.honorValue("1억 원", resolver: resolver),
                ProDecisionCopy.eyebrow(season: 2, week: 12, resolver: resolver),
                ProDecisionCopy.confirmMessage(detail: "선택", effect: "효과", timing: "즉시", resolver: resolver),
                ProDecisionCopy.summaryLine(season: 2, week: 12, effect: "효과", resolver: resolver),
                ProImportantGameCopy.eyebrow(season: 1, week: 6, resolver: resolver),
                ProCareerPresentation.weekSpanLabel(beforeWeek: 0, afterWeek: 0, resolver: resolver),
                ProCareerPresentation.weekSpanLabel(beforeWeek: 2, afterWeek: 3, resolver: resolver),
                ProCareerPresentation.weekSpanLabel(beforeWeek: 0, afterWeek: 3, resolver: resolver),
                ProRoleRequestCopy.outlook(.likely, resolver: resolver),
                ProWeeklyCopy.goalBoardLine(
                    ProGoalBoardRow(
                        id: "hallOfFame",
                        kind: .hallOfFame,
                        titleKey: "content.goal-board.hall-of-fame.title",
                        current: 42,
                        target: 70,
                        permille: 600,
                        completed: false,
                        hintKey: "content.goal-board.hall-of-fame.hint"
                    ),
                    resolver: resolver
                ),
                ProCareerPresentation.followUpSummary(
                    ProDecisionFollowUp(
                        decisionID: "rotation_push.week3",
                        type: .rotationPush,
                        season: 1,
                        week: 6,
                        summaryKey: "content.pro-decision.followup.rotation_push",
                        qualityStarts: 2,
                        runsAllowed: 8
                    ),
                    resolver: resolver
                ),
            ]

            for text in resolved {
                XCTAssertFalse(text.isEmpty, "\(language) helper returned empty copy")
                XCTAssertNotEqual(
                    text,
                    GameCopyResolver.unavailableText,
                    "\(language) helper did not match catalog placeholders: \(text)"
                )
            }
        }
    }

    func testProFeatureViewsDoNotAssembleCopyArguments() throws {
        let directory = repositoryRoot().appendingPathComponent("apps/ios/Sources/Features/Pro")
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "swift" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        XCTAssertFalse(files.isEmpty, "Features/Pro Swift 파일이 없습니다.")

        for file in files {
            let source = try String(contentsOf: file, encoding: .utf8)
            XCTAssertFalse(
                source.contains("arguments:"),
                "\(file.lastPathComponent)가 resolve/GameCopyText에 인자를 직접 넘기고 있습니다. Presentation 헬퍼로 빼세요."
            )
        }
    }

    private func resolver(language: AppLanguage) -> GameCopyResolver {
        GameCopyResolver(language: language, catalog: catalogs, policy: .releaseSafe)
    }

    private func loadProductionCatalogs() throws -> [AppLanguage: [String: String]] {
        var result: [AppLanguage: [String: String]] = [.korean: [:], .english: [:], .japanese: [:]]
        for filename in ["Localizable.xcstrings", "GameContent.xcstrings"] {
            let url = repositoryRoot()
                .appendingPathComponent("apps/ios/Sources/Presentation/Localization/\(filename)")
            let object = try JSONSerialization.jsonObject(with: Data(contentsOf: url))
            let root = try XCTUnwrap(object as? [String: Any])
            let strings = try XCTUnwrap(root["strings"] as? [String: Any])
            for (key, raw) in strings {
                guard let entry = raw as? [String: Any],
                      let localizations = entry["localizations"] as? [String: Any] else { continue }
                if let value = stringUnit(localizations["ko"]) { result[.korean]?[key] = value }
                if let value = stringUnit(localizations["en"]) { result[.english]?[key] = value }
                if let value = stringUnit(localizations["ja"]) { result[.japanese]?[key] = value }
            }
        }
        return result
    }

    private func stringUnit(_ raw: Any?) -> String? {
        guard let localization = raw as? [String: Any],
              let unit = localization["stringUnit"] as? [String: Any] else { return nil }
        return unit["value"] as? String
    }

    private func repositoryRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
