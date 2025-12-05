import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        ZStack {
            // Fondo oscuro (usando el color definido en tu app)
            Color.deepSpace.ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Cabecera
                HStack {
                    Text("Configuración de Colores")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                    Spacer()
                    Button(action: {
                        themeManager.saveColors() // Guardar al cerrar
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                .padding()
                
                ScrollView {
                    VStack(spacing: 25) {
                        
                        // Sección Turnos Completos
                        VStack(alignment: .leading, spacing: 15) {
                            Text("Turnos Completos")
                                .font(.headline).foregroundColor(.gray)
                            
                            ColorPickerRow(label: "Mañana", color: $themeManager.morningColor)
                            ColorPickerRow(label: "Tarde", color: $themeManager.afternoonColor)
                            ColorPickerRow(label: "Noche", color: $themeManager.nightColor)
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(15)
                        .overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.white.opacity(0.1), lineWidth: 1))
                        
                        // Sección Media Jornada
                        VStack(alignment: .leading, spacing: 15) {
                            Text("Media Jornada")
                                .font(.headline).foregroundColor(.gray)
                            
                            ColorPickerRow(label: "Media Mañana", color: $themeManager.morningHalfColor)
                            ColorPickerRow(label: "Media Tarde", color: $themeManager.afternoonHalfColor)
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(15)
                        .overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.white.opacity(0.1), lineWidth: 1))
                        
                        // Sección Otros
                        VStack(alignment: .leading, spacing: 15) {
                            Text("Otros")
                                .font(.headline).foregroundColor(.gray)
                            
                            ColorPickerRow(label: "Vacaciones / Libre", color: $themeManager.holidayColor)
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(15)
                        .overlay(RoundedRectangle(cornerRadius: 15).stroke(Color.white.opacity(0.1), lineWidth: 1))
                        
                        // Botón para restablecer
                        Button(action: {
                            withAnimation {
                                themeManager.resetDefaults()
                            }
                        }) {
                            Text("Restablecer colores por defecto")
                                .foregroundColor(.red)
                                .font(.subheadline)
                                .padding()
                        }
                    }
                    .padding()
                }
            }
        }
        .onDisappear {
            // Aseguramos guardado al salir por gesto
            themeManager.saveColors()
        }
    }
}

// Componente auxiliar para cada fila de color
struct ColorPickerRow: View {
    let label: String
    @Binding var color: Color
    
    var body: some View {
        ColorPicker(selection: $color, supportsOpacity: false) {
            Text(label)
                .foregroundColor(.white)
                .bold()
        }
        .padding(.vertical, 5)
    }
}
