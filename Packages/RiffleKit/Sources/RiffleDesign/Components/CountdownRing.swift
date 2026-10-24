import SwiftUI

/// The chord quiz's 44 pt countdown: an orange arc that empties clockwise around the seconds left.
public struct CountdownRing: View {
    let remaining: Double
    let total: Double
    let track: Track

    public init(remaining: Double, total: Double, track: Track = .chords) {
        self.remaining = remaining
        self.total = total
        self.track = track
    }

    public var body: some View {
        let fraction = total > 0 ? max(0, min(1, remaining / total)) : 0
        let urgent = remaining <= 5
        ZStack {
            Circle().stroke(RiffleColor.borderStrong, lineWidth: 4)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(urgent ? RiffleColor.orange : track.accent, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.25), value: fraction)
            Text("\(Int(remaining.rounded(.up)))")
                .riffleFont(.mono, size: 13, maxScale: 1)
                .foregroundStyle(RiffleColor.text)
                .contentTransition(.numericText(countsDown: true))
        }
        .frame(width: 36, height: 36)
        .padding(4)
        .accessibilityElement()
        .accessibilityLabel("\(Int(remaining.rounded(.up))) seconds left")
    }
}
