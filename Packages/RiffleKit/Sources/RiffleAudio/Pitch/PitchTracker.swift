import Foundation

/// A smoothed pitch reading at a point in the stream.
public struct PitchReading: Equatable, Sendable {
    /// Seconds since the tracker started.
    public let time: Double
    /// Median of the recent confident estimates.
    public let frequency: Double
    public let clarity: Double
    public let levelDB: Double
}

/// Streams audio into the pitch detector: high-pass, noise gate, skips the sharp attack after a pluck,
/// and medians the last few confident estimates (plan §5.2 steps 1–7, minus the M2 tuner logic).
public final class PitchTracker {
    public struct Configuration: Sendable {
        public var detector = PitchDetector.Configuration()
        public var hopSize = 1024
        public var highPassCutoff = 50.0
        public var minClarity = 0.85
        /// Attack to ignore after a pluck; strings start sharp.
        public var attackSkip = 0.06
        public var medianCount = 5
        /// A rise of this many dB within one hop counts as a new pluck.
        public var onsetRiseDB = 9.0

        public init() {}
    }

    public let sampleRate: Double
    public let configuration: Configuration
    private let detector: PitchDetector
    private var filter: Biquad
    private var buffer: [Float]
    private var pending: [Float] = []
    private var samplesSeen = 0
    private var recent: [Double] = []
    private var previousHopDB = -160.0
    private var skipUntil = 0.0

    public init(sampleRate: Double, configuration: Configuration = Configuration()) {
        self.sampleRate = sampleRate
        self.configuration = configuration
        detector = PitchDetector(sampleRate: sampleRate, configuration: configuration.detector)
        filter = .highPass(cutoff: configuration.highPassCutoff, sampleRate: sampleRate)
        buffer = [Float](repeating: 0, count: configuration.detector.windowSize)
    }

    /// Feeds samples; returns a reading for each completed hop that produced a confident pitch.
    public func process(_ samples: [Float]) -> [PitchReading] {
        var filtered = samples
        filter.process(&filtered)
        pending += filtered
        var readings: [PitchReading] = []
        let hop = configuration.hopSize
        while pending.count >= hop {
            let chunk = Array(pending.prefix(hop))
            pending.removeFirst(hop)
            buffer.removeFirst(hop)
            buffer += chunk
            samplesSeen += hop
            if let reading = analyseCurrentWindow(newest: chunk) { readings.append(reading) }
        }
        return readings
    }

    public func reset() {
        filter.reset()
        buffer = [Float](repeating: 0, count: configuration.detector.windowSize)
        pending = []
        samplesSeen = 0
        recent = []
        previousHopDB = -160
        skipUntil = 0
    }

    private func analyseCurrentWindow(newest: [Float]) -> PitchReading? {
        let time = Double(samplesSeen) / sampleRate
        let hopDB = newest.withUnsafeBufferPointer(rmsDecibels)
        if hopDB - previousHopDB > configuration.onsetRiseDB && hopDB > configuration.detector.silenceDB {
            skipUntil = time + configuration.attackSkip
            recent.removeAll()
        }
        previousHopDB = hopDB
        guard time >= skipUntil,
              let estimate = detector.estimate(buffer),
              estimate.clarity >= configuration.minClarity else { return nil }

        recent.append(estimate.frequency)
        if recent.count > configuration.medianCount { recent.removeFirst() }
        let sorted = recent.sorted()
        return PitchReading(time: time, frequency: sorted[sorted.count / 2], clarity: estimate.clarity,
                            levelDB: estimate.levelDB)
    }
}
