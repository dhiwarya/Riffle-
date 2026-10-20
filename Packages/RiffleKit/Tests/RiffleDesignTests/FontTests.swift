import CoreText
import Testing
@testable import RiffleDesign

struct FontTests {
    @Test func bundledFontsLoad() {
        #expect(RiffleFonts.shared.allFontsAvailable)
    }

    @Test func displayFontIsBricolageAtTheRequestedWeight() throws {
        let heavy = try #require(RiffleFonts.shared.ctFont(.display, size: 40, weight: .heavy))
        let regular = try #require(RiffleFonts.shared.ctFont(.display, size: 40, weight: .regular))
        #expect((CTFontCopyFamilyName(heavy) as String).hasPrefix("Bricolage Grotesque"))
        // 800 is the file's default instance, so CoreText only reports the axis when it differs.
        let variation = try #require(CTFontCopyVariation(regular) as? [NSNumber: NSNumber])
        #expect(variation[NSNumber(value: 0x7767_6874)]?.doubleValue == 400)
        #expect(advance(of: "W", in: heavy) > advance(of: "W", in: regular))
    }

    private func advance(of character: Character, in font: CTFont) -> CGFloat {
        var chars = Array(String(character).utf16)
        var glyphs = [CGGlyph](repeating: 0, count: chars.count)
        CTFontGetGlyphsForCharacters(font, &chars, &glyphs, chars.count)
        return CTFontGetAdvancesForGlyphs(font, .horizontal, &glyphs, nil, glyphs.count)
    }

    @Test func bodyAndMonoFonts() throws {
        let body = try #require(RiffleFonts.shared.ctFont(.body, size: 15, weight: .bold))
        #expect((CTFontCopyFamilyName(body) as String).hasPrefix("DM Sans"))
        let mono = try #require(RiffleFonts.shared.ctFont(.mono, size: 12, weight: .medium))
        #expect(CTFontCopyPostScriptName(mono) as String == "DMMono-Medium")
        let monoRegular = try #require(RiffleFonts.shared.ctFont(.mono, size: 12, weight: .regular))
        #expect(CTFontCopyPostScriptName(monoRegular) as String == "DMMono-Regular")
    }
}

import Foundation
