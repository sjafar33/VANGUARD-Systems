import SwiftUI
import UIKit

// MARK: Feel

enum Haptics {
    static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func thump() { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    static func heavy() { UIImpactFeedbackGenerator(style: .heavy).impactOccurred() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func warning() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
}

enum GamePalette {
    static let night = Color(hex: 0x0B1426)
    static let hud = Color(hex: 0x0B1426, opacity: 0.78)

    struct Bevel {
        let top: Color
        let bottom: Color
        let edge: Color
    }

    static let go = Bevel(top: Color(hex: 0x7EDB6E), bottom: Color(hex: 0x43A63E), edge: Color(hex: 0x2B6E28))
    static let gold = Bevel(top: Color(hex: 0xFFD66B), bottom: Color(hex: 0xF2A93B), edge: Color(hex: 0xB0680F))
    static let steel = Bevel(top: Color(hex: 0x7C93B3), bottom: Color(hex: 0x52698B), edge: Color(hex: 0x324560))
    static let coral = Bevel(top: Color(hex: 0xF7A68C), bottom: Color(hex: 0xE06A50), edge: Color(hex: 0x9C3F2C))
    static let energy = Bevel(top: Color(hex: 0x74DFEC), bottom: Color(hex: 0x2CAEC3), edge: Color(hex: 0x1A6F7D))
    static let card = Bevel(top: Color(hex: 0xFFFFFF), bottom: Color(hex: 0xE3E9F0), edge: Color(hex: 0x9AA8BA))
}

/// White heavy text with a dark outline-like shadow, readable on any part of the world.
struct GameTextModifier: ViewModifier {
    var color: Color = .white

    func body(content: Content) -> some View {
        content
            .foregroundStyle(color)
            .shadow(color: GamePalette.night.opacity(0.95), radius: 0, x: 0, y: 2)
            .shadow(color: GamePalette.night.opacity(0.7), radius: 1.2, x: 0, y: 0)
    }
}

extension View {
    func gameText(_ color: Color = .white) -> some View { modifier(GameTextModifier(color: color)) }
}

extension Font {
    static func game(_ style: Font.TextStyle) -> Font {
        .system(style, design: .rounded).weight(.black)
    }
}

// MARK: Buttons

/// A chunky, bevelled game button that presses down with a haptic tap.
struct GameButtonStyle: ButtonStyle {
    var bevel: GamePalette.Bevel = GamePalette.gold
    var height: CGFloat = 58
    var font: Font = .game(.title3)
    var dark: Bool = false
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        return configuration.label
            .font(font)
            .modifier(GameTextModifier(color: dark ? Theme.ink : .white))
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity, minHeight: height)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(bevel.edge)
                        .offset(y: pressed ? 1 : 6)
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(LinearGradient(colors: [bevel.top, bevel.bottom], startPoint: .top, endPoint: .bottom))
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.28))
                        .frame(height: height * 0.32)
                        .padding(.horizontal, 8)
                        .frame(maxHeight: .infinity, alignment: .top)
                        .padding(.top, 5)
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.45), lineWidth: 2)
                }
            }
            .offset(y: pressed ? 5 : 0)
            .padding(.bottom, 6)
            .saturation(isEnabled ? 1 : 0.1)
            .opacity(isEnabled ? 1 : 0.7)
            .animation(.spring(response: 0.16, dampingFraction: 0.55), value: pressed)
            .onChange(of: pressed) { _, now in if now { Haptics.tap() } }
    }
}

/// A round bevelled icon button for HUD corners.
struct RoundIconButton: View {
    let symbol: String
    let label: String
    var bevel: GamePalette.Bevel = GamePalette.steel
    var size: CGFloat = 48
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size * 0.42, weight: .black, design: .rounded))
        }
        .buttonStyle(RoundBevelStyle(bevel: bevel, size: size))
        .accessibilityLabel(label)
    }
}

struct RoundBevelStyle: ButtonStyle {
    let bevel: GamePalette.Bevel
    let size: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        return configuration.label
            .gameText()
            .frame(width: size, height: size)
            .background {
                ZStack {
                    Circle().fill(bevel.edge).offset(y: pressed ? 1 : 4)
                    Circle().fill(LinearGradient(colors: [bevel.top, bevel.bottom], startPoint: .top, endPoint: .bottom))
                    Circle().strokeBorder(Color.white.opacity(0.5), lineWidth: 2)
                }
            }
            .offset(y: pressed ? 3 : 0)
            .padding(.bottom, 4)
            .frame(minWidth: 44, minHeight: 44)
            .animation(.spring(response: 0.16, dampingFraction: 0.55), value: pressed)
            .onChange(of: pressed) { _, now in if now { Haptics.tap() } }
    }
}

