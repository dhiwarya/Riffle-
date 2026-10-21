import RiffleTheory

/// Ear-check difficulty (plan §7.4).
public enum EarLevel: String, CaseIterable, Sendable {
    /// One major key, starts with 1-3-5 and grows to all 7 degrees, cadence before every question.
    case easy
    /// All 7 degrees, any major or minor key, two octaves, cadence every 5 questions.
    case medium
    /// All 12 degrees inside the key, two octaves, cadence once per session.
    case hard
}

/// What sets the key before a question (D2).
public enum KeyContext: String, CaseIterable, Sendable {
    case cadence, tonic, none
}

/// Automatic grade for an answer; raw values match `RiffleStore.Grade`.
public enum QuizGrade: Int, Sendable {
    case again = 1, hard, good, easy
}

public struct EarQuestion: Equatable, Sendable {
    /// 1-based.
    public let number: Int
    public let degree: ScaleDegree
    public let midi: Int
    /// Play the key context (cadence or tonic) before the note.
    public let playsKeyContext: Bool
}

public struct EarAnswer: Equatable, Sendable {
    public let question: EarQuestion
    public let picked: ScaleDegree
    public let replaysUsed: Int
    public let responseTime: Double

    public var isCorrect: Bool { picked.interval == question.degree.interval }

    public var grade: QuizGrade {
        guard isCorrect else { return .again }
        return replaysUsed == 0 && responseTime < 3 ? .easy : .good
    }
}

/// One ear-check session: picks questions, grows the pool on a staircase, tracks replays,
/// score and confusions. Pure logic; the screen plays the audio.
public final class EarSession {
    public struct Settings: Equatable, Sendable {
        public var level: EarLevel
        public var key: Key
        public var questionCount: Int
        public var context: KeyContext
        /// Restrict questions to these degrees ("Practise these" after a session).
        public var focus: [Interval]?

        public init(level: EarLevel, key: Key, questionCount: Int = 10, context: KeyContext = .cadence, focus: [Interval]? = nil) {
            self.level = level
            self.key = key
            self.questionCount = questionCount
            self.context = context
            self.focus = focus
        }
    }

    public static let replaysPerQuestion = 3
    /// Easy starts with these degree numbers and adds the rest in this order.
    static let easyStart = [1, 3, 5]
    static let easyGrowth = [4, 2, 6, 7]

    public let settings: Settings
    /// Every degree the level can ask (the answer pads when the pool is full).
    public let allDegrees: [ScaleDegree]
    /// Degrees currently in play: the answer pads.
    public private(set) var pool: [ScaleDegree]
    public private(set) var question: EarQuestion?
    public private(set) var answers: [EarAnswer] = []
    public private(set) var replaysLeft = EarSession.replaysPerQuestion
    /// The degree added most recently by the staircase, for a "new note" hint.
    public private(set) var newlyAdded: ScaleDegree?

    private var random: SeededRandom
    private var correctStreak = 0
    private let tonicMidi: Int

    public init(settings: Settings, seed: UInt64) {
        self.settings = settings
        random = SeededRandom(seed: seed)
        let scale = settings.level == .hard ? settings.key.chromaticScale : settings.key.scale
        allDegrees = scale.degrees

        if let focus = settings.focus, !focus.isEmpty {
            var focused = allDegrees.filter { focus.contains($0.interval) }
            if focused.count < 2, let tonic = allDegrees.first, !focused.contains(tonic) { focused.insert(tonic, at: 0) }
            pool = focused
        } else if settings.level == .easy {
            pool = allDegrees.filter { Self.easyStart.contains($0.interval.number) }
        } else {
            pool = allDegrees
        }

        // Easy stays in one octave around G3–F♯4; the others start an octave lower and span two.
        let low = settings.level == .easy ? 55 : 48
        tonicMidi = low + settings.key.tonic.pitchClass.semitones(above: PitchClass(low))
        question = makeQuestion(number: 1)
    }

    public var score: Int { answers.filter(\.isCorrect).count }
    public var isFinished: Bool { question == nil }
    public var questionNumber: Int { question?.number ?? settings.questionCount }

    /// The current question has been answered and is waiting for "Next".
    public var awaitingNext: Bool {
        guard let question else { return false }
        return answers.last?.question.number == question.number
    }

    /// Spends a replay. Returns false when none are left.
    public func useReplay() -> Bool {
        guard replaysLeft > 0, !awaitingNext else { return false }
        replaysLeft -= 1
        return true
    }

    /// Records the answer to the current question (one answer per question).
    @discardableResult
    public func answer(_ picked: ScaleDegree, responseTime: Double) -> EarAnswer? {
        guard let question, !awaitingNext else { return nil }
        let answer = EarAnswer(question: question, picked: picked,
                               replaysUsed: Self.replaysPerQuestion - replaysLeft, responseTime: responseTime)
        answers.append(answer)
        if answer.isCorrect {
            correctStreak += 1
            if correctStreak >= 2 { growPool() }
        } else {
            correctStreak = 0
        }
        return answer
    }

