package com.example.turnoshospi.ui.theme

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.tooling.preview.Preview
import androidx.compose.ui.unit.dp

import com.example.turnoshospi.ui.theme.TurnoshospiTheme

val BrandBackground = Color(0xFF0F172A)
val BrandBackgroundVariant = Color(0xFF111827)
val BrandDeep = Color(0xFF0B1021)
val AccentBlue = Color(0xFF54C7EC)
val AccentPurple = Color(0xFFA855F7)
val AccentCyan = Color(0xFF22D3EE)

@Preview(showBackground = true, backgroundColor = 0xFF0F172A)
@Composable
fun ColorPalettePreview() {
    TurnoshospiTheme(darkTheme = true, dynamicColor = false) {
        Column(
            modifier = Modifier
                .background(BrandBackground)
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Text(text = "Paleta Turnoshospi", style = MaterialTheme.typography.titleMedium, color = Color.White)
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                PaletteSwatch("Fondo", BrandBackground)
                PaletteSwatch("Fondo alt", BrandBackgroundVariant)
                PaletteSwatch("Profundo", BrandDeep)
            }
            Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                PaletteSwatch("Azul", AccentBlue)
                PaletteSwatch("Púrpura", AccentPurple)
                PaletteSwatch("Cian", AccentCyan)
            }
        }
    }
}

@Composable
private fun PaletteSwatch(label: String, color: Color) {
    Card(colors = CardDefaults.cardColors(containerColor = color)) {
        Text(
            text = label,
            modifier = Modifier
                .padding(12.dp)
                .height(24.dp),
            color = Color.White,
            style = MaterialTheme.typography.bodyMedium
        )
    }
}

// Modelo de datos para los colores personalizables
data class ShiftColors(
    val morning: Color = Color(0xFFFFA500),      // Naranja
    val morningHalf: Color = Color(0xFFFFCC80),  // Naranja claro
    val afternoon: Color = Color(0xFF2196F3),    // Azul
    val afternoonHalf: Color = Color(0xFF40E0D0),// Turquesa
    val night: Color = Color(0xFF9C27B0),        // Violeta
    val saliente: Color = Color(0xFF1A237E),     // Azul oscuro
    val free: Color = Color(0xFF4CAF50),         // Verde
    val holiday: Color = Color(0xFFE91E63)       // Rosa
)