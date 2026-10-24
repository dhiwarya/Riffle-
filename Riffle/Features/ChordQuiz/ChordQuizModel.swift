import Foundation
import Observation
import RiffleAudio
import RiffleQuiz
import RiffleTheory

/// Drives one "Play the chord" round: the mic and chord verifier, the per-chord clock, hints,
/// coaching and outcomes (mockup screen 3).
@MainActor
@Observable
final class ChordQuizModel {
    enum Availability: Equatable {
        case idle
        case listening
        case denied
        case failed(String)
    }

    enum Phase: Equatable {
        case playing
        /// Passed; the screen celebrates, then moves on.
        case passed(ChordAttempt)
        /// Time ran out; the player picks Show me how or Next.
        case timedOut(ChordAttempt)
    }

    let tuning: Tuning
    let a4: Double
    /// A "Practise these" round or a library pick: counts as free practice, not the daily set.
    let isFreePractice: Bool
    let startedAt = Date.now
    private(set) var session: ChordQuizSession
    private(set) var phase: Phase = .playing
    private(set) var availability: Availability = .idle
    private(set) var evidence = ChordEvidence()
    private(set) var levelDB = -160.0
    /// Coaching after a strum that didn't pass.
    private(set) var feedback: String?
    private(set) var hintOpen = false
    /// Seconds on the clock for the current chord.
    private(set) var elapsed = 0.0

    private let listener = LiveListener()
    private var coach: ChordCoach?
    private var clockStartedAt: Date?
    private var banked = 0.0
    private var ticker: Task<Void, Never>?
    private var advanceTask: Task<Void, Never>?
    private var finishedStrums = 0

    init(settings: ChordQuizSession.Settings, tuning: Tuning, a4: Double, isFreePractice: Bool = false) {
        session = ChordQuizSession(settings: settings)
        self.tuning = tuning
        self.a4 = a4
        self.isFreePractice = isFreePractice
    }

    var item: ChordItem? { session.current }
    var timeLimit: Double? { session.settings.timeLimit }
    var remaining: Double? { timeLimit.map { max(0, $0 - elapsed) } }
    var hint: String { coach?.hint ?? "" }
    var isListening: Bool { availability == .listening && phase == .playing }
    var durationSeconds: Int { Int(Date.now.timeIntervalSince(startedAt)) }

    /// Nothing loud enough after a while: tell them to come closer.
    var hearsNothing: Bool { phase == .playing && evidence.strums == 0 && elapsed > 8 && levelDB < -50 }

    // MARK: Lifecycle

    func start() async {
        guard availability != .listening else { return }
        guard await MicrophoneCapture.requestPermission() else {
            availability = .denied
            return
        }
        prepareChord()
        do {
            #if DEBUG
            if Self.isDemo {
                startDemo()
                availability = .listening
                startClock()
                return
            }
            #endif
            try listener.start(analysis: analysis) { [weak self] snapshot in
                Task { @MainActor in self?.handle(snapshot) }
            }
            availability = .listening
            startClock()
        } catch {
            availability = .failed(error.localizedDescription)
        }
    }

    func stop() {
        ticker?.cancel()
        advanceTask?.cancel()
        listener.stop()
        availability = .idle
    }

    private var analysis: LiveListener.Analysis {
        guard let item else { return .none }
        return .chord(item.chord, requiredBass: item.requiredBass)
    }

    private func prepareChord() {
        guard let item else { return }
        coach = ChordCoach(item: item, tuning: tuning)
        evidence = ChordEvidence()
        feedback = nil
        hintOpen = false
        finishedStrums = 0
        elapsed = 0
        banked = 0
        phase = .playing
    }

    // MARK: Clock

