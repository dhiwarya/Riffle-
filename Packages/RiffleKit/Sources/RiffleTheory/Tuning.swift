import Foundation

/// A six-string tuning. `strings[0]` is the lowest string (string 6), `strings[5]` the highest (string 1).
public struct Tuning: Identifiable, Hashable, Codable, Sendable {
    public static let stringCount = 6

    public var id: String
    public var name: String
    public var strings: [SpelledPitch]

    public init(id: String, name: String, strings: [SpelledPitch]) {
        precondition(strings.count == Self.stringCount, "A tuning needs six strings")
        self.id = id
        self.name = name
        self.strings = strings
    }

    public var notes: [Note] { strings.map(\.note) }

    /// Guitar string number for an index (index 0 → string 6).
    public static func stringNumber(forIndex index: Int) -> Int { stringCount - index }

    /// "E A D G B E".
    public var noteNamesLabel: String { strings.map(\.name.description).joined(separator: " ") }

    public var isStandard: Bool { notes == Tuning.standard.notes }

    /// How a player names a string in coaching text: "A string", or "low E string" / "high E string"
    /// when two strings share a note name.
    public func stringName(_ index: Int) -> String {
        let name = strings[index].name
        let same = strings.indices.filter { strings[$0].name == name }
        guard same.count > 1 else { return "\(name) string" }
        if index == same.first { return "low \(name) string" }
        if index == same.last { return "high \(name) string" }
        return "\(name) string"
    }

    public func frequencies(a4: Double = 440) -> [Double] { notes.map { $0.frequency(a4: a4) } }

    /// The string whose open note is closest to `frequency`, by absolute cents.
    public func nearestString(to frequency: Double, a4: Double = 440) -> (index: Int, cents: Double) {
        let candidates = notes.enumerated().map { ($0.offset, $0.element.cents(of: frequency, a4: a4)) }
        let best = candidates.min { abs($0.1) < abs($1.1) }!
        return (best.0, best.1)
    }

    // MARK: Presets

    private static func preset(_ id: String, _ name: String, _ notes: [String]) -> Tuning {
        Tuning(id: id, name: name, strings: notes.map { SpelledPitch($0)! })
    }

    public static let standard = preset("standard", "Standard", ["E2", "A2", "D3", "G3", "B3", "E4"])
    public static let dropD = preset("drop-d", "Drop D", ["D2", "A2", "D3", "G3", "B3", "E4"])
    public static let halfStepDown = preset("half-step-down", "Half step down", ["E♭2", "A♭2", "D♭3", "G♭3", "B♭3", "E♭4"])
    public static let fullStepDown = preset("full-step-down", "Full step down", ["D2", "G2", "C3", "F3", "A3", "D4"])
    public static let dropC = preset("drop-c", "Drop C", ["C2", "G2", "C3", "F3", "A3", "D4"])
    public static let openG = preset("open-g", "Open G", ["D2", "G2", "D3", "G3", "B3", "D4"])
    public static let openD = preset("open-d", "Open D", ["D2", "A2", "D3", "F♯3", "A3", "D4"])
    public static let openE = preset("open-e", "Open E", ["E2", "B2", "E3", "G♯3", "B3", "E4"])
    public static let openC = preset("open-c", "Open C", ["C2", "G2", "C3", "G3", "C4", "E4"])
    public static let dadgad = preset("dadgad", "DADGAD", ["D2", "A2", "D3", "G3", "A3", "D4"])

    public static let presets: [Tuning] = [
        .standard, .dropD, .halfStepDown, .fullStepDown, .dropC, .openG, .openD, .openE, .openC, .dadgad,
    ]

    public static func preset(id: String) -> Tuning? { presets.first { $0.id == id } }

    // MARK: Custom tunings

    /// How far a custom string may move from standard pitch, in semitones.
    public static let customRange = -5...5
    /// Above this many semitones over standard, warn about string tension.
    public static let tensionWarningThreshold = 2

    public struct Issue: Hashable, Sendable {
        public enum Kind: Hashable, Sendable { case tooLow, tooHigh, highTension }
        public let stringIndex: Int
        public let kind: Kind
        public var isBlocking: Bool { kind != .highTension }
    }

    /// Checks a custom tuning against the limits; `.highTension` is a warning, the others block saving.
    public static func issues(for strings: [SpelledPitch]) -> [Issue] {
        precondition(strings.count == stringCount, "A tuning needs six strings")
        return strings.enumerated().compactMap { index, pitch in
            let offset = pitch.note.midi - standard.notes[index].midi
            if offset < customRange.lowerBound { return Issue(stringIndex: index, kind: .tooLow) }
            if offset > customRange.upperBound { return Issue(stringIndex: index, kind: .tooHigh) }
            if offset > tensionWarningThreshold { return Issue(stringIndex: index, kind: .highTension) }
            return nil
        }
    }

    public static func custom(name: String, strings: [SpelledPitch]) -> Tuning {
        Tuning(id: "custom-" + UUID().uuidString, name: name, strings: strings)
    }
}
