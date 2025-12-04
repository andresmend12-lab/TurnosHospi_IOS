import SwiftUI

struct MainMenuView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject var shiftManager = ShiftManager()
    
    @State private var showMenu = false
    @State private var selectedDate = Date()
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ZStack {
                    Color.deepSpace.ignoresSafeArea()
                    
                    VStack(spacing: 20) {
                        
                        // HEADER
                        HStack {
                            Button(action: {
                                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                                    showMenu.toggle()
                                }
                            }) {
                                Image(systemName: "line.3.horizontal")
                                    .font(.title)
                                    .foregroundColor(.white)
                                    .padding(10)
                                    .background(Color.white.opacity(0.1))
                                    .clipShape(Circle())
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing) {
                                Text("Bienvenido")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.6))
                                Text(authManager.currentUserName.isEmpty ? "Usuario" : authManager.currentUserName)
                                    .font(.headline)
                                    .bold()
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 50)
                        
                        // CONTENIDO
                        ScrollView {
                            VStack(spacing: 20) {
                                
                                // CALENDARIO
                                // FIX: Se añade el parámetro 'monthlyAssignments' con un diccionario vacío.
                                CalendarWithShiftsView(
                                    selectedDate: $selectedDate,
                                    shifts: shiftManager.userShifts,
                                    monthlyAssignments: [:]
                                )
                                
                                // INFO DEL DÍA
                                VStack(alignment: .leading, spacing: 15) {
                                    Text("Agenda del día")
                                        .font(.title3)
                                        .bold()
                                        .foregroundColor(.white)
                                        .padding(.horizontal)
                                    
                                    let shiftForDay = shiftManager.userShifts.first { shift in
                                        Calendar.current.isDate(shift.date, inSameDayAs: selectedDate)
                                    }
                                    
                                    if let shift = shiftForDay {
                                        HStack {
                                            Rectangle()
                                                .fill(shift.type.color)
                                                .frame(width: 5)
                                                .cornerRadius(2)
                                            
                                            VStack(alignment: .leading) {
                                                Text(shift.type.rawValue)
                                                    .font(.headline)
                                                    .foregroundColor(.white)
                                                Text("Turno asignado")
                                                    .font(.subheadline)
                                                    .foregroundColor(.gray)
                                            }
                                            Spacer()
                                            
                                            Image(systemName: getIconForShift(shift.type))
                                                .foregroundColor(.white.opacity(0.5))
                                                .font(.title2)
                                        }
                                        .padding()
                                        .background(Color.white.opacity(0.05))
                                        .cornerRadius(15)
                                        .overlay(RoundedRectangle(cornerRadius: 15).stroke(shift.type.color.opacity(0.5), lineWidth: 1))
                                        .padding(.horizontal)
                                        
                                    } else {
                                        HStack {
                                            Spacer()
                                            VStack(spacing: 10) {
                                                Image(systemName: "calendar.badge.exclamationmark")
                                                    .font(.largeTitle)
                                                    .foregroundColor(.gray.opacity(0.5))
                                                Text("No tienes turnos para este día")
                                                    .foregroundColor(.gray)
                                            }
                                            Spacer()
                                        }
                                        .padding(.vertical, 30)
                                    }
                                }
                            }
                            .padding(.bottom, 100)
                        }
                    }
                }
                .cornerRadius(showMenu ? 30 : 0)
                .offset(x: showMenu ? 260 : 0)
                .scaleEffect(showMenu ? 0.85 : 1)
                .shadow(color: .black.opacity(0.5), radius: showMenu ? 20 : 0, x: -10, y: 0)
                .disabled(showMenu)
                .onTapGesture {
                    if showMenu { withAnimation { showMenu = false } }
                }
                
                if showMenu {
                    SideMenuView(isShowing: $showMenu)
                        .frame(width: 260)
                        .transition(.move(edge: .leading))
                        .offset(x: -UIScreen.main.bounds.width / 2 + 130)
                        .zIndex(2)
                }
            }
        }
        .onAppear {
            if let user = authManager.user, authManager.currentUserName.isEmpty {
                authManager.fetchUserData(uid: user.uid)
            }
            shiftManager.fetchUserShifts()
        }
    }
    
    func getIconForShift(_ type: ShiftType) -> String {
        switch type {
        case .manana, .mediaManana: return "sun.max.fill"
        case .tarde, .mediaTarde: return "sunset.fill"
        case .noche: return "moon.stars.fill"
        }
    }
}
