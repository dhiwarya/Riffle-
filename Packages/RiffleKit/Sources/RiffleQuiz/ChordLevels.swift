import RiffleTheory

/// One thing to play in the chord quiz: a chord, or (level 5) a triad in a given inversion.
public struct ChordItem: Hashable, Sendable, Identifiable {
    public var chord: Chord
    /// 0 = root position, 1 = 3rd in the bass, 2 = 5th in the bass. `nil` = any voicing.
    public var inversion: Int?
    /// The lowest note must be the root (power chords, level 3).
    public var rootInBass: Bool

    public init(_ chord: Chord, inversion: Int? = nil, rootInBass: Bool = false) {
        self.chord = chord
        self.inversion = inversion
        self.rootInBass = rootInBass
    }

    public init?(_ symbol: String, inversion: Int? = nil, rootInBass: Bool = false) {
        guard let chord = Chord(symbol: symbol) else { return nil }
        self.init(chord, inversion: inversion, rootInBass: rootInBass)
    }

    public var id: String { key }

    /// Stable key for the skill model (plan §8.1): "chord:Am", "triad:C/1".
    public var key: String {
        if let inversion { return "triad:\(chord.symbol)/\(inversion)" }
        return "chord:\(chord.symbol)"
    }

    /// The pitch class that has to be lowest, if the item checks the bass.
    public var requiredBass: PitchClass? {
        if let inversion { return chord.tones[inversion % chord.tones.count].note.pitchClass }
        return rootInBass ? chord.root.pitchClass : nil
    }

    /// Line under the big chord name: "A minor — any voicing counts".
    public var subtitle: String {
        switch inversion {
        case 0: "\(chord.name) — root position triad"
        case 1: "\(chord.name) — 1st inversion, \(chord.tones[1].note) lowest"
        case 2: "\(chord.name) — 2nd inversion, \(chord.tones[2].note) lowest"
        default: rootInBass ? "\(chord.name) — root as the lowest note" : "\(chord.name) — any voicing counts"
        }
    }

    /// Chip on the chord card: "Minor triad", "1st inversion".
    public var kindLabel: String {
        switch inversion {
        case 0: "Root position"
        case 1: "1st inversion"
        case 2: "2nd inversion"
        default: chord.quality.kindLabel
        }
    }
}

/// The default level ladder (plan §6.5). Personalisation (M5) moves people up and down it.
public enum ChordLevels {
    public static let range = 1...7

    public static func title(_ level: Int) -> String {
        switch level {
        case 1: "Open majors & minors"
        case 2: "Sevenths & sus chords"
        case 3: "Power chords"
        case 4: "Barre chords"
        case 5: "Triads & inversions"
        case 6: "Seventh chords"
        default: "Colour chords"
        }
    }

    public static func items(level: Int) -> [ChordItem] {
        switch min(max(level, range.lowerBound), range.upperBound) {
        case 1: symbols("E A D G C Em Am Dm")
        case 2: symbols("E7 A7 D7 G7 B7 C7 Dsus2 Dsus4 Asus2 Asus4")
        case 3: symbols("E5 F5 G5 A5 B5 C5 D5", rootInBass: true)
        case 4: symbols("F Bm B♭ F♯m B Cm Gm C♯m")
        case 5: ["C", "G", "D", "A", "E", "Am", "Em", "Dm"].flatMap { symbol in
                (0..<3).compactMap { ChordItem(symbol, inversion: $0) }
            }
        case 6: symbols("Cmaj7 Fmaj7 Dmaj7 Am7 Dm7 Em7 Bm7♭5 Bdim7")
        default: symbols("Cadd9 C6 A6 Am6 C9 D9")
        }
    }

    /// Today's chords: `count` distinct items from the level, the same all day for a given seed.
    public static func dailyItems(level: Int, count: Int, seed: UInt64) -> [ChordItem] {
        var random = SeededRandom(seed: seed &* 0x2545_F491_4F6C_DD1D &+ UInt64(level))
        return Array(items(level: level).shuffled(using: &random).prefix(count))
    }

    private static func symbols(_ list: String, rootInBass: Bool = false) -> [ChordItem] {
        list.split(separator: " ").compactMap { ChordItem(String($0), rootInBass: rootInBass) }
    }
}
