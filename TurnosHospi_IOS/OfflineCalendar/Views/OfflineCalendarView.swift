import SwiftUI

// MARK: - Vista Principal del Calendario Offline

struct OfflineCalendarView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var viewModel = OfflineCalendarViewModel()
    @Binding var showSettings: Bool
    @State private var showConfigDialog = false
    @State private var selectedTab: OfflineCalendarTab = .calendar

    // Nuevos sheets
    @State private var showExportSheet = false
    @State private var showDatePicker = false
    @State private var showTemplates = false

    // Bottom sheet state
    @State private var sheetOffset: CGFloat = 0
    @State private var lastSheetOffset: CGFloat = 0
    @State private var sheetExpanded: Bool = false

    // Constantes para el bottom sheet
    private let sheetMinHeight: CGFloat = 140
    private let sheetMaxHeight: CGFloat = UIScreen.main.bounds.height * 0.55

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
                .environmentObject(themeManager)
        }
        .sheet(isPresented: $showExportSheet) {
            ExportSheet(viewModel: viewModel)
                .environmentObject(themeManager)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showDatePicker) {
            DatePickerSheet(viewModel: viewModel)
                .environmentObject(themeManager)
                .presentationDetents([.large])
        }
        .sheet(isPresented: $showTemplates) {
            TemplateSheet(viewModel: viewModel)
                .environmentObject(themeManager)
                .presentationDetents([.large])
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
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                // Capa 1: Calendario FIJO (siempre visible)
                VStack(spacing: 0) {
                    // Grid del calendario
                    CalendarGridView(viewModel: viewModel)
                        .padding(.horizontal, DesignSpacing.md)

                    // Leyenda
                    if !viewModel.isAssignmentMode {
                        LegendView(items: viewModel.legendItems, viewModel: viewModel)
                            .padding(.horizontal, DesignSpacing.md)
                            .padding(.top, DesignSpacing.sm)
                    }

                    Spacer()
                }

                // Capa 2: Bottom Sheet deslizable
                if viewModel.isAssignmentMode {
                    // Modo asignación: panel fijo sin arrastrar
                    AssignmentControlPanel(viewModel: viewModel)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    // Modo normal: bottom sheet deslizable
                    draggableBottomSheet(geometry: geometry)
                }
            }
        }
    }

    // MARK: - Draggable Bottom Sheet

    private func draggableBottomSheet(geometry: GeometryProxy) -> some View {
        let currentHeight = sheetMinHeight + sheetOffset

        return VStack(spacing: 0) {
            // Handle para arrastrar
            sheetHandle

            // Contenido del panel
            bottomSheetContent
        }
        .frame(height: max(sheetMinHeight, min(currentHeight, sheetMaxHeight)))
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: DesignCornerRadius.extraLarge)
                .fill(DesignColors.cardBackground)
                .shadow(color: Color.black.opacity(0.3), radius: 20, y: -5)
        )
        .overlay(
            // FAB superpuesto
            floatingActionButton
                .offset(x: -16, y: -28),
            alignment: .topTrailing
        )
        .gesture(
            DragGesture()
                .onChanged { value in
                    let newOffset = lastSheetOffset - value.translation.height
                    sheetOffset = max(0, min(newOffset, sheetMaxHeight - sheetMinHeight))
                }
                .onEnded { value in
                    let velocity = value.predictedEndLocation.y - value.location.y
                    let threshold = (sheetMaxHeight - sheetMinHeight) / 2

                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        if velocity > 100 {
                            // Arrastrar hacia abajo rápido: colapsar
                            sheetOffset = 0
                            sheetExpanded = false
                        } else if velocity < -100 {
                            // Arrastrar hacia arriba rápido: expandir
                            sheetOffset = sheetMaxHeight - sheetMinHeight
                            sheetExpanded = true
                        } else if sheetOffset > threshold {
                            // Más de la mitad: expandir
                            sheetOffset = sheetMaxHeight - sheetMinHeight
                            sheetExpanded = true
                        } else {
                            // Menos de la mitad: colapsar
                            sheetOffset = 0
                            sheetExpanded = false
                        }
                        lastSheetOffset = sheetOffset
                    }
                    HapticManager.selection()
                }
        )
    }

    private var sheetHandle: some View {
        VStack(spacing: DesignSpacing.xs) {
            // Barra indicadora
            RoundedRectangle(cornerRadius: 3)
                .fill(DesignColors.textTertiary.opacity(0.5))
                .frame(width: 40, height: 5)
                .padding(.top, DesignSpacing.sm)

            // Indicador de expansión
            HStack {
                Image(systemName: sheetExpanded ? "chevron.down" : "chevron.up")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(DesignColors.textTertiary)

                Text(sheetExpanded ? "Desliza para cerrar" : "Desliza para ver más")
                    .font(DesignFonts.caption)
                    .foregroundColor(DesignColors.textTertiary)

                Image(systemName: sheetExpanded ? "chevron.down" : "chevron.up")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(DesignColors.textTertiary)
            }
            .padding(.bottom, DesignSpacing.xs)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }

    private var bottomSheetContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSpacing.md) {
                // Header del día seleccionado
                dayInfoHeader

                Divider()
                    .background(DesignColors.border)

                // Sección de notas
                notesSection
            }
            .padding(.horizontal, DesignSpacing.lg)
            .padding(.bottom, DesignSpacing.lg)
        }
    }

    private var dayInfoHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: DesignSpacing.xs) {
                Text(formattedSelectedDate)
                    .font(DesignFonts.headline)
                    .foregroundColor(.white)

                // Turno del día
                let key = viewModel.dateKey(for: viewModel.selectedDate)
                let shiftName = viewModel.localShifts[key]?.shiftName ?? "Libre"
                let shiftColor = getShiftColorForType(
                    shiftName,
                    customShiftTypes: viewModel.customShiftTypes,
                    themeManager: themeManager
                )

                HStack(spacing: DesignSpacing.xs) {
                    Circle()
                        .fill(shiftColor)
                        .frame(width: 10, height: 10)
                    Text(shiftName)
                        .font(DesignFonts.caption)
                        .foregroundColor(DesignColors.textSecondary)
                }
            }

            Spacer()

            // Badge de notas
            let notesCount = viewModel.localNotes[viewModel.dateKey(for: viewModel.selectedDate)]?.count ?? 0
            if notesCount > 0 {
                Text("\(notesCount)")
                    .font(DesignFonts.captionBold)
                    .foregroundColor(.white)
                    .frame(width: 24, height: 24)
                    .background(DesignColors.accent)
                    .clipShape(Circle())
            }
        }
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: DesignSpacing.sm) {
            // Header de notas
            HStack {
                Label("Anotaciones", systemImage: "note.text")
                    .font(DesignFonts.bodyMedium)
                    .foregroundColor(DesignColors.accent)

                Spacer()

                if !viewModel.isAddingNote && viewModel.editingNoteIndex == nil {
                    Button(action: {
                        withAnimation(DesignAnimation.springBouncy) {
                            viewModel.isAddingNote = true
                            viewModel.newNoteText = ""
                            // Expandir el sheet al añadir nota
                            if !sheetExpanded {
                                sheetOffset = sheetMaxHeight - sheetMinHeight
                                lastSheetOffset = sheetOffset
                                sheetExpanded = true
                            }
                        }
                        HapticManager.selection()
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(DesignColors.accent)
                    }
                }
            }

            // Lista de notas o estado vacío
            notesListView

            // Campo para nueva nota
            if viewModel.isAddingNote {
                addNoteField
            }
        }
    }

    private var notesListView: some View {
        let key = viewModel.dateKey(for: viewModel.selectedDate)
        let notes = viewModel.localNotes[key] ?? []

        return Group {
            if notes.isEmpty && !viewModel.isAddingNote {
                HStack {
                    Image(systemName: "text.bubble")
                        .foregroundColor(DesignColors.textTertiary)
                    Text("No hay notas. Pulsa + para crear una.")
                        .font(DesignFonts.caption)
                        .foregroundColor(DesignColors.textTertiary)
                }
                .padding(.vertical, DesignSpacing.md)
            } else {
                ForEach(Array(notes.enumerated()), id: \.offset) { index, note in
                    if viewModel.editingNoteIndex == index {
                        editNoteField(index: index)
                    } else {
                        noteRow(note: note, index: index)
                    }
                }
            }
        }
    }

    private func noteRow(note: String, index: Int) -> some View {
        HStack(spacing: DesignSpacing.sm) {
            Text(note)
                .font(DesignFonts.body)
                .foregroundColor(.white)
                .padding(DesignSpacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: DesignCornerRadius.small)
                        .fill(DesignColors.glassBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignCornerRadius.small)
                                .stroke(DesignColors.glassBorder, lineWidth: 1)
                        )
                )

            VStack(spacing: DesignSpacing.xs) {
                Button(action: {
                    viewModel.editingNoteIndex = index
                    viewModel.editingNoteText = note
                    viewModel.isAddingNote = false
                    HapticManager.selection()
                }) {
                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(DesignColors.accent)
                }

                Button(action: {
                    withAnimation(DesignAnimation.springBouncy) {
                        viewModel.deleteNote(at: index)
                    }
                    HapticManager.warning()
                }) {
                    Image(systemName: "trash.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(DesignColors.error)
                }
            }
        }
    }

    private func editNoteField(index: Int) -> some View {
        HStack(spacing: DesignSpacing.sm) {
            TextField("Editar nota", text: $viewModel.editingNoteText)
                .textInputAutocapitalization(.sentences)
                .padding(DesignSpacing.md)
                .background(Color.white)
                .foregroundColor(.black)
                .cornerRadius(DesignCornerRadius.small)

            Button(action: {
                viewModel.updateNote(at: index)
                HapticManager.success()
            }) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(DesignColors.success)
            }

            Button(action: {
                withAnimation {
                    viewModel.editingNoteIndex = nil
                }
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(DesignColors.error)
            }
        }
    }

    private var addNoteField: some View {
        HStack(spacing: DesignSpacing.sm) {
            TextField("Escribe una nota...", text: $viewModel.newNoteText)
                .textInputAutocapitalization(.sentences)
                .padding(DesignSpacing.md)
                .background(Color.white)
                .foregroundColor(.black)
                .cornerRadius(DesignCornerRadius.small)

            Button(action: {
                viewModel.addNote()
                HapticManager.success()
            }) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(DesignColors.success)
            }
            .disabled(viewModel.newNoteText.trimmingCharacters(in: .whitespaces).isEmpty)
            .opacity(viewModel.newNoteText.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)

            Button(action: {
                withAnimation {
                    viewModel.isAddingNote = false
                }
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(DesignColors.error)
            }
        }
        .padding(.top, DesignSpacing.sm)
    }

    private var formattedSelectedDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateFormat = "EEEE, d 'de' MMMM"
        return formatter.string(from: viewModel.selectedDate).capitalized
    }

    // MARK: - Settings Tab View

    private var settingsTabView: some View {
        ScrollView {
            VStack(spacing: DesignSpacing.lg) {
                // Card de configuración rápida
                quickSettingsCard

                // Acciones rápidas
                quickActionsCard

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

    private var quickActionsCard: some View {
        VStack(alignment: .leading, spacing: DesignSpacing.lg) {
            Label("Acciones Rápidas", systemImage: "bolt.fill")
                .font(DesignFonts.headline)
                .foregroundColor(DesignColors.accent)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DesignSpacing.md) {
                QuickActionButton(title: "Ir a fecha", icon: "calendar.badge.clock") {
                    showDatePicker = true
                }

                QuickActionButton(title: "Plantillas", icon: "doc.on.doc") {
                    showTemplates = true
                }

                QuickActionButton(title: "Exportar", icon: "square.and.arrow.up") {
                    showExportSheet = true
                }

                QuickActionButton(title: "Hoy", icon: "sun.max.fill") {
                    withAnimation {
                        viewModel.currentMonth = Date()
                        viewModel.selectedDate = Date()
                        selectedTab = .calendar
                    }
                    HapticManager.selection()
                }
            }
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
                    .frame(width: 56, height: 56)
                    .shadow(color: DesignColors.accent.opacity(0.4), radius: 12, y: 6)

                Image(systemName: "pencil")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
        .buttonStyle(.plain)
        .padding(.trailing, 16)
    }

    // MARK: - Helpers

    private func currentDateString() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateFormat = "EEEE, d 'de' MMMM"
        return formatter.string(from: Date()).capitalized
    }
}

// MARK: - Quick Action Button

struct QuickActionButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: DesignSpacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundColor(DesignColors.accent)

                Text(title)
                    .font(DesignFonts.caption)
                    .foregroundColor(DesignColors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(DesignSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: DesignCornerRadius.medium)
                    .fill(DesignColors.cardBackgroundLight)
            )
        }
    }
}

// MARK: - Preview

#Preview {
    OfflineCalendarView()
        .environmentObject(ThemeManager.shared)
}
