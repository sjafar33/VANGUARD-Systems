import SwiftUI
import UIKit

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: alpha)
    }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(uiColor: UIColor(hex: hex, alpha: CGFloat(opacity)))
    }
}

/// The single palette for the world and the interface.
enum Theme {
    static let space = Color(hex: 0x0C1324)
    static let spaceShadow = Color(hex: 0x18243A)
    static let ground = Color(hex: 0xB7BEC8)
    static let ceramic = Color(hex: 0xEDF1F3)
    static let ceramicShade = Color(hex: 0xADB8C7)
    static let solar = Color(hex: 0x3D77A8)
    static let amber = Color(hex: 0xF2B84B)
    static let energy = Color(hex: 0x53C6D7)
    static let plant = Color(hex: 0x76B582)
    static let warning = Color(hex: 0xE98772)
    static let ink = Color(hex: 0x172334)
    static let inkSecondary = Color(hex: 0x46566B)
    static let panel = Color(hex: 0xF5F7F9)
    static let panelRaised = Color.white
    static let panelLine = Color(hex: 0xD6DDE5)
    /// Darker versions for text and icons on light panels, where the bright world colors lack contrast.
    /// Measured: 6.3:1 on white, 5.1:1 on the card gradient's darkest stop, 6.3:1 for white text on it.
    static let energyInk = Color(hex: 0x186A76)
    static let plantInk = Color(hex: 0x3E7A4B)
    static let warningInk = Color(hex: 0xB04A33)
    static let amberInk = Color(hex: 0x8A5A00)
}

extension Font {
    static func rounded(_ style: Font.TextStyle, weight: Font.Weight = .bold) -> Font {
        .system(style, design: .rounded).weight(weight)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    var tint: Color = Theme.amber
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.rounded(.headline))
            .foregroundStyle(Theme.ink)
            .frame(maxWidth: .infinity, minHeight: 52)
            .padding(.horizontal, 16)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isEnabled ? tint : Theme.panelLine))
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.rounded(.headline, weight: .semibold))
            .foregroundStyle(Theme.ink)
            .frame(maxWidth: .infinity, minHeight: 48)
            .padding(.horizontal, 14)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Theme.ink.opacity(0.25), lineWidth: 1.5)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.panelRaised)))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}

struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.panelRaised))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Theme.panelLine, lineWidth: 1))
    }
}

extension View {
    func card() -> some View { modifier(CardModifier()) }
}

/// A row of large, clearly selected choices. Used instead of tiny segmented controls for young players.
struct ChoiceRow<Value: Hashable>: View {
    let title: String
    let options: [(value: Value, label: String)]
    @Binding var selection: Value
    var disabled: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.inkSecondary)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) { buttons }
                VStack(spacing: 8) { buttons }
            }
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder private var buttons: some View {
        ForEach(options.indices, id: \.self) { index in
            let option = options[index]
            let selected = option.value == selection
            Button {
                selection = option.value
            } label: {
                Text(option.label)
                    .font(.body.weight(selected ? .bold : .regular))
                    .foregroundStyle(selected ? Color.white : Theme.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .padding(.horizontal, 8)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(selected ? Theme.ink : Theme.panel))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(selected ? Theme.ink : Theme.panelLine, lineWidth: 1.5))
            }
            .buttonStyle(.plain)
            .disabled(disabled)
            .accessibilityLabel("\(title): \(option.label)")
            .accessibilityAddTraits(selected ? .isSelected : [])
        }
    }
}

struct MeterView: View {
    let title: String
    let valueText: String
    let fraction: Double
    let tint: Color
    let systemImage: String
    var warning: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: warning ? "exclamationmark.triangle.fill" : systemImage)
                    .foregroundStyle(warning ? Theme.warningInk : tint)
                    .accessibilityHidden(true)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.inkSecondary)
                Spacer(minLength: 4)
                Text(valueText)
                    .font(.body.weight(.bold).monospacedDigit())
                    .foregroundStyle(Theme.ink)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.panelLine)
                    Capsule().fill(warning ? Theme.warning : tint)
                        .frame(width: max(0, min(1, fraction)) * proxy.size.width)
                }
            }
            .frame(height: 10)
            .accessibilityHidden(true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title): \(valueText)\(warning ? ", warning" : "")")
    }
}

enum Format {
    static func kWh(_ value: Double) -> String {
        "\(value.formatted(.number.precision(.fractionLength(1)))) kWh"
    }

    static func kW(_ value: Double) -> String {
        "\(value.formatted(.number.precision(.fractionLength(0...2)))) kW"
    }

    static func kg(_ value: Double, digits: Int = 2) -> String {
        "\(value.formatted(.number.precision(.fractionLength(0...digits)))) kg"
    }

    static func meters(_ value: Double, digits: Int = 2) -> String {
        "\(value.formatted(.number.precision(.fractionLength(0...digits)))) m"
    }

    static func seconds(_ value: Double) -> String {
        "\(value.formatted(.number.precision(.fractionLength(2)))) s"
    }

    static func hours(_ value: Double) -> String {
        let totalMinutes = Int((value * 60).rounded())
        let h = totalMinutes / 60
        let m = totalMinutes % 60
        if m == 0 { return "\(h) h" }
        if h == 0 { return "\(m) min" }
        return "\(h) h \(m) min"
    }

    static func wholeHours(_ value: Double) -> String {
        "\(Int(value.rounded(.down))) h"
    }

    static func number(_ value: Double, digits: Int = 1) -> String {
        value.formatted(.number.precision(.fractionLength(0...digits)))
    }
}
