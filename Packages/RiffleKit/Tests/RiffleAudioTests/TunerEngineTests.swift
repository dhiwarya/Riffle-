import Foundation
import RiffleTheory
import Testing
@testable import RiffleAudio

struct TunerEngineTests {
    /// Readings every 21 ms (one 1024-sample hop at 48 kHz).
    private func feed(_ engine: TunerEngine, midi: Int, cents: Double, from start: Double, to end: Double,
                      octave: Int = 0, a4: Double = 440) -> TunerState {
        var time = start
        var state = engine.state
        while time <= end {
            let frequency = Note(midi: midi).frequency(a4: a4) * pow(2, cents / 1200 + Double(octave))
            state = engine.process(PitchReading(time: time, frequency: frequency, clarity: 0.97, levelDB: -20))
            time += 1024 / 48_000
        }
        return state
    }

    @Test func manualModeMeasuresTheSelectedString() throws {
        let engine = TunerEngine(mode: .manual)
        engine.select(string: 1)
        let state = feed(engine, midi: 45, cents: -12, from: 0, to: 0.5)
        #expect(state.selectedString == 1)
        #expect(abs(try #require(state.cents) + 12) < 0.5)
        #expect(!state.isInTune)
    }

    @Test func inTuneNeedsAHold() {
        let engine = TunerEngine()
        var state = feed(engine, midi: 40, cents: 1.5, from: 0, to: 0.3)
        #expect(!state.isInTune, "only 0.3 s so far")
        state = feed(engine, midi: 40, cents: 1.5, from: 0.32, to: 0.6)
        #expect(state.isInTune)
        #expect(state.tuned == [0])
        #expect(state.tunedEvents == 1)
    }

    @Test func autoModeFollowsAFreshPluckImmediately() {
        let engine = TunerEngine()
        let state = feed(engine, midi: 59, cents: -20, from: 0, to: 0.05)
        #expect(state.selectedString == 4)
    }

    @Test func autoModeWaitsBeforeSwitchingWhileAStringRings() {
        let engine = TunerEngine()
        _ = feed(engine, midi: 45, cents: 0, from: 0, to: 0.3)
        var state = feed(engine, midi: 50, cents: 0, from: 0.32, to: 0.4)
        #expect(state.selectedString == 1, "a brief other note doesn't steal the needle")
        state = feed(engine, midi: 50, cents: 0, from: 0.42, to: 0.7)
        #expect(state.selectedString == 2)
    }

    @Test func octaveErrorsAreFolded() throws {
        let engine = TunerEngine()
        // The detector reports the low E's octave (E3); no standard open string is E3.
        let state = feed(engine, midi: 40, cents: -6, from: 0, to: 0.4, octave: 1)
        #expect(state.selectedString == 0)
        #expect(abs(try #require(state.cents) + 6) < 0.5)
    }

    @Test func openTuningsKeepRealOctaves() {
        let engine = TunerEngine(tuning: .openE)
        // Open E has E3 on string 4: it must win over "low E, an octave up".
        let state = feed(engine, midi: 52, cents: 0, from: 0, to: 0.3)
        #expect(state.selectedString == 2)
    }

    @Test func autoAdvancesAfterATunedStringStops() {
        let engine = TunerEngine()
        _ = feed(engine, midi: 40, cents: 0, from: 0, to: 0.7)
        var state = engine.tick(time: 0.8)
        #expect(state.hasSignal, "still within the timeout")
        state = engine.tick(time: 1.2)
        #expect(!state.hasSignal)
        #expect(state.selectedString == 1)
    }

    @Test func manualModeDoesNotAdvance() {
        let engine = TunerEngine(mode: .manual)
        _ = feed(engine, midi: 40, cents: 0, from: 0, to: 0.7)
        #expect(engine.tick(time: 1.5).selectedString == 0)
    }

    @Test func allSixStrings() {
        let engine = TunerEngine()
        var time = 0.0
        for midi in Tuning.standard.notes.map(\.midi) {
            _ = feed(engine, midi: midi, cents: 0.5, from: time, to: time + 0.6)
            time += 1.2
            engine.tick(time: time - 0.1)
        }
        #expect(engine.state.allTuned)
        #expect(engine.state.tunedEvents == 6)
    }

    @Test func changingTuningOrA4ResetsProgress() {
        let engine = TunerEngine()
        _ = feed(engine, midi: 40, cents: 0, from: 0, to: 0.7)
        engine.tuning = .dropD
        #expect(engine.state.tuned.isEmpty)
        _ = feed(engine, midi: 38, cents: 0, from: 1, to: 1.7)
        #expect(engine.state.tuned == [0])
        engine.a4 = 432
        #expect(engine.state.tuned.isEmpty)
    }

    @Test func respectsA4() throws {
        let engine = TunerEngine(a4: 432)
        let state = feed(engine, midi: 45, cents: 0, from: 0, to: 0.7, a4: 432)
        #expect(abs(try #require(state.cents)) < 0.5)
        #expect(state.isInTune)
    }

    @Test func badgeDoesNotFlickerAtTheEdge() {
        let engine = TunerEngine()
        _ = feed(engine, midi: 40, cents: 2, from: 0, to: 0.7)
        let state = feed(engine, midi: 40, cents: 4, from: 0.72, to: 1.5)
        #expect(state.isInTune, "4¢ is inside the 4.5¢ release band")
    }

    /// Whole chain on a synthetic pluck: tracker → engine.
    @Test func pluckedStringEndToEnd() throws {
        let sampleRate = 48_000.0
        var pluck = GuitarSynth.Pluck(frequency: Note(midi: 50).frequency() * pow(2, -8.0 / 1200))
        pluck.amplitude = 0.3
        let audio = GuitarSynth.tone(pluck, duration: 2, sampleRate: sampleRate, startAt: 0.3)
        let tracker = PitchTracker(sampleRate: sampleRate)
        let engine = TunerEngine()
        for start in stride(from: 0, to: audio.count, by: 1024) {
            for reading in tracker.process(Array(audio[start..<min(start + 1024, audio.count)])) {
                engine.process(reading)
            }
        }
        #expect(engine.state.selectedString == 2)
        #expect(abs(try #require(engine.state.cents) + 8) < 1)
    }
}

struct OneEuroFilterTests {
    @Test func smoothsJitterButFollowsMoves() {
        var filter = OneEuroFilter()
        var jittered: [Double] = []
        for i in 0..<100 { jittered.append(filter.filter(i.isMultiple(of: 2) ? 1 : -1, at: Double(i) * 0.02)) }
        #expect(jittered.suffix(50).allSatisfy { abs($0) < 0.5 })

        filter.reset()
        var last = 0.0
        for i in 0..<50 { last = filter.filter(Double(i) * 0.6, at: Double(i) * 0.02) } // 30 ¢/s turn
        #expect(abs(last - 29.4) < 4)
    }
}
