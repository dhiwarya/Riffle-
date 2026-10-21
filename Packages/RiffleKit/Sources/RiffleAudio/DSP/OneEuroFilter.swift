import Foundation

/// One-Euro filter (Casiez et al. 2012): heavy smoothing when the value is steady, little lag when it
/// moves. Keeps the tuner needle calm on a held note but quick while a peg is turned (plan §5.2 step 7).
public struct OneEuroFilter: Sendable {
    public var minCutoff: Double
    public var beta: Double
    public var derivativeCutoff: Double

    private var value: Double?
    private var derivative = 0.0
    private var lastTime: Double?

    public init(minCutoff: Double = 1.2, beta: Double = 0.05, derivativeCutoff: Double = 1.0) {
        self.minCutoff = minCutoff
        self.beta = beta
        self.derivativeCutoff = derivativeCutoff
    }

    public mutating func filter(_ input: Double, at time: Double) -> Double {
        guard let previous = value, let last = lastTime else {
            value = input
            lastTime = time
            return input
        }
        let dt = max(time - last, 1e-3)
        lastTime = time
        let rawDerivative = (input - previous) / dt
        derivative += Self.alpha(cutoff: derivativeCutoff, dt: dt) * (rawDerivative - derivative)
        let cutoff = minCutoff + beta * abs(derivative)
        let smoothed = previous + Self.alpha(cutoff: cutoff, dt: dt) * (input - previous)
        value = smoothed
        return smoothed
    }

    public mutating func reset() {
        value = nil
        derivative = 0
        lastTime = nil
    }

    private static func alpha(cutoff: Double, dt: Double) -> Double {
        let tau = 1 / (2 * Double.pi * cutoff)
        return 1 / (1 + tau / dt)
    }
}
