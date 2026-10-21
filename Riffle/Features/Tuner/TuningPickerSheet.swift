import RiffleDesign
import RiffleStore
import RiffleTheory
import SwiftData
import SwiftUI

/// Pick a preset or custom tuning, set A4, and create or edit custom tunings (plan §5.3).
struct TuningPickerSheet: View {
    @Binding var tuningID: String
    @Binding var a4: Double
    @Query(sort: \CustomTuning.createdAt) private var customTunings: [CustomTuning]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var editing: EditorTarget?

    enum EditorTarget: Identifiable {
        case new(template: Tuning)
        case edit(CustomTuning)

        var id: String {
            switch self {
            case .new: "new"
            case .edit(let record): record.id
            }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(Tuning.presets) { preset in
                        row(preset, isSelected: preset.id == tuningID) { tuningID = preset.id }
                    }
                } header: {
                    MonoLabel("Presets").foregroundStyle(RiffleColor.textMuted)
                }

                Section {
                    ForEach(customTunings) { record in
                        if let tuning = record.tuning {
                            row(tuning, isSelected: record.id == tuningID) { tuningID = record.id }
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) { delete(record) } label: { Label("Delete", systemImage: "trash") }
                                    Button { editing = .edit(record) } label: { Label("Edit", systemImage: "pencil") }
                                        .tint(RiffleColor.blue)
                                }
                        }
                    }
                    Button {
                        editing = .new(template: Tuning.resolve(id: tuningID, custom: customTunings))
                    } label: {
                        Label("New tuning", systemImage: "plus")
                            .riffleFont(.body, size: 16, weight: .bold)
                            .foregroundStyle(RiffleColor.lime)
                    }
                    .listRowBackground(RiffleColor.surface)
                } header: {
                    MonoLabel("Your tunings").foregroundStyle(RiffleColor.textMuted)
                } footer: {
                    if !customTunings.isEmpty {
                        Text("Swipe left on a tuning to edit or delete it.")
                            .riffleFont(.body, size: 12)
                            .foregroundStyle(RiffleColor.textDim)
                    }
                }

                Section {
                    A4Stepper(a4: $a4).listRowBackground(RiffleColor.surface)
                } header: {
                    MonoLabel("Reference pitch").foregroundStyle(RiffleColor.textMuted)
                } footer: {
                    Text("Most music uses A4 = 440 Hz. Change it only to match a recording or another instrument.")
                        .riffleFont(.body, size: 12)
                        .foregroundStyle(RiffleColor.textDim)
                }
            }
            .scrollContentBackground(.hidden)
            .background(RiffleColor.background)
            .navigationTitle("Tuning")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .sheet(item: $editing) { target in
                CustomTuningEditor(target: target) { tuning in save(tuning, target: target) }
            }
        }
        .tint(RiffleColor.lime)
        .presentationDragIndicator(.visible)
    }

    private func row(_ tuning: Tuning, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(tuning.name).riffleFont(.body, size: 16, weight: .bold).foregroundStyle(RiffleColor.text)
                    Text(tuning.noteNamesLabel).riffleFont(.mono, size: 12).foregroundStyle(RiffleColor.textMuted)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark").font(.system(size: 15, weight: .bold)).foregroundStyle(RiffleColor.lime)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(isSelected ? RiffleColor.surfaceRaised : RiffleColor.surface)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func save(_ tuning: Tuning, target: EditorTarget) {
        switch target {
        case .new:
            let record = CustomTuning(tuning: tuning)
            modelContext.insert(record)
            tuningID = record.id
        case .edit(let record):
            record.name = tuning.name
            record.strings = tuning.strings.map(\.description)
        }
    }

    private func delete(_ record: CustomTuning) {
        if record.id == tuningID { tuningID = Tuning.standard.id }
        modelContext.delete(record)
    }
}

private struct A4Stepper: View {
    @Binding var a4: Double

    var body: some View {
        HStack(spacing: 10) {
            Text("A4").riffleFont(.display, size: 20, weight: .bold).foregroundStyle(RiffleColor.text)
            Spacer()
            Button { a4 = max(Pref.Default.a4Range.lowerBound, a4 - 1) } label: { Image(systemName: "minus") }
                .buttonStyle(ChipButtonStyle())
                .accessibilityLabel("Lower A4")
            Text("\(Int(a4)) Hz")
                .riffleFont(.mono, size: 16, weight: .medium)
                .foregroundStyle(a4 == Pref.Default.a4Hz ? RiffleColor.text : RiffleColor.lime)
                .monospacedDigit()
                .frame(minWidth: 70)
            Button { a4 = min(Pref.Default.a4Range.upperBound, a4 + 1) } label: { Image(systemName: "plus") }
                .buttonStyle(ChipButtonStyle())
                .accessibilityLabel("Raise A4")
            if a4 != Pref.Default.a4Hz {
                Button("Reset") { a4 = Pref.Default.a4Hz }
                    .buttonStyle(.plain)
                    .riffleFont(.body, size: 14, weight: .bold)
                    .foregroundStyle(RiffleColor.lime)
            }
        }
        .buttonStyle(.borderless)
        .accessibilityElement(children: .contain)
        .accessibilityValue("\(Int(a4)) hertz")
    }
}
