import RiffleAudio
import RiffleDesign
import RiffleStore
import RiffleTheory
import SwiftData
import SwiftUI

/// The Tuner tab (mockup screen 2). Listens only while the tab is visible and the app is active.
struct TunerView: View {
    let isActive: Bool

    @AppStorage(Pref.tuningID) private var tuningID = Pref.Default.tuningID
    @AppStorage(Pref.a4Hz) private var a4 = Pref.Default.a4Hz
    @AppStorage(Pref.tunerMode) private var storedMode = TunerEngine.Mode.auto
    @AppStorage(Pref.dailyMinutes) private var dailyMinutes = Pref.Default.dailyMinutes
    @Query(sort: \CustomTuning.createdAt) private var customTunings: [CustomTuning]
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var model = TunerModel()
    @State private var showTuningPicker = false

    private var tuning: Tuning { Tuning.resolve(id: tuningID, custom: customTunings) }
    private var shouldListen: Bool { isActive && scenePhase == .active }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                header
                switch model.availability {
                case .denied:
                    MicrophoneDeniedCard()
                case .failed(let message):
                    MicrophoneDeniedCard(message: "The microphone couldn't start: \(message)")
                case .idle, .listening:
                    notePanel
                    TunerGauge(cents: model.state.cents, isInTune: model.state.isInTune)
                        .frame(maxWidth: .infinity)
                }
                Headstock(tuning: tuning, state: model.state) { index in
                    storedMode = .manual
                    model.select(string: index)
                }
                .padding(.top, 6)
                if model.isUsingBluetoothMic {
                    Text("A Bluetooth headset mic is active. Disconnect it for an accurate reading.")
                        .riffleFont(.body, size: 13, weight: .semibold)
                        .foregroundStyle(RiffleColor.orange)
                        .multilineTextAlignment(.center)
                }
                Text(footer)
                    .riffleFont(.body, size: 13)
                    .foregroundStyle(RiffleColor.textMuted)
                    .multilineTextAlignment(.center)
                    .contentTransition(.opacity)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .background(DotGridBackground())
        .sheet(isPresented: $showTuningPicker) {
            TuningPickerSheet(tuningID: $tuningID, a4: $a4)
        }
        .sensoryFeedback(.success, trigger: model.state.tunedEvents)
        .sensoryFeedback(.selection, trigger: model.state.selectedString)
        .onAppear {
            model.mode = storedMode
            model.configure(tuning: tuning, a4: a4)
        }
        .onChange(of: tuning) { _, new in model.configure(tuning: new, a4: a4) }
        .onChange(of: a4) { _, new in model.configure(tuning: tuning, a4: new) }
        .onChange(of: storedMode) { _, new in model.mode = new }
        .onChange(of: model.state.allTuned) { _, allTuned in
            if allTuned { markTunedToday() }
        }
        .task(id: shouldListen) {
            if shouldListen { await model.start() } else { model.stop() }
        }
        .onDisappear { model.stop() }
    }

    // MARK: Pieces

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Tuner")
                    .riffleFont(.display, size: 34, weight: .heavy, relativeTo: .largeTitle, maxScale: 1.2)
                    .foregroundStyle(RiffleColor.text)
                    .accessibilityAddTraits(.isHeader)
                Button { showTuningPicker = true } label: {
                    HStack(spacing: 4) {
                        Text("\(tuning.name) · A4 = \(Int(a4)) Hz")
                            .riffleFont(.mono, size: 12, relativeTo: .caption)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Image(systemName: "chevron.down").font(.system(size: 10, weight: .bold))
                    }
                    .foregroundStyle(RiffleColor.textMuted)
                    .frame(minHeight: 28)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Tuning: \(tuning.name), A4 \(Int(a4)) hertz. Change")
            }
            Spacer(minLength: 0)
            SegmentedPill("Detection mode", options: [(TunerEngine.Mode.auto, "Auto"), (.manual, "Manual")],
                          selection: $storedMode)
                .frame(width: 172)
        }
    }

    private var notePanel: some View {
        let state = model.state
        let pitch = tuning.strings[state.selectedString]
        let hz = state.frequency ?? tuning.notes[state.selectedString].frequency(a4: a4)
        return VStack(spacing: 6) {
            Text(pitch.name.description)
                .riffleFont(.display, size: 112, weight: .heavy, relativeTo: .largeTitle, maxScale: 1)
                .foregroundStyle(state.isInTune ? RiffleColor.lime : RiffleColor.text)
                .shadow(color: state.isInTune ? RiffleColor.lime.opacity(0.6) : .clear, radius: 14)
                .contentTransition(.interpolate)
                .animation(.easeOut(duration: 0.25), value: state.isInTune)
            Text("\(pitch.description) · string \(Tuning.stringNumber(forIndex: state.selectedString)) · \(hz, format: .number.precision(.fractionLength(1))) Hz")
                .riffleFont(.mono, size: 14, relativeTo: .caption)
                .foregroundStyle(RiffleColor.textMuted)
                .monospacedDigit()
            StatusPill(state: state, tuning: tuning, mode: storedMode)
        }
        .padding(.top, 6)
        .accessibilityElement(children: .combine)
    }

    private var footer: String {
        if model.state.allTuned { return "All six strings in tune. Go play." }
        return storedMode == .auto ? "Auto: just pluck — we detect the string." : "Manual: tap a peg, then pluck that string."
    }

    private func markTunedToday() {
        guard let day = try? DayActivity.forDay(.now, goalMinutes: dailyMinutes, in: modelContext) else { return }
        day.tuned = true
    }
}

