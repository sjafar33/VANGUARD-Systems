import SpriteKit
import UIKit

/// The look of upgraded buildings. Level 1 uses the original art. Levels 2 and 3 are drawn here as
/// completely new buildings: taller, multi-storey and more futuristic at each level.
/// Looks only. Nothing here feeds a drill or a base test.
@MainActor
enum UpgradeArt {
    /// How far the building is lifted by the deck it stands on.
    static func lift(_ level: Int) -> CGFloat { level >= 3 ? 7 : (level == 2 ? 4 : 0) }

    static func applies(to kind: BuildingKind) -> Bool {
        switch kind {
        case .habitat, .solarArray, .battery, .greenhouse, .shelter, .dish: return true
        default: return false
        }
    }

    /// The highest point of the upgraded building, so the level pips can sit above it.
    static func top(_ kind: BuildingKind, level: Int) -> CGFloat {
        guard level >= 2 else { return 0 }
        let gold = level >= 3
        switch kind {
        case .solarArray: return gold ? 116 : 68
        case .battery: return gold ? 98 : 70
        case .dish: return gold ? 116 : 88
        case .greenhouse: return gold ? 108 : 72
        case .shelter: return gold ? 104 : 60
        case .habitat: return gold ? 166 : 124
        default: return 0
        }
    }

    private static func half(_ kind: BuildingKind) -> CGFloat { CGFloat(kind.footprint.w) / 2 }

    private static func canvas(half: CGFloat, up: CGFloat) -> Art.Canvas {
        let width = half * 128 + 64
        let down = half * 32 + 30
        return Art.Canvas(size: CGSize(width: width, height: up + down), origin: CGPoint(x: width / 2, y: up))
    }

    private static func accent(_ gold: Bool) -> UInt32 { gold ? 0xFFD66B : 0x6FE6F2 }

    // MARK: Deck

    /// The raised deck under an upgraded building: cyan-lit at level 2, gold at level 3.
    static func platform(kind: BuildingKind, level: Int) -> SKNode? {
        guard level >= 2, applies(to: kind) else { return nil }
        let h = half(kind)
        let top = lift(level)
        let gold = level >= 3
        let sprite = Art.sprite("upgrade.deck.\(kind.footprint.w).\(level)", canvas(half: h, up: 24)) { pt in
            let e = h - 0.05
            let colors = gold ? IsoPainter.BoxColors(0x4A566C, 0xE0B24A, 0xB8862A)
                              : IsoPainter.BoxColors(0x56667E, 0x53C6D7, 0x3A9DB0)
            pt.box(-e, -e, e, e, z1: top, colors: colors, edge: UIColor(hex: gold ? 0xFFE27A : 0x9FF0FA))
            let i = e - 0.12
            pt.stroke([pt.p(-i, -i, top), pt.p(i, -i, top), pt.p(i, i, top), pt.p(-i, i, top)],
                      UIColor(hex: accent(gold), alpha: 0.85), width: 1.6, close: true)
        }
        sprite.zPosition = 0.5
        return sprite
    }

    // MARK: Drawing helpers

    private static let white = IsoPainter.BoxColors(0xEEF1F4, 0xC7CED8, 0xA3ADBB)
    private static let steel = IsoPainter.BoxColors(0x6B7B92, 0x4A566C, 0x3A4658)
    private static let dark = IsoPainter.BoxColors(0x4A5568, 0x364152, 0x2A3342)
    private static let cyanBox = IsoPainter.BoxColors(0x9FF0FA, 0x53C6D7, 0x3A9DB0)
    private static let goldBox = IsoPainter.BoxColors(0xFFE27A, 0xE0B24A, 0xB8862A)
    private static let whiteSide: (UInt32, UInt32) = (0xEEF2F5, 0x98A5B6)
    private static let steelSide: (UInt32, UInt32) = (0x6B7B92, 0x323D4E)
    private static let goldSide: (UInt32, UInt32) = (0xFFE27A, 0xB8862A)
    private static let cyanSide: (UInt32, UInt32) = (0x9FF0FA, 0x3A9DB0)

