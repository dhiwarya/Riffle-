/// Voicings for the chord quiz and the reveal screen (plan §6.4). Standard tuning gets hand-written open
/// shapes plus movable barre shapes; any gap, and every other tuning, is filled by `VoicingGenerator`.
public enum VoicingLibrary {
    /// The two tabs on the reveal screen.
    public struct Set: Hashable, Sendable {
        public var full: [Voicing]
        public var triads: [Voicing]

        public var all: [Voicing] { full + triads }
    }

    public static func voicings(for chord: Chord, in tuning: Tuning) -> Set {
        var full: [Voicing] = []
        if tuning.isStandard {
            full += openShapes.filter { $0.matches(chord) }.map { $0.voicing(for: chord) }
            for shape in movableShapes where shape.qualities.contains(chord.quality) {
                if let voicing = shape.voicing(for: chord) { full.append(voicing) }
            }
        }
        if full.count < 2 {
            let found = VoicingGenerator.fullVoicings(for: chord, in: tuning, limit: 3)
            full += found.filter { candidate in !full.contains { $0.frets == candidate.frets } }
        }
        let triads = VoicingGenerator.triads(for: chord, in: tuning)
        return Set(full: Array(full.prefix(4)), triads: triads)
    }

    /// The voicing feedback refers to ("check the B string"): the first full shape, else a triad.
    public static func reference(for chord: Chord, in tuning: Tuning, inversion: Int? = nil) -> Voicing? {
        let set = voicings(for: chord, in: tuning)
        if let inversion, set.triads.indices.contains(inversion) { return set.triads[inversion] }
        return set.full.first ?? set.triads.first
    }

    // MARK: Open shapes (standard tuning)

    struct OpenShape {
        let symbol: String
        let frets: String
        let fingers: String
        var barre: Voicing.Barre?
        let tip: String

        func matches(_ chord: Chord) -> Bool {
            guard let own = Chord(symbol: symbol) else { return false }
            return own.quality == chord.quality && own.root.pitchClass == chord.root.pitchClass
        }

        func voicing(for chord: Chord) -> Voicing {
            Voicing(id: "\(symbol)-open", frets: parse(frets), fingers: parse(fingers),
                    barres: barre.map { [$0] } ?? [], family: .full, shapeName: "Open", tip: tip)
        }

        /// "x02210" → [nil, 0, 2, 2, 1, 0]; "-" also means nothing.
        private func parse(_ text: String) -> [Int?] {
            text.map { Int(String($0)) }
        }
    }

