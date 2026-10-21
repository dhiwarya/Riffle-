import RiffleAudio
import RiffleDesign
import RiffleQuiz
import RiffleStore
import RiffleTheory
import SwiftData
import SwiftUI

/// "Name that note" (mockup screen 5, reworked for the key-based model, D2).
struct EarCheckView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @AppStorage(Pref.earAnswerMode) private var naming = DegreeNaming.degrees
    @AppStorage(Pref.playbackSound) private var sound = Instrument.guitar
    @AppStorage(Pref.dailyMinutes) private var dailyMinutes = Pref.Default.dailyMinutes
    @State private var model: EarCheckModel
    @State private var summary: EarSummary?

    init(settings: EarSession.Settings, seed: UInt64, isFreePractice: Bool = false) {
        let instrument = Instrument(rawValue: UserDefaults.standard.string(forKey: Pref.playbackSound) ?? "") ?? .guitar
        _model = State(initialValue: EarCheckModel(settings: settings, seed: seed, instrument: instrument,
                                                   isFreePractice: isFreePractice))
    }

    var body: some View {
        Group {
            if let summary {
                EarResultsView(summary: summary, settings: model.settings, naming: naming,
                               practise: { focus in startFocusSession(focus) }, done: { dismiss() })
            } else {
                quiz
            }
        }
        .background(DotGridBackground())
        .onChange(of: sound) { _, new in model.instrument = new }
        .onDisappear { model.stopAudio() }
    }

    private var quiz: some View {
        VStack(spacing: 12) {
            header
            infoRow
            PlayButton(isPlaying: model.isPlaying, isEnabled: canPlay) { model.play() }
                .frame(height: 200)
            replayRow
            feedback
            pads
                .padding(.top, 6)
            Spacer(minLength: 0)
            nextButton
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 16)
        .sensoryFeedback(trigger: model.feedback) { _, new in
            switch new {
            case .right: .success
            case .wrong: .error
            case .waiting: nil
            }
        }
        .task {
            model.prepareAudio()
            try? await Task.sleep(for: .seconds(0.5))
            if !model.hasHeardQuestion { model.play() }
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 12) {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(RiffleColor.text)
                    .frame(width: 44, height: 44)
                    .riffleCard(cornerRadius: 22)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close ear check")
            ProgressDots(total: model.settings.questionCount, current: model.session.questionNumber, track: .ear)
            ScorePill(score: model.session.score, bumps: model.scoreBumps)
        }
    }

    private var infoRow: some View {
        HStack(spacing: 8) {
            MonoLabel("Key of \(model.settings.key) · \(model.settings.level.rawValue)", weight: .regular, tracking: 0.1)
                .foregroundStyle(RiffleColor.textMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 0)
            Menu {
                Picker("Answer as", selection: $naming) {
                    Text("Scale degrees (1 2 3)").tag(DegreeNaming.degrees)
                    Text("Note names (C D E)").tag(DegreeNaming.noteNames)
                    Text("Solfège (do re mi)").tag(DegreeNaming.solfege)
                }
                Picker("Sound", selection: $sound) {
                    Label("Guitar", systemImage: "guitars").tag(Instrument.guitar)
                    Label("Piano", systemImage: "pianokeys").tag(Instrument.piano)
                }
            } label: {
                Label(sound == .guitar ? "Guitar" : "Piano", systemImage: "slider.horizontal.3")
                    .riffleFont(.body, size: 13, weight: .bold)
                    .foregroundStyle(RiffleColor.textSoft)
                    .padding(.horizontal, 12)
                    .frame(height: 32)
                    .riffleCard(cornerRadius: 16)
            }
            .accessibilityLabel("Answer and sound options")
        }
    }

    // MARK: Play area

    private var canPlay: Bool {
        !model.hasHeardQuestion || model.isAnswered || model.session.replaysLeft > 0
    }

    private var replayRow: some View {
        HStack(spacing: 8) {
            Button { model.replayKey() } label: {
                Label(model.settings.context == .cadence ? "Replay key" : "Play tonic", systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(ChipButtonStyle())
            Text(model.isAnswered ? "Tap play to hear it again" : "\(model.session.replaysLeft) replays left")
                .riffleFont(.mono, size: 12)
                .foregroundStyle(RiffleColor.textMuted)
        }
    }

    @ViewBuilder
    private var feedback: some View {
        Group {
            switch model.feedback {
            case .waiting:
                Text(model.hasHeardQuestion ? "Which note did you hear?" : "Listen…")
                    .riffleFont(.body, size: 15)
                    .foregroundStyle(RiffleColor.textMuted)
                    .frame(maxWidth: .infinity, minHeight: 48)
            case .right(let answer):
                Label("Nice ear — that was \(describe(answer.question.degree)).", systemImage: "checkmark")
                    .riffleFont(.body, size: 15, weight: .bold)
                    .foregroundStyle(RiffleColor.limeInk)
                    .padding(.horizontal, 14)
                    .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 14).fill(RiffleColor.lime))
                    .transition(.asymmetric(insertion: .offset(y: 12).combined(with: .opacity), removal: .opacity))
            case .wrong(let answer):
                HStack(spacing: 10) {
                    Text("It was **\(describe(answer.question.degree))**, you picked \(describe(answer.picked)).")
                        .riffleFont(.body, size: 15)
                        .foregroundStyle(Color(hex: 0xFFD2B8))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button("Hear both") { model.hearBoth() }
                        .riffleFont(.body, size: 13, weight: .bold)
                        .foregroundStyle(Color(hex: 0xFFB48A))
                        .padding(.horizontal, 12)
                        .frame(height: 36)
                        .overlay(Capsule().strokeBorder(Color(hex: 0xFFB48A), lineWidth: 1.5))
                        .buttonStyle(.plain)
                }
                .padding(.leading, 14)
                .padding(.trailing, 6)
                .frame(minHeight: 48)
                .background(RoundedRectangle(cornerRadius: 14).fill(Color(hex: 0x3A2214)))
                .transition(.asymmetric(insertion: .offset(y: 12).combined(with: .opacity), removal: .opacity))
            }
        }
        .animation(.timingCurve(0.2, 0.9, 0.3, 1.2, duration: 0.4), value: model.feedback)
        .accessibilityElement(children: .combine)
    }

    /// "5 (G)" in degree mode, "G (5)" in note-name mode, "sol (G)" in solfège.
    private func describe(_ degree: ScaleDegree) -> String {
        let labels = naming.labels(for: degree)
        return "\(labels.primary) (\(labels.secondary))"
    }

    // MARK: Pads and next

    private var pads: some View {
        let many = model.session.pool.count > 7
        return FlowPads(spacing: 10) {
            ForEach(model.session.pool, id: \.interval) { degree in
                AnswerPad(degree: degree, naming: naming, state: padState(degree), compact: many,
                          isNew: degree == model.session.newlyAdded) { model.pick(degree) }
            }
        }
        .animation(.snappy, value: model.session.pool)
    }

    private func padState(_ degree: ScaleDegree) -> AnswerPad.State {
        guard let answer = model.session.answers.last, model.isAnswered else { return .idle }
        if degree == answer.question.degree { return answer.isCorrect ? .correct : .reveal }
        if degree == answer.picked { return .wrong }
        return .dimmed
    }

    private var nextButton: some View {
        let last = model.session.questionNumber >= model.settings.questionCount
        return Button {
            if !model.next() { finish() }
        } label: {
            Text(model.isAnswered ? (last ? "See results" : "Next note") : "Pick a note to continue")
                .riffleFont(.body, size: 16, weight: .heavy)
                .foregroundStyle(model.isAnswered ? RiffleColor.background : RiffleColor.textDim)
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(Capsule().fill(model.isAnswered ? RiffleColor.text : RiffleColor.surfaceSunken))
        }
        .buttonStyle(.plain)
        .disabled(!model.isAnswered)
    }

    // MARK: Finishing

    private func finish() {
        let result = model.session.summary
        saveSession()
        withAnimation(.easeOut(duration: 0.3)) { summary = result }
    }

    private func startFocusSession(_ focus: [Interval]) {
        var settings = model.settings
        settings.focus = focus
        settings.questionCount = 8
        model.stopAudio()
        model = EarCheckModel(settings: settings, seed: UInt64.random(in: 1...UInt64.max), instrument: sound, isFreePractice: true)
        model.prepareAudio()
        summary = nil
    }

    /// Session, attempts and the day's progress (D6: a focus round counts as free practice time).
    private func saveSession() {
        let session = model.session
        let record = SessionRecord(kind: .ear, isFreePractice: model.isFreePractice, score: session.score,
                                   total: session.answers.count, durationSec: model.durationSeconds,
                                   level: EarLevel.allCases.firstIndex(of: model.settings.level).map { $0 + 1 } ?? 1)
        modelContext.insert(record)
        for answer in session.answers {
            let detail: [String: String] = [
                "key": model.settings.key.description, "picked": answer.picked.label,
                "midi": String(answer.question.midi), "sound": model.instrument.rawValue,
            ]
            modelContext.insert(AttemptRecord(
                sessionID: record.id,
                itemKey: EarSession.itemKey(degree: answer.question.degree, mode: model.settings.key.mode, context: model.settings.context),
                grade: Grade(rawValue: answer.grade.rawValue) ?? .again,
                responseMs: Int(answer.responseTime * 1000), replays: answer.replaysUsed,
                detailJSON: try? JSONEncoder().encode(detail)
            ))
        }
        if let day = try? DayActivity.forDay(.now, goalMinutes: dailyMinutes, in: modelContext) {
            if model.isFreePractice { day.freePracticeSec += model.durationSeconds } else { day.earDone = true }
        }
    }
}

