import SpriteKit
import UIKit

/// What the board shows. Built by the app model from `BaseState`; the scene never changes game state.
struct BoardSnapshot: Equatable {
    var buildings: [PlacedBuilding] = []
    var habitatTint: UInt32 = 0xFFFFFF
    var boardColor: UInt32 = 0x9AA2AE
    var boardTrim: UInt32 = 0xD6DDE5
    var selectedID: String?
    /// Robot buddy colours, for the little robot walking around the base.
    var robotShell: UInt32 = 0xFFFFFF
    var robotEyes: UInt32 = 0x6FE6F2
    /// Placement preview: kind, tile, and whether it fits there.
    var ghost: Ghost?

    struct Ghost: Equatable {
        var kind: BuildingKind
        var x: Int
        var y: Int
        var valid: Bool
    }
}

/// The Clash-style base board: a raised square platform on the Moon, cut into tiles, with buildings that
/// snap to the grid. One finger pans (or drags the placement preview), two fingers pinch to zoom, and taps
/// become intents (`onTileTapped`, `onBuildingTapped`). Idle life (rover, robot buddy, glints, beacons,
/// shooting stars) runs unless motion is reduced. Everything is also reachable from SwiftUI controls.
final class BoardScene: SKScene {
    var onTileTapped: ((Int, Int) -> Void)?
    var onBuildingTapped: ((String) -> Void)?
    var reduceMotion = false {
        didSet { if reduceMotion != oldValue { updateAmbient() } }
    }
    var hudInsets: UIEdgeInsets = .zero {
        didSet { if hudInsets != oldValue { layoutForSize() } }
    }

    /// Board corners in grid units.
    static let low = CGFloat(BaseState.minCoord)
    static let high = CGFloat(BaseState.maxCoord + 1)
    static var contentRect: CGRect {
        let left = Iso.point(low, high).x
        let right = Iso.point(high, low).x
        let top = Iso.point(low, low).y
        let bottom = Iso.point(high, high).y
        return CGRect(x: left - 20, y: bottom - 30, width: right - left + 40, height: top - bottom + 110)
    }
    static let minZoom: CGFloat = 1
    static let maxZoom: CGFloat = 2.8

    private let world = SKNode()
    private let background = SKSpriteNode(texture: Art.starfield())
    private let earth = SKSpriteNode(texture: Art.earth())
    private let skyLayer = SKNode()
    private var twinkles: [(SKSpriteNode, CGPoint)] = []
    private let board = SKSpriteNode()
    private let buildingLayer = SKNode()
    private let effectsLayer = SKNode()
    private let ghostNode = SKNode()
    private let selectionRing = SKShapeNode()
    private let rover = Art.rover()
    private var robot = SKSpriteNode()
    private var robotKey = ""
    private var buildingNodes: [String: SKNode] = [:]
    private var nodeKeys: [String: String] = [:]
    private var current = BoardSnapshot()
    private var boardKey = ""
    private var ambientRunning = false
    private var lastRoverX: CGFloat = 0

    // Camera: the board is fitted to the free screen area, then zoomed and panned on top of that fit.
    private var fitScale: CGFloat = 1
    private var fitPosition: CGPoint = .zero
    private var zoomLevel: CGFloat = 1
    private var pan: CGPoint = .zero

    // Touches.
    private var activeTouches: [UITouch] = []
    private var touchStart: CGPoint?
    private var lastTouch: CGPoint?
    private var dragging = false
    private var draggingGhost = false
    private var pinchStartDistance: CGFloat = 0
    private var pinchStartZoom: CGFloat = 1
    private var lastPinchMid: CGPoint?
    private var gestureWasMulti = false

