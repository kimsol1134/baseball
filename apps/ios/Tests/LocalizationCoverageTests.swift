import Foundation
import XCTest
import SimulationCore
@testable import BaseballIOS

final class LocalizationCoverageTests: XCTestCase {
    private struct CatalogEntry {
        let korean: String
        let english: String
    }

    private let koreanPattern = try! NSRegularExpression(pattern: "[가-힣ㄱ-ㅎㅏ-ㅣ]")

    func testProductionKeysAreSemanticAndNeverKoreanSentences() {
        for key in GameCopyKey.allCases {
            XCTAssertFalse(key.rawValue.contains(" "), key.rawValue)
            XCTAssertNil(
                koreanPattern.firstMatch(
                    in: key.rawValue,
                    range: NSRange(location: 0, length: key.rawValue.utf16.count)
                ),
                key.rawValue
            )
        }
    }

    func testP4BatchKeysAreStableSemanticIDs() {
        XCTAssertFalse(AppCopyKey.allCases.isEmpty)
        XCTAssertEqual(
            Set(AppCopyKey.allCases.map(\.rawValue)).count,
            AppCopyKey.allCases.count
        )
        XCTAssertTrue(AppCopyKey.allCases.allSatisfy { GameCopyKey.isSemanticID($0.rawValue) })
        XCTAssertTrue(AppCopyKey.allCases.allSatisfy { $0.table == .localizable })
    }

    func testPrologueKeysAreExactly31UniqueAndAppearOnceInAllCases() {
        XCTAssertEqual(AppCopyKey.prologueKeys.count, Set(AppCopyKey.prologueKeys).count)
        XCTAssertEqual(Set(AppCopyKey.prologueKeys).count, 31)

        for key in AppCopyKey.prologueKeys {
            XCTAssertEqual(
                AppCopyKey.allCases.filter { $0 == key }.count,
                1,
                key.rawValue
            )
        }
    }

    func testSemanticIDValidationRejectsEmptySegmentsAndSourceCopy() {
        XCTAssertTrue(GameCopyKey.isSemanticID("content.school.hanbit_traditional.name"))
        XCTAssertFalse(GameCopyKey.isSemanticID("content..school"))
        XCTAssertFalse(GameCopyKey.isSemanticID("content.school-"))
        XCTAssertFalse(GameCopyKey.isSemanticID("Content.school.name"))
        XCTAssertFalse(GameCopyKey.isSemanticID("학교.이름"))
    }

    func testTypedTokenResolvesEnglishWithoutKoreanLookup() {
        let resolver = GameCopyResolver(
            language: .english,
            catalog: [
                .english: [
                    GameCopyKey.actionNext.rawValue: "Next",
                    GameCopyKey.accessibilityStatLine.rawValue: "Week %lld, %@, %@, %@",
                ],
                .korean: [
                    GameCopyKey.actionNext.rawValue: "다음",
                    GameCopyKey.accessibilityStatLine.rawValue: "%lld주차, %@, %@, %@",
                ],
            ]
        )

        XCTAssertEqual(resolver.resolve(.actionNext), "Next")
        XCTAssertEqual(
            resolver.resolve(
                .accessibilityStatLine,
                arguments: [.integer(12), .userText("6⅔ IP"), .userText("7K"), .userText("2.84 RA9")]
            ),
            "Week 12, 6⅔ IP, 7K, 2.84 RA9"
        )
    }

    func testReleaseSafeMissingEnglishCopyNeverReturnsKorean() {
        let resolver = GameCopyResolver(
            language: .english,
            catalog: [.korean: [GameCopyKey.actionClose.rawValue: "닫기"]],
            policy: .releaseSafe
        )

        XCTAssertEqual(resolver.resolve(.actionClose), GameCopyResolver.unavailableText)
        XCTAssertFalse(resolver.resolve(.actionClose).contains("닫기"))
    }

    func testP4BatchEnglishNeverFallsBackToKorean() {
        let resolver = GameCopyResolver(
            language: .english,
            catalog: [
                .korean: [
                    AppCopyKey.openingSummary.rawValue: "당신은 고교 투수입니다.\n3년 안에 프로 지명을 받아야 합니다.",
                ],
            ],
            policy: .releaseSafe
        )

        XCTAssertEqual(
            resolver.resolve(AppCopyKey.openingSummary),
            GameCopyResolver.unavailableText
        )
        XCTAssertFalse(resolver.resolve(AppCopyKey.openingSummary).contains("고교"))
    }

    func testAwakeningContentCatalogHasExactKoreanParityAndCompleteEnglishCoverage() throws {
        let entries = try gameContentEntries()
        let awakeningDescriptors = CopyToken.awakeningDescriptors
        let branchDescriptors = CopyToken.awakeningBranchDescriptors
        let expectedAwakeningKeys = Set(
            awakeningDescriptors.flatMap { [$0.titleToken.key, $0.detailToken.key] }
        )
        let expectedBranchKeys = Set(
            branchDescriptors.flatMap { [$0.titleToken.key, $0.detailToken.key] }
        )
        XCTAssertEqual(expectedAwakeningKeys.count, 36)
        XCTAssertEqual(expectedBranchKeys.count, 8)
        XCTAssertEqual(
            Set(entries.keys.filter { $0.hasPrefix("content.awakening.") }),
            expectedAwakeningKeys
        )
        XCTAssertEqual(
            Set(entries.keys.filter { $0.hasPrefix("content.awakening-branch.") }),
            expectedBranchKeys
        )

        let koreanCatalog = Dictionary(uniqueKeysWithValues: entries.map { ($0.key, $0.value.korean) })
        let englishCatalog = Dictionary(uniqueKeysWithValues: entries.map { ($0.key, $0.value.english) })
        let koreanResolver = GameCopyResolver(
            language: .korean,
            catalog: [.korean: koreanCatalog, .english: englishCatalog],
            policy: .releaseSafe
        )
        let englishResolver = GameCopyResolver(
            language: .english,
            catalog: [.korean: koreanCatalog, .english: englishCatalog],
            policy: .releaseSafe
        )

        for descriptor in awakeningDescriptors {
            let expected = HighSchoolPresentation.awakening(descriptor.id)
            let title = try XCTUnwrap(entries[descriptor.titleToken.key], descriptor.titleToken.key)
            let detail = try XCTUnwrap(entries[descriptor.detailToken.key], descriptor.detailToken.key)
            XCTAssertEqual(title.korean, expected.title, descriptor.titleToken.key)
            XCTAssertEqual(detail.korean, expected.detail, descriptor.detailToken.key)
            XCTAssertFalse(title.english.isEmpty, descriptor.titleToken.key)
            XCTAssertFalse(detail.english.isEmpty, descriptor.detailToken.key)
            assertNoHangul(title.english, descriptor.titleToken.key)
            assertNoHangul(detail.english, descriptor.detailToken.key)
            XCTAssertEqual(
                GameCopyResolver.placeholderKinds(in: title.korean),
                GameCopyResolver.placeholderKinds(in: title.english),
                descriptor.titleToken.key
            )
            XCTAssertEqual(
                GameCopyResolver.placeholderKinds(in: detail.korean),
                GameCopyResolver.placeholderKinds(in: detail.english),
                descriptor.detailToken.key
            )
            XCTAssertEqual(koreanResolver.resolve(descriptor.titleToken), expected.title)
            XCTAssertEqual(koreanResolver.resolve(descriptor.detailToken), expected.detail)
            XCTAssertEqual(englishResolver.resolve(descriptor.titleToken), title.english)
            XCTAssertEqual(englishResolver.resolve(descriptor.detailToken), detail.english)
        }

        for descriptor in branchDescriptors {
            let expected = descriptor.branch
            let title = try XCTUnwrap(entries[descriptor.titleToken.key], descriptor.titleToken.key)
            let detail = try XCTUnwrap(entries[descriptor.detailToken.key], descriptor.detailToken.key)
            XCTAssertEqual(title.korean, expected.title, descriptor.titleToken.key)
            XCTAssertEqual(detail.korean, expected.detail, descriptor.detailToken.key)
            XCTAssertFalse(title.english.isEmpty, descriptor.titleToken.key)
            XCTAssertFalse(detail.english.isEmpty, descriptor.detailToken.key)
            assertNoHangul(title.english, descriptor.titleToken.key)
            assertNoHangul(detail.english, descriptor.detailToken.key)
            XCTAssertEqual(
                GameCopyResolver.placeholderKinds(in: title.korean),
                GameCopyResolver.placeholderKinds(in: title.english),
                descriptor.titleToken.key
            )
            XCTAssertEqual(
                GameCopyResolver.placeholderKinds(in: detail.korean),
                GameCopyResolver.placeholderKinds(in: detail.english),
                descriptor.detailToken.key
            )
            XCTAssertEqual(koreanResolver.resolve(descriptor.titleToken), expected.title)
            XCTAssertEqual(koreanResolver.resolve(descriptor.detailToken), expected.detail)
            XCTAssertEqual(englishResolver.resolve(descriptor.titleToken), title.english)
            XCTAssertEqual(englishResolver.resolve(descriptor.detailToken), detail.english)
        }
    }

    func testAwakeningStaticCatalogHasExactKoreanParityAndUniqueTypedKeys() throws {
        let entries = try localizableEntries()
        let expected: [GameCopyKey: String] = [
            AppCopyKey.awakeningReadOnlyEmpty: "아직 찍은 스킬이 없습니다. 다음 각성에서 네 갈래의 1단 스킬 중 하나를 고릅니다.",
            AppCopyKey.awakeningReadOnlyProgress: "찍은 스킬 %lld/%lld · 남은 선택 %lld회",
            AppCopyKey.awakeningGuide: "체크는 현재 보유, ‘다음’은 다음 각성에서 고를 수 있는 스킬입니다. 잠긴 가지에는 먼저 필요한 스킬이 표시됩니다.",
            AppCopyKey.awakeningEyebrow: "각성",
            AppCopyKey.awakeningKeyArtTitle: "몸이 하나를 기억합니다",
            AppCopyKey.awakeningCounter: "고교 3년 동안 %lld번 각성합니다 — 지금은 %lld번째입니다.",
            AppCopyKey.awakeningSelectionGuidance: "하나를 찍으면 그 갈래의 다음 가지가 열립니다. 남은 각성 %lld번 — 한 갈래를 끝까지 팔지, 여러 갈래를 나눠 가질지 고르세요.",
            AppCopyKey.awakeningSparkLeaps: "시즌의 호투가 몸을 완전히 깨웠습니다 — 한 단계를 건너뛰고 찍을 수 있습니다.",
            AppCopyKey.awakeningSparkBeforeFirstGame: "아직 증명할 무대가 없었습니다 — 순서대로만 열립니다. 마운드의 호투가 다음 각성에서 건너뛰기를 엽니다.",
            AppCopyKey.awakeningSparkNeedsProof: "전조가 부족합니다 — 이번에는 순서대로만 열립니다. 호투(무실점·삼진쇼)와 만개가 다음 각성에서 건너뛰기를 엽니다.",
            AppCopyKey.awakeningConfirmationTitle: "%@ 각성할까요?",
            AppCopyKey.awakeningConfirmationAction: "이걸로 각성한다",
            AppCopyKey.awakeningConfirmationCancel: "다시 고른다",
            AppCopyKey.awakeningConfirmationMessage: "%@ 갈래 %lld단\n%@\n\n한 번 고르면 고교 3년 동안 바꿀 수 없습니다.",
            AppCopyKey.awakeningBranchTitle: "%@ 갈래",
            AppCopyKey.awakeningBranchSelectedCount: "%lld개 찍음",
            AppCopyKey.awakeningTierLabel: "%lld단",
            AppCopyKey.awakeningLeapLabel: "건너뛰기",
            AppCopyKey.awakeningNextLabel: "다음",
            AppCopyKey.awakeningSelectLabel: "찍기",
            AppCopyKey.awakeningLockReason: "먼저 '%@'을(를) 찍어야 열립니다.",
            AppCopyKey.awakeningNodeVoiceOwned: "%@ 갈래 %lld단, %@, 이미 찍음",
            AppCopyKey.awakeningNodeVoiceAvailableNow: "%@ 갈래 %lld단, %@, %@, 지금 찍을 수 있음",
            AppCopyKey.awakeningNodeVoiceAvailableNext: "%@ 갈래 %lld단, %@, %@, 다음 각성에서 선택 가능",
            AppCopyKey.awakeningNodeVoiceLocked: "%@ 갈래 %lld단, %@, 잠김. %@",
            AppCopyKey.awakeningSummaryTitle: "스킬트리 · %lld/%lld",
            AppCopyKey.awakeningSummaryEmpty: "아직 찍은 스킬 없음 · 다음 경로 확인",
            AppCopyKey.awakeningSheetTitle: "내 스킬트리",
            AppCopyKey.awakeningSheetDone: "완료",
        ]
        XCTAssertEqual(Set(expected.keys), Set(AppCopyKey.awakeningKeys))
        XCTAssertEqual(expected.count, AppCopyKey.awakeningKeys.count)
        let uniqueAwakeningKeys = AppCopyKey.awakeningKeys.filter { key in
            AppCopyKey.allCases.filter { $0 == key }.count == 1
        }
        XCTAssertEqual(uniqueAwakeningKeys.count, AppCopyKey.awakeningKeys.count)

        for key in AppCopyKey.awakeningKeys {
            let entry = try XCTUnwrap(entries[key.rawValue], key.rawValue)
            XCTAssertEqual(entry.korean, expected[key], key.rawValue)
            XCTAssertFalse(entry.english.isEmpty, key.rawValue)
            assertNoHangul(entry.english, key.rawValue)
            XCTAssertEqual(
                GameCopyResolver.placeholderKinds(in: entry.korean),
                GameCopyResolver.placeholderKinds(in: entry.english),
                key.rawValue
            )
            XCTAssertEqual(key.table, .localizable, key.rawValue)
        }
    }

    func testAwakeningEnglishPresentationRepresentativeOutputAndSignedModifiers() throws {
        let entries = try allLocalizationEntries()
        let englishCatalog = Dictionary(uniqueKeysWithValues: entries.map { ($0.key, $0.value.english) })
        let resolver = GameCopyResolver(
            language: .english,
            catalog: [.english: englishCatalog],
            policy: .releaseSafe
        )

        XCTAssertEqual(
            entries["awakening.spark.needs-proof"]?.english,
            "You have not earned a skip yet — nodes unlock in order for now. Strong outings (scoreless frames and strikeout shows) and talent breakthroughs can unlock a one-tier skip at the next awakening."
        )
        XCTAssertEqual(
            entries["content.awakening.scout_composure.detail"]?.korean,
            "구위·제구 +2 · 체력 -1"
        )
        XCTAssertEqual(
            entries["content.awakening.scout_composure.detail"]?.english,
            "Stuff and Control +2 · Stamina -1"
        )

        XCTAssertEqual(
            HighSchoolPresentation.localizedAwakeningCounter(total: 3, current: 2, resolver: resolver),
            "You get 3 awakenings across high school — this is awakening 2."
        )
        XCTAssertEqual(
            HighSchoolPresentation.localizedAwakeningReadOnlySummary(
                selectedCount: 0,
                total: 3,
                resolver: resolver
            ),
            "No skills selected yet. At the next awakening, choose one Tier 1 skill from any of the four branches."
        )
        XCTAssertEqual(
            HighSchoolPresentation.localizedAwakeningReadOnlySummary(
                selectedCount: 1,
                total: 3,
                resolver: resolver
            ),
            "1/3 skills chosen · 2 choices left"
        )
        XCTAssertEqual(
            HighSchoolPresentation.localizedAwakeningSpark(
                sparks: AwakeningTree.leapSparks,
                beforeFirstGame: false,
                resolver: resolver
            ).text,
            "A strong season has unlocked a one-tier skip — you can take a node one tier ahead."
        )
        XCTAssertEqual(
            HighSchoolPresentation.localizedAwakeningSpark(
                sparks: 0,
                beforeFirstGame: true,
                resolver: resolver
            ).text,
            "You have not had a game to prove yourself yet — nodes unlock in order. A strong outing can unlock a one-tier skip at the next awakening."
        )
        XCTAssertEqual(
            HighSchoolPresentation.localizedAwakeningSpark(
                sparks: 0,
                beforeFirstGame: false,
                resolver: resolver
            ).text,
            "You have not earned a skip yet — nodes unlock in order for now. Strong outings (scoreless frames and strikeout shows) and talent breakthroughs can unlock a one-tier skip at the next awakening."
        )
        XCTAssertEqual(
            HighSchoolPresentation.localizedAwakeningBranchTitle(.power, resolver: resolver),
            "Power"
        )
        XCTAssertEqual(
            HighSchoolPresentation.localizedAwakeningBranchDetail(.game, resolver: resolver),
            "Read the hitter. Manage runners and counts to keep runs off the board."
        )

        let root = AwakeningTree.node(.explosiveFastball)
        let next = AwakeningTree.node(.risingFourSeam)
        XCTAssertEqual(
            HighSchoolPresentation.localizedAwakeningNodeVoiceLabel(
                root,
                owned: true,
                open: false,
                readOnly: false,
                selected: [root.id],
                resolver: resolver
            ),
            "Power branch, Tier 1, Explosive Four-Seam, owned."
        )
        XCTAssertEqual(
            HighSchoolPresentation.localizedAwakeningNodeVoiceLabel(
                root,
                owned: false,
                open: true,
                readOnly: false,
                selected: [],
                resolver: resolver
            ),
            "Power branch, Tier 1, Explosive Four-Seam, Stuff +4 · Control -2 · More Four-Seam velocity and whiffs, available now."
        )
        XCTAssertEqual(
            HighSchoolPresentation.localizedAwakeningNodeVoiceLabel(
                next,
                owned: false,
                open: true,
                readOnly: true,
                selected: [root.id],
                resolver: resolver
            ),
            "Power branch, Tier 2, Rising Four-Seam, More Four-Seam life and whiffs · Breaking Ball -1, available at the next awakening."
        )
        XCTAssertEqual(
            HighSchoolPresentation.localizedAwakeningLockReason(next, selected: [], resolver: resolver),
            "Take 'Explosive Four-Seam' first to unlock this node."
        )
        XCTAssertEqual(
            HighSchoolPresentation.localizedAwakeningConfirmationTitle(root.id, resolver: resolver),
            "Choose 'Explosive Four-Seam' as your awakening?"
        )
        XCTAssertEqual(
            HighSchoolPresentation.localizedAwakeningConfirmationMessage(root.id, resolver: resolver),
            "Power branch, Tier 1\nStuff +4 · Control -2 · More Four-Seam velocity and whiffs\n\nOnce chosen, this awakening cannot be changed during your three-year high school career."
        )
        XCTAssertEqual(
            HighSchoolPresentation.localizedAwakeningSummaryTitle(
                selectedCount: 2,
                total: 3,
                resolver: resolver
            ),
            "Skill Tree · 2/3"
        )
        XCTAssertEqual(
            HighSchoolPresentation.localizedAwakeningSummaryEmpty(resolver: resolver),
            "No skills chosen yet · See your next path"
        )

        for descriptor in CopyToken.awakeningDescriptors {
            let detail = resolver.resolve(descriptor.detailToken)
            XCTAssertFalse(detail.isEmpty, descriptor.detailToken.key)
            assertNoHangul(detail, descriptor.detailToken.key)
            XCTAssertEqual(
                signedNumericModifiers(detail),
                signedNumericModifiers(HighSchoolPresentation.awakening(descriptor.id).detail),
                descriptor.detailToken.key
            )
        }
    }

