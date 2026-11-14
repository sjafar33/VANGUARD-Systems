import SpriteKit
import UIKit

/// Factories for every structure in the base. Each one has a recognizable silhouette, a dimensional body,
/// a shadow cast in the shared light direction, and a state detail driven by the model.
@MainActor
enum Art {
    struct Canvas {
        let size: CGSize
        let origin: CGPoint
    }

    static let habitatCanvas = Canvas(size: CGSize(width: 200, height: 168), origin: CGPoint(x: 96, y: 120))
    static let arrayCanvas = Canvas(size: CGSize(width: 100, height: 86), origin: CGPoint(x: 44, y: 58))
    static let batteryCanvas = Canvas(size: CGSize(width: 84, height: 84), origin: CGPoint(x: 40, y: 60))
    static let greenhouseCanvas = Canvas(size: CGSize(width: 210, height: 140), origin: CGPoint(x: 98, y: 88))
    static let plantCanvas = Canvas(size: CGSize(width: 28, height: 24), origin: CGPoint(x: 14, y: 18))
    static let shelterCanvas = Canvas(size: CGSize(width: 200, height: 130), origin: CGPoint(x: 88, y: 82))
    static let roverCanvas = Canvas(size: CGSize(width: 84, height: 70), origin: CGPoint(x: 38, y: 48))
    static let padCanvas = Canvas(size: CGSize(width: 76, height: 46), origin: CGPoint(x: 38, y: 21))
    static let terrainCanvas = Canvas(size: CGSize(width: 680, height: 372), origin: CGPoint(x: 340, y: 156))

    static func texture(_ key: String, _ canvas: Canvas, draw: (IsoPainter) -> Void) -> SKTexture {
        ArtCache.shared.texture(key, size: canvas.size) { ctx in
            draw(IsoPainter(ctx: ctx, origin: canvas.origin))
        }
    }

    static func sprite(_ texture: SKTexture, _ canvas: Canvas) -> SKSpriteNode {
        let node = SKSpriteNode(texture: texture, size: canvas.size)
        node.anchorPoint = CGPoint(x: canvas.origin.x / canvas.size.width, y: 1 - canvas.origin.y / canvas.size.height)
        return node
    }

    static func sprite(_ key: String, _ canvas: Canvas, draw: (IsoPainter) -> Void) -> SKSpriteNode {
        sprite(texture(key, canvas, draw: draw), canvas)
    }

    // MARK: Habitat

    static func habitatBody() -> SKSpriteNode {
        sprite("habitat.body", habitatCanvas) { pt in
            pt.softShadow(cx: 0.62, cy: 0.05, r: 1.28)
            pt.cylinder(cx: 0, cy: 0, r: 1.13, z0: 0, z1: 5, side: (0x8E98A6, 0x667081), top: 0xA9B2BE)
            pt.cylinder(cx: 0, cy: 0, r: 1.0, z0: 5, z1: 14, side: (0xD6DDE4, 0x93A0B1), top: 0xC9D1DA)
            let dome = pt.domePath(cx: 0, cy: 0, r: 0.97, z: 14, height: 48)
            let base = pt.ellipseRect(cx: 0, cy: 0, z: 14, r: 0.97)
            pt.gradient(dome, from: CGPoint(x: base.minX, y: base.minY - 30), to: CGPoint(x: base.maxX, y: base.maxY),
                        colors: [UIColor(hex: 0xF7F9FA), UIColor(hex: 0xEDF1F3), UIColor(hex: 0xADB8C7)])
            pt.radial(dome, center: CGPoint(x: base.midX - base.width * 0.2, y: base.midY - 36), radius: base.width * 0.36,
                      colors: [UIColor(white: 1, alpha: 0.75), UIColor(white: 1, alpha: 0)])
            // Panel seams follow the dome's curve.
            let seam = UIColor(hex: 0x9AA6B6, alpha: 0.55)
            let mid = pt.ellipseRect(cx: 0, cy: 0, z: 38, r: 0.8)
            let seamPath = CGMutablePath()
            seamPath.addArc(center: CGPoint(x: mid.midX, y: mid.midY), radius: mid.width / 2,
                            startAngle: 0.15, endAngle: .pi - 0.15, clockwise: false,
                            transform: CGAffineTransform(translationX: mid.midX, y: mid.midY)
                                .scaledBy(x: 1, y: mid.height / mid.width)
                                .translatedBy(x: -mid.midX, y: -mid.midY))
            pt.ctx.addPath(seamPath)
            pt.ctx.setStrokeColor(seam.cgColor)
            pt.ctx.setLineWidth(1)
            pt.ctx.strokePath()
            for offset in [-0.42, 0.0, 0.42] as [CGFloat] {
                let top = CGPoint(x: base.midX + offset * 18, y: base.midY - 47)
                let bottom = CGPoint(x: base.midX + offset * base.width * 0.5, y: base.midY + base.height * 0.5 * (1 - abs(offset) * 0.5))
                let path = CGMutablePath()
                path.move(to: top)
                path.addQuadCurve(to: bottom, control: CGPoint(x: base.midX + offset * base.width * 0.6, y: base.midY - 16))
                pt.ctx.addPath(path)
                pt.ctx.setStrokeColor(seam.cgColor)
                pt.ctx.setLineWidth(0.9)
                pt.ctx.strokePath()
            }
            // Antenna mast on the back of the dome.
            pt.line(pt.p(-0.32, -0.46, 52), pt.p(-0.32, -0.46, 76), UIColor(hex: 0x6E7A8B), width: 1.6)
            let tip = pt.p(-0.32, -0.46, 77)
            pt.ctx.setFillColor(UIColor(hex: 0xF2B84B).cgColor)
            pt.ctx.fillEllipse(in: CGRect(x: tip.x - 2.2, y: tip.y - 2.2, width: 4.4, height: 4.4))
            // Ribbed airlock toward the viewer, with a door.
            pt.box(-0.34, 0.72, 0.34, 1.55, z1: 21,
                   colors: .init(0xE6EBEF, 0xC8D0D9, 0x9CA8B7), edge: UIColor(hex: 0x8793A3, alpha: 0.7))
            for x in stride(from: -0.27, through: 0.27, by: 0.09) {
                pt.line(pt.p(x, 1.55, 2), pt.p(x, 1.55, 19), UIColor(hex: 0xADB8C6), width: 0.9)
            }
            for y in stride(from: 0.82, through: 1.5, by: 0.11) {
                pt.line(pt.p(0.34, y, 2), pt.p(0.34, y, 19), UIColor(hex: 0x8996A6), width: 0.8)
            }
            let door = [pt.p(-0.13, 1.55, 0), pt.p(0.13, 1.55, 0), pt.p(0.13, 1.55, 15), pt.p(-0.13, 1.55, 15)]
            pt.fill(door, UIColor(hex: 0x22314A))
            pt.stroke(door, UIColor(hex: 0xF2B84B), width: 1.2, close: true)
        }
    }

