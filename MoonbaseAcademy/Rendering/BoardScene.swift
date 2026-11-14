import SpriteKit
import UIKit

/// What the board shows. Built by the app model from `BaseState`; the scene never changes game state.
struct BoardSnapshot: Equatable {
    var buildings: [PlacedBuilding] = []
    var habitatTint: UInt32 = 0xFFFFFF
    var boardColor: UInt32 = 0x9AA2AE
    var boardTrim: UInt32 = 0xD6DDE5
    var selectedID: String?
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
/// snap to the grid. Taps become intents (`onTileTapped`, `onBuildingTapped`); dragging moves the placement
/// preview. Everything here is also reachable from SwiftUI controls for VoiceOver and Switch Control users.
final class BoardScene: SKScene {
    var onTileTapped: ((Int, Int) -> Void)?
    var onBuildingTapped: ((String) -> Void)?
    var reduceMotion = false
    var hudInsets: UIEdgeInsets = .zero {
        didSet { if hudInsets != oldValue { layoutForSize() } }
    }

    static let tiles = BaseState.maxCoord - BaseState.minCoord + 1
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

    private let world = SKNode()
    private let background = SKSpriteNode(texture: Art.starfield())
    private let earth = SKSpriteNode(texture: Art.earth())
    private let board = SKSpriteNode()
    private let buildingLayer = SKNode()
    private let ghostNode = SKNode()
    private let selectionRing = SKShapeNode()
    private var buildingNodes: [String: SKNode] = [:]
    private var nodeKeys: [String: String] = [:]
    private var current = BoardSnapshot()
    private var boardKey = ""
    private var touchStart: CGPoint?
    private var dragging = false

    override init(size: CGSize) {
        super.init(size: size)
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        backgroundColor = UIColor(hex: 0x0C1324)
        scaleMode = .resizeFill
        background.zPosition = ZLayer.background
        addChild(background)
        earth.zPosition = ZLayer.earth
        addChild(earth)
        addChild(world)
        let terrain = Art.terrain()
        terrain.position = Iso.point(0, 0)
        terrain.zPosition = ZLayer.terrain
        world.addChild(terrain)
        board.zPosition = ZLayer.terrain + 2
        world.addChild(board)
        world.addChild(buildingLayer)
        ghostNode.zPosition = ZLayer.flow
        world.addChild(ghostNode)
        selectionRing.strokeColor = UIColor(hex: 0xFFD66B)
        selectionRing.lineWidth = 3
        selectionRing.glowWidth = 2
        selectionRing.fillColor = UIColor(hex: 0xFFD66B, alpha: 0.12)
        selectionRing.zPosition = ZLayer.pads + 1
        selectionRing.isHidden = true
        world.addChild(selectionRing)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        layoutForSize()
    }

    private func layoutForSize() {
        guard size.width > 1, size.height > 1 else { return }
        let content = Self.contentRect
        let top = min(hudInsets.top, size.height * 0.4)
        let bottom = min(hudInsets.bottom, size.height * 0.5)
        let available = CGRect(x: -size.width / 2 + 8, y: -size.height / 2 + bottom,
                               width: size.width - 16, height: max(140, size.height - top - bottom))
        let scale = min(available.width / content.width, available.height / content.height)
        world.setScale(scale)
        world.position = CGPoint(x: available.midX - content.midX * scale, y: available.midY - content.midY * scale)
        let side = max(size.width, size.height)
        background.size = CGSize(width: side, height: side)
        let earthSize = max(44, min(84, min(size.width, size.height) * 0.15))
        earth.size = CGSize(width: earthSize, height: earthSize)
        earth.position = CGPoint(x: size.width / 2 - earthSize * 0.8, y: size.height / 2 - top - earthSize * 0.6)
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
            let look = "\(b.kind.rawValue)-\(b.level)-\(b.kind == .habitat ? s.habitatTint : 0)"
            let target = Iso.point(CGFloat(b.centerX), CGFloat(b.centerY))
            let depth = Iso.depth(CGPoint(x: b.centerX, y: b.centerY))
            if let node = buildingNodes[b.id], nodeKeys[b.id] == look {
                if node.position != target {
                    node.removeAction(forKey: "move")
                    if animate {
                        node.run(.move(to: target, duration: 0.18), withKey: "move")
                    } else {
                        node.position = target
                    }
                }
                node.zPosition = depth
            } else {
                let isNew = buildingNodes[b.id] == nil
                buildingNodes[b.id]?.removeFromParent()
                let node = BoardArt.building(b, habitatTint: s.habitatTint)
                node.position = target
                node.zPosition = depth
                node.name = "building:\(b.id)"
                buildingLayer.addChild(node)
                buildingNodes[b.id] = node
                nodeKeys[b.id] = look
                if animate {
                    // A small pop when something is built or upgraded.
                    node.setScale(isNew ? 0.6 : 0.9)
                    node.run(.sequence([.scale(to: 1.08, duration: 0.14), .scale(to: 1, duration: 0.1)]))
                }
            }
        }
        for (id, node) in buildingNodes where !seen.contains(id) {
            node.removeFromParent()
            buildingNodes[id] = nil
            nodeKeys[id] = nil
        }
        updateSelection(s)
        updateGhost(s.ghost)
        current = s
    }

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
            if !reduceMotion {
                selectionRing.run(.repeatForever(.sequence([.fadeAlpha(to: 0.5, duration: 0.7), .fadeAlpha(to: 1, duration: 0.7)])))
            }
        }
    }

    private func updateGhost(_ ghost: BoardSnapshot.Ghost?) {
        guard ghost != current.ghost || ghostNode.children.isEmpty else { return }
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
                                        habitatTint: current.habitatTint)
        preview.alpha = 0.6
        preview.position = Iso.point(cx, cy)
        ghostNode.addChild(preview)
        // Shape cue as well as colour: a check or a cross above the preview.
        let mark = SKLabelNode(text: ghost.valid ? "✓" : "✕")
        mark.fontName = "AvenirNext-Heavy"
        mark.fontSize = 28
        mark.fontColor = color
        mark.position = Iso.point(cx, cy).offset(0, 70)
        ghostNode.addChild(mark)
    }

    // MARK: Touches

    private func tile(at point: CGPoint) -> BoardTile {
        let local = convert(point, to: world)
        let g = Iso.grid(from: local)
        return BoardTile(x: Int(floor(g.x)), y: Int(floor(g.y)))
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchStart = touches.first?.location(in: self)
        dragging = false
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first, let start = touchStart else { return }
        let point = touch.location(in: self)
        if hypot(point.x - start.x, point.y - start.y) > 12 { dragging = true }
        // While placing, dragging slides the preview along the grid.
        if dragging, let ghost = current.ghost {
            let t = tile(at: point)
            let size = ghost.kind.footprint
            let x = t.x - (size.w - 1) / 2
            let y = t.y - (size.h - 1) / 2
            if x != ghost.x || y != ghost.y { onTileTapped?(x, y) }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        defer { touchStart = nil; dragging = false }
        guard let touch = touches.first, !dragging else { return }
        let point = touch.location(in: self)
        if current.ghost == nil {
            // The nearest building drawn under the finger wins (front-most first).
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
            let size = ghost.kind.footprint
            onTileTapped?(t.x - (size.w - 1) / 2, t.y - (size.h - 1) / 2)
        } else {
            onTileTapped?(t.x, t.y)
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchStart = nil
        dragging = false
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
}
