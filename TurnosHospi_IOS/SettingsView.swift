import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var authService: AuthService
    
    // Estado para toggles simulados
    @State private var notificationsEnabled = true
    @State private var emailAlerts = false
    
    var body: some View {
        NavigationView {
            List {
                // --- Sección de Perfil ---
                if let user = authService.currentUser {
                    Section {
                        HStack(spacing: 15) {
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .frame(width: 60, height: 60)
                                .foregroundColor(.blue)
                            
                            VStack(alignment: .leading, spacing: 5) {
                                Text(user.fullName)
                                    .font(.headline)
                                Text(user.role.rawValue) // "Enfermero/a", etc.
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
                
                // --- Configuración General ---
                Section(header: Text("Notificaciones")) {
                    Toggle("Notificaciones Push", isOn: $notificationsEnabled)
                    Toggle("Alertas por Email", isOn: $emailAlerts)
                }
                
                Section(header: Text("Preferencias de Turnos")) {
                    NavigationLink(destination: Text("Configurar disponibilidad...")) {
                        Text("Mis Preferencias")
                    }
                    NavigationLink(destination: Text("Historial de cambios...")) {
                        Text("Historial")
                    }
                }
                
                // --- Información de la App ---
                Section(header: Text("Acerca de")) {
                    HStack {
                        Text("Versión")
                        Spacer()
                        Text("1.0.0 (Beta)")
                            .foregroundColor(.gray)
                    }
                    HStack {
                        Text("Hospital")
                        Spacer()
                        Text("Hospital General")
                            .foregroundColor(.gray)
                    }
                }
                
                // --- Cerrar Sesión ---
                Section {
                    Button(action: {
                        // CORREGIDO: Usar signOut()
                        authService.signOut()
                    }) {
                        HStack {
                            Spacer()
                            Text("Cerrar Sesión")
                                .foregroundColor(.red)
                            Spacer()
                        }
                    }
                }
            }
            // Mantenemos la corrección de estilo para Mac/iOS que hicimos antes
            #if os(iOS)
            .listStyle(InsetGroupedListStyle())
            #else
            .listStyle(GroupedListStyle())
            #endif
            .navigationTitle("Perfil")
        }
    }
}
