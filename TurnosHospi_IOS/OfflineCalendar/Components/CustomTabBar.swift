import SwiftUI

// MARK: - Tipos de Tab

enum OfflineCalendarTab: Int, CaseIterable {
    case calendar = 0
    case statistics = 1
    case settings = 2

    var icon: String {
        switch self {
        case .calendar: return "calendar"
        case .statistics: return "chart.bar.fill"
        case .settings: return "gearshape.fill"
        }
    }

    var title: String {
        switch self {
        case .calendar: return "Calendario"
        case .statistics: return "Estadísticas"
        case .settings: return "Ajustes"
        }
    }
}

// MARK: - Tab Bar Personalizado

struct CustomTabBar: View {
    @Binding var selectedTab: OfflineCalendarTab
    @Namespace private var tabAnimation

    var body: some View {
        HStack(spacing: 0) {
            ForEach(OfflineCalendarTab.allCases, id: \.rawValue) { tab in
                TabBarButton(
                    tab: tab,
                    isSelected: selectedTab == tab,
                    namespace: tabAnimation,
                    action: {
                        withAnimation(DesignAnimation.springBouncy) {
                            selectedTab = tab
                        }
                        HapticManager.selection()
                    }
                )
            }
        }
        .padding(.horizontal, DesignSpacing.lg)
        .padding(.top, DesignSpacing.md)
        .padding(.bottom, DesignSpacing.xl)
        .background(
            DesignGradients.tabBarBackground
                .overlay(
                    Rectangle()
                        .fill(DesignColors.glassBorder)
                        .frame(height: 1),
                    alignment: .top
                )
        )
        .background(
            DesignColors.cardBackground
                .shadow(color: DesignShadows.heavy, radius: 20, y: -10)
        )
    }
}

// MARK: - Botón de Tab

struct TabBarButton: View {
    let tab: OfflineCalendarTab
    let isSelected: Bool
    let namespace: Namespace.ID
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: DesignSpacing.xs) {
                ZStack {
                    if isSelected {
                        Circle()
                            .fill(DesignColors.accent.opacity(0.15))
                            .frame(width: 50, height: 50)
                            .matchedGeometryEffect(id: "tabBackground", in: namespace)
                    }

                    Image(systemName: tab.icon)
                        .font(.system(size: isSelected ? DesignSizes.tabBarIconSelected : DesignSizes.tabBarIcon))
                        .foregroundColor(isSelected ? DesignColors.accent : DesignColors.textTertiary)
                        .scaleEffect(isSelected ? 1.1 : 1.0)
                }
                .frame(height: 50)

                Text(tab.title)
                    .font(DesignFonts.tabLabel)
                    .foregroundColor(isSelected ? DesignColors.accent : DesignColors.textTertiary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#if DEBUG
struct CustomTabBar_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            DesignColors.background
                .ignoresSafeArea()

            VStack {
                Spacer()
                CustomTabBar(selectedTab: .constant(.calendar))
            }
        }
    }
}
#endif
