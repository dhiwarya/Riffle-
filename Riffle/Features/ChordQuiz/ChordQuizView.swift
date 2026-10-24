import RiffleAudio
import RiffleDesign
import RiffleQuiz
import RiffleStore
import RiffleTheory
import SwiftData
import SwiftUI
import UIKit

/// "Play the chord" (mockup screen 3): the chord card, live per-tone slots, coaching, Hint,
/// Show me how and Skip. Ends on the results screen.
struct ChordQuizView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(Pref.dailyMinutes) private var dailyMinutes = Pref.Default.dailyMinutes
    @State private var model: ChordQuizModel
    @State private var showReveal = false
    @State private var finished = false

    init(settings: ChordQuizSession.Settings, tuning: Tuning, a4: Double, isFreePractice: Bool = false) {
        _model = State(initialValue: ChordQuizModel(settings: settings, tuning: tuning, a4: a4, isFreePractice: isFreePractice))
    }

    var body: some View {
        Group {
            if finished {
                ChordResultsView(session: model.session, practise: startPractice, done: { dismiss() })
            } else {
                GeometryReader { geo in
                    ScrollView {
                        quiz.frame(minHeight: geo.size.height)
                    }
                    .scrollIndicators(.hidden)
                    .scrollBounceBehavior(.basedOnSize)
                }
            }
        }
        .background(DotGridBackground())
        .task { await model.start() }
        .onDisappear { model.stop() }
        .fullScreenCover(isPresented: $showReveal, onDismiss: { model.closeReveal() }) {
            if let item = model.item {
                ChordRevealView(chord: item.chord, tuning: model.tuning, a4: model.a4,
                                startOnTriads: item.inversion != nil, initialTriad: item.inversion)
            }
        }
    }

    private var quiz: some View {
        VStack(spacing: 16) {
            header
            if let item = model.item {
                ChordCard(item: item, level: model.session.settings.level, phase: model.phase)
                    .id(item.key)
                    .transition(.asymmetric(insertion: .offset(x: 60).combined(with: .opacity),
                                            removal: .offset(x: -60).combined(with: .opacity)))
            }
            micPanel
            if model.hintOpen {
                Text("Hint: \(model.hint)")
                    .riffleFont(.body, size: 14)
                    .foregroundStyle(RiffleColor.nut)
                    .lineSpacing(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .riffleCard(cornerRadius: 16)
                    .transition(.asymmetric(insertion: .offset(y: 16).combined(with: .opacity), removal: .opacity))
            }
            Spacer(minLength: 0)
            actions
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .animation(.timingCurve(0.2, 0.9, 0.3, 1.2, duration: 0.45), value: model.hintOpen)
        .animation(.timingCurve(0.2, 0.9, 0.3, 1.2, duration: 0.45), value: model.feedback)
        .animation(.snappy, value: model.item?.key)
        .sensoryFeedback(trigger: model.phase) { _, new in
            switch new {
            case .passed: .success
            case .timedOut: .warning
            case .playing: nil
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: model.feedback) { _, new in new != nil }
        .task(id: model.phase) {
            // Pop, then on to the next chord.
            guard case .passed = model.phase else { return }
            try? await Task.sleep(for: .seconds(1.6))
            guard !Task.isCancelled else { return }
            goNext()
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 14) {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(RiffleColor.text)
                    .frame(width: 44, height: 44)
                    .riffleCard(cornerRadius: 22)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close quiz")
            ProgressDots(total: model.session.total, current: model.session.number, track: .chords)
                .accessibilityLabel("Chord \(model.session.number) of \(model.session.total)")
            if let remaining = model.remaining, let limit = model.timeLimit {
                CountdownRing(remaining: remaining, total: limit)
            }
        }
    }

    // MARK: Mic panel

    @ViewBuilder
    private var micPanel: some View {
        VStack(spacing: 14) {
            switch model.availability {
            case .denied:
                MicDeniedNotice()
            case .failed(let message):
                Text("The microphone didn't start: \(message)")
                    .riffleFont(.body, size: 15)
                    .foregroundStyle(RiffleColor.textMuted)
            case .idle, .listening:
                statusRow
                WaveBars(levelDB: model.levelDB, active: model.isListening, dimmed: model.feedback != nil)
                    .frame(height: 44)
                if let item = model.item {
                    ToneSlots(chord: item.chord, heard: heardTones)
                }
                if let feedback = model.feedback {
                    feedbackRow(feedback)
                }
            }
        }
        .padding(16)
        .riffleCard(cornerRadius: 24, fill: RiffleColor.surface, border: RiffleColor.border)
        .accessibilityElement(children: .contain)
    }

    private var heardTones: Set<PitchClass> {
        if case .passed = model.phase, let item = model.item { return item.chord.requiredPitchClasses }
        return model.evidence.heard
    }

    private var statusRow: some View {
        HStack(spacing: 12) {
            Image(systemName: status.icon)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(status.ink)
                .frame(width: 36, height: 36)
                .background(Circle().fill(status.fill))
                .modifier(PulseIf(active: model.isListening && !reduceMotion, color: RiffleColor.orange))
            VStack(alignment: .leading, spacing: 1) {
                Text(status.title)
                    .riffleFont(.body, size: 16, weight: .bold)
                    .foregroundStyle(RiffleColor.text)
                    .contentTransition(.opacity)
                Text(status.subtitle)
                    .riffleFont(.body, size: 13)
                    .foregroundStyle(RiffleColor.textMuted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .animation(.easeOut(duration: 0.2), value: status.title)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.updatesFrequently)
    }

    private struct Status {
        var title: String
        var subtitle: String
        var icon = "mic.fill"
        var fill = RiffleColor.orange
        var ink = RiffleColor.orangeInk
    }

    private var status: Status {
        let required = model.item?.chord.requiredPitchClasses.count ?? 0
        let anyShape = model.item?.requiredBass.flatMap { bass in
            model.item?.chord.tone(for: bass).map { "Any octave · \($0.note) lowest" }
        } ?? "Any octave, any shape"
        switch model.phase {
        case .passed(let attempt):
            let detail = attempt.strums <= 1 ? "Clean on the first strum." : "Got it in \(attempt.strums) strums."
            return Status(title: "Nailed it!", subtitle: detail, icon: "checkmark", fill: RiffleColor.lime, ink: RiffleColor.limeInk)
        case .timedOut:
            return Status(title: "Time's up", subtitle: "Look at the shape, then try the next one.", icon: "clock",
                          fill: RiffleColor.surfaceSunken, ink: RiffleColor.textMuted)
        case .playing:
            if model.hearsNothing {
                return Status(title: "Can't hear you yet", subtitle: "Move closer or strum a little harder.")
            }
            switch model.evidence.verdict {
            case .waiting: return Status(title: "Listening… strum when ready", subtitle: anyShape)
            case .listening: return Status(title: "Hearing you…", subtitle: anyShape)
            case .failed:
                let heard = model.evidence.heard.count
                return heard == required
                    ? Status(title: "All \(required) notes, but…", subtitle: "Let it ring, then strum once more")
                    : Status(title: "Heard \(heard) of \(required) notes", subtitle: "Let it ring, then strum once more")
            case .passed: return Status(title: "Nailed it!", subtitle: "", icon: "checkmark", fill: RiffleColor.lime, ink: RiffleColor.limeInk)
            }
        }
    }

    private func feedbackRow(_ text: String) -> some View {
        HStack(spacing: 10) {
            Text(text)
                .riffleFont(.body, size: 14)
                .foregroundStyle(Color(hex: 0xFFD2B8))
                .lineSpacing(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            if model.phase == .playing {
                Button("Listen again") { model.listenAgain() }
                    .riffleFont(.body, size: 13, weight: .bold)
                    .foregroundStyle(Color(hex: 0xFFB48A))
                    .padding(.horizontal, 12)
                    .frame(height: 36)
                    .overlay(Capsule().strokeBorder(Color(hex: 0xFFB48A), lineWidth: 1.5))
                    .buttonStyle(.plain)
                    .fixedSize()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(hex: 0x3A2214)))
        .transition(.asymmetric(insertion: .offset(y: 16).combined(with: .opacity), removal: .opacity))
        .accessibilityElement(children: .combine)
    }

    // MARK: Actions

    @ViewBuilder
    private var actions: some View {
        VStack(spacing: 10) {
            switch model.phase {
            case .playing:
                HStack(spacing: 10) {
                    Button { model.toggleHint() } label: {
                        Text(model.hintOpen ? "Hide hint" : "Hint")
                            .frame(maxWidth: .infinity, minHeight: 54)
                    }
                    .buttonStyle(QuizButtonStyle(kind: .secondary))
                    Button { openReveal() } label: {
                        Text("Show me how").frame(maxWidth: .infinity, minHeight: 54)
                    }
                    .buttonStyle(QuizButtonStyle(kind: .primary))
                }
                Button("Skip this chord") {
                    model.skip()
                    goNext()
                }
                .riffleFont(.body, size: 14, weight: .semibold)
                .foregroundStyle(RiffleColor.textMuted)
                .frame(maxWidth: .infinity, minHeight: 44)
                .buttonStyle(.plain)
            case .timedOut:
                HStack(spacing: 10) {
                    Button { openReveal() } label: {
                        Text("Show me how").frame(maxWidth: .infinity, minHeight: 54)
                    }
                    .buttonStyle(QuizButtonStyle(kind: .secondary))
                    Button { goNext() } label: {
                        Text(isLast ? "See results" : "Next chord").frame(maxWidth: .infinity, minHeight: 54)
                    }
                    .buttonStyle(QuizButtonStyle(kind: .primary))
                }
                Color.clear.frame(height: 44)
            case .passed:
                Button { goNext() } label: {
                    Text(isLast ? "See results" : "Next chord").frame(maxWidth: .infinity, minHeight: 54)
                }
                .buttonStyle(QuizButtonStyle(kind: .lime))
                Color.clear.frame(height: 44)
            }
        }
    }

    private var isLast: Bool { model.session.number >= model.session.total }

    private func openReveal() {
        model.openReveal()
        showReveal = true
    }

    private func goNext() {
        withAnimation(.snappy) {
            if !model.next() {
                saveSession()
                finished = true
            }
        }
    }

    private func startPractice(_ items: [ChordItem]) {
        model.stop()
        model = ChordQuizModel(settings: .init(items: items, level: model.session.settings.level, timeLimit: nil),
                               tuning: model.tuning, a4: model.a4, isFreePractice: true)
        finished = false
        Task { await model.start() }
    }

    // MARK: Saving

    /// Session, attempts and the day's progress (D6: a practice round counts as free practice time).
    private func saveSession() {
        let session = model.session
        let record = SessionRecord(kind: .chord, isFreePractice: model.isFreePractice, score: session.score,
                                   total: session.attempts.count, durationSec: model.durationSeconds,
                                   level: session.settings.level)
        modelContext.insert(record)
        for attempt in session.attempts {
            let detail: [String: String] = [
                "outcome": attempt.outcome.rawValue,
                "strums": String(attempt.strums),
                "missing": attempt.missing.map(\.description).joined(separator: " "),
                "extra": attempt.extra.map(\.description).joined(separator: " "),
                "reveal": String(attempt.usedReveal),
                "tuning": model.tuning.id,
            ]
            modelContext.insert(AttemptRecord(
                sessionID: record.id, itemKey: attempt.item.key,
                grade: Grade(rawValue: attempt.grade.rawValue) ?? .again,
                responseMs: Int(attempt.elapsed * 1000), usedHint: attempt.usedHint, replays: 0,
                detailJSON: try? JSONEncoder().encode(detail)
            ))
        }
        if let day = try? DayActivity.forDay(.now, goalMinutes: dailyMinutes, in: modelContext) {
            if model.isFreePractice { day.freePracticeSec += model.durationSeconds } else { day.chordDone = true }
        }
    }
}

// MARK: - Pieces

/// The big orange card: "PLAY THIS CHORD · Am · A minor — any voicing counts". Wobbles gently;
/// turns lime when the chord passes.
private struct ChordCard: View {
    let item: ChordItem
    let level: Int
    let phase: ChordQuizModel.Phase

    private var passed: Bool { if case .passed = phase { true } else { false } }

    var body: some View {
        let ink = passed ? RiffleColor.limeInk : RiffleColor.orangeInk
        VStack(spacing: 10) {
            MonoLabel(passed ? "Nailed it" : "Play this chord")
            Text(item.chord.symbol)
                .riffleFont(.display, size: 120, weight: .heavy, maxScale: 1, tracking: -0.03)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(height: 112)
                .scaleEffect(passed ? 1.06 : 1)
            Text(item.subtitle)
                .riffleFont(.body, size: 16, weight: .semibold)
                .multilineTextAlignment(.center)
            HStack(spacing: 8) {
                chip(item.kindLabel)
                chip("Level \(level)")
            }
        }
        .foregroundStyle(ink)
        .padding(.horizontal, 20)
        .padding(.top, 22)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 32)
                .fill(passed ? RiffleColor.lime : RiffleColor.orange)
                .shadow(color: passed ? Color(hex: 0x6E8A1F) : Track.chords.shadow, radius: 0, y: 7)
        }
        .pingPong(duration: 1.5) { view, on in view.rotationEffect(.degrees(passed ? 0 : (on ? 1.5 : -1.5))) }
        .animation(RiffleMotion.pop, value: passed)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Play this chord: \(item.chord.name). \(item.subtitle)")
    }

    private func chip(_ text: String) -> some View {
        Text(text)
            .riffleFont(.body, size: 13, weight: .semibold)
            .padding(.horizontal, 12)
            .frame(height: 28)
            .background(Capsule().fill(Color(hex: 0x1A0F05).opacity(0.14)))
    }
}

/// ROOT / ♭3RD / 5TH: dashed "?" until the tone is heard, then a lime tile with the note.
private struct ToneSlots: View {
    let chord: Chord
    let heard: Set<PitchClass>

    var body: some View {
        let tones = chord.tones.filter { !$0.isOptional }
        HStack(spacing: 10) {
            ForEach(tones, id: \.interval) { tone in
                let isHeard = heard.contains(tone.note.pitchClass)
                VStack(spacing: 6) {
                    MonoLabel(tone.interval.slotLabel, size: 11, tracking: 0.1)
                        .foregroundStyle(isHeard ? RiffleColor.limeInk : RiffleColor.textMuted)
                    ZStack {
                        if isHeard {
                            Text(tone.note.description)
                                .riffleFont(.display, size: 30, weight: .heavy, maxScale: 1)
                                .foregroundStyle(RiffleColor.limeInk)
                                .transition(.scale(scale: 0.4).combined(with: .opacity))
                        } else {
                            Text("?")
                                .riffleFont(.display, size: 30, weight: .heavy, maxScale: 1)
                                .foregroundStyle(RiffleColor.textDim)
                                .blinking(period: 1.4)
                                .transition(.opacity)
                        }
                    }
                    .frame(height: 32)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 10)
                .padding(.bottom, 12)
                .background {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isHeard ? RiffleColor.lime : .clear)
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(isHeard ? RiffleColor.lime : RiffleColor.fretLine,
                                      style: StrokeStyle(lineWidth: 1.5, dash: isHeard ? [] : [5, 4]))
                }
                .animation(RiffleMotion.pop, value: isHeard)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(tone.interval.slotLabel.lowercased()), \(tone.note.description): \(isHeard ? "heard" : "not heard yet")")
            }
        }
    }
}

/// 30 orange bars that dance with the mic level.
private struct WaveBars: View {
    let levelDB: Double
    let active: Bool
    let dimmed: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: !active || reduceMotion)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            // -65 dB → barely moving, -20 dB → full height.
            let loudness = max(0.12, min(1, (levelDB + 65) / 45))
            HStack(alignment: .center, spacing: 0) {
                ForEach(0..<30, id: \.self) { index in
                    let shape = 10 + 34 * abs(sin(Double(index) * 0.55))
                    let wave = active && !reduceMotion ? 0.15 + 0.85 * abs(sin(time * 3.5 + Double(index) * 0.45)) : 0.4
                    Capsule()
                        .fill(RiffleColor.orange)
                        .frame(width: 5, height: max(4, shape * wave * (active ? loudness : 0.3)))
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(maxHeight: .infinity)
            .opacity(dimmed || !active ? 0.35 : 1)
        }
        .accessibilityHidden(true)
    }
}

private struct PulseIf: ViewModifier {
    let active: Bool
    let color: Color

    func body(content: Content) -> some View {
        if active { content.pulseRing(color, spread: 6, duration: 1.2) } else { content }
    }
}

/// Mic permission was declined: say why it matters and link to Settings.
struct MicDeniedNotice: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Microphone is off", systemImage: "mic.slash.fill")
                .riffleFont(.body, size: 16, weight: .bold)
                .foregroundStyle(RiffleColor.text)
            Text("Riffle listens to your guitar to check each chord. Nothing is recorded or sent anywhere.")
                .riffleFont(.body, size: 14)
                .foregroundStyle(RiffleColor.textMuted)
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
            }
            .buttonStyle(ChipButtonStyle(isSelected: true))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The quiz's big buttons: cream primary, dark secondary, lime after a pass.
struct QuizButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary, lime }
    let kind: Kind

    func makeBody(configuration: Configuration) -> some View {
        let fill: Color = switch kind {
        case .primary: RiffleColor.text
        case .secondary: RiffleColor.surfaceRaised
        case .lime: RiffleColor.lime
        }
        let ink: Color = switch kind {
        case .primary: RiffleColor.background
        case .secondary: RiffleColor.text
        case .lime: RiffleColor.limeInk
        }
        configuration.label
            .riffleFont(.body, size: 16, weight: .bold)
            .foregroundStyle(ink)
            .background {
                Capsule().fill(fill)
                if kind == .secondary { Capsule().strokeBorder(RiffleColor.borderStrong, lineWidth: 1.5) }
            }
            .contentShape(Capsule())
            .offset(y: configuration.isPressed ? 3 : 0)
            .animation(RiffleMotion.press, value: configuration.isPressed)
    }
}
