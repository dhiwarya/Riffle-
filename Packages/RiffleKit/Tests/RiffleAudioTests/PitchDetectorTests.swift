import Foundation
import RiffleTheory
import Testing
@testable import RiffleAudio

struct PitchDetectorTests {
    let sampleRate = 48_000.0

    private func sine(_ frequency: Double, count: Int = 4096, amplitude: Double = 0.3) -> [Float] {
        (0..<count).map { Float(amplitude * sin(2 * .pi * frequency * Double($0) / sampleRate + 0.3)) }
    }

    private func sawtooth(_ frequency: Double, count: Int = 4096) -> [Float] {
        (0..<count).map { i in
            Float((1...20).reduce(0.0) { sum, h in
                let f = Double(h) * frequency
                return f < sampleRate / 2 ? sum + sin(2 * .pi * f * Double(i) / sampleRate) / Double(h) : sum
            } * 0.2)
        }
    }

    private func cents(_ measured: Double, _ expected: Double) -> Double {
        PitchMath.cents(measured, relativeTo: expected)
    }

    /// Plan §5.4: error under 0.5 ¢ from 60 to 1,400 Hz on synthetic tones.
    @Test(arguments: Array(stride(from: 36, through: 88, by: 1)))
    func sineAccuracy(midi: Int) throws {
        let detector = PitchDetector(sampleRate: sampleRate)
        let f = Note(midi: midi).frequency()
        let estimate = try #require(detector.estimate(sine(f)))
        #expect(abs(cents(estimate.frequency, f)) < 0.5, "midi \(midi): \(cents(estimate.frequency, f))¢")
        #expect(estimate.clarity > 0.95)
    }

    @Test(arguments: Array(stride(from: 36, through: 88, by: 2)))
    func harmonicRichAccuracy(midi: Int) throws {
        let detector = PitchDetector(sampleRate: sampleRate)
        let f = Note(midi: midi).frequency()
        let estimate = try #require(detector.estimate(sawtooth(f)))
        #expect(abs(cents(estimate.frequency, f)) < 0.5, "midi \(midi): \(cents(estimate.frequency, f))¢")
    }

    @Test(arguments: [-25.0, -10.0, -3.0, 3.0, 10.0, 25.0])
    func measuresDetuning(offset: Double) throws {
        let detector = PitchDetector(sampleRate: sampleRate)
        let target = Note(midi: 45).frequency()
        let f = target * pow(2, offset / 1200)
        let estimate = try #require(detector.estimate(sawtooth(f)))
        #expect(abs(cents(estimate.frequency, target) - offset) < 0.5)
    }

    /// Low strings through a phone mic: the fundamental is weak, the octave must still be right.
    @Test(arguments: Tuning.standard.notes.map(\.midi) + Tuning.dropC.notes.prefix(1).map(\.midi))
    func pluckedStringsKeepTheirOctave(midi: Int) throws {
        let detector = PitchDetector(sampleRate: sampleRate)
        let f = Note(midi: midi).frequency()
        var pluck = GuitarSynth.Pluck(frequency: f)
        pluck.inharmonicity = 0.00008
        let tone = GuitarSynth.tone(pluck, duration: 1.0, sampleRate: sampleRate)
        for start in stride(from: 4_800, to: 40_000, by: 7_000) {
            let window = Array(tone[start..<start + 4096])
            let estimate = try #require(detector.estimate(window))
            #expect(abs(cents(estimate.frequency, f)) < 3, "midi \(midi) at \(start): \(cents(estimate.frequency, f))¢")
        }
    }

    @Test func silenceGivesNothing() {
        let detector = PitchDetector(sampleRate: sampleRate)
        #expect(detector.estimate([Float](repeating: 0, count: 4096)) == nil)
        #expect(detector.estimate(GuitarSynth.noise(levelDB: -70, duration: 0.1, sampleRate: sampleRate).prefix(4096).map { $0 }) == nil)
    }

    @Test func noiseIsNotConfident() {
        let detector = PitchDetector(sampleRate: sampleRate)
        let noise = Array(GuitarSynth.noise(levelDB: -25, duration: 0.1, sampleRate: sampleRate).prefix(4096))
        let estimate = detector.estimate(noise)
        #expect((estimate?.clarity ?? 0) < 0.85)
    }
}

struct PitchTrackerTests {
    let sampleRate = 48_000.0

    /// An ideal string must read exactly; a stiff one (inharmonic partials) reads slightly sharp,
    /// like it does on any tuner, so it gets a looser bound.
    @Test(arguments: [(0.0, 1.0), (0.0001, 3.5)])
    func tracksAPluckAfterSilence(inharmonicity: Double, tolerance: Double) throws {
        let f = Note(midi: 45).frequency() * pow(2, -12.0 / 1200)
        var pluck = GuitarSynth.Pluck(frequency: f)
        pluck.inharmonicity = inharmonicity
        let audio = GuitarSynth.tone(pluck, duration: 2.5, sampleRate: sampleRate, startAt: 0.5)
        let tracker = PitchTracker(sampleRate: sampleRate)
        var readings: [PitchReading] = []
        for chunk in stride(from: 0, to: audio.count, by: 512) {
            readings += tracker.process(Array(audio[chunk..<min(chunk + 512, audio.count)]))
        }
        #expect(readings.first.map { $0.time > 0.5 } ?? false, "nothing before the pluck")
        let sustain = readings.filter { $0.time > 0.8 && $0.time < 2.2 }
        #expect(sustain.count > 40)
        for reading in sustain {
            #expect(abs(Note(midi: 45).cents(of: reading.frequency) + 12) < tolerance)
        }
    }

    @Test func noiseProducesNoReadings() {
        let tracker = PitchTracker(sampleRate: sampleRate)
        let noise = GuitarSynth.noise(levelDB: -35, duration: 2, sampleRate: sampleRate)
        #expect(tracker.process(noise).count < 3)
    }
}
