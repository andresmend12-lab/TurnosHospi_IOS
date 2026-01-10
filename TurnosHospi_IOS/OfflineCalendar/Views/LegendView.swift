import SwiftUI

// MARK: - Vista de Leyenda Expandible

struct LegendView: View {
    let items: [String]
    @ObservedObject var viewModel: OfflineCalendarViewModel
    @EnvironmentObject var themeManager: ThemeManager
    @State private var isExpanded: Bool = false

    let columns = Array(repeating: GridItem(.flexible(), spacing: DesignSpacing.xs), count: 3)

    var body: some View {
        VStack(spacing: 0) {
            // Header con toggle
            legendHeader

            // Contenido expandible
            if isExpanded {
                expandedContent
                    .transition(.opacity.combined(with: .move(edge: .top)))
            } else {
                collapsedContent
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, DesignSpacing.md)
        .padding(.vertical, DesignSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: DesignCornerRadius.medium)
                .fill(DesignColors.cardBackground.opacity(0.5))
        )
        .animation(DesignAnimation.springGentle, value: isExpanded)
    }

    // MARK: - Subviews

    private var legendHeader: some View {
        Button(action: {
            withAnimation(DesignAnimation.springGentle) {
                isExpanded.toggle()
            }
            HapticManager.selection()
        }) {
            HStack {
                Text("Leyenda")
                    .font(DesignFonts.captionMedium)
                    .foregroundColor(DesignColors.textSecondary)

                Spacer()

                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(DesignColors.accent)
                    .rotationEffect(.degrees(isExpanded ? 0 : 0))
            }
            .padding(.bottom, DesignSpacing.sm)
        }
        .buttonStyle(.plain)
    }

    private var collapsedContent: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignSpacing.md) {
                ForEach(items, id: \.self) { item in
                    legendItem(item)
                }
            }
        }
    }

    private var expandedContent: some View {
        LazyVGrid(columns: columns, spacing: DesignSpacing.sm) {
            ForEach(items, id: \.self) { item in
                legendItem(item)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func legendItem(_ item: String) -> some View {
        HStack(spacing: DesignSpacing.xs) {
            Circle()
                .fill(colorForShiftName(item))
                .frame(width: DesignSizes.noteIndicator, height: DesignSizes.noteIndicator)
                .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))
                .shadow(color: colorForShiftName(item).opacity(0.4), radius: 2)

            Text(item)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(DesignColors.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, DesignSpacing.sm)
        .padding(.vertical, DesignSpacing.xs)
        .background(
            Capsule()
                .fill(DesignColors.glassBackground)
        )
    }

    // MARK: - Helpers

    func colorForShiftName(_ name: String) -> Color {
        return getShiftColorForType(
            name,
            customShiftTypes: viewModel.customShiftTypes,
            themeManager: themeManager
        )
    }
}
