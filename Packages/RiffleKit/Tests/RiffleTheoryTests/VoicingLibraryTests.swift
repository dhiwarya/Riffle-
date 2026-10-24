import Testing
@testable import RiffleTheory

struct VoicingLibraryTests {
    @Test func everyOpenShapePlaysItsChord() throws {
        for shape in VoicingLibrary.openShapes {
            let chord = try #require(Chord(symbol: shape.symbol), "\(shape.symbol)")
            let voicing = shape.voicing(for: chord)
            #expect(voicing.plays(chord, in: .standard), "\(shape.symbol)")
            #expect(voicing.bassNote(in: .standard)?.pitchClass == chord.root.pitchClass, "\(shape.symbol) root in bass")
            // A finger on every fretted string, none on open or muted ones.
            for (fret, finger) in zip(voicing.frets, voicing.fingers) {
                #expect(((fret ?? 0) > 0) == (finger != nil), "\(shape.symbol) fingers")
            }
        }
    }

    @Test func movableShapesPlayEveryRoot() {
        for shape in VoicingLibrary.movableShapes {
            for quality in shape.qualities {
                for pc in PitchClass.all {
                    let chord = Chord(.preferred(for: pc, preference: .sharps), quality)
                    guard let voicing = shape.voicing(for: chord) else { continue }
                    #expect(voicing.plays(chord, in: .standard), "\(chord) \(shape.kind)")
                    #expect(voicing.bassNote(in: .standard)?.pitchClass == chord.root.pitchClass, "\(chord) \(shape.kind)")
                    #expect(voicing.frets.compactMap { $0 }.allSatisfy { $0 >= 1 }, "\(chord) \(shape.kind) no open strings")
                }
            }
        }
    }

    /// The reveal screen in the mockup: Open, E shape at 5, A shape at 12; triads 2-1-0, 5-5-5, 9-10-8.
    @Test func aMinorMatchesTheMockup() throws {
        let am = try #require(Chord(symbol: "Am"))
        let set = VoicingLibrary.voicings(for: am, in: .standard)
        #expect(set.full.map(\.shapeName) == ["Open", "E shape", "A shape"])
        #expect(set.full.map(\.frets) == [[nil, 0, 2, 2, 1, 0], [5, 7, 7, 5, 5, 5], [nil, 12, 14, 14, 13, 12]])
        #expect(set.full[1].barres == [Voicing.Barre(fret: 5, fromString: 0, toString: 5)])
        #expect(set.full[2].barres == [Voicing.Barre(fret: 12, fromString: 1, toString: 5)])
        #expect(set.triads.map(\.shapeName) == ["Root", "1st inv", "2nd inv"])
        #expect(set.triads.map(\.frets) == [[nil, nil, nil, 2, 1, 0], [nil, nil, nil, 5, 5, 5], [nil, nil, nil, 9, 10, 8]])
        #expect(set.triads.map(\.fingers) == [[nil, nil, nil, 2, 1, nil], [nil, nil, nil, 1, 1, 1], [nil, nil, nil, 2, 3, 1]])
        #expect(set.triads[1].barres == [Voicing.Barre(fret: 5, fromString: 3, toString: 5)])
        #expect(set.triads[0].tip == "A C E, low to high, on the top three strings. Only strum G, B and E.")
        #expect(set.triads[1].tip == "C E A: the 3rd is now lowest. One finger flat across the 5th fret.")
    }

    @Test func triadInversionsPutTheRightToneInTheBass() throws {
        for symbol in ["C", "G", "D", "A", "E", "F", "Am", "Em", "Dm", "Bdim", "Caug", "Dsus4"] {
            let chord = try #require(Chord(symbol: symbol))
            let triads = VoicingGenerator.triads(for: chord, in: .standard)
            #expect(triads.count == 3, "\(symbol)")
            for (inversion, triad) in triads.enumerated() {
                #expect(triad.plays(chord, in: .standard), "\(symbol) \(inversion)")
                #expect(triad.bassNote(in: .standard)?.pitchClass == chord.tones[inversion].note.pitchClass, "\(symbol) \(inversion)")
                let frets = triad.frets.compactMap { $0 }
                #expect(frets.max()! - frets.min()! <= 3, "\(symbol) \(inversion) span")
            }
        }
        let c7 = try #require(Chord(symbol: "C7"))
        #expect(VoicingGenerator.triads(for: c7, in: .standard).isEmpty)
    }