// MARK: HUD

/// A resource counter in the style of a mobile base-builder: icon medallion plus a dark pill.
struct ResourcePill: View {
    let symbol: String
    let bevel: GamePalette.Bevel
    let value: String
    let label: String
    var fraction: Double? = nil
    var warning: Bool = false

    var body: some View {
        HStack(spacing: 0) {
            ZStack {
                Circle().fill(LinearGradient(colors: [warning ? GamePalette.coral.top : bevel.top,
                                                      warning ? GamePalette.coral.bottom : bevel.bottom],
                                             startPoint: .top, endPoint: .bottom))
                Circle().strokeBorder(Color.white.opacity(0.7), lineWidth: 2)
                Image(systemName: warning ? "exclamationmark" : symbol)
                    .font(.system(size: 17, weight: .black, design: .rounded))
                    .gameText()
            }
            .frame(width: 40, height: 40)
            .zIndex(1)
            VStack(alignment: .leading, spacing: 3) {
                Text(value)
                    .font(.system(.subheadline, design: .rounded).weight(.black).monospacedDigit())
                    .gameText()
                    .contentTransition(.numericText())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if let fraction {
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.18))
                            Capsule().fill(warning ? GamePalette.coral.top : bevel.top)
                                .frame(width: proxy.size.width * max(0, min(1, fraction)))
                        }
                    }
                    .frame(width: 92, height: 6)
                }
            }
            .padding(.leading, 22)
            .padding(.trailing, 12)
            .padding(.vertical, 6)
            .frame(minWidth: 86, alignment: .leading)
            .fixedSize(horizontal: true, vertical: false)
            .background(Capsule().fill(GamePalette.hud).overlay(Capsule().strokeBorder(Color.white.opacity(0.16), lineWidth: 1.5)))
            .padding(.leading, -18)
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: value)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(value)\(warning ? ", warning" : "")")
    }
}

/// A ribbon banner used for titles.
struct Ribbon: View {
    let text: String
    var bevel: GamePalette.Bevel = GamePalette.gold
    var font: Font = .game(.title2)

    var body: some View {
        Text(text)
            .font(font)
            .gameText()
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .padding(.horizontal, 26)
            .padding(.vertical, 10)
            .background {
                ZStack {
                    RibbonShape().fill(bevel.edge).offset(y: 4)
                    RibbonShape().fill(LinearGradient(colors: [bevel.top, bevel.bottom], startPoint: .top, endPoint: .bottom))
                    RibbonShape().stroke(Color.white.opacity(0.45), lineWidth: 2)
                }
            }
            .accessibilityAddTraits(.isHeader)
    }
}

struct RibbonShape: Shape {
    func path(in rect: CGRect) -> Path {
        let notch: CGFloat = min(14, rect.height * 0.35)
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - notch, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + notch, y: rect.midY))
        p.closeSubpath()
        return p
    }
}

/// A raised card surface with a darker lip, like a tile you can press.
struct GameCardBackground: View {
    var bevel: GamePalette.Bevel = GamePalette.card
    var corner: CGFloat = 20
    var highlighted = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: corner, style: .continuous).fill(bevel.edge).offset(y: 5)
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(LinearGradient(colors: [bevel.top, bevel.bottom], startPoint: .top, endPoint: .bottom))
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .strokeBorder(highlighted ? Theme.amber : Color.white.opacity(0.7), lineWidth: highlighted ? 4 : 2)
        }
    }
}

// MARK: Nova, the guide

/// Nova is the team's own helper robot. Drawn in code so no external art is needed.
struct NovaAvatar: View {
    var size: CGFloat = 64
    var talking = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var bob = false

