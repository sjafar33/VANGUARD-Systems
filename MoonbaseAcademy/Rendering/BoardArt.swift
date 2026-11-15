import SpriteKit
import UIKit

/// Art for the base board: the tiled platform, a footprint plate per building that shows its level,
/// and building nodes built from the existing structure art.
@MainActor
enum BoardArt {
    static let dishCanvas = Art.Canvas(size: CGSize(width: 96, height: 112), origin: CGPoint(x: 46, y: 84))

    // MARK: Board

    /// A raised square platform cut into tiles, drawn in the shared isometric projection.
    static func board(color: UInt32, trim: UInt32) -> SKSpriteNode {
        let low = BoardScene.low
        let high = BoardScene.high
        let thickness: CGFloat = 14
        let left = Iso.point(low, high)
        let right = Iso.point(high, low)
        let top = Iso.point(low, low)
        let bottom = Iso.point(high, high)
        let margin: CGFloat = 12
        let size = CGSize(width: right.x - left.x + margin * 2, height: top.y - bottom.y + thickness + margin * 2)
        let origin = CGPoint(x: -left.x + margin, y: top.y + margin)
        let canvas = Art.Canvas(size: size, origin: origin)
        let texture = ArtCache.shared.texture("board.\(color).\(trim)", size: size, scale: 2) { ctx in
            func c(_ p: CGPoint) -> CGPoint { CGPoint(x: origin.x + p.x, y: origin.y - p.y) }
            func poly(_ pts: [CGPoint]) -> CGPath {
                let path = CGMutablePath()
                path.addLines(between: pts.map(c))
                path.closeSubpath()
                return path
            }
            let base = UIColor(hex: color)
            // Side faces give the platform its thickness.
            let down = CGPoint(x: 0, y: -thickness)
            ctx.addPath(poly([left, bottom, bottom + down, left + down]))
            ctx.setFillColor(base.adjusted(by: -0.28).cgColor)
            ctx.fillPath()
            ctx.addPath(poly([bottom, right, right + down, bottom + down]))
            ctx.setFillColor(base.adjusted(by: -0.4).cgColor)
            ctx.fillPath()
            // Top surface with a soft light from the upper left.
            let topPath = poly([top, right, bottom, left])
            ctx.saveGState()
            ctx.addPath(topPath)
            ctx.clip()
            let colors = [base.adjusted(by: 0.12).cgColor, base.cgColor, base.adjusted(by: -0.1).cgColor] as CFArray
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 0.55, 1]) {
                ctx.drawLinearGradient(gradient, start: c(left), end: c(right), options: [])
            }
            // Checker tiles, very subtle, so the grid reads without shouting.
            for x in BaseState.minCoord...BaseState.maxCoord {
                for y in BaseState.minCoord...BaseState.maxCoord where (x + y) % 2 == 0 {
                    let fx = CGFloat(x), fy = CGFloat(y)
                    ctx.addPath(poly([Iso.point(fx, fy), Iso.point(fx + 1, fy), Iso.point(fx + 1, fy + 1), Iso.point(fx, fy + 1)]))
                }
            }
            ctx.setFillColor(UIColor(white: 1, alpha: 0.06).cgColor)
            ctx.fillPath()
            // Grid lines.
            ctx.setStrokeColor(UIColor(white: 1, alpha: 0.16).cgColor)
            ctx.setLineWidth(1)
            for i in BaseState.minCoord...(BaseState.maxCoord + 1) {
                let f = CGFloat(i)
                ctx.move(to: c(Iso.point(f, low)))
                ctx.addLine(to: c(Iso.point(f, high)))
                ctx.move(to: c(Iso.point(low, f)))
                ctx.addLine(to: c(Iso.point(high, f)))
            }
            ctx.strokePath()
            ctx.restoreGState()
            // Trim around the edge, like a base wall.
            ctx.addPath(topPath)
            ctx.setStrokeColor(UIColor(hex: trim).cgColor)
            ctx.setLineWidth(4)
            ctx.strokePath()
            ctx.addPath(poly([left, bottom, right]))
            ctx.setStrokeColor(UIColor(hex: trim).withAlphaComponent(0.5).cgColor)
            ctx.setLineWidth(2)
            ctx.strokePath()
        }
        return Art.sprite(texture, canvas)
    }

    // MARK: Buildings

    static func levelColor(_ level: Int) -> UInt32 {
        switch level {
        case 3: return 0xF2B84B
        case 2: return 0x53C6D7
        default: return 0x8D98A8
        }
    }

    /// The building, standing on a plate whose rim colour shows its level (grey, blue, gold),
    /// with level pips above it. Level is also announced in words by the SwiftUI panels.
    static func building(_ b: PlacedBuilding, habitatTint: UInt32, animated: Bool = false) -> SKNode {
        let node = SKNode()
        let size = b.kind.footprint
        node.addChild(plate(w: size.w, h: size.h, level: b.level))
        let body: SKNode
        switch b.kind {
        case .habitat:
            let group = SKNode()
            let dome = Art.habitatBody()
            if habitatTint != 0xFFFFFF {
                dome.color = UIColor(hex: habitatTint)
                dome.colorBlendFactor = 0.38
            }
            group.addChild(dome)
            let windows = Art.sprite(Art.habitatWindowsTexture(lit: true), Art.habitatCanvas)
            windows.zPosition = 0.1
            group.addChild(windows)
            // Antenna beacon (same spot as on the drill screen).
            let beacon = SKSpriteNode(texture: Art.glowDot(color: 0xFFB347, diameter: 12))
            beacon.position = CGPoint(x: 4.5, y: 89.5)
            beacon.zPosition = 0.3
            beacon.blendMode = .add
            group.addChild(beacon)
            if animated {
                beacon.run(.repeatForever(.sequence([.fadeAlpha(to: 1, duration: 0.12), .wait(forDuration: 0.25),
                                                     .fadeAlpha(to: 0.15, duration: 0.5), .wait(forDuration: 0.9)])))
                windows.run(.repeatForever(.sequence([.wait(forDuration: 2, withRange: 2), .fadeAlpha(to: 0.7, duration: 0.3),
                                                      .fadeAlpha(to: 1, duration: 0.3)])))
            }
            body = group
        case .solarArray:
            let group = SKNode()
            group.addChild(Art.solarArray())
            if animated { addGlint(to: group) }
            body = group
        case .battery:
            let group = SKNode()
            group.addChild(Art.batteryBody())
            let charge = Art.sprite(Art.batteryChargeTexture(level: 3, low: false), Art.batteryCanvas)
            charge.zPosition = 0.1
            group.addChild(charge)
            if animated {
                // Charging: the bars fill up, then start again.
                let levels = (1...5).map { Art.batteryChargeTexture(level: $0, low: $0 <= 1) }
                charge.run(.repeatForever(.sequence([.animate(with: levels, timePerFrame: 0.45), .wait(forDuration: 0.8)])))
            }
            body = group
        case .greenhouse:
            let group = SKNode()
            group.addChild(Art.greenhouseBase())
            // A few plants inside, more at higher levels.
            let plants = [CGPoint(x: -0.6, y: 0), CGPoint(x: -0.2, y: 0), CGPoint(x: 0.2, y: 0), CGPoint(x: 0.6, y: 0)]
            for spot in plants {
                let plant = Art.sprite(Art.plantTexture(level: min(2, b.level)), Art.plantCanvas)
                plant.position = Iso.point(spot).offset(0, 7)
                plant.zPosition = 0.1
                group.addChild(plant)
            }
            let shell = Art.greenhouseShell()
            shell.zPosition = 0.2
            group.addChild(shell)
            let glow = Art.greenhouseGlow()
            glow.zPosition = 0.15
            group.addChild(glow)
            if animated {
                glow.run(.repeatForever(.sequence([.fadeAlpha(to: 0.55, duration: 1.4), .fadeAlpha(to: 1, duration: 1.4)])))
                for case let plant as SKSpriteNode in group.children where plant.zPosition == 0.1 {
                    let sway = SKAction.sequence([.scaleY(to: 1.08, duration: 0.9), .scaleY(to: 0.96, duration: 0.9)])
                    plant.run(.sequence([.wait(forDuration: Double.random(in: 0...0.8)), .repeatForever(sway)]))
                }
            }
            body = group
        case .shelter:
            let group = SKNode()
            let shelter = Art.shelterBody()
            shelter.position = Iso.point(-0.24, -0.11)
            group.addChild(shelter)
            let glow = Art.shelterGlow()
            glow.position = shelter.position
            glow.zPosition = 0.1
            group.addChild(glow)
            if animated {
                glow.run(.repeatForever(.sequence([.fadeAlpha(to: 0.4, duration: 1.2), .fadeAlpha(to: 1, duration: 1.2)])))
            }
            body = group
        case .dish:
            let group = SKNode()
            let dish = groundDish()
            group.addChild(dish)
            if animated {
                dish.run(.repeatForever(.sequence([.rotate(toAngle: 0.04, duration: 2.2), .rotate(toAngle: -0.04, duration: 2.2)])))
                // Signal rings going out to Earth.
                group.run(.repeatForever(.sequence([.wait(forDuration: 1.6), .run { [weak group] in
                    guard let group else { return }
                    let ring = SKShapeNode(ellipseOf: CGSize(width: 18, height: 10))
                    ring.strokeColor = UIColor(hex: 0x8BE3EE)
                    ring.lineWidth = 2
                    ring.position = CGPoint(x: 0, y: 52)
                    ring.zPosition = 2
                    group.addChild(ring)
                    ring.run(.sequence([.group([.scale(to: 3, duration: 1.2), .fadeOut(withDuration: 1.2),
                                                .moveBy(x: 14, y: 14, duration: 1.2)]), .removeFromParent()]))
                }])))
            }
            body = group
        case .landingStation:
            body = b.isWorking ? stationRestored(animated: animated) : stationRuin(animated: animated)
        case .flag:
            body = flag(animated: animated)
        case .lamp:
            body = lamp(animated: animated)
        case .rockGarden:
            body = rockGarden(animated: animated)
        }
        body.zPosition = 1
        // Higher levels stand a little taller, on a lit deck, with new equipment around them.
        body.setScale(1 + CGFloat(b.level - 1) * 0.06)
        let lift = UpgradeArt.applies(to: b.kind) ? UpgradeArt.lift(b.level) : 0
        body.position = CGPoint(x: body.position.x, y: body.position.y + lift)
        if let deck = UpgradeArt.platform(kind: b.kind, level: b.level) {
            node.addChild(deck)
        }
        let extras = UpgradeArt.extras(kind: b.kind, level: b.level, animated: animated)
        if let back = extras.back {
            back.position = CGPoint(x: 0, y: lift)
            back.zPosition = 0.8
            node.addChild(back)
        }
        node.addChild(body)
        if let front = extras.front {
            front.position = CGPoint(x: 0, y: lift)
            front.zPosition = 2
            node.addChild(front)
        }
        // The landing station has no levels: it is either a ruin or repaired.
        if b.kind != .landingStation && !b.kind.isDecoration {
            let height = max(pipHeight(b.kind), UpgradeArt.top(b.kind, level: b.level)) + lift
            node.addChild(levelPips(b.level, height: height))
        }
        if animated && b.level >= BuildingKind.maxLevel {
            // Top level: a few gold sparkles now and then.
            node.run(.repeatForever(.sequence([.wait(forDuration: 1.2, withRange: 1), .run { [weak node] in
                guard let node else { return }
                let star = SKSpriteNode(texture: Art.glowDot(color: 0xFFE27A, diameter: 10))
                star.position = CGPoint(x: CGFloat.random(in: -30...30), y: CGFloat.random(in: 10...60))
                star.blendMode = .add
                star.zPosition = 6
                star.alpha = 0
                node.addChild(star)
                star.run(.sequence([.fadeIn(withDuration: 0.25), .fadeOut(withDuration: 0.5), .removeFromParent()]))
            }])))
        }
        return node
    }

    /// A light sweeping across a solar panel now and then.
    private static func addGlint(to node: SKNode) {
        let glint = SKSpriteNode(texture: Art.glowDot(color: 0xFFFFFF, diameter: 28))
        glint.position = CGPoint(x: -12, y: 22)
        glint.yScale = 0.45
        glint.alpha = 0
        glint.blendMode = .add
        glint.zPosition = 0.2
        node.addChild(glint)
        let sweep = SKAction.group([.sequence([.fadeAlpha(to: 0.85, duration: 0.18), .fadeAlpha(to: 0, duration: 0.45)]),
                                    .moveBy(x: 26, y: 8, duration: 0.63)])
        glint.run(.repeatForever(.sequence([.wait(forDuration: 3.5, withRange: 3), sweep, .moveBy(x: -26, y: -8, duration: 0)])))
    }

    /// The robot buddy that walks around the base, in the chosen colours.
    static let robotCanvas = Art.Canvas(size: CGSize(width: 44, height: 56), origin: CGPoint(x: 22, y: 50))

    static func robot(shell: UInt32, eyes: UInt32) -> SKSpriteNode {
        let texture = ArtCache.shared.texture("board.robot.\(shell).\(eyes)", size: robotCanvas.size) { ctx in
            // Shadow.
            ctx.setFillColor(UIColor(white: 0, alpha: 0.22).cgColor)
            ctx.fillEllipse(in: CGRect(x: 8, y: 46, width: 28, height: 8))
            // Body.
            let body = CGRect(x: 12, y: 32, width: 20, height: 14)
            ctx.addPath(CGPath(roundedRect: body, cornerWidth: 6, cornerHeight: 6, transform: nil))
            ctx.setFillColor(UIColor(hex: shell).adjusted(by: -0.12).cgColor)
            ctx.fillPath()
            // Antenna.
            ctx.setStrokeColor(UIColor(hex: 0x6E7A8B).cgColor)
            ctx.setLineWidth(2)
            ctx.move(to: CGPoint(x: 22, y: 8))
            ctx.addLine(to: CGPoint(x: 22, y: 3))
            ctx.strokePath()
            ctx.setFillColor(UIColor(hex: 0xF2B84B).cgColor)
            ctx.fillEllipse(in: CGRect(x: 19, y: 0, width: 6, height: 6))
            // Head.
            let head = CGRect(x: 6, y: 7, width: 32, height: 27)
            ctx.addPath(CGPath(roundedRect: head.offsetBy(dx: 0, dy: 2), cornerWidth: 11, cornerHeight: 11, transform: nil))
            ctx.setFillColor(UIColor(hex: 0x8794A6).cgColor)
            ctx.fillPath()
            ctx.addPath(CGPath(roundedRect: head, cornerWidth: 11, cornerHeight: 11, transform: nil))
            ctx.setFillColor(UIColor(hex: shell).cgColor)
            ctx.fillPath()
            // Visor and eyes.
            let visor = head.insetBy(dx: 5, dy: 6)
            ctx.addPath(CGPath(roundedRect: visor, cornerWidth: 6, cornerHeight: 6, transform: nil))
            ctx.setFillColor(UIColor(hex: 0x16223A).cgColor)
            ctx.fillPath()
            ctx.setFillColor(UIColor(hex: eyes).cgColor)
            for x in [visor.midX - 6, visor.midX + 3] {
                ctx.addPath(CGPath(roundedRect: CGRect(x: x, y: visor.midY - 4, width: 3.5, height: 7), cornerWidth: 1.7, cornerHeight: 1.7, transform: nil))
                ctx.fillPath()
            }
        }
        return Art.sprite(texture, robotCanvas)
    }

    private static func pipHeight(_ kind: BuildingKind) -> CGFloat {
        switch kind {
        case .habitat: return 120
        case .greenhouse: return 70
        case .shelter: return 58
        case .dish: return 82
        case .solarArray: return 52
        case .battery: return 60
        case .landingStation: return 64
        case .flag, .lamp, .rockGarden: return 60
        }
    }

    // MARK: Decorations (looks only)

    static let decorCanvas = Art.Canvas(size: CGSize(width: 72, height: 84), origin: CGPoint(x: 32, y: 64))

    private static func flag(animated: Bool) -> SKNode {
        let group = SKNode()
        group.addChild(Art.sprite("board.decor.flagpole", decorCanvas) { pt in
            pt.softShadow(cx: 0.08, cy: 0, r: 0.2)
            pt.box(-0.12, -0.12, 0.12, 0.12, z1: 5, colors: .init(0xC3CBD6, 0x97A2B1, 0x7B8798))
            pt.line(pt.p(0, 0, 5), pt.p(0, 0, 56), UIColor(hex: 0xE8ECF0), width: 2.6)
            pt.ctx.setFillColor(UIColor(hex: 0xF2B84B).cgColor)
            let top = pt.p(0, 0, 58)
            pt.ctx.fillEllipse(in: CGRect(x: top.x - 3, y: top.y - 3, width: 6, height: 6))
        })
        // The cloth is its own sprite so it can wave.
        let clothCanvas = Art.Canvas(size: CGSize(width: 30, height: 20), origin: CGPoint(x: 0, y: 1))
        let cloth = Art.sprite("board.decor.flagcloth", clothCanvas) { pt in
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 0, y: 1))
            path.addLine(to: CGPoint(x: 27, y: 4))
            path.addLine(to: CGPoint(x: 20, y: 9))
            path.addLine(to: CGPoint(x: 27, y: 15))
            path.addLine(to: CGPoint(x: 0, y: 17))
            path.closeSubpath()
            pt.fill(path, UIColor(hex: 0x2CAEC3))
            pt.ctx.setFillColor(UIColor(hex: 0xFFE27A).cgColor)
            pt.ctx.fillEllipse(in: CGRect(x: 5, y: 5, width: 8, height: 8))
        }
        cloth.position = CGPoint(x: 1, y: 55)
        cloth.zPosition = 0.1
        group.addChild(cloth)
        if animated {
            cloth.run(.repeatForever(.sequence([.scaleX(to: 0.86, duration: 0.7), .scaleX(to: 1, duration: 0.7)])))
        }
        return group
    }

    private static func lamp(animated: Bool) -> SKNode {
        let group = SKNode()
        group.addChild(Art.sprite("board.decor.lamp", decorCanvas) { pt in
            pt.softShadow(cx: 0.08, cy: 0, r: 0.2)
            pt.box(-0.12, -0.12, 0.12, 0.12, z1: 5, colors: .init(0xAEB7C3, 0x8792A1, 0x6C7787))
            pt.line(pt.p(0, 0, 5), pt.p(0, 0, 40), UIColor(hex: 0x6E7A8B), width: 3)
            let head = pt.p(0, 0, 46)
            pt.ctx.setFillColor(UIColor(hex: 0x3A4658).cgColor)
            pt.ctx.fillEllipse(in: CGRect(x: head.x - 9, y: head.y - 8, width: 18, height: 16))
            pt.ctx.setFillColor(UIColor(hex: 0xFFE9A8).cgColor)
            pt.ctx.fillEllipse(in: CGRect(x: head.x - 6, y: head.y - 5, width: 12, height: 10))
        })
        let glow = SKSpriteNode(texture: Art.glowDot(color: 0xFFE27A, diameter: 34))
        glow.position = CGPoint(x: 0, y: 46)
        glow.zPosition = 0.1
        glow.blendMode = .add
        glow.alpha = 0.7
        group.addChild(glow)
        if animated {
            glow.run(.repeatForever(.sequence([.fadeAlpha(to: 0.45, duration: 1.3), .fadeAlpha(to: 0.8, duration: 1.3)])))
        }
        return group
    }

    private static func rockGarden(animated: Bool) -> SKNode {
        let group = SKNode()
        group.addChild(Art.sprite("board.decor.rocks", decorCanvas) { pt in
            pt.softShadow(cx: 0.06, cy: 0.02, r: 0.4)
            pt.box(-0.34, -0.14, -0.04, 0.2, z1: 11, colors: .init(0xB4BBC5, 0x8D95A1, 0x727A87))
            pt.box(0.02, -0.3, 0.3, -0.04, z1: 7, colors: .init(0xA7AEB9, 0x838B97, 0x6A727F))
            pt.box(-0.14, 0.22, 0.06, 0.38, z1: 5, colors: .init(0xBDC4CD, 0x959DA9, 0x78808D))
            // A crystal standing between the rocks.
            let base1 = pt.p(0.1, 0.12, 0)
            let base2 = pt.p(0.3, 0.12, 0)
            let base3 = pt.p(0.2, 0.26, 0)
            let tip = pt.p(0.2, 0.17, 26)
            pt.fill([base1, base3, tip], UIColor(hex: 0x8BE3EE))
            pt.fill([base3, base2, tip], UIColor(hex: 0x4FB6C8))
        })
        let glow = SKSpriteNode(texture: Art.glowDot(color: 0x8BE3EE, diameter: 26))
        glow.position = Iso.point(0.2, 0.17).offset(0, 14)
        glow.zPosition = 0.1
        glow.blendMode = .add
        glow.alpha = 0.55
        group.addChild(glow)
        if animated {
            glow.run(.repeatForever(.sequence([.fadeAlpha(to: 0.2, duration: 1.1), .fadeAlpha(to: 0.65, duration: 1.1)])))
        }
        return group
    }

    // MARK: Landing station

    static let stationCanvas = Art.Canvas(size: CGSize(width: 176, height: 132), origin: CGPoint(x: 88, y: 82))

    /// The repaired station: a clean pad with a landing circle, corner lights and a small control tower.
    private static func stationRestored(animated: Bool) -> SKNode {
        let group = SKNode()
        let pad = Art.sprite("board.station.restored", stationCanvas) { pt in
            pt.shadow(-0.9, -0.9, 0.9, 0.9, length: 0.22)
            pt.box(-0.9, -0.9, 0.9, 0.9, z1: 6, colors: .init(0xC3CBD6, 0x97A2B1, 0x7B8798), edge: UIColor(hex: 0x5E6978))
            // Landing circle and cross.
            let yellow = UIColor(hex: 0xF2B84B)
            pt.ctx.setStrokeColor(yellow.cgColor)
            pt.ctx.setLineWidth(3)
            pt.ctx.strokeEllipse(in: pt.ellipseRect(cx: 0.12, cy: 0.12, z: 6, r: 0.58))
            pt.line(pt.p(-0.16, 0.12, 6), pt.p(0.4, 0.12, 6), yellow, width: 2.4)
            pt.line(pt.p(0.12, -0.16, 6), pt.p(0.12, 0.4, 6), yellow, width: 2.4)
            // Corner light housings.
            for corner in [CGPoint(x: 0.78, y: -0.78), CGPoint(x: 0.78, y: 0.78), CGPoint(x: -0.78, y: 0.78)] {
                pt.box(corner.x - 0.07, corner.y - 0.07, corner.x + 0.07, corner.y + 0.07, z0: 6, z1: 10,
                       colors: .init(0xFFD66B, 0xD9A63A, 0xB8862A))
            }
            // Control tower at the back corner.
            pt.box(-0.86, -0.86, -0.5, -0.5, z0: 6, z1: 30, colors: .init(0xEEF1F4, 0xC7CED8, 0xA3ADBB))
            pt.box(-0.92, -0.92, -0.44, -0.44, z0: 30, z1: 39, colors: .init(0xBFEFF5, 0x6FC4D2, 0x4A9DAD),
                   edge: UIColor(hex: 0x2F6E7A))
            pt.line(pt.p(-0.68, -0.68, 39), pt.p(-0.68, -0.68, 50), UIColor(hex: 0x6E7A8B), width: 2)
        }
        group.addChild(pad)
        let lights = [CGPoint(x: 0.78, y: -0.78), CGPoint(x: 0.78, y: 0.78), CGPoint(x: -0.78, y: 0.78)]
        for (index, corner) in lights.enumerated() {
            let light = SKSpriteNode(texture: Art.glowDot(color: 0xFFE27A, diameter: 14))
            light.position = Iso.point(corner).offset(0, 11)
            light.zPosition = 0.2
            light.blendMode = .add
            group.addChild(light)
            if animated {
                // The lights blink one after another, like a runway.
                light.alpha = 0.25
                light.run(.sequence([.wait(forDuration: Double(index) * 0.35),
                                     .repeatForever(.sequence([.fadeAlpha(to: 1, duration: 0.15), .fadeAlpha(to: 0.25, duration: 0.45),
                                                               .wait(forDuration: 0.45)]))]))
            }
        }
        let beacon = SKSpriteNode(texture: Art.glowDot(color: 0x8BE3EE, diameter: 12))
        beacon.position = Iso.point(-0.68, -0.68).offset(0, 51)
        beacon.zPosition = 0.3
        beacon.blendMode = .add
        group.addChild(beacon)
        if animated {
            beacon.run(.repeatForever(.sequence([.fadeAlpha(to: 1, duration: 0.2), .fadeAlpha(to: 0.2, duration: 0.9)])))
        }
        return group
    }

    /// The ruin: a cracked, dusty pad with a broken tower, and a wrench badge so it reads as "fix me".
    private static func stationRuin(animated: Bool) -> SKNode {
        let group = SKNode()
        let pad = Art.sprite("board.station.ruin", stationCanvas) { pt in
            pt.shadow(-0.9, -0.9, 0.9, 0.9, length: 0.18, alpha: 0.18)
            pt.box(-0.9, -0.9, 0.9, 0.9, z1: 5, colors: .init(0x858D99, 0x676F7B, 0x535B67))
            // What is left of the landing circle.
            pt.ctx.setStrokeColor(UIColor(hex: 0xC9A455, alpha: 0.4).cgColor)
            pt.ctx.setLineWidth(2.5)
            pt.ctx.setLineDash(phase: 0, lengths: [9, 7])
            pt.ctx.strokeEllipse(in: pt.ellipseRect(cx: 0.12, cy: 0.12, z: 5, r: 0.58))
            pt.ctx.setLineDash(phase: 0, lengths: [])
            // Cracks across the pad.
            let crack = UIColor(hex: 0x2B323D, alpha: 0.85)
            pt.stroke([pt.p(-0.7, 0.5, 5), pt.p(-0.35, 0.3, 5), pt.p(-0.2, 0.45, 5), pt.p(0.15, 0.1, 5), pt.p(0.5, 0.2, 5)], crack, width: 1.6)
            pt.stroke([pt.p(0.15, 0.1, 5), pt.p(0.3, -0.3, 5), pt.p(0.7, -0.45, 5)], crack, width: 1.4)
            pt.stroke([pt.p(-0.2, 0.45, 5), pt.p(-0.05, 0.8, 5)], crack, width: 1.2)
            // Dust drifts.
            pt.ctx.setFillColor(UIColor(hex: 0xB9BEC6, alpha: 0.75).cgColor)
            pt.ctx.fillEllipse(in: pt.ellipseRect(cx: 0.55, cy: 0.6, z: 5, r: 0.3))
            pt.ctx.fillEllipse(in: pt.ellipseRect(cx: -0.45, cy: 0.7, z: 5, r: 0.22))
            // Broken tower stump, and the piece that fell off.
            pt.box(-0.86, -0.86, -0.5, -0.5, z0: 5, z1: 17, colors: .init(0x9AA1AB, 0x7E8691, 0x666E7A))
            pt.fill([pt.p(-0.86, -0.5, 17), pt.p(-0.5, -0.5, 17), pt.p(-0.5, -0.5, 22), pt.p(-0.7, -0.5, 19)], UIColor(hex: 0x7E8691))
            pt.box(-0.3, -0.72, 0.28, -0.46, z0: 5, z1: 11, colors: .init(0xA6ADB7, 0x858D98, 0x6B7380))
            // Rubble.
            pt.box(0.3, 0.05, 0.44, 0.19, z0: 5, z1: 9, colors: .init(0x9299A4, 0x747C88, 0x5F6773))
            pt.box(-0.62, 0.1, -0.5, 0.22, z0: 5, z1: 8, colors: .init(0x9299A4, 0x747C88, 0x5F6773))
            pt.box(0.62, -0.2, 0.72, -0.1, z0: 5, z1: 8, colors: .init(0x8A919C, 0x6E7682, 0x59616D))
        }
        group.addChild(pad)
        // "Fix me" badge: a gold disc with a wrench, floating above the ruin.
        let badge = SKNode()
        badge.position = CGPoint(x: 0, y: 62)
        badge.zPosition = 5
        let disc = SKShapeNode(circleOfRadius: 17)
        disc.fillColor = UIColor(hex: 0xFFD66B)
        disc.strokeColor = UIColor(hex: 0x0B1426, alpha: 0.85)
        disc.lineWidth = 2.5
        badge.addChild(disc)
        let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .black)
        if let symbol = UIImage(systemName: "wrench.and.screwdriver.fill", withConfiguration: config) {
            let image = symbol.withTintColor(UIColor(hex: 0x3A2A00), renderingMode: .alwaysOriginal)
            let icon = SKSpriteNode(texture: SKTexture(image: image))
            icon.zPosition = 0.1
            badge.addChild(icon)
        }
        group.addChild(badge)
        if animated {
            badge.run(.repeatForever(.sequence([.moveBy(x: 0, y: 7, duration: 0.6), .moveBy(x: 0, y: -7, duration: 0.6)])))
        }
        return group
    }

    private static func levelPips(_ level: Int, height: CGFloat) -> SKNode {
        let node = SKNode()
        node.zPosition = 5
        for i in 0..<BuildingKind.maxLevel {
            let pip = SKShapeNode(circleOfRadius: 4.5)
            pip.fillColor = i < level ? UIColor(hex: 0xFFD66B) : UIColor(white: 1, alpha: 0.25)
            pip.strokeColor = UIColor(hex: 0x0B1426, alpha: 0.8)
            pip.lineWidth = 1.5
            pip.position = CGPoint(x: CGFloat(i - 1) * 12, y: height)
            node.addChild(pip)
        }
        return node
    }

    private static func plate(w: Int, h: Int, level: Int) -> SKNode {
        let path = CGMutablePath()
        let fw = CGFloat(w), fh = CGFloat(h)
        let inset: CGFloat = 0.06
        path.addLines(between: [Iso.point(-fw / 2 + inset, -fh / 2 + inset), Iso.point(fw / 2 - inset, -fh / 2 + inset),
                                Iso.point(fw / 2 - inset, fh / 2 - inset), Iso.point(-fw / 2 + inset, fh / 2 - inset)])
        path.closeSubpath()
        let plate = SKShapeNode(path: path)
        plate.fillColor = UIColor(hex: 0x6F7988, alpha: 0.55)
        plate.strokeColor = UIColor(hex: levelColor(level))
        plate.lineWidth = level >= 2 ? 3 : 2
        plate.zPosition = 0
        return plate
    }

    /// A radio dish standing on its own mast (the habitat-roof dish art is drawn for the roof).
    static func groundDish() -> SKSpriteNode {
        Art.sprite("board.dish", dishCanvas) { pt in
            pt.shadow(-0.34, -0.34, 0.34, 0.34, length: 0.7)
            pt.box(-0.36, -0.36, 0.36, 0.36, z1: 6, colors: .init(0x9AA4B1, 0x7D8897, 0x667180))
            pt.box(-0.1, -0.1, 0.1, 0.1, z0: 6, z1: 30, colors: .init(0xDDE2E8, 0xBAC3CE, 0x8F9AAA))
            let top = pt.p(0, 0, 46)
            pt.line(pt.p(0, 0, 30), top, UIColor(hex: 0x6E7A8B), width: 2.4)
            pt.ctx.saveGState()
            pt.ctx.translateBy(x: top.x, y: top.y)
            pt.ctx.rotate(by: -0.45)
            let dish = CGRect(x: -22, y: -12, width: 44, height: 24)
            pt.ctx.setFillColor(UIColor(hex: 0xF3F5F7).cgColor)
            pt.ctx.fillEllipse(in: dish)
            pt.ctx.setStrokeColor(UIColor(hex: 0x9AA6B6).cgColor)
            pt.ctx.setLineWidth(1.4)
            pt.ctx.strokeEllipse(in: dish)
            pt.ctx.setFillColor(UIColor(hex: 0xF2B84B).cgColor)
            pt.ctx.fillEllipse(in: CGRect(x: -3, y: -3, width: 6, height: 6))
            pt.ctx.restoreGState()
        }
    }
}

extension UIColor {
    /// Lighter (positive) or darker (negative) version of the colour.
    func adjusted(by amount: CGFloat) -> UIColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        func f(_ v: CGFloat) -> CGFloat { amount >= 0 ? v + (1 - v) * amount : v * (1 + amount) }
        return UIColor(red: f(r), green: f(g), blue: f(b), alpha: a)
    }
}
