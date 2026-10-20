import RiffleAudio
import RiffleDesign
import RiffleTheory
import SwiftUI

/// One shot: instructions, live readout of what the detector hears, record → review → keep.
struct ClipRecordingView: View {
    let model: ClipRecorderModel
    let shot: CorpusShot
    let goTo: (CorpusShot?) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    MonoLabel(shot.group.title).foregroundStyle(track.accent)
                    Text(shot.title)
                        .riffleFont(.display, size: 28, weight: .heavy, relativeTo: .title)
                        .foregroundStyle(RiffleColor.text)
                    Text(shot.instruction)
                        .riffleFont(.body, size: 17)
                        .foregroundStyle(RiffleColor.textSoft)
                        .fixedSize(horizontal: false, vertical: true)
                    if model.recorded.contains(shot.id) {
                        Label("Already recorded. Recording again replaces it.", systemImage: "checkmark.circle.fill")
                            .riffleFont(.body, size: 13, weight: .semibold)
                            .foregroundStyle(RiffleColor.lime)
                    }
                }
                LiveReadout(shot: shot, snapshot: model.snapshot, track: track)
                if model.isUsingBluetoothMic {
                    Text("A Bluetooth headset mic is active. Disconnect it so the phone's own mic records.")
                        .riffleFont(.body, size: 14, weight: .semibold)
                        .foregroundStyle(RiffleColor.orange)
                }
                if let problem = model.problem {
                    Text(problem).riffleFont(.body, size: 14, weight: .semibold).foregroundStyle(RiffleColor.orange)
                }
                controls
            }
            .padding(20)
        }
        .scrollIndicators(.hidden)
        .background(DotGridBackground())
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.startListening(for: shot) }
        .onDisappear { if model.phase != .idle { model.retake(shot) } }
    }

    private var track: Track {
        switch shot.group {
        case .tuner: .tuner
        case .noise: .ear
        default: .chords
        }
    }

    @ViewBuilder
    private var controls: some View {
        switch model.phase {
        case .idle:
            PedalButton("Record \(Int(shot.seconds)) s", track: track) { model.record(shot) }
        case .countIn(let n):
            Text("\(n)")
                .riffleFont(.display, size: 64, weight: .heavy, maxScale: 1)
                .foregroundStyle(track.accent)
                .frame(maxWidth: .infinity)
                .contentTransition(.numericText())
                .animation(.snappy, value: n)
        case .recording:
            VStack(spacing: 10) {
                Text("Play now")
                    .riffleFont(.display, size: 30, weight: .heavy)
                    .foregroundStyle(track.accent)
                ProgressView(value: min(model.snapshot.recordedSeconds, shot.seconds), total: shot.seconds)
                    .tint(track.accent)
            }
            .frame(maxWidth: .infinity)
        case .review:
            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    Button { model.playBack() } label: { Label("Play back", systemImage: "play.fill") }
                        .buttonStyle(ChipButtonStyle())
                    Button { model.retake(shot) } label: { Label("Retake", systemImage: "arrow.counterclockwise") }
                        .buttonStyle(ChipButtonStyle())
                }
                PedalButton("Keep & next", track: track) {
                    model.keep(shot)
                    goTo(model.nextUnrecorded(after: shot))
                }
            }
        }
    }
}

