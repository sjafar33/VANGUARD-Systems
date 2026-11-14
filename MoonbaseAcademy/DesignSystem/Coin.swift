import SwiftUI

/// A shiny gold Moon coin: rim, raised face, embossed crescent and star, and a highlight.
/// Drawn in code, so it stays crisp at any size and needs no image files.
struct CoinIcon: View {
    var size: CGFloat = 28

    var body: some View {
        ZStack {
            // Rim and edge thickness.
            Circle()
                .fill(Color(hex: 0xB86E0E))
                .offset(y: size * 0.06)
            Circle()
                .fill(RadialGradient(colors: [Color(hex: 0xFFE89A), Color(hex: 0xF7B731), Color(hex: 0xD98A12)],
                                     center: .init(x: 0.35, y: 0.3), startRadius: 0, endRadius: size * 0.7))
            // Inner ring.
            Circle()
                .strokeBorder(Color(hex: 0xC27A10).opacity(0.75), lineWidth: max(1, size * 0.06))
                .padding(size * 0.12)
            // Embossed crescent moon and star.
            Image(systemName: "moon.stars.fill")
                .font(.system(size: size * 0.42, weight: .black))
                .foregroundStyle(Color(hex: 0xB86E0E))
                .shadow(color: Color(hex: 0xFFF3C4).opacity(0.9), radius: 0, x: -size * 0.02, y: -size * 0.02)
            // Shine.
            Ellipse()
                .fill(Color.white.opacity(0.55))
                .frame(width: size * 0.34, height: size * 0.16)
                .rotationEffect(.degrees(-35))
                .offset(x: -size * 0.2, y: -size * 0.24)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// "Build for (coin) 40" style label for buttons and prices.
struct CoinLabel: View {
    var title: String? = nil
    let amount: Int
    var size: CGFloat = 24

    var body: some View {
        HStack(spacing: 6) {
            if let title { Text(title) }
            CoinIcon(size: size)
            Text("\(amount)")
        }
    }
}

/// The coin counter for HUDs: a coin medallion with a dark pill, matching `ResourcePill`.
struct CoinPill: View {
    let coins: Int
    var label = "Moon coins"

    var body: some View {
        HStack(spacing: 0) {
            CoinIcon(size: 42)
                .zIndex(1)
            Text("\(coins)")
                .font(.system(.title3, design: .rounded).weight(.black).monospacedDigit())
                .gameText(Color(hex: 0xFFE27A))
                .contentTransition(.numericText())
                .lineLimit(1)
                .padding(.leading, 24)
                .padding(.trailing, 14)
                .padding(.vertical, 6)
                .frame(minWidth: 80, alignment: .leading)
                .fixedSize(horizontal: true, vertical: false)
                .background(Capsule().fill(GamePalette.hud).overlay(Capsule().strokeBorder(Color(hex: 0xFFD66B).opacity(0.6), lineWidth: 1.5)))
                .padding(.leading, -20)
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: coins)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label): \(coins)")
    }
}