// MARK: - Pieces

/// Big blue play button with ripples and floating notes while sound plays.
private struct PlayButton: View {
    let isPlaying: Bool
    let isEnabled: Bool
    let action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if isPlaying && !reduceMotion {
                Ripple(delay: 0)
                Ripple(delay: 0.35)
                FloatingNote(symbol: "♪", dx: -30, color: Track.ear.soft, delay: 0).offset(x: -40, y: -40)
                FloatingNote(symbol: "♫", dx: 28, color: RiffleColor.lime, delay: 0.4).offset(x: 40, y: -34)
            }
            Button(action: action) {
                Image(systemName: "play.fill")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(Track.ear.ink)
                    .offset(x: 4)
                    .frame(width: 140, height: 140)
                    .background(Circle().fill(isEnabled ? Track.ear.accent : RiffleColor.surfaceSunken))
                    .background(Circle().fill(Track.ear.shadow).offset(y: 8))
            }
            .buttonStyle(PressDownStyle())
            .disabled(!isEnabled)
            .pingPong(duration: 1.2) { view, on in view.scaleEffect(on ? 1.04 : 1) }
            .accessibilityLabel("Play the mystery note")
        }
        .frame(width: 140, height: 140)
    }
}

private struct PressDownStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .offset(y: configuration.isPressed ? 5 : 0)
            .animation(RiffleMotion.press, value: configuration.isPressed)
    }
}