    static func habitatWindowsTexture(lit: Bool) -> SKTexture {
        texture(lit ? "habitat.windows.lit" : "habitat.windows.dark", habitatCanvas) { pt in
            let ring = pt.ellipseRect(cx: 0, cy: 0, z: 27, r: 0.92)
            for degrees in [10.0, 34.0, 57.0, 78.0] as [CGFloat] {
                let t = degrees * .pi / 180
                let c = CGPoint(x: ring.midX + ring.width / 2 * sin(t), y: ring.midY + ring.height / 2 * cos(t))
                let w = 9 * cos(t) + 3
                let rect = CGRect(x: c.x - w / 2, y: c.y - 4.5, width: w, height: 9)
                if lit {
                    pt.ctx.setShadow(offset: .zero, blur: 7, color: UIColor(hex: 0xFFCF70, alpha: 0.95).cgColor)
                }
                pt.fill(UIBezierPath(roundedRect: rect, cornerRadius: 2).cgPath,
                        lit ? UIColor(hex: 0xFFD98A) : UIColor(hex: 0x2E3D57))
                pt.ctx.setShadow(offset: .zero, blur: 0, color: nil)
            }
            if lit {
                let band = pt.ellipseRect(cx: 0, cy: 0, z: 9.5, r: 1.0)
                for degrees in [-30.0, -10.0, 10.0, 30.0] as [CGFloat] {
                    let t = degrees * .pi / 180
                    let c = CGPoint(x: band.midX + band.width / 2 * sin(t) * 0.98, y: band.midY + band.height / 2 * cos(t))
                    pt.ctx.setShadow(offset: .zero, blur: 4, color: UIColor(hex: 0x53C6D7).cgColor)
                    pt.ctx.setFillColor(UIColor(hex: 0x8BE3EE).cgColor)
                    pt.ctx.fillEllipse(in: CGRect(x: c.x - 1.6, y: c.y - 1.6, width: 3.2, height: 3.2))
                    pt.ctx.setShadow(offset: .zero, blur: 0, color: nil)
                }
            }
        }
    }

    static func dish() -> SKSpriteNode {
        sprite("habitat.dish", habitatCanvas) { pt in
            let foot = pt.p(0.42, -0.3, 50)
            let top = pt.p(0.42, -0.3, 66)
            pt.line(foot, top, UIColor(hex: 0x6E7A8B), width: 1.8)
            let dish = CGRect(x: top.x - 11, y: top.y - 9, width: 22, height: 12)
            pt.ctx.saveGState()
            pt.ctx.translateBy(x: dish.midX, y: dish.midY)
            pt.ctx.rotate(by: -0.45)
            let local = CGRect(x: -11, y: -6, width: 22, height: 12)
            pt.ctx.setFillColor(UIColor(hex: 0xF3F5F7).cgColor)
            pt.ctx.fillEllipse(in: local)
            pt.ctx.setStrokeColor(UIColor(hex: 0x9AA6B6).cgColor)
            pt.ctx.setLineWidth(1)
            pt.ctx.strokeEllipse(in: local)
            pt.ctx.setFillColor(UIColor(hex: 0xF2B84B).cgColor)
            pt.ctx.fillEllipse(in: CGRect(x: -2, y: -2, width: 4, height: 4))
            pt.ctx.restoreGState()
        }
    }

    // MARK: Solar array

