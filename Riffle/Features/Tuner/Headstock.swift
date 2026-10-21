import RiffleAudio
import RiffleDesign
import RiffleTheory
import SwiftUI

/// 3 + 3 headstock from the mockup: pegs D A E on the left, G B E on the right, strings in the middle.
struct Headstock: View {
    let tuning: Tuning
    let state: TunerState
    let pick: (Int) -> Void

    private static let stringWidths: [CGFloat] = [3.2, 2.7, 2.2, 1.8, 1.4, 1.1]

    var body: some View {
        HStack(spacing: 18) {
            pegColumn([2, 1, 0])
            headstockBody(strings: Self.stringWidths)
            pegColumn([3, 4, 5])
        }
        .frame(maxWidth: .infinity)
    }

    private func pegColumn(_ indexes: [Int]) -> some View {
        VStack(spacing: 12) {
            ForEach(indexes, id: \.self) { index in
                Peg(label: tuning.strings[index].name.description,
                    isSelected: index == state.selectedString,
                    isTuned: state.tuned.contains(index)) { pick(index) }
                    .accessibilityLabel(accessibilityLabel(for: index))
                    .accessibilityAddTraits(index == state.selectedString ? .isSelected : [])
            }
        }
    }

    private func headstockBody(strings widths: [CGFloat]) -> some View {
        ZStack(alignment: .bottom) {
            UnevenRoundedRectangle(topLeadingRadius: 46, bottomLeadingRadius: 16, bottomTrailingRadius: 16,
                                   topTrailingRadius: 46, style: .continuous)
                .fill(RiffleColor.surfaceSunken)
                .overlay(
                    UnevenRoundedRectangle(topLeadingRadius: 46, bottomLeadingRadius: 16, bottomTrailingRadius: 16,
                                           topTrailingRadius: 46, style: .continuous)
                        .strokeBorder(RiffleColor.borderStrong, lineWidth: 1.5)
                )
            HStack(alignment: .bottom, spacing: 9) {
                ForEach(0..<Tuning.stringCount, id: \.self) { index in
                    StringLine(width: widths[index], color: stringColor(index),
                               vibrating: index == state.selectedString && state.hasSignal)
                }
            }
            .frame(height: 182)
            Capsule()
                .fill(RiffleColor.nut)
                .frame(height: 8)
                .padding(.horizontal, 10)
        }
        .frame(width: 120, height: 204)
        .accessibilityHidden(true)
    }

    private func stringColor(_ index: Int) -> Color {
        guard index == state.selectedString else { return RiffleColor.stringIdle }
        return state.isInTune ? RiffleColor.lime : RiffleColor.orange
    }

    private func accessibilityLabel(for index: Int) -> String {
        let pitch = tuning.strings[index]
        return "String \(Tuning.stringNumber(forIndex: index)), \(pitch.description)" + (state.tuned.contains(index) ? ", tuned" : "")
    }
}

private struct Peg: View {
    let label: String
    let isSelected: Bool
    let isTuned: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .riffleFont(.display, size: 22, weight: .heavy, maxScale: 1)
                .foregroundStyle(isSelected ? RiffleColor.limeInk : RiffleColor.text)
                .frame(width: 56, height: 56)
                .background(Circle().fill(isSelected ? RiffleColor.lime : RiffleColor.surfaceRaised))
                .overlay(Circle().strokeBorder(isSelected ? RiffleColor.lime : RiffleColor.borderStrong, lineWidth: 2))
                .overlay(alignment: .topTrailing) {
                    if isTuned {
                        Circle()
                            .fill(RiffleColor.lime)
                            .overlay(Circle().strokeBorder(RiffleColor.background, lineWidth: 2))
                            .frame(width: 14, height: 14)
                            .offset(x: 2, y: -2)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .animation(RiffleMotion.pop, value: isTuned)
                .animation(.easeOut(duration: 0.2), value: isSelected)
        }
        .buttonStyle(PegButtonStyle())
    }
}

/// Pressing a peg squeezes and twists it, like turning a tuning key.
private struct PegButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .rotationEffect(.degrees(configuration.isPressed ? -25 : 0))
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

private struct StringLine: View {
    let width: CGFloat
    let color: Color
    let vibrating: Bool

    var body: some View {
        let line = RoundedRectangle(cornerRadius: 2).fill(color).frame(width: width, height: 182)
        if vibrating {
            line.pingPong(duration: 0.045) { view, on in view.offset(x: on ? 1.4 : -0.4) }
        } else {
            line
        }
    }
}
