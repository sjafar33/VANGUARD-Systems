import AVFoundation

/// Tiny synthesized sound effects. Generated in code, so there are no audio files or licenses.
/// Uses the ambient category, so the silent switch and other audio are respected.
@MainActor
final class SoundFX {
    enum Kind: Hashable {
        case tap
        case pop
        case remove
        case tick
        case go
        case star
        case success
        case fail
        case denied
    }

    static let shared = SoundFX()
    var enabled = true

    /// Background music on/off. The loop is composed in code by `LofiComposer`.
    var musicEnabled = true {
        didSet { musicEnabled ? startMusic() : stopMusic() }
    }

    private let musicNode = AVAudioPlayerNode()
    private let musicFormat = AVAudioFormat(standardFormatWithSampleRate: 22_050, channels: 1)
    private var musicBuffer: AVAudioPCMBuffer?
    private var rendering = false
    private var musicPlaying = false
    private var fadeTask: Task<Void, Never>?

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format: AVAudioFormat?
    private var buffers: [Kind: AVAudioPCMBuffer] = [:]
    private var started = false

    private init() {
        format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        engine.attach(player)
        if let format { engine.connect(player, to: engine.mainMixerNode, format: format) }
        engine.mainMixerNode.outputVolume = 0.6
        engine.attach(musicNode)
        if let musicFormat { engine.connect(musicNode, to: engine.mainMixerNode, format: musicFormat) }
        musicNode.volume = 0
        NotificationCenter.default.addObserver(forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main) { _ in
            Task { @MainActor in SoundFX.shared.recover() }
        }
    }

    private func ensureEngine() -> Bool {
        if engine.isRunning { return true }
        do {
            try engine.start()
            started = true
            return true
        } catch {
            return false
        }
    }

    // MARK: Music

    func startMusic() {
        guard musicEnabled, !musicPlaying, !LaunchOptions.isUITesting else { return }
        guard let buffer = musicBuffer else {
            guard !rendering, musicFormat != nil else { return }
            rendering = true
            Task.detached(priority: .utility) {
                let samples = LofiComposer.render(sampleRate: 22_050)
                await MainActor.run {
                    SoundFX.shared.finishRendering(samples)
                }
            }
            return
        }
        guard ensureEngine() else { return }
        musicNode.stop()
        musicNode.scheduleBuffer(buffer, at: nil, options: .loops, completionHandler: nil)
        musicNode.volume = 0
        musicNode.play()
        musicPlaying = true
        fade(to: 0.42, over: 2.5)
    }

    private func finishRendering(_ samples: [Float]) {
        rendering = false
        guard let format = musicFormat,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)),
              let channel = buffer.floatChannelData?[0] else { return }
        samples.withUnsafeBufferPointer { source in
            for i in 0..<samples.count { channel[i] = source[i] }
        }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        musicBuffer = buffer
        startMusic()
    }

    func stopMusic() {
        guard musicPlaying else { return }
        musicPlaying = false
        fadeTask?.cancel()
        let node = musicNode
        fadeTask = Task { @MainActor in
            let startVolume = node.volume
            for step in 1...12 {
                try? await Task.sleep(nanoseconds: 50_000_000)
                if Task.isCancelled { return }
                node.volume = startVolume * Float(12 - step) / 12
            }
            node.stop()
        }
    }

    /// Called when the app becomes active again or audio hardware changes.
    func recover() {
        let wasPlaying = musicPlaying
        musicPlaying = false
        if wasPlaying || musicEnabled { startMusic() }
    }

    func pauseForBackground() {
        musicNode.pause()
        musicPlaying = false
    }

    private func fade(to target: Float, over seconds: Double) {
        fadeTask?.cancel()
        let node = musicNode
        fadeTask = Task { @MainActor in
            let steps = 30
            let start = node.volume
            for step in 1...steps {
                try? await Task.sleep(nanoseconds: UInt64(seconds / Double(steps) * 1_000_000_000))
                if Task.isCancelled { return }
                node.volume = start + (target - start) * Float(step) / Float(steps)
            }
        }
    }

    func play(_ kind: Kind) {
        guard enabled, let format else { return }
        guard ensureEngine() else { return }
        guard let buffer = buffers[kind] ?? make(kind, format: format) else { return }
        buffers[kind] = buffer
        player.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
        if !player.isPlaying { player.play() }
    }

    /// Each note: start frequency, end frequency, duration in seconds.
    private func notes(_ kind: Kind) -> [(Double, Double, Double)] {
        switch kind {
        case .tap: return [(900, 900, 0.035)]
        case .pop: return [(380, 980, 0.09)]
        case .remove: return [(700, 300, 0.09)]
        case .tick: return [(660, 660, 0.07)]
        case .go: return [(520, 1300, 0.28)]
        case .star: return [(1047, 1047, 0.07), (1319, 1319, 0.07), (1568, 1568, 0.12)]
        case .success: return [(523, 523, 0.09), (659, 659, 0.09), (784, 784, 0.09), (1047, 1047, 0.22)]
        case .fail: return [(440, 300, 0.22), (300, 250, 0.25)]
        case .denied: return [(220, 200, 0.12)]
        }
    }

    private func make(_ kind: Kind, format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let rate = format.sampleRate
        let parts = notes(kind)
        let total = parts.reduce(0) { $0 + Int($1.2 * rate) }
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(total)),
              let channel = buffer.floatChannelData?[0] else { return nil }
        var index = 0
        var phase = 0.0
        for (start, end, duration) in parts {
            let count = Int(duration * rate)
            for i in 0..<count {
                let t = Double(i) / Double(max(1, count))
                let frequency = start + (end - start) * t
                phase += 2 * .pi * frequency / rate
                let attack = min(1, Double(i) / (0.004 * rate))
                let envelope = attack * pow(1 - t, 1.6)
                let wave = sin(phase) + 0.25 * sin(2 * phase) + 0.1 * sin(3 * phase)
                channel[index] = Float(wave * envelope * 0.5)
                index += 1
            }
        }
        buffer.frameLength = AVAudioFrameCount(index)
        return buffer
    }
}
