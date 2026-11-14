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
        engine.mainMixerNode.outputVolume = 0.45
    }

    func play(_ kind: Kind) {
        guard enabled, let format else { return }
        if !started {
            do {
                try engine.start()
                started = true
            } catch {
                return
            }
        }
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
