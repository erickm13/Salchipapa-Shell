pragma Singleton
// Configuración global de la shell, compartida por todos los diseños.
import Quickshell

Singleton {
    // Diseño de barra activo. Hoy: "island". Futuros: "classic", "minimal", ...
    // Cambiar aquí y la shell recarga sola.
    property string design: "island"

    // Separación de la barra respecto al borde superior
    property int topMargin: 6
}
