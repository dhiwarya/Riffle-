import RiffleDesign
import RiffleStore
import RiffleTheory
import SwiftData
import SwiftUI

/// Tuner tab shell. Live pitch detection arrives in M2; for now it shows the
/// selected tuning's target notes and lets the user switch tunings.
struct TunerView: View {
    @AppStorage(Pref.tuningID) private var tuningID = Pref.Default.tuningID
    @AppStorage(Pref.a4Hz) private var a4 = Pref.Default.a4Hz
    @Query(sort: \CustomTuning.createdAt) private var customTunings: [CustomTuning]
    @State private var mode: Mode = .auto
    @State private var selectedString = 0

    enum Mode: Hashable { case auto, manual }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                notePanel
                strings
                Text(mode == .auto ? "Auto: just pluck — we detect the string." : "Manual: tap a string, then pluck it.")
                    .riffleFont(.body, size: 14)
                    .foregroundStyle(RiffleColor.textMuted)
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
        .background(DotGridBackground())
    }

    private var tuning: Tuning {
        Tuning.preset(id: tuningID) ?? customTunings.first { $0.id == tuningID }?.tuning ?? .standard
    }

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Tuner")
                    .riffleFont(.display, size: 40, weight: .heavy, relativeTo: .largeTitle, maxScale: 1.2, tracking: -0.02)
                    .foregroundStyle(RiffleColor.text)
                    .accessibilityAddTraits(.isHeader)
                Menu {
                    Picker("Tuning", selection: $tuningID) {
                        ForEach(Tuning.presets) { preset in
                            Text("\(preset.name) · \(preset.noteNamesLabel)").tag(preset.id)
                        }
                        ForEach(customTunings) { custom in
                            Text(custom.name).tag(custom.id)
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text("\(tuning.name) · A4 = \(Int(a4)) Hz")
                            .riffleFont(.mono, size: 12, relativeTo: .caption)
                        Image(systemName: "chevron.down").font(.system(size: 10, weight: .bold))
                    }
                    .foregroundStyle(RiffleColor.textMuted)
                }
                .accessibilityLabel("Tuning: \(tuning.name). Change tuning")
            }
            Spacer()
            SegmentedPill("Detection mode", options: [(Mode.auto, "Auto"), (Mode.manual, "Manual")], selection: $mode)
                .frame(width: 168)
        }
    }

    private var notePanel: some View {
        let note = tuning.strings[selectedString]
        let hz = tuning.notes[selectedString].frequency(a4: a4)
        return VStack(spacing: 8) {
            Text(note.name.description)
                .riffleFont(.display, size: 96, weight: .heavy, relativeTo: .largeTitle, maxScale: 1)
                .foregroundStyle(RiffleColor.text)
            Text("\(note.description) · string \(Tuning.stringNumber(forIndex: selectedString)) · \(hz, format: .number.precision(.fractionLength(1))) Hz")
                .riffleFont(.mono, size: 13, relativeTo: .caption)
                .foregroundStyle(RiffleColor.textMuted)
            Text("Live tuning arrives in M2")
                .riffleFont(.body, size: 14, weight: .semibold)
                .foregroundStyle(RiffleColor.lime)
                .padding(.top, 6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .riffleCard(cornerRadius: 28, fill: RiffleColor.surface, border: RiffleColor.border)
        .accessibilityElement(children: .combine)
    }

    /// Strings low → high with their target notes, laid out as a list for now (the headstock comes in M2).
    private var strings: some View {
        VStack(spacing: 8) {
            ForEach(Array(tuning.strings.enumerated()).reversed(), id: \.offset) { index, pitch in
                let selected = index == selectedString
                Button {
                    selectedString = index
                    mode = .manual
                } label: {
                    HStack(spacing: 14) {
                        Text("\(Tuning.stringNumber(forIndex: index))")
                            .riffleFont(.mono, size: 12, weight: .medium)
                            .foregroundStyle(selected ? RiffleColor.limeInk : RiffleColor.textMuted)
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(selected ? RiffleColor.lime : RiffleColor.surface))
                        Text(pitch.description)
                            .riffleFont(.display, size: 20, weight: .bold)
                        Spacer()
                        Text("\(tuning.notes[index].frequency(a4: a4), format: .number.precision(.fractionLength(2))) Hz")
                            .riffleFont(.mono, size: 13)
                            .foregroundStyle(RiffleColor.textMuted)
                    }
                    .foregroundStyle(RiffleColor.text)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 52)
                    .riffleCard(cornerRadius: 18, border: selected ? RiffleColor.lime : RiffleColor.borderStrong)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("String \(Tuning.stringNumber(forIndex: index)), \(pitch.description)")
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }
}

#Preview {
    TunerView()
        .modelContainer(PreviewData.container)
        .preferredColorScheme(.dark)
}
