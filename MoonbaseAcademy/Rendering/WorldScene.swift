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
    /// Part of the world that must stay visible, including the curved horizon above the base.
    static let contentRect = CGRect(x: -300, y: -205, width: 600, height: 495)

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
    private var touchStart: CGPoint?
    private let skyLayer = SKNode()
    private var twinkles: [(SKSpriteNode, CGPoint)] = []
    private let beaconTip = SKSpriteNode(texture: Art.glowDot(color: 0xFFB347, diameter: 10))
    private let bottomShade = SKSpriteNode(texture: Art.bottomShade())
    private var patrolling = false
    private var lastRoverX: CGFloat = 0
    private var skyRunning = false

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
        skyLayer.zPosition = ZLayer.background + 50
        addChild(skyLayer)
        var rng = SeededRandom(seed: 42)
        for _ in 0..<26 {
            let star = SKSpriteNode(texture: Art.glowDot(color: 0xDDEBFF, diameter: 8))
            star.setScale(rng.range(0.35, 0.9))
            star.alpha = rng.range(0.3, 0.9)
            skyLayer.addChild(star)
            twinkles.append((star, CGPoint(x: rng.range(-0.5, 0.5), y: rng.range(-0.05, 0.5))))
        }
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
        beaconTip.position = CGPoint(x: 4.5, y: 89.5)
        beaconTip.zPosition = 0.3
        beaconTip.blendMode = .add
        habitat.addChild(beaconTip)
        world.addChild(habitat)

        rover.position = Iso.point(Self.roverParking)
        rover.zPosition = Iso.depth(Self.roverParking)
        world.addChild(rover)

        flowLayer.zPosition = ZLayer.flow
        world.addChild(flowLayer)

        bottomShade.anchorPoint = CGPoint(x: 0.5, y: 0)
        bottomShade.zPosition = ZLayer.tint - 5
        addChild(bottomShade)
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
        bottomShade.size = CGSize(width: size.width + 4, height: max(120, bottom + 60))
        bottomShade.position = CGPoint(x: 0, y: -size.height / 2)
        let earthSize = max(44, min(84, min(size.width, size.height) * 0.15))
        earth.size = CGSize(width: earthSize, height: earthSize)
        earth.position = CGPoint(x: size.width / 2 - earthSize * 0.8, y: size.height / 2 - top - earthSize * 0.6)
        if let storm {
            storm.position = CGPoint(x: -size.width * 0.2, y: size.height / 2 + 20)
            storm.particlePositionRange = CGVector(dx: size.width * 1.3, dy: 10)
        }
        for (star, unit) in twinkles {
            star.position = CGPoint(x: unit.x * size.width, y: unit.y * size.height)
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
        updateAmbient(s)
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
                addGlint(to: node, seed: index)
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
            if !s.ambient || reduceMotion {
                rover.removeAction(forKey: "patrol")
                patrolling = false
                rover.xScale = 1
                rover.position = Iso.point(Self.roverParking)
                rover.zPosition = Iso.depth(Self.roverParking)
            }
            return
        }
        if patrolling {
            rover.removeAction(forKey: "patrol")
            patrolling = false
            rover.xScale = 1
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
        rover.removeAction(forKey: "runMove")
        rover.removeAction(forKey: "fade")
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
            rover.run(.fadeIn(withDuration: 0.25), withKey: "fade")
            return
        }
        rover.run(.move(to: stop, duration: max(0.01, run.stopM / run.speed)), withKey: "runMove")
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

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchStart = touches.first?.location(in: self)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchStart = nil
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        // A drag or swipe is not a tap.
        let end = touch.location(in: self)
        defer { touchStart = nil }
        if let start = touchStart, hypot(end.x - start.x, end.y - start.y) > 14 { return }
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

    // MARK: Ambient life

    /// A brief flash of sunlight sliding across a solar panel now and then.
    private func addGlint(to node: SKNode, seed: Int) {
        guard !reduceMotion else { return }
        let glint = SKSpriteNode(texture: Art.glowDot(color: 0xFFFFFF, diameter: 28))
        glint.position = CGPoint(x: -12, y: 22)
        glint.yScale = 0.45
        glint.alpha = 0
        glint.blendMode = .add
        glint.zPosition = 0.2
        node.addChild(glint)
        let pause = 3.5 + Double(seed) * 1.3
        let sweep = SKAction.group([.sequence([.fadeAlpha(to: 0.85, duration: 0.18), .fadeAlpha(to: 0, duration: 0.45)]),
                                    .moveBy(x: 26, y: 8, duration: 0.63)])
        glint.run(.repeatForever(.sequence([.wait(forDuration: pause, withRange: 2), sweep,
                                            .moveBy(x: -26, y: -8, duration: 0)])))
    }

    private func updateAmbient(_ s: WorldSnapshot) {
        // Sky: twinkling stars and the occasional shooting star, on every screen.
        if !reduceMotion && !skyRunning {
            skyRunning = true
            for (star, _) in twinkles {
                let low = SKAction.fadeAlpha(to: CGFloat.random(in: 0.1...0.35), duration: Double.random(in: 0.8...2.2))
                let high = SKAction.fadeAlpha(to: CGFloat.random(in: 0.6...1), duration: Double.random(in: 0.8...2.2))
                star.run(.repeatForever(.sequence([low, high])), withKey: "twinkle")
            }
            run(.repeatForever(.sequence([.wait(forDuration: 4, withRange: 4),
                                          .run { [weak self] in self?.shootingStar() }])), withKey: "sky")
            beaconTip.run(.repeatForever(.sequence([.fadeAlpha(to: 1, duration: 0.12), .wait(forDuration: 0.25),
                                                    .fadeAlpha(to: 0.15, duration: 0.5), .wait(forDuration: 0.9)])), withKey: "blink")
        } else if reduceMotion && skyRunning {
            skyRunning = false
            removeAction(forKey: "sky")
            twinkles.forEach { $0.0.removeAction(forKey: "twinkle") }
            beaconTip.removeAction(forKey: "blink")
            beaconTip.alpha = 0.8
        }
        // Base only: the rover goes for a drive around the habitat.
        let wantsPatrol = s.ambient && s.roverTrack == nil && !reduceMotion
        if wantsPatrol && !patrolling {
            startPatrol()
        } else if !wantsPatrol && patrolling {
            rover.removeAction(forKey: "patrol")
            patrolling = false
            rover.xScale = 1
            rover.position = Iso.point(Self.roverParking)
            rover.zPosition = Iso.depth(Self.roverParking)
        }
    }

    private func startPatrol() {
        patrolling = true
        rover.position = Iso.point(Self.roverParking)
        lastRoverX = rover.position.x
        let route: [CGPoint] = [CGPoint(x: 4.3, y: 2.5), CGPoint(x: 4.7, y: 0.4), CGPoint(x: 4.4, y: -1.5),
                                CGPoint(x: 3.0, y: -1.5), CGPoint(x: 4.5, y: -0.8), CGPoint(x: 4.4, y: 2.3), Self.roverParking]
        var steps: [SKAction] = [.wait(forDuration: 1.5)]
        var from = Self.roverParking
        for (index, to) in route.enumerated() {
            let distance = hypot(to.x - from.x, to.y - from.y)
            let move = SKAction.move(to: Iso.point(to), duration: Double(distance) / 0.55)
            move.timingMode = .easeInEaseOut
            steps.append(move)
            steps.append(.run { [weak self] in self?.roverDust() })
            steps.append(.wait(forDuration: index == 2 || index == route.count - 1 ? 2.2 : 0.6))
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

    private func shootingStar() {
        guard size.width > 1 else { return }
        let streak = SKSpriteNode(texture: Art.glowDot(color: 0xCFE6FF, diameter: 12))
        streak.xScale = 7
        streak.yScale = 0.22
        streak.blendMode = .add
        let startX = CGFloat.random(in: -size.width * 0.45...size.width * 0.35)
        let startY = size.height * CGFloat.random(in: 0.28...0.48)
        streak.position = CGPoint(x: startX, y: startY)
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
        guard patrolling else { return }
        rover.zPosition = Iso.depth(Iso.grid(from: rover.position))
        let dx = rover.position.x - lastRoverX
        if abs(dx) > 0.05 { rover.xScale = dx >= 0 ? 1 : -1 }
        lastRoverX = rover.position.x
    }

    // MARK: Mission markers

    private func markerAnchor(_ mission: MissionID) -> CGPoint {
        switch mission {
        // Each pin stands on the empty site that drill will build on.
        case .lightsOut: return Iso.point(-2.6, 0.6) + CGPoint(x: 0, y: 6)
        case .livingBase: return Iso.point(3.0, 0.6) + CGPoint(x: 0, y: 6)
        case .stormDrill: return Iso.point(0.3, 2.9) + CGPoint(x: 0, y: 6)
        case .signalLag: return Iso.point(3.6, 3.3) + CGPoint(x: 0, y: 6)
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
            let side: CGFloat = marker.state == .next ? 46 : 32
            node.size = CGSize(width: side, height: side * 1.25)
            node.anchorPoint = CGPoint(x: 0.5, y: 0)
            node.position = markerAnchor(marker.mission)
            node.zPosition = ZLayer.flow + 20
            node.alpha = marker.state == .locked ? 0.8 : 1
            world.addChild(node)
            let shadow = SKSpriteNode(texture: Art.glowDot(color: 0x0B1426, diameter: 20))
            shadow.position = CGPoint(x: 0, y: -2)
            shadow.yScale = 0.35
            shadow.alpha = 0.5
            shadow.zPosition = -0.1
            node.addChild(shadow)
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
