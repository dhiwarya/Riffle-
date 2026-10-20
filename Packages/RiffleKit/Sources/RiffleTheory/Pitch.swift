import Foundation

/// One of the 12 pitch classes, 0 = C … 11 = B. Octave-less.
public struct PitchClass: Hashable, Comparable, Codable, Sendable, CustomStringConvertible {
    public let rawValue: Int

    public init(_ value: Int) {
        rawValue = ((value % 12) + 12) % 12
    }

    public static func + (lhs: PitchClass, semitones: Int) -> PitchClass {
        PitchClass(lhs.rawValue + semitones)
    }

    /// Upward distance in semitones from `other` to `self` (0…11).
    public func semitones(above other: PitchClass) -> Int {
        PitchClass(rawValue - other.rawValue).rawValue
    }

    public static func < (lhs: PitchClass, rhs: PitchClass) -> Bool { lhs.rawValue < rhs.rawValue }

    public var description: String { SpelledNote.preferred(for: self, preference: .sharps).description }

    public static let all: [PitchClass] = (0..<12).map(PitchClass.init)
}

/// The seven natural note letters.
public enum Letter: Int, CaseIterable, Codable, Sendable {
    case C, D, E, F, G, A, B

    public var naturalPitchClass: PitchClass {
        PitchClass([0, 2, 4, 5, 7, 9, 11][rawValue])
    }

    public func advanced(by steps: Int) -> Letter {
        Letter(rawValue: ((rawValue + steps) % 7 + 7) % 7)!
    }

    public var name: String { String(describing: self) }
}

public enum Accidental: Int, CaseIterable, Codable, Sendable {
    case doubleFlat = -2, flat = -1, natural = 0, sharp = 1, doubleSharp = 2

    public var symbol: String {
        switch self {
        case .doubleFlat: "𝄫"
        case .flat: "♭"
        case .natural: ""
        case .sharp: "♯"
        case .doubleSharp: "𝄪"
        }
    }
}

public enum AccidentalPreference: String, Codable, Sendable, CaseIterable {
    case sharps, flats
}

/// A note name with correct spelling (letter + accidental), e.g. B♭ rather than A♯.
public struct SpelledNote: Hashable, Codable, Sendable, CustomStringConvertible {
    public var letter: Letter
    public var accidental: Accidental

    public init(_ letter: Letter, _ accidental: Accidental = .natural) {
        self.letter = letter
        self.accidental = accidental
    }

    /// Parses "C", "F#", "F♯", "Bb", "B♭", "Ebb", "C##".
    public init?(_ text: String) {
        var chars = Substring(text.trimmingCharacters(in: .whitespaces))
        guard let first = chars.first, let letter = Letter.allCases.first(where: { $0.name == String(first).uppercased() }) else {
            return nil
        }
        chars = chars.dropFirst()
        var offset = 0
        for c in chars {
            switch c {
            case "#", "♯": offset += 1
            case "b", "♭": offset -= 1
            case "𝄪": offset += 2
            case "𝄫": offset -= 2
            default: return nil
            }
        }
        guard let accidental = Accidental(rawValue: offset) else { return nil }
        self.init(letter, accidental)
    }

    public var pitchClass: PitchClass { letter.naturalPitchClass + accidental.rawValue }

    public var description: String { letter.name + accidental.symbol }

    /// The note `interval` above this one, spelled by letter distance (A + ♭3 = C, F + 4 = B♭).
    public func adding(_ interval: Interval) -> SpelledNote {
        let targetLetter = letter.advanced(by: interval.number - 1)
        let wanted = pitchClass + interval.semitones
        var diff = wanted.rawValue - targetLetter.naturalPitchClass.rawValue
        if diff > 6 { diff -= 12 }
        if diff < -6 { diff += 12 }
        if let accidental = Accidental(rawValue: diff) {
            return SpelledNote(targetLetter, accidental)
        }
        return SpelledNote.preferred(for: wanted, preference: .sharps)
    }