    /// Every chord the quiz can ask for has something to show in every preset tuning.
    @Test func generatorCoversAlternateTunings() throws {
        let symbols = "E A D G C Em Am Dm E7 A7 D7 G7 B7 C7 Dsus2 Dsus4 Asus2 Asus4 E5 F5 G5 A5 B5 C5 D5 F Bm B♭ F♯m B Cm Gm C♯m Cmaj7 Fmaj7 Dmaj7 Am7 Dm7 Em7 Bm7♭5 Bdim7 Cadd9 C6 A6 Am6 C9 D9"
        for tuning in Tuning.presets {
            for symbol in symbols.split(separator: " ") {
                let chord = try #require(Chord(symbol: String(symbol)), "\(symbol)")
                let set = VoicingLibrary.voicings(for: chord, in: tuning)
                #expect(!set.full.isEmpty, "\(symbol) in \(tuning.name)")
                for voicing in set.all {
                    #expect(voicing.plays(chord, in: tuning), "\(voicing.id) in \(tuning.name)")
                    #expect(VoicingGenerator.fingersNeeded(voicing.frets).map { $0 <= 4 } ?? false
                            || voicing.barres.count == 1, "\(voicing.id) fingers")
                }
            }
        }
    }

    @Test func generatorFindsOpenGShapesInOpenG() throws {
        let g = try #require(Chord(symbol: "G"))
        let first = try #require(VoicingGenerator.fullVoicings(for: g, in: .openG).first)
        // Open G: strum the open strings (the low D is the 5th, so the root-position shape starts on string 5).
        #expect(first.frets == [nil, 0, 0, 0, 0, 0])
        #expect(first.shapeName == "Open")
    }

    @Test func fingerAssignmentBarresWhenNeeded() {
        let (fingers, barres) = VoicingGenerator.assignFingers([1, 3, 3, 2, 1, 1])
        #expect(barres == [Voicing.Barre(fret: 1, fromString: 0, toString: 5)])
        #expect(fingers == [1, 3, 4, 2, 1, 1])
        #expect(VoicingGenerator.fingersNeeded([1, 3, 3, 2, 1, 1]) == 4)
        #expect(VoicingGenerator.fingersNeeded([nil, 3, 2, 0, 1, 0]) == 3)
        // Five fretted notes with an open string under the would-be barre: not playable.
        #expect(VoicingGenerator.fingersNeeded([1, 0, 3, 2, 1, 1]) == nil)
    }

    @Test func stringNames() {
        #expect(Tuning.standard.stringName(0) == "low E string")
        #expect(Tuning.standard.stringName(1) == "A string")
        #expect(Tuning.standard.stringName(4) == "B string")
        #expect(Tuning.standard.stringName(5) == "high E string")
        #expect(Tuning.openD.stringName(0) == "low D string")
        #expect(Tuning.openD.stringName(2) == "D string")
        #expect(Tuning.openD.stringName(5) == "high D string")
        #expect(Tuning.dropD.stringName(0) == "low D string")
        #expect(Tuning.dropD.stringName(2) == "high D string")
    }

    @Test func strumPhraseRunsLowToHigh() throws {
        let chord = try #require(Chord(symbol: "Am"))
        let am = try #require(VoicingLibrary.voicings(for: chord, in: .standard).full.first)
        let phrase = Phrase.strum(am, in: .standard)
        #expect(phrase.notes.map(\.midi) == [45, 52, 57, 60, 64])
        #expect(zip(phrase.notes.map(\.offset), [0, 0.045, 0.09, 0.135, 0.18]).allSatisfy { abs($0 - $1) < 1e-9 })
    }

    @Test func ordinals() {
        #expect([1, 2, 3, 4, 11, 12, 13, 21, 22].map(ordinal) == ["1st", "2nd", "3rd", "4th", "11th", "12th", "13th", "21st", "22nd"])
    }
}
