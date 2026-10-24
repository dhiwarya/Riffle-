import Foundation
import RiffleTheory
import Testing
@testable import RiffleAudio

/// Synthetic strums; the real-guitar thresholds get tuned on the recorded corpus.
struct ChordVerifierTests {
    let sampleRate = 48_000.0

    private func frequencies(_ frets: [Int?], detune: [Int: Double] = [:]) -> [Double] {
        zip(frets, Tuning.standard.notes).enumerated().compactMap { index, pair in
            pair.0.map { pair.1.transposed(by: $0).frequency() * pow(2, (detune[index] ?? 0) / 1200) }
        }
    }

    private func strum(_ frets: [Int?], detune: [Int: Double] = [:], configure: (inout GuitarSynth.Pluck) -> Void = { _ in }) -> [Float] {
        GuitarSynth.strum(frequencies(frets, detune: detune), duration: 2.5, sampleRate: sampleRate) { pluck in
            pluck.inharmonicity = 0.00008
            configure(&pluck)
        }
    }

    private func verify(_ symbol: String, _ audio: [Float], configuration: ChordVerifier.Configuration = .init()) -> ChordEvidence {
        ChordVerifier(target: Chord(symbol: symbol)!, sampleRate: sampleRate, configuration: configuration).evaluate(audio)
    }

    private func names(_ set: Set<PitchClass>) -> Set<String> { Set(set.map(\.description)) }

    /// Every voicing the reveal screen can show for the quiz's chords passes when strummed cleanly;
    /// triads also pass the bass check for their inversion. A sample by default (each voicing takes
    /// about half a second in debug); `RIFFLE_ALL_VOICINGS=1` checks every quiz chord.
    @Test func libraryVoicingsPass() {
        let symbols = ProcessInfo.processInfo.environment["RIFFLE_ALL_VOICINGS"] == nil
            ? "Am C B7 F Cmaj7 C9"
            : "E A D G C Em Am Dm E7 A7 D7 G7 B7 C7 Dsus2 Dsus4 Asus2 Asus4 E5 G5 C5 F Bm B♭ F♯m Cm C♯m Cmaj7 Fmaj7 Am7 Dm7 Bm7♭5 Bdim7 Cadd9 C6 A6 Am6 C9 D9"
        var failures: [String] = []
        for symbol in symbols.split(separator: " ").map(String.init) {
            let chord = Chord(symbol: symbol)!
            let set = VoicingLibrary.voicings(for: chord, in: .standard)
            for voicing in set.full {
                let evidence = verify(symbol, strum(voicing.frets))
                if evidence.verdict != .passed {
                    failures.append("\(voicing.id) missing \(names(evidence.missing)) extra \(names(evidence.extra))")
                }
            }
            for (inversion, triad) in set.triads.enumerated() {
                var configuration = ChordVerifier.Configuration()
                configuration.requiredBass = chord.tones[inversion].note.pitchClass
                let evidence = verify(symbol, strum(triad.frets), configuration: configuration)
                if evidence.verdict != .passed {
                    failures.append("\(triad.id) bass \(evidence.bass.map(\.description) ?? "-") missing \(names(evidence.missing)) extra \(names(evidence.extra))")
                }
            }
        }
        #expect(failures.isEmpty, "\(failures.joined(separator: "\n"))")
    }

    let amOpen: [Int?] = [nil, 0, 2, 2, 1, 0]
    let aOpen: [Int?] = [nil, 0, 2, 2, 2, 0]

    /// The overtone trap: a loud 5th harmonic on every string must not turn Am into A major.
    @Test func aMinorWithLoudFifthHarmonicsStaysMinor() {
        let audio = strum(amOpen) { $0.partialOverrides = [5: 0.45] }
        #expect(verify("Am", audio).verdict == .passed)
        let asMajor = verify("A", audio)
        #expect(asMajor.verdict == .failed)
        #expect(names(asMajor.missing) == ["C♯"])
    }

    @Test func aMajorIsNotAMinor() {
        let evidence = verify("Am", strum(aOpen))
        #expect(evidence.verdict == .failed)
        #expect(names(evidence.missing) == ["C"])
        #expect(names(evidence.extra) == ["C♯"])
        #expect(verify("A", strum(aOpen)).verdict == .passed)
    }

    @Test func deadStringLeavesATheMissingTone() {
        let evidence = verify("Am", strum([nil, 0, 2, 2, nil, 0]))
        #expect(evidence.verdict == .failed)
        #expect(names(evidence.missing) == ["C"])
        #expect(evidence.extra.isEmpty)
    }

    @Test func detunedStringStillPasses() {
        #expect(verify("Am", strum(amOpen, detune: [3: -30])).verdict == .passed)
    }

