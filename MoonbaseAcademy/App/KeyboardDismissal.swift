import UIKit

/// Tapping anywhere that is not a text field puts the keyboard away, everywhere in the app,
/// including sheets. The recognizer never blocks the tap it sees.
@MainActor
enum KeyboardDismissal {
    private static let delegate = Delegate()

    static func install() {
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
        for window in windows where !(window.gestureRecognizers ?? []).contains(where: { $0.name == "dismissKeyboard" }) {
            let tap = UITapGestureRecognizer(target: delegate, action: #selector(Delegate.tapped(_:)))
            tap.name = "dismissKeyboard"
            tap.cancelsTouchesInView = false
            tap.requiresExclusiveTouchType = false
            tap.delegate = delegate
            window.addGestureRecognizer(tap)
        }
    }

    final class Delegate: NSObject, UIGestureRecognizerDelegate {
        @objc func tapped(_ recognizer: UITapGestureRecognizer) {
            recognizer.view?.endEditing(true)
        }

        func gestureRecognizer(_ recognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            var view = touch.view
            while let current = view {
                if current is UITextField || current is UITextView { return false }
                view = current.superview
            }
            return true
        }

        func gestureRecognizer(_ recognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            true
        }
    }
}
