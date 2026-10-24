import RiffleDesign
import RiffleQuiz
import RiffleTheory
import SwiftUI

/// End of a chord round: score, each chord with its time and grade, and "Practise these".
struct ChordResultsView: View {
    let session: ChordQuizSession
    let practise: ([ChordItem]) -> Void
    let done: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 6) {
                    MonoLabel("Play the chord · Level \(session.settings.level)").foregroundStyle(Track.chords.accent)
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(session.score)")
                            .riffleFont(.display, size: 88, weight: .heavy, maxScale: 1)
                            .foregroundStyle(RiffleColor.text)
                        Text("/ \(session.attempts.count)")
                            .riffleFont(.display, size: 32, weight: .bold, maxScale: 1)
                            .foregroundStyle(RiffleColor.textMuted)
                    }
                    Text(headline)
                        .riffleFont(.body, size: 17)
                        .foregroundStyle(RiffleColor.textSoft)
                }
                .riseIn()

                VStack(spacing: 0) {
                    ForEach(Array(session.attempts.enumerated()), id: \.offset) { offset, attempt in
                        AttemptRow(attempt: attempt)
                        if offset < session.attempts.count - 1 {
                            Rectangle().fill(RiffleColor.border).frame(height: 1)
                        }
                    }
                }
                .padding(.horizontal, 18)
                .riffleCard(cornerRadius: 24, fill: RiffleColor.surface, border: RiffleColor.border)
                .riseIn(delay: 0.1)

                VStack(spacing: 12) {
                    if !session.practiseThese.isEmpty {
                        Button { practise(session.practiseThese) } label: {
                            Label("Practise these", systemImage: "target")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(ChipButtonStyle(track: .chords))
                    }
                    PedalButton("Done", track: .chords, action: done)
                }
                .padding(.top, 4)
                .riseIn(delay: 0.2)
            }
            .padding(20)
        }
        .scrollIndicators(.hidden)
    }

    private var headline: String {
        let total = max(session.attempts.count, 1)
        let clean = session.attempts.filter { $0.grade == .easy }.count
        if session.score == total && clean == total { return "Every chord clean on the first strum." }
        switch Double(session.score) / Double(total) {
        case 1...: return "All of them. Your hands know these."
        case 0.6..<1: return "Nearly there. One more look at the shape helps."
        case 0.01..<0.6: return "A good start. Practise the ones that got away."
        default: return "Tough round. Show me how is there for exactly this."
        }
    }
}

private struct AttemptRow: View {
    let attempt: ChordAttempt

    var body: some View {
        HStack(spacing: 14) {
            Text(attempt.item.chord.symbol)
                .riffleFont(.display, size: 26, weight: .heavy, maxScale: 1.2)
                .foregroundStyle(RiffleColor.text)
                .frame(minWidth: 64, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(detail)
                    .riffleFont(.body, size: 14, weight: .semibold)
                    .foregroundStyle(RiffleColor.textSoft)
                if !attempt.missing.isEmpty || !attempt.extra.isEmpty {
                    Text(notes)
                        .riffleFont(.mono, size: 11)
                        .foregroundStyle(RiffleColor.textMuted)
                }
            }
            Spacer(minLength: 0)
            Text(gradeLabel)
                .riffleFont(.mono, size: 12, weight: .medium)
                .foregroundStyle(gradeInk)
                .padding(.horizontal, 10)
                .frame(height: 26)
                .background(Capsule().fill(gradeFill))
        }
        .padding(.vertical, 14)
        .accessibilityElement(children: .combine)
    }

    private var detail: String {
        switch attempt.outcome {
        case .passed:
            let time = "\(Int(attempt.elapsed.rounded())) s"
            let help = attempt.usedReveal ? " · after Show me how" : attempt.usedHint ? " · with a hint" : ""
            return "\(time) · \(attempt.strums == 1 ? "1 strum" : "\(attempt.strums) strums")\(help)"
        case .timedOut: return "Ran out of time"
        case .skipped: return "Skipped"
        }
    }

    private var notes: String {
        var parts: [String] = []
        if !attempt.missing.isEmpty { parts.append("missing \(attempt.missing.map { spelled($0) }.joined(separator: " "))") }
        if !attempt.extra.isEmpty { parts.append("extra \(attempt.extra.map { spelled($0) }.joined(separator: " "))") }
        return parts.joined(separator: " · ").uppercased()
    }

    private func spelled(_ pc: PitchClass) -> String {
        attempt.item.chord.tone(for: pc)?.note.description ?? pc.description
    }

    private var gradeLabel: String {
        switch attempt.grade {
        case .easy: "EASY"
        case .good: "GOOD"
        case .hard: "HARD"
        case .again: "AGAIN"
        }
    }

    private var gradeFill: Color {
        switch attempt.grade {
        case .easy, .good: RiffleColor.lime
        case .hard: RiffleColor.surfaceSunken
        case .again: Color(hex: 0x3A2214)
        }
    }

    private var gradeInk: Color {
        switch attempt.grade {
        case .easy, .good: RiffleColor.limeInk
        case .hard: RiffleColor.textSoft
        case .again: Color(hex: 0xFFB48A)
        }
    }
}
