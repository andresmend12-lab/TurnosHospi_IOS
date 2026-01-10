import SwiftUI

// MARK: - Vista Principal del Calendario Offline

struct OfflineCalendarView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var viewModel = OfflineCalendarViewModel()
    @Binding var showSettings: Bool
    @State private var showConfigDialog = false
    @State private var selectedTab: OfflineCalendarTab = .calendar

    init(showSettings: Binding<Bool> = .constant(false)) {
        _showSettings = showSettings
    }

    var body: some View {
        NavigationView {
            ZStack {
                // Fondo con gradiente
                DesignGradients.backgroundMain
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header
                    headerView

                    // Contenido principal según tab
                    tabContent

                    // Tab bar personalizado
                    if !viewModel.isAssignmentMode {
                        CustomTabBar(selectedTab: $selectedTab)
                    }
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                viewModel.loadData()
            }
        }
        .navigationViewStyle(.stack)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showConfigDialog) {
            OfflineCalendarSettingsView(viewModel: viewModel)
        }
    }

    // MARK: - Header View

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: DesignSpacing.xxs) {
                Text("Mi Planilla")
                    .font(DesignFonts.titleLarge)
                    .foregroundColor(.white)

                Text(currentDateString())
                    .font(DesignFonts.caption)
                    .foregroundColor(DesignColors.textSecondary)
            }

            Spacer()

            if !viewModel.isAssignmentMode {
                settingsButton
            }
        }
        .padding(.horizontal, DesignSpacing.lg)
        .padding(.top, DesignSpacing.md)
        .padding(.bottom, DesignSpacing.sm)
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .calendar:
            calendarTabView
        case .statistics:
            StatisticsTabView(viewModel: viewModel)
        case .settings:
            settingsTabView
        }
    }

    // MARK: - Calendar Tab

    private var calendarTabView: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: DesignSpacing.md) {
                        // Grid del calendario
                        CalendarGridView(viewModel: viewModel)
                            .padding(.horizontal, DesignSpacing.md)

                        // Leyenda expandible
                        if !viewModel.isAssignmentMode {
                            LegendView(items: viewModel.legendItems, viewModel: viewModel)
                                .padding(.horizontal, DesignSpacing.md)
                        }
                    }
                    .padding(.bottom, viewModel.isAssignmentMode ? 200 : 280)
                }

                // Panel de control
                controlPanel
            }

            // FAB para modo asignación
            if !viewModel.isAssignmentMode {
                floatingActionButton
            }
        }
    }

    // MARK: - Settings Tab View

    private var settingsTabView: some View {
        ScrollView {
            VStack(spacing: DesignSpacing.lg) {
                // Card de configuración rápida
                quickSettingsCard

                // Botón para configuración completa
                fullSettingsButton
            }
            .padding(DesignSpacing.lg)
        }
        .background(DesignGradients.backgroundMain.ignoresSafeArea())
    }

    private var quickSettingsCard: some View {
        VStack(alignment: .leading, spacing: DesignSpacing.lg) {
            Label("Configuración Rápida", systemImage: "slider.horizontal.3")
                .font(DesignFonts.headline)
                .foregroundColor(DesignColors.accent)

            // Patrón actual
            HStack {
                Text("Patrón de turnos")
                    .font(DesignFonts.body)
                    .foregroundColor(.white)
                Spacer()
                Text(viewModel.shiftPattern.title)
                    .font(DesignFonts.bodyMedium)
                    .foregroundColor(DesignColors.accent)
            }

            Divider()
                .background(DesignColors.border)

            // Media jornada
            Toggle(isOn: $viewModel.allowHalfDay) {
                Text("Medias jornadas")
                    .font(DesignFonts.body)
                    .foregroundColor(.white)
            }
            .tint(DesignColors.accent)
        }
        .padding(DesignSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: DesignCornerRadius.large)
                .fill(DesignGradients.cardElevated)
        )
    }

    private var fullSettingsButton: some View {
        Button(action: { showConfigDialog = true }) {
            HStack {
                Image(systemName: "gearshape.fill")
                Text("Configuración Completa")
                Spacer()
                Image(systemName: "chevron.right")
            }
            .font(DesignFonts.bodyMedium)
            .foregroundColor(.white)
            .padding(DesignSpacing.lg)
            .background(
                RoundedRectangle(cornerRadius: DesignCornerRadius.medium)
                    .fill(DesignColors.cardBackground)
            )
        }
    }

    // MARK: - Subviews

    private var settingsButton: some View {
        Button(action: { showConfigDialog = true }) {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 18))
                .foregroundColor(DesignColors.accent)
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(DesignColors.glassBackground)
                        .overlay(
                            Circle()
                                .stroke(DesignColors.glassBorder, lineWidth: 1)
                        )
                )
        }
    }

    private var controlPanel: some View {
        Group {
            if viewModel.isAssignmentMode {
                AssignmentControlPanel(viewModel: viewModel)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                NotesControlPanel(viewModel: viewModel)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(DesignAnimation.springGentle, value: viewModel.isAssignmentMode)
    }

    private var floatingActionButton: some View {
        Button(action: {
            withAnimation(DesignAnimation.springBouncy) {
                viewModel.isAssignmentMode = true
            }
            HapticManager.impact()
        }) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [DesignColors.accent, DesignColors.accentSecondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: DesignSizes.fabButton, height: DesignSizes.fabButton)
                    .shadow(color: DesignColors.accent.opacity(0.4), radius: 12, y: 6)

                Image(systemName: "pencil")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
        .padding(.trailing, DesignSpacing.xl)
        .padding(.bottom, 240)
    }

    // MARK: - Helpers

    private func currentDateString() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateFormat = "EEEE, d 'de' MMMM"
        return formatter.string(from: Date()).capitalized
    }
}

// MARK: - Preview

#Preview {
    OfflineCalendarView()
        .environmentObject(ThemeManager.shared)
}
