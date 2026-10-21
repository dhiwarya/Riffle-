import Foundation
import RiffleTheory

/// Everything the tuner screen shows.
public struct TunerState: Equatable, Sendable {
    /// String index, 0 = string 6 (low).
    public var selectedString = 0
    /// Smoothed offset from the selected string's target, nil when nothing is ringing.
    public var cents: Double?
    /// Measured frequency, folded to the target's octave.
    public var frequency: Double?
    public var isInTune = false
    public var tuned: Set<Int> = []
    /// Increments each time a string newly reaches "in tune" (drives the haptic).
    public var tunedEvents = 0

    public init(selectedString: Int = 0) {
        self.selectedString = selectedString
    }

    public var hasSignal: Bool { cents != nil }
    public var allTuned: Bool { tuned.count == Tuning.stringCount }
}

/// Tuner logic on top of the pitch tracker (plan §5.3): auto string detection with hysteresis,
/// manual string lock, octave-error folding, in-tune hold, and auto-advance to the next string.
public final class TunerEngine {
    public enum Mode: String, Sendable, CaseIterable { case auto, manual }

    public struct Configuration: Sendable {
        /// In tune within this many cents…
        public var inTuneCents = 3.0
        /// …held for this long.
        public var inTuneHold = 0.4
        /// Leaves "in tune" only beyond this, so the badge doesn't flicker at the edge.
        public var outOfTuneCents = 4.5
        /// Auto mode switches strings only after another string has been nearest this long.
        public var switchHold = 0.15
        /// No reading for this long means the string stopped ringing.
        public var signalTimeout = 0.35
        /// Auto-mode penalty (cents) for explaining a reading as the detector jumping an octave up,
        /// its usual slip on low strings with a weak fundamental…
        public var octaveUpPenalty = 30.0
        /// …and the rarer slip an octave down.
        public var octaveDownPenalty = 60.0

        public init() {}
    }

    public private(set) var state = TunerState()
    public let configuration: Configuration

    public var tuning: Tuning { didSet { if tuning != oldValue { resetProgress() } } }
    public var a4: Double { didSet { if a4 != oldValue { resetProgress() } } }
    public var mode: Mode

    private var filter = OneEuroFilter()
    private var lastReadingTime: Double?
    private var inTuneSince: Double?
    private var candidate: (index: Int, since: Double)?

    public init(tuning: Tuning = .standard, a4: Double = 440, mode: Mode = .auto, configuration: Configuration = Configuration()) {
        self.tuning = tuning
        self.a4 = a4
        self.mode = mode
        self.configuration = configuration
    }

    /// The user tapped a peg.
    public func select(string index: Int) {
        guard (0..<Tuning.stringCount).contains(index) else { return }
        switchString(to: index)
    }

    /// Forgets the current signal but keeps tuned strings, e.g. when the microphone restarts
    /// (the stream clock starts again at zero).
    public func clearSignal() {
        state.cents = nil
        state.frequency = nil
        state.isInTune = false
        inTuneSince = nil
        candidate = nil
        filter.reset()
        lastReadingTime = nil
    }

    public func resetProgress() {
        state = TunerState(selectedString: state.selectedString)
        filter.reset()
        inTuneSince = nil
        candidate = nil
        lastReadingTime = nil
    }

    /// Feeds one pitch reading (time is stream time in seconds).
    @discardableResult
    public func process(_ reading: PitchReading) -> TunerState {
        let time = reading.time
        if let last = lastReadingTime, time - last > configuration.signalTimeout { filter.reset() }
        lastReadingTime = time

        if mode == .auto {
            let nearest = nearestString(to: reading.frequency)
            if nearest.index == state.selectedString {
                candidate = nil
            } else if state.cents == nil {
                // A fresh pluck: follow it straight away.
                switchString(to: nearest.index)
            } else if let current = candidate, current.index == nearest.index, time - current.since >= configuration.switchHold {
                switchString(to: nearest.index)
            } else {
                // A different string while one is ringing: wait for it to persist, keep the display as is.
                if candidate?.index != nearest.index { candidate = (nearest.index, time) }
                return state
            }
        }

        let (rawCents, folded) = centsToSelected(reading.frequency)
        let cents = filter.filter(rawCents, at: time)
        state.cents = cents
        state.frequency = folded
        updateInTune(cents: cents, time: time)
        return state
    }

    /// Advances time without a reading: clears the signal after a timeout and, in auto mode,
    /// moves on to the next untuned string once a tuned one stops ringing.
    @discardableResult
    public func tick(time: Double) -> TunerState {
        guard let last = lastReadingTime, time - last > configuration.signalTimeout, state.cents != nil else { return state }
        state.cents = nil
        state.frequency = nil
        state.isInTune = false
        inTuneSince = nil
        candidate = nil
        filter.reset()
        if mode == .auto, state.tuned.contains(state.selectedString), let next = nextUntunedString() {
            state.selectedString = next
        }
        return state
    }

    // MARK: Helpers

    private func switchString(to index: Int) {
        state.selectedString = index
        state.cents = nil
        state.frequency = nil
        state.isInTune = false
        inTuneSince = nil
        candidate = nil
        filter.reset()
    }

    private func updateInTune(cents: Double, time: Double) {
        if state.isInTune {
            if abs(cents) > configuration.outOfTuneCents {
                state.isInTune = false
                inTuneSince = nil
            }
            return
        }
        guard abs(cents) <= configuration.inTuneCents else {
            inTuneSince = nil
            return
        }
        let since = inTuneSince ?? time
        inTuneSince = since
        if time - since >= configuration.inTuneHold {
            state.isInTune = true
            if !state.tuned.contains(state.selectedString) {
                state.tuned.insert(state.selectedString)
                state.tunedEvents += 1
            }
        }
    }

    /// Nearest open string, allowing for a reading an octave off (with a penalty, so a real
    /// open-string match wins). Returns the cents for the best match.
    func nearestString(to frequency: Double) -> (index: Int, cents: Double) {
        var best = (index: 0, cents: 0.0, score: Double.infinity)
        for (index, note) in tuning.notes.enumerated() {
            for shift in [-1, 0, 1] {
                let cents = note.cents(of: frequency * pow(2, Double(-shift)), a4: a4)
                let penalty = shift == 0 ? 0 : shift > 0 ? configuration.octaveUpPenalty : configuration.octaveDownPenalty
                let score = abs(cents) + penalty
                if score < best.score { best = (index, cents, score) }
            }
        }
        return (best.index, best.cents)
    }

    /// Cents from the selected string's target, folding octave errors away. Also returns the folded frequency.
    private func centsToSelected(_ frequency: Double) -> (Double, Double) {
        let target = tuning.notes[state.selectedString]
        var best = (cents: Double.infinity, frequency: frequency)
        for shift in [-1, 0, 1] {
            let folded = frequency * pow(2, Double(-shift))
            let cents = target.cents(of: folded, a4: a4)
            if abs(cents) < abs(best.cents) { best = (cents, folded) }
        }
        return (best.cents, best.frequency)
    }

    private func nextUntunedString() -> Int? {
        (1...Tuning.stringCount).map { (state.selectedString + $0) % Tuning.stringCount }
            .first { !state.tuned.contains($0) }
    }
}