    var body: some View {
        Canvas { context, canvas in
            let s = canvas.width
            let head = CGRect(x: s * 0.1, y: s * 0.18, width: s * 0.8, height: s * 0.74)
            // antenna
            var stem = Path()
            stem.move(to: CGPoint(x: s * 0.5, y: s * 0.2))
            stem.addLine(to: CGPoint(x: s * 0.5, y: s * 0.06))
            context.stroke(stem, with: .color(Color(hex: 0x6E7A8B)), lineWidth: s * 0.04)
            context.fill(Path(ellipseIn: CGRect(x: s * 0.43, y: s * 0.0, width: s * 0.14, height: s * 0.14)), with: .color(Theme.amber))
            // head shell
            context.fill(Path(roundedRect: head.offsetBy(dx: 0, dy: s * 0.04), cornerRadius: s * 0.3), with: .color(Color(hex: 0x8794A6)))
            context.fill(Path(roundedRect: head, cornerRadius: s * 0.3),
                         with: .linearGradient(Gradient(colors: [Color(hex: 0xFFFFFF), Color(hex: 0xD3DBE4)]),
                                               startPoint: CGPoint(x: head.minX, y: head.minY), endPoint: CGPoint(x: head.maxX, y: head.maxY)))
            // visor
            let visor = head.insetBy(dx: s * 0.1, dy: s * 0.17).offsetBy(dx: 0, dy: s * 0.02)
            context.fill(Path(roundedRect: visor, cornerRadius: s * 0.16), with: .color(Color(hex: 0x16223A)))
            // eyes
            let eyeW = s * 0.1
            let eyeH = s * 0.17
            for dx in [-0.13, 0.13] as [CGFloat] {
                let eye = CGRect(x: s * (0.5 + dx) - eyeW / 2, y: visor.midY - eyeH / 2, width: eyeW, height: eyeH)
                context.fill(Path(roundedRect: eye, cornerRadius: eyeW / 2), with: .color(Color(hex: 0x6FE6F2)))
            }
            // smile
            var smile = Path()
            smile.move(to: CGPoint(x: s * 0.42, y: visor.maxY - s * 0.08))
            smile.addQuadCurve(to: CGPoint(x: s * 0.58, y: visor.maxY - s * 0.08), control: CGPoint(x: s * 0.5, y: visor.maxY - s * 0.02))
            context.stroke(smile, with: .color(Color(hex: 0x6FE6F2)), lineWidth: s * 0.03)
            // cheek light
            context.fill(Path(ellipseIn: CGRect(x: head.minX + s * 0.04, y: head.midY, width: s * 0.08, height: s * 0.08)), with: .color(Theme.amber.opacity(0.9)))
        }
        .frame(width: size, height: size)
        .offset(y: bob ? -3 : 0)
        .onAppear {
            guard talking, !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.45).repeatForever(autoreverses: true)) { bob = true }
        }
        .accessibilityHidden(true)
    }
}

/// Nova's speech bubble. Short lines, large text, tap to continue when there is more.
struct NovaBubble: View {
    let text: String
    var actionLabel: String? = nil
    var compact = false
    var onTap: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            NovaAvatar(size: compact ? 52 : 66, talking: true)
            VStack(alignment: .leading, spacing: 6) {
                Text(text)
                    .font(.system(compact ? .callout : .body, design: .rounded).weight(.semibold))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .id(text)
                    .transition(.opacity)
                if let actionLabel {
                    HStack(spacing: 4) {
                        Text(actionLabel)
                        Image(systemName: "chevron.right.circle.fill")
                    }
                    .font(.system(.subheadline, design: .rounded).weight(.heavy))
                    .foregroundStyle(Theme.energyInk)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background {
                ZStack(alignment: .bottomLeading) {
                    RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color(hex: 0x9AA8BA)).offset(y: 3)
                    RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white)
                    BubbleTail().fill(Color.white).frame(width: 16, height: 14).offset(x: -10, y: -10)
                }
            }
            .frame(maxWidth: 560, alignment: .leading)
        }
        .contentShape(Rectangle())
        .onTapGesture { onTap?() }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Nova says: \(text)")
        .accessibilityAddTraits(onTap == nil ? [] : .isButton)
        .animation(.easeOut(duration: 0.2), value: text)
    }
}

struct BubbleTail: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY * 0.55))
        p.closeSubpath()
        return p
    }
}

// MARK: Stars