    func testAwakeningEnglishMissingCopyUsesReleaseSafeNeutralFallbacks() throws {
        let contentEntries = try gameContentEntries()
        let localizable = try localizableEntries()
        let koreanCatalog = Dictionary(
            uniqueKeysWithValues: Array(contentEntries)
                .map { ($0.key, $0.value.korean) }
                + Array(localizable).map { ($0.key, $0.value.korean) }
        )
        let resolver = GameCopyResolver(
            language: .english,
            catalog: [.korean: koreanCatalog],
            policy: .releaseSafe
        )

        for key in AppCopyKey.awakeningKeys {
            XCTAssertEqual(resolver.resolve(key), GameCopyResolver.unavailableText, key.rawValue)
            assertNoHangul(resolver.resolve(key), key.rawValue)
        }
        for descriptor in CopyToken.awakeningDescriptors {
            XCTAssertEqual(resolver.resolve(descriptor.titleToken), GameCopyResolver.unavailableText, descriptor.titleToken.key)
            XCTAssertEqual(resolver.resolve(descriptor.detailToken), GameCopyResolver.unavailableText, descriptor.detailToken.key)
        }
        for descriptor in CopyToken.awakeningBranchDescriptors {
            XCTAssertEqual(resolver.resolve(descriptor.titleToken), GameCopyResolver.unavailableText, descriptor.titleToken.key)
            XCTAssertEqual(resolver.resolve(descriptor.detailToken), GameCopyResolver.unavailableText, descriptor.detailToken.key)
        }
    }

    func testP4BatchKoreanValuesKeepTheExistingMeaning() {
        let resolver = GameCopyResolver(
            language: .korean,
            catalog: [
                .korean: [
                    AppCopyKey.openingSummary.rawValue: "당신은 고교 투수입니다.\n3년 안에 프로 지명을 받아야 합니다.",
                    AppCopyKey.settingsAutoReleaseDescription.rawValue: "켜면 와인드업 타이밍 없이 탭 한 번으로 던집니다. 결과는 릴리스가 딱 중간일 때와 같습니다.",
                    AppCopyKey.returnPlanBodyPledge.rawValue: "%@ · %@ — 이어서 완성해 보세요.",
                ],
            ]
        )

        XCTAssertEqual(
            resolver.resolve(AppCopyKey.openingSummary),
            "당신은 고교 투수입니다.\n3년 안에 프로 지명을 받아야 합니다."
        )
        XCTAssertEqual(
            resolver.resolve(AppCopyKey.settingsAutoReleaseDescription),
            "켜면 와인드업 타이밍 없이 탭 한 번으로 던집니다. 결과는 릴리스가 딱 중간일 때와 같습니다."
        )
        XCTAssertEqual(
            resolver.resolve(
                AppCopyKey.returnPlanBodyPledge,
                arguments: [.userText("무실점 등판 4회"), .userText("무실점 등판 2/4")]
            ),
            "무실점 등판 4회 · 무실점 등판 2/4 — 이어서 완성해 보세요."
        )
    }

    func testHighSchoolSetupCatalogHasKoreanParityAndPlaceholderParityForEveryNewKey() throws {
        let entries = try localizableEntries()
        let expectedKeys = Set(AppCopyKey.highSchoolSetupKeys.map(\.rawValue))
        XCTAssertEqual(expectedKeys.count, AppCopyKey.highSchoolSetupKeys.count)
        XCTAssertEqual(
            expectedKeys,
            Set(expectedHighSchoolSetupKoreanCopy().keys.map(\.rawValue))
        )

        for key in AppCopyKey.highSchoolSetupKeys {
            let entry = try XCTUnwrap(entries[key.rawValue], key.rawValue)
            XCTAssertFalse(entry.korean.isEmpty, key.rawValue)
            XCTAssertFalse(entry.english.isEmpty, key.rawValue)
            XCTAssertEqual(
                GameCopyResolver.placeholderKinds(in: entry.korean),
                GameCopyResolver.placeholderKinds(in: entry.english),
                key.rawValue
            )
            XCTAssertNil(
                koreanPattern.firstMatch(
                    in: entry.english,
                    range: NSRange(location: 0, length: entry.english.utf16.count)
                ),
                key.rawValue
            )
            XCTAssertEqual(entry.korean, expectedHighSchoolSetupKoreanCopy()[key], key.rawValue)
        }
    }

    func testHighSchoolSetupEnglishNeverFallsBackToKoreanForEveryNewKey() throws {
        let entries = try localizableEntries()
        let koreanCatalog = Dictionary(uniqueKeysWithValues: AppCopyKey.highSchoolSetupKeys.map { key in
            (key.rawValue, entries[key.rawValue]!.korean)
        })
        let resolver = GameCopyResolver(
            language: .english,
            catalog: [.korean: koreanCatalog],
            policy: .releaseSafe
        )

        for key in AppCopyKey.highSchoolSetupKeys {
            let resolved = resolver.resolve(key)
            XCTAssertEqual(resolved, GameCopyResolver.unavailableText, key.rawValue)
            XCTAssertNil(
                koreanPattern.firstMatch(
                    in: resolved,
                    range: NSRange(location: 0, length: resolved.utf16.count)
                ),
                key.rawValue
            )
        }
    }

    func testHighSchoolSetupTypedArgumentsPreservePlayerNamesVerbatim() throws {
        let entries = try localizableEntries()
        let resolver = GameCopyResolver(
            language: .english,
            catalog: [
                .korean: Dictionary(uniqueKeysWithValues: entries.map { ($0.key, $0.value.korean) }),
                .english: Dictionary(uniqueKeysWithValues: entries.map { ($0.key, $0.value.english) }),
            ],
            policy: .releaseSafe
        )
        for playerName in ["김솔", "José O’Neil", "⚾️✨"] {
            let suggestion = resolver.resolve(
                AppCopyKey.setupNameSuggestionAction,
                arguments: [.userText(playerName)]
            )
            XCTAssertTrue(suggestion.contains(playerName))

            let summary = resolver.resolve(
                AppCopyKey.setupQuickRebirthSummary,
                arguments: [.userText(playerName), .userText("Seoul")]
            )
            XCTAssertTrue(summary.contains(playerName))
            XCTAssertTrue(summary.contains("Seoul"))
        }
    }

    func testPitcherPresetCatalogHasCompleteKoreanAndEnglishSemanticCoverage() throws {
        let entries = try gameContentEntries()
        let descriptors = CopyToken.pitcherPresetDescriptors
        let expectedIDs = [
            "power_prospect",
            "precision_commander",
            "breaking_ball_artist",
            "innings_eater",
        ]
        let expectedSlots = [
            "name", "tagline", "strength.0", "strength.1", "strength.2", "tradeoff", "default-name",
        ]
        let pitcherEntries = entries.filter { $0.key.hasPrefix("content.pitcher-preset.") }

        XCTAssertEqual(PitcherPresetCatalog.all.map(\.id), expectedIDs)
        XCTAssertEqual(descriptors.count, expectedIDs.count * expectedSlots.count)
        XCTAssertEqual(Set(pitcherEntries.keys), Set(descriptors.map(\.token.key)))
        XCTAssertEqual(pitcherEntries.count, descriptors.count)

        let catalog = Dictionary(uniqueKeysWithValues: entries.map { ($0.key, $0.value.korean) })
        let englishCatalog = Dictionary(uniqueKeysWithValues: entries.map { ($0.key, $0.value.english) })
        let koreanResolver = GameCopyResolver(
            language: .korean,
            catalog: [.korean: catalog, .english: englishCatalog],
            policy: .releaseSafe
        )
        let englishResolver = GameCopyResolver(
            language: .english,
            catalog: [.korean: catalog, .english: englishCatalog],
            policy: .releaseSafe
        )

        for preset in PitcherPresetCatalog.all {
            let expectedKorean: [String: String] = [
                "name": preset.name,
                "tagline": preset.tagline,
                "strength.0": preset.strengths[0],
                "strength.1": preset.strengths[1],
                "strength.2": preset.strengths[2],
                "tradeoff": preset.tradeoff,
                "default-name": preset.pitcher.name,
            ]
            let presetDescriptors = descriptors.filter { $0.presetID == preset.id }
            XCTAssertEqual(presetDescriptors.map(\.slot), expectedSlots, preset.id)
            for descriptor in presetDescriptors {
                let entry = try XCTUnwrap(entries[descriptor.token.key], descriptor.token.key)
                XCTAssertEqual(entry.korean, expectedKorean[descriptor.slot], descriptor.token.key)
                XCTAssertFalse(entry.english.isEmpty, descriptor.token.key)
                XCTAssertNil(
                    koreanPattern.firstMatch(
                        in: entry.english,
                        range: NSRange(location: 0, length: entry.english.utf16.count)
                    ),
                    descriptor.token.key
                )
                XCTAssertEqual(
                    GameCopyResolver.placeholderKinds(in: entry.korean),
                    GameCopyResolver.placeholderKinds(in: entry.english),
                    descriptor.token.key
                )
                XCTAssertEqual(koreanResolver.resolve(descriptor.token), entry.korean, descriptor.token.key)
                XCTAssertEqual(englishResolver.resolve(descriptor.token), entry.english, descriptor.token.key)
            }
        }

        let expectedEnglishDefaults = [
            "power_prospect": "Min Seo-jun",
            "precision_commander": "Go Tae-yun",
            "breaking_ball_artist": "Jin Seo-yul",
            "innings_eater": "Do Ha-ram",
        ]
        for preset in PitcherPresetCatalog.all {
            XCTAssertEqual(
                englishResolver.resolve(preset.defaultPlayerNameCopyToken),
                expectedEnglishDefaults[preset.id],
                preset.id
            )
            XCTAssertEqual(
                preset.pitcher.name,
                expectedKoreanDefaultName(for: preset.id),
                preset.id
            )
        }
    }

    func testSchoolSelectionStaticCatalogHasExactKoreanCopyAndNaturalEnglish() throws {
        let entries = try localizableEntries()
        let expectedKorean: [GameCopyKey: String] = [
            AppCopyKey.schoolSelectionTitle: "어느 학교로 갈지 고르세요",
            AppCopyKey.schoolSelectionStrength: "강점 · %@",
            AppCopyKey.schoolSelectionCoach: "%@ 감독",
            AppCopyKey.schoolSelectionCatcher: "%@ 포수",
            AppCopyKey.schoolSelectionCardAccessibility: "%@. %@. 강점 · %@. %@ %@, %@. %@, %@.",
            AppCopyKey.schoolSelectionConfirmTitle: "%@로 가시겠습니까?",
            AppCopyKey.schoolSelectionConfirmAction: "이 학교로 간다",
            AppCopyKey.schoolSelectionConfirmCancel: "다시 고른다",
            AppCopyKey.schoolSelectionConfirmMessage: "강점 · %@\n%@\n\n한 번 정하면 3년 동안 바꿀 수 없습니다.",
        ]
        XCTAssertEqual(Set(expectedKorean.keys), Set(AppCopyKey.schoolSelectionKeys))

        let arguments: [GameCopyKey: [LocalizedCopyArgument]] = [
            AppCopyKey.schoolSelectionStrength: [.userText("구위")],
            AppCopyKey.schoolSelectionCoach: [.userText("윤태문")],
            AppCopyKey.schoolSelectionCatcher: [.userText("서준호")],
            AppCopyKey.schoolSelectionCardAccessibility: [
                .userText("서울덕성고"), .userText("기본기와 긴 이닝"), .userText("구위"),
                .userText("새 구종을 시험할 기회가 적습니다."), .userText("윤태문 감독"), .userText("원칙형"),
                .userText("서준호 포수"), .userText("안정형"),
            ],
            AppCopyKey.schoolSelectionConfirmTitle: [.userText("서울덕성고")],
            AppCopyKey.schoolSelectionConfirmMessage: [.userText("구위"), .userText("새 구종을 시험할 기회가 적습니다.")],
        ]
        let englishArguments: [GameCopyKey: [LocalizedCopyArgument]] = [
            AppCopyKey.schoolSelectionStrength: [.userText("Pitching stuff")],
            AppCopyKey.schoolSelectionCoach: [.userText("Yoon Tae-mun")],
            AppCopyKey.schoolSelectionCatcher: [.userText("Seo Jun-ho")],
            AppCopyKey.schoolSelectionCardAccessibility: [
                .userText("Seoul Deokseong High"), .userText("Win with fundamentals and work deep into games"), .userText("Pitching stuff"),
                .userText("Fewer chances to experiment with a new pitch."), .userText("Yoon Tae-mun, head coach"), .userText("Fundamentals-first"),
                .userText("Seo Jun-ho, catcher"), .userText("Steady hand"),
            ],
            AppCopyKey.schoolSelectionConfirmTitle: [.userText("Seoul Deokseong High")],
            AppCopyKey.schoolSelectionConfirmMessage: [.userText("Pitching stuff"), .userText("Fewer chances to experiment with a new pitch.")],
        ]
        let expectedResolvedKorean: [GameCopyKey: String] = [
            AppCopyKey.schoolSelectionTitle: "어느 학교로 갈지 고르세요",
            AppCopyKey.schoolSelectionStrength: "강점 · 구위",
            AppCopyKey.schoolSelectionCoach: "윤태문 감독",
            AppCopyKey.schoolSelectionCatcher: "서준호 포수",
            AppCopyKey.schoolSelectionCardAccessibility: "서울덕성고. 기본기와 긴 이닝. 강점 · 구위. 새 구종을 시험할 기회가 적습니다. 윤태문 감독, 원칙형. 서준호 포수, 안정형.",
            AppCopyKey.schoolSelectionConfirmTitle: "서울덕성고로 가시겠습니까?",
            AppCopyKey.schoolSelectionConfirmAction: "이 학교로 간다",
            AppCopyKey.schoolSelectionConfirmCancel: "다시 고른다",
            AppCopyKey.schoolSelectionConfirmMessage: "강점 · 구위\n새 구종을 시험할 기회가 적습니다.\n\n한 번 정하면 3년 동안 바꿀 수 없습니다.",
        ]
        let koreanCatalog = Dictionary(uniqueKeysWithValues: entries.map { ($0.key, $0.value.korean) })
        let englishCatalog = Dictionary(uniqueKeysWithValues: entries.map { ($0.key, $0.value.english) })
        let koreanResolver = GameCopyResolver(
            language: .korean,
            catalog: [.korean: koreanCatalog, .english: englishCatalog],
            policy: .releaseSafe
        )
        let englishResolver = GameCopyResolver(
            language: .english,
            catalog: [.korean: koreanCatalog, .english: englishCatalog],
            policy: .releaseSafe
        )
        let missingEnglishResolver = GameCopyResolver(
            language: .english,
            catalog: [.korean: koreanCatalog],
            policy: .releaseSafe
        )

        for key in AppCopyKey.schoolSelectionKeys {
            let entry = try XCTUnwrap(entries[key.rawValue], key.rawValue)
            XCTAssertEqual(entry.korean, expectedKorean[key], key.rawValue)
            XCTAssertFalse(entry.english.isEmpty, key.rawValue)
            XCTAssertEqual(
                GameCopyResolver.placeholderKinds(in: entry.korean),
                GameCopyResolver.placeholderKinds(in: entry.english),
                key.rawValue
            )
            XCTAssertNil(
                koreanPattern.firstMatch(
                    in: entry.english,
                    range: NSRange(location: 0, length: entry.english.utf16.count)
                ),
                key.rawValue
            )
            let resolvedKorean = koreanResolver.resolve(key, arguments: arguments[key] ?? [])
            let resolvedEnglish = englishResolver.resolve(key, arguments: englishArguments[key] ?? [])
            XCTAssertNotEqual(resolvedKorean, GameCopyResolver.unavailableText, key.rawValue)
            XCTAssertNotEqual(resolvedEnglish, GameCopyResolver.unavailableText, key.rawValue)
            XCTAssertEqual(resolvedKorean, expectedResolvedKorean[key], key.rawValue)
            XCTAssertNil(
                koreanPattern.firstMatch(
                    in: resolvedEnglish,
                    range: NSRange(location: 0, length: resolvedEnglish.utf16.count)
                ),
                key.rawValue
            )
            XCTAssertEqual(
                missingEnglishResolver.resolve(key, arguments: englishArguments[key] ?? []),
                GameCopyResolver.unavailableText,
                key.rawValue
            )
        }
    }