    override init(size: CGSize) {
        super.init(size: size)
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        backgroundColor = UIColor(hex: 0x0C1324)
        scaleMode = .resizeFill
        background.zPosition = ZLayer.background
        addChild(background)
        earth.zPosition = ZLayer.earth
        addChild(earth)
        skyLayer.zPosition = ZLayer.background + 50
        addChild(skyLayer)
        var rng = SeededRandom(seed: 7)
        for _ in 0..<30 {
            let star = SKSpriteNode(texture: Art.glowDot(color: 0xDDEBFF, diameter: 8))
            star.setScale(rng.range(0.35, 0.9))
            star.alpha = rng.range(0.3, 0.9)
            skyLayer.addChild(star)
            twinkles.append((star, CGPoint(x: rng.range(-0.5, 0.5), y: rng.range(-0.1, 0.5))))
        }
        addChild(world)
        let terrain = Art.terrain()
        terrain.position = Iso.point(0, 0)
        terrain.zPosition = ZLayer.terrain
        world.addChild(terrain)
        board.zPosition = ZLayer.terrain + 2
        world.addChild(board)
        world.addChild(buildingLayer)
        effectsLayer.zPosition = ZLayer.flow - 1
        world.addChild(effectsLayer)
        ghostNode.zPosition = ZLayer.flow
        world.addChild(ghostNode)
        selectionRing.strokeColor = UIColor(hex: 0xFFD66B)
        selectionRing.lineWidth = 3
        selectionRing.glowWidth = 2
        selectionRing.fillColor = UIColor(hex: 0xFFD66B, alpha: 0.12)
        selectionRing.zPosition = ZLayer.pads + 1
        selectionRing.isHidden = true
        world.addChild(selectionRing)
        rover.position = Iso.point(Self.patrolRoute[0])
        rover.zPosition = Iso.depth(Self.patrolRoute[0])
        world.addChild(rover)
        world.addChild(robot)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    override func didMove(to view: SKView) {
        super.didMove(to: view)
        view.isMultipleTouchEnabled = true
        updateAmbient()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        layoutForSize()
    }

    private func layoutForSize() {
        guard size.width > 1, size.height > 1 else { return }
        let content = Self.contentRect
        let top = min(hudInsets.top, size.height * 0.4)
        let bottom = min(hudInsets.bottom, size.height * 0.6)
        let available = CGRect(x: -size.width / 2 + 8, y: -size.height / 2 + bottom,
                               width: size.width - 16, height: max(140, size.height - top - bottom))
        fitScale = min(available.width / content.width, available.height / content.height)
        fitPosition = CGPoint(x: available.midX - content.midX * fitScale, y: available.midY - content.midY * fitScale)
        applyCamera(animated: false)
        let side = max(size.width, size.height)
        background.size = CGSize(width: side, height: side)
        let earthSize = max(44, min(84, min(size.width, size.height) * 0.15))
        earth.size = CGSize(width: earthSize, height: earthSize)
        earth.position = CGPoint(x: size.width / 2 - earthSize * 0.8, y: size.height / 2 - top - earthSize * 0.6)
        for (star, unit) in twinkles {
            star.position = CGPoint(x: unit.x * size.width, y: unit.y * size.height)
        }
    }

    // MARK: Camera

    private func clampPan() {
        let content = Self.contentRect
        let maxX = content.width * fitScale * (zoomLevel - 1) / 2 + 30
        let maxY = content.height * fitScale * (zoomLevel - 1) / 2 + 30
        pan.x = min(maxX, max(-maxX, pan.x))
        pan.y = min(maxY, max(-maxY, pan.y))
    }

    private func applyCamera(animated: Bool) {
        clampPan()
        let scale = fitScale * zoomLevel
        let position = CGPoint(x: fitPosition.x + pan.x, y: fitPosition.y + pan.y)
        world.removeAction(forKey: "camera")
        if animated && !reduceMotion {
            let move = SKAction.group([.scale(to: scale, duration: 0.3), .move(to: position, duration: 0.3)])
            move.timingMode = .easeInEaseOut
            world.run(move, withKey: "camera")
        } else {
            world.setScale(scale)
            world.position = position
        }
    }

    /// Zooms keeping `focus` (a scene point) still on screen: the world point under it stays under it.
    private func setZoom(_ newZoom: CGFloat, around focus: CGPoint, animated: Bool = false) {
        let target = min(Self.maxZoom, max(Self.minZoom, newZoom))
        let ratio = target / zoomLevel
        pan.x = focus.x - fitPosition.x - (focus.x - fitPosition.x - pan.x) * ratio
        pan.y = focus.y - fitPosition.y - (focus.y - fitPosition.y - pan.y) * ratio
        zoomLevel = target
        applyCamera(animated: animated)
    }

    /// Zoom buttons: around the middle of the free screen area.
    func zoom(by factor: CGFloat) {
        let center = CGPoint(x: 0, y: (hudInsets.bottom - hudInsets.top) / 2)
        setZoom(zoomLevel * factor, around: center, animated: true)
    }

    func resetCamera() {
        zoomLevel = 1
        pan = .zero
        applyCamera(animated: true)
    }

    /// Moves the camera so a board position (in grid units) sits in the middle of the free screen area.
    func focus(gridX: CGFloat, gridY: CGFloat, zoom: CGFloat = 1.7) {
        zoomLevel = min(Self.maxZoom, max(Self.minZoom, zoom))
        let point = Iso.point(gridX, gridY)
        let center = CGPoint(x: 0, y: (hudInsets.bottom - hudInsets.top) / 2)
        pan = CGPoint(x: center.x - fitPosition.x - point.x * fitScale * zoomLevel,
                      y: center.y - fitPosition.y - point.y * fitScale * zoomLevel)
        applyCamera(animated: true)
    }

    // MARK: Snapshot

    func apply(_ s: BoardSnapshot) {
        let key = "\(s.boardColor)-\(s.boardTrim)"
        if key != boardKey {
            boardKey = key
            let sprite = BoardArt.board(color: s.boardColor, trim: s.boardTrim)
            board.texture = sprite.texture
            board.size = sprite.size
            board.anchorPoint = sprite.anchorPoint
            board.position = Iso.point(0, 0)
        }
        let animate = !reduceMotion && !current.buildings.isEmpty
        var seen = Set<String>()
        for b in s.buildings {
            seen.insert(b.id)
            let look = "\(b.kind.rawValue)-\(b.level)-\(b.isWorking ? "working" : "damaged")-\(b.kind == .habitat ? s.habitatTint : 0)-\(reduceMotion)"
            let target = Iso.point(CGFloat(b.centerX), CGFloat(b.centerY))
            let depth = Iso.depth(CGPoint(x: b.centerX, y: b.centerY))
            if let node = buildingNodes[b.id], nodeKeys[b.id] == look {
                if node.position != target {
                    node.removeAction(forKey: "move")
                    if animate {
                        node.run(.move(to: target, duration: 0.18), withKey: "move")
                        puff(at: target)
                    } else {
                        node.position = target
                    }
                }
                node.zPosition = depth
            } else {
                let old = buildingNodes[b.id]
                let isNew = old == nil
                let levelledUp = old != nil && (nodeKeys[b.id]?.hasPrefix("\(b.kind.rawValue)-\(b.level - 1)-") ?? false)
                let repaired = old != nil && b.isWorking && (nodeKeys[b.id]?.contains("-damaged-") ?? false)
                old?.removeFromParent()
                let node = BoardArt.building(b, habitatTint: s.habitatTint, animated: !reduceMotion)
                node.position = target
                node.zPosition = depth
                node.name = "building:\(b.id)"
                buildingLayer.addChild(node)
                buildingNodes[b.id] = node
                nodeKeys[b.id] = look
                if animate && isNew {
                    construct(node, at: target)
                } else if animate && levelledUp {
                    node.setScale(0.9)
                    node.run(.sequence([.scale(to: 1.12, duration: 0.16), .scale(to: 1, duration: 0.12)]))
                    sparkle(at: target + CGPoint(x: 0, y: 40), count: 12)
                } else if animate && repaired {
                    // A ruin coming back to life: dust off, pop up, and a burst of sparkles.
                    puff(at: target)
                    node.setScale(0.8)
                    node.run(.sequence([.scale(to: 1.15, duration: 0.2), .scale(to: 1, duration: 0.14)]))
                    sparkle(at: target + CGPoint(x: 0, y: 30), count: 16)
                    sparkle(at: target + CGPoint(x: 0, y: 55), count: 10)
                }
            }
        }
        for (id, node) in buildingNodes where !seen.contains(id) {
            node.removeFromParent()
            buildingNodes[id] = nil
            nodeKeys[id] = nil
        }
        updateRobot(s)
        updateSelection(s)
        updateGhost(s.ghost, habitatTint: s.habitatTint)
        current = s
    }

    // MARK: Effects

    /// A new building drops in like a delivered crate, with a dust ring and sparkles.
    private func construct(_ node: SKNode, at point: CGPoint) {
        let target = node.position
        node.position = target + CGPoint(x: 0, y: 140)
        node.alpha = 0
        let drop = SKAction.move(to: target, duration: 0.32)
        drop.timingMode = .easeIn
        node.run(.sequence([.group([drop, .fadeIn(withDuration: 0.15)]),
                            .run { [weak self] in
                                self?.puff(at: target)
                                self?.sparkle(at: target + CGPoint(x: 0, y: 30), count: 10)
                            },
                            .scaleX(to: 1.12, y: 0.86, duration: 0.08),
                            .scale(to: 1, duration: 0.16)]))
    }

    private func puff(at point: CGPoint) {
        for i in 0..<3 {
            let dust = SKSpriteNode(texture: Art.glowDot(color: 0xD9DEE5, diameter: 26))
            dust.position = point + CGPoint(x: CGFloat(i - 1) * 16, y: 0)
            dust.yScale = 0.5
            dust.alpha = 0.7
            effectsLayer.addChild(dust)
            dust.run(.sequence([.group([.scaleX(to: 2.6, y: 1.2, duration: 0.45), .fadeOut(withDuration: 0.45),
                                        .moveBy(x: CGFloat(i - 1) * 18, y: 6, duration: 0.45)]),
                                .removeFromParent()]))
        }
    }

    private func sparkle(at point: CGPoint, count: Int) {
        for i in 0..<count {
            let star = SKSpriteNode(texture: Art.glowDot(color: i % 2 == 0 ? 0xFFE27A : 0xFFFFFF, diameter: 12))
            star.position = point
            star.blendMode = .add
            effectsLayer.addChild(star)
            let angle = CGFloat(i) / CGFloat(count) * .pi * 2
            let distance = CGFloat.random(in: 34...60)
            star.run(.sequence([.group([.moveBy(x: cos(angle) * distance, y: sin(angle) * distance * 0.7 + 12, duration: 0.5),
                                        .fadeOut(withDuration: 0.5), .scale(to: 0.3, duration: 0.5)]),
                                .removeFromParent()]))
        }
    }

    // MARK: Idle life

    /// The rover drives around the outside of the platform.
    static let patrolRoute: [CGPoint] = [CGPoint(x: -6.8, y: 6.6), CGPoint(x: 6.6, y: 6.6), CGPoint(x: 6.6, y: -6.8),
                                         CGPoint(x: 1, y: -6.8), CGPoint(x: 6.6, y: -6.8), CGPoint(x: 6.6, y: 6.6)]

    private func updateAmbient() {
        if !reduceMotion && !ambientRunning {
            ambientRunning = true
            for (star, _) in twinkles {
                let low = SKAction.fadeAlpha(to: CGFloat.random(in: 0.1...0.35), duration: Double.random(in: 0.8...2.2))
                let high = SKAction.fadeAlpha(to: CGFloat.random(in: 0.6...1), duration: Double.random(in: 0.8...2.2))
                star.run(.repeatForever(.sequence([low, high])), withKey: "twinkle")
            }
            run(.repeatForever(.sequence([.wait(forDuration: 3.5, withRange: 4),
                                          .run { [weak self] in self?.shootingStar() }])), withKey: "sky")
            startPatrol()
            startRobotWander()
        } else if reduceMotion && ambientRunning {
            ambientRunning = false
            removeAction(forKey: "sky")
            twinkles.forEach { $0.0.removeAction(forKey: "twinkle") }
            rover.removeAction(forKey: "patrol")
            robot.removeAction(forKey: "wander")
        }
    }

    private func startPatrol() {
        let route = Self.patrolRoute
        var steps: [SKAction] = [.wait(forDuration: 1)]
        var from = route[0]
        for to in route.dropFirst() + [route[0]] {
            let distance = hypot(to.x - from.x, to.y - from.y)
            let move = SKAction.move(to: Iso.point(to), duration: Double(distance) / 0.7)
            move.timingMode = .easeInEaseOut
            steps.append(move)
            steps.append(.run { [weak self] in self?.roverDust() })
            steps.append(.wait(forDuration: 0.8))
            from = to
        }
        rover.run(.repeatForever(.sequence(steps)), withKey: "patrol")
    }

    private func roverDust() {
        let dust = SKSpriteNode(texture: Art.glowDot(color: 0xD9DEE5, diameter: 20))
        dust.position = rover.position + CGPoint(x: 0, y: 2)
        dust.zPosition = rover.zPosition - 0.5
        dust.yScale = 0.45
        dust.alpha = 0.55
        world.addChild(dust)
        dust.run(.sequence([.group([.scaleX(to: 2.4, y: 0.9, duration: 0.6), .fadeOut(withDuration: 0.6)]), .removeFromParent()]))
    }

    private func updateRobot(_ s: BoardSnapshot) {
        let key = "\(s.robotShell)-\(s.robotEyes)"
        guard key != robotKey else { return }
        robotKey = key
        let fresh = BoardArt.robot(shell: s.robotShell, eyes: s.robotEyes)
        robot.texture = fresh.texture
        robot.size = fresh.size
        robot.anchorPoint = fresh.anchorPoint
        if robot.parent == nil { world.addChild(robot) }
        if robot.position == .zero {
            robot.position = Iso.point(1.5, 2.5)
        }
    }

    /// The robot buddy hops to a free tile now and then, with a little bounce.
    private func startRobotWander() {
        robot.removeAction(forKey: "wander")
        let hop = SKAction.run { [weak self] in
            guard let self else { return }
            let taken = Set(self.current.buildings.flatMap(\.footprintTiles))
            var spot: BoardTile?
            for _ in 0..<12 {
                let t = BoardTile(x: Int.random(in: BaseState.minCoord...BaseState.maxCoord),
                                  y: Int.random(in: BaseState.minCoord...BaseState.maxCoord))
                if !taken.contains(t) { spot = t; break }
            }
            guard let spot else { return }
            let target = Iso.point(CGFloat(spot.x) + 0.5, CGFloat(spot.y) + 0.5)
            let distance = hypot(target.x - self.robot.position.x, target.y - self.robot.position.y)
            let duration = Double(max(0.6, min(2.6, distance / 90)))
            self.robot.xScale = target.x >= self.robot.position.x ? 1 : -1
            let hops = max(2, Int(duration / 0.3))
            var bounce: [SKAction] = []
            for _ in 0..<hops {
                let up = SKAction.moveBy(x: 0, y: 8, duration: duration / Double(hops) / 2)
                up.timingMode = .easeOut
                bounce.append(up)
                let down = up.reversed()
                down.timingMode = .easeIn
                bounce.append(down)
            }
            self.robot.run(.group([.move(to: target, duration: duration), .sequence(bounce)]), withKey: "hop")
        }
        robot.run(.repeatForever(.sequence([.wait(forDuration: 2.5, withRange: 2), hop, .wait(forDuration: 2.5)])), withKey: "wander")
    }

    private func shootingStar() {
        guard size.width > 1 else { return }
        let streak = SKSpriteNode(texture: Art.glowDot(color: 0xCFE6FF, diameter: 12))
        streak.xScale = 7
        streak.yScale = 0.22
        streak.blendMode = .add
        streak.position = CGPoint(x: CGFloat.random(in: -size.width * 0.45...size.width * 0.35),
                                  y: size.height * CGFloat.random(in: 0.28...0.48))
        let angle = -CGFloat.random(in: 0.35...0.6)
        streak.zRotation = angle
        streak.alpha = 0
        skyLayer.addChild(streak)
        let length = size.width * CGFloat.random(in: 0.25...0.4)
        let travel = SKAction.moveBy(x: length * cos(angle), y: length * sin(angle), duration: 0.7)
        travel.timingMode = .easeIn
        streak.run(.sequence([.group([travel, .sequence([.fadeAlpha(to: 0.95, duration: 0.12), .wait(forDuration: 0.3),
                                                         .fadeOut(withDuration: 0.28)])]), .removeFromParent()]))
    }

    override func update(_ currentTime: TimeInterval) {
        rover.zPosition = Iso.depth(Iso.grid(from: rover.position))
        let dx = rover.position.x - lastRoverX
        if abs(dx) > 0.05 { rover.xScale = dx >= 0 ? 1 : -1 }
        lastRoverX = rover.position.x
        robot.zPosition = Iso.depth(Iso.grid(from: robot.position)) + 0.5
    }

    // MARK: Selection and placement preview

    private func diamondPath(w: CGFloat, h: CGFloat, inset: CGFloat = 0) -> CGPath {
        let path = CGMutablePath()
        let pts = [Iso.point(-w / 2 + inset, -h / 2 + inset), Iso.point(w / 2 - inset, -h / 2 + inset),
                   Iso.point(w / 2 - inset, h / 2 - inset), Iso.point(-w / 2 + inset, h / 2 - inset)]
        path.addLines(between: pts)
        path.closeSubpath()
        return path
    }

    private func updateSelection(_ s: BoardSnapshot) {
        guard let id = s.selectedID, let b = s.buildings.first(where: { $0.id == id }) else {
            selectionRing.isHidden = true
            selectionRing.removeAllActions()
            return
        }
        let size = b.kind.footprint
        selectionRing.path = diamondPath(w: CGFloat(size.w), h: CGFloat(size.h), inset: -0.08)
        selectionRing.position = Iso.point(CGFloat(b.centerX), CGFloat(b.centerY))
        if selectionRing.isHidden || current.selectedID != id {
            selectionRing.isHidden = false
            selectionRing.removeAllActions()
            selectionRing.alpha = 1
            // The tapped building gives a little bounce, so a tap always feels answered.
            if !reduceMotion, let node = buildingNodes[id] {
                node.removeAction(forKey: "tap")
                node.setScale(1)
                node.run(.sequence([.scale(to: 1.1, duration: 0.09), .scale(to: 1, duration: 0.13)]), withKey: "tap")
            }
            if !reduceMotion {
                selectionRing.run(.repeatForever(.sequence([.fadeAlpha(to: 0.5, duration: 0.7), .fadeAlpha(to: 1, duration: 0.7)])))
            }
        }
    }

    private func updateGhost(_ ghost: BoardSnapshot.Ghost?, habitatTint: UInt32) {
        guard ghost != current.ghost || (ghost != nil && ghostNode.children.isEmpty) else { return }
        ghostNode.removeAllChildren()
        guard let ghost else { return }
        let size = ghost.kind.footprint
        let cx = CGFloat(ghost.x) + CGFloat(size.w) / 2
        let cy = CGFloat(ghost.y) + CGFloat(size.h) / 2
        let color = ghost.valid ? UIColor(hex: 0x7EDB6E) : UIColor(hex: 0xF26B5B)
        let plate = SKShapeNode(path: diamondPath(w: CGFloat(size.w), h: CGFloat(size.h)))
        plate.fillColor = color.withAlphaComponent(0.35)
        plate.strokeColor = color
        plate.lineWidth = 3
        plate.position = Iso.point(cx, cy)
        ghostNode.addChild(plate)
        let preview = BoardArt.building(PlacedBuilding(id: "ghost", kind: ghost.kind, x: ghost.x, y: ghost.y, level: 1),
                                        habitatTint: habitatTint, animated: false)
        preview.alpha = 0.65
        preview.position = Iso.point(cx, cy)
        ghostNode.addChild(preview)
        if !reduceMotion {
            preview.run(.repeatForever(.sequence([.moveBy(x: 0, y: 6, duration: 0.5), .moveBy(x: 0, y: -6, duration: 0.5)])))
        }
        // Shape cue as well as colour: a check or a cross above the preview.
        let mark = SKLabelNode(text: ghost.valid ? "✓" : "✕")
        mark.fontName = "AvenirNext-Heavy"
        mark.fontSize = 30
        mark.fontColor = color
        mark.position = Iso.point(cx, cy).offset(0, 74)
        ghostNode.addChild(mark)
    }

    // MARK: Touches

    private func tile(at point: CGPoint) -> BoardTile {
        let local = convert(point, to: world)
        let g = Iso.grid(from: local)
        return BoardTile(x: Int(floor(g.x)), y: Int(floor(g.y)))
    }

    private func ghostCorner(for t: BoardTile, _ ghost: BoardSnapshot.Ghost) -> BoardTile {
        let size = ghost.kind.footprint
        return BoardTile(x: t.x - (size.w - 1) / 2, y: t.y - (size.h - 1) / 2)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches where !activeTouches.contains(touch) { activeTouches.append(touch) }
        if activeTouches.count >= 2 {
            gestureWasMulti = true
            dragging = true
            draggingGhost = false
            let a = activeTouches[0].location(in: self)
            let b = activeTouches[1].location(in: self)
            pinchStartDistance = max(1, hypot(a.x - b.x, a.y - b.y))
            pinchStartZoom = zoomLevel
            lastPinchMid = CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
            world.removeAction(forKey: "camera")
            return
        }
        guard let point = touches.first?.location(in: self) else { return }
        touchStart = point
        lastTouch = point
        dragging = false
        gestureWasMulti = false
        // Dragging that starts on (or right next to) the placement preview moves the preview; anywhere else pans.
        if let ghost = current.ghost {
            let t = tile(at: point)
            let size = ghost.kind.footprint
            draggingGhost = t.x >= ghost.x - 1 && t.x <= ghost.x + size.w && t.y >= ghost.y - 1 && t.y <= ghost.y + size.h
        } else {
            draggingGhost = false
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if activeTouches.count >= 2 {
            let a = activeTouches[0].location(in: self)
            let b = activeTouches[1].location(in: self)
            let distance = max(1, hypot(a.x - b.x, a.y - b.y))
            let mid = CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
            if let last = lastPinchMid {
                pan.x += mid.x - last.x
                pan.y += mid.y - last.y
            }
            lastPinchMid = mid
            setZoom(pinchStartZoom * distance / pinchStartDistance, around: mid)
            return
        }
        guard let touch = touches.first, let start = touchStart else { return }
        let point = touch.location(in: self)
        if hypot(point.x - start.x, point.y - start.y) > 10 { dragging = true }
        guard dragging else { return }
        if draggingGhost, let ghost = current.ghost {
            let corner = ghostCorner(for: tile(at: point), ghost)
            if corner.x != ghost.x || corner.y != ghost.y { onTileTapped?(corner.x, corner.y) }
        } else if let last = lastTouch {
            pan.x += point.x - last.x
            pan.y += point.y - last.y
            applyCamera(animated: false)
        }
        lastTouch = point
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        let wasTap = !dragging && !gestureWasMulti && activeTouches.count == 1
        activeTouches.removeAll { touches.contains($0) }
        if activeTouches.count < 2 { lastPinchMid = nil }
        if activeTouches.isEmpty {
            touchStart = nil
            lastTouch = nil
            draggingGhost = false
        }
        guard wasTap, let touch = touches.first else {
            if activeTouches.isEmpty { dragging = false; gestureWasMulti = false }
            return
        }
        dragging = false
        let point = touch.location(in: self)
        if current.ghost == nil {
            // The building drawn nearest the viewer under the finger wins.
            let hits = nodes(at: point).compactMap { node -> (String, CGFloat)? in
                var n: SKNode? = node
                while let found = n {
                    if let name = found.name, name.hasPrefix("building:") { return (String(name.dropFirst(9)), found.zPosition) }
                    n = found.parent
                }
                return nil
            }
            if let id = hits.max(by: { $0.1 < $1.1 })?.0 {
                onBuildingTapped?(id)
                return
            }
        }
        let t = tile(at: point)
        if let ghost = current.ghost {
            let corner = ghostCorner(for: t, ghost)
            onTileTapped?(corner.x, corner.y)
        } else {
            onTileTapped?(t.x, t.y)
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        activeTouches.removeAll { touches.contains($0) }
        if activeTouches.isEmpty {
            touchStart = nil
            lastTouch = nil
            dragging = false
            draggingGhost = false
            gestureWasMulti = false
            lastPinchMid = nil
        }
    }
}

/// Owns the board scene for the app's lifetime.
@MainActor
final class BoardCoordinator {
    let scene = BoardScene(size: CGSize(width: 800, height: 600))

    func show(_ snapshot: BoardSnapshot, reduceMotion: Bool) {
        scene.reduceMotion = reduceMotion
        scene.apply(snapshot)
    }

    func setHUDInsets(top: CGFloat, bottom: CGFloat) {
        scene.hudInsets = UIEdgeInsets(top: top, left: 0, bottom: bottom, right: 0)
    }

    func zoom(by factor: CGFloat) { scene.zoom(by: factor) }

    func resetCamera() { scene.resetCamera() }

    func focus(x: Double, y: Double) { scene.focus(gridX: CGFloat(x), gridY: CGFloat(y)) }
}
