import SwiftUI
import UniformTypeIdentifiers

// Estructura para exportar el archivo CSV (Plantilla)
struct CSVDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }
    var text: String = ""

    init(text: String) {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        if let data = configuration.file.regularFileContents {
            text = String(decoding: data, as: UTF8.self)
        }
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        return FileWrapper(regularFileWithContents: text.data(using: .utf8)!)
    }
}

struct ImportShiftsView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authManager: AuthManager
    @StateObject var plantManager = PlantManager()
    
    // Estados para la importación/exportación
    @State private var showFileImporter = false
    @State private var showFileExporter = false
    @State private var csvDocument: CSVDocument?
    
    // Feedback al usuario
    @State private var isLoading = false
    @State private var statusMessage: String?
    @State private var isError = false

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
                    Text("Importar Turnos")
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                    Image(systemName: "arrow.left").font(.title2).opacity(0)
                }
                .padding()
                .background(Color.black.opacity(0.3))
                
                ScrollView {
                    VStack(spacing: 25) {
                        Text("Gestión masiva de turnos")
                            .font(.title2.bold())
                            .foregroundColor(.white)
                            .padding(.top)
                        
                        // Tarjeta de opciones
                        VStack(spacing: 20) {
                            Text("Opciones")
                                .font(.headline)
                                .foregroundColor(.gray)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            // Opción 1: Descargar Plantilla
                            Button(action: prepareTemplateDownload) {
                                HStack {
                                    Image(systemName: "arrow.down.doc.fill")
                                    Text("Descargar Plantilla CSV")
                                }
                                .bold()
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(red: 0.33, green: 0.8, blue: 0.95))
                                .foregroundColor(.black)
                                .cornerRadius(12)
                            }
                            
                            Divider().background(Color.white.opacity(0.2))
                            
                            // Opción 2: Subir Archivo
                            Button(action: { showFileImporter = true }) {
                                HStack {
                                    Image(systemName: "square.and.arrow.up.fill")
                                    Text("Importar archivo CSV")
                                }
                                .bold()
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(red: 0.7, green: 0.5, blue: 1.0))
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                        }
                        .padding()
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(20)
                        .padding(.horizontal)
                        
                        // Estado
                        if isLoading {
                            ProgressView("Procesando archivo...")
                                .tint(.white)
                                .foregroundColor(.white)
                        }
                        
                        if let message = statusMessage {
                            Text(message)
                                .foregroundColor(isError ? .red : .green)
                                .font(.subheadline)
                                .multilineTextAlignment(.center)
                                .padding()
                                .background(Color.black.opacity(0.4))
                                .cornerRadius(10)
                                .padding(.horizontal)
                        }
                        
                        // Instrucciones actualizadas al formato matriz
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Instrucciones (Formato Matriz):")
                                .font(.caption).bold().foregroundColor(.white)
                            Text("1. La primera fila debe contener las fechas (AAAA-MM-DD) empezando en la columna 2.")
                                .font(.caption).foregroundColor(.gray)
                            Text("2. La primera columna debe contener los nombres del personal.")
                                .font(.caption).foregroundColor(.gray)
                            Text("3. Rellena las celdas con el nombre del turno (ej: Mañana, Tarde, Noche).")
                                .font(.caption).foregroundColor(.gray)
                            Text("4. Deja la celda vacía si no hay turno asignado.")
                                .font(.caption).foregroundColor(.gray)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
        .fileExporter(
            isPresented: $showFileExporter,
            document: csvDocument,
            contentType: .commaSeparatedText,
            defaultFilename: "plantilla_matriz.csv"
        ) { result in
            if case .success = result {
                statusMessage = "Plantilla guardada correctamente."
                isError = false
            } else {
                statusMessage = "Error al guardar plantilla."
                isError = true
            }
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.commaSeparatedText, .plainText],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                processImportedFile(url: url)
            case .failure(let error):
                statusMessage = "Error al leer: \(error.localizedDescription)"
                isError = true
            }
        }
        .onAppear {
            if !authManager.userPlantId.isEmpty {
                plantManager.fetchCurrentPlant(plantId: authManager.userPlantId)
            }
        }
    }
    
    // Generar plantilla estilo MATRIZ (Horizontal)
    func prepareTemplateDownload() {
        // Generamos fechas para el mes actual como ejemplo
        let calendar = Calendar.current
        let today = Date()
        let range = calendar.range(of: .day, in: .month, for: today)!
        let components = calendar.dateComponents([.year, .month], from: today)
        let year = components.year!
        let month = components.month!
        
        var header = "," // Primera celda vacía (esquina superior izquierda)
        
        // Crear cabeceras de fecha
        for day in range {
            let dateStr = String(format: "%04d-%02d-%02d", year, month, day)
            header += "\(dateStr),"
        }
        // Eliminar última coma
        header = String(header.dropLast()) + "\n"
        
        // Añadir filas de ejemplo con personal (si existe)
        var body = ""
        let staff = plantManager.currentPlant?.allStaffList.prefix(5) ?? []
        
        if staff.isEmpty {
            body += "Nombre del Personal,Mañana,Tarde,Noche,,,,,"
        } else {
            for person in staff {
                body += "\(person.name),Mañana,Tarde,Noche,,,,,\n"
            }
        }
        
        csvDocument = CSVDocument(text: header + body)
        showFileExporter = true
    }
    
    func processImportedFile(url: URL) {
        guard let plant = plantManager.currentPlant else {
            statusMessage = "Error: Datos de planta no cargados."
            isError = true
            return
        }
        
        isLoading = true
        statusMessage = nil
        
        guard url.startAccessingSecurityScopedResource() else {
            statusMessage = "Permiso denegado."
            isError = true
            isLoading = false
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }
        
        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            // Llamamos a la nueva función de importación matricial
            plantManager.processMatrixCSVImport(csvContent: content, plant: plant) { success, msg in
                DispatchQueue.main.async {
                    isLoading = false
                    isError = !success
                    statusMessage = msg
                }
            }
        } catch {
            isLoading = false
            isError = true
            statusMessage = "Error leyendo archivo."
        }
    }
}