    func testSchoolSelectionContentHasAllRegionalNamesCastNamesAndAttributes() throws {
        let entries = try gameContentEntries()
        let contentCatalog = Dictionary(uniqueKeysWithValues: entries.map { ($0.key, $0.value.korean) })
        let englishCatalog = Dictionary(uniqueKeysWithValues: entries.map { ($0.key, $0.value.english) })
        let koreanResolver = GameCopyResolver(
            language: .korean,
            catalog: [.korean: contentCatalog, .english: englishCatalog],
            policy: .releaseSafe
        )
        let englishResolver = GameCopyResolver(
            language: .english,
            catalog: [.korean: contentCatalog, .english: englishCatalog],
            policy: .releaseSafe
        )

        let regional = CopyToken.schoolRegionalNameDescriptors
        let cast = CopyToken.schoolCastNameDescriptors
        let regionalKeys = Set(entries.keys.filter { $0.hasPrefix("content.school.region.") })
        let castKeys = Set(entries.keys.filter { $0.hasPrefix("content.school.cast.") })
        XCTAssertEqual(regionalKeys, Set(regional.map(\.token.key)))
        XCTAssertEqual(castKeys, Set(cast.map(\.token.key)))
        XCTAssertEqual(regionalKeys.count, 19 * 4)
        XCTAssertEqual(castKeys.count, 4 * 5 * 2)
        XCTAssertEqual(CopyToken.schoolPhilosophyDescriptors.count, 4)
        XCTAssertEqual(CopyToken.schoolTradeoffDescriptors.count, 4)
        XCTAssertEqual(CopyToken.schoolArchetypeDescriptors.count, 8)

        func assertResolved(_ token: CopyToken, expectedKorean: String, key: String) throws {
            let entry = try XCTUnwrap(entries[key], key)
            XCTAssertEqual(entry.korean, expectedKorean, key)
            XCTAssertFalse(entry.english.isEmpty, key)
            XCTAssertNil(
                koreanPattern.firstMatch(
                    in: entry.english,
                    range: NSRange(location: 0, length: entry.english.utf16.count)
                ),
                key
            )
            XCTAssertEqual(
                GameCopyResolver.placeholderKinds(in: entry.korean),
                GameCopyResolver.placeholderKinds(in: entry.english),
                key
            )
            XCTAssertEqual(koreanResolver.resolve(token), entry.korean, key)
            XCTAssertEqual(englishResolver.resolve(token), entry.english, key)
            XCTAssertNotEqual(englishResolver.resolve(token), GameCopyResolver.unavailableText, key)
        }

        for descriptor in regional {
            let rawRegion = HighSchoolCareerEngine.regions[descriptor.region.ordinal]
            let school = try XCTUnwrap(
                HighSchoolCareerEngine.schools(for: rawRegion).first { $0.id == descriptor.schoolID },
                descriptor.token.key
            )
            try assertResolved(descriptor.token, expectedKorean: school.name, key: descriptor.token.key)
        }

        let firstRegionSchools = HighSchoolCareerEngine.schools(for: HighSchoolCareerEngine.regions[0])
        for descriptor in CopyToken.schoolPhilosophyDescriptors {
            let school = try XCTUnwrap(firstRegionSchools.first { $0.id == descriptor.schoolID })
            try assertResolved(descriptor.token, expectedKorean: school.philosophy, key: descriptor.token.key)
        }
        for descriptor in CopyToken.schoolTradeoffDescriptors {
            let school = try XCTUnwrap(firstRegionSchools.first { $0.id == descriptor.schoolID })
            try assertResolved(descriptor.token, expectedKorean: school.tradeoff, key: descriptor.token.key)
        }
        for descriptor in CopyToken.schoolArchetypeDescriptors {
            let school = try XCTUnwrap(firstRegionSchools.first { $0.id == descriptor.schoolID })
            let expected: String
            switch descriptor.slot {
            case .coachArchetype: expected = school.coachArchetype
            case .catcherArchetype: expected = school.catcherArchetype
            case .philosophy, .tradeoff:
                XCTFail("Unexpected archetype slot \(descriptor.slot)")
                continue
            }
            try assertResolved(descriptor.token, expectedKorean: expected, key: descriptor.token.key)
        }

        for descriptor in cast {
            let rawRegion = try XCTUnwrap(
                HighSchoolCareerEngine.regions.first(where: { region in
                    guard let index = HighSchoolCareerEngine.regions.firstIndex(of: region) else { return false }
                    return index % 5 == descriptor.poolIndex
                })
            )
            let school = try XCTUnwrap(
                HighSchoolCareerEngine.schools(for: rawRegion).first { $0.id == descriptor.schoolID },
                descriptor.token.key
            )
            let expected = descriptor.role == .coach ? school.coachName : school.catcherName
            try assertResolved(descriptor.token, expectedKorean: expected, key: descriptor.token.key)
        }

        let onlyKoreanResolver = GameCopyResolver(
            language: .english,
            catalog: [.korean: contentCatalog],
            policy: .releaseSafe
        )
        for token in regional.map(\.token)
            + cast.map(\.token)
            + CopyToken.schoolPhilosophyDescriptors.map(\.token)
            + CopyToken.schoolTradeoffDescriptors.map(\.token)
            + CopyToken.schoolArchetypeDescriptors.map(\.token) {
            XCTAssertEqual(onlyKoreanResolver.resolve(token), GameCopyResolver.unavailableText, token.key)
        }
    }

    func testCareerSchoolNameUsesTheRawRegionForEveryLanguageAndSafeLegacyFallbacks() throws {
        let entries = try allLocalizationEntries()
        let koreanCatalog = Dictionary(uniqueKeysWithValues: entries.map { ($0.key, $0.value.korean) })
        let englishCatalog = Dictionary(uniqueKeysWithValues: entries.map { ($0.key, $0.value.english) })
        let koreanResolver = GameCopyResolver(
            language: .korean,
            catalog: [.korean: koreanCatalog, .english: englishCatalog],
            policy: .releaseSafe
        )
        let englishResolver = GameCopyResolver(
            language: .english,
            catalog: [.korean: koreanCatalog, .english: englishCatalog],
            policy: .releaseSafe
        )

        for (region, rawRegion) in zip(SchoolRegionID.allCases, HighSchoolCareerEngine.regions) {
            for school in HighSchoolCareerEngine.schools(for: rawRegion) {
                let descriptor = CopyToken.schoolSelectionDescriptor(region: region, schoolID: school.id)
                XCTAssertEqual(
                    HighSchoolPresentation.localizedSchoolName(
                        school,
                        rawRegion: rawRegion,
                        resolver: koreanResolver
                    ),
                    koreanResolver.resolve(descriptor.schoolNameToken),
                    "Korean regional school: \(rawRegion)/\(school.id.rawValue)"
                )
                XCTAssertEqual(
                    HighSchoolPresentation.localizedSchoolName(
                        school,
                        rawRegion: rawRegion,
                        resolver: englishResolver
                    ),
                    englishResolver.resolve(descriptor.schoolNameToken),
                    "English regional school: \(rawRegion)/\(school.id.rawValue)"
                )
                XCTAssertEqual(
                    HighSchoolPresentation.localizedSchoolCastName(
                        school,
                        rawRegion: rawRegion,
                        role: .coach,
                        resolver: englishResolver
                    ),
                    englishResolver.resolve(
                        AppCopyKey.schoolSelectionCoach,
                        arguments: [.userText(englishResolver.resolve(descriptor.coachNameToken))]
                    )
                )
                XCTAssertEqual(
                    HighSchoolPresentation.localizedSchoolCastName(
                        school,
                        rawRegion: rawRegion,
                        role: .catcher,
                        resolver: englishResolver
                    ),
                    englishResolver.resolve(
                        AppCopyKey.schoolSelectionCatcher,
                        arguments: [.userText(englishResolver.resolve(descriptor.catcherNameToken))]
                    )
                )
            }
        }

        let busanSchool = try XCTUnwrap(HighSchoolCareerEngine.schools(for: "부산").first)
        XCTAssertEqual(
            HighSchoolPresentation.localizedSchoolName(
                busanSchool,
                rawRegion: "부산",
                resolver: englishResolver
            ),
            englishResolver.resolve(
                CopyToken.schoolSelectionDescriptor(region: .busan, schoolID: busanSchool.id).schoolNameToken
            )
        )
        XCTAssertNotEqual(
            HighSchoolPresentation.localizedSchoolName(
                busanSchool,
                rawRegion: "부산",
                resolver: englishResolver
            ),
            englishResolver.resolve(busanSchool.id.nameCopyToken)
        )

        let unknownRegion = "legacy-region"
        let legacySchool = busanSchool
        XCTAssertEqual(
            HighSchoolPresentation.localizedSchoolName(
                legacySchool,
                rawRegion: unknownRegion,
                resolver: koreanResolver
            ),
            legacySchool.name
        )
        let fallbackName = englishResolver.resolve(legacySchool.id.fallbackNameCopyToken)
        XCTAssertEqual(
            HighSchoolPresentation.localizedSchoolName(
                legacySchool,
                rawRegion: unknownRegion,
                resolver: englishResolver
            ),
            fallbackName
        )
        XCTAssertNotEqual(fallbackName, englishResolver.resolve(legacySchool.id.nameCopyToken))
        assertNoHangul(fallbackName, "unknown-region school fallback")

        XCTAssertEqual(
            HighSchoolPresentation.localizedSchoolCastName(
                legacySchool,
                rawRegion: unknownRegion,
                role: .coach,
                resolver: koreanResolver
            ),
            "\(legacySchool.coachName) 감독"
        )
        let englishLegacyCoach = HighSchoolPresentation.localizedSchoolCastName(
            legacySchool,
            rawRegion: unknownRegion,
            role: .coach,
            resolver: englishResolver
        )
        XCTAssertTrue(englishLegacyCoach.contains(englishResolver.resolve(
            CopyToken.schoolFallbackCastName(schoolID: legacySchool.id, role: .coach)
        )))
        assertNoHangul(englishLegacyCoach, "unknown-region coach fallback")
    }

    func testRelationshipCardCatalogHasKoEnCoverageAndPlaceholderParity() throws {
        let entries = try gameContentEntries()
        let koreanCatalog = Dictionary(uniqueKeysWithValues: entries.map { ($0.key, $0.value.korean) })
        let englishCatalog = Dictionary(uniqueKeysWithValues: entries.map { ($0.key, $0.value.english) })
        let koreanResolver = GameCopyResolver(
            language: .korean,
            catalog: [.korean: koreanCatalog, .english: englishCatalog],
            policy: .releaseSafe
        )
        let englishResolver = GameCopyResolver(
            language: .english,
            catalog: [.korean: koreanCatalog, .english: englishCatalog],
            policy: .releaseSafe
        )

        func assertToken(_ token: CopyToken, expectedKorean: String? = nil) throws {
            let entry = try XCTUnwrap(entries[token.key], token.key)
            XCTAssertFalse(entry.korean.isEmpty, token.key)
            XCTAssertFalse(entry.english.isEmpty, token.key)
            XCTAssertEqual(
                GameCopyResolver.placeholderKinds(in: entry.korean),
                GameCopyResolver.placeholderKinds(in: entry.english),
                token.key
            )
            assertNoHangul(entry.english, token.key)
            XCTAssertNotEqual(koreanResolver.resolve(token), GameCopyResolver.unavailableText, token.key)
            XCTAssertNotEqual(englishResolver.resolve(token), GameCopyResolver.unavailableText, token.key)
            if let expectedKorean {
                XCTAssertEqual(koreanResolver.resolve(token), expectedKorean, token.key)
            }
        }

        try assertToken(.relationshipPrompt(), expectedKorean: "어떻게 답할까요")
        try assertToken(.relationshipAccessibilityEvent(
            speaker: "감독", name: "윤태문 감독", title: "선발인가 불펜인가",
            primaryText: "인용", summary: "요약"
        ))
        try assertToken(.relationshipAccessibilityChoice(title: "먼저 듣는다", detail: "믿음을 쌓는다"))
        try assertToken(.relationshipWindLine(title: "배터리의 해", effects: "믿음 변화 +2"))
        try assertToken(.relationshipWindFavoredEffect(target: .catcher, bonus: 2))
        try assertToken(.relationshipWindLossEffect(penalty: 2))

        for event in HighSchoolContentCatalog.relationshipEvents {
            let card = RelationshipPresentationCatalog.cardDescriptor(for: event)
            try assertToken(card.event.titleToken, expectedKorean: event.title)
            try assertToken(card.event.summaryToken, expectedKorean: event.summary)
            try assertToken(card.event.categoryLabelToken)
            try assertToken(card.event.speakerLabelToken)

            for quote in card.quoteDescriptors {
                let token = RelationshipVoiceCatalog.quoteCopyToken(
                    eventID: quote.eventID,
                    trustBand: quote.trustBand,
                    playerName: "Player"
                )
                let entry = try XCTUnwrap(entries[token.key], token.key)
                XCTAssertEqual(
                    koreanResolver.resolve(token),
                    entry.korean.replacingOccurrences(of: "%@", with: "Player"),
                    token.key
                )
                XCTAssertEqual(englishResolver.resolve(token), entry.english.replacingOccurrences(of: "%@", with: "Player"), token.key)
                assertNoHangul(englishResolver.resolve(token), token.key)
            }
            for choice in card.choiceDescriptors {
                try assertToken(choice.titleToken)
                try assertToken(choice.detailToken)
            }
        }

        for choice in RelationshipPresentationCatalog.choiceDescriptors {
            try assertToken(choice.titleToken)
            try assertToken(choice.detailToken)
        }
        for descriptor in RivalPresentationCatalog.descriptors {
            try assertToken(descriptor.nameToken)
            try assertToken(descriptor.archetypeToken)
            try assertToken(descriptor.signatureToken)
        }
        for descriptor in CopyToken.schoolFallbackDescriptors {
            try assertToken(descriptor.token)
        }

        let verbatimPlayerName = "김솔 · José O’Neil %"
        let verbatimQuoteToken = RelationshipVoiceCatalog.quoteCopyToken(
            eventID: "evt-coach-role",
            trustBand: .high,
            playerName: verbatimPlayerName
        )
        XCTAssertTrue(koreanResolver.resolve(verbatimQuoteToken).contains(verbatimPlayerName))
        XCTAssertTrue(englishResolver.resolve(verbatimQuoteToken).contains(verbatimPlayerName))

        let unknown = CareerEventContent(
            id: "legacy-event",
            title: "오래된 한국어 제목",
            category: "legacy-category",
            summary: "오래된 한국어 요약"
        )
        let unknownTitle = HighSchoolPresentation.localizedRelationshipEventTitle(unknown, resolver: englishResolver)
        let unknownSummary = HighSchoolPresentation.localizedRelationshipEventSummary(unknown, resolver: englishResolver)
        let unknownSpeaker = HighSchoolPresentation.localizedRelationshipSpeaker(event: unknown, resolver: englishResolver)
        let unknownCategory = HighSchoolPresentation.localizedRelationshipCategory(event: unknown, resolver: englishResolver)
        let unknownQuote = HighSchoolPresentation.localizedRelationshipQuote(
            event: unknown,
            band: .low,
            playerName: "Player",
            resolver: englishResolver
        )
        XCTAssertFalse(unknownTitle.contains(unknown.title))
        XCTAssertFalse(unknownSummary.contains(unknown.summary))
        assertNoHangul(unknownTitle, "unknown relationship event title")
        assertNoHangul(unknownSummary, "unknown relationship event summary")
        assertNoHangul(unknownSpeaker, "unknown relationship speaker")
        assertNoHangul(unknownCategory, "unknown relationship category")
        assertNoHangul(unknownQuote, "unknown relationship quote")
        XCTAssertFalse(unknownQuote.contains(unknown.title))
        XCTAssertFalse(unknownQuote.contains(unknown.summary))
        for response in RelationshipResponse.allCases {
            let title = HighSchoolPresentation.localizedRelationshipChoiceTitle(
                event: unknown,
                response: response,
                resolver: englishResolver
            )
            let detail = HighSchoolPresentation.localizedRelationshipChoiceDetail(
                event: unknown,
                response: response,
                resolver: englishResolver
            )
            assertNoHangul(title, "unknown relationship choice title")
            assertNoHangul(detail, "unknown relationship choice detail")
        }
        let unknownRival = RivalSnapshot(
            id: "legacy-rival", name: "오래된 라이벌", archetype: "오래된 유형",
            contact: 40, discipline: 40, power: 40, signatureRecord: "오래된 기록"
        )
        assertNoHangul(HighSchoolPresentation.localizedRivalName(unknownRival, resolver: englishResolver), "unknown rival name")
        assertNoHangul(HighSchoolPresentation.localizedRivalArchetype(unknownRival, resolver: englishResolver), "unknown rival archetype")
        assertNoHangul(HighSchoolPresentation.localizedRivalSignature(unknownRival, resolver: englishResolver) ?? "", "unknown rival signature")
    }

