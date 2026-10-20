import Testing
@testable import RiffleTheory

struct ChordTests {
    @Test func aMinorMatchesTheMockup() {
        let am = Chord(.A, .minor)
        #expect(am.symbol == "Am")
        #expect(am.name == "A minor")
        #expect(am.quality.kindLabel == "Minor triad")
        #expect(am.tones.map(\.note.description) == ["A", "C", "E"])
        #expect(am.tones.map(\.role) == ["R", "♭3", "5"])
        #expect(am.tones.map(\.interval.slotLabel) == ["ROOT", "♭3RD", "5TH"])
    }

    @Test func spellingAcrossQualities() {
        #expect(Chord(.Fs, .minor7).tones.map(\.note.description) == ["F♯", "A", "C♯", "E"])
        #expect(Chord(.Bb, .major).tones.map(\.note.description) == ["B♭", "D", "F"])
        #expect(Chord(.B, .diminished7).tones.map(\.note.description) == ["B", "D", "F", "A♭"])
        #expect(Chord(.C, .augmented).tones.map(\.note.description) == ["C", "E", "G♯"])
        #expect(Chord(.B, .halfDiminished7).symbol == "Bm7♭5")
    }

    @Test(arguments: [
        ("Am", "Am"), ("F#m7", "F♯m7"), ("Bb", "B♭"), ("Bbmaj7", "B♭maj7"), ("Dsus", "Dsus4"),
        ("Bm7b5", "Bm7♭5"), ("Ebm", "E♭m"), ("G7", "G7"), ("C", "C"), ("Cmin", "Cm"), ("E5", "E5"),
    ])
    func parsesSymbols(input: String, expected: String) {
        #expect(Chord(symbol: input)?.symbol == expected)
    }

    @Test(arguments: ["", "H7", "Cxyz", "m7"])
    func rejectsBadSymbols(input: String) {
        #expect(Chord(symbol: input) == nil)
    }

    @Test func requiredTonesAllowOmittedFifth() {
        let g7 = Chord(.G, .dominant7)
        #expect(g7.pitchClasses.count == 4)
        #expect(g7.requiredPitchClasses == [PitchClass(7), PitchClass(11), PitchClass(5)])
        #expect(Chord(.A, .minor).requiredPitchClasses.count == 3)
    }
}

struct TuningTests {
    @Test func presets() {
        #expect(Tuning.standard.noteNamesLabel == "E A D G B E")
        #expect(Tuning.standard.notes.map(\.midi) == [40, 45, 50, 55, 59, 64])
        #expect(Tuning.halfStepDown.noteNamesLabel == "E♭ A♭ D♭ G♭ B♭ E♭")
        #expect(Tuning.dropD.notes.first?.midi == 38)
        #expect(Tuning.standard.isStandard)
        #expect(!Tuning.dadgad.isStandard)
        #expect(Set(Tuning.presets.map(\.id)).count == Tuning.presets.count)
        #expect(Tuning.preset(id: "open-g") == .openG)
        #expect(Tuning.stringNumber(forIndex: 0) == 6)
    }

    @Test func standardFrequencies() {
        let f = Tuning.standard.frequencies()
        #expect(abs(f[0] - 82.41) < 0.01)
        #expect(abs(f[5] - 329.63) < 0.01)
        #expect(abs(Tuning.standard.frequencies(a4: 432)[1] - 108) < 0.01)
    }

    @Test func nearestStringForAutoMode() {
        #expect(Tuning.standard.nearestString(to: 81).index == 0)
        #expect(Tuning.standard.nearestString(to: 196.5).index == 3)
        let b = Tuning.standard.nearestString(to: 240)
        #expect(b.index == 4)
        #expect(b.cents < -40)
    }

