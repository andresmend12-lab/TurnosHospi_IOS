import SwiftUI

// MARK: - Vista Principal del Calendario Offline

struct OfflineCalendarView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var viewModel = OfflineCalendarViewModel()
    @Binding var showSettings: Bool
    @State private var showConfigDialog = false

    init(showSettings: Binding<Bool> = .constant(false)) {
        _showSettings = showSettings
    }

    var body: some View {
        NavigationView {
            ZStack {
                DesignColors.background.edgesIgnoringSafeArea(.all)

                VStack(spacing: 0) {
                    tabPicker

                    if viewModel.selectedTab == 0 {
                        calendarTabView
                    } else {
                        StatisticsTabView(viewModel: viewModel)
                    }
                }
            }
            .navigationBarTitle("Mi Planilla", displayMode: .inline)
            .navigationBarBackButtonHidden(true)
            .onAppear {
                viewModel.loadData()
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showConfigDialog) {
            OfflineCalendarSettingsView(viewModel: viewModel)
        }
    }

    // MARK: - Tab Picker

    private var tabPicker: some View {
        Picker("Vista", selection: $viewModel.selectedTab) {
            Text("Calendario").tag(0)
            Text("Estadísticas").tag(1)
        }
        .pickerStyle(.segmented)
        .padding()
        .background(DesignColors.background)
    }

    // MARK: - Calendar Tab

    private var calendarTabView: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                ZStack(alignment: .topTrailing) {
                    VStack(spacing: 0) {
                        CalendarGridView(viewModel: viewModel)
                            .padding(.horizontal)

                        if !viewModel.isAssignmentMode {
                            LegendView(items: viewModel.legendItems, viewModel: viewModel)
                                .padding(.vertical, DesignSpacing.sm)
                        }
                    }

                    if !viewModel.isAssignmentMode {
                        settingsButton
                    }
                }

                Spacer(minLength: 0)

                controlPanel
            }

            if !viewModel.isAssignmentMode {
                floatingActionButton
            }
        }
    }

    // MARK: - Subviews

    private var settingsButton: some View {
        Button(action: { showConfigDialog = true }) {
            Image(systemName: "gearshape")
                .foregroundColor(.black)
                .padding(DesignSpacing.sm)
                .background(Color.white)
                .clipShape(Circle())
                .shadow(color: DesignShadows.medium, radius: 4, x: 0, y: 2)
        }
        .padding(.trailing, DesignSpacing.xxl)
        .padding(.top, DesignSpacing.xs)
    }

    private var controlPanel: some View {
        Group {
            if viewModel.isAssignmentMode {
                AssignmentControlPanel(viewModel: viewModel)
            } else {
                NotesControlPanel(viewModel: viewModel)
            }
        }
        .background(DesignColors.cardBackground)
        .cornerRadius(DesignCornerRadius.large, corners: [.topLeft, .topRight])
        .shadow(color: DesignShadows.heavy, radius: 8, x: 0, y: -4)
    }

    private var floatingActionButton: some View {
        Button(action: {
            viewModel.isAssignmentMode = true
        }) {
            Image(systemName: "pencil")
                .font(.title2)
                .foregroundColor(.black)
                .padding(DesignSpacing.lg)
                .background(DesignColors.accent)
                .clipShape(Circle())
                .shadow(radius: 4)
        }
        .padding(.trailing, DesignSpacing.xl)
        .padding(.bottom, 220)
    }
}

// MARK: - Preview

#Preview {
    OfflineCalendarView()
        .environmentObject(ThemeManager.shared)
}