    static func solarArray() -> SKSpriteNode {
        sprite("array", arrayCanvas) { pt in
            func z(_ x: CGFloat) -> CGFloat { 11 + (x + 0.46) * 15 }
            pt.fill([pt.p(-0.25, -0.42), pt.p(1.05, -0.42), pt.p(1.05, 0.42), pt.p(-0.25, 0.42)], UIColor(white: 0, alpha: 0.13))
            pt.fill([pt.p(-0.15, -0.36), pt.p(0.95, -0.36), pt.p(0.95, 0.36), pt.p(-0.15, 0.36)], UIColor(white: 0, alpha: 0.1))
            let steel = IsoPainter.BoxColors(0x9AA4B1, 0x7D8897, 0x667180)
            for x in [-0.28, 0.28] as [CGFloat] {
                pt.box(x - 0.07, -0.07, x + 0.07, 0.07, z1: 3, colors: steel)
                pt.line(pt.p(x, 0, 3), pt.p(x, 0, z(x)), UIColor(hex: 0x566173), width: 2.4)
            }
            pt.line(pt.p(-0.28, 0, 6), pt.p(0.28, 0, z(0.28) - 4), UIColor(hex: 0x6E7A8B), width: 1.2)
            let a = pt.p(-0.46, -0.42, z(-0.46))
            let b = pt.p(0.46, -0.42, z(0.46))
            let c = pt.p(0.46, 0.42, z(0.46))
            let d = pt.p(-0.46, 0.42, z(-0.46))
            pt.fill([b, c, c.offset(0, 2.6), b.offset(0, 2.6)], UIColor(hex: 0x4F5B6B))
            pt.fill([d, c, c.offset(0, 2.6), d.offset(0, 2.6)], UIColor(hex: 0x76828F))
            pt.fill([a, b, c, d], UIColor(hex: 0xDCE3EA))
            let cols = 4
            let rows = 3
            for i in 0..<cols {
                for j in 0..<rows {
                    let gap: CGFloat = 0.035
                    let u0 = CGFloat(i) / CGFloat(cols) + gap
                    let u1 = CGFloat(i + 1) / CGFloat(cols) - gap
                    let v0 = CGFloat(j) / CGFloat(rows) + gap * 1.3
                    let v1 = CGFloat(j + 1) / CGFloat(rows) - gap * 1.3
                    let cell = [pt.lerpQuad(a, b, c, d, u0, v0), pt.lerpQuad(a, b, c, d, u1, v0),
                                pt.lerpQuad(a, b, c, d, u1, v1), pt.lerpQuad(a, b, c, d, u0, v1)]
                    let shade: UInt32 = (i + j) % 2 == 0 ? 0x3D77A8 : 0x376E9D
                    pt.fill(cell, UIColor(hex: shade))
                    let um = (u0 + u1) / 2
                    pt.line(pt.lerpQuad(a, b, c, d, um, v0), pt.lerpQuad(a, b, c, d, um, v1), UIColor(hex: 0x76A3CB, alpha: 0.55), width: 0.5)
                }
            }
            pt.gradient(pt.polygon([a, b, c, d]), from: a, to: c,
                        colors: [UIColor(white: 1, alpha: 0.28), UIColor(white: 1, alpha: 0), UIColor(white: 1, alpha: 0.1)])
            pt.stroke([a, b, c, d], UIColor(hex: 0xC4CDD7), width: 0.8, close: true)
        }
    }

    // MARK: Battery

    static func batteryBody() -> SKSpriteNode {
        sprite("battery.body", batteryCanvas) { pt in
            pt.shadow(-0.38, -0.38, 0.38, 0.38, length: 0.45)
            pt.box(-0.39, -0.39, 0.39, 0.39, z1: 4, colors: .init(0x8A95A4, 0x6F7A8A, 0x5B6574))
            pt.box(-0.31, -0.31, 0.31, 0.31, z0: 4, z1: 31, colors: .init(0xDDE2E8, 0xBAC3CE, 0x8F9AAA),
                   edge: UIColor(hex: 0x7D8898, alpha: 0.6))
            for z in stride(from: CGFloat(11), through: 25, by: 4) {
                pt.line(pt.p(0.31, -0.2, z), pt.p(0.31, 0.2, z), UIColor(hex: 0x667182), width: 1.3)
            }
            pt.box(-0.17, -0.17, -0.05, -0.05, z0: 31, z1: 35, colors: .init(0x8BE3EE, 0x53C6D7, 0x3BA3B2))
            pt.box(0.05, 0.05, 0.17, 0.17, z0: 31, z1: 35, colors: .init(0xF6CF7C, 0xF2B84B, 0xC9952F))
            pt.fill([pt.p(-0.31, 0.31, 27), pt.p(0.31, 0.31, 27), pt.p(0.31, 0.31, 29), pt.p(-0.31, 0.31, 29)], UIColor(hex: 0x53C6D7))
        }
    }

    /// Five charge bars on the battery's front face. The level comes from the model's stored energy.
    static func batteryChargeTexture(level: Int, low: Bool) -> SKTexture {
        texture("battery.charge.\(level).\(low)", batteryCanvas) { pt in
            let frame = [pt.p(-0.22, 0.31, 7), pt.p(0.22, 0.31, 7), pt.p(0.22, 0.31, 27.5), pt.p(-0.22, 0.31, 27.5)]
            pt.fill(frame, UIColor(hex: 0x1F2A3B))
            for i in 0..<5 {
                let z0 = 8.5 + CGFloat(i) * 3.8
                let bar = [pt.p(-0.17, 0.31, z0), pt.p(0.17, 0.31, z0), pt.p(0.17, 0.31, z0 + 2.6), pt.p(-0.17, 0.31, z0 + 2.6)]
                let on = i < level
                let color: UIColor = on ? (low ? UIColor(hex: 0xE98772) : UIColor(hex: 0x53C6D7)) : UIColor(hex: 0x33435A)
                if on { pt.ctx.setShadow(offset: .zero, blur: 3, color: color.cgColor) }
                pt.fill(bar, color)
                pt.ctx.setShadow(offset: .zero, blur: 0, color: nil)
            }
        }
    }