private struct Ripple: View {
    let delay: Double
    @State private var expanded = false

    var body: some View {
        Circle()
            .strokeBorder(Track.ear.accent, lineWidth: 3)
            .scaleEffect(expanded ? 1.7 : 1)
            .opacity(expanded ? 0 : 0.55)
            .onAppear {
                withAnimation(.easeOut(duration: 1.1).repeatForever(autoreverses: false).delay(delay)) { expanded = true }
            }
    }
}

private struct FloatingNote: View {
    let symbol: String
    let dx: CGFloat
    let color: Color
    let delay: Double
    @State private var flying = false

    var body: some View {
        Text(symbol)
            .font(.system(size: 22, weight: .bold))
            .foregroundStyle(color)
            .offset(x: flying ? dx : 0, y: flying ? -90 : 0)
            .rotationEffect(.degrees(flying ? 20 : 0))
            .opacity(flying ? 0 : 1)
            .onAppear {
                withAnimation(.easeOut(duration: 1.4).repeatForever(autoreverses: false).delay(delay)) { flying = true }
            }
            .accessibilityHidden(true)
    }
}

private struct ScorePill: View {
    let score: Int
    let bumps: Int
    @State private var showBump = false

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "star.fill").font(.system(size: 12, weight: .bold)).foregroundStyle(RiffleColor.lime)
            Text("\(score)").riffleFont(.display, size: 16, weight: .heavy).contentTransition(.numericText())
        }
        .foregroundStyle(RiffleColor.text)
        .padding(.horizontal, 12)
        .frame(height: 36)
        .riffleCard(cornerRadius: 18)
        .overlay(alignment: .topTrailing) {
            if showBump {
                Text("+1")
                    .riffleFont(.display, size: 15, weight: .heavy)
                    .foregroundStyle(RiffleColor.lime)
                    .transition(.asymmetric(insertion: .offset(y: 6).combined(with: .opacity),
                                            removal: .offset(y: -28).combined(with: .opacity)))
                    .offset(x: 4, y: -10)
            }
        }
        .animation(.snappy, value: score)
        .onChange(of: bumps) {
            withAnimation(.easeOut(duration: 0.3)) { showBump = true }
            Task {
                try? await Task.sleep(for: .seconds(0.8))
                withAnimation(.easeIn(duration: 0.4)) { showBump = false }
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Score \(score)")
    }
}