    /// Moves to the next question; nil when the session is over.
    @discardableResult
    public func advance() -> EarQuestion? {
        guard let current = question, awaitingNext else { return question }
        newlyAdded = nil
        question = current.number < settings.questionCount ? makeQuestion(number: current.number + 1) : nil
        replaysLeft = Self.replaysPerQuestion
        return question
    }

    // MARK: Building questions

    private func growPool() {
        guard settings.level == .easy, settings.focus == nil else { return }
        let next = Self.easyGrowth.lazy.compactMap { number in
            self.allDegrees.first { $0.interval.number == number && !self.pool.contains($0) }
        }.first
        guard let next else { return }
        pool.append(next)
        pool.sort { $0.interval.semitones < $1.interval.semitones }
        newlyAdded = next
        correctStreak = 0
    }

    private func makeQuestion(number: Int) -> EarQuestion {
        let previous = answers.last?.question.degree
        let missed = Set(answers.filter { !$0.isCorrect }.map(\.question.degree.interval))
        let candidates = pool.filter { $0 != previous || pool.count == 1 }
        let weighted = candidates.map { degree -> (ScaleDegree, Double) in
            var weight = 1.0
            if missed.contains(degree.interval) { weight += 1.5 }
            if degree == newlyAdded { weight += 1 }
            return (degree, weight)
        }
        let degree = random.weightedPick(weighted) ?? pool[0]
        var midi = tonicMidi + degree.interval.semitones
        if settings.level != .easy, Bool.random(using: &random) { midi += 12 }
        return EarQuestion(number: number, degree: degree, midi: midi, playsKeyContext: playsContext(number))
    }

    private func playsContext(_ number: Int) -> Bool {
        guard settings.context != .none else { return false }
        switch settings.level {
        case .easy: return true
        case .medium: return (number - 1) % 5 == 0
        case .hard: return number == 1
        }
    }

    /// The tonic in the register the questions use, for "Replay key" in tonic mode.
    public var tonicNote: Int { tonicMidi }
}

// MARK: - Results

public struct EarSummary: Equatable, Sendable {
    public struct DegreeResult: Equatable, Sendable {
        public let degree: ScaleDegree
        public let correct: Int
        public let total: Int
    }

    public struct Confusion: Equatable, Sendable {
        public let target: ScaleDegree
        public let picked: ScaleDegree
        public let count: Int
    }

    public let score: Int
    public let total: Int
    public let perDegree: [DegreeResult]
    /// Most frequent mix-ups first.
    public let confusions: [Confusion]

    /// Degrees worth a focused follow-up: anything missed, plus what it was confused with.
    public var practiseThese: [Interval] {
        var intervals: [Interval] = []
        for confusion in confusions {
            for interval in [confusion.target.interval, confusion.picked.interval] where !intervals.contains(interval) {
                intervals.append(interval)
            }
        }
        return intervals
    }
}

extension EarSession {
    public var summary: EarSummary {
        let perDegree = allDegrees.compactMap { degree -> EarSummary.DegreeResult? in
            let asked = answers.filter { $0.question.degree == degree }
            guard !asked.isEmpty else { return nil }
            return .init(degree: degree, correct: asked.filter(\.isCorrect).count, total: asked.count)
        }
        var counts: [String: (ScaleDegree, ScaleDegree, Int)] = [:]
        for answer in answers where !answer.isCorrect {
            let key = answer.question.degree.label + ">" + answer.picked.label
            let existing = counts[key]?.2 ?? 0
            counts[key] = (answer.question.degree, answer.picked, existing + 1)
        }
        let confusions = counts.values
            .map { EarSummary.Confusion(target: $0.0, picked: $0.1, count: $0.2) }
            .sorted { $0.count != $1.count ? $0.count > $1.count : $0.target.interval.semitones < $1.target.interval.semitones }
        return EarSummary(score: score, total: answers.count, perDegree: perDegree, confusions: confusions)
    }

    /// Stable key for the skill model (plan §7.6), e.g. "degree:♭3|mode:minor|ctx:cadence".
    public static func itemKey(degree: ScaleDegree, mode: Key.Mode, context: KeyContext) -> String {
        "degree:\(degree.label)|mode:\(mode.rawValue)|ctx:\(context.rawValue)"
    }
}

/// How answer pads label a degree (D2): degree number, note name, or movable-do solfège.
public enum DegreeNaming: String, CaseIterable, Sendable {
    case degrees, noteNames, solfege

    private static let solfegeSyllables: [String: String] = [
        "1": "do", "♭2": "ra", "2": "re", "♭3": "me", "3": "mi", "4": "fa", "♯4": "fi",
        "5": "sol", "♭6": "le", "6": "la", "♭7": "te", "7": "ti",
    ]

    /// Big label and small label for a pad.
    public func labels(for degree: ScaleDegree) -> (primary: String, secondary: String) {
        switch self {
        case .degrees: (degree.label, degree.note.description)
        case .noteNames: (degree.note.description, degree.label)
        case .solfege: (Self.solfegeSyllables[degree.label] ?? degree.label, degree.note.description)
        }
    }
}