/// "In tune" / "Too low — tighten" / "Pluck a string".
private struct StatusPill: View {
    let state: TunerState
    let tuning: Tuning
    let mode: TunerEngine.Mode

    var body: some View {
        HStack(spacing: 6) {
            if state.isInTune {
                Image(systemName: "checkmark").font(.system(size: 13, weight: .heavy))
                Text("In tune")
            } else if let cents = state.cents {
                Text(cents < 0 ? "Too low — tighten" : "Too high — loosen")
            } else {
                Text(mode == .auto ? "Pluck any string" : "Pluck the \(tuning.strings[state.selectedString].name.description) string")
            }
        }
        .riffleFont(.body, size: 14, weight: .bold)
        .foregroundStyle(foreground)
        .padding(.horizontal, 14)
        .frame(height: 32)
        .background(Capsule().fill(background))
        .scaleEffect(state.isInTune ? 1 : 0.98)
        .animation(RiffleMotion.pop, value: state.isInTune)
    }

    private var foreground: Color {
        if state.isInTune { return RiffleColor.limeInk }
        return state.hasSignal ? Color(hex: 0xFFB48A) : RiffleColor.textMuted
    }

    private var background: Color {
        if state.isInTune { return RiffleColor.lime }
        return state.hasSignal ? Color(hex: 0x3A2214) : RiffleColor.surfaceRaised
    }
}

/// Shown instead of the meter when microphone access is off.
private struct MicrophoneDeniedCard: View {
    var message = "Riffle needs the microphone to hear your guitar. Audio never leaves your phone."
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: "mic.slash.fill")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(RiffleColor.orange)
            Text("Microphone is off")
                .riffleFont(.display, size: 26, weight: .heavy)
                .foregroundStyle(RiffleColor.text)
            Text(message)
                .riffleFont(.body, size: 15)
                .foregroundStyle(RiffleColor.textMuted)
            PedalButton("Open Settings", track: .tuner) {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            }
        }
        .padding(20)
        .riffleCard(cornerRadius: 28, fill: RiffleColor.surface, border: RiffleColor.border)
        .padding(.vertical, 12)
    }
}

#Preview {
    TunerView(isActive: false)
        .modelContainer(PreviewData.container)
        .preferredColorScheme(.dark)
}
