/// A diatonic interval: the letter distance (`number`, 1 = unison, 3 = third) plus its size in semitones.
/// Keeping both lets us spell notes correctly (a ♭3 above A is C, never B♯).
public struct Interval: Hashable, Codable, Sendable, CustomStringConvertible {
    public let number: Int
    public let semitones: Int

    public init(number: Int, semitones: Int) {
        precondition(number >= 1, "Interval numbers start at 1 (unison)")
        self.number = number
        self.semitones = semitones
    }

    public static let unison = Interval(number: 1, semitones: 0)
    public static let minorSecond = Interval(number: 2, semitones: 1)
    public static let majorSecond = Interval(number: 2, semitones: 2)
    public static let minorThird = Interval(number: 3, semitones: 3)
    public static let majorThird = Interval(number: 3, semitones: 4)
    public static let perfectFourth = Interval(number: 4, semitones: 5)
    public static let augmentedFourth = Interval(number: 4, semitones: 6)
    public static let diminishedFifth = Interval(number: 5, semitones: 6)
    public static let perfectFifth = Interval(number: 5, semitones: 7)
    public static let augmentedFifth = Interval(number: 5, semitones: 8)
    public static let minorSixth = Interval(number: 6, semitones: 8)
    public static let majorSixth = Interval(number: 6, semitones: 9)
    public static let diminishedSeventh = Interval(number: 7, semitones: 9)
    public static let minorSeventh = Interval(number: 7, semitones: 10)
    public static let majorSeventh = Interval(number: 7, semitones: 11)
    public static let octave = Interval(number: 8, semitones: 12)
    public static let majorNinth = Interval(number: 9, semitones: 14)

    /// 1–7 regardless of octave.
    public var simpleNumber: Int { (number - 1) % 7 + 1 }

    private var isPerfectClass: Bool { [1, 4, 5].contains(simpleNumber) }

    /// Semitone offset from the major/perfect interval with the same number.
    public var alteration: Int {
        let reference = [0, 2, 4, 5, 7, 9, 11][simpleNumber - 1] + 12 * ((number - 1) / 7)
        return semitones - reference
    }

    /// Degree label used across the app: "1", "♭3", "5", "♯4", "♭7", "𝄫7", "9".
    public var degreeLabel: String {
        let prefix: String
        switch alteration {
        case 0: prefix = ""
        case -1: prefix = "♭"
        case -2: prefix = "𝄫"
        case 1: prefix = "♯"
        case 2: prefix = "𝄪"
        default: prefix = "?"
        }
        return prefix + String(number)
    }

    /// Label for a chord tone: the root is "R", everything else uses `degreeLabel`.
    public var chordRoleLabel: String { number == 1 && semitones == 0 ? "R" : degreeLabel }

    /// Long label for the listening slots: "ROOT", "♭3RD", "5TH", "9TH".
    public var slotLabel: String {
        if number == 1 && semitones == 0 { return "ROOT" }
        let suffix: String
        switch number % 100 {
        case 11, 12, 13: suffix = "TH"
        default:
            switch number % 10 {
            case 2: suffix = "ND"
            case 3: suffix = "RD"
            default: suffix = "TH"
            }
        }
        return degreeLabel + suffix
    }

    public var description: String { degreeLabel }
}
