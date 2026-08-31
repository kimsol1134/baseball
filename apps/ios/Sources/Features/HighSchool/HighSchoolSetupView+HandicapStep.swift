import SwiftUI
import SimulationCore
import BaseballIOSDomain

extension HighSchoolSetupView {
    var handicapStep: some View {
        VStack(alignment: .leading, spacing: BaseballMetrics.stackSpacing) {
            GameCopyText(AppCopyKey.setupHandicapTitle)
                .font(.title.bold())
                .foregroundStyle(BaseballTheme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            BaseballCard(title: copyResolver.resolve(AppCopyKey.setupDifficultyTitle)) {
                HStack(spacing: 6) {
                    ForEach(DifficultyLevel.allCases, id: \.self) { level in
                        Button { harshness = level } label: {
                            GameCopyText(Self.difficultyKey(level))
                                .font(.footnote.weight(.semibold))
                                .frame(maxWidth: .infinity, minHeight: BaseballMetrics.minimumTapTarget)
                        }
                        .buttonStyle(.plain)
                        .background(
                            harshness == level ? BaseballTheme.selection.opacity(0.2) : BaseballTheme.surfaceRaised,
                            in: RoundedRectangle(cornerRadius: 8)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(harshness == level ? BaseballTheme.selection : BaseballTheme.border.opacity(0.6),
                                        lineWidth: harshness == level ? 2 : 1)
                        }
                        .accessibilityAddTraits(harshness == level ? .isSelected : [])
                        .accessibilityIdentifier("hs.setup.harshness.\(level.rawValue)")
                    }
                }
            }

            if parsedChallenge != nil {
                BaseballCard(title: copyResolver.resolve(AppCopyKey.setupChallengeTitle), tone: .milestone) {
                    GameCopyText(AppCopyKey.setupChallengeDescription)
                        .font(.footnote)
                        .foregroundStyle(BaseballTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if parsedChallenge == nil, !unlockedSignatureLegacies.isEmpty {
                BaseballCard(title: copyResolver.resolve(AppCopyKey.setupLegacyTitle), tone: .milestone) {
                    VStack(alignment: .leading, spacing: 8) {
                        GameCopyText(AppCopyKey.setupLegacyDescription)
                            .font(.footnote)
                            .foregroundStyle(BaseballTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        ForEach(unlockedSignatureLegacies) { legacy in
                            let selected = (selectedSignatureLegacyID
                                            ?? career.inheritance.equippedSignatureLegacyID) == legacy.id
                            let mastery = HighSchoolCareerStore.lineageMasteries(from: career.archive)
                                .first { $0.family == legacy.family }
                                ?? CareerLineageMastery(family: legacy.family, contributions: 0)
                            Button { selectedSignatureLegacyID = legacy.id } label: {
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: selected ? "checkmark.seal.fill" : "seal")
                                        .foregroundStyle(selected ? BaseballTheme.milestone : BaseballTheme.textTertiary)
                                    VStack(alignment: .leading, spacing: 3) {
                                        GameCopyText(verbatim: legacy.title)
                                            .font(.subheadline.weight(.bold))
                                            .foregroundStyle(BaseballTheme.textPrimary)
                                        GameCopyText(verbatim: legacy.detail)
                                            .font(.caption)
                                            .foregroundStyle(BaseballTheme.textSecondary)
                                            .fixedSize(horizontal: false, vertical: true)
                                        GameCopyText(verbatim: Self.localizedSignatureLegacyEffectLine(legacy.effect, resolver: copyResolver))
                                            .font(.caption2.weight(.semibold).monospacedDigit())
                                            .foregroundStyle(BaseballTheme.milestone)
                                        Text(verbatim: copyResolver.resolve(
                                            LegacyUICopyKey.masteryRank,
                                            arguments: [.integer(mastery.rank), .integer(mastery.contributions)]
                                        ))
                                        .font(.caption2.weight(.bold).monospacedDigit())
                                        .foregroundStyle(BaseballTheme.information)
                                        if let threshold = mastery.nextThreshold {
                                            Text(verbatim: copyResolver.resolve(
                                                LegacyUICopyKey.masteryNext,
                                                arguments: [
                                                    .integer(max(0, threshold - mastery.contributions)),
                                                    .integer(mastery.rank + 1),
                                                ]
                                            ))
                                            .font(.caption2)
                                            .foregroundStyle(BaseballTheme.textTertiary)
                                        } else {
                                            Text(verbatim: copyResolver.resolve(LegacyUICopyKey.masteryMax))
                                                .font(.caption2)
                                                .foregroundStyle(BaseballTheme.textTertiary)
                                        }
                                    }
                                    Spacer(minLength: 0)
                                }
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(selected ? BaseballTheme.milestone.opacity(0.12) : BaseballTheme.surfaceRaised,
                                            in: RoundedRectangle(cornerRadius: BaseballMetrics.controlRadius))
                                .overlay {
                                    RoundedRectangle(cornerRadius: BaseballMetrics.controlRadius)
                                        .stroke(selected ? BaseballTheme.milestone : BaseballTheme.border,
                                                lineWidth: selected ? 2 : 1)
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(selected ? .isSelected : [])
                            .accessibilityIdentifier("hs.setup.signatureLegacy.\(legacy.id.rawValue)")
                        }
                    }
                }
            }

            // 야구혼을 어디에 붓는지 고른다. 코어는 처음부터 이 값을 받았는데 화면이
            // 넘기지 않아 늘 기본값(제구)으로 갔다 — 회차마다 같은 곳만 오르는 원인 하나였다.
            if Self.showsSoulDomain(
                automaticSoulTotal: career.inheritance.automaticSoulTotal,
                isChallenge: parsedChallenge != nil
            ) {
                BaseballCard(
                    title: copyResolver.resolve(
                        AppCopyKey.setupSoulDomainTitle,
                        arguments: [.integer(career.inheritance.automaticSoulTotal)]
                    )
                ) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            ForEach(SoulDomain.allCases, id: \.self) { domain in
                                Button { soulDomain = domain } label: {
                                    GameCopyText(Self.domainKey(domain))
                                        .font(.footnote.weight(.semibold))
                                        .frame(maxWidth: .infinity, minHeight: BaseballMetrics.minimumTapTarget)
                                }
                                .buttonStyle(.plain)
                                .background(
                                    soulDomain == domain ? BaseballTheme.selection.opacity(0.2) : BaseballTheme.surfaceRaised,
                                    in: RoundedRectangle(cornerRadius: 8)
                                )
                                .overlay {
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(soulDomain == domain ? BaseballTheme.selection : BaseballTheme.border.opacity(0.6),
                                                lineWidth: soulDomain == domain ? 2 : 1)
                                }
                                .accessibilityAddTraits(soulDomain == domain ? .isSelected : [])
                            }
                        }
                        GameCopyText(Self.domainDetailKey(soulDomain))
                            .font(.caption)
                            .foregroundStyle(BaseballTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        GameCopyText(AppCopyKey.setupSoulDomainRule)
                            .font(.caption)
                            .foregroundStyle(BaseballTheme.textTertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            if parsedChallenge == nil {
                GameCopyText(AppCopyKey.setupHandicapLabel)
                    .font(.headline)
                GameCopyText(
                    AppCopyKey.setupHandicapDescription,
                    arguments: [.integer(rewardPermille / 10)]
                )
                    .font(.footnote)
                    .foregroundStyle(rewardPermille > 0 ? BaseballTheme.milestone : BaseballTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(KarmaID.allCases, id: \.self) { karma in
                    // 코어가 카르마를 2개까지만 받는다. 3개를 보내면
                    // 커리어 생성이 실패하고, 그 화면의 유일한 버튼이 진행 삭제다 — 여기서 막는다.
                    KarmaRow(
                        karma: karma,
                        selected: selectedKarmas.contains(karma),
                        atCapacity: selectedKarmas.count >= 2,
                        onToggle: {
                            if selectedKarmas.contains(karma) { selectedKarmas.remove(karma) }
                            else if selectedKarmas.count < 2 { selectedKarmas.insert(karma) }
                        }
                    )
                }
            }
        }
    }
}