    // MARK: Greenhouse

    private static func tunnelPoints(_ pt: IsoPainter, x: CGFloat, half: CGFloat = 0.5, base: CGFloat = 6, height: CGFloat = 32) -> [CGPoint] {
        (0...14).map { i in
            let phi = CGFloat(i) / 14 * .pi
            return pt.p(x, -half * cos(phi), base + height * sin(phi))
        }
    }

    static func greenhouseBase() -> SKSpriteNode {
        sprite("greenhouse.base", greenhouseCanvas) { pt in
            pt.shadow(-1.05, -0.55, 1.05, 0.55, length: 0.55)
            pt.box(-1.07, -0.57, 1.07, 0.57, z1: 5, colors: .init(0xA4ADB9, 0x86909D, 0x6F7988))
            pt.box(-0.94, -0.4, 0.94, 0.4, z0: 5, z1: 7, colors: .init(0x7D6853, 0x65523F, 0x544434))
            for x in stride(from: CGFloat(-0.8), through: 0.8, by: 0.35) {
                pt.line(pt.p(x, -0.38, 7), pt.p(x, 0.38, 7), UIColor(hex: 0x5E4C3B), width: 0.8)
            }
        }
    }

    static func greenhouseShell() -> SKSpriteNode {
        sprite("greenhouse.shell", greenhouseCanvas) { pt in
            let hull = IsoPainter.convexHull(tunnelPoints(pt, x: -1) + tunnelPoints(pt, x: 1))
            pt.fill(hull, UIColor(white: 1, alpha: 0.22))
            let ridgeA = pt.p(-1, 0, 38)
            let ridgeB = pt.p(1, 0, 38)
            pt.gradient(pt.polygon(hull), from: ridgeA.offset(0, -6), to: pt.p(1, 0.5, 6),
                        colors: [UIColor(white: 1, alpha: 0.34), UIColor(white: 1, alpha: 0.04), UIColor(hex: 0xBFD9E8, alpha: 0.18)])
            for x in stride(from: CGFloat(-1), through: 1.001, by: 0.4) {
                pt.stroke(tunnelPoints(pt, x: x), UIColor(white: 1, alpha: x > 0.99 || x < -0.99 ? 0.9 : 0.6), width: 1.3)
            }
            pt.line(ridgeA, ridgeB, UIColor(white: 1, alpha: 0.75), width: 1.2)
            for side in [-0.5, 0.5] as [CGFloat] {
                pt.line(pt.p(-1, side, 6), pt.p(1, side, 6), UIColor(hex: 0xE6ECF1), width: 1.6)
            }
            let end = tunnelPoints(pt, x: 1)
            pt.fill(end, UIColor(white: 1, alpha: 0.12))
        }
    }

    static func greenhouseGlow() -> SKSpriteNode {
        sprite("greenhouse.glow", greenhouseCanvas) { pt in
            let hull = IsoPainter.convexHull(tunnelPoints(pt, x: -0.95, half: 0.45, base: 7, height: 28)
                                             + tunnelPoints(pt, x: 0.95, half: 0.45, base: 7, height: 28))
            pt.ctx.setShadow(offset: .zero, blur: 12, color: UIColor(hex: 0xFFE7B0, alpha: 0.9).cgColor)
            pt.fill(hull, UIColor(hex: 0xFFF1CF, alpha: 0.32))
            pt.ctx.setShadow(offset: .zero, blur: 0, color: nil)
        }
    }

    static func plantTexture(level: Int) -> SKTexture {
        texture("plant.\(level)", plantCanvas) { pt in
            let c = pt.p(0, 0, 0)
            func leaf(_ dx: CGFloat, _ dy: CGFloat, _ w: CGFloat, _ h: CGFloat, _ color: UInt32) {
                pt.ctx.setFillColor(UIColor(hex: color).cgColor)
                pt.ctx.fillEllipse(in: CGRect(x: c.x + dx - w / 2, y: c.y + dy - h / 2, width: w, height: h))
            }
            switch level {
            case 0:
                leaf(0, 1, 5, 2, 0x5A4636)
                leaf(-2, -2, 4, 2.6, 0x8FCB95)
                leaf(2, -2.4, 4, 2.6, 0x76B582)
            case 1:
                leaf(0, 1.5, 9, 3, 0x5A4636)
                leaf(-3.5, -2, 7, 4.5, 0x5E9C6B)
                leaf(3.5, -2.5, 7, 4.5, 0x76B582)
                leaf(0, -5, 6, 5, 0x8FCB95)
            default:
                leaf(0, 1.5, 15, 4, 0x4E3D2F)
                leaf(-6, -2, 10, 7, 0x4F8A5D)
                leaf(6, -2, 10, 7, 0x5E9C6B)
                leaf(-3, -6, 10, 8, 0x76B582)
                leaf(3.5, -6.5, 10, 8, 0x6AAD77)
                leaf(0, -9, 9, 7, 0x9CCF9F)
                leaf(0, -5, 5, 4, 0xB9E0B5)
            }
        }
    }

    // MARK: Shelter

