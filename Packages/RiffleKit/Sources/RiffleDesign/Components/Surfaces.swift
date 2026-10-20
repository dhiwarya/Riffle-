import SwiftUI

/// The mockup's background: dark stage with a faint 14 pt dot grid.
public struct DotGridBackground: View {
    public init() {}

    public var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = 14
            let dot = RiffleColor.text.opacity(0.06)
            var y: CGFloat = spacing / 2
            while y < size.height {
                var x: CGFloat = spacing / 2
                while x < size.width {
                    context.fill(Path(ellipseIn: CGRect(x: x - 1, y: y - 1, width: 2, height: 2)), with: .color(dot))
                    x += spacing
                }
                y += spacing
            }
        }
        .background(RiffleColor.background)
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

/// Outlined card on a dark surface (principle 1).
struct RiffleCard: ViewModifier {
    let cornerRadius: CGFloat
    let fill: Color
    let border: Color

    func body(content: Content) -> some View {
        content
            .background(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).fill(fill))
            .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).strokeBorder(border, lineWidth: 1.5))
    }
}

extension View {
    public func riffleCard(
        cornerRadius: CGFloat = 20,
        fill: Color = RiffleColor.surfaceRaised,
        border: Color = RiffleColor.borderStrong
    ) -> some View {
        modifier(RiffleCard(cornerRadius: cornerRadius, fill: fill, border: border))
    }
}

/// Caps label in DM Mono with wide tracking: "CHORD OF THE DAY", "MON · 19 OCT".
public struct MonoLabel: View {
    let text: String
    let size: CGFloat
    let weight: RiffleWeight
    let tracking: CGFloat

    public init(_ text: String, size: CGFloat = 12, weight: RiffleWeight = .medium, tracking: CGFloat = 0.14) {
        self.text = text
        self.size = size
        self.weight = weight
        self.tracking = tracking
    }

    public var body: some View {
        Text(text.uppercased())
            .riffleFont(.mono, size: size, weight: weight, relativeTo: .caption, tracking: tracking)
    }
}

/// Glowing status LED, blinking.
public struct StatusLED: View {
    let color: Color
    let delay: Double

    public init(_ color: Color, delay: Double = 0) {
        self.color = color
        self.delay = delay
    }

    public var body: some View {
        Circle()
            .fill(color)
            .frame(width: 10, height: 10)
            .shadow(color: color, radius: 4)
            .blinking(delay: delay)
            .accessibilityHidden(true)
    }
}
