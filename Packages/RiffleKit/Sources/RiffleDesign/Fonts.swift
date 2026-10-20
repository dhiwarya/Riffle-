import CoreText
import SwiftUI

/// The three typefaces from the mockup (design principle 4).
public enum RiffleTypeface: Sendable, CaseIterable {
    /// Bricolage Grotesque: titles and big values.
    case display
    /// DM Sans: body text.
    case body
    /// DM Mono: caps labels and metadata.
    case mono
}

public enum RiffleWeight: Sendable {
    case regular, medium, semibold, bold, heavy

    var value: Double {
        switch self {
        case .regular: 400
        case .medium: 500
        case .semibold: 600
        case .bold: 700
        case .heavy: 800
        }
    }

    var systemWeight: Font.Weight {
        switch self {
        case .regular: .regular
        case .medium: .medium
        case .semibold: .semibold
        case .bold: .bold
        case .heavy: .heavy
        }
    }
}

/// Loads the bundled WOFF2 fonts straight from the package (no Info.plist registration needed)
/// and builds variable-font instances by weight and optical size.
public final class RiffleFonts: @unchecked Sendable {
    public static let shared = RiffleFonts()

    private static let weightAxis = NSNumber(value: 0x7767_6874) // 'wght'
    private static let opticalSizeAxis = NSNumber(value: 0x6F70_737A) // 'opsz'

    private let lock = NSLock()
    private var descriptors: [String: CTFontDescriptor] = [:]
    private var cache: [String: CTFont] = [:]

    private init() {}

    /// True when every bundled font file loaded. Fonts fall back to the system font otherwise.
    public var allFontsAvailable: Bool {
        ["BricolageGrotesque-400_800", "DMSans-400_700", "DMMono-400", "DMMono-500"].allSatisfy { descriptor(file: $0) != nil }
    }

    public func ctFont(_ typeface: RiffleTypeface, size: CGFloat, weight: RiffleWeight) -> CTFont? {
        let key = "\(typeface)-\(size)-\(weight.value)"
        if let cached = lock.withLock({ cache[key] }) { return cached }

        let file: String
        var variation: [NSNumber: Double] = [:]
        switch typeface {
        case .display:
            file = "BricolageGrotesque-400_800"
            variation = [Self.weightAxis: min(max(weight.value, 200), 800), Self.opticalSizeAxis: min(max(size, 12), 96)]
        case .body:
            file = "DMSans-400_700"
            variation = [Self.weightAxis: weight.value, Self.opticalSizeAxis: min(max(size, 9), 40)]
        case .mono:
            file = weight.value >= 500 ? "DMMono-500" : "DMMono-400"
        }
        guard let base = descriptor(file: file) else { return nil }

        let descriptor = variation.isEmpty ? base : CTFontDescriptorCreateCopyWithAttributes(
            base, [kCTFontVariationAttribute: variation] as CFDictionary
        )
        let font = CTFontCreateWithFontDescriptor(descriptor, size, nil)
        lock.withLock { cache[key] = font }
        return font
    }

    public func font(_ typeface: RiffleTypeface, size: CGFloat, weight: RiffleWeight) -> Font {
        if let ctFont = ctFont(typeface, size: size, weight: weight) {
            return Font(ctFont)
        }
        return .system(size: size, weight: weight.systemWeight, design: typeface == .mono ? .monospaced : .default)
    }

    private func descriptor(file: String) -> CTFontDescriptor? {
        lock.withLock {
            if let loaded = descriptors[file] { return loaded }
            guard let url = Bundle.module.url(forResource: file, withExtension: "woff2", subdirectory: "Fonts"),
                  let data = try? Data(contentsOf: url),
                  let loaded = CTFontManagerCreateFontDescriptorFromData(data as CFData) else { return nil }
            descriptors[file] = loaded
            return loaded
        }
    }
}

extension Font {
    public static func riffle(_ typeface: RiffleTypeface, size: CGFloat, weight: RiffleWeight = .regular) -> Font {
        RiffleFonts.shared.font(typeface, size: size, weight: weight)
    }
}

/// Applies a Riffle font that grows with Dynamic Type, capped so fixed layouts don't break.
struct RiffleFontModifier: ViewModifier {
    let typeface: RiffleTypeface
    let weight: RiffleWeight
    let baseSize: CGFloat
    let maxScale: CGFloat
    let tracking: CGFloat
    @ScaledMetric private var scaledSize: CGFloat

    init(typeface: RiffleTypeface, size: CGFloat, weight: RiffleWeight, relativeTo: Font.TextStyle,
         maxScale: CGFloat, tracking: CGFloat) {
        self.typeface = typeface
        self.weight = weight
        self.baseSize = size
        self.maxScale = maxScale
        self.tracking = tracking
        _scaledSize = ScaledMetric(wrappedValue: size, relativeTo: relativeTo)
    }

    func body(content: Content) -> some View {
        let size = min(scaledSize, baseSize * maxScale)
        content
            .font(.riffle(typeface, size: size, weight: weight))
            .tracking(size * tracking)
    }
}

extension View {
    /// `tracking` is in em, like the mockup's CSS letter-spacing (0.12em → 0.12).
    public func riffleFont(
        _ typeface: RiffleTypeface,
        size: CGFloat,
        weight: RiffleWeight = .regular,
        relativeTo: Font.TextStyle = .body,
        maxScale: CGFloat = 1.35,
        tracking: CGFloat = 0
    ) -> some View {
        modifier(RiffleFontModifier(typeface: typeface, size: size, weight: weight, relativeTo: relativeTo,
                                    maxScale: maxScale, tracking: tracking))
    }
}