    private func startClock() {
        clockStartedAt = .now
        ticker?.cancel()
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100))
                self?.tick()
            }
        }
    }

    private func pauseClock() {
        if let start = clockStartedAt { banked += Date.now.timeIntervalSince(start) }
        clockStartedAt = nil
    }

    private func resumeClock() {
        if clockStartedAt == nil { clockStartedAt = .now }
    }

    private func tick() {
        guard phase == .playing, let start = clockStartedAt else { return }
        elapsed = banked + Date.now.timeIntervalSince(start)
        if let limit = timeLimit, elapsed >= limit { timeUp() }
    }

    // MARK: Listening

    private func handle(_ snapshot: LiveSnapshot) {
        guard availability == .listening else { return }
        levelDB = snapshot.levelDB
        guard phase == .playing, let chord = snapshot.chord else { return }
        evidence = chord
        if chord.verdict == .passed {
            pass()
        } else if chord.verdict == .failed, chord.strums != finishedStrums {
            finishedStrums = chord.strums
            feedback = coach?.feedback(missing: chord.missing, extra: chord.extra, bass: chord.bass)
        }
    }

    private func pass() {
        guard let attempt = session.pass(elapsed: elapsed, strums: max(evidence.strums, 1)) else { return }
        pauseClock()
        feedback = nil
        phase = .passed(attempt)
        listener.setAnalysis(.none)
    }

    private func timeUp() {
        guard let attempt = session.timeUp(strums: evidence.strums, missing: evidence.missing, extra: evidence.extra) else { return }
        pauseClock()
        elapsed = timeLimit ?? elapsed
        phase = .timedOut(attempt)
        listener.setAnalysis(.none)
        if feedback == nil, evidence.strums == 0 { feedback = ChordCoach.nothingHeard }
    }

    // MARK: Actions

    /// "Listen again": forget the last strum and start fresh on the same chord.
    func listenAgain() {
        guard phase == .playing else { return }
        evidence = ChordEvidence()
        feedback = nil
        finishedStrums = 0
        restartAnalysis()
    }

    func toggleHint() {
        hintOpen.toggle()
        if hintOpen { session.useHint() }
    }

    /// Show me how: the clock and the mic pause while the reveal screen is up, so its "Hear it"
    /// strum can't pass the chord.
    func openReveal() {
        session.useReveal()
        pauseClock()
        listener.setAnalysis(.none)
    }

    func closeReveal() {
        guard phase == .playing else { return }
        evidence = ChordEvidence()
        feedback = nil
        finishedStrums = 0
        resumeClock()
        // Let the reveal's strum die away before listening again.
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            self?.restartAnalysis()
        }
    }

    func skip() {
        session.skip(elapsed: elapsed, strums: evidence.strums, missing: evidence.missing, extra: evidence.extra)
    }

    /// Next chord. Returns false when the round is over.
    @discardableResult
    func next() -> Bool {
        advanceTask?.cancel()
        guard session.advance() else {
            stop()
            return false
        }
        prepareChord()
        restartAnalysis()
        startClock()
        return true
    }

    private func restartAnalysis() {
        #if DEBUG
        if Self.isDemo {
            startDemo()
            return
        }
        #endif
        listener.setAnalysis(analysis)
    }

    // MARK: Demo

    #if DEBUG
    static var isDemo: Bool { ProcessInfo.processInfo.arguments.contains("-chordDemo") }

    /// Launch with `-chordDemo` to drive the quiz with synthetic strums of the reference voicing
    /// instead of the mic: one strum with the 3rd's strings dead, then a clean strum.
    private func startDemo() {
        guard let item else { return }
        listener.stop()
        let sampleRate = 48_000.0
        let voicing = VoicingLibrary.reference(for: item.chord, in: tuning, inversion: item.inversion)
        let notes = voicing?.notes(in: tuning) ?? []
        let third = item.chord.tones.count > 1 ? item.chord.tones[1].note.pitchClass : nil
        let full = notes.compactMap { $0?.frequency(a4: a4) }
        let partial = notes.compactMap { note in note.flatMap { $0.pitchClass == third ? nil : $0.frequency(a4: a4) } }
        let first = GuitarSynth.strum(partial, duration: 9, sampleRate: sampleRate, startAt: 1.0)
        let second = GuitarSynth.strum(full, duration: 9, sampleRate: sampleRate, startAt: 5.5)
        let clip = AudioClip(samples: GuitarSynth.mix(first, second) + [Float](repeating: 0, count: Int(sampleRate * 6)),
                             sampleRate: sampleRate)
        listener.startSimulated(clip, analysis: analysis) { [weak self] snapshot in
            Task { @MainActor in self?.handle(snapshot) }
        }
    }
    #endif
}