    /// Points along the front (viewer-facing) half of a circle on the ground plane at height z.
    private static func frontArc(_ pt: IsoPainter, cx: CGFloat, cy: CGFloat, r: CGFloat, z: CGFloat, steps: Int = 14) -> [CGPoint] {
        let e = pt.ellipseRect(cx: cx, cy: cy, z: z, r: r)
        return (0...steps).map { i in
            let t = CGFloat.pi * CGFloat(i) / CGFloat(steps)
            return CGPoint(x: e.midX + e.width / 2 * cos(t), y: e.midY + e.height / 2 * sin(t))
        }
    }

    /// A glowing band around the front of a round wall.
    private static func band(_ pt: IsoPainter, cx: CGFloat, cy: CGFloat, r: CGFloat, z: CGFloat, color: UInt32, width: CGFloat) {
        pt.stroke(frontArc(pt, cx: cx, cy: cy, r: r, z: z), UIColor(hex: color), width: width)
    }

    /// A row of lit windows around the front of a round wall.
    private static func windows(_ pt: IsoPainter, cx: CGFloat, cy: CGFloat, r: CGFloat, z: CGFloat, count: Int, color: UInt32) {
        let points = frontArc(pt, cx: cx, cy: cy, r: r, z: z, steps: count + 1)
        pt.ctx.setFillColor(UIColor(hex: color).cgColor)
        for point in points.dropFirst().dropLast() {
            let rect = CGRect(x: point.x - 2.6, y: point.y - 7, width: 5.2, height: 7)
            pt.ctx.addPath(CGPath(roundedRect: rect, cornerWidth: 1.6, cornerHeight: 1.6, transform: nil))
            pt.ctx.fillPath()
        }
    }

    /// A dome standing on a round wall top, filled top-to-bottom with the given colours and outlined.
    private static func dome(_ pt: IsoPainter, cx: CGFloat, cy: CGFloat, r: CGFloat, z: CGFloat, height: CGFloat,
                             colors: [UIColor], outline: UIColor) {
        let path = pt.domePath(cx: cx, cy: cy, r: r, z: z, height: height)
        let base = pt.ellipseRect(cx: cx, cy: cy, z: z, r: r)
        pt.gradient(path, from: CGPoint(x: base.minX, y: base.midY - height), to: CGPoint(x: base.maxX, y: base.maxY), colors: colors)
        pt.ctx.addPath(path)
        pt.ctx.setStrokeColor(outline.cgColor)
        pt.ctx.setLineWidth(1.2)
        pt.ctx.strokePath()
    }

    private static let glass = [UIColor(hex: 0xEAFBFD, alpha: 0.9), UIColor(hex: 0x9FE6EF, alpha: 0.78), UIColor(hex: 0x4FB6C8, alpha: 0.8)]
    private static let shell = [UIColor(hex: 0xF7F9FA), UIColor(hex: 0xEDF1F3), UIColor(hex: 0xADB8C7)]

    /// A solar panel tilted toward the viewer, centred on (cx, cy) with its low edge at height z.
    private static func panel(_ pt: IsoPainter, cx: CGFloat, cy: CGFloat, z: CGFloat, w: CGFloat, d: CGFloat,
                              rise: CGFloat, gold: Bool) {
        let a = pt.p(cx - w, cy - d, z + rise)
        let b = pt.p(cx + w, cy - d, z + rise)
        let c = pt.p(cx + w, cy + d, z)
        let e = pt.p(cx - w, cy + d, z)
        pt.fill([a, b, c, e], UIColor(hex: 0x24468F))
        let grid = UIColor(hex: 0x7FB0F0, alpha: 0.8)
        for u in [CGFloat(0.25), 0.5, 0.75] {
            pt.line(pt.lerpQuad(a, b, c, e, u, 0), pt.lerpQuad(a, b, c, e, u, 1), grid, width: 0.8)
        }
        pt.line(pt.lerpQuad(a, b, c, e, 0, 0.5), pt.lerpQuad(a, b, c, e, 1, 0.5), grid, width: 0.8)
        pt.stroke([a, b, c, e], UIColor(hex: gold ? 0xFFD66B : 0xE4EAF0), width: 1.6, close: true)
    }

    private static func glow(_ color: UInt32, _ diameter: CGFloat, at point: CGPoint, alpha: CGFloat = 0.9) -> SKSpriteNode {
        let node = SKSpriteNode(texture: Art.glowDot(color: color, diameter: diameter))
        node.position = point
        node.blendMode = .add
        node.alpha = alpha
        node.zPosition = 0.3
        return node
    }