    @Test func singleStringIsNotAChord() {
        let evidence = verify("Am", strum([nil, 0, nil, nil, nil, nil]))
        #expect(evidence.verdict == .failed)
        #expect(names(evidence.missing) == ["C", "E"])
    }

    @Test func silenceAndNoiseNeverPass() {
        let silence = [Float](repeating: 0, count: Int(sampleRate * 2))
        #expect(verify("Am", silence).verdict == .waiting)
        let noise = GuitarSynth.noise(levelDB: -30, duration: 2, sampleRate: sampleRate)
        #expect(verify("Am", noise).verdict != .passed)
    }

    @Test func passesWithModestBackgroundNoise() {
        let audio = GuitarSynth.mix(strum(amOpen), GuitarSynth.noise(levelDB: -45, duration: 2.5, sampleRate: sampleRate))
        #expect(verify("Am", audio).verdict == .passed)
    }

    @Test func seventhChordMayOmitTheFifth() {
        #expect(verify("G7", strum([3, nil, 3, 4, nil, nil])).verdict == .passed)
    }

    @Test func bassCheckForInversions() {
        var configuration = ChordVerifier.Configuration()
        configuration.requiredBass = PitchClass(0) // C: first inversion of Am
        #expect(verify("Am", strum([nil, nil, nil, 5, 5, 5]), configuration: configuration).verdict == .passed)
        #expect(verify("Am", strum([nil, nil, nil, 2, 1, 0]), configuration: configuration).verdict == .failed)
    }

    @Test func passesEarlyWhileTheChordRings() {
        let verifier = ChordVerifier(target: Chord(.A, .minor), sampleRate: sampleRate)
        let audio = strum(amOpen)
        var passedAt: Double?
        for start in stride(from: 0, to: audio.count, by: 1024) {
            let evidence = verifier.process(Array(audio[start..<min(start + 1024, audio.count)]))
            if evidence.verdict == .passed { passedAt = Double(start) / sampleRate; break }
        }
        // Strum starts at 0.3 s; the plan asks for a verdict within 1 s.
        #expect((passedAt ?? 99) < 1.3)
    }

    /// Every chord clip in the recording list, synthesised: correct shapes pass, mistakes fail the right way.
    @Test(arguments: CorpusShotList.all.filter {
        if case .chord = $0.expectation { return !$0.id.contains("g-flat") }
        return false
    })
    func shotListChordsBehave(shot: CorpusShot) {
        guard case let .chord(target, frets, shouldPass, missing, extra) = shot.expectation else { return }
        let evidence = verify(target, strum(frets))
        #expect((evidence.verdict == .passed) == shouldPass, "\(shot.id): \(evidence)")
        if !shouldPass {
            #expect(names(evidence.missing) == Set(missing), "\(shot.id) missing")
            #expect(names(evidence.extra) == Set(extra), "\(shot.id) extra")
        }
    }
}

/// The recording list itself must be musically right, or the corpus tests would test the wrong thing.
struct CorpusShotListTests {
    @Test func idsAreUniqueAndCountIsAsPlanned() {
        #expect(Set(CorpusShotList.all.map(\.id)).count == CorpusShotList.all.count)
        #expect(CorpusShotList.all.count == 116)
    }

    @Test func chordShapesMatchTheirLabels() {
        for shot in CorpusShotList.all {
            guard case let .chord(target, frets, shouldPass, missing, extra) = shot.expectation else { continue }
            let chord = Chord(symbol: target)!
            let voicing = Voicing(id: shot.id, frets: frets, fingers: Array(repeating: nil, count: 6), family: .full, shapeName: "")
            #expect(voicing.plays(chord, in: .standard) == shouldPass, "\(shot.id)")
            let sounding = voicing.pitchClasses(in: .standard)
            #expect(Set(chord.requiredPitchClasses.subtracting(sounding).map(\.description)) == Set(missing), "\(shot.id)")
            #expect(Set(sounding.subtracting(chord.pitchClasses).map(\.description)) == Set(extra), "\(shot.id)")
        }
    }

    @Test func pitchShotsAreInGuitarRange() {
        for shot in CorpusShotList.all {
            guard case let .pitch(midi, cents, tolerance) = shot.expectation else { continue }
            #expect((38...76).contains(midi), "\(shot.id)")
            #expect(abs(cents) <= 25 && tolerance > 0)
        }
    }

    @Test func everyChordTargetParses() {
        for shot in CorpusShotList.all where shot.expectation != .noChord {
            if case .pitch = shot.expectation { continue }
            #expect(shot.targetChord != nil, "\(shot.id)")
        }
    }
}
