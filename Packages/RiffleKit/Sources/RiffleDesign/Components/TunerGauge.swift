import SwiftUI

/// The tuner's ±50 ¢ arc: 21 ticks every 5 ¢ (longer every 25 ¢), a springy needle at 1.6° per cent,
/// and the cents readout. Sized like the mockup (340 × 178).
public struct TunerGauge: View {
    /// Offset in cents, nil when nothing is ringing.
    let cents: Double?
    let isInTune: Bool

    public init(cents: Double?, isInTune: Bool) {
        self.cents = cents
        self.isInTune = isInTune
    }

    private static let size = CGSize(width: 340, height: 178)
    private static let pivot = CGPoint(x: 170, y: 166)
    private static let degreesPerCent = 1.6

    public var body: some View {
        let clamped = min(max(cents ?? 0, -50), 50)
        ZStack(alignment: .topLeading) {
            Canvas { context, _ in
                for c in stride(from: -50, through: 50, by: 5) {
                    let major = c % 25 == 0
                    let length: CGFloat = major ? 22 : 12
                    let angle = Angle.degrees(Double(c) * Self.degreesPerCent).radians
                    let outer: CGFloat = 154
                    var path = Path()
                    path.move(to: point(radius: outer - length, angle: angle))
                    path.addLine(to: point(radius: outer, angle: angle))
                    let color = abs(c) <= 5 ? RiffleColor.lime : major ? RiffleColor.textMuted : Color(hex: 0x5A5044)
                    context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                }
            }
            .frame(width: Self.size.width, height: Self.size.height)

            Text(centsLabel)
                .riffleFont(.mono, size: 15, maxScale: 1.1)
                .foregroundStyle(needleColor)
                .monospacedDigit()
                .contentTransition(.numericText())
                .frame(width: Self.size.width)
                .offset(y: 64)

            Capsule()
                .fill(needleColor)
                .frame(width: 4, height: 138)
                .rotationEffect(.degrees(clamped * Self.degreesPerCent), anchor: .bottom)
                .position(x: Self.pivot.x, y: Self.pivot.y - 69)
                .animation(.spring(response: 0.32, dampingFraction: 0.58), value: clamped)

            Circle()
                .fill(RiffleColor.text)
                .overlay(Circle().strokeBorder(RiffleColor.background, lineWidth: 5))
                .frame(width: 24, height: 24)
                .position(Self.pivot)

            HStack {
                Text("−50¢ flat")
                Spacer()
                Text("sharp +50¢")
            }
            .riffleFont(.mono, size: 12, maxScale: 1.1)
            .foregroundStyle(RiffleColor.textMuted)
            .padding(.horizontal, 6)
            .frame(width: Self.size.width, height: Self.size.height, alignment: .bottom)
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .animation(.easeOut(duration: 0.2), value: needleColor)
        .accessibilityHidden(true)
    }

    private func point(radius: CGFloat, angle: Double) -> CGPoint {
        CGPoint(x: Self.pivot.x + radius * sin(angle), y: Self.pivot.y - radius * cos(angle))
    }

    private var needleColor: Color {
        guard cents != nil else { return RiffleColor.textDim }
        return isInTune ? RiffleColor.lime : RiffleColor.orange
    }

    private var centsLabel: String {
        guard let cents else { return "—" }
        let rounded = Int(cents.rounded())
        if rounded == 0 { return "0¢" }
        return (rounded > 0 ? "+" : "−") + "\(abs(rounded))¢"
    }
}

#Preview {
    VStack(spacing: 30) {
        TunerGauge(cents: -34, isInTune: false)
        TunerGauge(cents: 1, isInTune: true)
        TunerGauge(cents: nil, isInTune: false)
    }
    .padding()
    .background(RiffleColor.background)
}
