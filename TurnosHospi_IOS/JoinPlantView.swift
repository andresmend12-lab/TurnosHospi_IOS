import SwiftUI

struct JoinPlantView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authManager: AuthManager
    @StateObject var plantManager = PlantManager()
    
    @State private var plantIdInput: String = ""
    @State private var passwordInput: String = ""
    @State private var selectedStaff: PlantStaff?
    
    var body: some View {
        ZStack {
            Color.deepSpace.ignoresSafeArea()
            
            ZStack {
                Circle().fill(Color.electricBlue).frame(width: 200).blur(radius: 60).offset(x: -120, y: -200)
                Circle().fill(Color.neonViolet).frame(width: 200).blur(radius: 60).offset(x: 120, y: 200)
            }
            .opacity(0.5)
            
            VStack(spacing: 20) {
                Text("Unirse a una Planta")
                    .font(.largeTitle.bold())
                    .foregroundColor(.white)
                    .padding(.top, 30)
                
                if plantManager.foundPlant == nil {
                    loginPhase
                } else {
                    selectionPhase
                }
                
                Spacer()
            }
            .padding()
            
            if plantManager.isLoading {
                ZStack {
                    Color.black.opacity(0.5).ignoresSafeArea()
                    ProgressView().tint(.white).scaleEffect(1.5)
                }
            }
        }
        // --- AQUÍ ESTÁ LA SOLUCIÓN ---
        .onChange(of: plantManager.joinSuccess) { success in
            if success {
                // 1. Actualizamos el AuthManager AL INSTANTE
                if let plant = plantManager.foundPlant {
                    authManager.userPlantId = plant.id
                    // También podemos actualizar el rol si cambió
                    if let staff = selectedStaff {
                        authManager.userRole = staff.role
                    }
                }
                
                // 2. Cerramos la pantalla
                dismiss()
            }
        }
    }
    
    var loginPhase: some View {
        VStack(spacing: 20) {
            Text("Introduce las credenciales de la planta.")
                .font(.body)
                .foregroundColor(.white.opacity(0.7))
            
            VStack(spacing: 15) {
                GlassTextField(icon: "building.2.fill", placeholder: "ID de la Planta", text: $plantIdInput)
                GlassTextField(icon: "key.fill", placeholder: "Contraseña", text: $passwordInput, isSecure: true)
                
                if let error = plantManager.errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                }
            }
            .padding()
            
            Button(action: {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                plantManager.searchPlant(plantId: plantIdInput, password: passwordInput)
            }) {
                Text("Buscar Planta")
                    .bold()
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(LinearGradient(colors: [.electricBlue, .neonViolet], startPoint: .leading, endPoint: .trailing))
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.1), lineWidth: 1))
        .padding()
    }
    
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
            
            Divider().background(Color.white.opacity(0.3))
            
            VStack(spacing: 5) {
                Text("Selecciona tu perfil en la lista")
                    .font(.subheadline)
                    .foregroundColor(.white)
                
                let displayRole = authManager.userRole == "Enfermero" ? "Enfermera/o" : authManager.userRole
                Text("(Solo se muestran puestos de \(displayRole))")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            ScrollView {
                VStack(spacing: 10) {
                    // Filtro inteligente de roles
                    let targetRole = (authManager.userRole == "Enfermero") ? "Enfermera/o" : authManager.userRole
                    
                    let filteredStaff = (plantManager.foundPlant?.staffList ?? []).filter { $0.role == targetRole }
                    
                    if filteredStaff.isEmpty {
                        Text("No hay puestos disponibles para tu rol en esta planta.")
                            .foregroundColor(.white.opacity(0.6))
                            .padding(.top, 20)
                            .multilineTextAlignment(.center)
                    } else {
                        ForEach(filteredStaff, id: \.id) { staff in
                            StaffRow(staff: staff, isSelected: selectedStaff?.id == staff.id)
                                .onTapGesture {
                                    selectedStaff = staff
                                }
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
                        .background(Color.green.opacity(0.8))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .shadow(color: .green.opacity(0.4), radius: 10, x: 0, y: 5)
                }
                .padding(.horizontal)
            }
            
            Button("Cancelar búsqueda") {
                withAnimation {
                    plantManager.foundPlant = nil
                    selectedStaff = nil
                    plantManager.errorMessage = nil
                }
            }
            .foregroundColor(.white.opacity(0.6))
            .padding(.bottom, 10)
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.1), lineWidth: 1))
        .padding()
    }
}

// Subvista auxiliar
struct StaffRow: View {
    let staff: PlantStaff
    let isSelected: Bool
    
    var body: some View {
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
            
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.neonViolet)
                    .font(.title3)
            } else {
                Image(systemName: "circle")
                    .foregroundColor(.white.opacity(0.2))
                    .font(.title3)
            }
        }
        .padding()
        .background(Color.white.opacity(isSelected ? 0.15 : 0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.neonViolet : Color.clear, lineWidth: 1)
        )
    }
}
