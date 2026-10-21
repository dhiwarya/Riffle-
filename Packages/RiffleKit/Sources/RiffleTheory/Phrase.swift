/// One note to play: pitch, start offset and length in seconds, loudness 0…1.
public struct PlaybackNote: Hashable, Sendable {
    public var midi: Int
    public var offset: Double
    public var duration: Double
    public var velocity: Double

    public init(midi: Int, offset: Double, duration: Double = 1.6, velocity: Double = 0.8) {
        self.midi = midi
        self.offset = offset
        self.duration = duration
        self.velocity = velocity
    }
}

/// A short musical phrase (a cadence, a note, two notes to compare). Pure data; RiffleAudio renders it.
public struct Phrase: Hashable, Sendable {
    public enum ChordStyle: Sendable { case strum, block }

    public var notes: [PlaybackNote]

    public init(_ notes: [PlaybackNote] = []) { self.notes = notes }

    /// When the last note ends.
    public var duration: Double { notes.map { $0.offset + $0.duration }.max() ?? 0 }

    /// This phrase followed by `other`, after `gap` seconds.
    public func then(_ other: Phrase, gap: Double = 0) -> Phrase {
        let start = duration + gap
        return Phrase(notes + other.notes.map { var n = $0; n.offset += start; return n })
    }

    public static func note(_ midi: Int, duration: Double = 1.6, velocity: Double = 0.85) -> Phrase {
        Phrase([PlaybackNote(midi: midi, offset: 0, duration: duration, velocity: velocity)])
    }

    /// A chord with the root in the bass (A2–G♯3) and the other tones in A3–G♯4.
    public static func chord(_ chord: Chord, style: ChordStyle, duration: Double = 0.7, velocity: Double = 0.6) -> Phrase {
        let bass = 45 + chord.root.pitchClass.semitones(above: PitchClass(9))
        var midis = [bass]
        for tone in chord.tones {
            midis.append(57 + tone.note.pitchClass.semitones(above: PitchClass(9)))
        }
        let spacing = style == .strum ? 0.018 : 0
        return Phrase(midis.sorted().enumerated().map { index, midi in
            PlaybackNote(midi: midi, offset: Double(index) * spacing, duration: duration, velocity: velocity)
        })
    }

    /// I–IV–V–I (i–iv–V–i in minor) to set the key before a question (decision D2).
    public static func cadence(_ key: Key, style: ChordStyle) -> Phrase {
        let chords = key.cadence
        var phrase = Phrase()
        for (index, chord) in chords.enumerated() {
            let last = index == chords.count - 1
            phrase = phrase.then(Phrase.chord(chord, style: style, duration: last ? 1.0 : 0.62), gap: 0)
        }
        return phrase
    }
}