    static func shelterBody() -> SKSpriteNode {
        sprite("shelter.body", shelterCanvas) { pt in
            pt.shadow(-0.8, -0.6, 1.3, 0.8, length: 0.45)
            let bags = IsoPainter.BoxColors(0xC9CDD3, 0xA8AFB9, 0x89919D)
            pt.box(-0.8, -0.6, 0.8, 0.6, z1: 17, colors: bags)
            pt.box(-0.62, -0.44, 0.62, 0.44, z0: 17, z1: 25, colors: .init(0xD3D7DC, 0xB2B8C1, 0x939BA6))
            let seam = UIColor(hex: 0x7F8793, alpha: 0.7)
            for (index, z) in [4.0, 8.5, 13.0].enumerated() {
                let zz = CGFloat(z)
                pt.line(pt.p(-0.8, 0.6, zz), pt.p(0.8, 0.6, zz), seam, width: 0.8)
                pt.line(pt.p(0.8, -0.6, zz), pt.p(0.8, 0.6, zz), seam, width: 0.8)
                let shift: CGFloat = index % 2 == 0 ? 0 : 0.1
                for x in stride(from: -0.7 + shift, through: 0.75, by: 0.2) {
                    pt.line(pt.p(x, 0.6, zz), pt.p(x, 0.6, zz + 4.2), seam, width: 0.7)
                }
                for y in stride(from: -0.5 + shift, through: 0.55, by: 0.2) {
                    pt.line(pt.p(0.8, y, zz), pt.p(0.8, y, zz + 4.2), seam, width: 0.7)
                }
            }
            pt.line(pt.p(-0.62, 0.44, 21), pt.p(0.62, 0.44, 21), seam, width: 0.7)
            pt.line(pt.p(0.62, -0.44, 21), pt.p(0.62, 0.44, 21), seam, width: 0.7)
            let entrance = [pt.p(-0.22, 0.6, 0), pt.p(0.22, 0.6, 0), pt.p(0.22, 0.6, 13), pt.p(-0.22, 0.6, 13)]
            pt.fill(entrance, UIColor(hex: 0x1C2738))
            pt.stroke(entrance, UIColor(hex: 0xF2B84B), width: 1.3, close: true)
            let amberCrate = IsoPainter.BoxColors(0xF4C86F, 0xD9A441, 0xB5862F)
            let grayCrate = IsoPainter.BoxColors(0xC3CAD3, 0x9FA8B4, 0x808A97)
            pt.box(0.95, -0.35, 1.22, -0.08, z1: 9, colors: grayCrate)
            pt.box(0.95, 0.12, 1.28, 0.45, z1: 11, colors: amberCrate)
            pt.line(pt.p(0.95, 0.45, 7), pt.p(1.28, 0.45, 7), UIColor(hex: 0x9C7328), width: 0.8)
            pt.box(1.0, 0.18, 1.22, 0.4, z0: 11, z1: 18, colors: grayCrate)
            pt.box(0.92, 0.62, 1.12, 0.82, z1: 7, colors: amberCrate)
        }
    }

    static func shelterGlow() -> SKSpriteNode {
        sprite("shelter.glow", shelterCanvas) { pt in
            let pool = pt.ellipseRect(cx: 0, cy: 0.95, z: 0, r: 0.42)
            pt.radial(CGPath(ellipseIn: pool, transform: nil), center: CGPoint(x: pool.midX, y: pool.midY), radius: pool.width / 2,
                      colors: [UIColor(hex: 0x8BE3EE, alpha: 0.55), UIColor(hex: 0x53C6D7, alpha: 0)])
            let entrance = [pt.p(-0.16, 0.6, 1), pt.p(0.16, 0.6, 1), pt.p(0.16, 0.6, 11), pt.p(-0.16, 0.6, 11)]
            pt.ctx.setShadow(offset: .zero, blur: 8, color: UIColor(hex: 0x53C6D7).cgColor)
            pt.fill(entrance, UIColor(hex: 0x8BE3EE, alpha: 0.9))
            pt.ctx.setShadow(offset: .zero, blur: 0, color: nil)
        }
    }

    // MARK: Rover

    static func rover() -> SKSpriteNode {
        sprite("rover", roverCanvas) { pt in
            pt.softShadow(cx: 0.12, cy: 0.02, r: 0.42, alpha: 0.28)
            func wheel(_ x: CGFloat, _ y: CGFloat) {
                let c = pt.p(x, y, 4.5)
                pt.ctx.setFillColor(UIColor(hex: 0x262E3B).cgColor)
                pt.ctx.fillEllipse(in: CGRect(x: c.x - 5, y: c.y - 4.5, width: 10, height: 9))
                pt.ctx.setFillColor(UIColor(hex: 0x6A7584).cgColor)
                pt.ctx.fillEllipse(in: CGRect(x: c.x - 2, y: c.y - 2, width: 4, height: 4))
            }
            wheel(-0.24, -0.24)
            wheel(0.24, -0.24)
            pt.box(-0.33, -0.2, 0.33, 0.2, z0: 4, z1: 13, colors: .init(0xF2B84B, 0xD99A34, 0xB27A22),
                   edge: UIColor(hex: 0x8F611A, alpha: 0.6))
            pt.fill([pt.p(-0.24, -0.13, 13.2), pt.p(0.2, -0.13, 13.2), pt.p(0.2, 0.13, 13.2), pt.p(-0.24, 0.13, 13.2)], UIColor(hex: 0x3D77A8))
            pt.line(pt.p(-0.02, -0.13, 13.3), pt.p(-0.02, 0.13, 13.3), UIColor(hex: 0x76A3CB), width: 0.6)
            wheel(-0.24, 0.24)
            wheel(0.24, 0.24)
            pt.fill([pt.p(0.33, -0.12, 7), pt.p(0.33, -0.02, 7), pt.p(0.33, -0.02, 10.5), pt.p(0.33, -0.12, 10.5)], UIColor(hex: 0xFFF1C2))
            pt.fill([pt.p(0.33, 0.04, 7), pt.p(0.33, 0.14, 7), pt.p(0.33, 0.14, 10.5), pt.p(0.33, 0.04, 10.5)], UIColor(hex: 0xFFF1C2))
            pt.line(pt.p(-0.2, 0, 13), pt.p(-0.2, 0, 30), UIColor(hex: 0x5E6A7B), width: 1.6)
            pt.box(-0.27, -0.06, -0.12, 0.06, z0: 28, z1: 34, colors: .init(0x5A6676, 0x3E4858, 0x2E3746))
            let lens = pt.p(-0.12, 0, 31)
            pt.ctx.setFillColor(UIColor(hex: 0x53C6D7).cgColor)
            pt.ctx.fillEllipse(in: CGRect(x: lens.x - 1.5, y: lens.y - 1.5, width: 3, height: 3))
        }
    }

