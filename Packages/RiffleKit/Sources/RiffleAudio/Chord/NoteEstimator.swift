import Foundation
import RiffleTheory

public struct SpectralPeak: Equatable, Sendable {
    public let frequency: Double
    public let magnitude: Double
}

/// A note judged to be sounding, built from its fundamental and attributed harmonics.
public struct DetectedNote: Equatable, Sendable {
    public let midi: Int
    /// Frequency of the lowest partial assigned to this note.
    public let frequency: Double
    /// Strongest partial's magnitude (linear).
    public let strength: Double
    public let partialCount: Int

    public var pitchClass: PitchClass { PitchClass(midi) }
}

/// Finds spectral peaks in a window and groups them into notes (plan §6.2 steps 1–4).
///
/// The key idea is harmonic attribution: each peak, lowest first, is explained as a harmonic of a
/// note already found where possible. That stops the 5th harmonic of A2 (≈C♯5) from looking like
/// a major third and turning a correct Am into "A major".
public final class NoteEstimator {
    public struct Configuration: Sendable {
        public var windowSize = 8192
        public var fftSize = 16384
        public var minFrequency = 70.0
        public var maxFrequency = 4200.0
        /// Ignore peaks this far below the strongest one.
        public var dynamicRangeDB = 40.0
        public var maxPeaks = 48
        /// Matching tolerance for harmonics and note centres, in cents.
        public var toleranceCents = 35.0
        public var maxHarmonic = 10
        /// A non-octave partial louder than this × the note's strongest partial is treated as a real note.
        public var harmonicLoudnessRatio = 1.2
        public var midiRange = 36...96

        public init() {}
    }

    public let sampleRate: Double
    public let configuration: Configuration
    private let fft: RealFFT
    private let window: [Float]
    private var windowed: [Float]
    private var magnitudes: [Float] = []

    public init(sampleRate: Double, configuration: Configuration = Configuration()) {
        self.sampleRate = sampleRate
        self.configuration = configuration
        fft = RealFFT(size: configuration.fftSize)
        window = hannWindow(configuration.windowSize)
        windowed = [Float](repeating: 0, count: configuration.windowSize)
    }

    public var windowSize: Int { configuration.windowSize }

    public func peaks(in samples: UnsafeBufferPointer<Float>) -> [SpectralPeak] {
        let count = min(samples.count, configuration.windowSize)
        for i in 0..<count { windowed[i] = samples[i] * window[i] }
        windowed.withUnsafeBufferPointer { fft.magnitudes(of: UnsafeBufferPointer(rebasing: $0[0..<count]), into: &magnitudes) }

        let binHz = sampleRate / Double(configuration.fftSize)
        let lowBin = max(2, Int(configuration.minFrequency / binHz))
        let highBin = min(magnitudes.count - 3, Int(configuration.maxFrequency / binHz))
        guard lowBin < highBin else { return [] }
        var loudest: Float = 0
        for k in lowBin...highBin { loudest = max(loudest, magnitudes[k]) }
        guard loudest > 0 else { return [] }
        let floor = loudest * Float(pow(10, -configuration.dynamicRangeDB / 20))

        var found: [SpectralPeak] = []
        for k in lowBin...highBin {
            let m = magnitudes[k]
            guard m > floor, m > magnitudes[k - 1], m >= magnitudes[k + 1], m > magnitudes[k - 2], m >= magnitudes[k + 2] else { continue }
            // Quadratic interpolation on log magnitude for the true peak position.
            let a = log(Double(magnitudes[k - 1]) + 1e-12), b = log(Double(m) + 1e-12), c = log(Double(magnitudes[k + 1]) + 1e-12)
            let denominator = a - 2 * b + c
            let p = denominator != 0 ? 0.5 * (a - c) / denominator : 0
            found.append(SpectralPeak(frequency: (Double(k) + p) * binHz, magnitude: exp(b - 0.25 * (a - c) * p)))
        }
        return Array(found.sorted { $0.magnitude > $1.magnitude }.prefix(configuration.maxPeaks))
            .sorted { $0.frequency < $1.frequency }
    }

    /// Groups ascending peaks into notes by harmonic attribution.
    public func notes(from peaks: [SpectralPeak], a4: Double = 440) -> [DetectedNote] {
        struct Building {
            var midi: Int
            var fundamental: Double
            var strength: Double
            var partials: Int
        }
        var notes: [Building] = []
        let tolerance = configuration.toleranceCents

        for peak in peaks {
            var attributed = false
            for index in notes.indices {
                let ratio = peak.frequency / notes[index].fundamental
                let h = Int(ratio.rounded())
                guard h >= 2, h <= configuration.maxHarmonic,
                      abs(PitchMath.cents(peak.frequency, relativeTo: Double(h) * notes[index].fundamental)) <= tolerance + Double(h)
                else { continue }
                // Octave partials (2, 4, 8) share the pitch class, so always absorb them.
                // Other partials only if they aren't louder than the note itself.
                let isOctave = h & (h - 1) == 0
                if isOctave || peak.magnitude <= configuration.harmonicLoudnessRatio * notes[index].strength {
                    notes[index].strength = max(notes[index].strength, peak.magnitude)
                    notes[index].partials += 1
                    attributed = true
                    break
                }
            }
            guard !attributed else { continue }

            let exact = PitchMath.midi(frequency: peak.frequency, a4: a4)
            let midi = Int(exact.rounded())
            guard abs(exact - Double(midi)) * 100 <= tolerance + 10, configuration.midiRange.contains(midi) else { continue }
            if let same = notes.firstIndex(where: { $0.midi == midi }) {
                notes[same].strength = max(notes[same].strength, peak.magnitude)
                notes[same].partials += 1
            } else {
                notes.append(Building(midi: midi, fundamental: peak.frequency, strength: peak.magnitude, partials: 1))
            }
        }
        return notes.map { DetectedNote(midi: $0.midi, frequency: $0.fundamental, strength: $0.strength, partialCount: $0.partials) }
    }

    /// Pitch-class strengths normalised to the strongest (0…1), compressed so a chord tone played on
    /// one string isn't drowned by a root doubled across three.
    public static func chroma(of notes: [DetectedNote], exponent: Double = 0.5) -> [Double] {
        var chroma = [Double](repeating: 0, count: 12)
        for note in notes {
            let pc = note.pitchClass.rawValue
            chroma[pc] = max(chroma[pc], pow(note.strength, exponent))
        }
        let top = chroma.max() ?? 0
        return top > 0 ? chroma.map { $0 / top } : chroma
    }
}
