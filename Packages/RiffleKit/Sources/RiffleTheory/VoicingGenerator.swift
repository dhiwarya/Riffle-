/// Finds playable voicings for any chord in any tuning (plan §4): triad inversions on the top three
/// strings, and full chords for tunings the hand-written shapes don't cover.
public enum VoicingGenerator {
    /// Highest fret the generator will use.
    static let maxFret = 15

    // MARK: Triads

    /// Root position, 1st and 2nd inversion on the top three strings, each in its most compact spot.
    /// Empty for chords that aren't three-note chords.
    public static func triads(for chord: Chord, in tuning: Tuning, strings: [Int] = [3, 4, 5]) -> [Voicing] {
        let tones = chord.tones
        guard tones.count == 3, strings.count == 3 else { return [] }
        let open = tuning.notes
        return (0..<3).compactMap { inversion in
            let order = Array(tones[inversion...] + tones[..<inversion])
            // Every way to place each tone on its string, keeping the most compact.
            var best: [Int]?
            var bestScore = Int.max
            let options = zip(order, strings).map { tone, string in
                (0...maxFret).filter { (open[string].pitchClass + $0) == tone.note.pitchClass }
            }
            for a in options[0] { for b in options[1] { for c in options[2] {
                let frets = [a, b, c]
                let span = frets.max()! - frets.min()!
                guard span <= 3 else { continue }
                let score = span * 100 + frets.max()!
                if score < bestScore { bestScore = score; best = frets }
            } } }
            guard let best else { return nil }
            var frets = [Int?](repeating: nil, count: Tuning.stringCount)
            for (string, fret) in zip(strings, best) { frets[string] = fret }
            let (fingers, barres) = assignFingers(frets)
            let names = ["Root", "1st inv", "2nd inv"]
            return Voicing(id: "\(chord.symbol)-triad-\(inversion)", frets: frets, fingers: fingers, barres: barres,
                           family: .triad, shapeName: names[inversion],
                           tip: triadTip(order: order, inversion: inversion, frets: best, barres: barres,
                                         strings: strings, tuning: tuning))
        }
    }

    private static func triadTip(order: [ChordTone], inversion: Int, frets: [Int], barres: [Voicing.Barre],
                                 strings: [Int], tuning: Tuning) -> String {
        let notes = order.map(\.note.description).joined(separator: " ")
        let lowest = order[0].interval == .unison ? "root" : "\(ordinal(order[0].interval.simpleNumber))"
        var text = inversion == 0
            ? "\(notes), low to high, on the top three strings."
            : "\(notes): the \(lowest) is now lowest."
        if let barre = barres.first {
            text += " One finger flat across the \(ordinal(barre.fret)) fret."
        } else if inversion == 0 {
            let names = strings.map { tuning.strings[$0].name.description }
            text += " Only strum \(names.dropLast().joined(separator: ", ")) and \(names.last!)."
        } else {
            text += " Strum only the top three strings."
        }
        return text
    }

    // MARK: Full chords

    /// Root-position voicings with at least four strings (power chords: two), no muted strings in the
    /// middle, a span of four frets and at most four fingers counting a barre. Best first, spread
    /// over different neck positions.
    public static func fullVoicings(for chord: Chord, in tuning: Tuning, limit: Int = 3) -> [Voicing] {
        let open = tuning.notes
        let chordPCs = chord.pitchClasses
        let minStrings = chord.quality == .power ? 2 : min(4, max(chord.tones.count, 3))
        var candidates: [(frets: [Int?], score: Double)] = []

        for window in 0...12 {
            let low = max(window, 1), high = window + 3
            let options: [[Int?]] = open.map { note in
                var list: [Int?] = [nil]
                if chordPCs.contains(note.pitchClass) { list.append(0) }
                for fret in low...high where chordPCs.contains(note.pitchClass + fret) { list.append(fret) }
                return list
            }
            var current = [Int?](repeating: nil, count: Tuning.stringCount)
            func visit(_ string: Int) {
                if string == Tuning.stringCount {
                    if let score = score(current, chord: chord, tuning: tuning, minStrings: minStrings, window: window) {
                        candidates.append((current, score))
                    }
                    return
                }
                for option in options[string] {
                    current[string] = option
                    visit(string + 1)
                }
            }
            visit(0)
        }

        var chosen: [[Int?]] = []
        var seen: Swift.Set<[Int?]> = []
        for candidate in candidates.sorted(by: { $0.score < $1.score }) where !seen.contains(candidate.frets) {
            seen.insert(candidate.frets)
            let position = Self.position(candidate.frets)
            guard !chosen.contains(where: { abs(Self.position($0) - position) < 3 }) else { continue }
            chosen.append(candidate.frets)
            if chosen.count == limit { break }
        }
        return chosen.map { frets in
            let (fingers, barres) = assignFingers(frets)
            let position = Self.position(frets)
            let rootString = frets.firstIndex { $0 != nil } ?? 0
            let rootFret = frets[rootString] ?? 0
            let rootText = rootFret == 0
                ? "Root on the open \(tuning.stringName(rootString))."
                : "Root on the \(tuning.stringName(rootString)), \(ordinal(rootFret)) fret."
            let muted = frets.indices.filter { frets[$0] == nil }
            let muteText = muted.isEmpty ? " All six strings ring." : " Don't play the \(muted.map(tuning.stringName).joined(separator: " or "))."
            return Voicing(id: "\(chord.symbol)-\(tuning.id)-\(frets.map { $0.map(String.init) ?? "x" }.joined())",
                           frets: frets, fingers: fingers, barres: barres, family: .full,
                           shapeName: position == 0 ? "Open" : "Fret \(position)", tip: rootText + muteText)
        }
    }

