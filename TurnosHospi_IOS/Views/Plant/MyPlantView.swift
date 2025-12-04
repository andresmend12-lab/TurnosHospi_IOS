import SwiftUI

struct MyPlantView: View {
    var plant: Plant?
    var onBack: () -> Void
    var onJoinPlant: (String, @escaping (Bool, String?) -> Void) -> Void
    
    @State private var invitationCode = ""
    @State private var isJoining = false
    @State private var errorMessage: String? = nil
    
    var body: some View {
        ZStack {
            Color(hex: "0F172A").ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Header Nav
                HStack {
                    Button(action: onBack) {
                        Image(systemName: "arrow.left").foregroundColor(.white)
                    }
                    Text("Mi Planta").font(.title3).fontWeight(.bold).foregroundColor(.white)
                    Spacer()
                }
                .padding()
                
                if let plant = plant {
                    // --- CASO 1: YA TIENE PLANTA ---
                    VStack(spacing: 20) {
                        Image(systemName: "building.2.crop.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(Color(hex: "54C7EC"))
                        
                        Text(plant.name)
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("Código: \(plant.id)") // ID como ejemplo de código
                            .padding(8)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(8)
                            .foregroundColor(.gray)
                        
                        Button(action: { /* onOpenDetail */ }) {
                            Text("Ver Tablón de Planta")
                                .fontWeight(.bold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(hex: "7C3AED"))
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                    }
                    .padding()
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(16)
                    
                } else {
                    // --- CASO 2: NO TIENE PLANTA (UNIRSE) ---
                    VStack(spacing: 20) {
                        Image(systemName: "person.3.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("No perteneces a ninguna planta")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Text("Introduce el código de invitación proporcionado por tu supervisor para unirte.")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        TextField("Código de invitación", text: $invitationCode)
                            .textFieldStyle(OutlinedTextFieldStyle())
                            .textInputAutocapitalization(.characters)
                        
                        if let error = errorMessage {
                            Text(error).foregroundColor(.red).font(.caption)
                        }
                        
                        Button(action: {
                            isJoining = true
                            errorMessage = nil
                            onJoinPlant(invitationCode) { success, msg in
                                isJoining = false
                                if !success { errorMessage = msg ?? "Error al unirse" }
                            }
                        }) {
                            HStack {
                                if isJoining { ProgressView().tint(.white) }
                                Text("UNIRSE A PLANTA")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(hex: "54C7EC"))
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(invitationCode.isEmpty || isJoining)
                    }
                    .padding()
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(16)
                }
                
                Spacer()
            }
            .padding()
        }
        .navigationBarHidden(true)
    }
}
