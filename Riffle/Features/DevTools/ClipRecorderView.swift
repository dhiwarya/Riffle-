import RiffleAudio
import RiffleDesign
import SwiftUI

/// Dev tool (debug builds only): record the M1 test corpus. See Corpus/README.md.
struct ClipRecorderView: View {
    @State private var model = ClipRecorderModel()
    @State private var path: [String] = []
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section {
                    header
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                }
                ForEach(CorpusShot.Group.allCases, id: \.self) { group in
                    Section {
                        ForEach(model.shots.filter { $0.group == group }) { shot in
                            NavigationLink(value: shot.id) { row(shot) }
                                .listRowBackground(RiffleColor.surface)
                        }
                    } header: {
                        let shots = model.shots.filter { $0.group == group }
                        MonoLabel("\(group.title) · \(shots.filter { model.recorded.contains($0.id) }.count)/\(shots.count)")
                            .foregroundStyle(RiffleColor.textMuted)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(DotGridBackground())
            .navigationTitle("Clip recorder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
            .navigationDestination(for: String.self) { id in
                if let shot = model.shot(id: id) {
                    ClipRecordingView(model: model, shot: shot) { next in
                        if let next { path[path.count - 1] = next.id } else { path.removeAll() }
                    }
                    .id(id)
                }
            }
        }
        .tint(RiffleColor.lime)
        .onAppear { model.refreshRecorded() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("\(model.recorded.count) of \(model.shots.count) clips")
                .riffleFont(.display, size: 30, weight: .heavy)
                .foregroundStyle(RiffleColor.text)
            ProgressView(value: Double(model.recorded.count), total: Double(model.shots.count))
                .tint(RiffleColor.lime)
            Text("Clips save to On My iPhone › Riffle › Corpus in the Files app. Corpus/README.md has the full how-to.")
                .riffleFont(.body, size: 14)
                .foregroundStyle(RiffleColor.textMuted)
            TextField("Guitar (e.g. Yamaha F310 acoustic)", text: $model.guitar)
                .riffleFont(.body, size: 15)
                .padding(12)
                .riffleCard(cornerRadius: 14, fill: RiffleColor.surface)
            HStack {
                Button("Make zip of all clips") { model.prepareExport() }
                    .buttonStyle(ChipButtonStyle())
                    .disabled(model.recorded.isEmpty)
                if let url = model.exportURL {
                    ShareLink(item: url) { Label("Share zip", systemImage: "square.and.arrow.up") }
                        .buttonStyle(ChipButtonStyle(isSelected: true, track: .tuner))
                }
            }
            if let problem = model.problem {
                Text(problem).riffleFont(.body, size: 14, weight: .semibold).foregroundStyle(RiffleColor.orange)
            }
        }
    }

    private func row(_ shot: CorpusShot) -> some View {
        HStack(spacing: 12) {
            Image(systemName: model.recorded.contains(shot.id) ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(model.recorded.contains(shot.id) ? RiffleColor.lime : RiffleColor.textDim)
            VStack(alignment: .leading, spacing: 2) {
                Text(shot.title).riffleFont(.body, size: 15, weight: .semibold).foregroundStyle(RiffleColor.text)
                Text(shot.id).riffleFont(.mono, size: 11).foregroundStyle(RiffleColor.textDim)
            }
        }
    }
}
