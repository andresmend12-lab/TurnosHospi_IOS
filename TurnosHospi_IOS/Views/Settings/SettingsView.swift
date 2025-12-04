import SwiftUI

struct SettingsView: View {
    @Binding var currentColors: ShiftColors
    var onBack: () -> Void
    var onDeleteAccount: () -> Void
    
    @State private var showDeleteConfirm = false
    
    var body: some View {
        ZStack {
            Color(hex: "0F172A").ignoresSafeArea()
            
            VStack {
                // Header
                HStack {
                    Button(action: onBack) {
                        Image(systemName: "arrow.left").foregroundColor(.white)
                    }
                    Text("Configuración").font(.title3).fontWeight(.bold).foregroundColor(.white)
                    Spacer()
                }
                .padding()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Sección Colores
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Personalizar Colores de Turnos")
                                .font(.headline).foregroundColor(.white)
                            
                            Divider().background(Color.white.opacity(0.2))
                            
                            Group {
                                ColorPickerRow(label: "Turno Mañana", color: $currentColors.morning)
                                ColorPickerRow(label: "Media Mañana", color: $currentColors.morningHalf)
                                ColorPickerRow(label: "Turno Tarde", color: $currentColors.afternoon)
                                ColorPickerRow(label: "Turno Noche", color: $currentColors.night)
                                ColorPickerRow(label: "Saliente", color: $currentColors.saliente)
                                ColorPickerRow(label: "Libre", color: $currentColors.free)
                            }
                        }
                        .padding()
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(16)
                        
                        // Sección Cuenta
                        VStack(spacing: 16) {
                            Text("Gestionar cuenta")
                                .font(.headline).foregroundColor(.white)
                            
                            Button(action: { showDeleteConfirm = true }) {
                                Text("Borrar mi cuenta")
                                    .foregroundColor(.white)
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.red.opacity(0.8))
                                    .cornerRadius(8)
                            }
                            
                            Text("Esta acción es permanente y no se puede deshacer.")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(16)
                    }
                    .padding()
                }
            }
        }
        .navigationBarHidden(true)
        .alert("¿Estás seguro?", isPresented: $showDeleteConfirm) {
            Button("Cancelar", role: .cancel) { }
            Button("Borrar", role: .destructive) { onDeleteAccount() }
        } message: {
            Text("Se borrarán todos tus datos asociados a la aplicación.")
        }
    }
}

struct ColorPickerRow: View {
    let label: String
    @Binding var color: Color
    
    var body: some View {
        HStack {
            Text(label).foregroundColor(.white)
            Spacer()
            ColorPicker("", selection: $color)
                .labelsHidden()
        }
        .padding(.vertical, 4)
    }
}