struct StarSlot: View {
    let filled: Bool
    let label: String
    let delay: Double
    var size: CGFloat = 54
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Image(systemName: "star.fill")
                    .font(.system(size: size, weight: .black))
                    .foregroundStyle(GamePalette.night.opacity(0.35))
                    .offset(y: 3)
                Image(systemName: "star.fill")
                    .font(.system(size: size, weight: .black))
                    .foregroundStyle(Color(hex: 0x3A4A63))
                if filled {
                    Image(systemName: "star.fill")
                        .font(.system(size: size, weight: .black))
                        .foregroundStyle(LinearGradient(colors: [Color(hex: 0xFFE27A), Color(hex: 0xF5A623)], startPoint: .top, endPoint: .bottom))
                        .overlay(Image(systemName: "star").font(.system(size: size, weight: .black)).foregroundStyle(Color.white.opacity(0.6)))
                        .scaleEffect(shown ? 1 : 0.2)
                        .opacity(shown ? 1 : 0)
                }
            }
            Text(label)
                .font(.system(.caption, design: .rounded).weight(.heavy))
                .foregroundStyle(filled ? Theme.ink : Theme.inkSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .frame(maxWidth: 110)
        }
        .onAppear {
            guard filled else { return }
            if reduceMotion {
                shown = true
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.5)) { shown = true }
                Haptics.thump()
                SoundFX.shared.play(.star)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(filled ? "star earned" : "no star")")
    }
}

struct MiniStars: View {
    let count: Int
    var size: CGFloat = 14

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<3, id: \.self) { index in
                Image(systemName: "star.fill")
                    .font(.system(size: size, weight: .black))
                    .foregroundStyle(index < count ? Color(hex: 0xF5B92E) : Color(hex: 0x9AA8BA).opacity(0.6))
                    .shadow(color: GamePalette.night.opacity(0.5), radius: 0, x: 0, y: 1)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(count) of 3 stars")
    }
}

// MARK: Celebration

/// Short confetti burst for a success. Skipped entirely with reduce motion.
struct ConfettiView: View {
    private struct Piece {
        let x: CGFloat
        let vx: CGFloat
        let vy: CGFloat
        let spin: Double
        let color: Color
        let size: CGFloat
    }

    @State private var start = Date()
    private let pieces: [Piece] = {
        var rng = SystemRandomNumberGenerator()
        let colors = [Theme.amber, Theme.energy, Theme.plant, Color(hex: 0xF7A68C), Color.white]
        return (0..<90).map { _ in
            Piece(x: CGFloat.random(in: 0.2...0.8, using: &rng),
                  vx: CGFloat.random(in: -0.35...0.35, using: &rng),
                  vy: CGFloat.random(in: -1.25 ... -0.7, using: &rng),
                  spin: Double.random(in: -8...8, using: &rng),
                  color: colors.randomElement(using: &rng) ?? .white,
                  size: CGFloat.random(in: 6...11, using: &rng))
        }
    }()

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSince(start)
            Canvas { context, size in
                guard t < 2.6 else { return }
                for piece in pieces {
                    let x = (piece.x + piece.vx * CGFloat(t)) * size.width
                    let y = size.height * 0.55 + (piece.vy * CGFloat(t) + 0.9 * CGFloat(t * t)) * size.height * 0.5
                    var c = context
                    c.translateBy(x: x, y: y)
                    c.rotate(by: .radians(piece.spin * t))
                    c.opacity = max(0, 1 - t / 2.6)
                    c.fill(Path(CGRect(x: -piece.size / 2, y: -piece.size / 4, width: piece.size, height: piece.size / 2)), with: .color(piece.color))
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Measures a view's height so the world can keep its buildings clear of the HUD.
struct HeightReader: ViewModifier {
    let onChange: (CGFloat) -> Void

    func body(content: Content) -> some View {
        content.background {
            GeometryReader { proxy in
                Color.clear
                    .onAppear { onChange(proxy.size.height) }
                    .onChange(of: proxy.size.height) { _, height in onChange(height) }
            }
        }
    }
}

extension View {
    func readHeight(_ onChange: @escaping (CGFloat) -> Void) -> some View { modifier(HeightReader(onChange: onChange)) }

    /// A quick horizontal shake used when an action is not possible.
    func shake(_ trigger: Int) -> some View { modifier(ShakeEffect(animatableData: CGFloat(trigger))) }
}

struct ShakeEffect: GeometryEffect {
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 8 * sin(animatableData * .pi * 4), y: 0))
    }
}
