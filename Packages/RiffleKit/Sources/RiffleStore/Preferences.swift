import Foundation

/// `@AppStorage` keys and defaults. Small settings live here; history lives in SwiftData.
public enum Pref {
    public static let a4Hz = "pref.a4Hz"
    public static let tuningID = "pref.tuningID"
    public static let noteNaming = "pref.noteNaming"
    public static let playbackSound = "pref.playbackSound"
    public static let earAnswerMode = "pref.earAnswerMode"
    public static let keyContext = "pref.keyContext"
    public static let dailyMinutes = "pref.dailyMinutes"
    public static let goal = "pref.goal"
    public static let leftHanded = "pref.leftHanded"
    public static let haptics = "pref.haptics"
    public static let reminderEnabled = "pref.reminderEnabled"
    /// Minutes after midnight.
    public static let reminderTime = "pref.reminderTime"
    public static let onboardingDone = "pref.onboardingDone"
    public static let chordLevel = "pref.chordLevel"
    public static let earDifficulty = "pref.earDifficulty"

    public enum Default {
        public static let a4Hz = 440.0
        public static let a4Range = 430.0...450.0
        public static let tuningID = "standard"
        public static let dailyMinutes = 10
        public static let reminderTime = 19 * 60
        public static let chordLevel = 1
    }
}

/// D8: the daily minutes options.
public enum DailyMinutes {
    public static let options = [5, 10, 15, 20]
}

/// D9: sound used for playback in the ear check.
public enum PlaybackSound: String, CaseIterable, Codable, Sendable {
    case guitar, piano
}

/// D2: how ear-check answers are shown.
public enum EarAnswerMode: String, CaseIterable, Codable, Sendable {
    case degrees, noteNames, solfege
}

/// D2: what establishes the key before a question.
public enum KeyContextMode: String, CaseIterable, Codable, Sendable {
    case cadence, tonic
}

public enum EarDifficulty: String, CaseIterable, Codable, Sendable {
    case easy, medium, hard
}

/// Note naming in places without a key (tuner, chord library).
public enum NoteNamingSetting: String, CaseIterable, Codable, Sendable {
    case auto, sharps, flats
}

/// Onboarding goal; sets how the daily minutes split between chords and ear (plan §8.2).
public enum PracticeGoal: String, CaseIterable, Codable, Sendable {
    case balanced, chords, ear

    /// Share of the daily minutes spent on the chord quiz.
    public var chordShare: Double {
        switch self {
        case .balanced: 0.6
        case .chords: 0.75
        case .ear: 0.25
        }
    }
}
