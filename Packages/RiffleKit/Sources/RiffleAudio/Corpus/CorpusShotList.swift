import RiffleTheory

/// The M1 recording session: about 116 short clips, roughly 45–60 minutes including re-tuning.
/// Order follows the recorder: chords first (guitar in tune), tuner offsets last.
public enum CorpusShotList {
    public static let all: [CorpusShot] = chords + mistakes + noise + environment + tuner

    public static func shots(in group: CorpusShot.Group) -> [CorpusShot] {
        all.filter { $0.group == group }
    }

    public static func shot(id: String) -> CorpusShot? { all.first { $0.id == id } }

    // MARK: Chords (49)

    /// "F#m barre" → "fsm-barre".
    private static func slug(_ text: String) -> String {
        text.replacingOccurrences(of: "#", with: "s").replacingOccurrences(of: "♯", with: "s")
            .replacingOccurrences(of: "♭", with: "b").replacingOccurrences(of: " ", with: "-").lowercased()
    }

    private static func fretsLabel(_ frets: [Int?]) -> String {
        let parts = frets.map { $0.map(String.init) ?? "x" }
        return parts.joined(separator: frets.contains { ($0 ?? 0) > 9 } ? "-" : "")
    }

    private static func chord(_ symbol: String, _ frets: [Int?], take: String? = nil, how: String = "Strum once, downwards",
                              name: String? = nil, seconds: Double = 6) -> CorpusShot {
        let label = name ?? symbol
        let id = "chord-" + slug(label) + (take.map { "-\($0)" } ?? "")
        return CorpusShot(
            id: id, group: .chords,
            title: "\(label) (\(fretsLabel(frets)))" + (take.map { " · take \($0.uppercased())" } ?? ""),
            instruction: "\(how). Shape \(fretsLabel(frets)), low E string first; x = don't play that string.",
            seconds: seconds,
            expectation: .chord(target: symbol, frets: frets, shouldPass: true)
        )
    }