    static let openShapes: [OpenShape] = [
        // Level 1
        OpenShape(symbol: "E", frets: "022100", fingers: "-231--",
                  tip: "All six strings ring. Fingers 2 and 3 share the 2nd fret, so stay on your fingertips."),
        OpenShape(symbol: "A", frets: "x02220", fingers: "--123-",
                  tip: "Three fingers squeezed into the 2nd fret. Skip the low E string."),
        OpenShape(symbol: "D", frets: "xx0232", fingers: "---132",
                  tip: "Strum from the open D string down. Keep the A and low E quiet."),
        OpenShape(symbol: "G", frets: "320003", fingers: "21---3",
                  tip: "All six strings. Stretch finger 3 to the high E string's 3rd fret."),
        OpenShape(symbol: "C", frets: "x32010", fingers: "-32-1-",
                  tip: "Root on the A string, 3rd fret. Arch every finger so the open G and high E ring."),
        OpenShape(symbol: "Em", frets: "022000", fingers: "-23---",
                  tip: "The friendliest chord there is: two fingers, all six strings."),
        OpenShape(symbol: "Am", frets: "x02210", fingers: "--231-",
                  tip: "The one most people learn first. Arch finger 3 so the B string rings clear."),
        OpenShape(symbol: "Dm", frets: "xx0231", fingers: "---231",
                  tip: "Like D, but finger 1 drops to the high E's 1st fret. Start the strum on the D string."),
        // Level 2
        OpenShape(symbol: "E7", frets: "020100", fingers: "-2-1--",
                  tip: "Open E with finger 3 lifted: the open D string adds the 7th."),
        OpenShape(symbol: "A7", frets: "x02020", fingers: "--2-3-",
                  tip: "Open A with the G string left open. That open G is the 7th."),
        OpenShape(symbol: "D7", frets: "xx0212", fingers: "---213",
                  tip: "An upside-down D. Strum from the D string."),
        OpenShape(symbol: "G7", frets: "320001", fingers: "32---1",
                  tip: "Like G, but the high E drops to the 1st fret for the 7th."),
        OpenShape(symbol: "B7", frets: "x21202", fingers: "-213-4",
                  tip: "Four fingers, five strings. The open B string doubles the root."),
        OpenShape(symbol: "C7", frets: "x32310", fingers: "-3241-",
                  tip: "Open C plus finger 4 on the G string's 3rd fret for the 7th."),
        OpenShape(symbol: "Dsus2", frets: "xx0230", fingers: "---13-",
                  tip: "Open D with the high E left open. Bright and unresolved."),
        OpenShape(symbol: "Dsus4", frets: "xx0233", fingers: "---134",
                  tip: "Open D with finger 4 on the high E's 3rd fret. Lift it to resolve back to D."),
        OpenShape(symbol: "Asus2", frets: "x02200", fingers: "--12--",
                  tip: "Open A with the B string left open."),
        OpenShape(symbol: "Asus4", frets: "x02230", fingers: "--123-",
                  tip: "Open A with the B string up at the 3rd fret. Lift finger 3 to resolve to A."),
        // Level 3
        OpenShape(symbol: "E5", frets: "022xxx", fingers: "-12---",
                  tip: "Low E, B, E. Strum only the bottom three strings."),
        OpenShape(symbol: "A5", frets: "x022xx", fingers: "--12--",
                  tip: "The open A string plus two fingers. Keep the other strings quiet."),
        // Level 6
        OpenShape(symbol: "Cmaj7", frets: "x32000", fingers: "-32---",
                  tip: "Open C with finger 1 lifted. The open B string is the major 7th."),
        OpenShape(symbol: "Fmaj7", frets: "xx3210", fingers: "--321-",
                  tip: "The friendly F, no barre. Strum from the D string."),
        OpenShape(symbol: "Dmaj7", frets: "xx0222", fingers: "---123",
                  tip: "Three fingers in a row on the 2nd fret. Strum from the D string."),
        OpenShape(symbol: "Am7", frets: "x02010", fingers: "--2-1-",
                  tip: "Open Am with finger 3 lifted. The open G is the 7th."),
        OpenShape(symbol: "Dm7", frets: "xx0211", fingers: "---211",
                  barre: Voicing.Barre(fret: 1, fromString: 4, toString: 5),
                  tip: "Finger 1 lies flat over the top two strings at the 1st fret."),
        OpenShape(symbol: "Em7", frets: "022030", fingers: "-12-3-",
                  tip: "Open Em plus finger 3 on the B string's 3rd fret."),
        // Level 7
        OpenShape(symbol: "Cadd9", frets: "x32030", fingers: "-21-3-",
                  tip: "Open C with the B string moved up to the 3rd fret. That D is the 9th."),
        OpenShape(symbol: "C6", frets: "x32210", fingers: "-4231-",
                  tip: "Open C with the G string pushed to the 2nd fret for the 6th."),
        OpenShape(symbol: "A6", frets: "x02222", fingers: "--1111",
                  barre: Voicing.Barre(fret: 2, fromString: 2, toString: 5),
                  tip: "One finger flat across the 2nd fret on four strings."),
        OpenShape(symbol: "Am6", frets: "x02212", fingers: "--2314",
                  tip: "Open Am with the high E at the 2nd fret. That F♯ is the 6th."),
    ]

    // MARK: Movable shapes (standard tuning)

    struct MovableShape {
        enum Kind { case eShape, aShape }

        let kind: Kind
        let qualities: [ChordQuality]
        /// Fret offsets from the root fret, low → high; `nil` = muted.
        let offsets: [Int?]
        let fingers: [Int?]
        /// Barre as (fret offset, from string, to string, finger).
        var barre: (offset: Int, from: Int, to: Int, finger: Int)?

        var rootString: Int { kind == .eShape ? 0 : 1 }

        func voicing(for chord: Chord) -> Voicing? {
            let open = Tuning.standard.notes[rootString].pitchClass
            var rootFret = chord.root.pitchClass.semitones(above: open)
            let lowest = offsets.compactMap { $0 }.min() ?? 0
            if rootFret + lowest < 1 { rootFret += 12 }
            let frets = offsets.map { $0.map { rootFret + $0 } }
            guard (frets.compactMap { $0 }.max() ?? 0) <= 17 else { return nil }
            let barres = barre.map { [Voicing.Barre(fret: rootFret + $0.offset, fromString: $0.from, toString: $0.to, finger: $0.finger)] } ?? []
            return Voicing(id: "\(chord.symbol)-\(kind)-\(rootFret)", frets: frets, fingers: fingers, barres: barres,
                           family: .full, shapeName: kind == .eShape ? "E shape" : "A shape",
                           tip: tip(for: chord, rootFret: rootFret))
        }

        private func tip(for chord: Chord, rootFret: Int) -> String {
            let fret = "\(ordinal(rootFret)) fret"
            if chord.quality == .power {
                return "Root on the \(kind == .eShape ? "low E" : "A") string, \(fret). Let your fretting hand rest on the other strings to mute them."
            }
            switch kind {
            case .eShape:
                let openName = Chord(.E, chord.quality).symbol
                return barre != nil
                    ? "An open \(openName) shape slid up to the \(fret), with finger 1 barring all six strings."
                    : "Root on the low E string, \(fret). Mute the A and high E strings."
            case .aShape:
                return "Root on the A string, \(fret). Mute the low E with the tip of finger 1."
            }
        }
    }

