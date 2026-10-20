/// One way to finger a chord on six strings. Arrays run low string → high string, like `Tuning.strings`.
public struct Voicing: Identifiable, Hashable, Codable, Sendable {
    public enum Family: String, Codable, Sendable { case full, triad }

    public struct Barre: Hashable, Codable, Sendable {
        public var fret: Int
        /// String indexes covered, inclusive (0 = low E).
        public var fromString: Int
        public var toString: Int
        public var finger: Int

        public init(fret: Int, fromString: Int, toString: Int, finger: Int = 1) {
            self.fret = fret
            self.fromString = fromString
            self.toString = toString
            self.finger = finger
        }
    }

    public var id: String
    /// `nil` = muted string, 0 = open string.
    public var frets: [Int?]
    /// Finger per string (1 = index … 4 = pinky), `nil` for open or muted strings.
    public var fingers: [Int?]
    public var barres: [Barre]
    public var family: Family
    /// "Open", "E shape", "1st inv".
    public var shapeName: String
    public var tip: String?

    public init(id: String, frets: [Int?], fingers: [Int?], barres: [Barre] = [], family: Family,
                shapeName: String, tip: String? = nil) {
        precondition(frets.count == Tuning.stringCount && fingers.count == Tuning.stringCount,
                     "Voicings describe all six strings")
        self.id = id
        self.frets = frets
        self.fingers = fingers
        self.barres = barres
        self.family = family
        self.shapeName = shapeName
        self.tip = tip
    }

    /// First fret shown in a diagram: 1 when the shape fits in the first four frets, else the lowest fretted note.
    public var baseFret: Int {
        let fretted = frets.compactMap { $0 }.filter { $0 > 0 }
        guard let low = fretted.min(), let high = fretted.max() else { return 1 }
        return high <= 4 ? 1 : low
    }

    public func notes(in tuning: Tuning) -> [Note?] {
        zip(frets, tuning.notes).map { fret, open in fret.map { open.transposed(by: $0) } }
    }

    public func pitchClasses(in tuning: Tuning) -> Set<PitchClass> {
        Set(notes(in: tuning).compactMap { $0?.pitchClass })
    }

    public func bassNote(in tuning: Tuning) -> Note? {
        notes(in: tuning).compactMap { $0 }.min()
    }

    /// True when every required chord tone sounds and nothing outside the chord does.
    public func plays(_ chord: Chord, in tuning: Tuning) -> Bool {
        let sounding = pitchClasses(in: tuning)
        return chord.requiredPitchClasses.isSubset(of: sounding) && sounding.isSubset(of: chord.pitchClasses)
    }

    /// Chord-role label per string ("R", "♭3", "5"), `nil` for muted strings.
    public func roleLabels(for chord: Chord, in tuning: Tuning) -> [String?] {
        notes(in: tuning).map { note in note.flatMap { chord.tone(for: $0.pitchClass)?.role } }
    }
}