    private static func pulse(_ node: SKNode, low: CGFloat, high: CGFloat, period: Double, delay: Double = 0) {
        let loop = SKAction.repeatForever(.sequence([.fadeAlpha(to: low, duration: period / 2),
                                                     .fadeAlpha(to: high, duration: period / 2)]))
        node.run(.sequence([.wait(forDuration: delay), loop]))
    }

    private static func light(_ group: SKNode, _ color: UInt32, _ diameter: CGFloat, x: CGFloat, y: CGFloat, z: CGFloat,
                              animated: Bool, period: Double = 1.4, delay: Double = 0) {
        let node = glow(color, diameter, at: Iso.point(x, y).offset(0, z))
        group.addChild(node)
        if animated { pulse(node, low: 0.3, high: 1, period: period, delay: delay) }
    }

    private static func hologram(width: CGFloat, at height: CGFloat, animated: Bool) -> SKNode {
        let group = SKNode()
        group.position = CGPoint(x: 0, y: height)
        group.zPosition = 0.4
        for (index, scale) in [CGFloat(1), 0.68].enumerated() {
            let ring = SKShapeNode(ellipseOf: CGSize(width: width * scale, height: width * scale * 0.5))
            ring.strokeColor = UIColor(hex: 0x8BE3EE, alpha: index == 0 ? 0.9 : 0.6)
            ring.fillColor = .clear
            ring.lineWidth = 2
            ring.glowWidth = 1.5
            ring.position = CGPoint(x: 0, y: CGFloat(index) * 9)
            group.addChild(ring)
            if animated { pulse(ring, low: 0.35, high: 1, period: 1.6, delay: Double(index) * 0.4) }
        }
        if animated {
            group.run(.repeatForever(.sequence([.moveBy(x: 0, y: 5, duration: 1.1), .moveBy(x: 0, y: -5, duration: 1.1)])))
        }
        return group
    }

    // MARK: Buildings

