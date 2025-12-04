import SwiftUI

struct StatisticsView: View {
    var body: some View {
        VStack {
            Text("Estadísticas Mensuales")
                .font(.title2)
                .bold()
                .padding()
            
            HStack(spacing: 20) {
                StatCard(title: "Horas Trabajadas", value: "144h", color: .blue)
                StatCard(title: "Cambios Realizados", value: "2", color: .green)
            }
            .padding()
            
            Spacer()
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack {
            Text(value)
                .font(.largeTitle)
                .bold()
                .foregroundColor(.white)
            Text(title)
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color)
        .cornerRadius(12)
    }
}
