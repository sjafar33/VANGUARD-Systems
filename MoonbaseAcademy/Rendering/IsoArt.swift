import SpriteKit
import UIKit

/// The one projection used by the world. Grid x runs down-right on screen, grid y runs down-left.
enum Iso {
    static let tileWidth: CGFloat = 64
    static let tileHeight: CGFloat = 32

    /// Grid to scene coordinates. SpriteKit's y axis points up, so larger gx + gy is nearer the viewer (lower).
    static func point(_ gx: CGFloat, _ gy: CGFloat) -> CGPoint {
        CGPoint(x: (gx - gy) * tileWidth / 2, y: -(gx + gy) * tileHeight / 2)
    }

    static func point(_ g: CGPoint) -> CGPoint { point(g.x, g.y) }

    static func grid(from p: CGPoint) -> CGPoint {
        let a = p.x / (tileWidth / 2)
        let b = -p.y / (tileHeight / 2)
        return CGPoint(x: (a + b) / 2, y: (b - a) / 2)
    }

    /// Structures nearer the viewer draw later. Every structure depth is above the ground layers.
    static func depth(_ g: CGPoint) -> CGFloat { 200 + (g.x + g.y) * 10 }
}

enum ZLayer {
    static let background: CGFloat = -1000
    static let earth: CGFloat = -900
    static let terrain: CGFloat = 0
    static let track: CGFloat = 4
    static let pads: CGFloat = 10
    static let padHighlight: CGFloat = 12
    static let roverOnTrack: CGFloat = 330
    static let flow: CGFloat = 400
    static let tint: CGFloat = 800
    static let particles: CGFloat = 810
    static let signal: CGFloat = 820
}

extension CGPoint {
    func offset(_ dx: CGFloat, _ dy: CGFloat) -> CGPoint { CGPoint(x: x + dx, y: y + dy) }
    static func + (a: CGPoint, b: CGPoint) -> CGPoint { CGPoint(x: a.x + b.x, y: a.y + b.y) }
}

struct SeededRandom {
    private var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E37_79B9_7F4A_7C15 }

    mutating func unit() -> CGFloat {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return CGFloat(Double(state >> 11) / Double(UInt64(1) << 53))
    }

    mutating func range(_ lo: CGFloat, _ hi: CGFloat) -> CGFloat { lo + (hi - lo) * unit() }
}

/// Draws isometric shapes into a Core Graphics context whose y axis points down.
/// Light comes from the upper left: top faces brightest, front-left faces medium, front-right faces darkest,
/// and shadows fall toward +x (lower right on screen).
struct IsoPainter {
    let ctx: CGContext
    let origin: CGPoint
    var tw: CGFloat = Iso.tileWidth
    var th: CGFloat = Iso.tileHeight

    struct BoxColors {
        var top: UIColor
        var left: UIColor
        var right: UIColor

        init(_ top: UInt32, _ left: UInt32, _ right: UInt32) {
            self.top = UIColor(hex: top)
            self.left = UIColor(hex: left)
            self.right = UIColor(hex: right)
        }
    }

    func p(_ x: CGFloat, _ y: CGFloat, _ z: CGFloat = 0) -> CGPoint {
        CGPoint(x: origin.x + (x - y) * tw / 2, y: origin.y + (x + y) * th / 2 - z)
    }

    func polygon(_ points: [CGPoint]) -> CGPath {
        let path = CGMutablePath()
        path.addLines(between: points)
        path.closeSubpath()
        return path
    }

    func fill(_ points: [CGPoint], _ color: UIColor) {
        ctx.setFillColor(color.cgColor)
        ctx.addPath(polygon(points))
        ctx.fillPath()
    }

    func fill(_ path: CGPath, _ color: UIColor) {
        ctx.setFillColor(color.cgColor)
        ctx.addPath(path)
        ctx.fillPath()
    }

    func stroke(_ points: [CGPoint], _ color: UIColor, width: CGFloat = 1, close: Bool = false) {
        guard points.count > 1 else { return }
        ctx.setStrokeColor(color.cgColor)
        ctx.setLineWidth(width)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        let path = CGMutablePath()
        path.addLines(between: points)
        if close { path.closeSubpath() }
        ctx.addPath(path)
        ctx.strokePath()
    }

