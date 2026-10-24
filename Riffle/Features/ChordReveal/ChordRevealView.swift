import RiffleAudio
import RiffleDesign
import RiffleStore
import RiffleTheory
import SwiftUI

/// "Show me how" (mockup screen 4): every voicing of the chord, full shapes and triads, with a
/// fretboard diagram, a tip per shape and a strummed "Hear it". Data-driven from `VoicingLibrary`.
struct ChordRevealView: View {
    let chord: Chord
    let tuning: Tuning
    let a4: Double

    @Environment(\.dismiss) private var dismiss
    @AppStorage(Pref.leftHanded) private var leftHanded = false
    @State private var index: Int
    @State private var labels: FretboardDiagram.Labels = .fingers
    @State private var tones = ToneEngine()
    private let library: VoicingLibrary.Set

    init(chord: Chord, tuning: Tuning, a4: Double, startOnTriads: Bool = false, initialTriad: Int? = nil) {
        self.chord = chord
        self.tuning = tuning
        self.a4 = a4
        let set = VoicingLibrary.voicings(for: chord, in: tuning)
        library = set
        let triadStart = set.full.count + min(initialTriad ?? 0, max(set.triads.count - 1, 0))
        _index = State(initialValue: startOnTriads && !set.triads.isEmpty ? triadStart : 0)
    }

    private var all: [Voicing] { library.all }
    private var voicing: Voicing? { all.indices.contains(index) ? all[index] : nil }
    private var onTriads: Bool { index >= library.full.count }

