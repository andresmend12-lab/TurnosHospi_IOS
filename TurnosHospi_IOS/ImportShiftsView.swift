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
    var showsStandaloneHeader: Bool = true
    var onClose: (() -> Void)? = nil
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
                if showsStandaloneHeader {
                    HStack(spacing: 14) {
                        Button(action: {
                            if let onClose = onClose {
                                onClose()
                            } else {
                                dismiss()
                            }
                        }) {
                            Image(systemName: "line.3.horizontal")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                                .padding(10)
                                .background(Color.white.opacity(0.1))
                                .clipShape(Circle())
                        }
                        Spacer()
                        Text("Importar Turnos")
                            .font(.headline)
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .padding()
                    .background(Color.black.opacity(0.3))
                }
                
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
                            Text("1. La primera fila contiene las fechas (AAAA-MM-DD) empezando en la columna 2.")
                                .font(.caption).foregroundColor(.gray)
                            Text("2. La primera columna contiene los nombres del personal.")
                                .font(.caption).foregroundColor(.gray)
                            Text("3. Rellena las celdas con el turno (Mañana, Tarde, Noche, Libre).")
                                .font(.caption).foregroundColor(.gray)
                            Text("4. Deja la celda vacía si no hay asignación.")
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
    
    // Generar plantilla estilo MATRIZ (Horizontal) corregida
    func prepareTemplateDownload() {
        // Generamos fechas para el mes actual y el siguiente como ejemplo (similar a tu archivo subido)
        let calendar = Calendar.current
        let today = Date()
        
        // Cabecera: Celda A1 vacía + Fechas
        var header = "," // Primera celda vacía
        
        // Generar 60 días desde hoy (aprox 2 meses)
        for i in 0..<60 {
            if let date = calendar.date(byAdding: .day, value: i, to: today) {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                let dateStr = formatter.string(from: date)
                header += "\(dateStr),"
            }
        }
        // Eliminar última coma y añadir salto de línea
        header = String(header.dropLast()) + "\n"
        
        // Cuerpo: Lista de personal + Celdas vacías
        var body = ""
        let staffList = plantManager.currentPlant?.allStaffList ?? []
        
        if staffList.isEmpty {
            // Ejemplo genérico si no hay personal cargado
            body += "Nombre Apellido,Mañana,Tarde,Noche,,,,,"
        } else {
            for person in staffList {
                // Nombre en primera columna, luego comas para dejar huecos vacíos para rellenar
                // Añadimos tantas comas como fechas generamos (60)
                let emptyCells = String(repeating: ",", count: 60)
                body += "\(person.name)\(emptyCells)\n"
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
            // Llamamos a la función de importación matricial en PlantManager
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
