/// SplitMix64: small, fast, deterministic. Seeded sessions give reproducible tests now and a
/// stable "today's set" in M5 (seeded with date + install ID).
public struct SeededRandom: RandomNumberGenerator, Sendable {
    private var state: UInt64

    public init(seed: UInt64) { state = seed }

    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// Picks an element with probability proportional to its weight.
    public mutating func weightedPick<T>(_ items: [(T, Double)]) -> T? {
        let total = items.reduce(0) { $0 + max($1.1, 0) }
        guard total > 0 else { return items.first?.0 }
        var target = Double.random(in: 0..<total, using: &self)
        for (item, weight) in items {
            target -= max(weight, 0)
            if target < 0 { return item }
        }
        return items.last?.0
    }
}