    var body: some View {
        VStack(spacing: 12) {
            header.riseIn()
            if !library.triads.isEmpty {
                familyTabs.riseIn(delay: 0.05)
            }
            shapeChips.riseIn(delay: 0.1)
            if let voicing {
                diagramCard(voicing).riseIn(delay: 0.15)
            }
            Spacer(minLength: 0)
            controls
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(DotGridBackground())
        .task { tones.prepare(all.map { Phrase.strum($0, in: tuning) }, instrument: .guitar) }
        .onDisappear { tones.stop() }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(RiffleColor.text)
                    .frame(width: 44, height: 44)
                    .riffleCard(cornerRadius: 22)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back to quiz")
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(chord.symbol)
                        .riffleFont(.display, size: 44, weight: .heavy, maxScale: 1.1)
                        .foregroundStyle(RiffleColor.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .layoutPriority(1)
                        .accessibilityAddTraits(.isHeader)
                    Text(tuning.isStandard ? chord.name : "\(chord.name) · \(tuning.name)")
                        .riffleFont(.body, size: 16)
                        .foregroundStyle(RiffleColor.textMuted)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                }
                HStack(spacing: 6) {
                    ForEach(chord.tones, id: \.interval) { tone in
                        HStack(spacing: 5) {
                            Text(tone.note.description).riffleFont(.body, size: 13, weight: .bold)
                            Text(tone.role).riffleFont(.mono, size: 11)
                        }
                        .foregroundStyle(ToneColor.ink(tone.interval))
                        .padding(.horizontal, 10)
                        .frame(height: 26)
                        .background(Capsule().fill(ToneColor.fill(tone.interval)))
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(tone.note.description), \(tone.interval == .unison ? "root" : ordinal(tone.interval.number))")
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: Pickers

    private var familyTabs: some View {
        let selection = Binding<Bool>(
            get: { onTriads },
            set: { triads in withAnimation(.snappy) { index = triads ? library.full.count : 0 } }
        )
        return SegmentedPill("Voicing family", options: [(false, "Full chords · \(library.full.count)"),
                                                         (true, "Triads · \(library.triads.count)")],
                             selection: selection)
    }

    private var shapeChips: some View {
        let group = onTriads ? Array(library.full.count..<all.count) : Array(0..<library.full.count)
        return HStack(spacing: 8) {
            ForEach(group, id: \.self) { position in
                let selected = position == index
                Button {
                    withAnimation(.snappy) { index = position }
                } label: {
                    Text(all[position].shapeName)
                        .riffleFont(.body, size: 13, weight: .bold, maxScale: 1.2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .foregroundStyle(selected ? RiffleColor.orangeInk : RiffleColor.nut)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background {
                            RoundedRectangle(cornerRadius: 14).fill(selected ? RiffleColor.orange : RiffleColor.surface)
                            RoundedRectangle(cornerRadius: 14).strokeBorder(selected ? RiffleColor.orange : RiffleColor.borderStrong, lineWidth: 1.5)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }

    // MARK: Diagram

    private func diagramCard(_ voicing: Voicing) -> some View {
        VStack(spacing: 8) {
            HStack {
                Text(title(voicing))
                    .riffleFont(.display, size: 20, weight: .heavy)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .foregroundStyle(RiffleColor.text)
                    .contentTransition(.opacity)
                Spacer()
                LabelToggle(selection: $labels)
            }
            .padding(.horizontal, 18)
            FretboardDiagram(voicing: voicing, chord: chord, tuning: tuning, labels: labels, leftHanded: leftHanded)
            if let tip = voicing.tip {
                Text(tip)
                    .riffleFont(.body, size: 14)
                    .foregroundStyle(RiffleColor.nut)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 22)
                    .frame(minHeight: 42)
                    .id(voicing.id)
                    .transition(.opacity)
            }
        }
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .riffleCard(cornerRadius: 28, fill: RiffleColor.surface, border: RiffleColor.border)
    }

    private func title(_ voicing: Voicing) -> String {
        switch voicing.family {
        case .triad:
            switch voicing.shapeName {
            case "Root": return "Triad · root position"
            case "1st inv": return "Triad · 1st inversion"
            default: return "Triad · 2nd inversion"
            }
        case .full:
            if voicing.shapeName == "Open" { return "Open position" }
            return voicing.barres.isEmpty ? voicing.shapeName : "Barre · \(voicing.shapeName)"
        }
    }

    // MARK: Controls

    private var controls: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                circleButton("chevron.left", label: "Previous voicing") { step(-1) }
                Button { hear() } label: {
                    Label("Hear it · \(index + 1) of \(all.count)", systemImage: "speaker.wave.2.fill")
                        .frame(maxWidth: .infinity, minHeight: 54)
                }
                .buttonStyle(QuizButtonStyle(kind: .lime))
                circleButton("chevron.right", label: "Next voicing") { step(1) }
            }
            Button { dismiss() } label: {
                Text("Got it — let me play it").frame(maxWidth: .infinity, minHeight: 54)
            }
            .buttonStyle(QuizButtonStyle(kind: .primary))
        }
    }

    private func circleButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(RiffleColor.text)
                .frame(width: 54, height: 54)
                .background(Circle().fill(RiffleColor.surfaceRaised))
                .overlay(Circle().strokeBorder(RiffleColor.borderStrong, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func step(_ delta: Int) {
        guard !all.isEmpty else { return }
        withAnimation(.snappy) { index = (index + delta + all.count) % all.count }
    }

    private func hear() {
        guard let voicing else { return }
        _ = tones.play(.strum(voicing, in: tuning), instrument: .guitar)
    }
}

#Preview {
    ChordRevealView(chord: Chord(symbol: "Am")!, tuning: .standard, a4: 440)
        .preferredColorScheme(.dark)
}

/// Fingers / Notes: the mockup's small toggle in the diagram card's corner.
private struct LabelToggle: View {
    @Binding var selection: FretboardDiagram.Labels

    var body: some View {
        HStack(spacing: 2) {
            option(.fingers, "Fingers")
            option(.notes, "Notes")
        }
        .padding(3)
        .background(Capsule().fill(RiffleColor.background))
        .animation(.easeOut(duration: 0.2), value: selection)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Dot labels")
    }

    private func option(_ value: FretboardDiagram.Labels, _ title: String) -> some View {
        let selected = selection == value
        return Button { selection = value } label: {
            Text(title)
                .riffleFont(.body, size: 12, weight: .bold, maxScale: 1.3)
                .foregroundStyle(selected ? RiffleColor.background : RiffleColor.textMuted)
                .padding(.horizontal, 10)
                .frame(minHeight: 30)
                .background(Capsule().fill(selected ? RiffleColor.text : .clear))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

extension Chord: @retroactive Identifiable {
    public var id: String { symbol }
}
