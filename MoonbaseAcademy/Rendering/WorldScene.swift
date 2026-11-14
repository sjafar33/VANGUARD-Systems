import SpriteKit
import UIKit

/// The isometric diorama. It reconciles nodes by stable identity against each `WorldSnapshot`.
/// Touches become selection intents; it never changes game state itself.
final class WorldScene: SKScene {
    var onPadTapped: ((PadID) -> Void)?
    var onMarkerTapped: ((MissionID) -> Void)?
    var onFlagTapped: ((Double) -> Void)?
    var reduceMotion = false
    /// Space covered by the HUD at the top and bottom, in points. The base is framed in what remains.
    var hudInsets: UIEdgeInsets = .zero {
        didSet { if hudInsets != oldValue { layoutForSize() } }
    }

    static let arrayPads: [CGPoint] = [CGPoint(x: -2.6, y: 2.1), CGPoint(x: -2.6, y: 1.1), CGPoint(x: -2.6, y: 0.1), CGPoint(x: -2.6, y: -0.9)]
    static let batteryPads: [CGPoint] = [CGPoint(x: -0.9, y: -2.6), CGPoint(x: 0.1, y: -2.6), CGPoint(x: 1.1, y: -2.6), CGPoint(x: 2.1, y: -2.6)]
    static let greenhouseSpot = CGPoint(x: 2.8, y: 0.3)
    static let shelterSpot = CGPoint(x: 0.3, y: 2.9)
    static let roverParking = CGPoint(x: 2.9, y: 2.6)
    static let trackY: CGFloat = 4.2
    static let trackStartX: CGFloat = -3
    /// Part of the world that must stay visible, in world coordinates.
    static let contentRect = CGRect(x: -312, y: -212, width: 624, height: 380)

    private let world = SKNode()
    private let background = SKSpriteNode(texture: Art.starfield())
    private let earth = SKSpriteNode(texture: Art.earth())
    private let tint = SKSpriteNode(color: UIColor(hex: 0x081530), size: CGSize(width: 10, height: 10))
    private var storm: SKEmitterNode?
    private let habitat = SKNode()
    private let windows = Art.sprite(Art.habitatWindowsTexture(lit: false), Art.habitatCanvas)
    private let beacon = SKSpriteNode(texture: Art.glowDot(color: 0xE98772, diameter: 18))
    private var dish: SKSpriteNode?
    private var pads: [PadID: SKSpriteNode] = [:]
    private var padHighlights: [PadID: SKSpriteNode] = [:]
    private var arrayNodes: [Int: SKNode] = [:]
    private var batteryNodes: [Int: SKSpriteNode] = [:]
    private var batteryCharges: [Int: SKSpriteNode] = [:]
    private var greenhouse: SKNode?
    private var plants: [SKSpriteNode] = []
    private var greenhouseGlow: SKSpriteNode?
    private var shelter: SKNode?
    private var shelterGlow: SKSpriteNode?
    private let rover = Art.rover()
    private var trackNode: SKNode?
    private var trackKey: RoverTrackVisual?
    private let flowLayer = SKNode()
    private let signalLayer = SKNode()
    private var current = WorldSnapshot()
    private var flowKey: String = ""
    private var hasApplied = false
    private var lastRunID: Int?
    private var shownFloaters: Set<Int> = []
    private var markerNodes: [MissionID: SKNode] = [:]
    private var markerKey: [MapMarker] = []
    private var flagPoints: [(Double, CGPoint)] = []

