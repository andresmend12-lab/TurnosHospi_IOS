import SwiftUI
import FirebaseDatabase

// MARK: - Modelos de Datos para Estadísticas

struct StaffStats: Identifiable {
    let id = UUID()
    let name: String
    var totalHours: Double
    var totalShifts: Int
}

struct MonthlyStats {
    var totalHours: Double
    var totalShifts: Int
    var breakdown: [String: Double] // NombreTurno -> Horas
}

struct StatisticsView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authManager: AuthManager
    @StateObject var plantManager = PlantManager()
    
    // Parámetros
    let plantId: String
    let isSupervisor: Bool
    
    // Estado
    @State private var currentMonth = Date()
    @State private var isLoading = true
    @State private var statsList: [StaffStats] = [] // Para el supervisor (lista ordenada)
    @State private var myStats: MonthlyStats? // Para el usuario normal
    
    // Referencia
    private let ref = Database.database().reference()
    
    // Calendario robusto
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2
        cal.locale = Locale(identifier: "es_ES")
        cal.timeZone = TimeZone.current
        return cal
    }
    
    var body: some View {
        ZStack {
            Color(red: 0.1, green: 0.1, blue: 0.18).ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "arrow.left")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                    Spacer()
                    Text("Estadísticas")
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                    Image(systemName: "arrow.left").font(.title2).opacity(0)
                }
                .padding()
                .background(Color.black.opacity(0.3))
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Selector de Mes
                        HStack {
                            Button(action: { changeMonth(by: -1) }) {
                                Image(systemName: "chevron.left")
                                    .foregroundColor(.white)
                                    .padding()
                                    .background(Color.white.opacity(0.1))
                                    .clipShape(Circle())
                            }
                            
                            Text(monthYearString(for: currentMonth).capitalized)
                                .font(.title3.bold())
                                .foregroundColor(.white)
                                .frame(width: 200)
                            
                            Button(action: { changeMonth(by: 1) }) {
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.white)
                                    .padding()
                                    .background(Color.white.opacity(0.1))
                                    .clipShape(Circle())
                            }
                        }
                        .padding(.top, 20)
                        
                        if isLoading {
                            ProgressView("Calculando horas...")
                                .tint(.white)
                                .foregroundColor(.white)
                                .padding(.top, 50)
                        } else {
                            if isSupervisor {
                                SupervisorStatsContent(statsList: statsList)
                            } else {
                                PersonalStatsContent(stats: myStats, userName: authManager.currentUserName)
                            }
                        }
                    }
                    .padding(.bottom, 50)
                }
            }
        }
        .onAppear {
            // Asegurar que tenemos la info de la planta (para duraciones de turnos y mi nombre real)
            if plantManager.currentPlant == nil {
                plantManager.fetchCurrentPlant(plantId: plantId)
            }
            // Retrasar un poco la carga para asegurar que currentPlant esté listo si acaba de entrar
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                calculateStatistics()
            }
        }
        .onChange(of: currentMonth) { _, _ in
            calculateStatistics()
        }
    }
    
    // MARK: - Lógica de Cálculo
    
    func calculateStatistics() {
        isLoading = true
        
        // Rango del mes seleccionado
        let components = calendar.dateComponents([.year, .month], from: currentMonth)
        guard let startOfMonth = calendar.date(from: components),
              let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth) else {
            isLoading = false
            return
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        
        // Descargar turnos del mes
        let startKey = "turnos-" + formatter.string(from: startOfMonth)
        let endKey = "turnos-" + formatter.string(from: endOfMonth)
        
        ref.child("plants").child(plantId).child("turnos")
            .queryOrderedByKey()
            .queryStarting(atValue: startKey)
            .queryEnding(atValue: endKey)
            .observeSingleEvent(of: .value) { snapshot in
                
                guard let plant = plantManager.currentPlant else {
                    self.isLoading = false
                    return
                }
                
                let shiftDurations = plant.shiftTimes ?? [:] // [NombreTurno : [start: HH:mm, end: HH:mm]]
                
                if isSupervisor {
                    // SUPERVISOR: Calcular para TODOS
                    var tempStats: [String: StaffStats] = [:]
                    
                    // Inicializar con todo el personal (para que salgan con 0 horas si no trabajaron)
                    for staff in plant.allStaffList {
                        tempStats[staff.name] = StaffStats(name: staff.name, totalHours: 0, totalShifts: 0)
                    }
                    
                    for child in snapshot.children.allObjects as? [DataSnapshot] ?? [] {
                        processDaySnapshotForSupervisor(child, shiftDurations: shiftDurations, stats: &tempStats)
                    }
                    
                    // Convertir a lista y ordenar
                    self.statsList = tempStats.values.sorted { $0.totalHours > $1.totalHours }
                    
                } else {
                    // USUARIO NORMAL: Calcular solo para MÍ
                    var myTotalHours: Double = 0
                    var myTotalShifts: Int = 0
                    var breakdown: [String: Double] = [:]
                    
                    // --- CORRECCIÓN IMPORTANTE ---
                    // Usar el nombre registrado en la planta (myPlantName) si está disponible.
                    // Esto asegura que coincida con el nombre guardado en los turnos.
                    let targetName = plantManager.myPlantName ?? authManager.currentUserName
                    
                    for child in snapshot.children.allObjects as? [DataSnapshot] ?? [] {
                        processDaySnapshotForUser(
                            child,
                            targetName: targetName, // <--- Usamos el nombre corregido
                            shiftDurations: shiftDurations,
                            totalHours: &myTotalHours,
                            totalShifts: &myTotalShifts,
                            breakdown: &breakdown
                        )
                    }
                    
                    self.myStats = MonthlyStats(totalHours: myTotalHours, totalShifts: myTotalShifts, breakdown: breakdown)
                }
                
                self.isLoading = false
            }
    }
    
    // Procesa un día completo para TODOS los empleados (Supervisor)
    private func processDaySnapshotForSupervisor(_ daySnapshot: DataSnapshot, shiftDurations: [String: [String: String]], stats: inout [String: StaffStats]) {
        for shiftSnap in daySnapshot.children.allObjects as? [DataSnapshot] ?? [] {
            // CORRECCIÓN: key es String, no String?
            let shiftName = shiftSnap.key
            let hours = getHoursForShift(shiftName: shiftName, durations: shiftDurations)
            
            // Procesar Enfermeros
            for slot in shiftSnap.childSnapshot(forPath: "nurses").children.allObjects as? [DataSnapshot] ?? [] {
                let p = slot.childSnapshot(forPath: "primary").value as? String ?? ""
                let s = slot.childSnapshot(forPath: "secondary").value as? String ?? ""
                let h = slot.childSnapshot(forPath: "halfDay").value as? Bool ?? false
                
                updateStats(name: p, hours: h ? hours / 2 : hours, stats: &stats)
                if h { updateStats(name: s, hours: hours / 2, stats: &stats) }
            }
            
            // Procesar Auxiliares
            for slot in shiftSnap.childSnapshot(forPath: "auxiliaries").children.allObjects as? [DataSnapshot] ?? [] {
                let p = slot.childSnapshot(forPath: "primary").value as? String ?? ""
                let s = slot.childSnapshot(forPath: "secondary").value as? String ?? ""
                let h = slot.childSnapshot(forPath: "halfDay").value as? Bool ?? false
                
                updateStats(name: p, hours: h ? hours / 2 : hours, stats: &stats)
                if h { updateStats(name: s, hours: hours / 2, stats: &stats) }
            }
        }
    }
    
    private func updateStats(name: String, hours: Double, stats: inout [String: StaffStats]) {
        if name.isEmpty || name == "Sin asignar" { return }
        // Si el usuario no estaba en la lista inicial (ej: borrado), lo creamos
        var current = stats[name] ?? StaffStats(name: name, totalHours: 0, totalShifts: 0)
        current.totalHours += hours
        current.totalShifts += 1
        stats[name] = current
    }
    
    // Procesa un día completo para UN usuario (Normal)
    private func processDaySnapshotForUser(_ daySnapshot: DataSnapshot, targetName: String, shiftDurations: [String: [String: String]], totalHours: inout Double, totalShifts: inout Int, breakdown: inout [String: Double]) {
        
        for shiftSnap in daySnapshot.children.allObjects as? [DataSnapshot] ?? [] {
            // CORRECCIÓN: key es String, no String?
            let shiftName = shiftSnap.key
            let hours = getHoursForShift(shiftName: shiftName, durations: shiftDurations)
            var workedHours: Double = 0
            
            // Buscar en Enfermeros
            for slot in shiftSnap.childSnapshot(forPath: "nurses").children.allObjects as? [DataSnapshot] ?? [] {
                let p = slot.childSnapshot(forPath: "primary").value as? String ?? ""
                let s = slot.childSnapshot(forPath: "secondary").value as? String ?? ""
                let h = slot.childSnapshot(forPath: "halfDay").value as? Bool ?? false
                
                if p == targetName { workedHours = h ? hours / 2 : hours }
                else if h && s == targetName { workedHours = hours / 2 }
            }
            
            // Buscar en Auxiliares (si no encontrado ya)
            if workedHours == 0 {
                for slot in shiftSnap.childSnapshot(forPath: "auxiliaries").children.allObjects as? [DataSnapshot] ?? [] {
                    let p = slot.childSnapshot(forPath: "primary").value as? String ?? ""
                    let s = slot.childSnapshot(forPath: "secondary").value as? String ?? ""
                    let h = slot.childSnapshot(forPath: "halfDay").value as? Bool ?? false
                    
                    if p == targetName { workedHours = h ? hours / 2 : hours }
                    else if h && s == targetName { workedHours = hours / 2 }
                }
            }
            
            if workedHours > 0 {
                totalHours += workedHours
                totalShifts += 1
                breakdown[shiftName, default: 0] += workedHours
            }
        }
    }
    
    // Helper para calcular duración
    private func getHoursForShift(shiftName: String, durations: [String: [String: String]]) -> Double {
        guard let times = durations[shiftName],
              let startStr = times["start"],
              let endStr = times["end"] else {
            // Fallback por defecto si no hay config (ej: 7h)
            return 7.0
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        
        guard let d1 = formatter.date(from: startStr),
              let d2 = formatter.date(from: endStr) else { return 0 }
        
        var interval = d2.timeIntervalSince(d1)
        if interval < 0 { interval += 24 * 3600 } // Cruza medianoche
        
        return interval / 3600.0
    }
    
    // MARK: - Helpers UI
    private func changeMonth(by value: Int) {
        if let newDate = calendar.date(byAdding: .month, value: value, to: currentMonth) {
            currentMonth = newDate
        }
    }
    
    private func monthYearString(for date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_ES")
        f.dateFormat = "LLLL yyyy"
        return f.string(from: date)
    }
}

