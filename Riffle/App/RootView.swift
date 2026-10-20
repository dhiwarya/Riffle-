import RiffleDesign
import SwiftUI

enum AppTab: Hashable {
    case practice, tuner
}

/// Two tabs, as in the mockup. Both stay alive so switching keeps their state.
struct RootView: View {
    @State private var tab: AppTab = .practice

    var body: some View {
        ZStack {
            screen(.practice) { PracticeView(openTuner: { tab = .tuner }) }
            screen(.tuner) { TunerView() }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            RiffleTabBar(selection: $tab)
        }
    }

    private func screen(_ which: AppTab, @ViewBuilder content: () -> some View) -> some View {
        content()
            .opacity(tab == which ? 1 : 0)
            .allowsHitTesting(tab == which)
            .accessibilityHidden(tab != which)
    }
}

struct RiffleTabBar: View {
    @Binding var selection: AppTab

    var body: some View {
        HStack(spacing: 8) {
            item(.practice, title: "Practice", icon: "music.note")
            item(.tuner, title: "Tuner", icon: "gauge.with.needle")
        }
        .padding(.horizontal, 40)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background {
            RiffleColor.navBar
                .overlay(alignment: .top) { Rectangle().fill(RiffleColor.border).frame(height: 1) }
                .ignoresSafeArea(edges: .bottom)
        }
    }

    private func item(_ tab: AppTab, title: String, icon: String) -> some View {
        let selected = selection == tab
        return Button {
            selection = tab
        } label: {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 21, weight: .semibold))
                    .frame(height: 24)
                Text(title)
                    .riffleFont(.body, size: 12, weight: selected ? .bold : .semibold, relativeTo: .caption, maxScale: 1.2)
            }
            .foregroundStyle(selected ? RiffleColor.lime : RiffleColor.textMuted)
            .frame(maxWidth: .infinity, minHeight: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

#Preview {
    RootView()
        .modelContainer(PreviewData.container)
        .preferredColorScheme(.dark)
}