    static let chords: [CorpusShot] = {
        let open: [(String, [Int?])] = [
            ("E", [0, 2, 2, 1, 0, 0]), ("A", [nil, 0, 2, 2, 2, 0]), ("D", [nil, nil, 0, 2, 3, 2]),
            ("G", [3, 2, 0, 0, 0, 3]), ("C", [nil, 3, 2, 0, 1, 0]), ("Em", [0, 2, 2, 0, 0, 0]),
            ("Am", [nil, 0, 2, 2, 1, 0]), ("Dm", [nil, nil, 0, 2, 3, 1]),
        ]
        var shots: [CorpusShot] = []
        for (symbol, frets) in open {
            shots.append(chord(symbol, frets, take: "a", how: "Strum once, downwards, at normal strength"))
            shots.append(chord(symbol, frets, take: "b", how: "Strum once, downwards, gently"))
        }
        let level2: [(String, [Int?])] = [
            ("E7", [0, 2, 0, 1, 0, 0]), ("A7", [nil, 0, 2, 0, 2, 0]), ("D7", [nil, nil, 0, 2, 1, 2]),
            ("G7", [3, 2, 0, 0, 0, 1]), ("B7", [nil, 2, 1, 2, 0, 2]), ("C7", [nil, 3, 2, 3, 1, 0]),
            ("Dsus2", [nil, nil, 0, 2, 3, 0]), ("Dsus4", [nil, nil, 0, 2, 3, 3]),
            ("Asus2", [nil, 0, 2, 2, 0, 0]), ("Asus4", [nil, 0, 2, 2, 3, 0]),
        ]
        shots += level2.map { chord($0.0, $0.1) }
        shots += [
            chord("E5", [0, 2, 2, nil, nil, nil], how: "Strum only the three lowest strings"),
            chord("A5", [nil, 0, 2, 2, nil, nil], how: "Strum only the A, D and G strings"),
            chord("G5", [3, 5, 5, nil, nil, nil], how: "Strum only the three lowest strings"),
        ]
        shots += [
            chord("F", [1, 3, 3, 2, 1, 1], name: "F barre"),
            chord("Bm", [nil, 2, 4, 4, 3, 2], name: "Bm barre"),
            chord("Bb", [nil, 1, 3, 3, 3, 1], name: "Bb barre"),
            chord("F#m", [2, 4, 4, 2, 2, 2], name: "F#m barre"),
            chord("Am", [5, 7, 7, 5, 5, 5], name: "Am E shape"),
            chord("C", [nil, 3, 5, 5, 5, 3], name: "C A shape"),
        ]
        let topThree = "Strum only the G, B and high e strings"
        shots += [
            chord("Am", [nil, nil, nil, 2, 1, 0], how: topThree, name: "Am triad root"),
            chord("Am", [nil, nil, nil, 5, 5, 5], how: topThree, name: "Am triad 1st inv"),
            chord("Am", [nil, nil, nil, 9, 10, 8], how: topThree, name: "Am triad 2nd inv"),
            chord("C", [nil, nil, nil, 5, 5, 3], how: topThree, name: "C triad root"),
            chord("C", [nil, nil, nil, 9, 8, 8], how: topThree, name: "C triad 1st inv"),
            chord("C", [nil, nil, nil, 0, 1, 0], how: topThree, name: "C triad 2nd inv"),
            chord("G", [nil, nil, nil, 12, 12, 10], how: topThree, name: "G triad root"),
            chord("G", [nil, nil, nil, 4, 3, 3], how: topThree, name: "G triad 1st inv"),
            chord("G", [nil, nil, nil, 7, 8, 7], how: topThree, name: "G triad 2nd inv"),
        ]
        shots += [
            chord("Cmaj7", [nil, 3, 2, 0, 0, 0]), chord("Am7", [nil, 0, 2, 0, 1, 0]),
            chord("Dm7", [nil, nil, 0, 2, 1, 1]), chord("Em7", [0, 2, 0, 0, 0, 0]),
            chord("Bm7b5", [nil, 2, 3, 2, 3, nil], how: "Strum the A to B strings; mute the high e"),
        ]
        return shots
    }()

    // MARK: Mistakes (9)

    static let mistakes: [CorpusShot] = [
        CorpusShot(id: "mistake-am-dead-b", group: .mistakes, title: "Am with a dead B string",
                   instruction: "Play Am but let a finger touch the B string so it doesn't ring. Strum once.",
                   seconds: 6, expectation: .chord(target: "Am", frets: [nil, 0, 2, 2, nil, 0], shouldPass: false, missing: ["C"])),
        CorpusShot(id: "mistake-em-dead-g", group: .mistakes, title: "Em with a dead G string",
                   instruction: "Play Em but mute the open G string with a fingertip. Strum all six strings once.",
                   seconds: 6, expectation: .chord(target: "Em", frets: [0, 2, 2, nil, 0, 0], shouldPass: false, missing: ["G"])),
        CorpusShot(id: "mistake-d-dead-e", group: .mistakes, title: "D with a dead high e",
                   instruction: "Play D but mute the high e string. Strum the D, G and B strings once.",
                   seconds: 6, expectation: .chord(target: "D", frets: [nil, nil, 0, 2, 3, nil], shouldPass: false, missing: ["F♯"])),
        CorpusShot(id: "mistake-d-low-e", group: .mistakes, title: "D strummed across all six strings",
                   instruction: "Hold a normal D shape but strum all six strings, so the open low E and A ring too.",
                   seconds: 6, expectation: .chord(target: "D", frets: [0, 0, 0, 2, 3, 2], shouldPass: false, extra: ["E"])),
        CorpusShot(id: "mistake-g-wrong-fret", group: .mistakes, title: "G with the A string on fret 3",
                   instruction: "Play G, but put the A-string finger on fret 3 instead of 2 (3 3 0 0 0 3). Strum once.",
                   seconds: 6, expectation: .chord(target: "G", frets: [3, 3, 0, 0, 0, 3], shouldPass: false, extra: ["C"])),
        CorpusShot(id: "mistake-c-wrong-fret", group: .mistakes, title: "C with the D string on fret 3",
                   instruction: "Play C, but put the D-string finger on fret 3 instead of 2 (x 3 3 0 1 0). Strum once.",
                   seconds: 6, expectation: .chord(target: "C", frets: [nil, 3, 3, 0, 1, 0], shouldPass: false, extra: ["F"])),
        CorpusShot(id: "mistake-am-g-flat", group: .mistakes, title: "Am with the G string slightly flat",
                   instruction: "Tune the G string about 30 cents flat on your reference tuner, play a normal Am, then re-tune the G string.",
                   seconds: 6, expectation: .chord(target: "Am", frets: [nil, 0, 2, 2, 1, 0], shouldPass: true)),
        CorpusShot(id: "mistake-am-buzz", group: .mistakes, title: "Am with buzzing frets",
                   instruction: "Play Am pressing too lightly, so a couple of strings buzz. Strum once.",
                   seconds: 6, expectation: .explore(target: "Am")),
        CorpusShot(id: "mistake-f-buzz", group: .mistakes, title: "F barre with buzzing strings",
                   instruction: "Play the F barre pressing too lightly, so some strings buzz or die. Strum once.",
                   seconds: 6, expectation: .explore(target: "F")),
    ]

