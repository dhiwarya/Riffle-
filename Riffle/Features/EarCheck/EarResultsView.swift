import RiffleDesign
import RiffleQuiz
import RiffleTheory
import SwiftUI

/// End of an ear-check session: score, accuracy per degree, most-confused pairs (plan §7.6).
struct EarResultsView: View {
    let summary: EarSummary
    let settings: EarSession.Settings
    let naming: DegreeNaming
    let practise: ([Interval]) -> Void
    let done: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 6) {
                    MonoLabel("Ear check · Key of \(settings.key)").foregroundStyle(Track.ear.accent)
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(summary.score)")
                            .riffleFont(.display, size: 88, weight: .heavy, maxScale: 1)
                            .foregroundStyle(RiffleColor.text)
                        Text("/ \(summary.total)")
                            .riffleFont(.display, size: 32, weight: .bold, maxScale: 1)
                            .foregroundStyle(RiffleColor.textMuted)
                    }
                    Text(headline)
                        .riffleFont(.body, size: 17)
                        .foregroundStyle(RiffleColor.textSoft)
                }
                .riseIn()

                VStack(alignment: .leading, spacing: 10) {
                    MonoLabel("By note").foregroundStyle(RiffleColor.textMuted)
                    ForEach(summary.perDegree, id: \.degree.interval) { result in
                        DegreeBar(result: result, naming: naming)
                    }
                }
                .padding(18)
                .riffleCard(cornerRadius: 24, fill: RiffleColor.surface, border: RiffleColor.border)
                .riseIn(delay: 0.1)

                if !summary.confusions.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        MonoLabel("Mixed up").foregroundStyle(RiffleColor.textMuted)
                        ForEach(Array(summary.confusions.prefix(3).enumerated()), id: \.offset) { _, confusion in
                            HStack {
                                Text("\(label(confusion.target)) heard as \(label(confusion.picked))")
                                    .riffleFont(.body, size: 15, weight: .semibold)
                                    .foregroundStyle(RiffleColor.text)
                                Spacer()
                                Text("\(confusion.count)×")
                                    .riffleFont(.mono, size: 13)
                                    .foregroundStyle(RiffleColor.orange)
                            }
                        }
                    }
                    .padding(18)
                    .riffleCard(cornerRadius: 24, fill: RiffleColor.surface, border: RiffleColor.border)
                    .riseIn(delay: 0.2)
                }

                VStack(spacing: 12) {
                    if !summary.practiseThese.isEmpty {
                        Button { practise(summary.practiseThese) } label: {
                            Label("Practise these", systemImage: "target")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(ChipButtonStyle(track: .ear))
                    }
                    PedalButton("Done", track: .ear, action: done)
                }
                .padding(.top, 4)
            }
            .padding(20)
        }
        .scrollIndicators(.hidden)
    }

    private var headline: String {
        let ratio = summary.total == 0 ? 0 : Double(summary.score) / Double(summary.total)
        switch ratio {
        case 0.9...: return "Sharp ear. That key is yours."
        case 0.7..<0.9: return "Solid. A couple of notes to tidy up."
        case 0.4..<0.7: return "Getting there. Practise the mix-ups below."
        default: return "Tough round. Replay the key more often, it helps."
        }
    }

    private func label(_ degree: ScaleDegree) -> String {
        let labels = naming.labels(for: degree)
        return "\(labels.primary) (\(labels.secondary))"
    }
}

private struct DegreeBar: View {
    let result: EarSummary.DegreeResult
    let naming: DegreeNaming

    var body: some View {
        let labels = naming.labels(for: result.degree)
        let ratio = Double(result.correct) / Double(max(result.total, 1))
        HStack(spacing: 12) {
            Text(labels.primary)
                .riffleFont(.display, size: 18, weight: .heavy)
                .foregroundStyle(RiffleColor.text)
                .frame(width: 44, alignment: .leading)
            GeometryReader { geo in
                Capsule().fill(RiffleColor.surfaceSunken)
                    .overlay(alignment: .leading) {
                        Capsule().fill(ratio >= 0.999 ? RiffleColor.lime : RiffleColor.orange)
                            .frame(width: max(8, geo.size.width * ratio))
                    }
            }
            .frame(height: 10)
            Text("\(result.correct)/\(result.total)")
                .riffleFont(.mono, size: 12)
                .foregroundStyle(RiffleColor.textMuted)
                .frame(width: 34, alignment: .trailing)
        }
        .accessibilityElement(children: .combine)
    }
}
