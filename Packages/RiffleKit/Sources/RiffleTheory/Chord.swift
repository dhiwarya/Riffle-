import Foundation

public enum ChordQuality: String, CaseIterable, Codable, Sendable {
    case major, minor, power, sus2, sus4, diminished, augmented
    case dominant7, major7, minor7, halfDiminished7, diminished7
    case add9, major6, minor6, dominant9

    public var intervals: [Interval] {
        switch self {
        case .major: [.unison, .majorThird, .perfectFifth]
        case .minor: [.unison, .minorThird, .perfectFifth]
        case .power: [.unison, .perfectFifth]
        case .sus2: [.unison, .majorSecond, .perfectFifth]
        case .sus4: [.unison, .perfectFourth, .perfectFifth]
        case .diminished: [.unison, .minorThird, .diminishedFifth]
        case .augmented: [.unison, .majorThird, .augmentedFifth]
        case .dominant7: [.unison, .majorThird, .perfectFifth, .minorSeventh]
        case .major7: [.unison, .majorThird, .perfectFifth, .majorSeventh]
        case .minor7: [.unison, .minorThird, .perfectFifth, .minorSeventh]
        case .halfDiminished7: [.unison, .minorThird, .diminishedFifth, .minorSeventh]
        case .diminished7: [.unison, .minorThird, .diminishedFifth, .diminishedSeventh]
        case .add9: [.unison, .majorThird, .perfectFifth, .majorNinth]
        case .major6: [.unison, .majorThird, .perfectFifth, .majorSixth]
        case .minor6: [.unison, .minorThird, .perfectFifth, .majorSixth]
        case .dominant9: [.unison, .majorThird, .perfectFifth, .minorSeventh, .majorNinth]
        }
    }

    /// Tones a player may leave out and still count as the chord (the 5th in 4+ note chords).
    public var optionalIntervals: Set<Interval> {
        intervals.count >= 4 && intervals.contains(.perfectFifth) ? [.perfectFifth] : []
    }

    /// Suffix after the root: "", "m", "7", "m7♭5".
    public var symbol: String {
        switch self {
        case .major: ""
        case .minor: "m"
        case .power: "5"
        case .sus2: "sus2"
        case .sus4: "sus4"
        case .diminished: "dim"
        case .augmented: "aug"
        case .dominant7: "7"
        case .major7: "maj7"
        case .minor7: "m7"
        case .halfDiminished7: "m7♭5"
        case .diminished7: "dim7"
        case .add9: "add9"
        case .major6: "6"
        case .minor6: "m6"
        case .dominant9: "9"
        }
    }

    public var displayName: String {
        switch self {
        case .major: "major"
        case .minor: "minor"
        case .power: "power chord"
        case .sus2: "sus2"
        case .sus4: "sus4"
        case .diminished: "diminished"
        case .augmented: "augmented"
        case .dominant7: "dominant 7th"
        case .major7: "major 7th"
        case .minor7: "minor 7th"
        case .halfDiminished7: "half-diminished"
        case .diminished7: "diminished 7th"
        case .add9: "add 9"
        case .major6: "6th"
        case .minor6: "minor 6th"
        case .dominant9: "9th"
        }
    }

    /// Short category for the chord card, e.g. "Minor triad", "Seventh chord".
    public var kindLabel: String {
        switch self {
        case .major: "Major triad"
        case .minor: "Minor triad"
        case .diminished: "Diminished triad"
        case .augmented: "Augmented triad"
        case .power: "Power chord"
        case .sus2, .sus4: "Suspended chord"
        case .dominant7, .major7, .minor7, .halfDiminished7, .diminished7: "Seventh chord"
        case .add9, .major6, .minor6, .dominant9: "Colour chord"
        }
    }

    private static let aliases: [String: ChordQuality] = [
        "": .major, "M": .major, "maj": .major,
        "m": .minor, "min": .minor, "-": .minor,
        "5": .power,
        "sus2": .sus2, "sus4": .sus4, "sus": .sus4,
        "dim": .diminished, "°": .diminished,
        "aug": .augmented, "+": .augmented,
        "7": .dominant7,
        "maj7": .major7, "M7": .major7, "Δ7": .major7, "Δ": .major7,
        "m7": .minor7, "min7": .minor7, "-7": .minor7,
        "m7♭5": .halfDiminished7, "m7b5": .halfDiminished7, "ø": .halfDiminished7, "ø7": .halfDiminished7,
        "dim7": .diminished7, "°7": .diminished7,
        "add9": .add9, "6": .major6, "m6": .minor6, "9": .dominant9,
    ]

    public init?(symbol: String) {
        guard let quality = Self.aliases[symbol] else { return nil }
        self = quality
    }
}

public struct ChordTone: Hashable, Sendable {
    public let interval: Interval
    public let note: SpelledNote
    public let isOptional: Bool

    /// "R", "♭3", "5".
    public var role: String { interval.chordRoleLabel }
}

public struct Chord: Hashable, Codable, Sendable, CustomStringConvertible {
    public var root: SpelledNote
    public var quality: ChordQuality

    public init(_ root: SpelledNote, _ quality: ChordQuality) {
        self.root = root
        self.quality = quality
    }

    /// Parses "Am", "F#m7", "B♭", "Bbmaj7", "Dsus4", "Bm7b5".
    public init?(symbol: String) {
        let text = symbol.trimmingCharacters(in: .whitespaces)
        guard let first = text.first else { return nil }
        var rootEnd = text.index(after: text.startIndex)
        // Accidentals belong to the root; a "b" after the letter is a flat (Bb, Eb).
        while rootEnd < text.endIndex, ["#", "♯", "b", "♭"].contains(text[rootEnd]) {
            rootEnd = text.index(after: rootEnd)
        }
        guard let root = SpelledNote(String(first) + text[text.index(after: text.startIndex)..<rootEnd]),
              let quality = ChordQuality(symbol: String(text[rootEnd...])) else { return nil }
        self.init(root, quality)
    }

    /// "Am", "F♯m7", "B♭".
    public var symbol: String { root.description + quality.symbol }

    /// "A minor", "C major 7th".
    public var name: String { "\(root) \(quality.displayName)" }

    public var tones: [ChordTone] {
        quality.intervals.map {
            ChordTone(interval: $0, note: root.adding($0), isOptional: quality.optionalIntervals.contains($0))
        }
    }

    public var pitchClasses: Set<PitchClass> { Set(tones.map(\.note.pitchClass)) }

    /// Pitch classes that must sound for the chord to count.
    public var requiredPitchClasses: Set<PitchClass> {
        Set(tones.filter { !$0.isOptional }.map(\.note.pitchClass))
    }

    /// The tone a pitch class plays in this chord, if any.
    public func tone(for pitchClass: PitchClass) -> ChordTone? {
        tones.first { $0.note.pitchClass == pitchClass }
    }

    public var description: String { symbol }
}
