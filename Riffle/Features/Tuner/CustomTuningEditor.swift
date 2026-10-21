import RiffleDesign
import RiffleStore
import RiffleTheory
import SwiftUI

/// Create or edit a custom tuning: name it and move each string up or down by semitones,
/// within ±5 of standard, with a tension warning above +2 (`Tuning.issues`).
struct CustomTuningEditor: View {
    let target: TuningPickerSheet.EditorTarget
    let onSave: (Tuning) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var midis: [Int]
    @State private var accidentals: AccidentalPreference

    init(target: TuningPickerSheet.EditorTarget, onSave: @escaping (Tuning) -> Void) {
        self.target = target
        self.onSave = onSave
        let tuning: Tuning
        let name: String
        switch target {
        case .new(let template):
            tuning = template
            name = template.isStandard ? "" : "My \(template.name)"
        case .edit(let record):
            tuning = record.tuning ?? .standard
            name = record.name
        }
        _name = State(initialValue: name)
        _midis = State(initialValue: tuning.notes.map(\.midi))
        let usesFlats = tuning.strings.contains { $0.name.accidental == .flat }
        _accidentals = State(initialValue: usesFlats ? .flats : .sharps)
    }

    private var pitches: [SpelledPitch] { midis.map { Note(midi: $0).spelled(accidentals) } }
    private var issues: [Tuning.Issue] { Tuning.issues(for: pitches) }
    private var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }
    private var canSave: Bool { !trimmedName.isEmpty && !issues.contains(where: \.isBlocking) }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Name, e.g. Open C♯", text: $name)
                        .riffleFont(.body, size: 16)
                        .listRowBackground(RiffleColor.surface)
                } header: {
                    MonoLabel("Name").foregroundStyle(RiffleColor.textMuted)
                }

                Section {
                    ForEach((0..<Tuning.stringCount).reversed(), id: \.self) { index in
                        stringRow(index).listRowBackground(RiffleColor.surface)
                    }
                    SegmentedPill("Accidentals", options: [(AccidentalPreference.sharps, "♯ Sharps"), (.flats, "♭ Flats")],
                                  selection: $accidentals)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                } header: {
                    MonoLabel("Strings, high to low").foregroundStyle(RiffleColor.textMuted)
                } footer: {
                    Text("Each string can go up to 5 semitones below or above standard.")
                        .riffleFont(.body, size: 12)
                        .foregroundStyle(RiffleColor.textDim)
                }
            }
            .scrollContentBackground(.hidden)
            .background(RiffleColor.background)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(tuning)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
        .tint(RiffleColor.lime)
    }

    private var title: String {
        if case .edit = target { return "Edit tuning" }
        return "New tuning"
    }

    private var tuning: Tuning {
        switch target {
        case .new: Tuning.custom(name: trimmedName, strings: pitches)
        case .edit(let record): Tuning(id: record.id, name: trimmedName, strings: pitches)
        }
    }

    private func stringRow(_ index: Int) -> some View {
        let issue = issues.first { $0.stringIndex == index }
        let standard = Tuning.standard.notes[index].midi
        let offset = midis[index] - standard
        return HStack(spacing: 12) {
            Text("\(Tuning.stringNumber(forIndex: index))")
                .riffleFont(.mono, size: 12, weight: .medium)
                .foregroundStyle(RiffleColor.textMuted)
                .frame(width: 26, height: 26)
                .background(Circle().fill(RiffleColor.surfaceRaised))
            VStack(alignment: .leading, spacing: 2) {
                Text(pitches[index].description)
                    .riffleFont(.display, size: 22, weight: .bold)
                    .foregroundStyle(RiffleColor.text)
                    .contentTransition(.numericText())
                Text(issueText(issue, offset: offset))
                    .riffleFont(.body, size: 12, weight: issue == nil ? .regular : .semibold)
                    .foregroundStyle(issue == nil ? RiffleColor.textDim : RiffleColor.orange)
            }
            Spacer()
            Button { midis[index] -= 1 } label: { Image(systemName: "minus") }
                .buttonStyle(ChipButtonStyle())
                .disabled(offset <= Tuning.customRange.lowerBound)
                .accessibilityLabel("Lower string \(Tuning.stringNumber(forIndex: index))")
            Button { midis[index] += 1 } label: { Image(systemName: "plus") }
                .buttonStyle(ChipButtonStyle())
                .disabled(offset >= Tuning.customRange.upperBound)
                .accessibilityLabel("Raise string \(Tuning.stringNumber(forIndex: index))")
        }
        .buttonStyle(.borderless)
        .animation(.snappy, value: midis)
    }

    private func issueText(_ issue: Tuning.Issue?, offset: Int) -> String {
        switch issue?.kind {
        case .tooLow: return "Too far below standard"
        case .tooHigh: return "Too far above standard"
        case .highTension: return "High tension: take care, strings can snap"
        case nil:
            if offset == 0 { return "Standard" }
            return "\(abs(offset)) semitone\(abs(offset) == 1 ? "" : "s") \(offset < 0 ? "down" : "up")"
        }
    }
}