    func testImportantGameCatalogHasExactKoreanParityNaturalEnglishAndSafeLegacyFallbacks() throws {
        let contentEntries = try gameContentEntries()
        let appEntries = try localizableEntries()
        let entries = contentEntries.merging(appEntries) { _, appValue in appValue }
        let koreanCatalog = Dictionary(uniqueKeysWithValues: entries.map { ($0.key, $0.value.korean) })
        let englishCatalog = Dictionary(uniqueKeysWithValues: entries.map { ($0.key, $0.value.english) })
        let koreanResolver = GameCopyResolver(
            language: .korean,
            catalog: [.korean: koreanCatalog, .english: englishCatalog],
            policy: .releaseSafe
        )
        let englishResolver = GameCopyResolver(
            language: .english,
            catalog: [.korean: koreanCatalog, .english: englishCatalog],
            policy: .releaseSafe
        )

        func assertToken(
            _ token: CopyToken,
            expectedKorean: String? = nil
        ) throws {
            let entry = try XCTUnwrap(entries[token.key], token.key)
            XCTAssertFalse(entry.korean.isEmpty, token.key)
            XCTAssertFalse(entry.english.isEmpty, token.key)
            XCTAssertEqual(
                GameCopyResolver.placeholderKinds(in: entry.korean),
                GameCopyResolver.placeholderKinds(in: entry.english),
                token.key
            )
            if let expectedKorean {
                XCTAssertEqual(entry.korean, expectedKorean, token.key)
            }
            if token.arguments.isEmpty {
                XCTAssertEqual(koreanResolver.resolve(token), entry.korean, token.key)
                XCTAssertEqual(englishResolver.resolve(token), entry.english, token.key)
            } else {
                XCTAssertFalse(koreanResolver.resolve(token).contains("%"), token.key)
                XCTAssertFalse(englishResolver.resolve(token).contains("%"), token.key)
            }
            assertNoHangul(entry.english, token.key)
        }

        func assertAppKey(
            _ key: GameCopyKey,
            expectedKorean: String,
            expectedEnglish: String? = nil
        ) throws {
            let entry = try XCTUnwrap(appEntries[key.rawValue], key.rawValue)
            XCTAssertNil(contentEntries[key.rawValue], "static ImportantGame key must not remain in GameContent")
            XCTAssertEqual(entry.korean, expectedKorean, key.rawValue)
            XCTAssertFalse(entry.english.isEmpty, key.rawValue)
            XCTAssertEqual(
                GameCopyResolver.placeholderKinds(in: entry.korean),
                GameCopyResolver.placeholderKinds(in: entry.english),
                key.rawValue
            )
            if let expectedEnglish {
                XCTAssertEqual(entry.english, expectedEnglish, key.rawValue)
            }
            assertNoHangul(entry.english, key.rawValue)
        }

        XCTAssertEqual(
            ImportantGamePresentationCatalog.scenarioIDs,
            HighSchoolContentCatalog.scenarios.map(\.id)
        )
        XCTAssertEqual(ImportantGamePresentationCatalog.scenarioDescriptors.count, 30)
        XCTAssertEqual(
            Set(ImportantGamePresentationCatalog.scenarioDescriptors.map(\.scenarioID)).count,
            30
        )
        for scenario in HighSchoolContentCatalog.scenarios {
            let descriptor = ImportantGamePresentationCatalog.descriptor(for: scenario.id)
            XCTAssertTrue(descriptor.isKnownScenario, scenario.id)
            try assertToken(descriptor.titleToken, expectedKorean: scenario.title)
            try assertToken(descriptor.narrativeToken, expectedKorean: scenario.narrative)
            let situation = HighSchoolPresentation.localizedImportantGameSituation(
                scenario,
                resolver: koreanResolver
            )
            let expectedSituation = scenario.outs == 0
                ? "\(scenario.inning)회 0아웃"
                : scenario.outs == 1
                    ? "\(scenario.inning)회 1아웃"
                    : "\(scenario.inning)회 \(scenario.outs)아웃"
            XCTAssertEqual(situation, expectedSituation, scenario.id)
            assertNoHangul(
                HighSchoolPresentation.localizedImportantGameSituation(scenario, resolver: englishResolver),
                "important-game situation \(scenario.id)"
            )
        }

        XCTAssertEqual(AppCopyKey.importantGameKeys.count, 11)
        XCTAssertEqual(Set(AppCopyKey.importantGameKeys).count, 11)
        try assertAppKey(AppCopyKey.importantGameOpponentTitle, expectedKorean: "상대", expectedEnglish: "Opponent")
        try assertAppKey(AppCopyKey.importantGameFinalShowdownTitle, expectedKorean: "숙적 — 마지막 승부", expectedEnglish: "Rival — Final Showdown")
        try assertAppKey(
            AppCopyKey.importantGameFinalShowdownBody,
            expectedKorean: "3년의 마지막 마운드. 이 승부가 서로의 마지막 기억이 됩니다.",
            expectedEnglish: "Your final high school matchup. This is how you'll remember each other."
        )
        try assertAppKey(
            AppCopyKey.importantGameSituationZero,
            expectedKorean: "%@ 0아웃",
            expectedEnglish: "%@ · No outs"
        )
        try assertAppKey(
            AppCopyKey.importantGameSituationOne,
            expectedKorean: "%@ 1아웃",
            expectedEnglish: "%@ · 1 out"
        )
        try assertAppKey(
            AppCopyKey.importantGameSituationMany,
            expectedKorean: "%@ %lld아웃",
            expectedEnglish: "%@ · %lld outs"
        )
        try assertAppKey(
            AppCopyKey.importantGameCareerMatchup,
            expectedKorean: "고교 3년 상대 전적 — %lld타석 %lld삼진 %lld피안타",
            expectedEnglish: "High school career matchup — %lld PA · %lld K · %lld H"
        )
        try assertAppKey(AppCopyKey.importantGameStartAction, expectedKorean: "마운드에 오르기", expectedEnglish: "Take the mound")
        try assertAppKey(AppCopyKey.importantGameScenarioAccessibility, expectedKorean: "%@. %@. %@.", expectedEnglish: "%@. %@. %@.")
        try assertAppKey(AppCopyKey.importantGameRivalAccessibility, expectedKorean: "%@, %@.", expectedEnglish: "%@, %@.")
        try assertAppKey(AppCopyKey.importantGameRivalAccessibilitySignature, expectedKorean: "%@, %@. %@.", expectedEnglish: "%@, %@. %@.")

        let debut = try XCTUnwrap(HighSchoolContentCatalog.scenarios.first { $0.id == "game-debut" })
        let rematch = try XCTUnwrap(HighSchoolContentCatalog.scenarios.first { $0.id == "game-rival-rematch" })
        let twoOuts = try XCTUnwrap(HighSchoolContentCatalog.scenarios.first { $0.id == "game-two-outs" })
        XCTAssertEqual(HighSchoolPresentation.localizedImportantGameSituation(debut, resolver: koreanResolver), "3회 0아웃")
        XCTAssertEqual(HighSchoolPresentation.localizedImportantGameSituation(debut, resolver: englishResolver), "3rd inning · No outs")
        XCTAssertEqual(HighSchoolPresentation.localizedImportantGameSituation(rematch, resolver: koreanResolver), "6회 1아웃")
        XCTAssertEqual(HighSchoolPresentation.localizedImportantGameSituation(rematch, resolver: englishResolver), "6th inning · 1 out")
        XCTAssertEqual(HighSchoolPresentation.localizedImportantGameSituation(twoOuts, resolver: koreanResolver), "8회 2아웃")
        XCTAssertEqual(HighSchoolPresentation.localizedImportantGameSituation(twoOuts, resolver: englishResolver), "8th inning · 2 outs")

        let heatwave = try XCTUnwrap(contentEntries["content.important-game.game-heatwave.narrative"])
        XCTAssertEqual(heatwave.korean, "35도의 낮 경기. 유니폼이 몸에 감기고 로진백도 눅눅합니다. 한 점 리드가 이 더위 속에서 여덟 아웃만큼 멀어 보입니다.")
        XCTAssertTrue(heatwave.english.contains("95°F"))
        XCTAssertFalse(heatwave.english.contains("35°C"))

        try assertToken(.importantGameScenarioFallbackTitle(), expectedKorean: "중요 경기")
        try assertToken(
            .importantGameScenarioFallbackNarrative(),
            expectedKorean: "마운드는 준비를 마친 쪽의 것입니다. 다음 타자가 들어섭니다."
        )

        let unknownScenario = ImportantGameScenarioContent(
            id: "legacy-scenario",
            title: "오래된 한국어 경기 제목",
            inning: 99,
            outs: 1,
            runners: BaserunnerStateSnapshot(
                firstOccupied: false, secondOccupied: false, thirdOccupied: false, leadRunnerSpeed: 0
            ),
            leverage: 0,
            narrative: "오래된 한국어 경기 설명"
        )
        let unknownTitle = HighSchoolPresentation.localizedImportantGameScenarioTitle(
            unknownScenario,
            resolver: englishResolver
        )
        let unknownNarrative = HighSchoolPresentation.localizedImportantGameScenarioNarrative(
            unknownScenario,
            resolver: englishResolver
        )
        XCTAssertFalse(unknownTitle.contains(unknownScenario.title))
        XCTAssertFalse(unknownNarrative.contains(unknownScenario.narrative))
        assertNoHangul(unknownTitle, "unknown important-game title")
        assertNoHangul(unknownNarrative, "unknown important-game narrative")

        XCTAssertNil(
            HighSchoolPresentation.localizedImportantGameCareerMatchup(
                HighSchoolCareerStore.RivalLedger(),
                resolver: englishResolver
            )
        )
        var ledger = HighSchoolCareerStore.RivalLedger()
        ledger.plateAppearances = 2
        ledger.strikeouts = 1
        ledger.hits = 0
        XCTAssertEqual(
            HighSchoolPresentation.localizedImportantGameCareerMatchup(ledger, resolver: koreanResolver),
            "고교 3년 상대 전적 — 2타석 1삼진 0피안타"
        )
        XCTAssertEqual(
            HighSchoolPresentation.localizedImportantGameCareerMatchup(ledger, resolver: englishResolver),
            "High school career matchup — 2 PA · 1 K · 0 H"
        )

        XCTAssertEqual(
            HighSchoolPresentation.localizedImportantGameOpponentTitle(
                isFinalShowdown: true,
                resolver: englishResolver
            ),
            "Rival — Final Showdown"
        )
        XCTAssertEqual(
            HighSchoolPresentation.localizedImportantGameFinalShowdownBody(resolver: englishResolver),
            "Your final high school matchup. This is how you'll remember each other."
        )
        XCTAssertEqual(
            HighSchoolPresentation.localizedChallengeOutcome(nil, resolver: koreanResolver),
            "지명 실패"
        )
        XCTAssertEqual(
            HighSchoolPresentation.localizedChallengeOutcome(nil, resolver: englishResolver),
            "Not drafted"
        )
        XCTAssertEqual(
            HighSchoolPresentation.localizedChallengeOutcome(.drafted, resolver: englishResolver),
            "Drafted"
        )
        XCTAssertEqual(
            HighSchoolPresentation.localizedChallengeOutcome(.drafted, resolver: koreanResolver),
            "지명 성공"
        )
        XCTAssertEqual(
            HighSchoolPresentation.localizedChallengeOutcome(.undrafted, resolver: koreanResolver),
            "지명 실패"
        )

        let unknownRival = RivalSnapshot(
            id: "legacy-rival", name: "오래된 라이벌", archetype: "오래된 유형",
            contact: 40, discipline: 40, power: 40, signatureRecord: nil
        )
        XCTAssertEqual(
            HighSchoolPresentation.importantGameRivalPortraitSeed(unknownRival),
            unknownRival.name
        )
        assertNoHangul(
            HighSchoolPresentation.localizedRivalName(unknownRival, resolver: englishResolver),
            "important-game unknown rival name"
        )
        assertNoHangul(
            HighSchoolPresentation.localizedRivalArchetype(unknownRival, resolver: englishResolver),
            "important-game unknown rival archetype"
        )
        XCTAssertNil(
            HighSchoolPresentation.localizedRivalSignature(unknownRival, resolver: englishResolver)
        )
    }

    func testReminderAndChallengeCardsHaveCompleteTypedKoEnCoverage() throws {
        let entries = try localizableEntries()
        let expectedKorean: [GameCopyKey: String] = [
            AppCopyKey.reminderNudgeTitle: "내일도 이어 던지기",
            AppCopyKey.reminderNudgeBody: "매일 저녁 7시 30분, 지금 키우는 선수의 다음 목표나 그날의 이닝 중 이어 할 한 가지를 알려 드립니다. 며칠 안 열면 저절로 멈춥니다.",
            AppCopyKey.reminderNudgeEnable: "알림 켜기",
            AppCopyKey.reminderNudgeDecline: "괜찮습니다",
            AppCopyKey.reminderNudgeAccessibility: "%@. %@. %@. %@.",
            AppCopyKey.challengeEndEyebrow: "기록 없는 도전 결과",
            AppCopyKey.challengeEndScore: "스카우트 평가 %lld점",
            AppCopyKey.challengeEndStats: "경기 %lld · %lld탈삼진 · %lld볼넷 · %lld실점",
            AppCopyKey.challengeEndDisclaimer: "이 도전은 선수 기록이나 다음 회차 보상에 남지 않습니다. 원래 진행은 그대로입니다.",
            AppCopyKey.challengeEndCTA: "도전을 닫는다",
            AppCopyKey.challengeEndAccessibility: "%@. %@. %@. %@. %@.",
            AppCopyKey.challengeEndCloseHint: "도전 결과를 닫고 원래 진행으로 돌아갑니다.",
            AppCopyKey.challengeEndOutcomeDrafted: "지명 성공",
            AppCopyKey.challengeEndOutcomeUndrafted: "지명 실패",
        ]
        let keys = AppCopyKey.reminderNudgeKeys + AppCopyKey.challengeEndKeys
        XCTAssertEqual(keys.count, Set(keys).count)
        XCTAssertEqual(Set(expectedKorean.keys), Set(keys))

        let englishOnlyResolver = GameCopyResolver(
            language: .english,
            catalog: [.korean: Dictionary(uniqueKeysWithValues: entries.map { ($0.key, $0.value.korean) })],
            policy: .releaseSafe
        )
        for key in keys {
            let entry = try XCTUnwrap(entries[key.rawValue], key.rawValue)
            XCTAssertEqual(entry.korean, expectedKorean[key], key.rawValue)
            XCTAssertFalse(entry.english.isEmpty, key.rawValue)
            XCTAssertEqual(
                GameCopyResolver.placeholderKinds(in: entry.korean),
                GameCopyResolver.placeholderKinds(in: entry.english),
                key.rawValue
            )
            assertNoHangul(entry.english, key.rawValue)
            XCTAssertEqual(englishOnlyResolver.resolve(key), GameCopyResolver.unavailableText, key.rawValue)
        }

        XCTAssertEqual(
            entries[AppCopyKey.challengeEndStats.rawValue]?.english,
            "Games %lld · %lld K · %lld BB · %lld R"
        )
        let allEntries = try allLocalizationEntries()
        let resolver = GameCopyResolver(
            language: .english,
            catalog: [
                .korean: Dictionary(uniqueKeysWithValues: allEntries.map { ($0.key, $0.value.korean) }),
                .english: Dictionary(uniqueKeysWithValues: allEntries.map { ($0.key, $0.value.english) }),
            ],
            policy: .releaseSafe
        )
        XCTAssertEqual(
            resolver.resolve(
                AppCopyKey.challengeEndStats,
                arguments: [.integer(1), .integer(1), .integer(1), .integer(1)]
            ),
            "Games 1 · 1 K · 1 BB · 1 R"
        )
    }

    func testBoundedCardsMissingEnglishCopyUseReleaseSafeNeutralFallbacks() throws {
        let allEntries = try allLocalizationEntries()
        let koreanCatalog = Dictionary(uniqueKeysWithValues: allEntries.map { ($0.key, $0.value.korean) })
        let resolver = GameCopyResolver(
            language: .english,
            catalog: [.korean: koreanCatalog],
            policy: .releaseSafe
        )

        let legacyScenario = ImportantGameScenarioContent(
            id: "legacy-important-game",
            title: "오래된 경기 제목",
            inning: 7,
            outs: 2,
            runners: BaserunnerStateSnapshot(
                firstOccupied: false, secondOccupied: false, thirdOccupied: false, leadRunnerSpeed: 0
            ),
            leverage: 0,
            narrative: "오래된 경기 설명"
        )
        XCTAssertEqual(
            HighSchoolPresentation.localizedImportantGameScenarioTitle(legacyScenario, resolver: resolver),
            GameCopyResolver.unavailableText
        )
        XCTAssertEqual(
            HighSchoolPresentation.localizedImportantGameScenarioNarrative(legacyScenario, resolver: resolver),
            GameCopyResolver.unavailableText
        )

        var ledger = HighSchoolCareerStore.RivalLedger()
        ledger.plateAppearances = 1
        let unknownRival = RivalSnapshot(
            id: "legacy-rival", name: "오래된 라이벌", archetype: "오래된 유형",
            contact: 40, discipline: 40, power: 40, signatureRecord: "오래된 기록"
        )
        XCTAssertEqual(
            HighSchoolPresentation.localizedImportantGameCareerMatchup(ledger, resolver: resolver),
            GameCopyResolver.unavailableText
        )
        XCTAssertEqual(
            HighSchoolPresentation.localizedRivalName(unknownRival, resolver: resolver),
            GameCopyResolver.unavailableText
        )
        XCTAssertEqual(
            HighSchoolPresentation.localizedChallengeOutcome(nil, resolver: resolver),
            GameCopyResolver.unavailableText
        )
        XCTAssertEqual(resolver.resolve(AppCopyKey.reminderNudgeTitle), GameCopyResolver.unavailableText)
        XCTAssertEqual(resolver.resolve(AppCopyKey.challengeEndEyebrow), GameCopyResolver.unavailableText)
    }

    func testRelationshipKoreanParityCoversRepresentativeVoicesCastRivalsAndWind() throws {
        let entries = try allLocalizationEntries()
        let koreanCatalog = Dictionary(uniqueKeysWithValues: entries.map { ($0.key, $0.value.korean) })
        let englishCatalog = Dictionary(uniqueKeysWithValues: entries.map { ($0.key, $0.value.english) })
        let koreanResolver = GameCopyResolver(
            language: .korean,
            catalog: [.korean: koreanCatalog, .english: englishCatalog],
            policy: .releaseSafe
        )
        let coachEvent = try XCTUnwrap(HighSchoolContentCatalog.relationshipEvents.first { $0.id == "evt-coach-role" })
        XCTAssertEqual(
            HighSchoolPresentation.localizedRelationshipEventTitle(coachEvent, resolver: koreanResolver),
            coachEvent.title
        )
        XCTAssertEqual(
            HighSchoolPresentation.localizedRelationshipEventSummary(coachEvent, resolver: koreanResolver),
            coachEvent.summary
        )
        XCTAssertEqual(
            koreanResolver.resolve(.relationshipSpeakerLabel(categoryID: "media")),
            "취재"
        )
        for (trust, band) in zip([30, 50, 70], RelationshipPresentationCatalog.trustBands) {
            let quote = HighSchoolPresentation.localizedRelationshipQuote(
                event: coachEvent,
                band: band,
                playerName: "민서준",
                resolver: koreanResolver
            )
            let key = "content.relationship.evt-coach-role.quote.\(band.rawValue)"
            XCTAssertEqual(quote, entries[key]?.korean.replacingOccurrences(of: "%@", with: "민서준"), key)
            _ = trust
        }
        for response in RelationshipResponse.allCases {
            let title = HighSchoolPresentation.localizedRelationshipChoiceTitle(
                event: coachEvent,
                response: response,
                resolver: koreanResolver
            )
            let detail = HighSchoolPresentation.localizedRelationshipChoiceDetail(
                event: coachEvent,
                response: response,
                resolver: koreanResolver
            )
            let raw = RelationshipVoiceCatalog.scenes[coachEvent.id]!.choices.first { $0.response == response }!
            XCTAssertEqual(title, raw.title, response.rawValue)
            XCTAssertEqual(detail, raw.detail, response.rawValue)
        }

        let school = try XCTUnwrap(HighSchoolCareerEngine.schools(for: "서울").first)
        XCTAssertEqual(
            HighSchoolPresentation.localizedSchoolCastName(
                school, rawRegion: "서울", role: .coach, resolver: koreanResolver
            ),
            "\(school.coachName) 감독"
        )
        XCTAssertEqual(
            HighSchoolPresentation.localizedSchoolCastName(
                school, rawRegion: "서울", role: .catcher, resolver: koreanResolver
            ),
            "\(school.catcherName) 포수"
        )
        let rival = RivalSnapshot(
            id: "rival-seo", name: "서하준", archetype: "천재 교타형", contact: 40, discipline: 40, power: 40,
            signatureRecord: "봄 대회 타율 .421 · 31안타"
        )
        XCTAssertEqual(HighSchoolPresentation.localizedRivalName(rival, resolver: koreanResolver), rival.name)
        XCTAssertEqual(HighSchoolPresentation.localizedRivalArchetype(rival, resolver: koreanResolver), rival.archetype)
        XCTAssertEqual(HighSchoolPresentation.localizedRivalSignature(rival, resolver: koreanResolver), rival.signatureRecord)

        let batteryWind = try XCTUnwrap(CareerWindPresentationCatalog.v2Winds.first { $0.id == "battery_year" })
        XCTAssertEqual(
            HighSchoolPresentation.localizedRelationshipWindLine(
                category: "catcher", wind: batteryWind, resolver: koreanResolver
            ),
            "배터리의 해: 믿음 변화 +2"
        )
        let spotlightWind = try XCTUnwrap(CareerWindPresentationCatalog.v2Winds.first { $0.id == "spotlight_year" })
        XCTAssertEqual(
            HighSchoolPresentation.localizedRelationshipWindLine(
                category: "coach", wind: spotlightWind, resolver: koreanResolver
            ),
            "조명의 해: 실패하면 믿음 손실 2 추가"
        )
    }