    // MARK: Pads and terrain

    static func pad() -> SKSpriteNode {
        sprite("pad", padCanvas) { pt in
            pt.box(-0.47, -0.47, 0.47, 0.47, z1: 3, colors: .init(0xA2ABB7, 0x86909D, 0x727C8A))
            let inner = [pt.p(-0.34, -0.34, 3), pt.p(0.34, -0.34, 3), pt.p(0.34, 0.34, 3), pt.p(-0.34, 0.34, 3)]
            pt.stroke(inner, UIColor(hex: 0xC1C8D1), width: 1, close: true)
            for corner in [(-0.4, -0.4), (0.4, -0.4), (0.4, 0.4), (-0.4, 0.4)] as [(CGFloat, CGFloat)] {
                let c = pt.p(corner.0, corner.1, 3)
                pt.ctx.setFillColor(UIColor(hex: 0x6C7684).cgColor)
                pt.ctx.fillEllipse(in: CGRect(x: c.x - 1.2, y: c.y - 0.8, width: 2.4, height: 1.6))
            }
        }
    }

    static func padHighlight() -> SKSpriteNode {
        sprite("pad.highlight", padCanvas) { pt in
            let outer = [pt.p(-0.52, -0.52, 3), pt.p(0.52, -0.52, 3), pt.p(0.52, 0.52, 3), pt.p(-0.52, 0.52, 3)]
            pt.fill(outer, UIColor(hex: 0xF2B84B, alpha: 0.24))
            pt.ctx.setShadow(offset: .zero, blur: 5, color: UIColor(hex: 0xF2B84B).cgColor)
            pt.stroke(outer, UIColor(hex: 0xF2B84B), width: 2.6, close: true)
            pt.ctx.setShadow(offset: .zero, blur: 0, color: nil)
        }
    }