/// An answer key: lime and pop when right, orange and shake when your wrong pick.
private struct AnswerPad: View {
    enum State { case idle, correct, wrong, reveal, dimmed }

    let degree: ScaleDegree
    let naming: DegreeNaming
    let state: State
    let compact: Bool
    let isNew: Bool
    let action: () -> Void
    @SwiftUI.State private var shake = 0.0

    var body: some View {
        let labels = naming.labels(for: degree)
        Button(action: action) {
            VStack(spacing: 0) {
                Text(labels.primary)
                    .riffleFont(.display, size: compact ? 20 : 24, weight: .heavy, maxScale: 1.1)
                Text(labels.secondary)
                    .riffleFont(.mono, size: 10, maxScale: 1.1)
                    .opacity(0.7)
            }
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .frame(height: compact ? 54 : 64)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(background))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(border, lineWidth: 2))
            .overlay(alignment: .topTrailing) {
                if isNew && state == .idle {
                    Text("NEW")
                        .riffleFont(.mono, size: 9, weight: .medium, maxScale: 1)
                        .foregroundStyle(Track.ear.ink)
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(Capsule().fill(Track.ear.accent))
                        .offset(x: 4, y: -6)
                }
            }
        }
        .buttonStyle(KeyStyle())
        .scaleEffect(state == .correct ? 1.06 : 1)
        .offset(x: shake)
        .animation(RiffleMotion.pop, value: state == .correct)
        .onChange(of: state) { _, new in
            guard new == .wrong else { return }
            withAnimation(.easeInOut(duration: 0.07).repeatCount(5, autoreverses: true)) { shake = 6 }
            Task {
                try? await Task.sleep(for: .seconds(0.36))
                withAnimation(.easeOut(duration: 0.08)) { shake = 0 }
            }
        }
        .accessibilityLabel("Answer \(labels.primary), \(labels.secondary)")
    }

    private var background: Color {
        switch state {
        case .correct, .reveal: RiffleColor.lime
        case .wrong: RiffleColor.orange
        case .idle, .dimmed: RiffleColor.surfaceRaised
        }
    }

    private var foreground: Color {
        switch state {
        case .correct, .reveal: RiffleColor.limeInk
        case .wrong: RiffleColor.orangeInk
        case .idle: RiffleColor.text
        case .dimmed: RiffleColor.textDim
        }
    }

    private var border: Color {
        switch state {
        case .correct, .reveal: RiffleColor.lime
        case .wrong: RiffleColor.orange
        case .idle, .dimmed: RiffleColor.borderStrong
        }
    }
}

/// Keys press down onto a short hard shadow.
private struct KeyStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.black.opacity(0.45)).offset(y: configuration.isPressed ? 1 : 5))
            .offset(y: configuration.isPressed ? 4 : 0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

/// Wraps pads four to a row, centring the last row (like the mockup's flex-wrap).
private struct FlowPads: Layout {
    var spacing: CGFloat = 10
    var columns = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 350
        let itemWidth = (width - spacing * CGFloat(columns - 1)) / CGFloat(columns)
        let rows = Int(ceil(Double(subviews.count) / Double(columns)))
        let height = subviews.first.map { $0.sizeThatFits(.init(width: itemWidth, height: nil)).height } ?? 0
        return CGSize(width: width, height: CGFloat(rows) * height + CGFloat(max(rows - 1, 0)) * spacing)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let itemWidth = (bounds.width - spacing * CGFloat(columns - 1)) / CGFloat(columns)
        let height = subviews.first.map { $0.sizeThatFits(.init(width: itemWidth, height: nil)).height } ?? 0
        for (index, subview) in subviews.enumerated() {
            let row = index / columns
            let inRow = min(columns, subviews.count - row * columns)
            let rowWidth = CGFloat(inRow) * itemWidth + CGFloat(inRow - 1) * spacing
            let x = bounds.minX + (bounds.width - rowWidth) / 2 + CGFloat(index % columns) * (itemWidth + spacing)
            let y = bounds.minY + CGFloat(row) * (height + spacing)
            subview.place(at: CGPoint(x: x, y: y), proposal: .init(width: itemWidth, height: height))
        }
    }
}