    /// Plain spelling of a pitch class when there is no key context.
    public static func preferred(for pitchClass: PitchClass, preference: AccidentalPreference) -> SpelledNote {
        let sharps: [SpelledNote] = [.C, .Cs, .D, .Ds, .E, .F, .Fs, .G, .Gs, .A, .As, .B]
        let flats: [SpelledNote] = [.C, .Db, .D, .Eb, .E, .F, .Gb, .G, .Ab, .A, .Bb, .B]
        return (preference == .sharps ? sharps : flats)[pitchClass.rawValue]
    }

    public static let C = SpelledNote(.C), D = SpelledNote(.D), E = SpelledNote(.E), F = SpelledNote(.F)
    public static let G = SpelledNote(.G), A = SpelledNote(.A), B = SpelledNote(.B)
    public static let Cs = SpelledNote(.C, .sharp), Ds = SpelledNote(.D, .sharp), Fs = SpelledNote(.F, .sharp)
    public static let Gs = SpelledNote(.G, .sharp), As = SpelledNote(.A, .sharp)
    public static let Db = SpelledNote(.D, .flat), Eb = SpelledNote(.E, .flat), Gb = SpelledNote(.G, .flat)
    public static let Ab = SpelledNote(.A, .flat), Bb = SpelledNote(.B, .flat)
}

/// A concrete pitch as a MIDI note number (60 = C4, 69 = A4).
public struct Note: Hashable, Comparable, Codable, Sendable {
    public let midi: Int

    public init(midi: Int) { self.midi = midi }

    public var pitchClass: PitchClass { PitchClass(midi) }
    /// Scientific octave (C4 = middle C).
    public var octave: Int { Int((Double(midi) / 12).rounded(.down)) - 1 }

    public func frequency(a4: Double = 440) -> Double {
        PitchMath.frequency(midi: Double(midi), a4: a4)
    }

    public func transposed(by semitones: Int) -> Note { Note(midi: midi + semitones) }

    /// Cents from this note to `frequency` (negative = flat).
    public func cents(of frequency: Double, a4: Double = 440) -> Double {
        PitchMath.cents(frequency, relativeTo: self.frequency(a4: a4))
    }

    /// The nearest equal-tempered note to `frequency` and how far off it is.
    public static func nearest(to frequency: Double, a4: Double = 440) -> (note: Note, cents: Double) {
        let exact = PitchMath.midi(frequency: frequency, a4: a4)
        let note = Note(midi: Int(exact.rounded()))
        return (note, (exact - Double(note.midi)) * 100)
    }

    public func spelled(_ preference: AccidentalPreference = .sharps) -> SpelledPitch {
        SpelledPitch(SpelledNote.preferred(for: pitchClass, preference: preference), octave: octave)
    }

    public static func < (lhs: Note, rhs: Note) -> Bool { lhs.midi < rhs.midi }
}

/// A spelled note in a specific octave, e.g. E♭2.
public struct SpelledPitch: Hashable, Codable, Sendable, CustomStringConvertible {
    public var name: SpelledNote
    public var octave: Int

    public init(_ name: SpelledNote, octave: Int) {
        self.name = name
        self.octave = octave
    }

    /// Parses "E2", "Eb2", "F♯3".
    public init?(_ text: String) {
        guard let digitIndex = text.firstIndex(where: { $0.isNumber || $0 == "-" }),
              let octave = Int(text[digitIndex...]),
              let name = SpelledNote(String(text[..<digitIndex])) else { return nil }
        self.init(name, octave: octave)
    }

    /// Octave follows the letter, so C♭4 is MIDI 59 (B3) and B♯3 is MIDI 60.
    public var note: Note {
        Note(midi: (octave + 1) * 12 + name.letter.naturalPitchClass.rawValue + name.accidental.rawValue)
    }

    public var description: String { "\(name)\(octave)" }
}

public enum PitchMath {
    public static func frequency(midi: Double, a4: Double = 440) -> Double {
        a4 * pow(2, (midi - 69) / 12)
    }

    public static func midi(frequency: Double, a4: Double = 440) -> Double {
        69 + 12 * log2(frequency / a4)
    }

    public static func cents(_ frequency: Double, relativeTo reference: Double) -> Double {
        1200 * log2(frequency / reference)
    }
}
