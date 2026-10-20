import Testing
@testable import RiffleTheory

struct IntervalTests {
    @Test func degreeLabels() {
        #expect(Interval.unison.degreeLabel == "1")
        #expect(Interval.minorThird.degreeLabel == "♭3")
        #expect(Interval.majorThird.degreeLabel == "3")
        #expect(Interval.augmentedFourth.degreeLabel == "♯4")
        #expect(Interval.diminishedFifth.degreeLabel == "♭5")
        #expect(Interval.diminishedSeventh.degreeLabel == "𝄫7")
        #expect(Interval.majorNinth.degreeLabel == "9")
    }

    @Test func chordAndSlotLabels() {
        #expect(Interval.unison.chordRoleLabel == "R")
        #expect(Interval.unison.slotLabel == "ROOT")
        #expect(Interval.minorThird.slotLabel == "♭3RD")
        #expect(Interval.perfectFifth.slotLabel == "5TH")
        #expect(Interval.majorSecond.slotLabel == "2ND")
        #expect(Interval.majorNinth.slotLabel == "9TH")
        #expect(Interval(number: 11, semitones: 17).slotLabel == "11TH")
    }
}

struct ScaleTests {
    private func names(_ scale: Scale) -> [String] { scale.notes.map(\.description) }

    @Test func majorScalesAreSpelledForTheirKey() {
        #expect(names(Scale(root: .C, type: .major)) == ["C", "D", "E", "F", "G", "A", "B"])
        #expect(names(Scale(root: .G, type: .major)) == ["G", "A", "B", "C", "D", "E", "F♯"])
        #expect(names(Scale(root: .F, type: .major)) == ["F", "G", "A", "B♭", "C", "D", "E"])
        #expect(names(Scale(root: .Db, type: .major)) == ["D♭", "E♭", "F", "G♭", "A♭", "B♭", "C"])
    }

    @Test func otherScales() {
        #expect(names(Scale(root: .A, type: .minorPentatonic)) == ["A", "C", "D", "E", "G"])
        #expect(names(Scale(root: .A, type: .naturalMinor)) == ["A", "B", "C", "D", "E", "F", "G"])
        #expect(names(Scale(root: .A, type: .harmonicMinor)).last == "G♯")
        #expect(names(Scale(root: .E, type: .blues)) == ["E", "G", "A", "B♭", "B", "D"])
        #expect(Scale(root: .C, type: .chromatic).notes.count == 12)
        #expect(Scale(root: .C, type: .chromatic).degrees.map(\.label)
            == ["1", "♭2", "2", "♭3", "3", "4", "♯4", "5", "♭6", "6", "♭7", "7"])
        #expect(Scale(root: .A, type: .minorPentatonic).description == "A minor pentatonic")
    }

    @Test func degreeLookup() {
        let g = Scale(root: .G, type: .major)
        #expect(g.degree(of: PitchClass(6))?.label == "7")
        #expect(g.degree(of: PitchClass(5)) == nil)
        #expect(g.contains(PitchClass(6)))
    }

    @Test func keyCadencesAndSpelling() {
        #expect(Key(.C).cadence.map(\.symbol) == ["C", "F", "G", "C"])
        #expect(Key(.A, .minor).cadence.map(\.symbol) == ["Am", "Dm", "E", "Am"])
        #expect(Key(.F).accidentalPreference == .flats)
        #expect(Key(.G).accidentalPreference == .sharps)
        #expect(Key(.D, .minor).accidentalPreference == .flats)
        #expect(Key(.C).accidentalPreference == .sharps)
    }
}
