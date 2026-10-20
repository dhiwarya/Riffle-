import Foundation

/// One pitch estimate from a single analysis window.
public struct PitchEstimate: Equatable, Sendable {
    public let frequency: Double
    /// Height of the NSDF peak, 0…1. Above ~0.9 is a clean, periodic tone.
    public let clarity: Double
    public let levelDB: Double
}

/// Monophonic pitch detection with the McLeod Pitch Method (NSDF + key maxima + parabolic interpolation).
/// Plan §5.2 steps 2–4: 4096-sample window, works down to drop tunings.
public final class PitchDetector {
    public struct Configuration: Sendable {
        public var windowSize = 4096
        public var minFrequency = 55.0
        public var maxFrequency = 1500.0
        /// First key maximum at or above this fraction of the highest one wins (MPM's k).
        public var keyMaximumRatio = 0.9
        /// Below this level the window counts as silence.
        public var silenceDB = -60.0
        /// Lag (samples) used to refine short periods; must stay under half the window.
        public var refinementLag = 1536

        public init() {}
    }

    public let sampleRate: Double
    public let configuration: Configuration
    private let fft: RealFFT
    private var acf: [Float] = []
    private var nsdf: [Float]

    public init(sampleRate: Double, configuration: Configuration = Configuration()) {
        self.sampleRate = sampleRate
        self.configuration = configuration
        fft = RealFFT(size: configuration.windowSize * 2)
        nsdf = [Float](repeating: 0, count: configuration.windowSize)
    }

    public var windowSize: Int { configuration.windowSize }

    /// Estimates the pitch of `window` (should be `windowSize` samples). Nil for silence or no periodicity.
    public func estimate(_ window: UnsafeBufferPointer<Float>) -> PitchEstimate? {
        let count = window.count
        guard count >= 64 else { return nil }
        let level = rmsDecibels(window)
        guard level > configuration.silenceDB else { return nil }

        fft.autocorrelation(of: window, into: &acf)

        // NSDF: n(τ) = 2·r(τ) / m(τ), with m(τ) = Σ (x[j]² + x[j+τ]²) updated incrementally.
        // Computed past the search range so the refinement step can look at later periods.
        let maxTau = min(Int(ceil(sampleRate / configuration.minFrequency)) + 2, count - 2)
        let nsdfEnd = min(max(maxTau, configuration.refinementLag + 4), count / 2)
        var m = Double(2 * acf[0])
        for tau in 0...nsdfEnd {
            if tau > 0 {
                let a = Double(window[tau - 1]), b = Double(window[count - tau])
                m -= a * a + b * b
            }
            nsdf[tau] = m > 1e-12 ? Float(2 * Double(acf[tau]) / m) : 0
        }

        // Key maxima: the highest point of each positive lobe after the first negative-going zero crossing.
        var keyMaxima: [(tau: Int, value: Float)] = []
        var tau = 1
        while tau < maxTau && nsdf[tau] > 0 { tau += 1 }
        var lobeBest: (tau: Int, value: Float)? = nil
        while tau < maxTau {
            if nsdf[tau] > 0 {
                if nsdf[tau] > nsdf[tau - 1] && nsdf[tau] >= nsdf[tau + 1] && nsdf[tau] > (lobeBest?.value ?? 0) {
                    lobeBest = (tau, nsdf[tau])
                }
            } else if let best = lobeBest {
                keyMaxima.append(best)
                lobeBest = nil
            }
            tau += 1
        }
        if let best = lobeBest { keyMaxima.append(best) }

        guard let highest = keyMaxima.map(\.value).max(), highest > 0 else { return nil }
        let minTau = sampleRate / configuration.maxFrequency
        guard let chosen = keyMaxima.first(where: { $0.value >= Float(configuration.keyMaximumRatio) * highest && Double($0.tau) >= minTau - 1 })
        else { return nil }

        let (basePeriod, peak) = interpolatedPeak(at: chosen.tau)
        let period = refine(period: basePeriod, limit: nsdfEnd)
        let frequency = sampleRate / period
        guard frequency >= configuration.minFrequency * 0.97, frequency <= configuration.maxFrequency * 1.03 else { return nil }
        return PitchEstimate(frequency: frequency, clarity: min(peak, 1), levelDB: level)
    }

    /// Parabolic interpolation of the NSDF peak at `tau`: (sub-sample lag, peak height).
    private func interpolatedPeak(at tau: Int) -> (Double, Double) {
        let a = Double(nsdf[tau - 1]), b = Double(nsdf[tau]), c = Double(nsdf[tau + 1])
        let denominator = a - 2 * b + c
        let shift = denominator != 0 ? 0.5 * (a - c) / denominator : 0
        return (Double(tau) + shift, b - 0.25 * (a - c) * shift)
    }

    /// Short periods (high notes) are only a few dozen samples, so interpolation error is large relative
    /// to the period. Re-measure at the k-th repeat of the period and divide by k.
    private func refine(period: Double, limit: Int) -> Double {
        let k = Int(Double(configuration.refinementLag) / period)
        guard k >= 2 else { return period }
        let expected = Int((period * Double(k)).rounded())
        let reach = 4 // stays well inside one period, since refinement only runs for periods ≤ refinementLag / 2
        guard expected + reach + 1 < limit else { return period }
        var best = expected
        for tau in (expected - reach)...(expected + reach) where nsdf[tau] > nsdf[best] { best = tau }
        guard best > expected - reach, best < expected + reach, nsdf[best] > 0.5 else { return period }
        let (lag, _) = interpolatedPeak(at: best)
        return lag / Double(k)
    }

    public func estimate(_ window: [Float]) -> PitchEstimate? {
        window.withUnsafeBufferPointer { estimate($0) }
    }
}
