import SwiftUI

struct JoinPlantView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject var plantManager = PlantManager()
    
    // Inputs
    @State private var plantIdInput: String = ""
    @State private var passwordInput: String = ""
    
    // Selección
    @State private var selectedStaff: PlantStaff?
    
    var body: some View {
        ZStack {
            // Fondo
            Color.deepSpace.ignoresSafeArea()
            
            // Círculos decorativos
            ZStack {
                Circle().fill(Color.electricBlue).frame(width: 200).blur(radius: 60).offset(x: -120, y: -200)
                Circle().fill(Color.neonViolet).frame(width: 200).blur(radius: 60).offset(x: 120, y: 200)
            }.opacity(0.5)
            
            VStack(spacing: 20) {
                
                // Cabecera
                Text("Unirse a una Planta")
                    .font(.largeTitle.bold())
                    .foregroundColor(.white)
                    .padding(.top, 40)
                
                if plantManager.foundPlant == nil {
                    // --- FASE 1: BUSCAR PLANTA ---
                    loginPhase
                } else {
                    // --- FASE 2: SELECCIONAR PERSONAL ---
                    selectionPhase
                }
                
                Spacer()
            }
            .padding()
            
            // Loading Overlay
            if plantManager.isLoading {
                ZStack {
                    Color.black.opacity(0.4).ignoresSafeArea()
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.5)
                }
            }
        }
        // Si el registro es exitoso, cerrar la pantalla
        .onChange(of: plantManager.joinSuccess) { success in
            if success {
                dismiss()
            }
        }
    }
    
    // VISTA FASE 1: Formulario de ID y Contraseña
    var loginPhase: some View {
        VStack(spacing: 20) {
            Text("Introduce las credenciales facilitadas por tu supervisor.")
                .font(.body)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            VStack(spacing: 15) {
                GlassTextField(icon: "building.2.fill", placeholder: "ID de la Planta", text: $plantIdInput)
                GlassTextField(icon: "key.fill", placeholder: "Contraseña de acceso", text: $passwordInput, isSecure: true)
                
                if let error = plantManager.errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
            .padding()
            
            Button(action: {
                // Ocultar teclado
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                plantManager.searchPlant(plantId: plantIdInput, password: passwordInput)
            }) {
                Text("Buscar Planta")
                    .bold()
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.electricBlue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .padding()
    }
    
    // VISTA FASE 2: Lista de personal
    var selectionPhase: some View {
        VStack(spacing: 20) {
            VStack(spacing: 5) {
                Text(plantManager.foundPlant?.name ?? "")
                    .font(.title2.bold())
                    .foregroundColor(.neonViolet)
                Text(plantManager.foundPlant?.hospitalName ?? "")
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Text("¿Quién eres tú en la lista?")
                .font(.subheadline)
                .foregroundColor(.white)
            
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(plantManager.foundPlant?.staffList ?? [], id: \.self) { staff in
                        Button(action: {
                            selectedStaff = staff
                        }) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(staff.name)
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    Text(staff.role)
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.6))
                                }
                                Spacer()
                                
                                if selectedStaff == staff {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.neonViolet)
                                } else {
                                    Image(systemName: "circle")
                                        .foregroundColor(.white.opacity(0.3))
                                }
                            }
                            .padding()
                            .background(Color.white.opacity(selectedStaff == staff ? 0.15 : 0.05))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(selectedStaff == staff ? Color.neonViolet : Color.clear, lineWidth: 1)
                            )
                        }
                    }
                }
                .padding(.horizontal)
            }
            .frame(maxHeight: 350)
            
            if let staff = selectedStaff {
                Button(action: {
                    if let plant = plantManager.foundPlant {
                        plantManager.joinPlant(plant: plant, selectedStaff: staff)
                    }
                }) {
                    Text("Confirmar: Soy \(staff.name)")
                        .bold()
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(LinearGradient(colors: [.electricBlue, .neonViolet], startPoint: .leading, endPoint: .trailing))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            
            Button("Cancelar / Buscar otra") {
                plantManager.foundPlant = nil
                selectedStaff = nil
                plantManager.errorMessage = nil
            }
            .foregroundColor(.white.opacity(0.6))
        }
    }
}

// Preview
struct JoinPlantView_Previews: PreviewProvider {
    static var previews: some View {
        JoinPlantView()
    }
}
