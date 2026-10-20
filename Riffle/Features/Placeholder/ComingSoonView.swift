import RiffleDesign
import SwiftUI

/// Destinations that exist in the plan but aren't built yet.
enum ComingSoon: String, Identifiable {
    case chordQuiz, earCheck, progress, chordLibrary, earSession

    var id: String { rawValue }

    var title: String {
        switch self {
        case .chordQuiz: "Play the chord"
        case .earCheck: "Name that note"
        case .progress: "Your progress"
        case .chordLibrary: "Chord library"
        case .earSession: "Ear session"
        }
    }

    var track: Track {
        switch self {
        case .chordQuiz, .chordLibrary: .chords
        case .earCheck, .earSession: .ear
        case .progress: .tuner
        }
    }

    var milestone: String {
        switch self {
        case .earCheck: "M3"
        case .chordQuiz: "M4"
        case .chordLibrary, .earSession: "M6"
        case .progress: "M7"
        }
    }
}

/// Full-screen placeholder with a close button top left, like the quiz flows will have.
struct ComingSoonView: View {
    let feature: ComingSoon
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(RiffleColor.text)
                    .frame(width: 44, height: 44)
                    .riffleCard(cornerRadius: 22)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")

            Spacer()

            VStack(alignment: .leading, spacing: 12) {
                MonoLabel("Coming in \(feature.milestone)")
                    .foregroundStyle(feature.track.accent)
                Text(feature.title)
                    .riffleFont(.display, size: 40, weight: .heavy, relativeTo: .largeTitle, maxScale: 1.2, tracking: -0.02)
                    .foregroundStyle(RiffleColor.text)
                Text("This part of Riffle isn’t built yet. It’s on the plan, so check back soon.")
                    .riffleFont(.body, size: 16)
                    .foregroundStyle(RiffleColor.textMuted)
            }
            .riseIn()

            Spacer()

            PedalButton("Back to practice", track: feature.track) { dismiss() }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(DotGridBackground())
    }
}

#Preview {
    ComingSoonView(feature: .chordQuiz)
}