    func testSystemDefaultNameIsLocalizedOnlyForBlankQuickRebirthNames() throws {
        let entries = try gameContentEntries()
        let resolver = GameCopyResolver(
            language: .english,
            catalog: [
                .korean: Dictionary(uniqueKeysWithValues: entries.map { ($0.key, $0.value.korean) }),
                .english: Dictionary(uniqueKeysWithValues: entries.map { ($0.key, $0.value.english) }),
            ],
            policy: .releaseSafe
        )
        let preset = try XCTUnwrap(PitcherPresetCatalog.all.first { $0.id == "power_prospect" })

        XCTAssertEqual(
            HighSchoolSetupView.localizedQuickRebirthPlayerName("", preset: preset, resolver: resolver),
            "Min Seo-jun"
        )
        for name in ["김솔", "José O’Neil", "⚾️✨"] {
            XCTAssertEqual(
                HighSchoolSetupView.localizedQuickRebirthPlayerName(name, preset: preset, resolver: resolver),
                name
            )
        }
        XCTAssertEqual(preset.pitcher.name, "민서준")
    }

    func testSubmittedNameHelperUsesEmptyInputForAllLocalizedSystemSuggestions() {
        let localizedDefaults = [
            "Min Seo-jun",
            "Go Tae-yun",
            "Jin Seo-yul",
            "Do Ha-ram",
        ]

        for localizedDefault in localizedDefaults {
            XCTAssertEqual(
                HighSchoolSetupView.submittedPlayerName(
                    localizedDefault,
                    isSystemSuggestion: true
                ),
                "",
                localizedDefault
            )
        }
    }

    func testSubmittedNameHelperPreservesUserTextVerbatim() {
        let userNames = ["김솔", "José O’Neil", "⚾️✨", "Min Seo-jun"]

        for userName in userNames {
            XCTAssertEqual(
                HighSchoolSetupView.submittedPlayerName(
                    userName,
                    isSystemSuggestion: false
                ),
                userName,
                userName
            )
        }
    }

    func testPlaceholderKindsRemainTypedAndOrdered() {
        XCTAssertEqual(
            GameCopyResolver.placeholderKinds(in: "Week %lld, %@, %.2f"),
            ["integer", "string", "decimal"]
        )
    }

    func testClosedEnumCatalogHasKoreanParityAndNaturalEnglishForEveryCase() throws {
        let entries = try gameContentEntries()
        let descriptors = CopyToken.closedEnumDescriptors
        let expectedKorean: [(PresentationCopyFamily, [String])] = [
            (.pitchType, ["포심", "슬라이더", "커브", "체인지업"]),
            (.pitchIntensity, ["힘 빼고", "보통", "전력"]),
            (.pitchUsage, ["주력 구종", "보조 구종", "개발 구종"]),
            (.batterSide, ["우타", "좌타", "우타"]),
            (.pitchOutcome, ["볼", "루킹 스트라이크", "헛스윙", "파울", "인플레이 아웃", "안타", "2루타", "3루타", "홈런", "몸에 맞는 공"]),
            (.zoneIntent, ["존 안으로", "존 경계", "존 밖 유인"]),
            (.highSchoolPhase, ["다시 태어남", "학교 선택", "훈련", "사람들", "고교 공식 경기", "각성", "이야기 마무리", "드래프트", "새 선수에게 남길 것", "완료"]),
            (.trainingFocus, ["구위", "제구", "변화구", "체력", "회복", "승부 설계"]),
            (.trainingIntensity, ["가볍게", "보통", "몰아붙이기"]),
            (.relationshipTarget, ["감독", "포수", "라이벌"]),
            (.relationshipResponse, ["먼저 듣는다", "내 생각을 말한다", "다음 승부로 증명한다"]),
            (.draftOutcome, ["지명", "미지명"]),
            (.armHealth, ["팔 상태 정상", "팔에 부담이 쌓임", "팔 상태 경고", "회복 중"]),
            (.proCareerPhase, ["계약 제안", "주간 계획", "시즌 결정", "중요 경기", "시즌 복기", "시즌 결산", "오프시즌 결정", "오프시즌 투자", "은퇴 결정", "완료"]),
            (.proLevel, ["2군", "1군"]),
            (.proRole, ["선발", "긴 이닝 구원", "필승조", "마무리"]),
            (.proWeekPlan, ["구위 개발", "변화구 개발", "무기 개발", "제구 다듬기", "체력 만들기", "회복", "신뢰 쌓기"]),
            (.offseasonDecision, ["현재 구단에 남는다", "군 복무를 다녀온다", "FA를 신청한다", "은퇴한다"]),
            (.proSeasonDecisionType, ["추가 불펜", "포수와 경기 계획", "역할 면담", "기록 추격", "라이벌 분석", "시즌 막바지", "미디어 기회"]),
            (.proSeasonSegment, ["스프링캠프", "개막", "전반기", "올스타 휴식기", "순위 싸움", "시즌 막바지"]),
            (.proSeasonTrigger, ["개막 선언", "콜업 오디션", "1군 데뷔", "기록 추격", "보직 승부", "순위 경쟁"]),
        ]

        for (family, values) in expectedKorean {
            let familyDescriptors = descriptors.filter { $0.family == family }
            XCTAssertEqual(familyDescriptors.count, values.count, family.rawValue)
            for (descriptor, expected) in zip(familyDescriptors, values) {
                let entry = try XCTUnwrap(entries[descriptor.token.key], descriptor.token.key)
                XCTAssertEqual(entry.korean, expected, descriptor.token.key)
            }
        }

        let resolver = GameCopyResolver(
            language: .english,
            catalog: [
                .korean: Dictionary(uniqueKeysWithValues: entries.map { ($0.key, $0.value.korean) }),
                .english: Dictionary(uniqueKeysWithValues: entries.map { ($0.key, $0.value.english) }),
            ],
            policy: .releaseSafe
        )
        for descriptor in descriptors {
            let entry = try XCTUnwrap(entries[descriptor.token.key], descriptor.token.key)
            let resolved = resolver.resolve(descriptor.token)
            XCTAssertEqual(resolved, entry.english, descriptor.token.key)
            XCTAssertFalse(resolved.isEmpty, descriptor.token.key)
            XCTAssertNotEqual(resolved, GameCopyResolver.unavailableText, descriptor.token.key)
            XCTAssertNil(
                koreanPattern.firstMatch(
                    in: resolved,
                    range: NSRange(location: 0, length: resolved.utf16.count)
                ),
                descriptor.token.key
            )
            XCTAssertNotEqual(resolved, entry.korean, descriptor.token.key)
        }
    }

    func testPrologueStaticCatalogHasExactKoreanCopyAndEnglishCoverage() throws {
        let entries = try localizableEntries()
        let expectedKorean: [GameCopyKey: String] = [
            AppCopyKey.prologueFirstLifeTitle: "첫 등교",
            AppCopyKey.prologueRebirthTitle: "다시 태어났습니다",
            AppCopyKey.prologueFirstLifeCoachQuote: "“몸부터 풀자. 불펜에서 한 구 던져 봐.” — 감독",
            AppCopyKey.prologueWindHeading: "이번 3년의 바람 · %@",
            AppCopyKey.prologueWindNeutralExplanation: "능력과 보상 보정 없이 실력만으로 승부합니다.",
            AppCopyKey.prologueWindAccessibility: "이번 3년의 바람, %@. %@. 효과: %@.",
            AppCopyKey.prologueHandicapHeading: "핸디캡",
            AppCopyKey.prologueThrow: "첫 공을 던진다",
            AppCopyKey.prologueSkip: "바로 학교 고르기",
            AppCopyKey.prologueCurrentPlayerTitle: "지금의 나",
            AppCopyKey.prologueInheritedStartTitle: "계보가 바꾼 시작",
            AppCopyKey.prologueInheritedStartJourney: "%@의 마지막 %lld → 이번 선수의 시작 %lld (%@)",
            AppCopyKey.prologueInheritedStartTotal: "시작에 스며든 계승 성장 %@",
            AppCopyKey.prologueInheritedStartSoul: "야구혼과 이전 선수의 기억",
            AppCopyKey.prologueInheritedStartBoost: "환생 상점 부스트",
            AppCopyKey.prologueInheritedStartSource: "%@ · %@",
            AppCopyKey.prologueAbilityTalent: "재능 %@",
            AppCopyKey.prologueAbilityCeiling: "%lld까지",
            AppCopyKey.prologueAbilityNoCeiling: "한계 없음",
            AppCopyKey.prologueAbilityExplanation: "큰 숫자가 지금 실력이고, 알파벳은 훈련으로 닿을 수 있는 한계입니다. 재능이 높아도 지금 수치가 낮을 수 있습니다.",
            AppCopyKey.prologueAbilityAccessibility: "%@, 현재 능력치 %lld, %@, %@.",
            AppCopyKey.prologueAbilityMeaningBest: "세대 최고 수준",
            AppCopyKey.prologueAbilityMeaningProTop: "프로 최상급",
            AppCopyKey.prologueAbilityMeaningAbovePro: "프로 평균 이상",
            AppCopyKey.prologueAbilityMeaningProAverage: "프로 평균",
            AppCopyKey.prologueAbilityMeaningRegional: "지역에서 손꼽는 재능",
            AppCopyKey.prologueAbilityMeaningHighSchool: "고교 상위권 도전",
            AppCopyKey.prologueAbilityMeaningStarter: "고교 주전 경쟁",
            AppCopyKey.prologueAbilityMeaningDeveloping: "성장 중인 기본기",
            AppCopyKey.prologueAbilityMeaningFoundations: "기본기 다지는 단계",
            AppCopyKey.prologueAbilityCeilingReached: "재능의 한계에 닿았습니다. 계속 훈련하면 열립니다.",
        ]
        XCTAssertEqual(Set(expectedKorean.keys), Set(AppCopyKey.prologueKeys))

        for key in AppCopyKey.prologueKeys {
            let entry = try XCTUnwrap(entries[key.rawValue], key.rawValue)
            XCTAssertEqual(entry.korean, expectedKorean[key], key.rawValue)
            XCTAssertFalse(entry.english.isEmpty, key.rawValue)
            XCTAssertEqual(
                GameCopyResolver.placeholderKinds(in: entry.korean),
                GameCopyResolver.placeholderKinds(in: entry.english),
                key.rawValue
            )
            XCTAssertNil(
                koreanPattern.firstMatch(
                    in: entry.english,
                    range: NSRange(location: 0, length: entry.english.utf16.count)
                ),
                key.rawValue
            )
        }

        XCTAssertEqual(
            [
                TrainingFocus.velocity.displayCopyToken,
                TrainingFocus.command.displayCopyToken,
                TrainingFocus.breakingBall.displayCopyToken,
                TrainingFocus.stamina.displayCopyToken,
            ].map(\.key),
            [
                "content.training-focus.velocity.label",
                "content.training-focus.command.label",
                "content.training-focus.breaking_ball.label",
                "content.training-focus.stamina.label",
            ]
        )
    }

    func testPrologueContentHasExactWindKarmaAndOpenerCoverage() throws {
        let entries = try gameContentEntries()
        let localizable = try localizableEntries()
        let koreanCatalog = Dictionary(
            uniqueKeysWithValues: entries.map { ($0.key, $0.value.korean) }
                + localizable.map { ($0.key, $0.value.korean) }
        )
        let englishCatalog = Dictionary(
            uniqueKeysWithValues: entries.map { ($0.key, $0.value.english) }
                + localizable.map { ($0.key, $0.value.english) }
        )
        let koreanResolver = GameCopyResolver(
            language: .korean,
            catalog: [.korean: koreanCatalog, .english: englishCatalog],
            policy: .releaseSafe
        )
        let englishResolver = GameCopyResolver(
            language: .english,
            catalog: [.korean: koreanCatalog, .english: englishCatalog],
            policy: .releaseSafe
        )

        let windDescriptors = CareerWindPresentationCatalog.descriptors
        let windTokens = windDescriptors.flatMap { [$0.titleToken, $0.detailToken] + $0.effectDescriptors.map(\.token) }
        let karmaTokens = KarmaPresentationCatalog.descriptors.flatMap { [$0.titleToken, $0.detailToken] }
        let openerTokens = ProloguePresentationCatalog.openerDescriptors.map(\.openerToken)
        let fallbackTokens = [
            CopyToken(key: "content.career-wind.fallback.title"),
            CopyToken(key: "content.career-wind.fallback.detail"),
        ]
        let allTokens = windTokens + karmaTokens + openerTokens + fallbackTokens
        let expectedKeys = Set(allTokens.map(\.key))
        let actualKeys = Set(
            entries.keys.filter {
                $0.hasPrefix("content.career-wind.") ||
                $0.hasPrefix("content.karma.") ||
                $0.hasPrefix("content.prologue.")
            }
        )
        XCTAssertEqual(actualKeys, expectedKeys)
        XCTAssertEqual(entries.keys.filter { $0.hasPrefix("content.career-wind.") }.count, 62)
        XCTAssertEqual(entries.keys.filter { $0.hasPrefix("content.karma.") }.count, 12)
        XCTAssertEqual(entries.keys.filter { $0.hasPrefix("content.prologue.") }.count, 5)

        for token in allTokens {
            let entry = try XCTUnwrap(entries[token.key], token.key)
            XCTAssertFalse(entry.korean.isEmpty, token.key)
            XCTAssertFalse(entry.english.isEmpty, token.key)
            XCTAssertEqual(
                GameCopyResolver.placeholderKinds(in: entry.korean),
                GameCopyResolver.placeholderKinds(in: entry.english),
                token.key
            )
            XCTAssertNil(
                koreanPattern.firstMatch(
                    in: entry.english,
                    range: NSRange(location: 0, length: entry.english.utf16.count)
                ),
                token.key
            )
        }

        for descriptor in windDescriptors {
            let rawWind = try XCTUnwrap(
                (CareerWindPresentationCatalog.v1Winds + CareerWindPresentationCatalog.v2Winds).first {
                    $0.id == descriptor.id && $0.rulesVersion == descriptor.rulesVersion
                },
                descriptor.id
            )
            XCTAssertEqual(koreanResolver.resolve(descriptor.titleToken), rawWind.title, descriptor.id)
            XCTAssertEqual(koreanResolver.resolve(descriptor.detailToken), rawWind.detail, descriptor.id)
            XCTAssertEqual(
                descriptor.effectDescriptors.map { koreanResolver.resolve($0.token) },
                rawWind.effectDescriptions,
                "v\(descriptor.rulesVersion.rawValue):\(descriptor.id)"
            )
            for token in [descriptor.titleToken, descriptor.detailToken] + descriptor.effectDescriptors.map(\.token) {
                let english = englishResolver.resolve(token)
                XCTAssertNotEqual(english, GameCopyResolver.unavailableText, token.key)
                XCTAssertNil(
                    koreanPattern.firstMatch(
                        in: english,
                        range: NSRange(location: 0, length: english.utf16.count)
                    ),
                    token.key
                )
            }
            for effect in descriptor.effectDescriptors {
                guard case .integer(let value) = effect.token.arguments.first else {
                    XCTFail("Non-numeric effect argument: \(effect.token.key)")
                    continue
                }
                let numericMarker: String
                switch effect.slot {
                case "starting-fan-interest": numericMarker = "\(value)"
                case "relationship-loss": numericMarker = "+\(value)"
                case "inheritance-bonus": numericMarker = "\(value >= 0 ? "+" : "")\(value)%"
                default: numericMarker = value > 0 ? "+\(value)" : "\(value)"
                }
                XCTAssertTrue(
                    englishResolver.resolve(effect.token).contains(numericMarker),
                    "\(effect.token.key) missing \(numericMarker)"
                )
            }
        }

        for descriptor in KarmaPresentationCatalog.descriptors {
            let legacyCopy = HighSchoolPresentation.karma(descriptor.id)
            XCTAssertEqual(koreanResolver.resolve(descriptor.titleToken), legacyCopy.title, descriptor.id.rawValue)
            XCTAssertEqual(koreanResolver.resolve(descriptor.detailToken), legacyCopy.detail, descriptor.id.rawValue)
            XCTAssertNil(
                koreanPattern.firstMatch(
                    in: englishResolver.resolve(descriptor.titleToken),
                    range: NSRange(location: 0, length: englishResolver.resolve(descriptor.titleToken).utf16.count)
                ),
                descriptor.id.rawValue
            )
            XCTAssertNil(
                koreanPattern.firstMatch(
                    in: englishResolver.resolve(descriptor.detailToken),
                    range: NSRange(location: 0, length: englishResolver.resolve(descriptor.detailToken).utf16.count)
                ),
                descriptor.id.rawValue
            )
        }

        let engine = HighSchoolCareerEngine()
        for (region, rawRegion) in zip(SchoolRegionID.allCases, HighSchoolCareerEngine.regions) {
            let koreanRegion = koreanResolver.resolve(AppCopyKey.setupRegionName(for: region))
            for lifeNumber in 1...4 {
                let started = try engine.start(
                    .init(
                        seed: String(202608130000 + region.ordinal * 10 + lifeNumber),
                        presetID: "power_prospect",
                        lifeNumber: lifeNumber,
                        identity: PlayerIdentitySnapshot(
                            name: "테스트 투수",
                            throwingHand: .right,
                            bodyType: .balanced,
                            region: rawRegion
                        )
                    )
                )
                let currentContext = try XCTUnwrap(
                    started.snapshot.news.first(where: { !$0.hasPrefix("이번 3년의 바람") }),
                    "missing prologue context for \(rawRegion) life \(lifeNumber)"
                )
                let descriptor = ProloguePresentationCatalog.opener(
                    lifeNumber: lifeNumber,
                    region: region
                )
                XCTAssertEqual(
                    ProloguePresentationCatalog.opener(
                        lifeNumber: lifeNumber,
                        rawRegion: rawRegion
                    ),
                    descriptor,
                    "known raw region should preserve the typed opener"
                )
                XCTAssertEqual(
                    koreanResolver.resolve(descriptor, regionName: koreanRegion),
                    currentContext,
                    descriptor.openerToken.key
                )
                let english = englishResolver.resolve(descriptor, regionName: englishResolver.resolve(AppCopyKey.setupRegionName(for: region)))
                XCTAssertNotEqual(english, GameCopyResolver.unavailableText, descriptor.openerToken.key)
                XCTAssertNil(
                    koreanPattern.firstMatch(
                        in: english,
                        range: NSRange(location: 0, length: english.utf16.count)
                    ),
                    descriptor.openerToken.key
                )
            }
        }

        let fallback = ProloguePresentationCatalog.opener(lifeNumber: 0, region: .seoul)
        XCTAssertEqual(koreanResolver.resolve(fallback, regionName: "서울"), entries[fallback.openerToken.key]?.korean)
        let fallbackEnglish = englishResolver.resolve(fallback, regionName: "Seoul")
        XCTAssertNotEqual(fallbackEnglish, GameCopyResolver.unavailableText)
        XCTAssertNil(
            koreanPattern.firstMatch(
                in: fallbackEnglish,
                range: NSRange(location: 0, length: fallbackEnglish.utf16.count)
            )
        )

        let unknownRaw = ProloguePresentationCatalog.opener(
            lifeNumber: 2,
            rawRegion: "legacy-region"
        )
        let unknownEntry = try XCTUnwrap(entries[unknownRaw.openerToken.key])
        XCTAssertEqual(unknownRaw.variant, .fallback)
        XCTAssertNil(unknownRaw.region)
        XCTAssertEqual(unknownRaw.openerToken.arguments, [])
        XCTAssertEqual(koreanResolver.resolve(unknownRaw), unknownEntry.korean)
        XCTAssertEqual(englishResolver.resolve(unknownRaw), unknownEntry.english)
        XCTAssertFalse(englishResolver.resolve(unknownRaw).contains("legacy-region"))
    }

