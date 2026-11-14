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

    // MARK: Space ambient

    static let ambientBPM = 64.0

    static func ambientLoopSeconds() -> Double { Double(bars) * beatsPerBar * 60 / ambientBPM }

    /// An original, dreamy space-ambient loop: Ebmaj9 – Cm9 – Abmaj7 – Bb6 at 64 BPM. Detuned pads,
    /// an echoing eighth-note arpeggio, a sparse bell melody and a sub-bass bed. No drums.
    static func renderAmbient(sampleRate: Double = 22_050, seed: UInt64 = 21) -> [Float] {
        let beat = 60 / ambientBPM
        let count = Int(ambientLoopSeconds() * sampleRate)
        var mix = [Double](repeating: 0, count: count)
        var wet = [Double](repeating: 0, count: count)
        var rng = Random(state: seed)

        func add(_ target: inout [Double], at start: Double, length: Double, _ voice: (Double) -> Double) {
            let first = Int(start * sampleRate)
            let frames = Int(length * sampleRate)
            for i in 0..<frames {
                target[(first + i) % count] += voice(Double(i) / sampleRate)
            }
        }

        // Voicings (MIDI) and roots.
        let chords: [[Double]] = [[51, 58, 62, 65, 67], [48, 55, 58, 62, 63], [44, 51, 55, 60, 63], [46, 53, 55, 58, 62]]
        let roots: [Double] = [39, 36, 32, 34]
        let barLength = beatsPerBar * beat

        for block in 0..<(bars / 2) {
            let chord = chords[block % chords.count]
            let start = Double(block) * 2 * barLength
            // Pad: three detuned sines per note with a slow swell that overlaps the next chord.
            for (n, note) in chord.enumerated() {
                let f = hz(note + 12 * (n == 0 ? 0 : 0))
                let length = 2 * barLength + 2.0
                add(&mix, at: start, length: length) { t in
                    let swell = min(1, t / 1.4) * max(0, min(1, (length - t) / 2.2))
                    let wobble = 1 + 0.002 * sin(2 * .pi * 0.3 * t + Double(n))
                    let tone = sin(2 * .pi * f * 0.9975 * wobble * t) + sin(2 * .pi * f * t) + sin(2 * .pi * f * 1.0025 * t)
                    return tone * swell * 0.017
                }
            }
            // Sub bass.
            let root = hz(roots[block % roots.count])
            add(&mix, at: start, length: 2 * barLength + 1.5) { t in
                let swell = min(1, t / 0.6) * max(0, min(1, (2 * barLength + 1.5 - t) / 1.5))
                return sin(2 * .pi * root * t) * swell * 0.11
            }
            // Arpeggio: eighth notes walking up and down the chord, an octave above, into the echo.
            let pattern = [1, 2, 3, 4, 3, 2, 4, 3]
            for step in 0..<16 {
                let note = chord[pattern[step % pattern.count]] + 12
                let f = hz(note)
                let velocity = (step % 4 == 0 ? 1.0 : 0.7) * rng.range(0.85, 1.0)
                let at = start + Double(step) * 0.5 * beat
                let pluck: (Double) -> Double = { t in
                    let tone = sin(2 * .pi * f * t) + sin(6 * .pi * f * t) / 9 + sin(10 * .pi * f * t) / 25
                    return tone * (1 - exp(-t / 0.006)) * exp(-t * 3.6) * 0.045 * velocity
                }
                add(&mix, at: at, length: 1.4, pluck)
                add(&wet, at: at, length: 1.4, pluck)
            }
        }

        // Bell melody from bar 4: slow, sparse notes on chord tones and the Eb major scale.
        let scale: [Double] = [75, 77, 79, 82, 84, 87]
        for bar in 4..<bars where bar % 4 != 3 {
            let chord = chords[(bar / 2) % chords.count]
            let slots = rng.next() > 0.5 ? [0, 3] : [0, 2, 5]
            for (k, slot) in slots.enumerated() {
                let midi = k == 0 ? chord[2 + Int(rng.next() * 3)] + 12 : scale[Int(rng.next() * Double(scale.count))]
                let f = hz(midi)
                let at = Double(bar) * barLength + Double(slot) * 0.5 * beat
                let bell: (Double) -> Double = { t in
                    let tone = sin(2 * .pi * f * t) + 0.45 * sin(2 * .pi * f * 2.756 * t) * exp(-t * 3) + 0.2 * sin(4 * .pi * f * t)
                    return tone * (1 - exp(-t / 0.01)) * exp(-t * 1.6) * 0.05
                }
                add(&mix, at: at, length: 2.6, bell)
                add(&wet, at: at, length: 2.6, bell)
            }
        }

        // Echo: dotted-eighth feedback delay applied cyclically so the loop joins cleanly.
        let delay = Int(0.75 * beat * sampleRate)
        var echo = [Double](repeating: 0, count: count)
        for _ in 0..<3 {
            for i in 0..<count {
                let back = (i - delay + count) % count
                echo[i] = wet[i] + echo[back] * 0.42
            }
        }
        for i in 0..<count { mix[i] += echo[i] * 0.45 }

        // Air: the faintest noise, then a soft low-pass and normalize.
        var air = Random(state: seed &+ 5)
        for i in 0..<count { mix[i] += (air.next() * 2 - 1) * 0.0015 }
        let alpha = 1 - exp(-2 * .pi * 4200 / sampleRate)
        var state = 0.0
        for _ in 0..<2 {
            for i in 0..<count {
                state += (mix[i] - state) * alpha
                mix[i] = state
            }
        }
        var peak = 1e-9
        for i in 0..<count {
            mix[i] = tanh(mix[i] * 1.2) / 1.2
            peak = max(peak, abs(mix[i]))
        }
        let gain = 0.8 / peak
        return mix.map { Float($0 * gain) }
    }
}

enum MusicStyle: String, CaseIterable, Codable, Sendable {
    case spaceAmbient
    case lofi

    var label: String {
        switch self {
        case .spaceAmbient: return "Space ambient"
        case .lofi: return "Lofi chill"
        }
    }

    func render(sampleRate: Double) -> [Float] {
        switch self {
        case .spaceAmbient: return LofiComposer.renderAmbient(sampleRate: sampleRate)
        case .lofi: return LofiComposer.render(sampleRate: sampleRate)
        }
    }
}