    /// The whole building for level 2 or 3, or nil when the level 1 art should be used.
    static func body(kind: BuildingKind, level: Int, tint: UInt32, animated: Bool) -> SKNode? {
        guard level >= 2, applies(to: kind) else { return nil }
        let gold = level >= 3
        let group = SKNode()
        let key = "upgrade.body.\(kind.rawValue).\(level)"
        let lamp = accent(gold)

        switch kind {
        case .habitat:
            habitat(group, key: key, gold: gold, tint: tint, animated: animated)

        case .battery:
            if gold {
                // A reactor-style power core: one big dark cell with glowing charge rings.
                group.addChild(Art.sprite(key, canvas(half: 0.5, up: 110)) { pt in
                    pt.softShadow(cx: 0.1, cy: 0.02, r: 0.44)
                    pt.box(-0.44, -0.44, 0.44, 0.44, z1: 8, colors: steel, edge: UIColor(hex: 0xFFD66B))
                    pt.cylinder(cx: 0, cy: 0, r: 0.34, z0: 8, z1: 64, side: (0x3A4658, 0x1F2733), top: 0x53C6D7)
                    for z in [CGFloat(20), 32, 44, 56] {
                        band(pt, cx: 0, cy: 0, r: 0.34, z: z, color: 0x6FE6F2, width: 3)
                    }
                    pt.cylinder(cx: 0, cy: 0, r: 0.39, z0: 64, z1: 70, side: goldSide, top: 0xFFE9A8)
                    pt.cylinder(cx: 0, cy: 0, r: 0.12, z0: 70, z1: 80, side: cyanSide, top: 0xEAFBFD)
                })
                light(group, 0x6FE6F2, 26, x: 0, y: 0, z: 84, animated: animated, period: 1.0)
                for (index, z) in [CGFloat(20), 32, 44, 56].enumerated() {
                    light(group, 0x6FE6F2, 16, x: 0.2, y: 0.2, z: z + 4, animated: animated, period: 1.2, delay: Double(index) * 0.2)
                }
                group.addChild(hologram(width: 52, at: 44, animated: animated))
            } else {
                // Twin tall cells on a shared base.
                group.addChild(Art.sprite(key, canvas(half: 0.5, up: 80)) { pt in
                    pt.softShadow(cx: 0.1, cy: 0.02, r: 0.42)
                    pt.box(-0.42, -0.42, 0.42, 0.42, z1: 6, colors: dark, edge: UIColor(hex: 0x6FE6F2))
                    pt.cylinder(cx: -0.15, cy: -0.15, r: 0.2, z0: 6, z1: 54, side: whiteSide, top: 0x53C6D7)
                    for z in [CGFloat(18), 30, 42] {
                        band(pt, cx: -0.15, cy: -0.15, r: 0.2, z: z, color: 0x53C6D7, width: 2.4)
                    }
                    pt.cylinder(cx: 0.17, cy: 0.17, r: 0.2, z0: 6, z1: 42, side: whiteSide, top: 0x53C6D7)
                    for z in [CGFloat(16), 26, 36] {
                        band(pt, cx: 0.17, cy: 0.17, r: 0.2, z: z, color: 0x53C6D7, width: 2.4)
                    }
                })
                light(group, lamp, 12, x: -0.15, y: -0.15, z: 58, animated: animated)
                light(group, lamp, 12, x: 0.17, y: 0.17, z: 46, animated: animated, delay: 0.5)
            }

        case .solarArray:
            if gold {
                // A solar tree: three panel decks on one tall mast, with a sun core on top.
                group.addChild(Art.sprite(key, canvas(half: 0.5, up: 126)) { pt in
                    pt.softShadow(cx: 0.12, cy: 0.02, r: 0.4)
                    pt.cylinder(cx: 0, cy: 0, r: 0.26, z0: 0, z1: 8, side: goldSide, top: 0x4A566C)
                    pt.line(pt.p(0, 0, 8), pt.p(0, 0, 100), UIColor(hex: 0xDCE3EA), width: 4)
                    panel(pt, cx: 0, cy: 0, z: 26, w: 0.5, d: 0.3, rise: 14, gold: true)
                    panel(pt, cx: 0, cy: 0, z: 54, w: 0.4, d: 0.24, rise: 12, gold: true)
                    panel(pt, cx: 0, cy: 0, z: 80, w: 0.28, d: 0.17, rise: 9, gold: true)
                    let orb = pt.p(0, 0, 104)
                    pt.ctx.setFillColor(UIColor(hex: 0xFFD66B).cgColor)
                    pt.ctx.fillEllipse(in: CGRect(x: orb.x - 6, y: orb.y - 6, width: 12, height: 12))
                })
                light(group, 0xFFE27A, 26, x: 0, y: 0, z: 104, animated: animated, period: 1.2)
                group.addChild(hologram(width: 50, at: 66, animated: animated))
            } else {
                // A big tracking panel on a sturdy mast.
                group.addChild(Art.sprite(key, canvas(half: 0.5, up: 80)) { pt in
                    pt.softShadow(cx: 0.12, cy: 0.02, r: 0.4)
                    pt.box(-0.24, -0.24, 0.24, 0.24, z1: 7, colors: dark, edge: UIColor(hex: 0x6FE6F2))
                    pt.line(pt.p(0, 0, 7), pt.p(0, 0, 36), UIColor(hex: 0xDCE3EA), width: 4.5)
                    panel(pt, cx: 0, cy: 0, z: 32, w: 0.52, d: 0.32, rise: 18, gold: false)
                })
                light(group, lamp, 10, x: 0, y: 0, z: 12, animated: animated)
            }

        case .dish:
            // A tower with a big dish; at the top level it is taller, gold-rimmed, and sends rings upward.
            let towerTop: CGFloat = gold ? 62 : 44
            let dishSize: CGSize = gold ? CGSize(width: 74, height: 40) : CGSize(width: 60, height: 32)
            group.addChild(Art.sprite(key, canvas(half: 0.5, up: 126)) { pt in
                pt.softShadow(cx: 0.1, cy: 0.02, r: 0.42)
                pt.box(-0.38, -0.38, 0.38, 0.38, z1: 8, colors: gold ? steel : white, edge: UIColor(hex: lamp))
                pt.box(-0.14, -0.14, 0.14, 0.14, z0: 8, z1: towerTop, colors: white)
                let strut = UIColor(hex: 0x7F8B9B)
                var z: CGFloat = 16
                while z < towerTop - 4 {
                    pt.line(pt.p(-0.14, 0.14, z), pt.p(0.14, 0.14, z), strut, width: 1)
                    pt.line(pt.p(0.14, -0.14, z), pt.p(0.14, 0.14, z), strut, width: 1)
                    z += 9
                }
                let hub = pt.p(0, 0, towerTop + 14)
                pt.line(pt.p(0, 0, towerTop), hub, UIColor(hex: 0x6E7A8B), width: 3)
                pt.ctx.saveGState()
                pt.ctx.translateBy(x: hub.x, y: hub.y)
                pt.ctx.rotate(by: -0.45)
                let rect = CGRect(x: -dishSize.width / 2, y: -dishSize.height / 2, width: dishSize.width, height: dishSize.height)
                pt.ctx.setFillColor(UIColor(hex: 0xF3F5F7).cgColor)
                pt.ctx.fillEllipse(in: rect)
                pt.ctx.setStrokeColor(UIColor(hex: gold ? 0xE0B24A : 0x9AA6B6).cgColor)
                pt.ctx.setLineWidth(gold ? 2.4 : 1.6)
                pt.ctx.strokeEllipse(in: rect)
                pt.ctx.setStrokeColor(UIColor(hex: 0xC9D2DC).cgColor)
                pt.ctx.setLineWidth(1)
                pt.ctx.strokeEllipse(in: rect.insetBy(dx: dishSize.width * 0.22, dy: dishSize.height * 0.22))
                pt.ctx.setFillColor(UIColor(hex: lamp).cgColor)
                pt.ctx.fillEllipse(in: CGRect(x: -4, y: -4, width: 8, height: 8))
                pt.ctx.restoreGState()
            })
            light(group, lamp, gold ? 16 : 11, x: 0, y: 0, z: towerTop + 14, animated: animated, period: 0.9)
            if animated {
                let origin = CGPoint(x: 6, y: towerTop + 26)
                group.run(.repeatForever(.sequence([.wait(forDuration: gold ? 1.0 : 1.6), .run { [weak group] in
                    guard let group else { return }
                    let ring = SKShapeNode(ellipseOf: CGSize(width: 18, height: 10))
                    ring.strokeColor = UIColor(hex: 0x8BE3EE)
                    ring.lineWidth = 2
                    ring.position = origin
                    ring.zPosition = 2
                    group.addChild(ring)
                    ring.run(.sequence([.group([.scale(to: 3.2, duration: 1.2), .fadeOut(withDuration: 1.2),
                                                .moveBy(x: 16, y: 18, duration: 1.2)]), .removeFromParent()]))
                }])))
            }
            if gold { group.addChild(hologram(width: 48, at: 36, animated: animated)) }

        case .greenhouse:
            if gold {
                // A bio-dome with a garden tower rising through it and a second dome on top.
                group.addChild(Art.sprite(key, canvas(half: 1, up: 124)) { pt in
                    pt.softShadow(cx: 0.3, cy: 0.04, r: 1.0)
                    pt.cylinder(cx: 0, cy: 0, r: 0.96, z0: 0, z1: 12, side: steelSide, top: 0x7A5C3E)
                    band(pt, cx: 0, cy: 0, r: 0.96, z: 9, color: 0xFFD66B, width: 2.5)
                    pt.ctx.setFillColor(UIColor(hex: 0x6FBF73).cgColor)
                    for spot in [CGPoint(x: -0.5, y: 0.1), CGPoint(x: -0.1, y: 0.5), CGPoint(x: 0.5, y: 0.3), CGPoint(x: 0.3, y: -0.4),
                                 CGPoint(x: -0.4, y: -0.4), CGPoint(x: 0.6, y: -0.1), CGPoint(x: 0.0, y: 0.72)] {
                        pt.ctx.fillEllipse(in: pt.ellipseRect(cx: spot.x, cy: spot.y, z: 14, r: 0.16))
                    }
                    pt.cylinder(cx: 0, cy: 0, r: 0.24, z0: 12, z1: 70, side: whiteSide, top: 0xC7CED8)
                    windows(pt, cx: 0, cy: 0, r: 0.24, z: 34, count: 3, color: 0x7EDB6E)
                    windows(pt, cx: 0, cy: 0, r: 0.24, z: 52, count: 3, color: 0x7EDB6E)
                    dome(pt, cx: 0, cy: 0, r: 0.93, z: 12, height: 44,
                         colors: [UIColor(hex: 0xEAFBFD, alpha: 0.5), UIColor(hex: 0x9FE6EF, alpha: 0.3), UIColor(hex: 0x4FB6C8, alpha: 0.34)],
                         outline: UIColor(white: 1, alpha: 0.9))
                    pt.cylinder(cx: 0, cy: 0, r: 0.5, z0: 66, z1: 71, side: goldSide, top: 0x6FBF73)
                    dome(pt, cx: 0, cy: 0, r: 0.47, z: 71, height: 26,
                         colors: [UIColor(hex: 0xEAFBFD, alpha: 0.6), UIColor(hex: 0x9FE6EF, alpha: 0.4), UIColor(hex: 0x4FB6C8, alpha: 0.45)],
                         outline: UIColor(white: 1, alpha: 0.9))
                })
                light(group, 0x7EDB6E, 16, x: 0, y: 0, z: 100, animated: animated)
                group.addChild(hologram(width: 92, at: 60, animated: animated))
            } else {
                // A round glass garden hall on a raised planter.
                group.addChild(Art.sprite(key, canvas(half: 1, up: 90)) { pt in
                    pt.softShadow(cx: 0.3, cy: 0.04, r: 1.0)
                    pt.cylinder(cx: 0, cy: 0, r: 0.94, z0: 0, z1: 10, side: whiteSide, top: 0x7A5C3E)
                    band(pt, cx: 0, cy: 0, r: 0.94, z: 7, color: 0x6FE6F2, width: 2.2)
                    pt.ctx.setFillColor(UIColor(hex: 0x6FBF73).cgColor)
                    for spot in [CGPoint(x: -0.5, y: 0.1), CGPoint(x: -0.1, y: 0.5), CGPoint(x: 0.5, y: 0.3), CGPoint(x: 0.3, y: -0.4),
                                 CGPoint(x: -0.4, y: -0.4), CGPoint(x: 0.0, y: 0.0), CGPoint(x: 0.6, y: -0.1), CGPoint(x: 0.0, y: 0.72)] {
                        pt.ctx.fillEllipse(in: pt.ellipseRect(cx: spot.x, cy: spot.y, z: 13, r: 0.17))
                    }
                    dome(pt, cx: 0, cy: 0, r: 0.9, z: 10, height: 46,
                         colors: [UIColor(hex: 0xEAFBFD, alpha: 0.5), UIColor(hex: 0x9FE6EF, alpha: 0.3), UIColor(hex: 0x4FB6C8, alpha: 0.34)],
                         outline: UIColor(white: 1, alpha: 0.9))
                    let rib = UIColor(white: 1, alpha: 0.6)
                    pt.stroke(frontArc(pt, cx: 0, cy: 0, r: 0.62, z: 40), rib, width: 1)
                    pt.stroke(frontArc(pt, cx: 0, cy: 0, r: 0.82, z: 26), rib, width: 1)
                })
            }
            for (index, x) in [CGFloat(-0.3), 0.3].enumerated() {
                let grow = glow(0xFF7AD9, 40, at: Iso.point(x, 0).offset(0, 30), alpha: 0.4)
                grow.xScale = 1.5
                grow.yScale = 0.5
                group.addChild(grow)
                if animated { pulse(grow, low: 0.15, high: 0.45, period: 2.2, delay: Double(index) * 0.5) }
            }

        case .shelter:
            // A two-storey bunker; at the top level a steel fortress with a turret and a shield bubble.
            group.addChild(Art.sprite(key, canvas(half: 1, up: 96)) { pt in
                pt.shadow(-0.85, -0.72, 0.85, 0.72, length: 0.3)
                let lower = gold ? steel : IsoPainter.BoxColors(0xC9CDD3, 0xA8AFB9, 0x89919D)
                let upper = gold ? IsoPainter.BoxColors(0x8090A6, 0x5C6A80, 0x485468) : IsoPainter.BoxColors(0xD8DCE1, 0xB7BDC6, 0x979FAA)
                let lowTop: CGFloat = gold ? 24 : 20
                let highTop: CGFloat = gold ? 52 : 42
                pt.box(-0.85, -0.72, 0.85, 0.72, z1: lowTop, colors: lower)
                pt.box(-0.9, -0.77, 0.9, 0.77, z0: lowTop, z1: lowTop + 5, colors: gold ? goldBox : dark, edge: UIColor(hex: lamp))
                pt.box(-0.55, -0.45, 0.55, 0.45, z0: lowTop + 5, z1: highTop, colors: upper)
                pt.box(-0.6, -0.5, 0.6, 0.5, z0: highTop, z1: highTop + 4, colors: gold ? goldBox : dark)
                // Door and window slits on the wall that faces the viewer's left.
                pt.fill([pt.p(-0.2, 0.72, 0), pt.p(0.2, 0.72, 0), pt.p(0.2, 0.72, 15), pt.p(-0.2, 0.72, 15)], UIColor(hex: 0x1C2738))
                pt.stroke([pt.p(-0.2, 0.72, 0), pt.p(-0.2, 0.72, 15), pt.p(0.2, 0.72, 15), pt.p(0.2, 0.72, 0)], UIColor(hex: lamp), width: 1.6)
                pt.line(pt.p(-0.38, 0.45, lowTop + 14), pt.p(0.38, 0.45, lowTop + 14), UIColor(hex: lamp), width: 3)
                pt.line(pt.p(0.55, -0.3, lowTop + 14), pt.p(0.55, 0.3, lowTop + 14), UIColor(hex: lamp), width: 3)
                if gold {
                    pt.cylinder(cx: 0, cy: 0, r: 0.26, z0: highTop + 4, z1: highTop + 14, side: steelSide, top: 0x53C6D7)
                    dome(pt, cx: 0, cy: 0, r: 0.22, z: highTop + 14, height: 12, colors: glass, outline: UIColor(white: 1, alpha: 0.9))
                }
            })
            light(group, lamp, 10, x: 0.75, y: 0.62, z: (gold ? 24 : 20) + 8, animated: animated)
            light(group, lamp, 10, x: -0.75, y: 0.62, z: (gold ? 24 : 20) + 8, animated: animated, delay: 0.5)
            if gold {
                let shield = SKShapeNode(ellipseOf: CGSize(width: 176, height: 124))
                shield.position = CGPoint(x: 0, y: 34)
                shield.fillColor = UIColor(hex: 0x8BE3EE, alpha: 0.12)
                shield.strokeColor = UIColor(hex: 0x8BE3EE, alpha: 0.8)
                shield.lineWidth = 2
                shield.glowWidth = 2
                shield.zPosition = 0.5
                group.addChild(shield)
                if animated { pulse(shield, low: 0.5, high: 1, period: 2.0) }
                light(group, 0x6FE6F2, 16, x: 0, y: 0, z: 82, animated: animated, period: 1.0)
            }

        default:
            return nil
        }
        return group
    }