    func testPrologueEnglishOnlyMissingCatalogNeverFallsBackToKorean() throws {
        let contentEntries = try gameContentEntries()
        let localizableCatalogEntries = try localizableEntries()
        let koreanCatalog = Dictionary(
            uniqueKeysWithValues: contentEntries.map { ($0.key, $0.value.korean) }
                + localizableCatalogEntries.map { ($0.key, $0.value.korean) }
        )
        let resolver = GameCopyResolver(
            language: .english,
            catalog: [.korean: koreanCatalog],
            policy: .releaseSafe
        )

        for key in AppCopyKey.prologueKeys {
            XCTAssertEqual(resolver.resolve(key), GameCopyResolver.unavailableText, key.rawValue)
        }
        for token in CareerWindPresentationCatalog.descriptors.flatMap({
            [$0.titleToken, $0.detailToken] + $0.effectDescriptors.map(\.token)
        }) + KarmaPresentationCatalog.descriptors.flatMap({ [$0.titleToken, $0.detailToken] }) + ProloguePresentationCatalog.openerDescriptors.map(\.openerToken) {
            XCTAssertEqual(resolver.resolve(token), GameCopyResolver.unavailableText, token.key)
        }
    }

    func testChapterTrainingAndResultRegistriesHaveCompleteKoEnCoverage() throws {
        let contentEntries = try gameContentEntries()
        let localizable = try localizableEntries()
        let koreanCatalog = Dictionary(
            uniqueKeysWithValues: contentEntries.map { ($0.key, $0.value.korean) }
                + localizable.map { ($0.key, $0.value.korean) }
        )
        let englishCatalog = Dictionary(
            uniqueKeysWithValues: contentEntries.map { ($0.key, $0.value.english) }
                + localizable.map { ($0.key, $0.value.english) }
        )
        let koreanResolver = GameCopyResolver(
            language: .korean,
            catalog: [.korean: koreanCatalog, .english: englishCatalog],
            policy: .releaseSafe
        )
        let englishResolver = GameCopyResolver(
            language: .english,
            catalog: [.korean: koreanCatalog, .english: englishCatalog],
            policy: .releaseSafe
        )

        let appKeys = AppCopyKey.chapterHeaderKeys + AppCopyKey.trainingKeys + AppCopyKey.trainingResultKeys
        XCTAssertEqual(appKeys.count, Set(appKeys).count)
        for key in appKeys {
            let entry = try XCTUnwrap(localizable[key.rawValue], key.rawValue)
            XCTAssertFalse(entry.korean.isEmpty, key.rawValue)
            XCTAssertFalse(entry.english.isEmpty, key.rawValue)
            XCTAssertEqual(
                GameCopyResolver.placeholderKinds(in: entry.korean),
                GameCopyResolver.placeholderKinds(in: entry.english),
                key.rawValue
            )
            if GameCopyResolver.placeholderKinds(in: entry.korean).isEmpty {
                XCTAssertEqual(koreanResolver.resolve(key), entry.korean, key.rawValue)
                XCTAssertEqual(englishResolver.resolve(key), entry.english, key.rawValue)
            }
            assertNoHangul(entry.english, key.rawValue)
        }

        let boundedContentKeys: [GameCopyKey] = [
            GameCopyKey.gameContent("content.chapter.fallback.title"),
            GameCopyKey.gameContent("content.chapter.fallback.act-title"),
            GameCopyKey.gameContent("content.chapter.fallback.season"),
            GameCopyKey.gameContent("content.training-wind.effect-line"),
            GameCopyKey.gameContent("content.training-wind.growth"),
            GameCopyKey.gameContent("content.training-wind.recovery"),
            GameCopyKey.gameContent("content.training-wind.fatigue"),
            GameCopyKey.gameContent("content.training-result.bloom-headline"),
            GameCopyKey.gameContent("content.training-result.detail.blocked"),
            GameCopyKey.gameContent("content.training-result.detail.growth"),
            GameCopyKey.gameContent("content.training-result.detail.growth-recovery"),
            GameCopyKey.gameContent("content.training-result.detail.jackpot"),
            GameCopyKey.gameContent("content.training-result.detail.no-growth"),
            GameCopyKey.gameContent("content.training-result.detail.rehab"),
            GameCopyKey.gameContent("content.training-result.detail.recovery"),
            GameCopyKey.gameContent("content.training-result.detail.repeat"),
            GameCopyKey.gameContent("content.training-result.detail.unknown"),
        ] + SchoolID.allCases.map(\.nameCopyToken).compactMap(GameCopyKey.init(coreToken:))
        XCTAssertEqual(boundedContentKeys.count, Set(boundedContentKeys).count)
        for key in boundedContentKeys {
            let entry = try XCTUnwrap(contentEntries[key.rawValue], key.rawValue)
            XCTAssertFalse(entry.korean.isEmpty, key.rawValue)
            XCTAssertFalse(entry.english.isEmpty, key.rawValue)
            XCTAssertEqual(
                GameCopyResolver.placeholderKinds(in: entry.korean),
                GameCopyResolver.placeholderKinds(in: entry.english),
                key.rawValue
            )
            assertNoHangul(entry.english, key.rawValue)
        }

        let sampleSchool = try XCTUnwrap(HighSchoolCareerEngine.schools(for: "서울").first)
        XCTAssertEqual(
            HighSchoolPresentation.localizedSchoolName(
                sampleSchool,
                rawRegion: "서울",
                resolver: koreanResolver
            ),
            sampleSchool.name
        )
        XCTAssertEqual(
            HighSchoolPresentation.localizedSchoolName(
                sampleSchool,
                rawRegion: "서울",
                resolver: englishResolver
            ),
            englishResolver.resolve(sampleSchool.id.nameCopyToken)
        )

        let chapterTitles = [
            "낯선 마운드", "첫 번째 증명", "첫 겨울", "전국의 시선",
            "흔들리는 배터리", "에이스의 책임", "마지막 겨울", "드래프트 데이",
        ]
        let chapterTokens = CareerChapterPresentationCatalog.descriptors.flatMap {
            [$0.titleToken, $0.actTitleToken, $0.seasonToken]
        }
        for descriptor in CareerChapterPresentationCatalog.descriptors {
            XCTAssertEqual(
                koreanResolver.resolve(descriptor.titleToken),
                chapterTitles[descriptor.number - 1],
                descriptor.titleToken.key
            )
        }
        for token in chapterTokens {
            let entry = try XCTUnwrap(contentEntries[token.key], token.key)
            XCTAssertEqual(koreanResolver.resolve(token), entry.korean, token.key)
            XCTAssertEqual(englishResolver.resolve(token), entry.english, token.key)
            assertNoHangul(entry.english, token.key)
        }

        let focusTokens = TrainingFocus.allCases.flatMap { focus in
            [
                focus.displayCopyToken,
                focus.detailCopyToken,
                focus.metricCopyToken,
                focus.tradeoffCopyToken,
            ]
        }
        let intensityTokens = TrainingIntensity.allCases.flatMap { intensity in
            [intensity.displayCopyToken, intensity.recoveryCopyToken]
        }
        let pitchTokens = PitchType.allCases.map(\.displayCopyToken)
        let statusTokens = ArmHealthState.allCases.map(\.displayCopyToken)
            + HighSchoolCareerEngine.TrainingGrowthOutlook.allCases.map(\.detailCopyToken)
            + TalentAbility.allCases.map(\.displayCopyToken)
            + TalentGrade.allCases.map(\.displayCopyToken)

        for token in focusTokens + intensityTokens + pitchTokens + statusTokens {
            let entry = try XCTUnwrap(contentEntries[token.key], token.key)
            XCTAssertEqual(koreanResolver.resolve(token), entry.korean, token.key)
            XCTAssertEqual(englishResolver.resolve(token), entry.english, token.key)
            assertNoHangul(entry.english, token.key)
        }

        let expectedFocusTradeoffs: [TrainingFocus: String] = [
            .velocity: "대성공 가능성과 성장 편차가 가장 크지만 피로·팔 위험도 가장 큽니다.",
            .command: "성장 편차와 피로가 작고 팔 위험이 없지만 대성공은 드뭅니다.",
            .breakingBall: "고른 결정구만 빠르게 완성합니다. 강하게 할수록 팔 위험이 조금 오릅니다.",
            .stamina: "후반 체감 피로를 낮춥니다. 당장의 구속·결정구는 오르지 않습니다.",
            .recovery: "능력 성장은 없고 피로와 팔 상태를 회복합니다.",
            .gamePlanning: "가벼운 피로로 제구를 다듬지만 구종 자체 위력은 오르지 않습니다.",
        ]
        for focus in TrainingFocus.allCases {
            XCTAssertEqual(
                koreanResolver.resolve(focus.detailCopyToken),
                HighSchoolPresentation.focusDetail(focus),
                focus.rawValue
            )
            XCTAssertEqual(
                koreanResolver.resolve(focus.tradeoffCopyToken),
                expectedFocusTradeoffs[focus],
                focus.rawValue
            )
        }

        for descriptor in TrainingPresentationCatalog.outlookDescriptors {
            let expected: String = switch descriptor.outlook {
            case .wall: "지금은 재능의 벽에 막혀 수치가 오르지 않습니다. 대신 계속 두드리면 벽이 열립니다."
            case .none: "이대로면 성장 없이 지나갑니다. 피로가 높거나 강도가 약합니다."
            case .zeroOrOne: "+1이 나올 수도, 성장 없이 지날 수도 있습니다."
            case .one: "+1이 확실한 훈련입니다."
            case .oneOrTwo: "+1은 확실하고, 잘 풀리면 +2까지 오릅니다."
            case .two: "크게 오를 훈련입니다. +2가 유력합니다."
            }
            XCTAssertEqual(koreanResolver.resolve(descriptor.token), expected, descriptor.token.key)
            assertNoHangul(englishResolver.resolve(descriptor.token), descriptor.token.key)
        }

        for focus in TrainingFocus.allCases {
            let reasons = expectedOpportunityReasons(for: focus)
            for (slot, reason) in reasons.enumerated() {
                let snapshot = TrainingOpportunitySnapshot(focus: focus, reason: reason)
                let descriptor = snapshot.copyDescriptor
                let entry = try XCTUnwrap(contentEntries[descriptor.token.key], descriptor.token.key)
                XCTAssertEqual(koreanResolver.resolve(descriptor.token), reason, descriptor.token.key)
                XCTAssertEqual(koreanResolver.resolve(descriptor.token), entry.korean, descriptor.token.key)
                XCTAssertEqual(englishResolver.resolve(descriptor.token), entry.english, descriptor.token.key)
                XCTAssertEqual(descriptor.reasonSlot, slot, descriptor.token.key)
                assertNoHangul(entry.english, descriptor.token.key)
            }

            let unknownRaw = "legacy opportunity reason 한국어"
            let fallback = TrainingOpportunitySnapshot(focus: focus, reason: unknownRaw).copyDescriptor
            let fallbackEntry = try XCTUnwrap(contentEntries[fallback.token.key], fallback.token.key)
            XCTAssertTrue(fallback.isFallback, focus.rawValue)
            XCTAssertEqual(koreanResolver.resolve(fallback.token), fallbackEntry.korean, focus.rawValue)
            XCTAssertFalse(englishResolver.resolve(fallback.token).contains(unknownRaw), focus.rawValue)
            assertNoHangul(englishResolver.resolve(fallback.token), focus.rawValue)
        }
    }

    @MainActor
    func testUnknownLegacyTrainingReceiptUsesEnglishSafeSemanticFallbacks() throws {
        let contentEntries = try gameContentEntries()
        let localizable = try localizableEntries()
        let resolver = GameCopyResolver(
            language: .english,
            catalog: [
                .korean: Dictionary(uniqueKeysWithValues: contentEntries.map { ($0.key, $0.value.korean) }
                    + localizable.map { ($0.key, $0.value.korean) }),
                .english: Dictionary(uniqueKeysWithValues: contentEntries.map { ($0.key, $0.value.english) }
                    + localizable.map { ($0.key, $0.value.english) }),
            ],
            policy: .releaseSafe
        )
        let rawHeadline = "구위 +999 · 오래된 한국어 결과"
        let rawDetail = "오래된 한국어 영수증 문구"
        let receipt = HighSchoolCareerStore.TrainingReceipt(
            focus: .velocity,
            headline: rawHeadline,
            detail: rawDetail,
            gains: [],
            growth: 0,
            jackpot: false,
            bloom: nil,
            fatigueAfter: 32,
            fatigueChange: 0,
            opportunityHit: false
        )

        let detail = HighSchoolPresentation.localizedTrainingResultDetail(receipt, resolver: resolver)
        let headline = HighSchoolPresentation.localizedTrainingResultHeadline(receipt, resolver: resolver)
        XCTAssertFalse(detail.contains(rawDetail))
        XCTAssertFalse(headline.contains(rawHeadline))
        assertNoHangul(detail, "unknown receipt detail")
        assertNoHangul(headline, "unknown receipt headline")
        XCTAssertEqual(detail, "Training complete. Check your updated ratings.")
        XCTAssertEqual(headline, "No rating change")

        let repeatReceipt = HighSchoolCareerStore.TrainingReceipt(
            focus: .command,
            headline: rawHeadline,
            detail: rawDetail,
            gains: [],
            growth: 0,
            repeatCount: 3,
            jackpot: false,
            bloom: nil,
            fatigueAfter: 32,
            fatigueChange: 0,
            opportunityHit: false
        )
        let repeatDetail = HighSchoolPresentation.localizedTrainingResultDetail(repeatReceipt, resolver: resolver)
        XCTAssertEqual(repeatDetail, "Kept the Command workout going for 3 sessions.")
        assertNoHangul(repeatDetail, "repeat receipt detail")

        let koreanResolver = GameCopyResolver(
            language: .korean,
            catalog: [
                .korean: Dictionary(uniqueKeysWithValues: contentEntries.map { ($0.key, $0.value.korean) }
                    + localizable.map { ($0.key, $0.value.korean) }),
                .english: Dictionary(uniqueKeysWithValues: contentEntries.map { ($0.key, $0.value.english) }
                    + localizable.map { ($0.key, $0.value.english) }),
            ],
            policy: .releaseSafe
        )
        let knownKoreanDetail = "이번 훈련에서는 능력치가 오르지 않았습니다. 피로와 훈련 강도를 조절해 다시 시도할 수 있습니다."
        let knownKoreanReceipt = HighSchoolCareerStore.TrainingReceipt(
            focus: .velocity,
            headline: "능력 변화 없음",
            detail: knownKoreanDetail,
            gains: [],
            growth: 0,
            jackpot: false,
            bloom: nil,
            fatigueAfter: 32,
            fatigueChange: 0,
            opportunityHit: false
        )
        XCTAssertEqual(
            HighSchoolPresentation.localizedTrainingResultDetail(knownKoreanReceipt, resolver: koreanResolver),
            knownKoreanDetail
        )
    }