    override init(size: CGSize) {
        super.init(size: size)
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        backgroundColor = UIColor(hex: 0x0C1324)
        scaleMode = .resizeFill
        build()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    private func build() {
        background.zPosition = ZLayer.background
        addChild(background)
        earth.zPosition = ZLayer.earth
        addChild(earth)
        addChild(world)

        let terrain = Art.terrain()
        terrain.position = Iso.point(0, 0)
        terrain.zPosition = ZLayer.terrain
        world.addChild(terrain)

        for (index, spot) in Self.arrayPads.enumerated() { addPad(.array(index), at: spot) }
        for (index, spot) in Self.batteryPads.enumerated() { addPad(.battery(index), at: spot) }

        habitat.position = Iso.point(0, 0)
        habitat.zPosition = Iso.depth(.zero)
        habitat.addChild(Art.habitatBody())
        windows.zPosition = 0.1
        habitat.addChild(windows)
        beacon.position = CGPoint(x: -36, y: 26)
        beacon.zPosition = 0.2
        beacon.alpha = 0
        habitat.addChild(beacon)
        world.addChild(habitat)

        rover.position = Iso.point(Self.roverParking)
        rover.zPosition = Iso.depth(Self.roverParking)
        world.addChild(rover)

        flowLayer.zPosition = ZLayer.flow
        world.addChild(flowLayer)

        tint.zPosition = ZLayer.tint
        tint.alpha = 0
        tint.colorBlendFactor = 1
        addChild(tint)
        signalLayer.zPosition = ZLayer.signal
        addChild(signalLayer)
    }

    private func addPad(_ id: PadID, at spot: CGPoint) {
        let pad = Art.pad()
        pad.position = Iso.point(spot)
        pad.zPosition = ZLayer.pads
        pad.isHidden = true
        world.addChild(pad)
        pads[id] = pad
        let highlight = Art.padHighlight()
        highlight.position = pad.position
        highlight.zPosition = ZLayer.padHighlight
        highlight.isHidden = true
        world.addChild(highlight)
        padHighlights[id] = highlight
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        layoutForSize()
    }

    private func layoutForSize() {
        guard size.width > 1, size.height > 1 else { return }
        let content = Self.contentRect
        let top = min(hudInsets.top, size.height * 0.4)
        let bottom = min(hudInsets.bottom, size.height * 0.55)
        let available = CGRect(x: -size.width / 2 + 8, y: -size.height / 2 + bottom,
                               width: size.width - 16, height: max(120, size.height - top - bottom))
        let scale = min(available.width / content.width, available.height / content.height)
        world.setScale(scale)
        world.position = CGPoint(x: available.midX - content.midX * scale, y: available.midY - content.midY * scale)
        let side = max(size.width, size.height)
        background.size = CGSize(width: side, height: side)
        tint.size = CGSize(width: size.width + 4, height: size.height + 4)
        let earthSize = max(44, min(84, min(size.width, size.height) * 0.15))
        earth.size = CGSize(width: earthSize, height: earthSize)
        earth.position = CGPoint(x: size.width / 2 - earthSize * 0.8, y: size.height / 2 - top - earthSize * 0.6)
        if let storm {
            storm.position = CGPoint(x: -size.width * 0.2, y: size.height / 2 + 20)
            storm.particlePositionRange = CGVector(dx: size.width * 1.3, dy: 10)
        }
    }

    // MARK: Snapshot reconciliation

    func apply(_ s: WorldSnapshot) {
        let animate = hasApplied && !reduceMotion
        updateMood(s, animate: animate)
        updateArrays(s.arrays, animate: animate)
        updateBatteries(s.batteries, fraction: s.batteryFraction, animate: animate)
        updateHabitat(s, animate: animate)
        updatePads(s)
        updateGreenhouse(s, animate: animate)
        updateShelter(s)
        updateRover(s)
        updateFlow(s)
        updateFloaters(s)
        updateMarkers(s)
        current = s
        hasApplied = true
    }

    private func updateMood(_ s: WorldSnapshot, animate: Bool) {
        let target: (UInt32, CGFloat)
        switch s.mood {
        case .sunlit: target = (0x081530, 0)
        case .steady: target = (0x081530, 0.06)
        case .shadow: target = (0x07122B, 0.5)
        case .storm: target = (0x0A2333, 0.36)
        }
        tint.color = UIColor(hex: target.0)
        tint.removeAction(forKey: "mood")
        if animate {
            tint.run(.fadeAlpha(to: target.1, duration: 0.6), withKey: "mood")
        } else {
            tint.alpha = target.1
        }
        let wantsStorm = s.stormParticles && !reduceMotion
        if wantsStorm && storm == nil {
            let emitter = SKEmitterNode()
            emitter.particleTexture = Art.glowDot(color: 0xBFEFF5, diameter: 10)
            emitter.particleBirthRate = 26
            emitter.particleLifetime = 3
            emitter.particleSpeed = 170
            emitter.particleSpeedRange = 60
            emitter.emissionAngle = -0.95
            emitter.emissionAngleRange = 0.12
            emitter.particleAlpha = 0.45
            emitter.particleAlphaRange = 0.2
            emitter.particleAlphaSpeed = -0.12
            emitter.particleScale = 0.45
            emitter.particleScaleRange = 0.25
            emitter.particleBlendMode = .add
            emitter.zPosition = ZLayer.particles
            addChild(emitter)
            storm = emitter
            layoutForSize()
        } else if !wantsStorm, let emitter = storm {
            emitter.particleBirthRate = 0
            emitter.run(.sequence([.wait(forDuration: 3), .removeFromParent()]))
            storm = nil
        }
    }

    private func updateArrays(_ count: Int, animate: Bool) {
        for index in Self.arrayPads.indices {
            let wanted = index < count
            if wanted, arrayNodes[index] == nil {
                let spot = Self.arrayPads[index]
                let node = Art.solarArray()
                node.position = Iso.point(spot)
                node.zPosition = Iso.depth(spot)
                world.addChild(node)
                arrayNodes[index] = node
                if animate {
                    node.yScale = 0.08
                    node.alpha = 0
                    let unfold = SKAction.scaleY(to: 1, duration: 0.34)
                    unfold.timingMode = .easeOut
                    node.run(.group([unfold, .fadeIn(withDuration: 0.18)]))
                    puff(at: node.position)
                }
            } else if !wanted, let node = arrayNodes.removeValue(forKey: index) {
                if animate {
                    node.run(.sequence([.group([.fadeOut(withDuration: 0.2), .scaleY(to: 0.1, duration: 0.2)]), .removeFromParent()]))
                } else {
                    node.removeFromParent()
                }
            }
        }
    }

    private func updateBatteries(_ count: Int, fraction: Double, animate: Bool) {
        let level = WorldSnapshot.chargeLevel(fraction)
        for index in Self.batteryPads.indices {
            let wanted = index < count
            if wanted, batteryNodes[index] == nil {
                let spot = Self.batteryPads[index]
                let node = Art.batteryBody()
                node.position = Iso.point(spot)
                node.zPosition = Iso.depth(spot)
                let charge = Art.sprite(Art.batteryChargeTexture(level: level, low: level <= 1), Art.batteryCanvas)
                charge.anchorPoint = node.anchorPoint
                charge.zPosition = 0.1
                node.addChild(charge)
                world.addChild(node)
                batteryNodes[index] = node
                batteryCharges[index] = charge
                if animate {
                    node.setScale(0.6)
                    node.alpha = 0
                    let settle = SKAction.scale(to: 1, duration: 0.3)
                    settle.timingMode = .easeOut
                    node.run(.group([settle, .fadeIn(withDuration: 0.2)]))
                    puff(at: node.position)
                }
            } else if !wanted, let node = batteryNodes.removeValue(forKey: index) {
                batteryCharges[index] = nil
                if animate {
                    node.run(.sequence([.fadeOut(withDuration: 0.2), .removeFromParent()]))
                } else {
                    node.removeFromParent()
                }
            }
        }
        for charge in batteryCharges.values {
            charge.texture = Art.batteryChargeTexture(level: level, low: level <= 1)
        }
    }

    private func puff(at point: CGPoint) {
        let dust = SKSpriteNode(texture: Art.glowDot(color: 0xD9DEE5, diameter: 24))
        dust.position = point
        dust.zPosition = ZLayer.pads + 1
        dust.yScale = 0.5
        dust.alpha = 0.7
        world.addChild(dust)
        dust.run(.sequence([.group([.scaleX(to: 3.2, y: 1.4, duration: 0.4), .fadeOut(withDuration: 0.4)]), .removeFromParent()]))
    }

    private func updateHabitat(_ s: WorldSnapshot, animate: Bool) {
        if s.habitatLit != current.habitatLit || !hasApplied {
            windows.texture = Art.habitatWindowsTexture(lit: s.habitatLit)
            if animate && s.habitatLit {
                windows.alpha = 0.3
                windows.run(.fadeAlpha(to: 1, duration: 0.35))
            }
        }
        beacon.removeAllActions()
        if s.habitatWarning {
            beacon.alpha = 1
            if !reduceMotion {
                beacon.run(.repeatForever(.sequence([.fadeAlpha(to: 0.25, duration: 0.5), .fadeAlpha(to: 1, duration: 0.5)])))
            }
        } else {
            beacon.alpha = 0
        }
        if s.dish, dish == nil {
            let node = Art.dish()
            node.zPosition = 0.05
            habitat.addChild(node)
            dish = node
        } else if !s.dish, let node = dish {
            node.removeFromParent()
            dish = nil
        }
    }

    private func updatePads(_ s: WorldSnapshot) {
        for (id, pad) in pads {
            pad.isHidden = !s.padsVisible
        }
        for (id, highlight) in padHighlights {
            let on = s.padsVisible && s.highlightedPads.contains(id)
            if on && highlight.isHidden {
                highlight.isHidden = false
                highlight.alpha = 1
                if !reduceMotion {
                    highlight.run(.repeatForever(.sequence([.fadeAlpha(to: 0.35, duration: 0.6), .fadeAlpha(to: 1, duration: 0.6)])), withKey: "pulse")
                }
            } else if !on {
                highlight.removeAction(forKey: "pulse")
                highlight.isHidden = true
            }
        }
    }

    private func updateGreenhouse(_ s: WorldSnapshot, animate: Bool) {
        if s.greenhouse, greenhouse == nil {
            let node = SKNode()
            let spot = Self.greenhouseSpot
            node.position = Iso.point(spot)
            node.zPosition = Iso.depth(spot)
            node.addChild(Art.greenhouseBase())
            for x in [-0.7, -0.35, 0, 0.35, 0.7] as [CGFloat] {
                for y in [-0.17, 0.17] as [CGFloat] {
                    let plant = Art.sprite(Art.plantTexture(level: 0), Art.plantCanvas)
                    plant.position = Iso.point(x, y) + CGPoint(x: 0, y: 7)
                    plant.zPosition = 1 + (x + y) * 0.01
                    node.addChild(plant)
                    plants.append(plant)
                }
            }
            let glow = Art.greenhouseGlow()
            glow.zPosition = 2
            glow.alpha = 0
            node.addChild(glow)
            greenhouseGlow = glow
            let shell = Art.greenhouseShell()
            shell.zPosition = 3
            node.addChild(shell)
            world.addChild(node)
            greenhouse = node
        } else if !s.greenhouse, let node = greenhouse {
            node.removeFromParent()
            greenhouse = nil
            plants = []
            greenhouseGlow = nil
        }
        guard greenhouse != nil else { return }
        let fraction = max(0, min(1, s.cropFraction))
        let level = fraction < 0.3 ? 0 : (fraction < 0.999 ? 1 : 2)
        let scale = 0.55 + 0.45 * fraction
        for plant in plants {
            plant.texture = Art.plantTexture(level: level)
            if animate {
                plant.run(.scale(to: scale, duration: 0.2))
            } else {
                plant.setScale(scale)
            }
        }
        greenhouseGlow?.alpha = s.gardenLights ? 1 : 0
    }

    private func updateShelter(_ s: WorldSnapshot) {
        if s.shelter, shelter == nil {
            let node = SKNode()
            let spot = Self.shelterSpot
            node.position = Iso.point(spot)
            node.zPosition = Iso.depth(spot)
            node.addChild(Art.shelterBody())
            let glow = Art.shelterGlow()
            glow.zPosition = 1
            glow.alpha = 0
            node.addChild(glow)
            shelterGlow = glow
            world.addChild(node)
            shelter = node
        } else if !s.shelter, let node = shelter {
            node.removeFromParent()
            shelter = nil
            shelterGlow = nil
        }
        guard let glow = shelterGlow else { return }
        glow.removeAllActions()
        if s.shelterOccupied {
            glow.alpha = 1
            if !reduceMotion {
                glow.run(.repeatForever(.sequence([.fadeAlpha(to: 0.6, duration: 1.1), .fadeAlpha(to: 1, duration: 1.1)])))
            }
        } else {
            glow.alpha = 0
        }
    }

    // MARK: Rover

    private func trackPoint(_ meters: Double) -> CGPoint {
        Iso.point(Self.trackStartX + CGFloat(meters), Self.trackY)
    }

    private func updateRover(_ s: WorldSnapshot) {
        if s.roverTrack != trackKey {
            trackNode?.removeFromParent()
            trackNode = nil
            trackKey = s.roverTrack
            if let track = s.roverTrack {
                let node = makeTrack(track)
                world.addChild(node)
                trackNode = node
            }
        }
        guard let track = s.roverTrack else {
            cancelRun()
            rover.position = Iso.point(Self.roverParking)
            rover.zPosition = Iso.depth(Self.roverParking)
            return
        }
        rover.zPosition = ZLayer.roverOnTrack
        if let run = s.roverRun {
            if run.id != lastRunID { startRun(run, track: track) }
        } else {
            cancelRun()
            rover.position = trackPoint(s.roverPositionM)
        }
    }

    private func cancelRun() {
        removeAction(forKey: "roverRun")
        rover.removeAllActions()
        rover.alpha = 1
        signalLayer.removeAllChildren()
        lastRunID = nil
    }

    private func makeTrack(_ track: RoverTrackVisual) -> SKNode {
        let node = SKNode()
        node.zPosition = ZLayer.track
        let x0 = Self.trackStartX
        let x1 = Self.trackStartX + CGFloat(track.lengthM)
        let y = Self.trackY
        func lane(_ a: CGFloat, _ b: CGFloat, _ halfWidth: CGFloat) -> CGPath {
            let path = CGMutablePath()
            path.addLines(between: [Iso.point(a, y - halfWidth), Iso.point(b, y - halfWidth),
                                    Iso.point(b, y + halfWidth), Iso.point(a, y + halfWidth)])
            path.closeSubpath()
            return path
        }
        let strip = SKShapeNode(path: lane(x0 - 0.2, x1 + 0.3, 0.32))
        strip.fillColor = UIColor(hex: 0xA3ABB6, alpha: 0.85)
        strip.strokeColor = UIColor(hex: 0x8A93A0)
        strip.lineWidth = 1
        node.addChild(strip)
        let bay = SKShapeNode(path: lane(x0 + CGFloat(track.bayStartM), x0 + CGFloat(track.bayEndM), 0.32))
        bay.fillColor = UIColor(hex: 0xF2B84B, alpha: 0.42)
        bay.strokeColor = UIColor(hex: 0xF2B84B)
        bay.lineWidth = 2
        bay.zPosition = 0.1
        node.addChild(bay)
        for meter in 0...Int(track.lengthM) {
            let gx = x0 + CGFloat(meter)
            let tick = SKShapeNode()
            let path = CGMutablePath()
            path.addLines(between: [Iso.point(gx, y - 0.32), Iso.point(gx, y + 0.32)])
            tick.path = path
            tick.strokeColor = UIColor(hex: 0x5B6472, alpha: 0.8)
            tick.lineWidth = 1.2
            tick.zPosition = 0.2
            node.addChild(tick)
            let label = SKLabelNode(text: meter == 0 ? "0 m" : "\(meter)")
            label.fontName = "AvenirNext-Bold"
            label.fontSize = 15
            label.fontColor = UIColor(hex: 0xEDF1F3)
            label.position = Iso.point(gx, y + 0.62) + CGPoint(x: -6, y: -8)
            label.zPosition = 0.3
            node.addChild(label)
        }
        flagPoints = []
        for marker in track.markers {
            flagPoints.append((marker, Iso.point(x0 + CGFloat(marker), y - 0.36) + CGPoint(x: 8, y: 22)))
            let selected = track.selectedMarker.map { abs($0 - marker) < 1e-9 } ?? false
            let base = Iso.point(x0 + CGFloat(marker), y - 0.36)
            let pole = SKShapeNode()
            let path = CGMutablePath()
            path.addLines(between: [base, base + CGPoint(x: 0, y: 30)])
            pole.path = path
            pole.strokeColor = UIColor(hex: 0x3A4555)
            pole.lineWidth = 2
            pole.zPosition = 0.4
            node.addChild(pole)
            let flag = SKShapeNode(rectOf: CGSize(width: selected ? 22 : 18, height: selected ? 14 : 12), cornerRadius: 2)
            flag.position = base + CGPoint(x: 8, y: 25)
            flag.fillColor = selected ? UIColor(hex: 0xF2B84B) : UIColor(hex: 0xEDF1F3)
            flag.strokeColor = UIColor(hex: 0x3A4555)
            flag.lineWidth = 1
            flag.zPosition = 0.5
            node.addChild(flag)
        }
        return node
    }

    private func startRun(_ run: RoverRun, track: RoverTrackVisual) {
        cancelRun()
        lastRunID = run.id
        let start = trackPoint(0)
        let stop = trackPoint(run.stopM)
        rover.position = start
        if reduceMotion {
            rover.alpha = 0
            rover.position = stop
            rover.run(.fadeIn(withDuration: 0.25))
            return
        }
        rover.run(.move(to: stop, duration: max(0.01, run.stopM / run.speed)))
        var steps: [SKAction] = []
        if let imageAt = run.imageAtSecond {
            steps.append(.wait(forDuration: imageAt))
            steps.append(.run { [weak self] in self?.flashRover(color: 0xFFFFFF) })
            steps.append(.run { [weak self] in self?.sendImagePulse(duration: run.oneWaySeconds) })
            steps.append(.wait(forDuration: run.oneWaySeconds))
            steps.append(.run { [weak self] in self?.sendCommandPulse(to: stop, duration: run.oneWaySeconds) })
            steps.append(.wait(forDuration: max(0, run.stopAtSecond - imageAt - run.oneWaySeconds)))
        } else {
            steps.append(.wait(forDuration: run.stopAtSecond))
        }
        steps.append(.run { [weak self] in self?.flashRover(color: 0x53C6D7) })
        self.run(.sequence(steps), withKey: "roverRun")
    }

    private func flashRover(color: UInt32) {
        let ring = SKSpriteNode(texture: Art.glowDot(color: color, diameter: 40))
        ring.position = world.convert(rover.position + CGPoint(x: 0, y: 14), to: self)
        ring.setScale(0.4)
        signalLayer.addChild(ring)
        ring.run(.sequence([.group([.scale(to: 1.6, duration: 0.35), .fadeOut(withDuration: 0.35)]), .removeFromParent()]))
    }

    private func sendImagePulse(duration: Double) {
        let from = world.convert(rover.position + CGPoint(x: 0, y: 18), to: self)
        pulse(from: from, to: earth.position, color: 0xF2B84B, duration: duration)
    }

    private func sendCommandPulse(to stop: CGPoint, duration: Double) {
        let target = world.convert(stop + CGPoint(x: 0, y: 18), to: self)
        pulse(from: earth.position, to: target, color: 0x53C6D7, duration: duration)
    }

    private func pulse(from: CGPoint, to: CGPoint, color: UInt32, duration: Double) {
        let dot = SKSpriteNode(texture: Art.glowDot(color: color, diameter: 22))
        dot.position = from
        signalLayer.addChild(dot)
        let trail = SKShapeNode()
        let path = CGMutablePath()
        path.addLines(between: [from, to])
        trail.path = path.copy(dashingWithPhase: 0, lengths: [4, 6])
        trail.strokeColor = UIColor(hex: color, alpha: 0.45)
        trail.lineWidth = 1.5
        trail.zPosition = -0.1
        signalLayer.addChild(trail)
        dot.run(.sequence([.move(to: to, duration: duration), .fadeOut(withDuration: 0.2), .removeFromParent()]))
        trail.run(.sequence([.wait(forDuration: duration + 0.4), .fadeOut(withDuration: 0.3), .removeFromParent()]))
    }

    // MARK: Energy flow

    private func updateFlow(_ s: WorldSnapshot) {
        let key = "\(s.flow)-\(s.arrays)-\(s.batteries)-\(reduceMotion)"
        guard key != flowKey else { return }
        flowKey = key
        flowLayer.removeAllChildren()
        let sources: [CGPoint]
        switch s.flow {
        case .none: return
        case .solarToBase: sources = Array(Self.arrayPads.prefix(s.arrays))
        case .batteryToBase: sources = Array(Self.batteryPads.prefix(s.batteries))
        }
        guard !sources.isEmpty else { return }
        let gx = sources.map(\.x).reduce(0, +) / CGFloat(sources.count)
        let gy = sources.map(\.y).reduce(0, +) / CGFloat(sources.count)
        let from = Iso.point(gx, gy) + CGPoint(x: 0, y: 12)
        let to = Iso.point(0, 0) + CGPoint(x: 0, y: 14)
        let path = CGMutablePath()
        path.move(to: from)
        path.addQuadCurve(to: to, control: CGPoint(x: (from.x + to.x) / 2, y: max(from.y, to.y) + 40))
        let line = SKShapeNode(path: path.copy(dashingWithPhase: 0, lengths: [5, 6]))
        line.strokeColor = UIColor(hex: 0x53C6D7, alpha: reduceMotion ? 0.9 : 0.4)
        line.lineWidth = reduceMotion ? 2.4 : 1.6
        flowLayer.addChild(line)
        guard !reduceMotion else { return }
        for i in 0..<5 {
            let dot = SKSpriteNode(texture: Art.glowDot(color: 0x53C6D7, diameter: 14))
            dot.position = from
            dot.alpha = 0
            flowLayer.addChild(dot)
            let follow = SKAction.follow(path, asOffset: false, orientToPath: false, duration: 1.5)
            dot.run(.sequence([.wait(forDuration: Double(i) * 0.3), .fadeIn(withDuration: 0.05), .repeatForever(follow)]))
        }
    }

    // MARK: Touch

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: world)
        let tolerance = 34 / max(0.3, world.xScale)
        if let onMarkerTapped {
            for (mission, node) in markerNodes where hypot(node.position.x - location.x, node.position.y + 20 - location.y) < tolerance {
                onMarkerTapped(mission)
                return
            }
        }
        if let onFlagTapped, trackKey != nil {
            var best: (Double, CGFloat)?
            for (marker, point) in flagPoints {
                let d = hypot(point.x - location.x, point.y - location.y)
                if d < tolerance, d < (best?.1 ?? .infinity) { best = (marker, d) }
            }
            if let best {
                onFlagTapped(best.0)
                return
            }
        }
        guard current.padsVisible else { return }
        let candidates = [location, location + CGPoint(x: 0, y: -16)]
        var best: (PadID, CGFloat)?
        for point in candidates {
            let g = Iso.grid(from: point)
            for (index, spot) in Self.arrayPads.enumerated() {
                let d = hypot(g.x - spot.x, g.y - spot.y)
                if d < 0.7, d < (best?.1 ?? .infinity) { best = (.array(index), d) }
            }
            for (index, spot) in Self.batteryPads.enumerated() {
                let d = hypot(g.x - spot.x, g.y - spot.y)
                if d < 0.7, d < (best?.1 ?? .infinity) { best = (.battery(index), d) }
            }
        }
        if let best { onPadTapped?(best.0) }
    }

    // MARK: Floating numbers

    private func anchorPoint(_ anchor: FloaterAnchor, _ s: WorldSnapshot) -> CGPoint {
        func average(_ spots: [CGPoint]) -> CGPoint {
            guard !spots.isEmpty else { return Iso.point(0, 0) }
            let gx = spots.map(\.x).reduce(0, +) / CGFloat(spots.count)
            let gy = spots.map(\.y).reduce(0, +) / CGFloat(spots.count)
            return Iso.point(gx, gy)
        }
        switch anchor {
        case .arrays: return average(Array(Self.arrayPads.prefix(max(1, s.arrays)))) + CGPoint(x: 0, y: 46)
        case .batteries: return average(Array(Self.batteryPads.prefix(max(1, s.batteries)))) + CGPoint(x: 0, y: 52)
        case .habitat: return Iso.point(0, 0) + CGPoint(x: 0, y: 84)
        case .greenhouse: return Iso.point(Self.greenhouseSpot) + CGPoint(x: 0, y: 52)
        case .shelter: return Iso.point(Self.shelterSpot) + CGPoint(x: 0, y: 44)
        }
    }

    private func updateFloaters(_ s: WorldSnapshot) {
        if s.floaters.isEmpty { shownFloaters.removeAll() }
        for (index, floater) in s.floaters.enumerated() where !shownFloaters.contains(floater.id) {
            shownFloaters.insert(floater.id)
            let label = SKLabelNode()
            let font = UIFont.systemFont(ofSize: 22, weight: .black)
            let rounded = font.fontDescriptor.withDesign(.rounded).map { UIFont(descriptor: $0, size: 22) } ?? font
            label.attributedText = NSAttributedString(string: floater.text, attributes: [
                .font: rounded,
                .foregroundColor: UIColor(hex: floater.color),
                .strokeColor: UIColor(hex: 0x0B1426),
                .strokeWidth: -5
            ])
            label.verticalAlignmentMode = .center
            label.position = anchorPoint(floater.anchor, s) + CGPoint(x: CGFloat(index % 2) * 18 - 9, y: 0)
            label.zPosition = ZLayer.flow + 10
            world.addChild(label)
            if reduceMotion {
                label.run(.sequence([.wait(forDuration: 0.9), .fadeOut(withDuration: 0.25), .removeFromParent()]))
            } else {
                label.setScale(0.4)
                let pop = SKAction.scale(to: 1.15, duration: 0.14)
                pop.timingMode = .easeOut
                let rise = SKAction.moveBy(x: 0, y: 34, duration: 1.0)
                rise.timingMode = .easeOut
                label.run(.sequence([pop, .scale(to: 1, duration: 0.08), .group([rise, .sequence([.wait(forDuration: 0.65), .fadeOut(withDuration: 0.35)])]), .removeFromParent()]))
            }
        }
    }

    // MARK: Mission markers

    private func markerAnchor(_ mission: MissionID) -> CGPoint {
        switch mission {
        case .lightsOut: return Iso.point(-2.6, 0.6) + CGPoint(x: 0, y: 50)
        case .livingBase: return Iso.point(Self.greenhouseSpot) + CGPoint(x: 0, y: 64)
        case .stormDrill: return Iso.point(Self.shelterSpot) + CGPoint(x: 0, y: 56)
        case .signalLag: return Iso.point(Self.roverParking) + CGPoint(x: 0, y: 58)
        }
    }

    private func updateMarkers(_ s: WorldSnapshot) {
        guard s.markers != markerKey else { return }
        markerKey = s.markers
        markerNodes.values.forEach { $0.removeFromParent() }
        markerNodes = [:]
        for marker in s.markers {
            let node = SKSpriteNode(texture: Art.markerTexture(symbol: marker.state == .done ? "checkmark" : (marker.state == .locked ? "lock.fill" : marker.symbol),
                                                                 state: marker.state))
            let side: CGFloat = marker.state == .next ? 58 : 40
            node.size = CGSize(width: side, height: side * 1.25)
            node.anchorPoint = CGPoint(x: 0.5, y: 0)
            node.position = markerAnchor(marker.mission)
            node.zPosition = ZLayer.flow + 20
            node.alpha = marker.state == .locked ? 0.8 : 1
            world.addChild(node)
            markerNodes[marker.mission] = node
            if marker.state == .next && !reduceMotion {
                let up = SKAction.moveBy(x: 0, y: 8, duration: 0.55)
                up.timingMode = .easeInEaseOut
                node.run(.repeatForever(.sequence([up, up.reversed()])))
            }
        }
    }
}

/// Owns one retained scene for one displayed world. SwiftUI body evaluations never create scenes.
@MainActor
final class WorldCoordinator {
    let scene: WorldScene
    private(set) var snapshot = WorldSnapshot()

    init() {
        scene = WorldScene(size: CGSize(width: 800, height: 600))
    }

    func show(_ snapshot: WorldSnapshot, reduceMotion: Bool) {
        scene.reduceMotion = reduceMotion
        self.snapshot = snapshot
        scene.apply(snapshot)
    }

    var onPadTapped: ((PadID) -> Void)? {
        get { scene.onPadTapped }
        set { scene.onPadTapped = newValue }
    }

    var onMarkerTapped: ((MissionID) -> Void)? {
        get { scene.onMarkerTapped }
        set { scene.onMarkerTapped = newValue }
    }

    var onFlagTapped: ((Double) -> Void)? {
        get { scene.onFlagTapped }
        set { scene.onFlagTapped = newValue }
    }

    func setHUDInsets(top: CGFloat, bottom: CGFloat) {
        scene.hudInsets = UIEdgeInsets(top: top, left: 0, bottom: bottom, right: 0)
    }
}
