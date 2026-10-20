import Foundation

/// Second-order IIR filter (RBJ cookbook), transposed direct form II.
struct Biquad {
    private var b0, b1, b2, a1, a2: Double
    private var z1 = 0.0, z2 = 0.0

    /// Butterworth high-pass, used to drop rumble and handling noise below the guitar's range.
    static func highPass(cutoff: Double, sampleRate: Double, q: Double = 0.70710678) -> Biquad {
        let w0 = 2 * Double.pi * cutoff / sampleRate
        let alpha = sin(w0) / (2 * q)
        let cosw = cos(w0)
        let a0 = 1 + alpha
        return Biquad(b0: (1 + cosw) / 2 / a0, b1: -(1 + cosw) / a0, b2: (1 + cosw) / 2 / a0,
                      a1: -2 * cosw / a0, a2: (1 - alpha) / a0)
    }

    private init(b0: Double, b1: Double, b2: Double, a1: Double, a2: Double) {
        self.b0 = b0
        self.b1 = b1
        self.b2 = b2
        self.a1 = a1
        self.a2 = a2
    }

    mutating func process(_ samples: inout [Float]) {
        for i in samples.indices {
            let x = Double(samples[i])
            let y = b0 * x + z1
            z1 = b1 * x - a1 * y + z2
            z2 = b2 * x - a2 * y
            samples[i] = Float(y)
        }
    }

    mutating func reset() {
        z1 = 0
        z2 = 0
    }
}
