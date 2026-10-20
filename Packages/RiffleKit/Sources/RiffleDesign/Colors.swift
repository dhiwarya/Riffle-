import SwiftUI

extension Color {
    /// `Color(hex: 0xC6F15A)`.
    public init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

/// Colour tokens from the Riffle mockup. The app is dark-only.
public enum RiffleColor {
    // Surfaces
    public static let background = Color(hex: 0x14110D)
    public static let surface = Color(hex: 0x1C1813)
    public static let surfaceRaised = Color(hex: 0x211C16)
    public static let surfaceSunken = Color(hex: 0x2B251D)
    public static let navBar = Color(hex: 0x1B1712)

    // Lines
    public static let border = Color(hex: 0x2E2720)
    public static let borderStrong = Color(hex: 0x3A3229)
    public static let fretLine = Color(hex: 0x4A4035)
    public static let nut = Color(hex: 0xE9DCC4)

    // Text
    public static let text = Color(hex: 0xF6EFE4)
    public static let textSoft = Color(hex: 0xE9DCC4)
    public static let textMuted = Color(hex: 0xB5A994)
    public static let textDim = Color(hex: 0x6E6455)
    public static let stringIdle = Color(hex: 0x8A7E6C)

    // Accents
    public static let lime = Color(hex: 0xC6F15A)
    public static let limeInk = Color(hex: 0x18200A)
    public static let limeBright = Color(hex: 0xE2FF9A)
    public static let orange = Color(hex: 0xFF7A33)
    public static let orangeInk = Color(hex: 0x1A0F05)
    public static let blue = Color(hex: 0x7B93FF)
    public static let blueInk = Color(hex: 0x0E1230)
}

/// Each practice track owns one accent colour (design principle 2).
public enum Track: String, Sendable, CaseIterable {
    /// Orange: Play the chord.
    case chords
    /// Blue: Name that note.
    case ear
    /// Lime: tuner, success, "done".
    case tuner

    public var accent: Color {
        switch self {
        case .chords: RiffleColor.orange
        case .ear: RiffleColor.blue
        case .tuner: RiffleColor.lime
        }
    }

    /// Text and icons drawn on top of `accent`.
    public var ink: Color {
        switch self {
        case .chords: RiffleColor.orangeInk
        case .ear: RiffleColor.blueInk
        case .tuner: RiffleColor.limeInk
        }
    }

    /// Hard drop shadow under pedal cards.
    public var shadow: Color {
        switch self {
        case .chords: Color(hex: 0xA9471A)
        case .ear: Color(hex: 0x4A5BC2)
        case .tuner: Color(hex: 0x7F9B2E)
        }
    }

    /// Lighter tint for secondary text on dark ink chips.
    public var soft: Color {
        switch self {
        case .chords: Color(hex: 0xFFB48A)
        case .ear: Color(hex: 0xB9C6FF)
        case .tuner: RiffleColor.limeBright
        }
    }

    /// Glowing status LED colour.
    public var glow: Color {
        switch self {
        case .chords: Color(hex: 0xFFF3C4)
        case .ear: Color(hex: 0xE8EDFF)
        case .tuner: RiffleColor.limeBright
        }
    }
}
