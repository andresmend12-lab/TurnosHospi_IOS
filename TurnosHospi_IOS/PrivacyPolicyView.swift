import SwiftUI

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            Color.deepSpace.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white.opacity(0.6))
                    }
                    Spacer()
                    Text("Política de Privacidad")
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.clear)
                }
                .padding()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {

                        // Última actualización
                        Text("Última actualización: Enero 2025")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.5))

                        // Introducción
                        PolicySection(
                            title: "1. Introducción",
                            content: """
                            Bienvenido a Shift Manager ("la App"). Esta política de privacidad describe cómo recopilamos, usamos y protegemos tu información personal cuando utilizas nuestra aplicación de gestión de turnos hospitalarios.

                            Al usar la App, aceptas las prácticas descritas en esta política.
                            """
                        )

                        // Información que recopilamos
                        PolicySection(
                            title: "2. Información que Recopilamos",
                            content: """
                            Recopilamos la siguiente información:

                            • Información de cuenta: nombre, apellido, correo electrónico, género (opcional) y rol profesional (opcional).

                            • Información laboral: turnos asignados, cambios de turno, días de vacaciones y asociación con plantas/unidades hospitalarias.

                            • Comunicaciones: mensajes enviados a través del chat de la aplicación.

                            • Información técnica: tokens de notificaciones push para enviarte alertas relevantes.
                            """
                        )

                        // Cómo usamos la información
                        PolicySection(
                            title: "3. Uso de la Información",
                            content: """
                            Utilizamos tu información para:

                            • Gestionar tu cuenta y autenticación.
                            • Mostrar y gestionar tus turnos de trabajo.
                            • Facilitar cambios de turno entre compañeros.
                            • Enviar notificaciones sobre cambios de turno, mensajes y aprobaciones.
                            • Permitir la comunicación con tu equipo de trabajo.
                            • Generar estadísticas de horas trabajadas.
                            """
                        )

                        // Almacenamiento
                        PolicySection(
                            title: "4. Almacenamiento de Datos",
                            content: """
                            Tus datos se almacenan de forma segura en Firebase, un servicio de Google Cloud Platform que cumple con estándares de seguridad internacionales.

                            Los datos se transmiten mediante conexiones cifradas (HTTPS/TLS).
                            """
                        )

                        // Compartir información
                        PolicySection(
                            title: "5. Compartir Información",
                            content: """
                            Tu información puede ser visible para:

                            • Supervisores de tu planta: pueden ver tu calendario de turnos y gestionar asignaciones.

                            • Compañeros de planta: pueden ver tu nombre y rol para facilitar cambios de turno y comunicación.

                            No vendemos ni compartimos tu información con terceros para fines publicitarios.
                            """
                        )

                        // Derechos del usuario
                        PolicySection(
                            title: "6. Tus Derechos",
                            content: """
                            Tienes derecho a:

                            • Acceder a tus datos personales.
                            • Modificar tu información de perfil.
                            • Eliminar tu cuenta y todos los datos asociados desde la configuración de la app.
                            • Solicitar una copia de tus datos.

                            Para ejercer estos derechos, puedes usar las opciones en la app o contactarnos directamente.
                            """
                        )

                        // Notificaciones
                        PolicySection(
                            title: "7. Notificaciones Push",
                            content: """
                            Si autorizas las notificaciones, te enviaremos alertas sobre:

                            • Nuevas solicitudes de cambio de turno.
                            • Mensajes de compañeros.
                            • Aprobaciones o rechazos de supervisores.

                            Puedes desactivar las notificaciones en cualquier momento desde la configuración de tu dispositivo.
                            """
                        )

                        // Retención de datos
                        PolicySection(
                            title: "8. Retención de Datos",
                            content: """
                            Conservamos tus datos mientras mantengas una cuenta activa. Si eliminas tu cuenta, tus datos personales serán eliminados permanentemente.

                            Algunos datos agregados y anónimos pueden conservarse para análisis estadísticos.
                            """
                        )

                        // Seguridad
                        PolicySection(
                            title: "9. Seguridad",
                            content: """
                            Implementamos medidas de seguridad para proteger tu información:

                            • Autenticación segura mediante Firebase Auth.
                            • Transmisión cifrada de datos.
                            • Acceso restringido a bases de datos.
                            • Contraseñas nunca almacenadas en texto plano.
                            """
                        )

                        // Menores de edad
                        PolicySection(
                            title: "10. Menores de Edad",
                            content: """
                            Esta aplicación está diseñada para profesionales de la salud adultos. No recopilamos intencionalmente información de menores de 18 años.
                            """
                        )

                        // Cambios en la política
                        PolicySection(
                            title: "11. Cambios en esta Política",
                            content: """
                            Podemos actualizar esta política ocasionalmente. Te notificaremos sobre cambios significativos a través de la aplicación o por correo electrónico.
                            """
                        )

                        // Contacto
                        PolicySection(
                            title: "12. Contacto",
                            content: """
                            Si tienes preguntas sobre esta política de privacidad, puedes contactarnos en:

                            Email: soporte@shiftmanager.app
                            """
                        )

                        Spacer(minLength: 50)
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
}

