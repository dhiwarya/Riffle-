import Foundation

/// Additive plucked-string tones with known pitch, for tests and as a fallback sound source.
/// Models what makes guitar detection hard: rich harmonics, weak fundamentals through a phone mic,
/// slight inharmonicity and strings that don't start together in a strum.
public enum GuitarSynth {
    public struct Pluck: Sendable {
        public var frequency: Double
        public var amplitude = 0.3
        /// Where the string is plucked, as a fraction of its length; sets the harmonic shape.
        public var pluckPosition = 0.18
        /// Stretches upper partials sharp: f_h = h·f0·√(1 + B·h²).
        public var inharmonicity = 0.0
        public var harmonics = 12
        /// Seconds for the fundamental to fall by 1/e.
        public var decay = 1.6
        /// Simulates a small mic: 12 dB/octave roll-off below this frequency.
        public var lowCut: Double? = 120
        /// Overrides for specific partial amplitudes (relative), e.g. [5: 0.5] for a loud 5th harmonic.
        public var partialOverrides: [Int: Double] = [:]

        public init(frequency: Double) { self.frequency = frequency }
    }

    public static func render(_ pluck: Pluck, duration: Double, sampleRate: Double, startAt: Double = 0,
                              into output: inout [Float]) {
        let total = Int(duration * sampleRate)
        if output.count < total { output += [Float](repeating: 0, count: total - output.count) }
        let start = Int(startAt * sampleRate)
        guard start < total else { return }

        for h in 1...pluck.harmonics {
            let frequency = Double(h) * pluck.frequency * (1 + pluck.inharmonicity * Double(h * h)).squareRoot()
            guard frequency < sampleRate / 2 - 500 else { break }
            var amplitude = pluck.partialOverrides[h] ?? abs(sin(Double.pi * Double(h) * pluck.pluckPosition)) / Double(h)
            if let cut = pluck.lowCut, frequency < cut { amplitude *= pow(frequency / cut, 2) }
            amplitude *= pluck.amplitude
            let decayRate = (1 + 0.35 * Double(h - 1)) / pluck.decay
            let phaseStep = 2 * Double.pi * frequency / sampleRate
            var phase = Double(h) * 0.7
            for i in start..<total {
                let t = Double(i - start) / sampleRate
                let attack = min(t / 0.003, 1)
                output[i] += Float(amplitude * attack * exp(-decayRate * t) * sin(phase))
                phase += phaseStep
            }
        }
    }

    public static func tone(_ pluck: Pluck, duration: Double, sampleRate: Double, startAt: Double = 0) -> [Float] {
        var output: [Float] = []
        render(pluck, duration: duration, sampleRate: sampleRate, startAt: startAt, into: &output)
        return output
    }

    /// A downstrum: strings start `spacing` seconds apart, low to high.
    public static func strum(_ frequencies: [Double], duration: Double, sampleRate: Double, startAt: Double = 0.3,
                             spacing: Double = 0.02, configure: (inout Pluck) -> Void = { _ in }) -> [Float] {
        var output = [Float](repeating: 0, count: Int(duration * sampleRate))
        for (index, frequency) in frequencies.enumerated() {
            var pluck = Pluck(frequency: frequency)
            pluck.amplitude = 0.18
            configure(&pluck)
            render(pluck, duration: duration, sampleRate: sampleRate, startAt: startAt + Double(index) * spacing, into: &output)
        }
        return output
    }

    /// Deterministic white noise at `levelDB` RMS.
    public static func noise(levelDB: Double, duration: Double, sampleRate: Double, seed: UInt64 = 7) -> [Float] {
        var state = seed
        let rms = pow(10, levelDB / 20)
        let scale = rms * 3.0.squareRoot() // uniform(-1, 1) has RMS 1/√3
        return (0..<Int(duration * sampleRate)).map { _ in
            state = state &* 6364136223846793005 &+ 1442695040888963407
            let unit = Double(state >> 11) / Double(1 << 53) * 2 - 1
            return Float(unit * scale)
        }
    }

    public static func mix(_ a: [Float], _ b: [Float]) -> [Float] {
        let count = max(a.count, b.count)
        return (0..<count).map { (($0 < a.count) ? a[$0] : 0) + (($0 < b.count) ? b[$0] : 0) }
    }
}
