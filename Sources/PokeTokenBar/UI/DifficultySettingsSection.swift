import SwiftUI

/// Local editing state. Discarding Settings discards this value without touching the store.
struct DifficultyDraft: Equatable {
    var growth: Double
    var shop: Double

    @MainActor init(companion: CompanionStore) {
        growth = companion.growthDifficulty
        shop = companion.shopDifficulty
    }

    @MainActor func differs(from companion: CompanionStore) -> Bool {
        growth != companion.growthDifficulty || shop != companion.shopDifficulty
    }

    @MainActor mutating func save(to companion: CompanionStore) {
        companion.setGrowthDifficulty(growth)
        companion.setShopDifficulty(shop)
        self = DifficultyDraft(companion: companion)
    }
}

@MainActor
struct DifficultySettingsSection: View {
    let companion: CompanionStore
    @State var draft: DifficultyDraft
    private var l: L { companion.l }

    init(companion: CompanionStore, draft: DifficultyDraft? = nil) {
        self.companion = companion
        _draft = State(initialValue: draft ?? DifficultyDraft(companion: companion))
    }

    /// A Form section: inside SettingsView's grouped Form the section draws the one card.
    var body: some View {
        Section(l.difficultySectionTitle) {
            row(l.difficultyGrowthLabel, value: $draft.growth, low: l.difficultyGrowthLowLabel, high: l.difficultyGrowthHighLabel)
            row(l.difficultyShopLabel, value: $draft.shop, low: l.difficultyShopLowLabel, high: l.difficultyShopHighLabel)
            if draft.differs(from: companion) {
                HStack {
                    Spacer()
                    Button(l.save) { draft.save(to: companion) }
                        .buttonStyle(.glassProminent)
                        .accessibilityIdentifier("saveDifficulty")
                }
            }
        }
    }

    /// Tick marks: both ends, the 100% default, and the halfway multipliers between them.
    private static let tickDifficulties: [Double] = [0.1, 0.25, 0.5, 1, 2]

    private func row(_ label: String, value: Binding<Double>, low: String, high: String) -> some View {
        // Name and value line up with the slider's center, not with the low/high labels below it.
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(label)
                .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] }
                .frame(width: 76, alignment: .leading)
            // Slider and its low/high labels share one column, so the labels sit exactly under its ends.
            VStack(spacing: 2) {
                Slider(value: Binding(
                    get: { PokemonBalance.difficultyPosition(value.wrappedValue) },
                    set: { value.wrappedValue = PokemonBalance.difficulty(atPosition: $0) }), in: 0...1) {
                    Text(label)
                } ticks: {
                    // The scale is logarithmic, so ticks sit at round multipliers rather than even steps.
                    SliderTickContentForEach(Self.tickDifficulties, id: \.self) { difficulty in
                        SliderTick(PokemonBalance.difficultyPosition(difficulty))
                    }
                }
                    // Without this the grouped Form treats the slider as a labeled control and pins it
                    // to a short fixed width in the trailing column.
                    .labelsHidden()
                    .accessibilityLabel(label)
                    .accessibilityHint(l.difficultyScaleHint(low: low, high: high))
                    .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] }
                HStack {
                    Text(low)
                    Spacer()
                    Text(high)
                }
                .font(.caption2).foregroundStyle(.secondary)
                .accessibilityHidden(true) // Read via the slider's hint instead.
            }
            .frame(maxWidth: .infinity)
            Text(l.difficultyValue(value.wrappedValue))
                .font(.caption).monospacedDigit()
                .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] }
                .frame(width: 52, alignment: .trailing)
        }
    }
}