struct PolicySection: View {
    let title: String
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .foregroundColor(.white)

            Text(content)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
                .lineSpacing(4)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }
}

// Vista de Términos de Servicio
struct TermsOfServiceView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            Color.deepSpace.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white.opacity(0.6))
                    }
                    Spacer()
                    Text("Términos de Servicio")
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.clear)
                }
                .padding()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {

                        Text("Última actualización: Enero 2025")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.5))

                        PolicySection(
                            title: "1. Aceptación de los Términos",
                            content: """
                            Al crear una cuenta y usar Shift Manager, aceptas estos términos de servicio. Si no estás de acuerdo, no debes usar la aplicación.
                            """
                        )

                        PolicySection(
                            title: "2. Descripción del Servicio",
                            content: """
                            Shift Manager es una aplicación de gestión de turnos para personal sanitario que permite:

                            • Visualizar y gestionar turnos de trabajo.
                            • Solicitar y aprobar cambios de turno.
                            • Comunicarse con compañeros de trabajo.
                            • Gestionar días de vacaciones.
                            """
                        )

                        PolicySection(
                            title: "3. Registro y Cuenta",
                            content: """
                            • Debes proporcionar información veraz y actualizada.
                            • Eres responsable de mantener la confidencialidad de tu contraseña.
                            • Debes notificar cualquier uso no autorizado de tu cuenta.
                            • Una cuenta por persona; no compartir credenciales.
                            """
                        )

                        PolicySection(
                            title: "4. Uso Aceptable",
                            content: """
                            Te comprometes a:

                            • Usar la app solo para fines profesionales legítimos.
                            • No compartir información confidencial de pacientes.
                            • Respetar a otros usuarios en las comunicaciones.
                            • No intentar acceder a datos de otros usuarios sin autorización.
                            • No usar la app para actividades ilegales.
                            """
                        )

                        PolicySection(
                            title: "5. Contenido del Usuario",
                            content: """
                            Eres responsable del contenido que compartes en la aplicación, incluyendo mensajes y notas. No debes compartir:

                            • Información médica confidencial de pacientes.
                            • Contenido ofensivo, discriminatorio o ilegal.
                            • Spam o publicidad no solicitada.
                            """
                        )

                        PolicySection(
                            title: "6. Propiedad Intelectual",
                            content: """
                            La aplicación, su diseño, código y contenido son propiedad de Shift Manager. No puedes copiar, modificar o distribuir la aplicación sin autorización.
                            """
                        )

                        PolicySection(
                            title: "7. Disponibilidad del Servicio",
                            content: """
                            Nos esforzamos por mantener el servicio disponible, pero no garantizamos disponibilidad ininterrumpida. Podemos realizar mantenimientos o actualizaciones que afecten temporalmente el servicio.
                            """
                        )

                        PolicySection(
                            title: "8. Limitación de Responsabilidad",
                            content: """
                            La app es una herramienta de apoyo. Las decisiones sobre turnos y personal son responsabilidad de tu institución. No somos responsables de:

                            • Errores en la asignación de turnos.
                            • Pérdida de datos por fallos técnicos.
                            • Conflictos laborales derivados del uso de la app.
                            """
                        )

                        PolicySection(
                            title: "9. Terminación",
                            content: """
                            Puedes eliminar tu cuenta en cualquier momento. Nos reservamos el derecho de suspender cuentas que violen estos términos.
                            """
                        )

                        PolicySection(
                            title: "10. Modificaciones",
                            content: """
                            Podemos modificar estos términos. Los cambios significativos serán notificados a través de la app.
                            """
                        )

                        PolicySection(
                            title: "11. Contacto",
                            content: """
                            Para consultas sobre estos términos:

                            Email: legal@shiftmanager.app
                            """
                        )

                        Spacer(minLength: 50)
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
}

#Preview("Privacy") {
    PrivacyPolicyView()
}

#Preview("Terms") {
    TermsOfServiceView()
}