    /// Lowest fretted fret, or 0 for shapes that use open strings near the nut.
    static func position(_ frets: [Int?]) -> Int {
        let fretted = frets.compactMap { $0 }.filter { $0 > 0 }
        if frets.contains(0) && (fretted.max() ?? 0) <= 4 { return 0 }
        return fretted.min() ?? 0
    }

    /// Lower is better; `nil` when the shape isn't playable or isn't the chord.
    private static func score(_ frets: [Int?], chord: Chord, tuning: Tuning, minStrings: Int, window: Int) -> Double? {
        let sounding = frets.indices.filter { frets[$0] != nil }
        guard sounding.count >= minStrings, let first = sounding.first, let last = sounding.last,
              last - first + 1 == sounding.count else { return nil }
        let notes = zip(frets, tuning.notes).compactMap { fret, open in fret.map { open.transposed(by: $0) } }
        let pcs = Swift.Set(notes.map(\.pitchClass))
        guard chord.requiredPitchClasses.isSubset(of: pcs), pcs.isSubset(of: chord.pitchClasses),
              notes.min()?.pitchClass == chord.root.pitchClass else { return nil }
        let fretted = frets.compactMap { $0 }.filter { $0 > 0 }
        // Open strings mixed with a high window are hard to reach cleanly.
        if frets.contains(0), (fretted.max() ?? 0) > 5 { return nil }
        guard let fingers = fingersNeeded(frets), fingers <= 4 else { return nil }
        let span = (fretted.max() ?? 0) - (fretted.min() ?? 0)
        let opens = frets.filter { $0 == 0 }.count
        return Double(position(frets)) * 1.2 + Double(span) * 0.5 - Double(sounding.count) * 0.9
            - Double(opens) * 0.3 + Double(fingers) * 0.4
    }

    /// Fingers needed, allowing finger 1 to barre the lowest fret; `nil` when it can't be fingered.
    static func fingersNeeded(_ frets: [Int?]) -> Int? {
        let fretted = frets.compactMap { $0 }.filter { $0 > 0 }
        guard let lowest = fretted.min() else { return 0 }
        if fretted.count <= 4 { return fretted.count }
        guard let barre = barre(for: frets, at: lowest) else { return nil }
        let covered = (barre.fromString...barre.toString).filter { frets[$0] == lowest }.count
        return 1 + fretted.count - covered
    }

    /// A barre at `fret` from the first string fretted there to the highest sounding string, as long as
    /// no string under it is open or lower.
    static func barre(for frets: [Int?], at fret: Int) -> Voicing.Barre? {
        guard let from = frets.firstIndex(where: { $0 == fret }),
              let to = frets.lastIndex(where: { $0 != nil }) else { return nil }
        let atFret = (from...to).filter { frets[$0] == fret }.count
        guard atFret >= 2, (from...to).allSatisfy({ frets[$0] == nil || frets[$0]! >= fret }) else { return nil }
        return Voicing.Barre(fret: fret, fromString: from, toString: to)
    }

    /// Fingers 1–4 from the lowest fret up (barring when it needs to), and the barre if any.
    static func assignFingers(_ frets: [Int?]) -> ([Int?], [Voicing.Barre]) {
        var fingers = [Int?](repeating: nil, count: frets.count)
        let fretted = frets.indices.filter { (frets[$0] ?? 0) > 0 }
        guard let lowest = fretted.map({ frets[$0]! }).min() else { return (fingers, []) }
        var barres: [Voicing.Barre] = []
        var remaining = fretted
        let sameFret = fretted.filter { frets[$0] == lowest }
        if fretted.count > 4 || (sameFret.count >= 3 && sameFret.count == fretted.count),
           let barre = barre(for: frets, at: lowest) {
            barres = [barre]
            for string in barre.fromString...barre.toString where frets[string] == lowest { fingers[string] = 1 }
            remaining.removeAll { fingers[$0] == 1 }
        }
        var next = barres.isEmpty ? 1 : 2
        for string in remaining.sorted(by: { (frets[$0]!, $0) < (frets[$1]!, $1) }) {
            fingers[string] = min(next, 4)
            next += 1
        }
        return (fingers, barres)
    }
}
