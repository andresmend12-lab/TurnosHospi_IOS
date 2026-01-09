import SwiftUI

// MARK: - Vista de Leyenda

struct LegendView: View {
    let items: [String]
    @ObservedObject var viewModel: OfflineCalendarViewModel

    let columns = Array(repeating: GridItem(.flexible(), spacing: DesignSpacing.xs), count: 3)

    var body: some View {
        LazyVGrid(columns: columns, spacing: DesignSpacing.sm) {
            ForEach(items, id: \.self) { item in
                HStack(spacing: DesignSpacing.xs) {
                    Circle()
                        .fill(colorForShiftName(item))
                        .frame(width: DesignSizes.noteIndicator, height: DesignSizes.noteIndicator)
                        .overlay(Circle().stroke(Color.white.opacity(0.2), lineWidth: 1))

                    Text(item)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, DesignSpacing.xs)
            }
        }
        .padding(.horizontal, DesignSpacing.md)
        .padding(.vertical, DesignSpacing.sm)
    }

    func colorForShiftName(_ name: String) -> Color {
        return getShiftColorForType(name, customShiftTypes: viewModel.customShiftTypes)
    }
}
