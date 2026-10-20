import SwiftUI

/// Question progress: done segments lime, current in the track colour, the rest dim.
public struct ProgressDots: View {
    let total: Int
    /// 1-based index of the current question.
    let current: Int
    let track: Track

    public init(total: Int, current: Int, track: Track) {
        self.total = total
        self.current = current
        self.track = track
    }

    public var body: some View {
        HStack(spacing: 4) {
            ForEach(1...max(total, 1), id: \.self) { index in
                Capsule()
                    .fill(index < current ? RiffleColor.lime : index == current ? track.accent : RiffleColor.borderStrong)
                    .frame(height: 6)
            }
        }
        .animation(.easeOut(duration: 0.25), value: current)
        .accessibilityElement()
        .accessibilityLabel("Question \(current) of \(total)")
    }
}

/// One day in the 7-day streak row.
public struct DayDot: Hashable, Sendable {
    public enum State: Hashable, Sendable { case done, today, missed, upcoming }

    public let label: String
    public let state: State

    public init(label: String, state: State) {
        self.label = label
        self.state = state
    }
}

/// The 7-day row on Today: lime glowing dot for practised days, pulsing orange ring for today.
public struct WeekDots: View {
    let days: [DayDot]

    public init(days: [DayDot]) {
        self.days = days
    }

    public var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                VStack(spacing: 8) {
                    Text(day.label)
                        .riffleFont(.mono, size: 11, relativeTo: .caption2)
                        .foregroundStyle(RiffleColor.textMuted)
                    dot(for: day.state)
                        .frame(width: 16, height: 16)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 10)
        .riffleCard(cornerRadius: 18, fill: RiffleColor.surface, border: RiffleColor.border)
        .accessibilityElement()
        .accessibilityLabel(accessibilitySummary)
    }

    @ViewBuilder
    private func dot(for state: DayDot.State) -> some View {
        switch state {
        case .done:
            Circle().fill(RiffleColor.lime).shadow(color: RiffleColor.lime.opacity(0.6), radius: 5)
        case .today:
            Circle().strokeBorder(RiffleColor.orange, lineWidth: 3).pulseRing(RiffleColor.orange)
        case .missed:
            Circle().strokeBorder(RiffleColor.borderStrong, lineWidth: 1.5)
        case .upcoming:
            Circle().fill(RiffleColor.border)
        }
    }

    private var accessibilitySummary: String {
        let done = days.filter { $0.state == .done }.count
        return "Last 7 days: practised on \(done) of \(days.count)"
    }
}

/// Streak count pill with a flickering flame.
public struct StreakPill: View {
    let count: Int
    let action: () -> Void

    public init(count: Int, action: @escaping () -> Void) {
        self.count = count
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(RiffleColor.orange)
                    .pingPong(duration: 0.6) { view, on in
                        view.scaleEffect(on ? 1.12 : 1, anchor: .bottom).rotationEffect(.degrees(on ? 4 : -4), anchor: .bottom)
                    }
                Text("\(count)")
                    .riffleFont(.display, size: 18, weight: .bold)
            }
            .foregroundStyle(RiffleColor.text)
            .padding(.horizontal, 14)
            .frame(height: 44)
            .riffleCard(cornerRadius: 22)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(count)-day streak")
    }
}