    func line(_ a: CGPoint, _ b: CGPoint, _ color: UIColor, width: CGFloat = 1) {
        stroke([a, b], color, width: width)
    }

    func box(_ x0: CGFloat, _ y0: CGFloat, _ x1: CGFloat, _ y1: CGFloat,
             z0: CGFloat = 0, z1: CGFloat, colors: BoxColors, edge: UIColor? = nil) {
        let left = [p(x0, y1, z0), p(x1, y1, z0), p(x1, y1, z1), p(x0, y1, z1)]
        let right = [p(x1, y0, z0), p(x1, y1, z0), p(x1, y1, z1), p(x1, y0, z1)]
        let top = [p(x0, y0, z1), p(x1, y0, z1), p(x1, y1, z1), p(x0, y1, z1)]
        fill(left, colors.left)
        fill(right, colors.right)
        fill(top, colors.top)
        if let edge {
            stroke(top, edge, width: 0.8, close: true)
            line(p(x1, y1, z0), p(x1, y1, z1), edge, width: 0.8)
        }
    }

    /// A soft rectangular shadow cast toward +x.
    func shadow(_ x0: CGFloat, _ y0: CGFloat, _ x1: CGFloat, _ y1: CGFloat, length: CGFloat, alpha: CGFloat = 0.24) {
        let outer = [p(x0 - 0.04, y0 - 0.04), p(x1 + length + 0.06, y0 - 0.04), p(x1 + length + 0.06, y1 + 0.04), p(x0 - 0.04, y1 + 0.04)]
        let inner = [p(x0, y0), p(x1 + length, y0), p(x1 + length, y1), p(x0, y1)]
        fill(outer, UIColor(white: 0, alpha: alpha * 0.45))
        fill(inner, UIColor(white: 0, alpha: alpha * 0.6))
    }

    func ellipseRect(cx: CGFloat, cy: CGFloat, z: CGFloat, r: CGFloat) -> CGRect {
        let c = p(cx, cy, z)
        let a = r * tw * 0.7071
        let b = r * th * 0.7071
        return CGRect(x: c.x - a, y: c.y - b, width: 2 * a, height: 2 * b)
    }

    func softShadow(cx: CGFloat, cy: CGFloat, r: CGFloat, alpha: CGFloat = 0.24) {
        ctx.setFillColor(UIColor(white: 0, alpha: alpha * 0.45).cgColor)
        ctx.fillEllipse(in: ellipseRect(cx: cx, cy: cy, z: 0, r: r * 1.08))
        ctx.setFillColor(UIColor(white: 0, alpha: alpha * 0.6).cgColor)
        ctx.fillEllipse(in: ellipseRect(cx: cx, cy: cy, z: 0, r: r))
    }

    func gradient(_ clip: CGPath, from: CGPoint, to: CGPoint, colors: [UIColor]) {
        guard let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                 colors: colors.map(\.cgColor) as CFArray, locations: nil) else { return }
        ctx.saveGState()
        ctx.addPath(clip)
        ctx.clip()
        ctx.drawLinearGradient(g, start: from, end: to, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        ctx.restoreGState()
    }