// MARK: - Subvistas de Contenido

struct SupervisorStatsContent: View {
    let statsList: [StaffStats]
    
    var body: some View {
        VStack(spacing: 15) {
            ForEach(Array(statsList.enumerated()), id: \.element.id) { index, stat in
                HStack {
                    // Puesto (Ranking)
                    Text("\(index + 1)")
                        .font(.headline)
                        .foregroundColor(.gray)
                        .frame(width: 30)
                    
                    VStack(alignment: .leading) {
                        Text(stat.name)
                            .font(.headline)
                            .foregroundColor(.white)
                        Text("\(stat.totalShifts) turnos")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    Text(String(format: "%.1f h", stat.totalHours))
                        .font(.title3.bold())
                        .foregroundColor(Color(red: 0.33, green: 0.8, blue: 0.95))
                }
                .padding()
                .background(Color.white.opacity(0.05))
                .cornerRadius(12)
                .padding(.horizontal)
            }
            
            if statsList.isEmpty {
                Text("No hay datos para este mes")
                    .foregroundColor(.gray)
            }
        }
    }
}

struct PersonalStatsContent: View {
    let stats: MonthlyStats?
    let userName: String
    
    var body: some View {
        VStack(spacing: 25) {
            if let s = stats, s.totalHours > 0 {
                // Total
                VStack(spacing: 5) {
                    Text("Total Horas")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    Text(String(format: "%.1f", s.totalHours))
                        .font(.system(size: 60, weight: .bold))
                        .foregroundColor(.white)
                    Text("horas trabajadas")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                .padding(30)
                .background(
                    Circle()
                        .stroke(Color(red: 0.33, green: 0.8, blue: 0.95), lineWidth: 4)
                        .background(Circle().fill(Color.white.opacity(0.05)))
                )
                .padding(.vertical)
                
                // Desglose
                VStack(alignment: .leading, spacing: 15) {
                    Text("Desglose por turno")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal)
                    
                    ForEach(s.breakdown.sorted(by: { $0.value > $1.value }), id: \.key) { key, value in
                        HStack {
                            Text(key)
                                .foregroundColor(.white)
                            Spacer()
                            Text(String(format: "%.1f h", value))
                                .bold()
                                .foregroundColor(Color(red: 0.7, green: 0.5, blue: 1.0))
                        }
                        .padding()
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(10)
                        .padding(.horizontal)
                    }
                }
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "chart.bar.doc.horizontal")
                        .font(.system(size: 60))
                        .foregroundColor(.gray.opacity(0.5))
                    Text("No tienes turnos registrados este mes.")
                        .foregroundColor(.gray)
                }
                .frame(height: 300)
            }
        }
    }
}
