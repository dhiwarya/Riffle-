public enum ScaleType: String, CaseIterable, Codable, Sendable {
    case major, naturalMinor, harmonicMinor, majorPentatonic, minorPentatonic, blues, dorian, mixolydian
    /// All 12 degrees inside a key (1 ♭2 2 ♭3 3 4 ♯4 5 ♭6 6 ♭7 7), used by the Hard ear check level.
    case chromatic

    public var intervals: [Interval] {
        switch self {
        case .major: [.unison, .majorSecond, .majorThird, .perfectFourth, .perfectFifth, .majorSixth, .majorSeventh]
        case .naturalMinor: [.unison, .majorSecond, .minorThird, .perfectFourth, .perfectFifth, .minorSixth, .minorSeventh]
        case .harmonicMinor: [.unison, .majorSecond, .minorThird, .perfectFourth, .perfectFifth, .minorSixth, .majorSeventh]
        case .majorPentatonic: [.unison, .majorSecond, .majorThird, .perfectFifth, .majorSixth]
        case .minorPentatonic: [.unison, .minorThird, .perfectFourth, .perfectFifth, .minorSeventh]
        case .blues: [.unison, .minorThird, .perfectFourth, .diminishedFifth, .perfectFifth, .minorSeventh]
        case .dorian: [.unison, .majorSecond, .minorThird, .perfectFourth, .perfectFifth, .majorSixth, .minorSeventh]
        case .mixolydian: [.unison, .majorSecond, .majorThird, .perfectFourth, .perfectFifth, .majorSixth, .minorSeventh]
        case .chromatic: [.unison, .minorSecond, .majorSecond, .minorThird, .majorThird, .perfectFourth,
                          .augmentedFourth, .perfectFifth, .minorSixth, .majorSixth, .minorSeventh, .majorSeventh]
        }
    }

    public var displayName: String {
        switch self {
        case .major: "major"
        case .naturalMinor: "minor"
        case .harmonicMinor: "harmonic minor"
        case .majorPentatonic: "major pentatonic"
        case .minorPentatonic: "minor pentatonic"
        case .blues: "blues"
        case .dorian: "dorian"
        case .mixolydian: "mixolydian"
        case .chromatic: "chromatic"
        }
    }
}

/// One degree of a scale: its interval from the tonic and the spelled note.
public struct ScaleDegree: Hashable, Sendable {
    public let interval: Interval
    public let note: SpelledNote

    public var label: String { interval.degreeLabel }
}

public struct Scale: Hashable, Codable, Sendable, CustomStringConvertible {
    public var root: SpelledNote
    public var type: ScaleType

    public init(root: SpelledNote, type: ScaleType) {
        self.root = root
        self.type = type
    }

    public var degrees: [ScaleDegree] {
        type.intervals.map { ScaleDegree(interval: $0, note: root.adding($0)) }
    }

    public var notes: [SpelledNote] { degrees.map(\.note) }

    public func contains(_ pitchClass: PitchClass) -> Bool {
        notes.contains { $0.pitchClass == pitchClass }
    }

    /// The degree a pitch class plays in this scale, if any.
    public func degree(of pitchClass: PitchClass) -> ScaleDegree? {
        degrees.first { $0.note.pitchClass == pitchClass }
    }

    /// "C major", "A minor pentatonic".
    public var description: String { "\(root) \(type.displayName)" }
}

/// A key: tonic plus major/minor mode. Drives ear-check context and note spelling.
public struct Key: Hashable, Codable, Sendable, CustomStringConvertible {
    public enum Mode: String, Codable, Sendable, CaseIterable { case major, minor }

    public var tonic: SpelledNote
    public var mode: Mode

    public init(_ tonic: SpelledNote, _ mode: Mode = .major) {
        self.tonic = tonic
        self.mode = mode
    }

    public var scale: Scale { Scale(root: tonic, type: mode == .major ? .major : .naturalMinor) }

    /// Degrees available in-key, including the chromatic ones for the Hard level.
    public var chromaticScale: Scale { Scale(root: tonic, type: .chromatic) }

    /// I–IV–V–I in major, i–iv–V–i in minor (harmonic-minor V so the key is unambiguous).
    public var cadence: [Chord] {
        let four = tonic.adding(.perfectFourth)
        let five = tonic.adding(.perfectFifth)
        switch mode {
        case .major:
            return [Chord(tonic, .major), Chord(four, .major), Chord(five, .major), Chord(tonic, .major)]
        case .minor:
            return [Chord(tonic, .minor), Chord(four, .minor), Chord(five, .major), Chord(tonic, .minor)]
        }
    }

    /// Flats for flat keys (F, B♭, D minor…), sharps otherwise.
    public var accidentalPreference: AccidentalPreference {
        scale.notes.contains { $0.accidental == .flat || $0.accidental == .doubleFlat } ? .flats : .sharps
    }

    public var description: String { "\(tonic) \(mode.rawValue)" }
}