    @Test func customTuningLimits() {
        var strings = Tuning.standard.strings
        #expect(Tuning.issues(for: strings).isEmpty)

        strings[0] = SpelledPitch("B1")!   // 5 below E2: allowed
        strings[5] = SpelledPitch("G4")!   // 3 above E4: tension warning
        let issues = Tuning.issues(for: strings)
        #expect(issues == [Tuning.Issue(stringIndex: 5, kind: .highTension)])
        #expect(issues.allSatisfy { !$0.isBlocking })

        strings[0] = SpelledPitch("A1")!   // 7 below: blocked
        strings[5] = SpelledPitch("B4")!   // 7 above: blocked
        #expect(Tuning.issues(for: strings).map(\.kind) == [.tooLow, .tooHigh])

        let custom = Tuning.custom(name: "Mine", strings: Tuning.standard.strings)
        #expect(custom.id.hasPrefix("custom-"))
    }
}

struct VoicingTests {
    private let am = Chord(.A, .minor)

    /// The six A minor voicings from the mockup's reveal screen.
    private let mockup: [(Voicing, [String?], Int)] = [
        (Voicing(id: "am-open", frets: [nil, 0, 2, 2, 1, 0], fingers: [nil, nil, 2, 3, 1, nil], family: .full, shapeName: "Open"),
         [nil, "R", "5", "R", "♭3", "5"], 1),
        (Voicing(id: "am-e", frets: [5, 7, 7, 5, 5, 5], fingers: [1, 3, 4, 1, 1, 1],
                 barres: [.init(fret: 5, fromString: 0, toString: 5)], family: .full, shapeName: "E shape"),
         ["R", "5", "R", "♭3", "5", "R"], 5),
        (Voicing(id: "am-a", frets: [nil, 12, 14, 14, 13, 12], fingers: [nil, 1, 3, 4, 2, 1],
                 barres: [.init(fret: 12, fromString: 1, toString: 5)], family: .full, shapeName: "A shape"),
         [nil, "R", "5", "R", "♭3", "5"], 12),
        (Voicing(id: "am-t0", frets: [nil, nil, nil, 2, 1, 0], fingers: [nil, nil, nil, 2, 1, nil], family: .triad, shapeName: "Root"),
         [nil, nil, nil, "R", "♭3", "5"], 1),
        (Voicing(id: "am-t1", frets: [nil, nil, nil, 5, 5, 5], fingers: [nil, nil, nil, 1, 1, 1],
                 barres: [.init(fret: 5, fromString: 3, toString: 5)], family: .triad, shapeName: "1st inv"),
         [nil, nil, nil, "♭3", "5", "R"], 5),
        (Voicing(id: "am-t2", frets: [nil, nil, nil, 9, 10, 8], fingers: [nil, nil, nil, 2, 3, 1], family: .triad, shapeName: "2nd inv"),
         [nil, nil, nil, "5", "R", "♭3"], 8),
    ]

    @Test func mockupVoicingsPlayAMinor() {
        for (voicing, roles, baseFret) in mockup {
            #expect(voicing.plays(am, in: .standard), "\(voicing.id)")
            #expect(voicing.roleLabels(for: am, in: .standard) == roles, "\(voicing.id)")
            #expect(voicing.baseFret == baseFret, "\(voicing.id)")
        }
    }

    @Test func inversionsHaveTheRightBass() {
        let bass = mockup.map { $0.0.bassNote(in: .standard)?.pitchClass }
        #expect(bass[3] == PitchClass(9))   // A
        #expect(bass[4] == PitchClass(0))   // C
        #expect(bass[5] == PitchClass(4))   // E
    }

    @Test func wrongShapesAreRejected() {
        let aMajor = Voicing(id: "a", frets: [nil, 0, 2, 2, 2, 0], fingers: [nil, nil, 1, 2, 3, nil], family: .full, shapeName: "Open")
        #expect(!aMajor.plays(am, in: .standard))
        #expect(aMajor.plays(Chord(.A, .major), in: .standard))

        let missingThird = Voicing(id: "x", frets: [nil, 0, 2, 2, 0, 0], fingers: [nil, nil, 1, 2, nil, nil], family: .full, shapeName: "?")
        #expect(!missingThird.plays(am, in: .standard))
    }

    @Test func voicingsDependOnTuning() {
        let open = mockup[0].0
        #expect(open.plays(am, in: .dropD))       // low string is muted, so Drop D changes nothing
        #expect(!open.plays(am, in: .halfStepDown))
    }
}
