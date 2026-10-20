import Foundation
import RiffleTheory

/// What the verifier has heard so far for the current target chord.
public struct ChordEvidence: Equatable, Sendable {
    public enum Verdict: Equatable, Sendable {
        /// Nothing strummed yet.
        case waiting
        /// A strum is ringing and being evaluated.
        case listening
        /// All required tones, nothing wrong.
        case passed
        /// A strum finished without passing.
        case failed
    }

    public var verdict: Verdict = .waiting
    /// Required chord tones heard in the current (or last) strum.
    public var heard: Set<PitchClass> = []
    /// Required chord tones not heard in the last finished strum.
    public var missing: Set<PitchClass> = []
    /// Strong pitch classes that don't belong to the chord.
    public var extra: Set<PitchClass> = []
    /// Lowest sounding pitch class in the last strum.
    public var bass: PitchClass?
    public var strums = 0
    /// Latest chroma (0…1 per pitch class), for live displays.
    public var chroma: [Double] = Array(repeating: 0, count: 12)

    public init() {}
}

/// Checks whether the target chord is being played (plan §6.2): onset detection, then the sustain
/// window 100–900 ms after each strum is scored per chord tone.
public final class ChordVerifier {
    public struct Configuration: Sendable {
        public var estimator = NoteEstimator.Configuration()
        public var hopSize = 2048
        public var highPassCutoff = 60.0
        /// A chord tone counts when its chroma is at least this…
        public var presentThreshold = 0.3
        /// …a non-chord tone counts as wrong when it reaches this.
        public var extraThreshold = 0.55
        /// …in at least this many frames of the strum's window.
        public var minFrames = 3
        public var windowStart = 0.1
        public var windowEnd = 0.9
        public var onsetRiseDB = 8.0
        public var gateDB = -55.0
        /// Require the lowest note to be this pitch class (inversions, root position).
        public var requiredBass: PitchClass?

        public init() {}
    }

    public let target: Chord
    public let sampleRate: Double
    public let configuration: Configuration
    public let a4: Double
    public private(set) var evidence = ChordEvidence()

    private let estimator: NoteEstimator
    private var filter: Biquad
    private var buffer: [Float]
    private var pending: [Float] = []
    private var samplesSeen = 0
    private var previousHopDB = -160.0
    private var strumStart: Double?
    private var presentCounts = [Int](repeating: 0, count: 12)
    private var extraCounts = [Int](repeating: 0, count: 12)
    private var bassCounts = [Int](repeating: 0, count: 12)
    private var framesInStrum = 0

    public init(target: Chord, sampleRate: Double, a4: Double = 440, configuration: Configuration = Configuration()) {
        self.target = target
        self.sampleRate = sampleRate
        self.a4 = a4
        self.configuration = configuration
        estimator = NoteEstimator(sampleRate: sampleRate, configuration: configuration.estimator)
        filter = .highPass(cutoff: configuration.highPassCutoff, sampleRate: sampleRate)
        buffer = [Float](repeating: 0, count: configuration.estimator.windowSize)
    }

    /// Feeds live or file audio; returns the updated evidence.
    @discardableResult
    public func process(_ samples: [Float]) -> ChordEvidence {
        var filtered = samples
        filter.process(&filtered)
        pending += filtered
        let hop = configuration.hopSize
        while pending.count >= hop {
            let chunk = Array(pending.prefix(hop))
            pending.removeFirst(hop)
            buffer.removeFirst(hop)
            buffer += chunk
            samplesSeen += hop
            analyse(newest: chunk)
        }
        return evidence
    }

    /// Runs a whole clip and finishes any strum still ringing at the end.
    public func evaluate(_ samples: [Float]) -> ChordEvidence {
        process(samples)
        if strumStart != nil { finishStrum() }
        return evidence
    }

    private var required: Set<PitchClass> { target.requiredPitchClasses }

    private func analyse(newest: [Float]) {
        let time = Double(samplesSeen) / sampleRate
        let hopDB = newest.withUnsafeBufferPointer(rmsDecibels)
        let isOnset = hopDB - previousHopDB > configuration.onsetRiseDB && hopDB > configuration.gateDB
        previousHopDB = hopDB

        if isOnset {
            if strumStart != nil { finishStrum() }
            if evidence.verdict != .passed { beginStrum(at: time) }
        }
        guard let start = strumStart, evidence.verdict != .passed else { return }

        let age = time - start
        if age > configuration.windowEnd {
            finishStrum()
            return
        }
        guard age >= configuration.windowStart, hopDB > configuration.gateDB else { return }

        let notes = buffer.withUnsafeBufferPointer { estimator.notes(from: estimator.peaks(in: $0), a4: a4) }
        let chroma = NoteEstimator.chroma(of: notes)
        evidence.chroma = chroma
        framesInStrum += 1
        let chordTones = target.pitchClasses
        for pc in 0..<12 {
            if chroma[pc] >= configuration.presentThreshold { presentCounts[pc] += 1 }
            if chroma[pc] >= configuration.extraThreshold && !chordTones.contains(PitchClass(pc)) { extraCounts[pc] += 1 }
        }
        if let lowest = notes.filter({ pow($0.strength, 0.5) >= configuration.presentThreshold * pow(notes.map(\.strength).max() ?? 0, 0.5) })
            .min(by: { $0.midi < $1.midi }) {
            bassCounts[lowest.pitchClass.rawValue] += 1
        }
        updateEvidence()
        if framesInStrum >= configuration.minFrames + 2 && strumPasses { evidence.verdict = .passed }
    }

    private func beginStrum(at time: Double) {
        strumStart = time
        presentCounts = Array(repeating: 0, count: 12)
        extraCounts = Array(repeating: 0, count: 12)
        bassCounts = Array(repeating: 0, count: 12)
        framesInStrum = 0
        evidence.strums += 1
        evidence.verdict = .listening
        evidence.heard = []
        evidence.extra = []
    }

    private func finishStrum() {
        strumStart = nil
        guard evidence.verdict != .passed else { return }
        updateEvidence()
        evidence.missing = required.subtracting(evidence.heard)
        evidence.verdict = framesInStrum > 0 && strumPasses ? .passed : .failed
    }

    private func updateEvidence() {
        let minFrames = min(configuration.minFrames, max(framesInStrum, 1))
        evidence.heard = Set(required.filter { presentCounts[$0.rawValue] >= minFrames })
        evidence.extra = Set((0..<12).filter { extraCounts[$0] >= minFrames }.map(PitchClass.init))
        let topBass = bassCounts.indices.max { bassCounts[$0] < bassCounts[$1] }
        evidence.bass = topBass.flatMap { bassCounts[$0] > 0 ? PitchClass($0) : nil }
    }

    private var strumPasses: Bool {
        guard evidence.heard == required, evidence.extra.isEmpty else { return false }
        if let bass = configuration.requiredBass { return evidence.bass == bass }
        return true
    }
}
