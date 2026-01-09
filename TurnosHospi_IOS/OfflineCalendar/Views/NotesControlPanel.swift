import SwiftUI

// MARK: - Panel de Control de Notas

struct NotesControlPanel: View {
    @ObservedObject var viewModel: OfflineCalendarViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Cabecera Día
            HStack {
                VStack(alignment: .leading, spacing: DesignSpacing.xs) {
                    Text(formattedDate(viewModel.selectedDate))
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    let key = viewModel.dateKey(for: viewModel.selectedDate)
                    Text(viewModel.localShifts[key]?.shiftName ?? "Libre")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                Spacer()
            }

            Divider().background(Color.gray)

            // Sección Notas
            HStack {
                Text("Anotaciones")
                    .font(.headline)
                    .foregroundColor(DesignColors.accent)
                Spacer()
                if !viewModel.isAddingNote && viewModel.editingNoteIndex == nil {
                    Button(action: {
                        viewModel.isAddingNote = true
                        viewModel.newNoteText = ""
                    }) {
                        Image(systemName: "plus")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                }
            }

            ScrollView {
                VStack(spacing: DesignSpacing.sm) {
                    let key = viewModel.dateKey(for: viewModel.selectedDate)
                    let notes = viewModel.localNotes[key] ?? []

                    if notes.isEmpty && !viewModel.isAddingNote {
                        Text("No hay notas. Pulsa + para crear una.")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(.top, DesignSpacing.xs)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    ForEach(Array(notes.enumerated()), id: \.offset) { index, note in
                        if viewModel.editingNoteIndex == index {
                            editingNoteRow(index: index)
                        } else {
                            noteRow(note: note, index: index)
                        }
                    }
                }
            }
            .frame(maxHeight: 120)

            if viewModel.isAddingNote {
                addNoteRow
            }
        }
        .padding(DesignSpacing.lg)
        .frame(minHeight: 200, alignment: .top)
    }

    // MARK: - Subviews

    private func editingNoteRow(index: Int) -> some View {
        HStack {
            NoteTextField(text: $viewModel.editingNoteText, placeholder: "Editar nota")

            Button(action: { viewModel.updateNote(at: index) }) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(DesignColors.success)
            }
            Button(action: { viewModel.editingNoteIndex = nil }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(DesignColors.error)
            }
        }
    }

    private func noteRow(note: String, index: Int) -> some View {
        HStack {
            Text(note)
                .foregroundColor(.white)
                .padding(DesignSpacing.sm)
                .background(DesignColors.cardBackgroundLight)
                .cornerRadius(DesignCornerRadius.small)
            Spacer()
            Button(action: {
                viewModel.editingNoteIndex = index
                viewModel.editingNoteText = note
                viewModel.isAddingNote = false
            }) {
                Image(systemName: "pencil")
                    .foregroundColor(DesignColors.accent)
            }
            Button(action: { viewModel.deleteNote(at: index) }) {
                Image(systemName: "trash")
                    .foregroundColor(DesignColors.error)
            }
        }
    }

    private var addNoteRow: some View {
        HStack {
            NoteTextField(text: $viewModel.newNoteText, placeholder: "Escribe aquí...")
            Button(action: { viewModel.addNote() }) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(DesignColors.success)
            }
            Button(action: { viewModel.isAddingNote = false }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(DesignColors.error)
            }
        }
        .padding(.top, DesignSpacing.sm)
    }

    // MARK: - Helpers

    func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "es_ES")
        formatter.dateFormat = "d 'de' MMMM"
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
            .padding(10)
            .background(Color.white)
            .cornerRadius(DesignCornerRadius.small)
            .foregroundColor(.black)
    }
}
