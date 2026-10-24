import RiffleTheory

/// Turns what the mic heard into one line of coaching, using the voicing the player most likely
/// used (plan §6.3): "So close. The 3rd isn't ringing — check the B string."
public struct ChordCoach: Sendable {
    public let item: ChordItem
    public let tuning: Tuning
    /// The shape the advice refers to.
    public let reference: Voicing?

    public init(item: ChordItem, tuning: Tuning, reference: Voicing? = nil) {
        self.item = item
        self.tuning = tuning
        self.reference = reference ?? VoicingLibrary.reference(for: item.chord, in: tuning, inversion: item.inversion)
    }

    private var chord: Chord { item.chord }

    public static let nothingHeard = "I can't hear you — move closer or strum harder."

    /// Advice after a strum that didn't pass. `bass` is the lowest pitch class heard.
    public func feedback(missing: Set<PitchClass>, extra: Set<PitchClass>, bass: PitchClass?) -> String {
        if let message = extraMessage(extra) { return message }
        if !missing.isEmpty { return missingMessage(missing) }
        if let required = item.requiredBass, let bass, bass != required { return bassMessage(required: required, heard: bass) }
        return "Almost. Let every string ring, then strum once more."
    }

    /// The Hint panel: what the chord is made of and where the root is.
    public var hint: String {
        let roles = chord.tones.filter { !$0.isOptional }.map { $0.interval == .unison ? "root" : $0.role }
        var text = "\(article(chord.quality.displayName)) \(chord.quality.displayName) chord is \(roles.joined(separator: " + "))."
        if let inversion = item.inversion, inversion > 0 {
            let tone = chord.tones[inversion]
            text += " Put the \(roleName(tone.interval)) (\(tone.note)) lowest."
        }
        if let place = rootPlace { text += " Your root is \(place)." }
        return text
    }

    // MARK: Pieces

    private func extraMessage(_ extra: Set<PitchClass>) -> String? {
        guard !extra.isEmpty else { return nil }
        let ordered = extra.sorted()
        // An open string that should be muted ("Mute the low E string").
        if let reference {
            for pc in ordered {
                if let string = reference.frets.indices.first(where: { reference.frets[$0] == nil && tuning.notes[$0].pitchClass == pc }) {
                    return "I hear \(spell(pc)) — mute the \(tuning.stringName(string)), it isn't part of \(chord.symbol)."
                }
            }
        }
        // A wrong 3rd, 5th or 7th that turns the chord into a different one.
        for pc in ordered {
            for tone in chord.tones where tone.interval != .unison {
                let distance = pc.semitones(above: tone.note.pitchClass)
                guard distance == 1 || distance == 11 else { continue }
                var pcs = chord.pitchClasses
                pcs.remove(tone.note.pitchClass)
                pcs.insert(pc)
                guard let other = quality(of: pcs) else { continue }
                var text = "I hear \(spell(pc)) — that makes it \(describe(Chord(chord.root, other)))."
                if let fix = place(of: tone.note.pitchClass) { text += " The \(fix)." }
                return text
            }
        }
        // An added tone that makes another chord (E → E7, C → Cmaj7): usually an open string that
        // should be fretted, or a finger a fret or two away.
        for pc in ordered {
            guard let other = quality(of: chord.pitchClasses.union([pc])) else { continue }
            var text = "I hear \(spell(pc)) — that makes it \(describe(Chord(chord.root, other)))."
            if let string = nearestString(producing: pc, within: 2), let fret = reference?.frets[string] {
                text += fret == 0 ? " The \(tuning.stringName(string)) should ring open."
                    : " The \(tuning.stringName(string)) should be on the \(ordinal(fret)) fret."
            }
            return text
        }
        // Probably a finger one fret off.
        let pc = ordered[0]
        if let string = nearestString(producing: pc, within: 1), let fret = reference?.frets[string] {
            let target = fret == 0 ? "ring open" : "be on the \(ordinal(fret)) fret"
            return "I hear \(spell(pc)), which isn't in \(chord.symbol). Check the \(tuning.stringName(string)) — it should \(target)."
        }
        return "I hear \(spell(pc)), which isn't in \(chord.symbol). Check each finger sits on the right fret."
    }

    private func quality(of pcs: Set<PitchClass>) -> ChordQuality? {
        ChordQuality.allCases.first { Chord(chord.root, $0).pitchClasses == pcs }
    }

