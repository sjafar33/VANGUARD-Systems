import SwiftUI

/// A full-screen lesson: Nova teaches a card, then asks. Wrong answers just try again (no lives, no timer).
/// Only first-try answers earn coins, and coins are paid once, at the end.
struct LessonView: View {
    let model: AppModel
    let lesson: Lesson
    let package: SciencePackage
    /// Called when the lesson closes. `true` means "build the unlocked building now".
    let finish: (Bool) -> Void

    @State private var index = 0
    @State private var wrongPicks: Set<Int> = []
    @State private var answered = false
    @State private var firstTryCorrect = 0
    @State private var done = false
    @State private var earned = 0
    @State private var unlockedNow = false
    @State private var firstTime = true
    @AccessibilityFocusState private var cardFocused: Bool
    @Environment(\.appReduceMotion) private var reduceMotion

    private var card: LessonCard { lesson.cards[index] }
    private var coinsPerAnswer: Int { firstTime ? BaseState.lessonCoinsPerAnswer : BaseState.lessonReplayPerAnswer }

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x0B1426), Color(hex: 0x1B2A4A)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            VStack(spacing: 14) {
                topBar
                ScrollView {
                    VStack(spacing: 16) {
                        if done {
                            finishCard
                        } else {
                            switch card {
                            case .teach(let fact): teachCard(fact)
                            case .question(let q): questionCard(q)
                            }
                        }
                    }
                    .frame(maxWidth: 620)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .onAppear {
            firstTime = model.baseState.lessons[lesson.id]?.completed != true
            speak()
        }
        .onChange(of: index) { _, _ in
            speak()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { cardFocused = true }
        }
        .onDisappear { Narrator.shared.stop() }
    }

    private func speak() {
        guard model.readAloud, !done else { return }
        switch card {
        case .teach(let fact): Narrator.shared.speak("\(fact.title). \(fact.text)")
        case .question(let q): Narrator.shared.speak("\(q.prompt) \(q.options.joined(separator: ". "))")
        }
    }

    // MARK: Top bar

    private var topBar: some View {
        HStack(spacing: 12) {
            RoundIconButton(symbol: "xmark", label: "Leave lesson", bevel: GamePalette.coral, size: 44) { finish(false) }
            VStack(alignment: .leading, spacing: 4) {
                Text(lesson.title).font(.game(.headline)).gameText().lineLimit(1)
                ProgressView(value: Double(done ? lesson.cards.count : index), total: Double(lesson.cards.count))
                    .tint(Color(hex: 0xFFD66B))
                    .accessibilityLabel("Card \(min(index + 1, lesson.cards.count)) of \(lesson.cards.count)")
            }
            CoinPill(coins: firstTryCorrect * coinsPerAnswer, label: "Moon coins earned so far")
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
    }

    // MARK: Cards

    private func teachCard(_ fact: LessonFact) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                NovaAvatar(size: 60, talking: true)
                VStack(alignment: .leading, spacing: 6) {
                    Text(fact.title)
                        .font(.game(.title3))
                        .foregroundStyle(Theme.ink)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityFocused($cardFocused)
                    Text(fact.text)
                        .font(.system(.body, design: .rounded).weight(.semibold))
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            HStack {
                Image(systemName: fact.symbol)
                    .font(.system(size: 40, weight: .black))
                    .foregroundStyle(Theme.energyInk)
                    .accessibilityHidden(true)
                Spacer()
                ReadAloudButton(enabled: model.readAloud, text: "\(fact.title). \(fact.text)", size: 40)
            }
            sourceTag(fact.sourceID, gameRule: fact.isGameRule)
            Button {
                advance()
            } label: {
                Label("Next", systemImage: "arrow.right")
            }
            .buttonStyle(GameButtonStyle(bevel: GamePalette.gold, height: 56))
        }
        .padding(18)
        .background(GameCardBackground(corner: 24))
    }

    private func questionCard(_ q: LessonQuestion) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                NovaAvatar(size: 56, talking: true)
                Text(q.prompt)
                    .font(.game(.title3))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityFocused($cardFocused)
                Spacer(minLength: 0)
                ReadAloudButton(enabled: model.readAloud, text: "\(q.prompt) \(q.options.joined(separator: ". "))", size: 40)
            }
            ForEach(q.options.indices, id: \.self) { i in
                optionButton(q, i)
            }
            if answered {
                VStack(alignment: .leading, spacing: 6) {
                    Label(wrongPicks.isEmpty ? "Yes! +\(coinsPerAnswer) Moon coins" : "Yes, that's it!",
                          systemImage: "checkmark.seal.fill")
                        .font(.game(.headline))
                        .foregroundStyle(Theme.plantInk)
                    Text(q.explanation)
                        .font(.system(.body, design: .rounded).weight(.semibold))
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    sourceTag(q.sourceID, gameRule: false)
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color(hex: 0xE9F7EC)))
                Button {
                    advance()
                } label: {
                    Label(index == lesson.cards.count - 1 ? "Finish" : "Next", systemImage: "arrow.right")
                }
                .buttonStyle(GameButtonStyle(bevel: GamePalette.gold, height: 56))
            } else if !wrongPicks.isEmpty {
                Label("Not quite. Have another look and try again!", systemImage: "lightbulb.fill")
                    .font(.system(.body, design: .rounded).weight(.heavy))
                    .foregroundStyle(Theme.amberInk)
            }
        }
        .padding(18)
        .background(GameCardBackground(corner: 24))
    }

    private func optionButton(_ q: LessonQuestion, _ i: Int) -> some View {
        let isWrong = wrongPicks.contains(i)
        let isRight = answered && i == q.correctIndex
        let bevel = isRight ? GamePalette.go : (isWrong ? GamePalette.coral : GamePalette.steel)
        let symbol = isRight ? "checkmark.circle.fill" : (isWrong ? "xmark.circle.fill" : "circle")
        return Button {
            pick(q, i)
        } label: {
            Label(q.options[i], systemImage: symbol)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(GameButtonStyle(bevel: bevel, height: 56, font: .game(.headline)))
        .disabled(answered || isWrong)
        .accessibilityLabel(q.options[i])
        .accessibilityValue(isRight ? "Correct" : (isWrong ? "Not this one" : ""))
    }

    private func pick(_ q: LessonQuestion, _ i: Int) {
        guard !answered else { return }
        if i == q.correctIndex {
            answered = true
            if wrongPicks.isEmpty { firstTryCorrect += 1 }
            Haptics.success()
            SoundFX.shared.play(.success)
            UIAccessibility.post(notification: .announcement, argument: "Correct. \(q.explanation)")
        } else {
            wrongPicks.insert(i)
            Haptics.warning()
            SoundFX.shared.play(.denied)
            UIAccessibility.post(notification: .announcement, argument: "Not quite. Try again.")
        }
    }

    private func advance() {
        if index + 1 < lesson.cards.count {
            index += 1
            wrongPicks = []
            answered = false
        } else {
            let wasFirst = model.baseState.lessons[lesson.id]?.completed != true
            earned = model.completeLesson(lesson.id, firstTryCorrect: firstTryCorrect)
            unlockedNow = wasFirst && lesson.unlocks != nil
            done = true
            Narrator.shared.stop()
            Haptics.success()
        }
    }

    @ViewBuilder private func sourceTag(_ id: String?, gameRule: Bool) -> some View {
        if gameRule {
            Label("Game rule: made up for this game, not a NASA number", systemImage: "gamecontroller.fill")
                .font(.system(.caption, design: .rounded).weight(.heavy))
                .foregroundStyle(Theme.amberInk)
                .fixedSize(horizontal: false, vertical: true)
        } else if let source = package.source(id) {
            Label("Source: \(source.title) (\(source.agency))", systemImage: "books.vertical.fill")
                .font(.system(.caption, design: .rounded).weight(.heavy))
                .foregroundStyle(Theme.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Finish

    private var finishCard: some View {
        VStack(spacing: 14) {
            Ribbon(text: "LESSON COMPLETE!", bevel: GamePalette.go, font: .game(.title2))
                .accessibilityFocused($cardFocused)
            NovaBubble(text: "You got \(firstTryCorrect) of \(lesson.questionCount) right on the first try. Great thinking!", compact: true)
            HStack(spacing: 8) {
                CoinIcon(size: 44)
                Text("+\(earned) Moon coins")
            }
            .font(.game(.title2))
            .foregroundStyle(Theme.amberInk)
            .accessibilityElement(children: .combine)
            if !firstTime {
                Text("Replays pay a little, so you can keep practising.")
                    .font(.system(.caption, design: .rounded).weight(.heavy))
                    .foregroundStyle(Theme.inkSecondary)
            }
            if unlockedNow, let kind = lesson.unlocks {
                Label("Blueprint unlocked: \(kind.name)!", systemImage: "lock.open.fill")
                    .font(.game(.headline))
                    .foregroundStyle(Theme.plantInk)
                Button {
                    finish(true)
                } label: {
                    Label("Build it now", systemImage: "hammer.fill")
                }
                .buttonStyle(GameButtonStyle(bevel: GamePalette.go, height: 58))
            }
            Button("Back to base") { finish(false) }
                .buttonStyle(GameButtonStyle(bevel: unlockedNow ? GamePalette.steel : GamePalette.go, height: 54, font: .game(.headline)))
        }
        .padding(18)
        .background(GameCardBackground(corner: 24))
        .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { cardFocused = true } }
    }
}
