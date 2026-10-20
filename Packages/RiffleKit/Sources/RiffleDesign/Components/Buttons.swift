import SwiftUI

/// Primary action as a guitar pedal: hard 6 pt shadow that collapses when pressed (principle 3).
public struct PedalButtonStyle: ButtonStyle {
    let track: Track
    let cornerRadius: CGFloat

    public init(_ track: Track, cornerRadius: CGFloat = 28) {
        self.track = track
        self.cornerRadius = cornerRadius
    }

    public func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        configuration.label
            .foregroundStyle(track.ink)
            .background(shape.fill(track.accent))
            .offset(y: pressed ? 5 : 0)
            .background(shape.fill(pressed ? Color.black : track.shadow).offset(y: 6))
            .animation(RiffleMotion.press, value: pressed)
            .contentShape(shape)
    }
}

/// Full-width pedal with a centred label, for the one main action on a screen.
public struct PedalButton: View {
    let title: String
    let track: Track
    let action: () -> Void

    public init(_ title: String, track: Track, action: @escaping () -> Void) {
        self.title = title
        self.track = track
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(title)
                .riffleFont(.body, size: 17, weight: .bold)
                .frame(maxWidth: .infinity, minHeight: 56)
        }
        .buttonStyle(PedalButtonStyle(track, cornerRadius: 22))
    }
}

/// Outline chip; filled with the track colour when selected.
public struct ChipButtonStyle: ButtonStyle {
    let isSelected: Bool
    let track: Track

    public init(isSelected: Bool = false, track: Track = .chords) {
        self.isSelected = isSelected
        self.track = track
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .riffleFont(.body, size: 14, weight: .bold)
            .foregroundStyle(isSelected ? track.ink : RiffleColor.textSoft)
            .padding(.horizontal, 16)
            .frame(minHeight: 40)
            .background(Capsule().fill(isSelected ? track.accent : RiffleColor.surface))
            .overlay(Capsule().strokeBorder(isSelected ? track.accent : RiffleColor.borderStrong, lineWidth: 1.5))
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(RiffleMotion.press, value: configuration.isPressed)
    }
}

/// Segmented control in a pill (Auto/Manual, Easy/Medium/Hard, Fingers/Notes).
public struct SegmentedPill<Value: Hashable>: View {
    let options: [(value: Value, label: String)]
    @Binding var selection: Value
    let selectedFill: Color
    let selectedText: Color
    let accessibilityLabel: String

    public init(
        _ accessibilityLabel: String,
        options: [(value: Value, label: String)],
        selection: Binding<Value>,
        selectedFill: Color = RiffleColor.text,
        selectedText: Color = RiffleColor.background
    ) {
        self.accessibilityLabel = accessibilityLabel
        self.options = options
        _selection = selection
        self.selectedFill = selectedFill
        self.selectedText = selectedText
    }

    public var body: some View {
        HStack(spacing: 4) {
            ForEach(options, id: \.value) { option in
                let selected = option.value == selection
                Button {
                    selection = option.value
                } label: {
                    Text(option.label)
                        .riffleFont(.body, size: 14, weight: .bold)
                        .foregroundStyle(selected ? selectedText : RiffleColor.textMuted)
                        .padding(.horizontal, 14)
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .background(Capsule().fill(selected ? selectedFill : .clear))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(4)
        .riffleCard(cornerRadius: 22, fill: RiffleColor.surface)
        .animation(.easeOut(duration: 0.2), value: selection)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityLabel)
    }
}