    static func terrain() -> SKSpriteNode {
        sprite("terrain", terrainCanvas) { pt in
            let lo: CGFloat = -4.5
            let hi: CGFloat = 5.5
            let thickness: CGFloat = 26
            let leftFace = [pt.p(lo, hi, 0), pt.p(hi, hi, 0), pt.p(hi, hi, -thickness), pt.p(lo, hi, -thickness)]
            let rightFace = [pt.p(hi, lo, 0), pt.p(hi, hi, 0), pt.p(hi, hi, -thickness), pt.p(hi, lo, -thickness)]
            pt.gradient(pt.polygon(leftFace), from: pt.p(lo, hi, 0), to: pt.p(lo, hi, -thickness),
                        colors: [UIColor(hex: 0x8B94A1), UIColor(hex: 0x5C6573)])
            pt.gradient(pt.polygon(rightFace), from: pt.p(hi, lo, 0), to: pt.p(hi, lo, -thickness),
                        colors: [UIColor(hex: 0x6F7886), UIColor(hex: 0x434B58)])
            for z in [-8.0, -15.0, -21.0] as [CGFloat] {
                pt.line(pt.p(lo, hi, z), pt.p(hi, hi, z), UIColor(white: 1, alpha: 0.07), width: 1)
                pt.line(pt.p(hi, lo, z), pt.p(hi, hi, z), UIColor(white: 1, alpha: 0.05), width: 1)
            }
            let top = [pt.p(lo, lo), pt.p(hi, lo), pt.p(hi, hi), pt.p(lo, hi)]
            let center = pt.p(0.5, 0.5)
            pt.radial(pt.polygon(top), center: center.offset(-40, -30), radius: 380,
                      colors: [UIColor(hex: 0xC4CAD2), UIColor(hex: 0xB7BEC8), UIColor(hex: 0x9FA7B3)])
            var rng = SeededRandom(seed: 2026)
            pt.ctx.saveGState()
            pt.ctx.addPath(pt.polygon(top))
            pt.ctx.clip()
            for _ in 0..<1400 {
                let gx = rng.range(lo, hi)
                let gy = rng.range(lo, hi)
                let q = pt.p(gx, gy)
                let s = rng.range(0.6, 1.8)
                let dark = rng.unit() > 0.45
                pt.ctx.setFillColor(UIColor(white: dark ? 0.35 : 1, alpha: rng.range(0.05, 0.16)).cgColor)
                pt.ctx.fillEllipse(in: CGRect(x: q.x, y: q.y, width: s * 1.6, height: s))
            }
            // Rover tracks from the airlock to the parking spot.
            for offset in [-0.07, 0.07] as [CGFloat] {
                var points: [CGPoint] = []
                for i in 0...20 {
                    let t = CGFloat(i) / 20
                    let gx = 0.2 + 2.6 * t + offset
                    let gy = 1.7 + 0.9 * t + 0.35 * sin(t * .pi) - offset
                    points.append(pt.p(gx, gy))
                }
                pt.stroke(points, UIColor(white: 0.3, alpha: 0.16), width: 2.2)
            }
            pt.ctx.restoreGState()
            let craters: [(CGFloat, CGFloat, CGFloat)] = [(-3.6, -3.5, 0.7), (4.3, -3.2, 0.85), (-4.0, 3.0, 0.4),
                                                         (4.9, 1.9, 0.45), (1.3, -4.0, 0.35), (3.3, 5.15, 0.28),
                                                         (-2.1, 5.1, 0.26), (-3.9, -1.9, 0.3)]
            for (gx, gy, r) in craters {
                let rim = pt.ellipseRect(cx: gx, cy: gy, z: 0, r: r * 1.15)
                let bowl = pt.ellipseRect(cx: gx, cy: gy, z: 0, r: r)
                pt.ctx.setFillColor(UIColor(white: 1, alpha: 0.18).cgColor)
                pt.ctx.fillEllipse(in: rim.offsetBy(dx: -1.5, dy: -1))
                pt.radial(CGPath(ellipseIn: bowl, transform: nil), center: CGPoint(x: bowl.midX + bowl.width * 0.18, y: bowl.midY + bowl.height * 0.2),
                          radius: bowl.width * 0.7,
                          colors: [UIColor(hex: 0xB3BAC4), UIColor(hex: 0x9AA2AE), UIColor(hex: 0x7C8592)])
                let crescent = CGMutablePath()
                crescent.addEllipse(in: bowl)
                pt.ctx.saveGState()
                pt.ctx.addPath(crescent)
                pt.ctx.clip()
                pt.ctx.setFillColor(UIColor(white: 0.15, alpha: 0.22).cgColor)
                pt.ctx.fillEllipse(in: bowl.offsetBy(dx: bowl.width * 0.22, dy: bowl.height * 0.3).insetBy(dx: -2, dy: -2).offsetBy(dx: -bowl.width * 0.45, dy: -bowl.height * 0.6))
                pt.ctx.restoreGState()
            }
            let rocks: [(CGFloat, CGFloat, CGFloat)] = [(-4.0, -1.0, 1.0), (3.7, -1.1, 0.8), (5.0, 3.1, 1.1),
                                                       (-1.0, -4.0, 0.9), (2.0, 5.25, 0.7), (-3.4, 4.9, 0.8), (4.6, -0.2, 0.6)]
            var rockRng = SeededRandom(seed: 11)
            for (gx, gy, size) in rocks {
                for k in 0..<3 {
                    let s = size * rockRng.range(0.08, 0.16)
                    let dx = CGFloat(k) * 0.16 - 0.12
                    let dy = rockRng.range(-0.12, 0.12)
                    let h = s * rockRng.range(40, 70)
                    pt.box(gx + dx - s, gy + dy - s, gx + dx + s, gy + dy + s, z1: h,
                           colors: .init(0xB4BBC4, 0x8F98A4, 0x6D7684))
                }
            }
        }
    }

    // MARK: Sky

