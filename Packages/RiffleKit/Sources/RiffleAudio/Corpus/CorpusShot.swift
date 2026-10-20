import RiffleTheory

/// One clip to record for the detection test corpus. The same list drives the in-app recorder,
/// the corpus tests and `Corpus/SHOTLIST.md`.
public struct CorpusShot: Identifiable, Hashable, Sendable {
    public enum Group: String, CaseIterable, Sendable {
        case chords, mistakes, noise, environment, tuner

        public var title: String {
            switch self {
            case .chords: "Chords"
            case .mistakes: "Mistakes on purpose"
            case .noise: "Noise and non-chords"
            case .environment: "Distance and background noise"
            case .tuner: "Single strings (tuner)"
            }
        }

        public var setup: String {
            switch self {
            case .chords:
                "Guitar in tune. Phone in its normal spot. Strum once, downwards, and let the chord ring until the timer ends."
            case .mistakes:
                "Guitar in tune. Play each chord wrong in exactly the way described, strum once and let it ring."
            case .noise:
                "No proper chord in these. Follow each instruction exactly."
            case .environment:
                "Same chords and strings as before, in worse conditions: phone farther away, or with background noise."
            case .tuner:
                "Use your reference tuner to set each string to the exact offset shown, then pick that string once and let it ring. Re-tune to pitch at the end."
            }
        }
    }

    public enum Expectation: Hashable, Sendable {
        /// A single note. `cents` is the offset from the equal-tempered note; `tolerance` in cents.
        case pitch(midi: Int, cents: Double, tolerance: Double)
        /// A strummed chord. `target` is what the quiz would ask for; `frets` low → high, nil = muted.
        case chord(target: String, frets: [Int?], shouldPass: Bool, missing: [String] = [], extra: [String] = [])
        /// Nothing in this clip should pass any chord check.
        case noChord
        /// Recorded for exploring and tuning; no pass/fail assertion.
        case explore(target: String?)
    }

    public let id: String
    public let group: Group
    public let title: String
    public let instruction: String
    public let seconds: Double
    public let expectation: Expectation

    public init(id: String, group: Group, title: String, instruction: String, seconds: Double, expectation: Expectation) {
        self.id = id
        self.group = group
        self.title = title
        self.instruction = instruction
        self.seconds = seconds
        self.expectation = expectation
    }

    /// The chord a shot is about, if any (for live verification while recording).
    public var targetChord: Chord? {
        switch expectation {
        case .chord(let target, _, _, _, _): Chord(symbol: target)
        case .explore(let target): target.flatMap(Chord.init(symbol:))
        case .pitch, .noChord: nil
        }
    }

    /// File name inside the corpus folder.
    public var fileName: String { "\(id).wav" }
}
