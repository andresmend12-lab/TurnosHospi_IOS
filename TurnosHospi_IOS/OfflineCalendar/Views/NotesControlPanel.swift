import SwiftUI

// MARK: - Panel de Control de Notas

struct NotesControlPanel: View {
    @ObservedObject var viewModel: OfflineCalendarViewModel
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSpacing.md) {
            // Cabecera del día
            dayHeader

            Divider()
                .background(DesignColors.border)

            // Sección de notas
            notesSection
        }
        .padding(DesignSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: DesignCornerRadius.large)
                .fill(DesignGradients.cardElevated)
                .shadow(color: DesignShadows.medium, radius: DesignShadows.cardShadowRadius, y: DesignShadows.cardShadowY)
        )
        .frame(minHeight: 200, alignment: .top)
    }

    // MARK: - Subviews

    private var dayHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: DesignSpacing.xs) {
                Text(formattedDate(viewModel.selectedDate))
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

            // Indicador de notas
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
            // Header de notas con botón añadir
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
                        }
                        HapticManager.selection()
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(DesignColors.accent)
                    }
                }
            }

            // Lista de notas
            notesListSection

            // Campo para nueva nota
            if viewModel.isAddingNote {
                addNoteRow
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var notesListSection: some View {
        ScrollView {
            VStack(spacing: DesignSpacing.sm) {
                let key = viewModel.dateKey(for: viewModel.selectedDate)
                let notes = viewModel.localNotes[key] ?? []

                if notes.isEmpty && !viewModel.isAddingNote {
                    emptyNotesState
                }

                ForEach(Array(notes.enumerated()), id: \.offset) { index, note in
                    if viewModel.editingNoteIndex == index {
                        editingNoteRow(index: index)
                            .transition(.opacity)
                    } else {
                        noteRow(note: note, index: index)
                            .transition(.opacity.combined(with: .scale))
                    }
                }
            }
        }
        .frame(maxHeight: 150)
    }

    private var emptyNotesState: some View {
        HStack {
            Image(systemName: "text.bubble")
                .foregroundColor(DesignColors.textTertiary)
            Text("No hay notas. Pulsa + para crear una.")
                .font(DesignFonts.caption)
                .foregroundColor(DesignColors.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, DesignSpacing.md)
    }

    private func editingNoteRow(index: Int) -> some View {
        HStack(spacing: DesignSpacing.sm) {
            NoteTextField(text: $viewModel.editingNoteText, placeholder: "Editar nota")

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

    private var addNoteRow: some View {
        HStack(spacing: DesignSpacing.sm) {
            NoteTextField(text: $viewModel.newNoteText, placeholder: "Escribe una nota...")

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

    // MARK: - Helpers

    func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateFormat = "EEEE, d 'de' MMMM"
        return formatter.string(from: date).capitalized
    }
}

// MARK: - Campo de Texto para Notas

struct NoteTextField: View {
    @Binding var text: String
    var placeholder: String

    var body: some View {
        TextField(placeholder, text: $text)
            .textInputAutocapitalization(.sentences)
            .disableAutocorrection(false)
            .padding(DesignSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: DesignCornerRadius.small)
                    .fill(Color.white)
            )
            .foregroundColor(.black)
    }
}