    static func starfield() -> SKTexture {
        ArtCache.shared.texture("stars", size: CGSize(width: 900, height: 900)) { ctx in
            let rect = CGRect(x: 0, y: 0, width: 900, height: 900)
            if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                  colors: [UIColor(hex: 0x0C1324).cgColor, UIColor(hex: 0x14203A).cgColor, UIColor(hex: 0x18243A).cgColor] as CFArray,
                                  locations: [0, 0.65, 1]) {
                ctx.drawLinearGradient(g, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: rect.height), options: [])
            }
            var rng = SeededRandom(seed: 7)
            for _ in 0..<420 {
                let x = rng.range(0, 900)
                let y = rng.range(0, 900)
                let s = rng.range(0.5, 1.7)
                let blue = rng.unit() > 0.8
                ctx.setFillColor((blue ? UIColor(hex: 0xBFE6FF) : UIColor.white).withAlphaComponent(rng.range(0.25, 0.9)).cgColor)
                ctx.fillEllipse(in: CGRect(x: x, y: y, width: s, height: s))
            }
        }
    }

    static func earth() -> SKTexture {
        ArtCache.shared.texture("earth", size: CGSize(width: 96, height: 96)) { ctx in
            let disc = CGRect(x: 8, y: 8, width: 80, height: 80)
            ctx.setShadow(offset: .zero, blur: 10, color: UIColor(hex: 0x6FB7FF, alpha: 0.65).cgColor)
            ctx.setFillColor(UIColor(hex: 0x2B65A8).cgColor)
            ctx.fillEllipse(in: disc)
            ctx.setShadow(offset: .zero, blur: 0, color: nil)
            ctx.saveGState()
            ctx.addEllipse(in: disc)
            ctx.clip()
            if let ocean = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                      colors: [UIColor(hex: 0x4A8FD6).cgColor, UIColor(hex: 0x1E4E8C).cgColor] as CFArray, locations: nil) {
                ctx.drawRadialGradient(ocean, startCenter: CGPoint(x: 36, y: 34), startRadius: 0,
                                       endCenter: CGPoint(x: 48, y: 48), endRadius: 48, options: [])
            }
            var rng = SeededRandom(seed: 3)
            for _ in 0..<9 {
                let x = rng.range(14, 70)
                let y = rng.range(16, 72)
                ctx.setFillColor((rng.unit() > 0.4 ? UIColor(hex: 0x6FA36A) : UIColor(hex: 0xC2B48A)).cgColor)
                ctx.fillEllipse(in: CGRect(x: x, y: y, width: rng.range(8, 20), height: rng.range(5, 13)))
            }
            for _ in 0..<7 {
                let x = rng.range(10, 72)
                let y = rng.range(12, 78)
                ctx.setFillColor(UIColor(white: 1, alpha: 0.6).cgColor)
                ctx.fillEllipse(in: CGRect(x: x, y: y, width: rng.range(10, 24), height: rng.range(2.5, 5)))
            }
            if let night = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                      colors: [UIColor(white: 0, alpha: 0).cgColor, UIColor(hex: 0x050A16, alpha: 0.78).cgColor] as CFArray,
                                      locations: [0.45, 0.8]) {
                ctx.drawLinearGradient(night, start: CGPoint(x: 20, y: 20), end: CGPoint(x: 88, y: 84), options: [.drawsAfterEndLocation])
            }
            ctx.restoreGState()
            ctx.setStrokeColor(UIColor(hex: 0x9FD4FF, alpha: 0.45).cgColor)
            ctx.setLineWidth(1.2)
            ctx.strokeEllipse(in: disc.insetBy(dx: 0.6, dy: 0.6))
        }
    }

    static func glowDot(color: UInt32, diameter: CGFloat) -> SKTexture {
        ArtCache.shared.texture("dot.\(color).\(diameter)", size: CGSize(width: diameter, height: diameter)) { ctx in
            let rect = CGRect(x: 0, y: 0, width: diameter, height: diameter)
            if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                  colors: [UIColor.white.cgColor, UIColor(hex: color).cgColor, UIColor(hex: color, alpha: 0).cgColor] as CFArray,
                                  locations: [0, 0.35, 1]) {
                ctx.drawRadialGradient(g, startCenter: CGPoint(x: rect.midX, y: rect.midY), startRadius: 0,
                                       endCenter: CGPoint(x: rect.midX, y: rect.midY), endRadius: diameter / 2, options: [])
            }
        }
    }

    // MARK: Game icons

    /// A map pin with a symbol, used for mission markers floating over the base.
    static func markerTexture(symbol: String, state: MarkerState) -> SKTexture {
        let key = "marker.\(symbol).\(state)"
        return ArtCache.shared.texture(key, size: CGSize(width: 80, height: 100)) { ctx in
            let fill: (UInt32, UInt32) = {
                switch state {
                case .next: return (0xFFD66B, 0xF2A93B)
                case .done: return (0x7EDB6E, 0x43A63E)
                case .locked: return (0x8A9AB0, 0x5E6F87)
                }
            }()
            let circle = CGRect(x: 8, y: 6, width: 64, height: 64)
            let pin = CGMutablePath()
            pin.addEllipse(in: circle)
            pin.move(to: CGPoint(x: 26, y: 62))
            pin.addLine(to: CGPoint(x: 40, y: 92))
            pin.addLine(to: CGPoint(x: 54, y: 62))
            pin.closeSubpath()
            ctx.saveGState()
            ctx.translateBy(x: 0, y: 4)
            ctx.addPath(pin)
            ctx.setFillColor(UIColor(hex: 0x0B1426, alpha: 0.45).cgColor)
            ctx.fillPath()
            ctx.restoreGState()
            ctx.saveGState()
            ctx.addPath(pin)
            ctx.clip()
            if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                  colors: [UIColor(hex: fill.0).cgColor, UIColor(hex: fill.1).cgColor] as CFArray, locations: nil) {
                ctx.drawLinearGradient(g, start: CGPoint(x: 0, y: 6), end: CGPoint(x: 0, y: 92), options: [])
            }
            ctx.restoreGState()
            ctx.addPath(pin)
            ctx.setStrokeColor(UIColor.white.cgColor)
            ctx.setLineWidth(3.5)
            ctx.strokePath()
            let config = UIImage.SymbolConfiguration(pointSize: 30, weight: .black)
            if let image = UIImage(systemName: symbol, withConfiguration: config)?.withTintColor(.white, renderingMode: .alwaysOriginal) {
                let size = image.size
                let rect = CGRect(x: circle.midX - size.width / 2, y: circle.midY - size.height / 2, width: size.width, height: size.height)
                ctx.saveGState()
                ctx.setShadow(offset: CGSize(width: 0, height: 2), blur: 0, color: UIColor(hex: 0x0B1426, alpha: 0.6).cgColor)
                image.draw(in: rect)
                ctx.restoreGState()
            }
        }
    }

    /// Picture of a buildable item for the build tray, taken from the same procedural art as the world.
    private static var iconCache: [CargoKind: UIImage] = [:]

    static func cargoIcon(_ kind: CargoKind) -> UIImage? {
        if let cached = iconCache[kind] { return cached }
        let texture: SKTexture?
        switch kind {
        case .solarArray: texture = solarArray().texture
        case .battery, .chargedBattery: texture = batteryBody().texture
        case .shelterKit: texture = shelterBody().texture
        case .scienceKit, .onboardComputer, .scienceCamera: texture = nil
        }
        guard let cg = texture?.cgImage() else { return nil }
        let image = UIImage(cgImage: cg, scale: 3, orientation: .up)
        iconCache[kind] = image
        return image
    }
}
