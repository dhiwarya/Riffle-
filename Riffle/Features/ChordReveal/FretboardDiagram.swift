import RiffleDesign
import RiffleTheory
import SwiftUI

/// Chord-tone colours from the mockup: root orange, 3rds blue, 5ths lime, everything else lilac.
enum ToneColor {
    static func fill(_ interval: Interval) -> Color {
        switch interval.simpleNumber {
        case 1: RiffleColor.orange
        case 3: RiffleColor.blue
        case 5: RiffleColor.lime
        default: Color(hex: 0xD9A2FF)
        }
    }

    static func ink(_ interval: Interval) -> Color {
        switch interval.simpleNumber {
        case 1: RiffleColor.orangeInk
        case 3: RiffleColor.blueInk
        case 5: RiffleColor.limeInk
        default: Color(hex: 0x2A1036)
        }
    }
}

/// A five-fret chord box drawn from a `Voicing` (plan §6.4): nut or start-fret label, barre capsule,
/// ×/o markers, and dots labelled by finger or by note in interval colours. Mirrored for left-handers.
struct FretboardDiagram: View {
    enum Labels: Hashable { case fingers, notes }

    let voicing: Voicing
    let chord: Chord
    let tuning: Tuning
    var labels: Labels = .fingers
    var leftHanded = false

    private let spacing: CGFloat = 44
    private let fretHeight: CGFloat = 48
    private let frets = 5
    private let dot: CGFloat = 38
    private let widths: [CGFloat] = [3, 2.6, 2.2, 1.8, 1.4, 1.1]

    private var base: Int { voicing.baseFret }
    private var gridWidth: CGFloat { spacing * 5 }
    private var gridHeight: CGFloat { fretHeight * CGFloat(frets) }

    private func x(_ string: Int) -> CGFloat {
        CGFloat(leftHanded ? 5 - string : string) * spacing
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(base == 1 ? "" : "\(base)fr")
                .riffleFont(.mono, size: 13, maxScale: 1)
                .foregroundStyle(RiffleColor.textMuted)
                .frame(width: 34, alignment: .trailing)
                .padding(.top, 30 + fretHeight / 2 - 9)
                .contentTransition(.numericText())
            ZStack(alignment: .topLeading) {
                markers
                grid.offset(y: 30)
            }
            .frame(width: gridWidth + dot, height: gridHeight + 30 + dot / 2, alignment: .topLeading)
        }
        .padding(.trailing, 34)
        .animation(.spring(response: 0.42, dampingFraction: 0.72), value: voicing)
        .animation(.easeOut(duration: 0.2), value: labels)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    // ×/o above the nut.
    private var markers: some View {
        ZStack(alignment: .topLeading) {
            ForEach(0..<6, id: \.self) { string in
                let fret = voicing.frets[string]
                Text(fret == nil ? "×" : fret == 0 ? "o" : "")
                    .riffleFont(.mono, size: 15, weight: .medium, maxScale: 1)
                    .foregroundStyle(fret == nil ? Color(hex: 0x8A7E6C) : RiffleColor.lime)
                    .frame(width: dot, height: 22)
                    .offset(x: x(string))
            }
        }
    }

    private var grid: some View {
        ZStack(alignment: .topLeading) {
            // Fret lines; a thick nut when the diagram starts at the 1st fret.
            ForEach(0...frets, id: \.self) { index in
                let nut = index == 0 && base == 1
                RoundedRectangle(cornerRadius: 2)
                    .fill(nut ? RiffleColor.nut : RiffleColor.fretLine)
                    .frame(width: gridWidth, height: nut ? 8 : 2)
                    .offset(x: dot / 2, y: CGFloat(index) * fretHeight - (nut ? 4 : 1))
            }
            // Strings, thick to thin.
            ForEach(0..<6, id: \.self) { string in
                Rectangle()
                    .fill(Color(hex: 0x8A7E6C))
                    .frame(width: widths[string], height: gridHeight)
                    .offset(x: x(string) + dot / 2 - widths[string] / 2)
            }
            ForEach(voicing.barres, id: \.self) { barre in
                let left = min(x(barre.fromString), x(barre.toString))
                Capsule()
                    .fill(RiffleColor.text.opacity(0.22))
                    .frame(width: abs(x(barre.toString) - x(barre.fromString)) + dot, height: 36)
                    .offset(x: left, y: (CGFloat(barre.fret - base) + 0.5) * fretHeight - 18)
                    .transition(.opacity)
            }
            ForEach(0..<6, id: \.self) { string in
                dotView(string)
            }
        }
    }

    private func dotView(_ string: Int) -> some View {
        let fret = voicing.frets[string] ?? 0
        let shown = fret > 0
        let row = shown ? CGFloat(fret - base) + 0.5 : 0.5
        let note = voicing.notes(in: tuning)[string]
        let tone = note.flatMap { chord.tone(for: $0.pitchClass) }
        let showNotes = labels == .notes
        let fill = showNotes ? tone.map { ToneColor.fill($0.interval) } ?? RiffleColor.text : RiffleColor.text
        let ink = showNotes ? tone.map { ToneColor.ink($0.interval) } ?? RiffleColor.background : RiffleColor.background
        let label = showNotes ? tone?.note.description ?? "" : voicing.fingers[string].map(String.init) ?? ""
        return Text(label)
            .riffleFont(.display, size: 16, weight: .heavy, maxScale: 1)
            .foregroundStyle(ink)
            .frame(width: dot, height: dot)
            .background(Circle().fill(fill))
            .opacity(shown ? 1 : 0)
            .scaleEffect(shown ? 1 : 0.2)
            .offset(x: x(string), y: row * fretHeight - dot / 2)
    }

    private var accessibilityText: String {
        let parts = voicing.frets.indices.map { string -> String in
            let name = tuning.stringName(string)
            guard let fret = voicing.frets[string] else { return "\(name) muted" }
            if fret == 0 { return "\(name) open" }
            let finger = voicing.fingers[string].map { ", finger \($0)" } ?? ""
            return "\(name) \(ordinal(fret)) fret\(finger)"
        }
        return "\(chord.symbol) chord diagram: " + parts.joined(separator: "; ")
    }
}

#Preview {
    let am = Chord(symbol: "Am")!
    let set = VoicingLibrary.voicings(for: am, in: .standard)
    return VStack(spacing: 30) {
        FretboardDiagram(voicing: set.full[1], chord: am, tuning: .standard)
        FretboardDiagram(voicing: set.triads[2], chord: am, tuning: .standard, labels: .notes)
    }
    .padding()
    .background(RiffleColor.background)
}
