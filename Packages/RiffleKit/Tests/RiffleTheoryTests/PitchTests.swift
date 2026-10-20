import Testing
@testable import RiffleTheory

struct PitchTests {
    @Test func pitchClassWrapsBothWays() {
        #expect(PitchClass(12).rawValue == 0)
        #expect(PitchClass(-1).rawValue == 11)
        #expect((PitchClass(10) + 5).rawValue == 3)
        #expect(PitchClass(2).semitones(above: PitchClass(11)) == 3)
    }

    @Test(arguments: [
        ("C", "C"), ("F#", "F♯"), ("F♯", "F♯"), ("Bb", "B♭"), ("b♭", "B♭"), ("Ebb", "E𝄫"), ("C##", "C𝄪"),
    ])
    func parsesNoteNames(input: String, expected: String) {
        #expect(SpelledNote(input)?.description == expected)
    }

    @Test(arguments: ["", "H", "C#b#x", "Cbbb"])
    func rejectsBadNoteNames(input: String) {
        #expect(SpelledNote(input) == nil)
    }

    @Test func spellsByLetterDistance() {
        #expect(SpelledNote.A.adding(.minorThird) == .C)
        #expect(SpelledNote.A.adding(.majorThird) == .Cs)
        #expect(SpelledNote.F.adding(.perfectFourth) == .Bb)
        #expect(SpelledNote.B.adding(.diminishedSeventh) == SpelledNote(.A, .flat))
        #expect(SpelledNote.Fs.adding(.minorThird) == .A)
        #expect(SpelledNote.Db.adding(.majorThird) == .F)
    }

    @Test func midiNotesHaveOctavesAndFrequencies() {
        let a4 = Note(midi: 69)
        #expect(a4.octave == 4)
        #expect(a4.frequency() == 440)
        #expect(abs(Note(midi: 40).frequency() - 82.4069) < 0.001)
        #expect(abs(Note(midi: 69).frequency(a4: 432) - 432) < 1e-9)
        #expect(Note(midi: 0).octave == -1)
    }

    @Test func nearestNoteAndCents() {
        let (note, cents) = Note.nearest(to: 445)
        #expect(note.midi == 69)
        #expect(abs(cents - 19.56) < 0.01)

        // 81 Hz is ~30 cents flat of E2 (82.41 Hz); 80 Hz would already be nearer D♯2.
        let (low, lowCents) = Note.nearest(to: 81)
        #expect(low.midi == 40)
        #expect(abs(lowCents + 29.9) < 0.1)
    }

    @Test func centsBetweenFrequencies() {
        #expect(abs(PitchMath.cents(880, relativeTo: 440) - 1200) < 1e-9)
        #expect(abs(Note(midi: 40).cents(of: 82.41 * pow(2, -10.0 / 1200)) + 10) < 0.1)
    }

    @Test func spelledPitchToMidi() {
        #expect(SpelledPitch("E2")?.note.midi == 40)
        #expect(SpelledPitch("C4")?.note.midi == 60)
        #expect(SpelledPitch("E♭2")?.note.midi == 39)
        #expect(SpelledPitch("Cb4")?.note.midi == 59)
        #expect(SpelledPitch("B#3")?.note.midi == 60)
        #expect(SpelledPitch("E")  == nil)
        #expect(Note(midi: 61).spelled(.flats).description == "D♭4")
    }
}

import Foundation
