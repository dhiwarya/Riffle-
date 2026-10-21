import Foundation
import Observation
import RiffleAudio
import RiffleQuiz
import RiffleTheory

/// Drives one ear-check session: plays key context and notes, takes answers, keeps the
/// feedback state the screen shows.
@MainActor
@Observable
final class EarCheckModel {
    enum Feedback: Equatable {
        case waiting
        case right(EarAnswer)
        case wrong(EarAnswer)
    }

    let settings: EarSession.Settings
    /// A "Practise these" follow-up counts as free practice, not the daily set.
    let isFreePractice: Bool
    let startedAt = Date.now
    private(set) var session: EarSession
    private(set) var feedback: Feedback = .waiting
    private(set) var isPlaying = false
    private(set) var scoreBumps = 0
    private(set) var hasHeardQuestion = false
    var instrument: Instrument {
        didSet { prepareAudio() }
    }

    private let tones = ToneEngine()
    private var targetStartedAt: Date?
    private var playingUntil: Task<Void, Never>?

    init(settings: EarSession.Settings, seed: UInt64, instrument: Instrument, isFreePractice: Bool = false) {
        self.settings = settings
        self.instrument = instrument
        self.isFreePractice = isFreePractice
        session = EarSession(settings: settings, seed: seed)
    }

    var question: EarQuestion? { session.question }
    var isAnswered: Bool { session.awaitingNext }

    // MARK: Sound

    private var chordStyle: Phrase.ChordStyle { instrument == .guitar ? .strum : .block }

    private var keyContext: Phrase {
        switch settings.context {
        case .cadence: .cadence(settings.key, style: chordStyle)
        case .tonic, .none: .note(session.tonicNote, duration: 1.0)
        }
    }

    /// Plays the question: key context first when scheduled (or asked for), then the note.
    /// The first play of a question is free; later ones spend a replay until it's answered.
    func play() {
        guard let question else { return }
        if hasHeardQuestion && !isAnswered && !session.useReplay() { return }
        let withContext = !hasHeardQuestion && question.playsKeyContext
        let target = Phrase.note(question.midi)
        let phrase = withContext ? keyContext.then(target, gap: 0.45) : target
        start(phrase)
        targetStartedAt = Date.now.addingTimeInterval(phrase.duration - target.duration)
        hasHeardQuestion = true
    }

    /// "Replay key": the cadence (or tonic) on its own. Free.
    func replayKey() {
        start(keyContext)
    }

    /// After a miss: the note you picked, then the right one.
    func hearBoth() {
        guard case .wrong(let answer) = feedback else { return }
        let base = answer.question.midi - answer.question.degree.interval.semitones
        let picked = Phrase.note(base + answer.picked.interval.semitones, duration: 1.2)
        start(picked.then(.note(answer.question.midi, duration: 1.4), gap: 0.25))
    }

    private func start(_ phrase: Phrase) {
        let length = tones.play(phrase, instrument: instrument)
        isPlaying = true
        playingUntil?.cancel()
        playingUntil = Task { [weak self] in
            try? await Task.sleep(for: .seconds(length))
            if !Task.isCancelled { self?.isPlaying = false }
        }
    }

    /// Pre-renders the cadence and every answer note. Called when the screen appears, not in init,
    /// because SwiftUI may create (and discard) the model more than once.
    func prepareAudio() {
        var phrases = [keyContext]
        phrases += session.allDegrees.map { .note(session.tonicNote + $0.interval.semitones) }
        tones.prepare(phrases, instrument: instrument)
    }

    func stopAudio() { tones.stop() }

    // MARK: Answers

    func pick(_ degree: ScaleDegree) {
        guard hasHeardQuestion, !isAnswered else { return }
        let responseTime = targetStartedAt.map { max(0, Date.now.timeIntervalSince($0)) } ?? 0
        guard let answer = session.answer(degree, responseTime: responseTime) else { return }
        feedback = answer.isCorrect ? .right(answer) : .wrong(answer)
        if answer.isCorrect { scoreBumps += 1 }
        // Hear what you picked on a miss; the right note confirms a hit.
        let midi = answer.question.midi - answer.question.degree.interval.semitones + degree.interval.semitones
        start(.note(midi, duration: 1.0))
    }

    /// Next question, playing it straight away. Returns false when the session is over.
    @discardableResult
    func next() -> Bool {
        guard isAnswered else { return true }
        session.advance()
        feedback = .waiting
        hasHeardQuestion = false
        guard session.question != nil else { return false }
        play()
        return true
    }

    var durationSeconds: Int { Int(Date.now.timeIntervalSince(startedAt)) }
}