/// Level meter plus what the pitch tracker or chord verifier currently hears.
private struct LiveReadout: View {
    let shot: CorpusShot
    let snapshot: LiveSnapshot
    let track: Track

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                MonoLabel("Live").foregroundStyle(RiffleColor.textMuted)
                Spacer()
                Text(String(format: "%.0f dB", max(snapshot.levelDB, -99)))
                    .riffleFont(.mono, size: 12)
                    .foregroundStyle(RiffleColor.textMuted)
            }
            GeometryReader { geo in
                Capsule().fill(RiffleColor.surfaceSunken)
                    .overlay(alignment: .leading) {
                        Capsule().fill(levelColor)
                            .frame(width: geo.size.width * levelFraction)
                            .animation(.linear(duration: 0.05), value: levelFraction)
                    }
            }
            .frame(height: 8)

            switch shot.expectation {
            case let .pitch(midi, cents, tolerance):
                pitchReadout(expectedMidi: midi, expectedCents: cents, tolerance: tolerance)
            default:
                chordReadout
            }
        }
        .padding(18)
        .riffleCard(cornerRadius: 24, fill: RiffleColor.surface, border: RiffleColor.border)
    }

    private var levelFraction: Double { min(max((snapshot.levelDB + 60) / 60, 0), 1) }
    private var levelColor: Color { snapshot.levelDB > -3 ? RiffleColor.orange : RiffleColor.lime }

    private func pitchReadout(expectedMidi: Int, expectedCents: Double, tolerance: Double) -> some View {
        let expected = Note(midi: expectedMidi)
        return VStack(alignment: .leading, spacing: 6) {
            if let reading = snapshot.pitch {
                let nearest = Note.nearest(to: reading.frequency)
                let offset = expected.cents(of: reading.frequency)
                let ok = abs(offset - expectedCents) <= tolerance
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(nearest.note.spelled().description)
                        .riffleFont(.display, size: 40, weight: .heavy)
                    Text(String(format: "%+.1f¢ vs %@", offset, expected.spelled().description))
                        .riffleFont(.mono, size: 15, weight: .medium)
                }
                .foregroundStyle(ok ? RiffleColor.lime : RiffleColor.orange)
                Text(String(format: "%.2f Hz · clarity %.2f", reading.frequency, reading.clarity))
                    .riffleFont(.mono, size: 12).foregroundStyle(RiffleColor.textMuted)
            } else {
                Text("Pick the string…").riffleFont(.body, size: 17, weight: .semibold).foregroundStyle(RiffleColor.textMuted)
            }
            Text(String(format: "Expect %@ %+.0f¢ ±%.0f", expected.spelled().description, expectedCents, tolerance))
                .riffleFont(.mono, size: 12).foregroundStyle(RiffleColor.textDim)
        }
    }

    @ViewBuilder
    private var chordReadout: some View {
        if let chord = shot.targetChord ?? Chord(symbol: "Am") {
            let evidence = snapshot.chord ?? ChordEvidence()
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Text(chord.symbol).riffleFont(.display, size: 28, weight: .heavy).foregroundStyle(RiffleColor.text)
                    ForEach(chord.tones, id: \.interval) { tone in
                        let heard = evidence.heard.contains(tone.note.pitchClass)
                        VStack(spacing: 2) {
                            Text(tone.interval.slotLabel).riffleFont(.mono, size: 10, weight: .medium)
                            Text(tone.note.description).riffleFont(.display, size: 18, weight: .bold)
                        }
                        .foregroundStyle(heard ? RiffleColor.limeInk : RiffleColor.textMuted)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 10).fill(heard ? RiffleColor.lime : RiffleColor.surfaceRaised))
                    }
                }
                Text(verdictText(evidence)).riffleFont(.body, size: 15, weight: .semibold).foregroundStyle(verdictColor(evidence))
                ChromaBars(chroma: evidence.chroma, chord: chord)
            }
        }
    }

    private func verdictText(_ evidence: ChordEvidence) -> String {
        let extra = evidence.extra.map(\.description).sorted().joined(separator: " ")
        switch evidence.verdict {
        case .waiting: return "Strum when ready…"
        case .listening: return extra.isEmpty ? "Listening…" : "Listening… also hearing \(extra)"
        case .passed: return "Would pass ✓"
        case .failed:
            let missing = evidence.missing.map(\.description).sorted().joined(separator: " ")
            var parts: [String] = []
            if !missing.isEmpty { parts.append("missing \(missing)") }
            if !extra.isEmpty { parts.append("extra \(extra)") }
            return "Wouldn't pass: " + (parts.isEmpty ? "too short" : parts.joined(separator: ", "))
        }
    }

    private func verdictColor(_ evidence: ChordEvidence) -> Color {
        switch evidence.verdict {
        case .passed: RiffleColor.lime
        case .failed: RiffleColor.orange
        default: RiffleColor.textMuted
        }
    }
}

/// 12 bars, one per pitch class; chord tones in lime, others muted.
private struct ChromaBars: View {
    let chroma: [Double]
    let chord: Chord

    var body: some View {
        HStack(alignment: .bottom, spacing: 4) {
            ForEach(0..<12, id: \.self) { pc in
                let inChord = chord.pitchClasses.contains(PitchClass(pc))
                VStack(spacing: 3) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(inChord ? RiffleColor.lime : RiffleColor.orange.opacity(0.8))
                        .frame(height: max(2, 44 * chroma[pc]))
                    Text(PitchClass(pc).description)
                        .riffleFont(.mono, size: 9, maxScale: 1)
                        .foregroundStyle(inChord ? RiffleColor.text : RiffleColor.textDim)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 60, alignment: .bottom)
        .animation(.linear(duration: 0.08), value: chroma)
        .accessibilityHidden(true)
    }
}