    static let movableShapes: [MovableShape] = [
        MovableShape(kind: .eShape, qualities: [.major], offsets: [0, 2, 2, 1, 0, 0], fingers: [1, 3, 4, 2, 1, 1],
                     barre: (0, 0, 5, 1)),
        MovableShape(kind: .eShape, qualities: [.minor], offsets: [0, 2, 2, 0, 0, 0], fingers: [1, 3, 4, 1, 1, 1],
                     barre: (0, 0, 5, 1)),
        MovableShape(kind: .eShape, qualities: [.dominant7], offsets: [0, 2, 0, 1, 0, 0], fingers: [1, 3, 1, 2, 1, 1],
                     barre: (0, 0, 5, 1)),
        MovableShape(kind: .eShape, qualities: [.minor7], offsets: [0, 2, 0, 0, 0, 0], fingers: [1, 3, 1, 1, 1, 1],
                     barre: (0, 0, 5, 1)),
        MovableShape(kind: .eShape, qualities: [.sus4], offsets: [0, 2, 2, 2, 0, 0], fingers: [1, 2, 3, 4, 1, 1],
                     barre: (0, 0, 5, 1)),
        MovableShape(kind: .eShape, qualities: [.major7], offsets: [0, nil, 1, 1, 0, nil], fingers: [1, nil, 3, 4, 2, nil]),
        MovableShape(kind: .eShape, qualities: [.power], offsets: [0, 2, 2, nil, nil, nil], fingers: [1, 3, 4, nil, nil, nil]),
        MovableShape(kind: .aShape, qualities: [.major], offsets: [nil, 0, 2, 2, 2, 0], fingers: [nil, 1, 2, 3, 4, 1],
                     barre: (0, 1, 5, 1)),
        MovableShape(kind: .aShape, qualities: [.minor], offsets: [nil, 0, 2, 2, 1, 0], fingers: [nil, 1, 3, 4, 2, 1],
                     barre: (0, 1, 5, 1)),
        MovableShape(kind: .aShape, qualities: [.dominant7], offsets: [nil, 0, 2, 0, 2, 0], fingers: [nil, 1, 3, 1, 4, 1],
                     barre: (0, 1, 5, 1)),
        MovableShape(kind: .aShape, qualities: [.minor7], offsets: [nil, 0, 2, 0, 1, 0], fingers: [nil, 1, 3, 1, 2, 1],
                     barre: (0, 1, 5, 1)),
        MovableShape(kind: .aShape, qualities: [.major7], offsets: [nil, 0, 2, 1, 2, 0], fingers: [nil, 1, 3, 2, 4, 1],
                     barre: (0, 1, 5, 1)),
        MovableShape(kind: .aShape, qualities: [.sus2], offsets: [nil, 0, 2, 2, 0, 0], fingers: [nil, 1, 3, 4, 1, 1],
                     barre: (0, 1, 5, 1)),
        MovableShape(kind: .aShape, qualities: [.sus4], offsets: [nil, 0, 2, 2, 3, 0], fingers: [nil, 1, 2, 3, 4, 1],
                     barre: (0, 1, 5, 1)),
        MovableShape(kind: .aShape, qualities: [.major6], offsets: [nil, 0, 2, 2, 2, 2], fingers: [nil, 1, 3, 3, 3, 3],
                     barre: (2, 2, 5, 3)),
        MovableShape(kind: .aShape, qualities: [.halfDiminished7], offsets: [nil, 0, 1, 0, 1, nil], fingers: [nil, 1, 3, 2, 4, nil]),
        MovableShape(kind: .aShape, qualities: [.diminished7], offsets: [nil, 0, 1, -1, 1, nil], fingers: [nil, 2, 3, 1, 4, nil]),
        MovableShape(kind: .aShape, qualities: [.dominant9], offsets: [nil, 0, -1, 0, 0, 0], fingers: [nil, 2, 1, 3, 3, 3],
                     barre: (0, 3, 5, 3)),
        MovableShape(kind: .aShape, qualities: [.power], offsets: [nil, 0, 2, 2, nil, nil], fingers: [nil, 1, 3, 4, nil, nil]),
    ]
}

/// "1st", "2nd", "3rd", "12th".
public func ordinal(_ number: Int) -> String {
    let tens = number % 100
    if (11...13).contains(tens) { return "\(number)th" }
    switch number % 10 {
    case 1: return "\(number)st"
    case 2: return "\(number)nd"
    case 3: return "\(number)rd"
    default: return "\(number)th"
    }
}
