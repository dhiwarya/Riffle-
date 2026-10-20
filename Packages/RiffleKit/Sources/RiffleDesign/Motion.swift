import SwiftUI

/// Motion vocabulary from the mockup. Every loop and entrance turns off under Reduce Motion (principle 6).
public enum RiffleMotion {
    /// `rise`: cubic-bezier(.2,.9,.25,1.2) over 0.6 s, a little overshoot.
    public static let rise = Animation.timingCurve(0.2, 0.9, 0.25, 1.2, duration: 0.6)
    /// `pop`: success bounce.
    public static let pop = Animation.timingCurve(0.2, 0.9, 0.3, 1.4, duration: 0.45)
    /// Tuner needle spring: cubic-bezier(.3,1.6,.45,1).
    public static let needle = Animation.timingCurve(0.3, 1.6, 0.45, 1, duration: 0.6)
    /// Pedal press.
    public static let press = Animation.easeOut(duration: 0.12)
}

/// Staggered entrance: fade in, slide up 24 pt and scale from 0.97.
struct RiseIn: ViewModifier {
    let delay: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    func body(content: Content) -> some View {
        let visible = shown || reduceMotion
        content
            .opacity(visible ? 1 : 0)
            .offset(y: visible ? 0 : 24)
            .scaleEffect(visible ? 1 : 0.97)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(RiffleMotion.rise.delay(delay)) { shown = true }
            }
    }
}

/// Runs `transform(content, phase)` back and forth forever, animating `phase` between false and true.
struct PingPong<Effect: View>: ViewModifier {
    let duration: Double
    let delay: Double
    let transform: (AnyView, Bool) -> Effect
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase = false

    func body(content: Content) -> some View {
        transform(AnyView(content), reduceMotion ? false : phase)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true).delay(delay)) {
                    phase = true
                }
            }
    }
}

/// An expanding ring that fades out, like the mockup's `ringpulse` / `halo`.
struct PulseRing: ViewModifier {
    let color: Color
    let spread: CGFloat
    let duration: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var expanded = false

    func body(content: Content) -> some View {
        content.background {
            if !reduceMotion {
                Circle()
                    .stroke(color, lineWidth: spread)
                    .scaleEffect(expanded ? 1 + spread * 2 / 16 : 1)
                    .opacity(expanded ? 0 : 0.55)
                    .onAppear {
                        withAnimation(.easeOut(duration: duration).repeatForever(autoreverses: false)) { expanded = true }
                    }
            }
        }
    }
}

extension View {
    public func riseIn(delay: Double = 0) -> some View {
        modifier(RiseIn(delay: delay))
    }

    /// Back-and-forth loop; `transform` receives the animated phase.
    public func pingPong<Effect: View>(
        duration: Double,
        delay: Double = 0,
        @ViewBuilder _ transform: @escaping (AnyView, Bool) -> Effect
    ) -> some View {
        modifier(PingPong(duration: duration, delay: delay, transform: transform))
    }

    /// Status LED blink: opacity 1 ↔ 0.35.
    public func blinking(period: Double = 1.4, delay: Double = 0) -> some View {
        pingPong(duration: period / 2, delay: delay) { view, on in view.opacity(on ? 0.35 : 1) }
    }

    public func pulseRing(_ color: Color, spread: CGFloat = 5, duration: Double = 1.6) -> some View {
        modifier(PulseRing(color: color, spread: spread, duration: duration))
    }
}