    func testBoundedBatchViewsDoNotRenderLegacyRawPresentationFields() throws {
        let chapterBlock = try IOSSourceScan.typeBody(
            "ChapterHeader",
            in: "apps/ios/Sources/HighSchoolChapterHeaderViews.swift"
        )
        XCTAssertFalse(chapterBlock.contains("state.chapter.title"))
        XCTAssertFalse(chapterBlock.contains("state.chapter.season"))
        XCTAssertFalse(chapterBlock.contains("state.school.name"))
        let rawWindFieldPattern = try NSRegularExpression(pattern: #"\bwind\.(title|detail|effectDescriptions)\b"#)
        XCTAssertNil(
            rawWindFieldPattern.firstMatch(
                in: chapterBlock,
                range: NSRange(location: 0, length: chapterBlock.utf16.count)
            )
        )
        XCTAssertTrue(chapterBlock.contains("CareerWindPresentationCatalog.descriptor"))
        XCTAssertTrue(chapterBlock.contains("chapterCopy.titleToken"))
        XCTAssertTrue(chapterBlock.contains("chapterCopy.seasonToken"))

        let resultBlock = try IOSSourceScan.typeBody(
            "TrainingResultPanel",
            in: "apps/ios/Sources/HighSchoolTrainingResultViews.swift"
        )
        XCTAssertFalse(resultBlock.contains("receipt.headline"))
        XCTAssertFalse(resultBlock.contains("receipt.detail"))
        XCTAssertFalse(resultBlock.contains("gain.label"))
        XCTAssertTrue(resultBlock.contains("localizedTrainingResultDetail"))
        XCTAssertTrue(resultBlock.contains("localizedTrainingGainRow"))

        let relationshipBlock = try IOSSourceScan.typeBody(
            "RelationshipCard",
            in: "apps/ios/Sources/HighSchoolRelationshipViews.swift"
        )
        for forbidden in [
            "event.title", "event.summary", "scene?.choices", ".quote(",
            "school.coachName", "school.catcherName", "state.rival.name",
            "wind.title", "wind.detail", "wind.effectDescriptions",
            "어떻게 답할까요", "믿음 변화", "실패하면 믿음 손실",
        ] {
            XCTAssertFalse(relationshipBlock.contains(forbidden), forbidden)
        }
        XCTAssertTrue(relationshipBlock.contains("RelationshipPresentationCatalog"))
        XCTAssertTrue(relationshipBlock.contains("localizedRelationshipQuote"))
        XCTAssertTrue(relationshipBlock.contains("localizedRelationshipWindLine"))
        XCTAssertTrue(relationshipBlock.contains("relationshipPortraitSeed"))
    }

    func testPrologueViewSourceDoesNotRenderLegacyRawPresentationFields() throws {
        let prologueBlock = try IOSSourceScan.typeBody(
            "PrologueCard",
            in: "apps/ios/Sources/HighSchoolPrologueViews.swift"
        )

        for forbidden in [
            "state.news", "hasPrefix", "HighSchoolPresentation.karma",
        ] {
            XCTAssertFalse(prologueBlock.contains(forbidden), forbidden)
        }
        let rawWindFieldPattern = try NSRegularExpression(pattern: #"\bwind\.(title|detail|effectDescriptions)\b"#)
        XCTAssertNil(
            rawWindFieldPattern.firstMatch(
                in: prologueBlock,
                range: NSRange(location: 0, length: prologueBlock.utf16.count)
            )
        )
        XCTAssertTrue(prologueBlock.contains("CareerWindPresentationCatalog.descriptor"))
        XCTAssertTrue(prologueBlock.contains("ProloguePresentationCatalog.opener"))
        XCTAssertTrue(prologueBlock.contains("TrainingFocus.velocity.displayCopyToken"))
        XCTAssertTrue(prologueBlock.contains("TrainingFocus.command.displayCopyToken"))
        XCTAssertTrue(prologueBlock.contains("TrainingFocus.breakingBall.displayCopyToken"))
        XCTAssertTrue(prologueBlock.contains("TrainingFocus.stamina.displayCopyToken"))
    }

    func testNextHighSchoolBatchCatalogHasExactKoreanParityAndCompleteEnglish() throws {
        let contentEntries = try gameContentEntries()
        let localizableEntries = try localizableEntries()
        XCTAssertTrue(
            Set(contentEntries.keys).isDisjoint(with: Set(localizableEntries.keys)),
            "a semantic copy key must belong to exactly one catalog"
        )

        let staticExpected: [GameCopyKey: [String]] = [
            AppCopyKey.chapterReviewCardTitle: ["%@ 마무리", "%@ Review"],
            AppCopyKey.chapterReviewStatLine: ["고교 공식 경기 %lld회 · %lld탈삼진 · %lld볼넷", "Official high-school games: %lld · %lld strikeouts · %lld walks"],
            AppCopyKey.chapterReviewGrowthTitle: ["이번 이야기의 성장", "Growth in This Story"],
            AppCopyKey.chapterReviewGrowthEmptyNoTraining: ["훈련 없이 지나간 시기입니다.", "You moved through this stretch without training."],
            AppCopyKey.chapterReviewGrowthEmptyWithTraining: ["훈련 %lld회 — 아직 숫자로 드러나지 않은 성장입니다.", "You trained %lld times, but the growth has not shown up in the numbers yet."],
            AppCopyKey.chapterReviewGrowthSummary: ["훈련 %lld회의 결과입니다.", "This reflects %lld training sessions."],
            AppCopyKey.chapterReviewAbilitiesTitle: ["능력", "Abilities"],
            AppCopyKey.chapterReviewAbilityAccessibility: ["%@ %lld. 재능 %@, 한계 %lld. %@", "%@ %lld. Talent %@, ceiling %lld. %@."],
            AppCopyKey.chapterReviewNextStoryRival: ["다음 이야기 — 상대는 더 강해집니다. %@도 이 시기를 지켜봤습니다.", "Next story — the competition gets tougher. %@ was watching this stretch too."],
            AppCopyKey.chapterReviewContinue: ["다음 이야기로", "Continue to the next story"],
            AppCopyKey.tournamentAceStart: ["에이스 등판 — %@", "Ace start — %@"],
            AppCopyKey.tournamentDash: ["—", "—"],
            AppCopyKey.tournamentNationalNote: ["전국 8팀. 스카우트들은 이런 무대의 공 하나를 오래 기억합니다.", "Eight teams from across the country. Scouts remember a single pitch on a stage like this."],
            AppCopyKey.chapterGoalCompleted: ["완수 — 숙제는 끝났고, 다음은 욕심의 영역입니다.", "Complete — the assignment is done. Anything more is ambition."],
            AppCopyKey.chapterGoalProgress: ["%lld/%lld", "%lld/%lld"],
        ]
        let staticKeys = AppCopyKey.chapterReviewKeys + AppCopyKey.tournamentKeys + AppCopyKey.chapterGoalKeys
        XCTAssertEqual(Set(staticExpected.keys), Set(staticKeys))
        XCTAssertEqual(staticKeys.count, Set(staticKeys).count)
        for key in staticKeys {
            let expected = try XCTUnwrap(staticExpected[key], key.rawValue)
            let entry = try XCTUnwrap(localizableEntries[key.rawValue], key.rawValue)
            XCTAssertEqual(entry.korean, expected[0], key.rawValue)
            XCTAssertEqual(entry.english, expected[1], key.rawValue)
            XCTAssertFalse(entry.english.isEmpty, key.rawValue)
            assertNoHangul(entry.english, key.rawValue)
            XCTAssertEqual(
                GameCopyResolver.placeholderKinds(in: entry.korean),
                GameCopyResolver.placeholderKinds(in: entry.english),
                key.rawValue
            )
        }

        let expectedGoalFrames: [ChapterGoal.Frame: [String]] = [
            .coachAssignment: ["감독의 숙제", "감독이 지나가듯 말했다 — 이번 이야기에 삼진 %lld개는 잡아 보라고."],
            .scoutAttention: ["스카우트의 시선", "관중석 뒤편의 수첩이 이번 이야기 탈삼진 %lld개를 기다립니다."],
            .catcherBet: ["포수의 내기", "포수가 장비를 챙기며 웃었다 — 이번 이야기 삼진 %lld개, 내기할까?"],
            .personalPromise: ["나와의 약속", "소등 전에 적어 둔 한 줄 — 이번 이야기, 삼진 %lld개."],
        ]
        let expectedVerdicts: [ChapterReviewVerdictID: [String]] = [
            .noOfficialGames: ["마운드 밖에서 보낸 시기였습니다. 다음 무대는 공으로 말할 차례입니다.", "This chapter unfolded away from the mound. Next, it is time to let the ball do the talking."],
            .walklessStrikeouts: ["볼넷 없이 지나온 시기 — 스카우트 수첩에 밑줄이 그어졌습니다.", "You made it through without a walk. Scouts underlined your name in their notebooks."],
            .strikeoutsOutpaceWalks: ["삼진이 볼넷을 압도했습니다. 공이 소문을 내기 시작합니다.", "Strikeouts outpaced walks. Your stuff is starting to make noise."],
            .processOverNumbers: ["숫자보다 과정이 남은 시기입니다. 폼은 거짓말하지 않습니다.", "The process mattered more than the numbers this time. Your mechanics do not lie."],
        ]
        let expectedTournamentNames: [Int: [String]] = [
            2: ["청룡곡 여름 초청전", "Cheongryong Valley Summer Invitational"],
            4: ["전국 화랑기", "National Hwarang Tournament"],
            6: ["가을 왕중왕전", "Autumn Champions Tournament"],
            8: ["최후의 여름 — 전국 선수권", "Last Summer — National Championship"],
        ]
        let expectedRounds: [String: [String]] = [
            "8강": ["8강", "Quarterfinal"],
            "준결승": ["준결승", "Semifinal"],
            "결승": ["결승", "Final"],
        ]
        let expectedSchools: [String: [String]] = [
            "북부상고": ["북부상고", "Northern Commerce High"],
            "남해정보고": ["남해정보고", "Namhae Information High"],
            "동성공고": ["동성공고", "Dongsung Technical High"],
            "서령고": ["서령고", "Seoryeong High"],
            "중앙체고": ["중앙체고", "Central Athletic High"],
            "한서고": ["한서고", "Hanseo High"],
            "대양고": ["대양고", "Daeyang High"],
            "청암고": ["청암고", "Cheongam High"],
            "금강고": ["금강고", "Geumgang High"],
            "삼도고": ["삼도고", "Samdo High"],
            "백파고": ["백파고", "Baekpa High"],
            "운암공고": ["운암공고", "Unam Technical High"],
        ]

        let highSchoolContentKeys = Set(
            contentEntries.keys.filter {
                $0.hasPrefix("content.chapter-goal.")
                    || $0.hasPrefix("content.chapter-review.")
                    || $0.hasPrefix("content.tournament.")
            }
        )
        let expectedHighSchoolContentKeys = Set(
            ChapterGoalPresentationCatalog.descriptors.flatMap { [$0.titleToken.key, $0.detailToken.key] }
                + ChapterReviewPresentationCatalog.verdictDescriptors.map(\.token.key)
                + TournamentPresentationCatalog.tournamentNameDescriptors.map(\.token.key)
                + TournamentPresentationCatalog.roundDescriptors.map(\.token.key)
                + TournamentPresentationCatalog.opponentSchoolDescriptors.map(\.token.key)
        )
        XCTAssertEqual(highSchoolContentKeys, expectedHighSchoolContentKeys)

        for descriptor in ChapterGoalPresentationCatalog.descriptors {
            let expected = try XCTUnwrap(expectedGoalFrames[descriptor.frame])
            for (token, expectedValue) in zip([descriptor.titleToken, descriptor.detailToken], expected) {
                let entry = try XCTUnwrap(contentEntries[token.key], token.key)
                XCTAssertEqual(entry.korean, expectedValue, token.key)
                XCTAssertFalse(entry.english.isEmpty, token.key)
                assertNoHangul(entry.english, token.key)
                XCTAssertEqual(
                    GameCopyResolver.placeholderKinds(in: entry.korean),
                    GameCopyResolver.placeholderKinds(in: entry.english),
                    token.key
                )
            }
        }
        for descriptor in ChapterReviewPresentationCatalog.verdictDescriptors {
            let expected = try XCTUnwrap(expectedVerdicts[descriptor.id])
            let entry = try XCTUnwrap(contentEntries[descriptor.token.key], descriptor.token.key)
            XCTAssertEqual(entry.korean, expected[0], descriptor.token.key)
            XCTAssertEqual(entry.english, expected[1], descriptor.token.key)
            assertNoHangul(entry.english, descriptor.token.key)
        }
        for descriptor in TournamentPresentationCatalog.tournamentNameDescriptors {
            let entry = try XCTUnwrap(contentEntries[descriptor.token.key], descriptor.token.key)
            let expected = try XCTUnwrap(expectedTournamentNames[descriptor.chapterNumber])
            XCTAssertEqual(entry.korean, expected[0], descriptor.token.key)
            XCTAssertEqual(entry.english, expected[1], descriptor.token.key)
            assertNoHangul(entry.english, descriptor.token.key)
        }
        for descriptor in TournamentPresentationCatalog.roundDescriptors {
            let entry = try XCTUnwrap(contentEntries[descriptor.token.key], descriptor.token.key)
            let expected = try XCTUnwrap(expectedRounds[descriptor.rawValue])
            XCTAssertEqual(entry.korean, expected[0], descriptor.token.key)
            XCTAssertEqual(entry.english, expected[1], descriptor.token.key)
            assertNoHangul(entry.english, descriptor.token.key)
        }
        for descriptor in TournamentPresentationCatalog.opponentSchoolDescriptors {
            let entry = try XCTUnwrap(contentEntries[descriptor.token.key], descriptor.token.key)
            let expected = try XCTUnwrap(expectedSchools[descriptor.rawSchoolName])
            XCTAssertEqual(entry.korean, expected[0], descriptor.token.key)
            XCTAssertEqual(entry.english, expected[1], descriptor.token.key)
            assertNoHangul(entry.english, descriptor.token.key)
        }

        let koreanCatalog = Dictionary(uniqueKeysWithValues: contentEntries.map { ($0.key, $0.value.korean) }
            + localizableEntries.map { ($0.key, $0.value.korean) })
        let englishCatalog = Dictionary(uniqueKeysWithValues: contentEntries.map { ($0.key, $0.value.english) }
            + localizableEntries.map { ($0.key, $0.value.english) })
        let koreanResolver = GameCopyResolver(
            language: .korean,
            catalog: [.korean: koreanCatalog, .english: englishCatalog],
            policy: .releaseSafe
        )
        let englishResolver = GameCopyResolver(
            language: .english,
            catalog: [.korean: koreanCatalog, .english: englishCatalog],
            policy: .releaseSafe
        )
        let performance = CareerPerformanceSnapshot(
            importantGamesCompleted: 2,
            strikeouts: 5,
            walks: 1,
            runsAllowed: 0
        )
        let chapter = CareerChapterSnapshot(
            number: 2, title: "첫 번째 증명", schoolYear: 1, season: "여름", theme: ""
        )
        XCTAssertEqual(
            HighSchoolPresentation.localizedChapterReviewTitle(chapter, resolver: koreanResolver),
            "첫 번째 증명 마무리"
        )
        XCTAssertEqual(
            HighSchoolPresentation.localizedChapterReviewTitle(chapter, resolver: englishResolver),
            "First Proof Review"
        )
        XCTAssertEqual(
            HighSchoolPresentation.localizedChapterReviewVerdict(performance, resolver: koreanResolver),
            expectedVerdicts[.strikeoutsOutpaceWalks]![0]
        )
        XCTAssertEqual(
            HighSchoolPresentation.localizedChapterReviewVerdict(performance, resolver: englishResolver),
            expectedVerdicts[.strikeoutsOutpaceWalks]![1]
        )
        XCTAssertEqual(
            HighSchoolPresentation.localizedChapterReviewStatLine(performance, resolver: koreanResolver),
            "고교 공식 경기 2회 · 5탈삼진 · 1볼넷"
        )
        XCTAssertEqual(
            HighSchoolPresentation.localizedChapterReviewStatLine(performance, resolver: englishResolver),
            "Official high-school games: 2 · 5 strikeouts · 1 walks"
        )
        XCTAssertEqual(
            HighSchoolPresentation.localizedChapterReviewGrowthEmpty(trainingCount: 0, resolver: koreanResolver),
            "훈련 없이 지나간 시기입니다."
        )
        XCTAssertEqual(
            HighSchoolPresentation.localizedChapterReviewGrowthEmpty(trainingCount: 2, resolver: englishResolver),
            "You trained 2 times, but the growth has not shown up in the numbers yet."
        )
        XCTAssertEqual(
            HighSchoolPresentation.localizedChapterReviewGrowthSummary(trainingCount: 4, resolver: koreanResolver),
            "훈련 4회의 결과입니다."
        )
        let rival = RivalSnapshot(
            id: "rival-seo", name: "서하준", archetype: "천재 교타형", contact: 40,
            discipline: 40, power: 40
        )
        XCTAssertEqual(
            HighSchoolPresentation.localizedChapterReviewRivalLine(rival, resolver: koreanResolver),
            "다음 이야기 — 상대는 더 강해집니다. 서하준도 이 시기를 지켜봤습니다."
        )
        XCTAssertEqual(
            HighSchoolPresentation.localizedChapterReviewRivalLine(rival, resolver: englishResolver),
            "Next story — the competition gets tougher. Ha-jun Seo was watching this stretch too."
        )

        let gains = ["구위": 1, "제구": 3, "변화구": 3, "체력": 2]
        let rows = HighSchoolPresentation.localizedChapterReviewGainRows(gains, resolver: englishResolver)
        XCTAssertEqual(rows.map(\.delta), [3, 3, 2, 1])
        XCTAssertEqual(Set(rows.map(\.id)), Set(["command", "movement", "stamina", "stuff"]))
        XCTAssertEqual(
            Dictionary(uniqueKeysWithValues: rows.map { ($0.id, $0.label) }),
            ["command": "Command", "movement": "Breaking ball", "stamina": "Stamina", "stuff": "Stuff"]
        )

        let catcherGoal = ChapterGoal.Goal(
            title: "무시되는 legacy title", detail: "무시되는 legacy detail", targetStrikeouts: 7, frame: .catcherBet
        )
        XCTAssertEqual(
            HighSchoolPresentation.localizedChapterGoalTitle(catcherGoal, resolver: koreanResolver),
            "포수의 내기"
        )
        XCTAssertEqual(
            HighSchoolPresentation.localizedChapterGoalDetail(catcherGoal, resolver: koreanResolver),
            "포수가 장비를 챙기며 웃었다 — 이번 이야기 삼진 7개, 내기할까?"
        )
        XCTAssertEqual(
            HighSchoolPresentation.localizedChapterGoalDetail(catcherGoal, resolver: englishResolver),
            "The catcher grinned while packing the gear. Want to bet on 7 strikeouts this stretch?"
        )
        XCTAssertEqual(
            HighSchoolPresentation.localizedChapterGoalProgress(progress: 2, targetStrikeouts: 7, resolver: englishResolver),
            "2/7"
        )

        XCTAssertEqual(
            HighSchoolPresentation.localizedTournamentName(chapterNumber: 2, resolver: koreanResolver),
            "청룡곡 여름 초청전"
        )
        XCTAssertEqual(
            HighSchoolPresentation.localizedTournamentName(chapterNumber: 2, resolver: englishResolver),
            "Cheongryong Valley Summer Invitational"
        )
        XCTAssertEqual(
            HighSchoolPresentation.localizedTournamentAceStart(round: "8강", resolver: koreanResolver),
            "에이스 등판 — 8강"
        )
        XCTAssertEqual(
            HighSchoolPresentation.localizedTournamentAceStart(round: "8강", resolver: englishResolver),
            "Ace start — Quarterfinal"
        )
        XCTAssertEqual(
            HighSchoolPresentation.localizedTournamentOpponentSchool(rawSchoolName: "북부상고", resolver: koreanResolver),
            "북부상고"
        )
        XCTAssertEqual(
            HighSchoolPresentation.localizedTournamentOpponentSchool(rawSchoolName: "북부상고", resolver: englishResolver),
            "Northern Commerce High"
        )
        assertNoHangul(
            HighSchoolPresentation.localizedTournamentOpponentSchool(rawSchoolName: "북부상고", resolver: englishResolver),
            "English tournament opponent"
        )
    }

    private func gameContentEntries() throws -> [String: CatalogEntry] {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = repositoryRoot
            .appendingPathComponent("apps/ios/Sources/Localization/GameContent.xcstrings")
        let object = try JSONSerialization.jsonObject(with: Data(contentsOf: url))
        let root = try XCTUnwrap(object as? [String: Any])
        let strings = try XCTUnwrap(root["strings"] as? [String: Any])

        var result: [String: CatalogEntry] = [:]
        for (key, rawValue) in strings {
            guard let value = rawValue as? [String: Any],
                  let localizations = value["localizations"] as? [String: Any],
                  let korean = Self.stringUnitValue(localizations["ko"]),
                  let english = Self.stringUnitValue(localizations["en"]) else {
                continue
            }
            result[key] = CatalogEntry(korean: korean, english: english)
        }
        return result
    }

    private func localizableEntries() throws -> [String: CatalogEntry] {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = repositoryRoot
            .appendingPathComponent("apps/ios/Sources/Localization/Localizable.xcstrings")
        let object = try JSONSerialization.jsonObject(with: Data(contentsOf: url))
        let root = try XCTUnwrap(object as? [String: Any])
        let strings = try XCTUnwrap(root["strings"] as? [String: Any])

        var result: [String: CatalogEntry] = [:]
        for (key, rawValue) in strings {
            guard let value = rawValue as? [String: Any],
                  let localizations = value["localizations"] as? [String: Any],
                  let korean = Self.stringUnitValue(localizations["ko"]),
                  let english = Self.stringUnitValue(localizations["en"]) else {
                continue
            }
            result[key] = CatalogEntry(korean: korean, english: english)
        }
        return result
    }

    private func allLocalizationEntries() throws -> [String: CatalogEntry] {
        var result = try gameContentEntries()
        for (key, value) in try localizableEntries() {
            result[key] = value
        }
        return result
    }

    private func expectedHighSchoolSetupKoreanCopy() -> [GameCopyKey: String] {
        [
            AppCopyKey.setupQuickRebirthTitle: "바로 환생",
            AppCopyKey.setupQuickRebirthSummary: "%@ · %@ · 지난 선수와 같은 설정",
            AppCopyKey.setupQuickRebirthAction: "같은 설정으로 다시 태어나기",
            AppCopyKey.setupQuickRebirthHint: "계승 상점을 쓰려면 아래에서 단계대로 진행하세요.",
            AppCopyKey.setupProgressRebirth: "%lld번째 선수 · %lld / %lld",
            AppCopyKey.setupProgressFirst: "선수 만들기 · %lld / %lld",
            AppCopyKey.setupNameTitleRebirth: "다시 태어날 이름을 정하세요",
            AppCopyKey.setupNameTitleFirst: "선수의 이름을 정하세요",
            AppCopyKey.setupNameDescription: "고교 3년 동안 이 이름으로 불립니다.",
            AppCopyKey.setupNameDefault: "이름",
            AppCopyKey.setupNameSuggestionAction: "%@ 쓰기",
            AppCopyKey.setupSeedPlaceholder: "시드 또는 카드 공유 코드 (선택)",
            AppCopyKey.setupSeedError: "숫자 시드나 카드에 적힌 공유 코드를 그대로 입력해 주세요.",
            AppCopyKey.setupSeedChallengeSummary: "기록 없는 도전 — %lld번째 선수와 같은 조건을 계승 도움 없이 엽니다. 결과는 선수 기록·계승 포인트에 남지 않습니다.",
            AppCopyKey.setupSeedSummary: "숫자만 입력하면 지금 만들 %lld번째 선수의 조건입니다. 카드와 똑같이 도전하려면 카드의 공유 코드를 입력하세요.",
            AppCopyKey.setupStadiumCaption: "이 이름이 3년 동안 이 구장에서 불립니다.",
            AppCopyKey.setupRebirthCaption: "전생의 기억이 새 이름을 기다립니다.",
            AppCopyKey.setupInheritanceTitle: "가져온 것",
            AppCopyKey.setupInheritancePoints: "계승 포인트 %lld",
            AppCopyKey.setupInheritanceAutomaticGrowth: "지난 선수들이 남긴 누적 포인트 중 이번 선수 능력에 자동 성장 +%lld · 계승 상점에서 쓸 수 있는 포인트 %lld",
            AppCopyKey.setupInheritanceNextStep: "계승 포인트 %lldP를 모으면 +%lld · 최대 +20",
            AppCopyKey.setupInheritanceMaxed: "자동 성장은 최대치(+20)에 닿았습니다.",
            AppCopyKey.setupInheritanceEmptyMemories: "가져온 기억이 없습니다.",
            AppCopyKey.setupInheritanceLegacy: "대표 유산 · %@",
            AppCopyKey.setupInheritanceShopTitle: "계승 상점",
            AppCopyKey.setupInheritanceShopDescription: "계승 포인트는 이전 선수의 커리어가 다음 선수에게 남긴 보상입니다. 여기서 이번 고교 3년에 적용할 규칙을 사고, 이미 쌓인 자동 성장 보너스는 줄지 않습니다.",
            AppCopyKey.setupBoostTalentBreakTitle: "재능 돌파",
            AppCopyKey.setupBoostTalentBreakDetail: "가장 낮은 재능 등급이 한 단계 열린 채 시작합니다.",
            AppCopyKey.setupBoostExtraMemoryTitle: "넓어진 유산의 시야",
            AppCopyKey.setupBoostExtraMemoryDetail: "이번 선수가 은퇴할 때 대표 유산 후보를 하나 더 발견합니다.",
            AppCopyKey.setupBoostHeadStartTitle: "조기 성장",
            AppCopyKey.setupBoostHeadStartDetail: "자동 스며듦 상한 너머로 +5가 추가로 스며듭니다.",
            AppCopyKey.setupBoostTrainingRhythmTitle: "성장 리듬",
            AppCopyKey.setupBoostTrainingRhythmDetail: "이번 고교 3년의 훈련 대성공 확률이 16% → 26%가 됩니다.",
            AppCopyKey.setupBoostCost: "%lldP",
            AppCopyKey.setupRegionTitle: "어느 지역에서 시작할까요?",
            AppCopyKey.setupRegionDescription: "중학교 마지막 대회를 치른 지역입니다. 이 지역의 네 고교가 손을 내밉니다.",
            AppCopyKey.setupStyleTitle: "어떤 공을 던지는 투수인가요?",
            AppCopyKey.setupStyleDescription: "시작 능력치만 다릅니다. 3년 동안의 훈련으로 얼마든지 바뀝니다.",
            AppCopyKey.setupHandicapTitle: "이번 고교 3년을 얼마나 어렵게 갈까요?",
            AppCopyKey.setupDifficultyTitle: "난이도",
            AppCopyKey.setupChallengeTitle: "같은 조건으로 겨루는 도전",
            AppCopyKey.setupChallengeDescription: "지난 선수의 기억·대표 유산·계승 포인트·핸디캡은 쓰지 않습니다. 고른 난이도와 직접 투구만 이 판에 반영됩니다.",
            AppCopyKey.setupLegacyTitle: "이번 선수에게 이어 줄 대표 유산",
            AppCopyKey.setupLegacyDescription: "지난 선수들이 남긴 강점 중 하나만 직접 이어집니다. 다른 유산은 사라지지 않고 다음에도 다시 고를 수 있습니다.",
            AppCopyKey.setupSoulDomainTitle: "자동 성장 포인트 %lldP를 어디에",
            AppCopyKey.setupSoulDomainRule: "고른 쪽에 절반이 먼저 가고, 나머지는 가장 낮은 능력부터 채웁니다. 재능의 한계는 넘지 않습니다.",
            AppCopyKey.setupHandicapLabel: "핸디캡",
            AppCopyKey.setupHandicapDescription: "최대 2개. 고르면 이번 고교 3년이 어려워집니다. 대신 새 선수가 이어받는 힘이 커집니다. 지금 +%lld%%",
            AppCopyKey.setupKarmaReward: "+%lld%%",
            AppCopyKey.setupSeedValidation: "시드 입력을 확인해 주세요 — %@",
            AppCopyKey.setupStartChallenge: "기록 없는 도전 시작",
            AppCopyKey.setupStartRebirth: "다시 태어나기",
            AppCopyKey.setupStartFirst: "고교 1학년 시작",
            AppCopyKey.setupActionNext: "다음",
            AppCopyKey.setupActionBack: "뒤로",
            AppCopyKey.setupKarmaCapacityHint: "핸디캡은 두 개까지 고를 수 있습니다. 다른 것을 빼면 고를 수 있습니다.",
            AppCopyKey.setupStatStuff: "구위",
            AppCopyKey.setupStatCommand: "제구",
            AppCopyKey.setupStatMovement: "변화구",
            AppCopyKey.setupStatStamina: "체력",
            AppCopyKey.setupSoulDomainBody: "몸",
            AppCopyKey.setupSoulDomainTechnique: "기술",
            AppCopyKey.setupSoulDomainGame: "경기 운영",
            AppCopyKey.setupSoulDomainBodyDetail: "구위와 체력에 먼저 들어갑니다. 긴 이닝을 버티는 쪽입니다.",
            AppCopyKey.setupSoulDomainTechniqueDetail: "제구와 변화구에 먼저 들어갑니다. 원하는 곳에 꽂는 쪽입니다.",
            AppCopyKey.setupSoulDomainGameDetail: "제구와 타자 상대법에 먼저 들어갑니다. 수 싸움으로 버티는 쪽입니다.",
            AppCopyKey.setupDifficultyRelaxed: "여유롭게",
            AppCopyKey.setupDifficultyStandard: "보통",
            AppCopyKey.setupDifficultyChallenging: "혹독하게",
            AppCopyKey.setupKarmaUnknownLandTitle: "낯선 땅",
            AppCopyKey.setupKarmaUnknownLandDetail: "연고가 없는 지역에서 시작합니다.",
            AppCopyKey.setupKarmaStubbornCoachTitle: "고집 센 감독",
            AppCopyKey.setupKarmaStubbornCoachDetail: "감독의 믿음을 얻기가 어렵습니다.",
            AppCopyKey.setupKarmaSingleWeaponTitle: "단 하나의 무기",
            AppCopyKey.setupKarmaSingleWeaponDetail: "구종 하나에만 기댈 수 있습니다.",
            AppCopyKey.setupKarmaGeniusGenerationTitle: "천재들의 세대",
            AppCopyKey.setupKarmaGeniusGenerationDetail: "같은 학년에 뛰어난 투수가 많습니다.",
            AppCopyKey.setupKarmaErasedMemoryTitle: "지워진 기억",
            AppCopyKey.setupKarmaErasedMemoryDetail: "가져갈 기억 카드가 줄어듭니다.",
            AppCopyKey.setupKarmaNoLastChanceTitle: "마지막 기회는 없다",
            AppCopyKey.setupKarmaNoLastChanceDetail: "부상 한 번이 커리어를 끝낼 수 있습니다.",
            AppCopyKey.setupSignatureEffectNone: "시작 능력 변화 없음",
            AppCopyKey.setupSignatureEffectStuff: "구위 +%lld",
            AppCopyKey.setupSignatureEffectCommand: "제구 +%lld",
            AppCopyKey.setupSignatureEffectMovement: "변화구 +%lld",
            AppCopyKey.setupSignatureEffectStamina: "체력 +%lld",
            AppCopyKey.setupSignatureEffectStuffCommand: "구위 +%lld · 제구 +%lld",
            AppCopyKey.setupSignatureEffectStuffMovement: "구위 +%lld · 변화구 +%lld",
            AppCopyKey.setupSignatureEffectStuffStamina: "구위 +%lld · 체력 +%lld",
            AppCopyKey.setupSignatureEffectCommandMovement: "제구 +%lld · 변화구 +%lld",
            AppCopyKey.setupSignatureEffectCommandStamina: "제구 +%lld · 체력 +%lld",
            AppCopyKey.setupSignatureEffectMovementStamina: "변화구 +%lld · 체력 +%lld",
            AppCopyKey.setupSignatureEffectStuffCommandMovement: "구위 +%lld · 제구 +%lld · 변화구 +%lld",
            AppCopyKey.setupSignatureEffectStuffCommandStamina: "구위 +%lld · 제구 +%lld · 체력 +%lld",
            AppCopyKey.setupSignatureEffectStuffMovementStamina: "구위 +%lld · 변화구 +%lld · 체력 +%lld",
            AppCopyKey.setupSignatureEffectCommandMovementStamina: "제구 +%lld · 변화구 +%lld · 체력 +%lld",
            AppCopyKey.setupSignatureEffectAll: "구위 +%lld · 제구 +%lld · 변화구 +%lld · 체력 +%lld",
            AppCopyKey.setupRegionSeoulName: "서울",
            AppCopyKey.setupRegionIncheonName: "인천",
            AppCopyKey.setupRegionSuwonName: "수원",
            AppCopyKey.setupRegionDaejeonName: "대전",
            AppCopyKey.setupRegionGwangjuName: "광주",
            AppCopyKey.setupRegionDaeguName: "대구",
            AppCopyKey.setupRegionBusanName: "부산",
            AppCopyKey.setupRegionChangwonName: "창원",
            AppCopyKey.setupRegionUlsanName: "울산",
            AppCopyKey.setupRegionSejongName: "세종",
            AppCopyKey.setupRegionGyeonggiName: "경기",
            AppCopyKey.setupRegionGangwonName: "강원",
            AppCopyKey.setupRegionChungbukName: "충북",
            AppCopyKey.setupRegionChungnamName: "충남",
            AppCopyKey.setupRegionJeonbukName: "전북",
            AppCopyKey.setupRegionJeonnamName: "전남",
            AppCopyKey.setupRegionGyeongbukName: "경북",
            AppCopyKey.setupRegionGyeongnamName: "경남",
            AppCopyKey.setupRegionJejuName: "제주",
            AppCopyKey.setupRegionSeoulFlavor: "스카우트가 가장 자주 오는 무대",
            AppCopyKey.setupRegionIncheonFlavor: "바닷바람 속 끈질긴 야구",
            AppCopyKey.setupRegionSuwonFlavor: "신흥 명문들의 각축전",
            AppCopyKey.setupRegionDaejeonFlavor: "뚝심의 원포인트 승부",
            AppCopyKey.setupRegionGwangjuFlavor: "타격의 고장, 투수엔 시련",
            AppCopyKey.setupRegionDaeguFlavor: "더위를 이기는 근성",
            AppCopyKey.setupRegionBusanFlavor: "함성이 가장 큰 관중석",
            AppCopyKey.setupRegionChangwonFlavor: "짜임새 있는 수비 야구",
            AppCopyKey.setupRegionUlsanFlavor: "묵묵히 던지는 공업 도시",
            AppCopyKey.setupRegionSejongFlavor: "역사가 짧아 기회가 많다",
            AppCopyKey.setupRegionGyeonggiFlavor: "팀 수가 가장 많은 격전지",
            AppCopyKey.setupRegionGangwonFlavor: "산바람에 단련된 어깨",
            AppCopyKey.setupRegionChungbukFlavor: "조용히 강한 다크호스",
            AppCopyKey.setupRegionChungnamFlavor: "전통 강호의 자존심",
            AppCopyKey.setupRegionJeonbukFlavor: "거친 바람의 홈그라운드",
            AppCopyKey.setupRegionJeonnamFlavor: "느리게, 그러나 확실하게",
            AppCopyKey.setupRegionGyeongbukFlavor: "전통과 자부심의 명문가",
            AppCopyKey.setupRegionGyeongnamFlavor: "남쪽 끝의 탄탄한 전력",
            AppCopyKey.setupRegionJejuFlavor: "가장 먼 곳에서 온 유망주",
        ]
    }

    private func expectedKoreanDefaultName(for presetID: String) -> String {
        switch presetID {
        case "power_prospect": return "민서준"
        case "precision_commander": return "고태윤"
        case "breaking_ball_artist": return "진서율"
        case "innings_eater": return "도하람"
        default:
            XCTFail("Unexpected pitcher preset ID: \(presetID)")
            return ""
        }
    }

    private static func stringUnitValue(_ rawValue: Any?) -> String? {
        guard let language = rawValue as? [String: Any],
              let unit = language["stringUnit"] as? [String: Any],
              let value = unit["value"] as? String else {
            return nil
        }
        return value
    }

    private func assertNoHangul(_ value: String, _ label: String) {
        XCTAssertNil(
            koreanPattern.firstMatch(
                in: value,
                range: NSRange(location: 0, length: value.utf16.count)
            ),
            label
        )
    }

    private func signedNumericModifiers(_ value: String) -> [String] {
        let pattern = try! NSRegularExpression(pattern: "[+-][0-9]+")
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        return pattern.matches(in: value, range: range).compactMap { match in
            guard let matchRange = Range(match.range, in: value) else { return nil }
            return String(value[matchRange])
        }
    }

    private func expectedOpportunityReasons(for focus: TrainingFocus) -> [String] {
        switch focus {
        case .velocity:
            return [
                "어제 불펜에서 팔 스윙이 가벼웠다. 오늘 직구를 밀어붙이자.",
                "하체 힘이 붙었다. 구속을 끌어올릴 타이밍이다.",
                "공 끝이 살아 있다. 오늘은 세게 던져 보자.",
            ]
        case .command:
            return [
                "포수가 미트를 거의 안 움직였다. 코스 훈련이 먹힐 날이다.",
                "던지는 리듬이 잡혔다. 오늘 존 구석을 노리자.",
                "밸런스가 좋다. 원하는 곳에 꽂는 연습을 늘리자.",
            ]
        case .breakingBall:
            return [
                "어제 변화구 회전이 좋았다. 오늘 확실히 내 것으로 만들자.",
                "손끝 감각이 살아 있다. 변화구를 다듬을 기회다.",
                "타자들이 변화구에 늦게 반응했다. 오늘 더 벼리자.",
            ]
        case .stamina:
            return [
                "긴 이닝을 버틸 몸을 만들 적기다.",
                "회복이 빨라졌다. 오늘 체력 훈련이 잘 붙는다.",
                "다음 등판까지 여유가 있다. 체력을 쌓자.",
            ]
        case .recovery:
            return [
                "팔이 무겁다는 신호다. 오늘은 회복이 최고의 훈련이다.",
                "쉬는 것도 실력이다. 몸을 만들 날이다.",
                "피로가 쌓였다. 오늘 회복하면 내일이 달라진다.",
            ]
        case .gamePlanning:
            return [
                "상대 타선 기록이 도착했다. 오늘 파고들자.",
                "포수와 사인을 맞출 시간이 났다. 수 싸움을 늘리자.",
                "경기 감각이 올라 있다. 상대 분석이 잘 먹힌다.",
            ]
        }
    }
}