    func radial(_ clip: CGPath, center: CGPoint, radius: CGFloat, colors: [UIColor]) {
        guard let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                 colors: colors.map(\.cgColor) as CFArray, locations: nil) else { return }
        ctx.saveGState()
        ctx.addPath(clip)
        ctx.clip()
        ctx.drawRadialGradient(g, startCenter: center, startRadius: 0, endCenter: center, endRadius: radius,
                               options: [.drawsAfterEndLocation])
        ctx.restoreGState()
    }

    /// A vertical cylinder seen from above: shaded side band, then a flat top.
    func cylinder(cx: CGFloat, cy: CGFloat, r: CGFloat, z0: CGFloat, z1: CGFloat,
                  side: (UInt32, UInt32), top: UInt32) {
        let bottom = ellipseRect(cx: cx, cy: cy, z: z0, r: r)
        let upper = ellipseRect(cx: cx, cy: cy, z: z1, r: r)
        let band = CGRect(x: upper.minX, y: upper.midY, width: upper.width, height: bottom.midY - upper.midY)
        let colors = [UIColor(hex: side.0), UIColor(hex: side.1)]
        let from = CGPoint(x: bottom.minX, y: bottom.midY)
        let to = CGPoint(x: bottom.maxX, y: bottom.midY)
        gradient(CGPath(ellipseIn: bottom, transform: nil), from: from, to: to, colors: colors)
        gradient(CGPath(rect: band, transform: nil), from: from, to: to, colors: colors)
        ctx.setFillColor(UIColor(hex: top).cgColor)
        ctx.fillEllipse(in: upper)
    }

    /// Lower half of an ellipse, from its right point back to its left point.
    private func addLowerHalf(_ path: CGMutablePath, _ e: CGRect) {
        let k: CGFloat = 0.5523
        let a = e.width / 2
        let b = e.height / 2
        let cx = e.midX
        let cy = e.midY
        path.addCurve(to: CGPoint(x: cx, y: cy + b),
                      control1: CGPoint(x: cx + a, y: cy + b * k), control2: CGPoint(x: cx + a * k, y: cy + b))
        path.addCurve(to: CGPoint(x: cx - a, y: cy),
                      control1: CGPoint(x: cx - a * k, y: cy + b), control2: CGPoint(x: cx - a, y: cy + b * k))
    }

    func domePath(cx: CGFloat, cy: CGFloat, r: CGFloat, z: CGFloat, height: CGFloat) -> CGPath {
        let base = ellipseRect(cx: cx, cy: cy, z: z, r: r)
        let a = base.width / 2
        let path = CGMutablePath()
        path.move(to: CGPoint(x: base.minX, y: base.midY))
        path.addCurve(to: CGPoint(x: base.midX, y: base.midY - height),
                      control1: CGPoint(x: base.minX, y: base.midY - height * 0.56),
                      control2: CGPoint(x: base.midX - a * 0.56, y: base.midY - height))
        path.addCurve(to: CGPoint(x: base.maxX, y: base.midY),
                      control1: CGPoint(x: base.midX + a * 0.56, y: base.midY - height),
                      control2: CGPoint(x: base.maxX, y: base.midY - height * 0.56))
        addLowerHalf(path, base)
        path.closeSubpath()
        return path
    }

    /// Bilinear point inside a quad given as corners a (0,0), b (1,0), c (1,1), d (0,1).
    func lerpQuad(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint, _ d: CGPoint, _ u: CGFloat, _ v: CGFloat) -> CGPoint {
        let x = a.x * (1 - u) * (1 - v) + b.x * u * (1 - v) + c.x * u * v + d.x * (1 - u) * v
        let y = a.y * (1 - u) * (1 - v) + b.y * u * (1 - v) + c.y * u * v + d.y * (1 - u) * v
        return CGPoint(x: x, y: y)
    }

    static func convexHull(_ points: [CGPoint]) -> [CGPoint] {
        let sorted = points.sorted { $0.x == $1.x ? $0.y < $1.y : $0.x < $1.x }
        guard sorted.count > 2 else { return sorted }
        func cross(_ o: CGPoint, _ a: CGPoint, _ b: CGPoint) -> CGFloat {
            (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x)
        }
        var lower: [CGPoint] = []
        for point in sorted {
            while lower.count >= 2 && cross(lower[lower.count - 2], lower[lower.count - 1], point) <= 0 { lower.removeLast() }
            lower.append(point)
        }
        var upper: [CGPoint] = []
        for point in sorted.reversed() {
            while upper.count >= 2 && cross(upper[upper.count - 2], upper[upper.count - 1], point) <= 0 { upper.removeLast() }
            upper.append(point)
        }
        return Array(lower.dropLast() + upper.dropLast())
    }
}

/// Procedural textures are drawn once and cached by name. Nothing is rasterized per frame.
final class ArtCache {
    static let shared = ArtCache()
    private var textures: [String: SKTexture] = [:]

    func texture(_ key: String, size: CGSize, scale: CGFloat = 3, draw: (CGContext) -> Void) -> SKTexture {
        if let cached = textures[key] { return cached }
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = false
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            draw(context.cgContext)
        }
        let texture = SKTexture(image: image)
        texture.filteringMode = .linear
        textures[key] = texture
        return texture
    }
}
