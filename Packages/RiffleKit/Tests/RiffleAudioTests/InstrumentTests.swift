import Foundation
import RiffleTheory
import Testing
@testable import RiffleAudio

/// The synthesised instruments must be in tune: an ear-training app that plays a note 10 ¢ off
/// teaches the wrong thing.
struct InstrumentTests {
    let sampleRate = 48_000.0

    private func measuredCents(_ samples: [Float], midi: Int) throws -> Double {
        let detector = PitchDetector(sampleRate: sampleRate)
        var readings: [Double] = []
        for start in stride(from: Int(0.15 * sampleRate), to: Int(0.9 * sampleRate), by: 2048) {
            if let estimate = detector.estimate(Array(samples[start..<start + 4096])), estimate.clarity > 0.8 {
                readings.append(Note(midi: midi).cents(of: estimate.frequency))
            }
        }
        try #require(readings.count > 5, "no confident pitch")
        return readings.sorted()[readings.count / 2]
    }

    @Test(arguments: [40, 45, 50, 55, 57, 60, 64, 67, 69, 72, 76])
    func guitarIsInTune(midi: Int) throws {
        let samples = Instrument.guitar.render(frequency: Note(midi: midi).frequency(), duration: 1.2, velocity: 0.8, sampleRate: sampleRate)
        let cents = try measuredCents(samples, midi: midi)
        #expect(abs(cents) < 1, "midi \(midi): \(cents)¢")
    }

    @Test(arguments: [45, 48, 52, 57, 60, 64, 67, 69, 72, 76])
    func pianoIsInTune(midi: Int) throws {
        let samples = Instrument.piano.render(frequency: Note(midi: midi).frequency(), duration: 1.2, velocity: 0.8, sampleRate: sampleRate)
        #expect(abs(try measuredCents(samples, midi: midi)) < 2, "midi \(midi)")
    }

    @Test(arguments: Instrument.allCases)
    func notesDecayAndNeverClip(instrument: Instrument) {
        let samples = instrument.render(frequency: 220, duration: 2, velocity: 1, sampleRate: sampleRate)
        let peak = samples.map(abs).max() ?? 0
        #expect(peak > 0.05 && peak <= 1)
        let early = samples[4_800..<9_600].map(abs).max() ?? 0
        let late = samples[86_400..<91_200].map(abs).max() ?? 0
        #expect(late < early * 0.6, "should ring down")
        #expect(abs(samples.last ?? 1) < 1e-3, "faded out")
    }

    @Test func mixedPhraseIsTimedAndLimited() {
        let engine = ToneEngine()
        let phrase = Phrase.cadence(Key(.C), style: .strum).then(.note(64), gap: 0.45)
        let mixed = engine.mix(phrase, instrument: .guitar)
        #expect(abs(Double(mixed.count) / ToneEngine.sampleRate - phrase.duration) < 0.06)
        #expect((mixed.map(abs).max() ?? 2) < 1)
        // The target note starts 0.45 s after the cadence: the onset is the loudest jump there.
        let targetStart = Int((phrase.duration - 1.6) * ToneEngine.sampleRate)
        let before = mixed[(targetStart - 2_400)..<targetStart].map(abs).max() ?? 1
        let after = mixed[targetStart..<(targetStart + 2_400)].map(abs).max() ?? 0
        #expect(after > before * 2)
    }
}

/// Dev aid: `RIFFLE_RENDER_SAMPLES=/some/folder swift test --filter renderListeningSamples`
/// writes what the ear check plays (cadence in C, then the 5th) for each instrument.
struct ListeningSamples {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["RIFFLE_RENDER_SAMPLES"] != nil))
    func renderListeningSamples() throws {
        let folder = URL(fileURLWithPath: ProcessInfo.processInfo.environment["RIFFLE_RENDER_SAMPLES"]!)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let engine = ToneEngine()
        for instrument in Instrument.allCases {
            let style: Phrase.ChordStyle = instrument == .guitar ? .strum : .block
            let phrase = Phrase.cadence(Key(.C), style: style).then(.note(67), gap: 0.45)
            try AudioClip(samples: engine.mix(phrase, instrument: instrument), sampleRate: ToneEngine.sampleRate)
                .writeWAV(to: folder.appendingPathComponent("ear-check-\(instrument.rawValue).wav"))
        }
    }
}
