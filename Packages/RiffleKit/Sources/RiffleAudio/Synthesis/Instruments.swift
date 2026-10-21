import Foundation

/// Offline note renderers. Both are tuned to land exactly on pitch, which matters more than
/// realism for ear training. Recorded samples can replace them later behind `ToneEngine`.
public enum Instrument: String, Sendable, CaseIterable {
    case guitar, piano

    public func render(frequency: Double, duration: Double, velocity: Double, sampleRate: Double) -> [Float] {
        switch self {
        case .guitar: PluckedString.render(frequency: frequency, duration: duration, velocity: velocity, sampleRate: sampleRate)
        case .piano: PianoTone.render(frequency: frequency, duration: duration, velocity: velocity, sampleRate: sampleRate)
        }
    }
}

/// Karplus–Strong plucked string with an allpass fractional delay so the loop length (and the
/// pitch) is exact, a pick-position comb for tone, and a decay that shortens up the neck.
enum PluckedString {
    static func render(frequency: Double, duration: Double, velocity: Double, sampleRate: Double, seed: UInt64 = 1) -> [Float] {
        let count = Int(duration * sampleRate)
        let period = sampleRate / frequency
        // Loop delay = N (buffer) + 0.5 (two-point average) + d (allpass); keep d in [0.1, 1.1) for stability.
        var n = Int(period - 0.5)
        var d = period - 0.5 - Double(n)
        if d < 0.1 {
            n -= 1
            d += 1
        }
        let c = (1 - d) / (1 + d)
        // Seconds to fall 60 dB: long on bass strings, shorter on treble.
        let t60 = max(1.2, 4.5 - 2.2 * log2(frequency / 82.4))
        let loss = pow(0.001, 1 / (frequency * t60))

        // Excitation: the string's shape when released (a triangle peaking at the pick point,
        // ~1/7 from the bridge), which guarantees a strong fundamental, plus a little low-passed
        // noise for pick attack; harder picking adds more noise and so more brightness.
        var rng = seed
        let pickPoint = 1.0 / 7
        let brightness = 0.35 + 0.55 * velocity
        let noiseShare = 0.15 + 0.25 * velocity
        var lowpassed = 0.0
        var buffer = [Double](repeating: 0, count: n)
        for i in 0..<n {
            let x = Double(i) / Double(n)
            let triangle = x < pickPoint ? x / pickPoint : (1 - x) / (1 - pickPoint)
            rng = rng &* 6364136223846793005 &+ 1442695040888963407
            let white = Double(rng >> 11) / Double(1 << 53) * 2 - 1
            lowpassed += brightness * (white - lowpassed)
            buffer[i] = (1 - noiseShare) * triangle + noiseShare * lowpassed
        }
        let mean = buffer.reduce(0, +) / Double(n)
        let peak = buffer.map { abs($0 - mean) }.max() ?? 1
        buffer = buffer.map { ($0 - mean) / max(peak, 1e-9) }

        var output = [Float](repeating: 0, count: count)
        var index = 0
        var previous = 0.0
        var apIn = 0.0
        var apOut = 0.0
        let gain = 0.45 * (0.4 + 0.6 * velocity)
        for i in 0..<count {
            let delayed = buffer[index]
            let averaged = 0.5 * (delayed + previous)
            previous = delayed
            let allpassed = c * averaged + apIn - c * apOut
            apIn = averaged
            apOut = allpassed
            buffer[index] = allpassed * loss
            index += 1
            if index == n { index = 0 }
            output[i] = Float(delayed * gain)
        }
        applyEdges(&output, sampleRate: sampleRate, attack: 0.002, release: 0.06)
        return output
    }
}

/// Additive piano-like tone: stretched (inharmonic) partials tuned so the fundamental is exact,
/// two slightly detuned strings per partial for the gentle beating of a real piano, and a
/// fast-then-slow decay. Uses recursive oscillators, so it's cheap to render.
enum PianoTone {
    static func render(frequency: Double, duration: Double, velocity: Double, sampleRate: Double) -> [Float] {
        let count = Int(duration * sampleRate)
        var output = [Double](repeating: 0, count: count)
        let midi = 69 + 12 * log2(frequency / 440)
        let b = 0.00012 * pow(2, (midi - 60) / 18)
        let base = frequency / (1 + b).squareRoot()
        let slowDecay = max(0.8, 3.2 - 0.05 * (midi - 48))
        let hammer = 0.9 - 0.45 * velocity // lower = brighter
        let detune = [pow(2, -0.7 / 1200), pow(2, 0.7 / 1200)]

        for h in 1...24 {
            let partial = Double(h) * base * (1 + b * Double(h * h)).squareRoot()
            guard partial < sampleRate * 0.45 else { break }
            let amplitude = pow(Double(h), -1.1) * exp(-Double(h - 1) * hammer * 0.35) / Double(detune.count)
            let tauFast = 0.22 / (1 + 0.1 * Double(h - 1))
            let tauSlow = slowDecay / (1 + 0.18 * Double(h - 1))
            let fastStep = exp(-1 / (tauFast * sampleRate))
            let slowStep = exp(-1 / (tauSlow * sampleRate))
            for (s, factor) in detune.enumerated() {
                let omega = 2 * Double.pi * partial * factor / sampleRate
                let cosW = cos(omega), sinW = sin(omega)
                var re = cos(Double(h + s)), im = sin(Double(h + s)) // per-partial phase offset
                var fast = 0.55 * amplitude, slow = 0.45 * amplitude
                for i in 0..<count {
                    output[i] += (fast + slow) * im
                    let nextRe = re * cosW - im * sinW
                    im = im * cosW + re * sinW
                    re = nextRe
                    fast *= fastStep
                    slow *= slowStep
                }
            }
        }
        let gain = 0.32 * (0.45 + 0.55 * velocity)
        var result = output.map { Float($0 * gain) }
        applyEdges(&result, sampleRate: sampleRate, attack: 0.004, release: 0.08)
        return result
    }
}

/// Short fade-in and fade-out so notes never click.
func applyEdges(_ samples: inout [Float], sampleRate: Double, attack: Double, release: Double) {
    let attackCount = min(samples.count, Int(attack * sampleRate))
    for i in 0..<attackCount { samples[i] *= Float(i) / Float(max(attackCount, 1)) }
    let releaseCount = min(samples.count, Int(release * sampleRate))
    for i in 0..<releaseCount { samples[samples.count - 1 - i] *= Float(i) / Float(max(releaseCount, 1)) }
}
