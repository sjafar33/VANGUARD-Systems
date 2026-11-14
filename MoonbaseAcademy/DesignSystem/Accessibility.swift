import AVFoundation
import Observation
import SwiftUI
import UIKit

// MARK: One motion policy

/// The app's single reduced-motion answer: the system setting OR the in-app Reduce motion switch.
/// Every SwiftUI view reads this instead of `accessibilityReduceMotion`, so both settings behave the same
/// everywhere. Reduced motion changes animation only; reading time and results never change.
private struct AppReduceMotionKey: EnvironmentKey {
    static let defaultValue = false
}

/// Focus view: calmer screens that keep the goal and the next action in front. Never changes results.
private struct FocusViewKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var appReduceMotion: Bool {
        get { self[AppReduceMotionKey.self] }
        set { self[AppReduceMotionKey.self] = newValue }
    }

    var focusView: Bool {
        get { self[FocusViewKey.self] }
        set { self[FocusViewKey.self] = newValue }
    }
}

// MARK: Read aloud

/// Optional narration with the on-device speech voice. Everything spoken is also on screen as text.
/// When VoiceOver is running, the narrator stays silent so the two never talk over each other
/// (VoiceOver already reads the screen and gets checkpoint announcements).
@MainActor
@Observable
final class Narrator {
    static let shared = Narrator()

    private(set) var isSpeaking = false
    private(set) var lastText = ""

    @ObservationIgnored private let synthesizer = AVSpeechSynthesizer()
    @ObservationIgnored private let delegate = SpeechDelegate()
    @ObservationIgnored private var currentID: ObjectIdentifier?

    private init() {
        synthesizer.delegate = delegate
        delegate.onEvent = { [weak self] id, speaking in
            guard let self, id == self.currentID else { return }
            self.isSpeaking = speaking
        }
    }

    /// Speaks `text`, replacing anything still being read (so stale steps never keep talking).
    func speak(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        lastText = trimmed
        stop()
        guard !UIAccessibility.isVoiceOverRunning else { return }
        let utterance = AVSpeechUtterance(string: Self.spoken(trimmed))
        // Uses an installed voice for the device language if there is one; otherwise the system default.
        // Never asks for a download and never blocks play.
        if let voice = AVSpeechSynthesisVoice(language: AVSpeechSynthesisVoice.currentLanguageCode()) {
            utterance.voice = voice
        }
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.92
        currentID = ObjectIdentifier(utterance)
        synthesizer.speak(utterance)
    }

    func repeatLast() { speak(lastText) }

    func stop() {
        currentID = nil
        isSpeaking = false
        if synthesizer.isSpeaking { synthesizer.stopSpeaking(at: .immediate) }
    }

    /// Unit symbols are read as words; the text on screen keeps the formal units.
    static func spoken(_ text: String) -> String {
        var result = text
        let words: [(String, String)] = [("kWh", "kilowatt hours"), ("kW", "kilowatts"), ("kg", "kilograms"),
                                         ("km", "kilometres"), ("pfu", "particle flux units")]
        for (symbol, word) in words {
            result = result.replacingOccurrences(of: "(?<=[0-9]) ?\(symbol)\\b", with: " \(word)", options: .regularExpression)
        }
        return result
    }
}

private final class SpeechDelegate: NSObject, AVSpeechSynthesizerDelegate {
    var onEvent: (@MainActor (ObjectIdentifier, Bool) -> Void)?

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        report(utterance, true)
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        report(utterance, false)
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        report(utterance, false)
    }

    private func report(_ utterance: AVSpeechUtterance, _ speaking: Bool) {
        let id = ObjectIdentifier(utterance)
        let callback = onEvent
        Task { @MainActor in callback?(id, speaking) }
    }
}

/// Repeat / stop control for Read aloud. Hidden when Read aloud is off or VoiceOver is running.
struct ReadAloudButton: View {
    let enabled: Bool
    let text: String
    var size: CGFloat = 44

    var body: some View {
        if enabled && !UIAccessibility.isVoiceOverRunning {
            let narrator = Narrator.shared
            let speaking = narrator.isSpeaking
            RoundIconButton(symbol: speaking ? "stop.fill" : "speaker.wave.2.fill",
                            label: speaking ? "Stop reading" : "Read aloud again",
                            bevel: GamePalette.energy, size: size) {
                speaking ? narrator.stop() : narrator.speak(text)
            }
        }
    }
}
