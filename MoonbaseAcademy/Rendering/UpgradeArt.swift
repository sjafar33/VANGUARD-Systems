import SpriteKit
import UIKit

/// What a building gains on the board when it is upgraded, so each level has its own shape:
/// level 2 adds a lit tech deck and new equipment, level 3 adds a gold deck, a glowing core and a hologram.
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
        case .solarArray: return gold ? 106 : 80
        case .battery: return gold ? 80 : 62
        case .dish: return gold ? 100 : 84
        case .greenhouse: return gold ? 78 : 72
        case .shelter: return gold ? 104 : 62
        case .habitat: return gold ? 128 : 122
        default: return 0
        }
    }

    private static func half(_ kind: BuildingKind) -> CGFloat { CGFloat(kind.footprint.w) / 2 }

    private static func canvas(half: CGFloat, up: CGFloat) -> Art.Canvas {
        let width = half * 128 + 56
        let down = half * 32 + 28
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

    // MARK: Shared pieces

    private static let white = IsoPainter.BoxColors(0xEEF1F4, 0xC7CED8, 0xA3ADBB)
    private static let dark = IsoPainter.BoxColors(0x4A5568, 0x364152, 0x2A3342)
    private static let cyanBox = IsoPainter.BoxColors(0x9FF0FA, 0x53C6D7, 0x3A9DB0)
    private static let goldBox = IsoPainter.BoxColors(0xFFE27A, 0xE0B24A, 0xB8862A)

    private static func pylon(_ pt: IsoPainter, _ x: CGFloat, _ y: CGFloat, height: CGFloat, gold: Bool) {
        pt.box(x - 0.09, y - 0.09, x + 0.09, y + 0.09, z1: height, colors: white)
        pt.box(x - 0.12, y - 0.12, x + 0.12, y + 0.12, z0: height, z1: height + 4, colors: gold ? goldBox : cyanBox)
    }

    /// A solar panel tilted toward the viewer, centred on (cx, cy) with its low edge at height z.
    private static func panel(_ pt: IsoPainter, cx: CGFloat, cy: CGFloat, z: CGFloat, w: CGFloat, d: CGFloat,
                              rise: CGFloat, gold: Bool) {
        let a = pt.p(cx - w, cy - d, z + rise)
        let b = pt.p(cx + w, cy - d, z + rise)
        let c = pt.p(cx + w, cy + d, z)
        let e = pt.p(cx - w, cy + d, z)
        pt.fill([a, b, c, e], UIColor(hex: 0x24468F))
        let grid = UIColor(hex: 0x7FB0F0, alpha: 0.8)
        pt.line(pt.lerpQuad(a, b, c, e, 0.33, 0), pt.lerpQuad(a, b, c, e, 0.33, 1), grid, width: 0.8)
        pt.line(pt.lerpQuad(a, b, c, e, 0.66, 0), pt.lerpQuad(a, b, c, e, 0.66, 1), grid, width: 0.8)
        pt.line(pt.lerpQuad(a, b, c, e, 0, 0.5), pt.lerpQuad(a, b, c, e, 1, 0.5), grid, width: 0.8)
        pt.stroke([a, b, c, e], UIColor(hex: gold ? 0xFFD66B : 0xE4EAF0), width: 1.4, close: true)
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
            if animated {
                pulse(ring, low: 0.35, high: 1, period: 1.6, delay: Double(index) * 0.4)
            }
        }
        if animated {
            group.run(.repeatForever(.sequence([.moveBy(x: 0, y: 5, duration: 1.1), .moveBy(x: 0, y: -5, duration: 1.1)])))
        }
        return group
    }

    // MARK: Equipment per building

    /// New equipment for this level, split into what stands behind the building and what stands in front,
    /// so everything overlaps the right way round.
    static func extras(kind: BuildingKind, level: Int, animated: Bool) -> (back: SKNode?, front: SKNode?) {
        guard level >= 2, applies(to: kind) else { return (nil, nil) }
        let gold = level >= 3
        let back = SKNode()
        let front = SKNode()
        let key = "upgrade.\(kind.rawValue).\(level)"
        let light = accent(gold)

        switch kind {
        case .solarArray:
            // A second panel deck above the first; at the top level a third, with a sun core.
            front.addChild(Art.sprite(key, canvas(half: 0.5, up: 112)) { pt in
                let mast = UIColor(hex: 0xC9D2DC)
                pt.line(pt.p(0, 0, 40), pt.p(0, 0, 62), mast, width: 2.6)
                panel(pt, cx: 0, cy: 0, z: 58, w: 0.36, d: 0.2, rise: 10, gold: gold)
                if gold {
                    pt.line(pt.p(0, 0, 66), pt.p(0, 0, 86), mast, width: 2.2)
                    panel(pt, cx: 0, cy: 0, z: 82, w: 0.26, d: 0.15, rise: 8, gold: true)
                }
            })
            let core = glow(light, gold ? 18 : 10, at: CGPoint(x: 0, y: gold ? 98 : 72))
            front.addChild(core)
            if animated { pulse(core, low: 0.35, high: 1, period: 1.4) }
            if gold { front.addChild(hologram(width: 44, at: 50, animated: animated)) }

        case .battery:
            // Extra cells with light strips; at the top level a second cell and an energy core.
            back.addChild(Art.sprite(key + ".back", canvas(half: 0.5, up: 60)) { pt in
                pt.box(0.1, -0.46, 0.44, -0.12, z1: 26, colors: dark)
                for z in [CGFloat(7), 13, 19] {
                    pt.line(pt.p(0.12, -0.12, z), pt.p(0.42, -0.12, z), UIColor(hex: light), width: 1.8)
                }
            })
            let cell = glow(light, 10, at: Iso.point(0.27, -0.29).offset(0, 30))
            back.addChild(cell)
            if animated { pulse(cell, low: 0.3, high: 1, period: 1.2) }
            if gold {
                front.addChild(Art.sprite(key + ".front", canvas(half: 0.5, up: 60)) { pt in
                    pt.box(-0.46, 0.12, -0.12, 0.46, z1: 20, colors: dark)
                    for z in [CGFloat(6), 11, 16] {
                        pt.line(pt.p(-0.44, 0.46, z), pt.p(-0.14, 0.46, z), UIColor(hex: light), width: 1.8)
                    }
                })
                let core = glow(light, 22, at: CGPoint(x: 0, y: 68))
                front.addChild(core)
                if animated { pulse(core, low: 0.4, high: 1, period: 1.0) }
                front.addChild(hologram(width: 44, at: 52, animated: animated))
            }

        case .dish:
            // A relay box with a second dish; at the top level a tall signal spire with rings.
            back.addChild(Art.sprite(key, canvas(half: 0.5, up: 108)) { pt in
                pt.box(-0.46, -0.46, -0.2, -0.2, z1: 14, colors: white)
                let foot = pt.p(-0.33, -0.33, 14)
                let tip = pt.p(-0.33, -0.33, gold ? 88 : 34)
                pt.line(foot, tip, UIColor(hex: 0xC9D2DC), width: 2.4)
                if gold {
                    pt.ctx.setStrokeColor(UIColor(hex: 0x8BE3EE).cgColor)
                    pt.ctx.setLineWidth(2)
                    let rings: [(CGFloat, CGFloat)] = [(44, 11), (58, 8), (72, 5)]
                    for (z, r) in rings {
                        let c = pt.p(-0.33, -0.33, z)
                        pt.ctx.strokeEllipse(in: CGRect(x: c.x - r, y: c.y - r * 0.5, width: r * 2, height: r))
                    }
                } else {
                    pt.ctx.setFillColor(UIColor(hex: 0xF3F5F7).cgColor)
                    pt.ctx.fillEllipse(in: CGRect(x: tip.x - 10, y: tip.y - 6, width: 20, height: 11))
                    pt.ctx.setStrokeColor(UIColor(hex: 0x9AA6B6).cgColor)
                    pt.ctx.setLineWidth(1.2)
                    pt.ctx.strokeEllipse(in: CGRect(x: tip.x - 10, y: tip.y - 6, width: 20, height: 11))
                }
            })
            let beacon = glow(light, gold ? 16 : 9, at: Iso.point(-0.33, -0.33).offset(0, gold ? 90 : 37))
            back.addChild(beacon)
            if animated { pulse(beacon, low: 0.25, high: 1, period: 0.9) }
            if gold { front.addChild(hologram(width: 40, at: 44, animated: animated)) }

        case .greenhouse:
            // A water tank and grow lights; at the top level a bio-tower with lit windows.
            back.addChild(Art.sprite(key, canvas(half: 1, up: 112)) { pt in
                pt.cylinder(cx: 0.8, cy: -0.8, r: 0.15, z0: 0, z1: 26, side: (0x8FD3F4, 0x4A9FCC), top: 0xBFE9FB)
                if gold {
                    pt.box(-0.96, -0.96, -0.56, -0.56, z1: 46, colors: white)
                    let window = UIColor(hex: 0x7EDB6E)
                    for z in [CGFloat(12), 23, 34] {
                        pt.line(pt.p(-0.9, -0.56, z), pt.p(-0.62, -0.56, z), window, width: 3)
                        pt.line(pt.p(-0.56, -0.9, z), pt.p(-0.56, -0.62, z), window, width: 3)
                    }
                    pt.box(-1.0, -1.0, -0.52, -0.52, z0: 46, z1: 52, colors: goldBox)
                }
            })
            for (index, x) in [CGFloat(-0.3), 0.3].enumerated() {
                let lamp = glow(0xFF7AD9, 40, at: Iso.point(x, 0).offset(0, 26), alpha: 0.45)
                lamp.xScale = 1.6
                lamp.yScale = 0.5
                front.addChild(lamp)
                if animated { pulse(lamp, low: 0.2, high: 0.5, period: 2.2, delay: Double(index) * 0.5) }
            }
            if gold {
                let beacon = glow(0x7EDB6E, 14, at: Iso.point(-0.76, -0.76).offset(0, 56))
                back.addChild(beacon)
                if animated { pulse(beacon, low: 0.3, high: 1, period: 1.3) }
                front.addChild(hologram(width: 84, at: 62, animated: animated))
            }

        case .shelter:
            // Armour plating and marker lights; at the top level a mast and a glowing shield bubble.
            let offset = Iso.point(-0.24, -0.11)
            let armour = Art.sprite(key, canvas(half: 1, up: 80)) { pt in
                pt.box(-0.68, -0.5, 0.68, 0.5, z0: 25, z1: 29, colors: IsoPainter.BoxColors(0x56667E, 0x3F4C60, 0x323D4E),
                       edge: UIColor(hex: light))
                pt.box(0.5, 0.34, 0.62, 0.46, z0: 29, z1: 33, colors: gold ? goldBox : cyanBox)
                pt.box(-0.62, 0.34, -0.5, 0.46, z0: 29, z1: 33, colors: gold ? goldBox : cyanBox)
                if gold {
                    pt.line(pt.p(0, 0, 29), pt.p(0, 0, 54), UIColor(hex: 0xC9D2DC), width: 2.2)
                    pt.box(-0.06, -0.06, 0.06, 0.06, z0: 54, z1: 58, colors: goldBox)
                }
            }
            armour.position = offset
            front.addChild(armour)
            for (index, x) in [CGFloat(0.56), -0.56].enumerated() {
                let lamp = glow(light, 10, at: offset + Iso.point(x, 0.4).offset(0, 35))
                front.addChild(lamp)
                if animated { pulse(lamp, low: 0.2, high: 1, period: 1.0, delay: Double(index) * 0.5) }
            }
            if gold {
                let shield = SKShapeNode(ellipseOf: CGSize(width: 170, height: 118))
                shield.position = offset + CGPoint(x: 0, y: 34)
                shield.fillColor = UIColor(hex: 0x8BE3EE, alpha: 0.12)
                shield.strokeColor = UIColor(hex: 0x8BE3EE, alpha: 0.8)
                shield.lineWidth = 2
                shield.glowWidth = 2
                shield.zPosition = 0.5
                front.addChild(shield)
                if animated { pulse(shield, low: 0.5, high: 1, period: 2.0) }
            }

        case .habitat:
            // Light pylons and a new module; at the top level a second module, a spire and a halo.
            let height: CGFloat = gold ? 30 : 20
            back.addChild(Art.sprite(key + ".back", canvas(half: 1.5, up: 100)) { pt in
                pylon(pt, -1.3, -1.3, height: height, gold: gold)
                if gold {
                    pt.box(-1.44, -0.35, -0.96, 0.35, z1: 16, colors: white)
                    pt.line(pt.p(-1.4, 0.35, 9), pt.p(-1.0, 0.35, 9), UIColor(hex: light), width: 2.5)
                }
            })
            front.addChild(Art.sprite(key + ".front", canvas(half: 1.5, up: 150)) { pt in
                pylon(pt, 1.3, -1.3, height: height, gold: gold)
                pylon(pt, -1.3, 1.3, height: height, gold: gold)
                pt.box(0.96, -0.35, 1.44, 0.35, z1: 18, colors: white)
                pt.line(pt.p(1.0, 0.35, 10), pt.p(1.4, 0.35, 10), UIColor(hex: light), width: 2.5)
                pt.line(pt.p(1.44, -0.3, 10), pt.p(1.44, 0.3, 10), UIColor(hex: light), width: 2.5)
                pt.box(1.1, -0.15, 1.3, 0.05, z0: 18, z1: 22, colors: gold ? goldBox : cyanBox)
                pylon(pt, 1.3, 1.3, height: height, gold: gold)
                if gold {
                    pt.line(pt.p(0, 0, 62), pt.p(0, 0, 108), UIColor(hex: 0xE8ECF0), width: 2.6)
                    let orb = pt.p(0, 0, 110)
                    pt.ctx.setFillColor(UIColor(hex: 0xFFD66B).cgColor)
                    pt.ctx.fillEllipse(in: CGRect(x: orb.x - 5, y: orb.y - 5, width: 10, height: 10))
                }
            })
            let corners = [CGPoint(x: -1.3, y: -1.3), CGPoint(x: 1.3, y: -1.3), CGPoint(x: 1.3, y: 1.3), CGPoint(x: -1.3, y: 1.3)]
            for (index, corner) in corners.enumerated() {
                let lamp = glow(light, 12, at: Iso.point(corner).offset(0, height + 6))
                (index == 0 ? back : front).addChild(lamp)
                if animated { pulse(lamp, low: 0.2, high: 1, period: 1.6, delay: Double(index) * 0.4) }
            }
            if gold {
                let orb = glow(0xFFE27A, 20, at: CGPoint(x: 0, y: 110))
                front.addChild(orb)
                if animated { pulse(orb, low: 0.4, high: 1, period: 1.2) }
                front.addChild(hologram(width: 96, at: 84, animated: animated))
            }

        default:
            break
        }
        return (back, front)
    }
}
