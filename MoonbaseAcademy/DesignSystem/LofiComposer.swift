import Foundation

/// An original, procedurally composed lofi loop: Fmaj7 – Em7 – Dm7 – Cmaj7 at 72 BPM with
/// electric-piano chords, bass, a sparse pentatonic melody, swung boom-bap drums and vinyl crackle.
/// Everything is synthesized from sine waves and noise in this file, so the music belongs to the
/// project and needs no license. Pure Foundation; deterministic for a given seed.
enum LofiComposer {
    static let bpm = 72.0
    static let bars = 16
    static let beatsPerBar = 4.0

    static func loopSeconds() -> Double { Double(bars) * beatsPerBar * 60 / bpm }

    private struct Random {
        var state: UInt64
        mutating func next() -> Double {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return Double(state >> 11) / Double(UInt64(1) << 53)
        }
        mutating func range(_ lo: Double, _ hi: Double) -> Double { lo + (hi - lo) * next() }
    }

    private static func hz(_ midi: Double) -> Double { 440 * pow(2, (midi - 69) / 12) }

    /// Renders one seamless loop of mono samples in -1...1. Note tails wrap around to the start.
    static func render(sampleRate: Double = 22_050, seed: UInt64 = 7) -> [Float] {
        let beat = 60 / bpm
        let count = Int(loopSeconds() * sampleRate)
        var mix = [Double](repeating: 0, count: count)
        var rng = Random(state: seed)

        func add(at start: Double, length: Double, _ voice: (Double) -> Double) {
            let first = Int(start * sampleRate)
            let frames = Int(length * sampleRate)
            for i in 0..<frames {
                let t = Double(i) / sampleRate
                mix[(first + i) % count] += voice(t)
            }
        }

        let chords: [[Double]] = [[53, 57, 60, 64], [52, 55, 59, 62], [50, 53, 57, 60], [55, 59, 60, 64]]
        let roots: [Double] = [41, 40, 38, 36]
        let pentatonic: [Double] = [72, 74, 76, 79, 81, 84]
        let swing = 0.12

        for bar in 0..<bars {
            let chordIndex = (bar / 2) % chords.count
            let barStart = Double(bar) * beatsPerBar * beat

            // Electric piano: a soft hit on 1 and a lazy one on the swung "and" of 2.
            let hits: [(Double, Double)] = bar % 2 == 0 ? [(0, 1.0), (1.5 + swing, 0.6)] : [(0, 0.85), (2.5 + swing, 0.55)]
            for (position, velocity) in hits {
                for (n, note) in chords[chordIndex].enumerated() {
                    let f = hz(note) * (1 + (Double(n) - 1.5) * 0.0007)
                    let strum = Double(n) * 0.012
                    add(at: barStart + (position) * beat + strum, length: 2.6) { t in
                        let attack = 1 - exp(-t / 0.012)
                        let body = sin(2 * .pi * f * t) + 0.35 * sin(4 * .pi * f * t) * exp(-t * 3) + 0.12 * sin(6 * .pi * f * t) * exp(-t * 6)
                        let tremolo = 1 + 0.14 * sin(2 * .pi * 4.2 * t)
                        return body * attack * exp(-t * 1.15) * tremolo * 0.06 * velocity
                    }
                }
            }

            // Bass: root on 1, a softer pickup on the swung "and" of 3.
            let root = hz(roots[chordIndex])
            for (position, velocity, length) in [(0.0, 1.0, 2.2), (2.5 + swing, 0.6, 1.2)] {
                add(at: barStart + position * beat, length: length) { t in
                    let attack = 1 - exp(-t / 0.01)
                    return (sin(2 * .pi * root * t) + 0.25 * sin(4 * .pi * root * t)) * attack * exp(-t * 1.4) * 0.2 * velocity
                }
            }

            // Melody enters after four bars: two or three gentle notes per bar, with rests.
            if bar >= 4 && bar % 4 != 3 {
                let notes = 2 + Int(rng.next() * 2)
                var used = Set<Int>()
                for _ in 0..<notes {
                    let slot = Int(rng.next() * 8)
                    guard used.insert(slot).inserted else { continue }
                    let midi = pentatonic[Int(rng.next() * Double(pentatonic.count))]
                    let f = hz(midi)
                    let position = Double(slot) * 0.5 + (slot % 2 == 1 ? swing : 0)
                    let velocity = rng.range(0.6, 1.0)
                    add(at: barStart + position * beat, length: 1.6) { t in
                        let attack = 1 - exp(-t / 0.03)
                        let vibrato = 1 + 0.004 * sin(2 * .pi * 5 * t)
                        let tone = sin(2 * .pi * f * vibrato * t) + 0.18 * sin(6 * .pi * f * t)
                        return tone * attack * exp(-t * 2.3) * 0.055 * velocity
                    }
                }
            }

            // Drums: kick on 1 and the "and" of 3, snare on 2 and 4, swung hats.
            for position in [0.0, 2.5 + swing] {
                add(at: barStart + position * beat, length: 0.4) { t in
                    let phase = 2 * .pi * (45 * t + (80 / 25) * (1 - exp(-t * 25)))
                    return sin(phase) * exp(-t * 9) * 0.42
                }
            }
            for position in [1.0, 3.0] {
                var noiseState = rng.next()
                var smooth = 0.0
                add(at: barStart + position * beat + 0.01, length: 0.3) { t in
                    noiseState = (noiseState * 9301 + 49297).truncatingRemainder(dividingBy: 233280)
                    let noise = noiseState / 233280 * 2 - 1
                    smooth += (noise - smooth) * 0.35
                    return smooth * exp(-t * 16) * 0.2 + sin(2 * .pi * 185 * t) * exp(-t * 22) * 0.09
                }
            }
            for eighth in 0..<8 where rng.next() > 0.12 {
                let position = Double(eighth) * 0.5 + (eighth % 2 == 1 ? swing : 0)
                let velocity = rng.range(0.5, 1.0) * (eighth % 2 == 0 ? 1 : 0.7)
                var last = 0.0
                var noiseState = rng.next() * 233280
                add(at: barStart + position * beat, length: 0.06) { t in
                    noiseState = (noiseState * 9301 + 49297).truncatingRemainder(dividingBy: 233280)
                    let noise = noiseState / 233280 * 2 - 1
                    let bright = noise - last
                    last = noise
                    return bright * exp(-t * 70) * 0.035 * velocity
                }
            }
        }

        // Vinyl: a quiet noise bed and occasional crackles.
        var crackle = Random(state: seed &+ 99)
        for i in 0..<count {
            mix[i] += (crackle.next() * 2 - 1) * 0.0035
            if crackle.next() < 0.0003 {
                mix[i] += (crackle.next() > 0.5 ? 1 : -1) * crackle.range(0.03, 0.08)
            }
        }

        // Warm low-pass (two cyclic passes so the loop joins cleanly), gentle saturation, normalize.
        let cutoff = 2800.0
        let alpha = 1 - exp(-2 * .pi * cutoff / sampleRate)
        var state = 0.0
        for _ in 0..<2 {
            for i in 0..<count {
                state += (mix[i] - state) * alpha
                mix[i] = state
            }
        }
        var peak = 1e-9
        for i in 0..<count {
            mix[i] = tanh(mix[i] * 1.3) / 1.3
            peak = max(peak, abs(mix[i]))
        }
        let gain = 0.8 / peak
        return mix.map { Float($0 * gain) }
    }
}
