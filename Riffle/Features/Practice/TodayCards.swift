import RiffleDesign
import RiffleStore
import RiffleTheory
import SwiftUI

/// Orange pedal: "Chord of the day".
struct ChordOfTheDayCard: View {
    let plan: TodayPlan
    let action: () -> Void
    private let track = Track.chords

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    HStack(spacing: 8) {
                        StatusLED(track.glow)
                        MonoLabel("Chord of the day")
                    }
                    Spacer()
                    HStack(spacing: 8) {
                        Knob(track: track, delay: 0)
                        Knob(track: track, delay: 1.3)
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("See it. Play it.")
                        .riffleFont(.display, size: 30, weight: .heavy, relativeTo: .title, maxScale: 1.25, tracking: -0.01)
                    Text("\(plan.chordCount) chords, \(plan.newChords) new · Level \(plan.chordLevel). The mic listens — no tapping answers.")
                        .riffleFont(.body, size: 15)
                        .fixedSize(horizontal: false, vertical: true)
                }
                HStack {
                    HStack(spacing: 8) {
                        ForEach(0..<3, id: \.self) { index in
                            FlipCard(track: track, delay: Double(index) * 0.25)
                        }
                    }
                    .accessibilityHidden(true)
                    Spacer()
                    HStack(spacing: 8) {
                        Text("Start").riffleFont(.body, size: 15, weight: .bold)
                        Image(systemName: "arrow.right").font(.system(size: 14, weight: .bold))
                    }
                    .foregroundStyle(track.soft)
                    .padding(.horizontal, 18)
                    .frame(height: 44)
                    .background(Capsule().fill(track.ink))
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(PedalButtonStyle(track))
        .accessibilityLabel("Chord of the day: \(plan.chordCount) chords. Start")
    }
}

/// Blue pedal: "Ear check".
struct EarCheckCard: View {
    let plan: TodayPlan
    let action: () -> Void
    private let track = Track.ear

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    HStack(spacing: 8) {
                        StatusLED(track.glow, delay: 0.7)
                        MonoLabel("Ear check")
                    }
                    Spacer()
                    EqualizerBars(color: track.ink)
                }
                HStack(alignment: .bottom, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Name that note")
                            .riffleFont(.display, size: 30, weight: .heavy, relativeTo: .title, maxScale: 1.25)
                        Text(subtitle)
                            .riffleFont(.body, size: 15)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "play.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(track.soft)
                        .frame(width: 48, height: 48)
                        .background(Circle().fill(track.ink))
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(PedalButtonStyle(track))
        .accessibilityLabel("Ear check: name that note. \(subtitle)")
    }

    private var subtitle: String {
        "\(plan.earCount) notes · Key of \(plan.earKey.tonic) · \(plan.earDifficulty.rawValue.capitalized)"
    }
}

/// "Tune up first" row, showing the current tuning.
struct TuneUpRow: View {
    let tuning: Tuning
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                MiniStrings()
                VStack(alignment: .leading, spacing: 2) {
                    Text("Tune up first")
                        .riffleFont(.body, size: 16, weight: .bold)
                    Text("\(tuning.name) · \(tuning.noteNamesLabel)")
                        .riffleFont(.mono, size: 12, relativeTo: .caption)
                        .foregroundStyle(RiffleColor.textMuted)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(RiffleColor.lime)
            }
            .foregroundStyle(RiffleColor.text)
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .riffleCard(cornerRadius: 20)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// D10: free practice lives on the Practice tab, under the daily set.
struct FreePracticeSection: View {
    let open: (ComingSoon) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            MonoLabel("Free practice", weight: .regular, tracking: 0.12)
                .foregroundStyle(RiffleColor.textMuted)
                .padding(.top, 6)
            row(.chordLibrary, icon: "square.grid.3x3.fill", title: "Chord library", detail: "Any chord, any time", track: .chords)
            row(.earSession, icon: "ear.fill", title: "Ear session", detail: "Pick a key and a level", track: .ear)
        }
    }

    private func row(_ feature: ComingSoon, icon: String, title: String, detail: String, track: Track) -> some View {
        Button { open(feature) } label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(track.ink)
                    .frame(width: 36, height: 36)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(track.accent))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).riffleFont(.body, size: 16, weight: .bold)
                    Text(detail)
                        .riffleFont(.body, size: 13)
                        .foregroundStyle(RiffleColor.textMuted)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(RiffleColor.textDim)
            }
            .foregroundStyle(RiffleColor.text)
            .padding(14)
            .riffleCard(cornerRadius: 20, fill: RiffleColor.surface, border: RiffleColor.border)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Small animated pieces from the mockup

/// Amp knob that turns back and forth.
private struct Knob: View {
    let track: Track
    let delay: Double

    var body: some View {
        ZStack(alignment: .top) {
            Circle().fill(track.ink)
            Capsule().fill(track.accent).frame(width: 3, height: 10).padding(.top, 4)
        }
        .frame(width: 30, height: 30)
        .pingPong(duration: 2, delay: delay) { view, on in
            view.rotationEffect(.degrees(on ? 40 : -30))
        }
        .accessibilityHidden(true)
    }
}

/// "?" card that flips every few seconds.
private struct FlipCard: View {
    let track: Track
    let delay: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Phase: CaseIterable { case rest, half, full }

    var body: some View {
        let card = Text("?")
            .riffleFont(.display, size: 22, weight: .heavy, maxScale: 1)
            .foregroundStyle(track.accent)
            .frame(width: 40, height: 48)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(track.ink))

        if reduceMotion {
            card
        } else {
            card.phaseAnimator(Phase.allCases) { view, phase in
                view.rotation3DEffect(.degrees(phase == .rest ? 0 : phase == .half ? 180 : 360),
                                      axis: (x: 0, y: 1, z: 0), perspective: 0.6)
            } animation: { phase in
                switch phase {
                case .rest: nil // snap 360° back to 0°, which looks identical
                case .half: .easeInOut(duration: 0.4).delay(2.8 + delay)
                case .full: .easeInOut(duration: 0.4)
                }
            }
        }
    }
}

/// Nine bouncing EQ bars.
private struct EqualizerBars: View {
    let color: Color

    var body: some View {
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(0..<9, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(width: 4, height: 26)
                    .pingPong(duration: 0.5, delay: Double(index) * 0.13) { view, on in
                        view.scaleEffect(x: 1, y: on ? 1 : 0.25, anchor: .bottom)
                    }
            }
        }
        .frame(height: 26)
        .accessibilityHidden(true)
    }
}

/// Six strings, thick to thin; the low one vibrates.
private struct MiniStrings: View {
    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array([3, 2.5, 2, 1.5, 1.2, 1].enumerated()), id: \.offset) { index, width in
                let line = Capsule()
                    .fill(index == 0 ? RiffleColor.lime : RiffleColor.textDim)
                    .frame(width: width, height: 36)
                if index == 0 {
                    line.pingPong(duration: 0.12) { view, on in view.offset(x: on ? 1.5 : -1.5) }
                } else {
                    line
                }
            }
        }
        .accessibilityHidden(true)
    }
}