    // MARK: Noise (5)

    static let noise: [CorpusShot] = [
        CorpusShot(id: "noise-silence", group: .noise, title: "Room silence",
                   instruction: "Don't play anything. Stay quiet for the whole clip.", seconds: 6, expectation: .noChord),
        CorpusShot(id: "noise-talking", group: .noise, title: "Talking, no guitar",
                   instruction: "Talk normally near the phone (read anything out loud). Don't touch the guitar.",
                   seconds: 6, expectation: .noChord),
        CorpusShot(id: "noise-single-a", group: .noise, title: "Only the open A string",
                   instruction: "Pick only the open A string once and let it ring.", seconds: 6, expectation: .noChord),
        CorpusShot(id: "noise-body-tap", group: .noise, title: "Tapping the guitar body",
                   instruction: "Tap the guitar body with your knuckles a few times. Don't let any string ring.",
                   seconds: 6, expectation: .noChord),
        CorpusShot(id: "noise-muted-strum", group: .noise, title: "Muted strum",
                   instruction: "Rest your fretting hand lightly across all strings and strum a few times (a percussive 'chuck').",
                   seconds: 6, expectation: .noChord),
    ]

    // MARK: Environment (8)

    static let environment: [CorpusShot] = [
        CorpusShot(id: "env-far-am", group: .environment, title: "Am, phone 1 m away",
                   instruction: "Move the phone about 1 metre from the guitar. Strum Am once.",
                   seconds: 6, expectation: .chord(target: "Am", frets: [nil, 0, 2, 2, 1, 0], shouldPass: true)),
        CorpusShot(id: "env-far-s6", group: .environment, title: "Low E string, phone 1 m away",
                   instruction: "Phone still about 1 metre away. Pick the open low E string once.",
                   seconds: 5, expectation: .pitch(midi: 40, cents: 0, tolerance: 4)),
        CorpusShot(id: "env-noisy-am", group: .environment, title: "Am with background noise",
                   instruction: "Back in the normal spot. Turn on a TV, music or a fan at a normal room level. Strum Am once.",
                   seconds: 6, expectation: .chord(target: "Am", frets: [nil, 0, 2, 2, 1, 0], shouldPass: true)),
        CorpusShot(id: "env-noisy-g", group: .environment, title: "G with background noise",
                   instruction: "Same background noise. Strum G once.",
                   seconds: 6, expectation: .chord(target: "G", frets: [3, 2, 0, 0, 0, 3], shouldPass: true)),
        CorpusShot(id: "env-noisy-c", group: .environment, title: "C with background noise",
                   instruction: "Same background noise. Strum C once.",
                   seconds: 6, expectation: .chord(target: "C", frets: [nil, 3, 2, 0, 1, 0], shouldPass: true)),
        CorpusShot(id: "env-noisy-s1", group: .environment, title: "High e string with background noise",
                   instruction: "Same background noise. Pick the open high e string once.",
                   seconds: 5, expectation: .pitch(midi: 64, cents: 0, tolerance: 4)),
        CorpusShot(id: "env-strum-twice-em", group: .environment, title: "Em strummed twice",
                   instruction: "Noise off. Strum Em, wait about a second, strum it again.",
                   seconds: 7, expectation: .chord(target: "Em", frets: [0, 2, 2, 0, 0, 0], shouldPass: true)),
        CorpusShot(id: "env-fingerpick-c", group: .environment, title: "C fingerpicked",
                   instruction: "Hold C and pick the strings one by one, low to high, slowly, letting them ring.",
                   seconds: 8, expectation: .explore(target: "C")),
    ]

