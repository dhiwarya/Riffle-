import RiffleTheory

/// How one chord went.
public struct ChordAttempt: Equatable, Sendable {
    public enum Outcome: String, Sendable { case passed, timedOut, skipped }

    public let item: ChordItem
    public let outcome: Outcome
    /// Seconds on the clock (time on the reveal screen doesn't count).
    public let elapsed: Double
    public let strums: Int
    public let usedHint: Bool
    public let usedReveal: Bool
    /// Required tones missing and wrong tones heard in the last strum, for the results screen.
    public let missing: [PitchClass]
    public let extra: [PitchClass]

    public var passed: Bool { outcome == .passed }

    /// Plan §8.1: clean first strum under 10 s = Easy; pass in time = Good; pass after Hint or
    /// Show me how = Hard; fail or skip = Again.
    public var grade: QuizGrade {
        guard passed else { return .again }
        if usedHint || usedReveal { return .hard }
        return strums <= 1 && elapsed < 10 ? .easy : .good
    }
}

/// One round of "Play the chord": the list of chords, the current one, hints and outcomes.
/// Pure logic; the screen feeds it what the mic heard and the clock.
public struct ChordQuizSession: Sendable {
    public struct Settings: Equatable, Sendable {
        public var items: [ChordItem]
        public var level: Int
        /// Seconds per chord (plan §8.2: shrinks with mastery in M5). `nil` = no clock (free practice).
        public var timeLimit: Double?

        public init(items: [ChordItem], level: Int, timeLimit: Double? = 30) {
            self.items = items
            self.level = level
            self.timeLimit = timeLimit
        }
    }

    public let settings: Settings
    public private(set) var index = 0
    public private(set) var attempts: [ChordAttempt] = []
    public private(set) var usedHint = false
    public private(set) var usedReveal = false

    public init(settings: Settings) {
        self.settings = settings
    }

    public var current: ChordItem? { settings.items.indices.contains(index) ? settings.items[index] : nil }
    /// 1-based, for "Chord 1 of 3".
    public var number: Int { min(index + 1, settings.items.count) }
    public var total: Int { settings.items.count }
    /// The current chord has been decided (passed, timed out or skipped) and waits for `advance()`.
    public var isDecided: Bool { attempts.count > index }
    public var isFinished: Bool { index >= settings.items.count }
    public var score: Int { attempts.filter(\.passed).count }
    public var lastAttempt: ChordAttempt? { attempts.last }

    public mutating func useHint() { if !isDecided { usedHint = true } }
    public mutating func useReveal() { if !isDecided { usedReveal = true } }

    @discardableResult
    public mutating func pass(elapsed: Double, strums: Int) -> ChordAttempt? {
        decide(.passed, elapsed: elapsed, strums: strums, missing: [], extra: [])
    }

    @discardableResult
    public mutating func timeUp(strums: Int, missing: Set<PitchClass>, extra: Set<PitchClass>) -> ChordAttempt? {
        decide(.timedOut, elapsed: settings.timeLimit ?? 0, strums: strums, missing: missing, extra: extra)
    }

    @discardableResult
    public mutating func skip(elapsed: Double, strums: Int, missing: Set<PitchClass> = [], extra: Set<PitchClass> = []) -> ChordAttempt? {
        decide(.skipped, elapsed: elapsed, strums: strums, missing: missing, extra: extra)
    }

    /// Moves to the next chord. Returns false when the round is over.
    @discardableResult
    public mutating func advance() -> Bool {
        guard isDecided else { return !isFinished }
        index += 1
        usedHint = false
        usedReveal = false
        return !isFinished
    }

    private mutating func decide(_ outcome: ChordAttempt.Outcome, elapsed: Double, strums: Int,
                                 missing: Set<PitchClass>, extra: Set<PitchClass>) -> ChordAttempt? {
        guard let item = current, !isDecided else { return nil }
        let attempt = ChordAttempt(item: item, outcome: outcome, elapsed: elapsed, strums: strums,
                                   usedHint: usedHint, usedReveal: usedReveal,
                                   missing: missing.sorted(), extra: extra.sorted())
        attempts.append(attempt)
        return attempt
    }

    /// Chords that didn't pass, or passed only with help: what "Practise these" replays.
    public var practiseThese: [ChordItem] {
        attempts.filter { $0.grade.rawValue <= QuizGrade.hard.rawValue }.map(\.item)
    }
}