    /// Level 2: a two-storey habitat with a dome on top. Level 3: a three-storey tower with gold rings,
    /// a glass dome, side pods and a spire. The walls take the chosen habitat colour; the lights do not.
    private static func habitat(_ group: SKNode, key: String, gold: Bool, tint: UInt32, animated: Bool) {
        let walls = Art.sprite(key + ".walls", canvas(half: 1.5, up: 176)) { pt in
            pt.softShadow(cx: 0.62, cy: 0.05, r: 1.4)
            if gold {
                pt.cylinder(cx: 0, cy: 0, r: 1.32, z0: 0, z1: 10, side: steelSide, top: 0x6B7B92)
                pt.cylinder(cx: 0, cy: 0, r: 1.1, z0: 10, z1: 40, side: whiteSide, top: 0xCBD3DC)
                pt.cylinder(cx: 0, cy: 0, r: 1.2, z0: 40, z1: 45, side: goldSide, top: 0xD6DDE4)
                pt.cylinder(cx: 0, cy: 0, r: 0.9, z0: 45, z1: 72, side: whiteSide, top: 0xCBD3DC)
                pt.cylinder(cx: 0, cy: 0, r: 1.0, z0: 72, z1: 76, side: goldSide, top: 0xD6DDE4)
                pt.cylinder(cx: 0, cy: 0, r: 0.68, z0: 76, z1: 98, side: whiteSide, top: 0xCBD3DC)
                dome(pt, cx: 0, cy: 0, r: 0.66, z: 98, height: 30, colors: glass, outline: UIColor(white: 1, alpha: 0.9))
                pt.line(pt.p(0, 0, 128), pt.p(0, 0, 152), UIColor(hex: 0xE8ECF0), width: 2.6)
                // Side pods, in front of the tower on the left and on the right.
                for pod in [CGPoint(x: 1.2, y: -0.62), CGPoint(x: -0.62, y: 1.2)] {
                    pt.cylinder(cx: pod.x, cy: pod.y, r: 0.27, z0: 10, z1: 30, side: whiteSide, top: 0xCBD3DC)
                    dome(pt, cx: pod.x, cy: pod.y, r: 0.25, z: 30, height: 13, colors: glass, outline: UIColor(white: 1, alpha: 0.9))
                }
            } else {
                pt.cylinder(cx: 0, cy: 0, r: 1.22, z0: 0, z1: 8, side: (0x8E98A6, 0x667081), top: 0xA9B2BE)
                pt.cylinder(cx: 0, cy: 0, r: 1.05, z0: 8, z1: 34, side: whiteSide, top: 0xCBD3DC)
                pt.cylinder(cx: 0, cy: 0, r: 1.13, z0: 34, z1: 38, side: (0xBFC8D3, 0x8793A3), top: 0xD6DDE4)
                pt.cylinder(cx: 0, cy: 0, r: 0.82, z0: 38, z1: 58, side: whiteSide, top: 0xCBD3DC)
                dome(pt, cx: 0, cy: 0, r: 0.8, z: 58, height: 34, colors: shell, outline: UIColor(hex: 0x8793A3, alpha: 0.6))
                pt.line(pt.p(0, 0, 92), pt.p(0, 0, 114), UIColor(hex: 0x6E7A8B), width: 2.4)
                // Airlock module at the front right.
                pt.box(0.86, -0.3, 1.42, 0.3, z1: 20, colors: white, edge: UIColor(hex: 0x8793A3, alpha: 0.7))
                pt.fill([pt.p(1.42, -0.14, 0), pt.p(1.42, 0.14, 0), pt.p(1.42, 0.14, 14), pt.p(1.42, -0.14, 14)], UIColor(hex: 0x1C2738))
            }
        }
        if tint != 0xFFFFFF {
            walls.color = UIColor(hex: tint)
            walls.colorBlendFactor = 0.34
        }
        group.addChild(walls)

        let lights = Art.sprite(key + ".lights", canvas(half: 1.5, up: 176)) { pt in
            if gold {
                windows(pt, cx: 0, cy: 0, r: 1.1, z: 26, count: 9, color: 0xFFD66B)
                windows(pt, cx: 0, cy: 0, r: 0.9, z: 60, count: 7, color: 0xFFD66B)
                windows(pt, cx: 0, cy: 0, r: 0.68, z: 89, count: 5, color: 0x8BE3EE)
                band(pt, cx: 0, cy: 0, r: 1.32, z: 6, color: 0x6FE6F2, width: 2.4)
                let orb = pt.p(0, 0, 154)
                pt.ctx.setFillColor(UIColor(hex: 0xFFD66B).cgColor)
                pt.ctx.fillEllipse(in: CGRect(x: orb.x - 5, y: orb.y - 5, width: 10, height: 10))
            } else {
                windows(pt, cx: 0, cy: 0, r: 1.05, z: 23, count: 8, color: 0xFFD66B)
                windows(pt, cx: 0, cy: 0, r: 0.82, z: 50, count: 5, color: 0x8BE3EE)
                band(pt, cx: 0, cy: 0, r: 1.22, z: 5, color: 0x6FE6F2, width: 2)
                pt.line(pt.p(0.9, 0.3, 12), pt.p(1.38, 0.3, 12), UIColor(hex: 0x6FE6F2), width: 2.5)
            }
        }
        lights.zPosition = 0.1
        group.addChild(lights)
        if animated {
            lights.run(.repeatForever(.sequence([.wait(forDuration: 2, withRange: 2), .fadeAlpha(to: 0.7, duration: 0.3),
                                                 .fadeAlpha(to: 1, duration: 0.3)])))
        }
        light(group, 0xFFB347, gold ? 18 : 12, x: 0, y: 0, z: gold ? 154 : 115, animated: animated, period: 1.2)
        if gold {
            light(group, 0x8BE3EE, 14, x: 1.2, y: -0.62, z: 44, animated: animated, delay: 0.3)
            light(group, 0x8BE3EE, 14, x: -0.62, y: 1.2, z: 44, animated: animated, delay: 0.7)
            group.addChild(hologram(width: 100, at: 118, animated: animated))
        }
    }
}