    /// "A major", "E7".
    private func describe(_ other: Chord) -> String {
        [.major, .minor].contains(other.quality) ? other.name : other.symbol
    }

    /// The sounding string in the reference voicing that would give `pc` if the finger moved by at
    /// most `within` frets (closest move first, higher strings first).
    private func nearestString(producing pc: PitchClass, within: Int) -> Int? {
        guard let reference else { return nil }
        for distance in 1...within {
            for string in reference.frets.indices.reversed() {
                guard let fret = reference.frets[string] else { continue }
                for delta in [-distance, distance] where fret + delta >= 0 && tuning.notes[string].pitchClass + (fret + delta) == pc {
                    return string
                }
            }
        }
        return nil
    }

    private func missingMessage(_ missing: Set<PitchClass>) -> String {
        let tones = chord.tones.filter { missing.contains($0.note.pitchClass) }
        let required = chord.tones.filter { !$0.isOptional }.count
        let opener = tones.count == 1 && required >= 3 ? "So close." : "Not quite."
        let subject = ("the " + joinedList(tones.map { roleName($0.interval) })).capitalizedFirst
        let verb = tones.count == 1 ? "isn't" : "aren't"
        let strings = tones.compactMap { stringCarrying($0.note.pitchClass) }
        let uniqueStrings = strings.reduce(into: [Int]()) { if !$0.contains($1) { $0.append($1) } }
        guard !uniqueStrings.isEmpty else { return "\(opener) \(subject) \(verb) ringing." }
        let stringText = uniqueStrings.count == 1
            ? tuning.stringName(uniqueStrings[0])
            : joinedList(uniqueStrings.map { tuning.stringName($0).replacingOccurrences(of: " string", with: "") }) + " strings"
        return "\(opener) \(subject) \(verb) ringing — check the \(stringText)."
    }

    private func bassMessage(required: PitchClass, heard: PitchClass) -> String {
        let needed = spell(required)
        if item.inversion == nil, let reference, let lowest = reference.frets.firstIndex(where: { $0 != nil }), lowest > 0 {
            return "Right notes, but \(spell(heard)) is the lowest. Start your strum on the \(tuning.stringName(lowest)) so \(needed) is in the bass."
        }
        return "Right notes, but \(spell(heard)) is the lowest. \(needed) should be the lowest note."
    }

    /// The string that carries a pitch class in the reference voicing, preferring fretted notes
    /// (an open string rarely fails to ring) and the higher strings.
    private func stringCarrying(_ pc: PitchClass) -> Int? {
        guard let reference else { return nil }
        let carrying = reference.frets.indices.filter { string in
            reference.frets[string].map { tuning.notes[string].pitchClass + $0 == pc } ?? false
        }
        return carrying.last { (reference.frets[$0] ?? 0) > 0 } ?? carrying.last
    }

    /// "B string should be on the 1st fret".
    private func place(of pc: PitchClass) -> String? {
        guard let string = stringCarrying(pc), let fret = reference?.frets[string] else { return nil }
        return fret == 0 ? "\(tuning.stringName(string)) should ring open" : "\(tuning.stringName(string)) should be on the \(ordinal(fret)) fret"
    }

    /// "the open A string", "the A string, 3rd fret".
    private var rootPlace: String? {
        guard let reference else { return nil }
        guard let string = reference.frets.indices.first(where: { string in
            reference.frets[string].map { tuning.notes[string].pitchClass + $0 == chord.root.pitchClass } ?? false
        }), let fret = reference.frets[string] else { return nil }
        return fret == 0 ? "the open \(tuning.stringName(string))" : "the \(tuning.stringName(string)), \(ordinal(fret)) fret"
    }

    private func roleName(_ interval: Interval) -> String {
        interval == .unison ? "root" : ordinal(interval.number)
    }

    private func spell(_ pc: PitchClass) -> String {
        if let tone = chord.tone(for: pc) { return tone.note.description }
        let flats = chord.root.accidental == .flat || (chord.root.letter == .F && chord.root.accidental == .natural)
        return SpelledNote.preferred(for: pc, preference: flats ? .flats : .sharps).description
    }

    private func article(_ word: String) -> String {
        guard let first = word.first?.lowercased() else { return "A" }
        return "aeiou".contains(first) ? "An" : "A"
    }

    private func joinedList(_ items: [String]) -> String {
        switch items.count {
        case 0: ""
        case 1: items[0]
        default: items.dropLast().joined(separator: ", ") + " and " + items.last!
        }
    }
}

private extension String {
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}