    // MARK: Tuner (45)

    static let tuner: [CorpusShot] = {
        let standard = Tuning.standard
        var shots: [CorpusShot] = []
        for index in (0..<6) {
            let number = Tuning.stringNumber(forIndex: index)
            let pitch = standard.strings[index]
            for cents in [-25, -10, 0, 10, 25] {
                let label = cents == 0 ? "in tune" : cents < 0 ? "\(-cents)¢ flat" : "\(cents)¢ sharp"
                let slug = cents == 0 ? "0" : cents < 0 ? "m\(-cents)" : "p\(cents)"
                shots.append(CorpusShot(
                    id: "tuner-s\(number)-\(slug)", group: .tuner,
                    title: "String \(number) (\(pitch)), \(label)",
                    instruction: "Set string \(number) to \(cents == 0 ? "exactly in tune" : label) on your reference tuner. Pick it once and let it ring.",
                    seconds: 5,
                    expectation: .pitch(midi: pitch.note.midi, cents: Double(cents), tolerance: cents == 0 ? 3 : 4)
                ))
            }
        }
        for fret in [12, 5] {
            for index in (0..<6) {
                let number = Tuning.stringNumber(forIndex: index)
                let midi = standard.notes[index].midi + fret
                shots.append(CorpusShot(
                    id: "tuner-s\(number)-f\(fret)", group: .tuner,
                    title: "String \(number), fret \(fret) (\(Note(midi: midi).spelled()))",
                    instruction: "All strings back in tune. Fret string \(number) at fret \(fret), pick once and let it ring.",
                    seconds: 5,
                    expectation: .pitch(midi: midi, cents: 0, tolerance: 6)
                ))
            }
        }
        shots += [
            CorpusShot(id: "tuner-s6-soft", group: .tuner, title: "String 6, picked softly",
                       instruction: "In tune. Pick the low E string very gently.", seconds: 5,
                       expectation: .pitch(midi: 40, cents: 0, tolerance: 4)),
            CorpusShot(id: "tuner-s1-soft", group: .tuner, title: "String 1, picked softly",
                       instruction: "In tune. Pick the high e string very gently.", seconds: 5,
                       expectation: .pitch(midi: 64, cents: 0, tolerance: 4)),
            CorpusShot(id: "tuner-dropd-s6", group: .tuner, title: "Drop D: string 6 tuned to D2",
                       instruction: "Tune the low E string down to D (D2) on your reference tuner, pick it once, then tune it back to E.",
                       seconds: 5, expectation: .pitch(midi: 38, cents: 0, tolerance: 3)),
        ]
        return shots
    }()
}
