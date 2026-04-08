# Directiva: Sistema de Diseño Velvet UI (Master)
## Versión: 1.0.0 | Última actualización: 2026-04-07

Esta directiva define los estándares visuales y de interacción para la aplicación Velvet Sync. Cualquier desarrollo en Flutter debe adherirse estrictamente a estos parámetros para mantener la fidelidad de marca.

---

## 1. Fundamentos Visuales (Design Tokens)

### 1.1 Paleta de Colores
- **Fondo Primario:** `#0D0D12` (Deep Black / Dark Navy).
- **Acento Canal 1 (Empuje):** `#FF006E` (Vivid Raspberry).
- **Acento Canal 2 (Vibración):** `#00F5FF` (Electric Cyan).
- **Gradiente de Acción:** `linear-gradient(90deg, #FF006E 0%, #8338EC 100%)`.
- **Alertas/Emergencia:** `#FF4D4D` (Neon Red).
- **Textos Técnicos/Logs:** `#FFD700` (Gold) y `#00FFCC` (Mint).

### 1.2 Tipografía
- **Títulos de Marca:** Serif elegante (ej. Playfair Display o similar en Flutter) con color blanco puro.
- **UI / Navegación:** Sans-serif moderna (Inter o Roboto).
- **Datos Técnicos:** Monoespaciada para la Consola de Depuración.

### 1.3 Estilo de Componentes
- **Border Radius:** Estándar de `24px` para tarjetas principales, `12px` para botones y controles.
- **Glassmorphism:** Uso de `BackdropFilter` con blur de `10px` y opacidad de fondo del 10-15% para modales.
- **Glow Effects:** Los elementos activos deben proyectar un "subtle glow" del color de su categoría (opacity: 0.3, blur: 8px).

---

## 2. Lógica de Interacción

- **Dualidad de Canal:** La interfaz debe reflejar visualmente qué canal se está controlando. Rosa para CH1, Cian para CH2.
- **Retroalimentación Tactil:** Cada interacción con un botón de patrón debe disparar una vibración corta (HapticFeedback.lightImpact).
- **Seguridad:** El botón de "Emergency Stop" debe estar accesible en todas las pantallas de control activo.

---

## 3. Historial de Aprendizaje (Trampas Conocidas)

- **[2026-04-07] Corrección de Texto:** Se detectó una errata en el modal de compartir acceso ("pajera"). **REGLA:** Validar siempre que el texto sea "pareja".
- **[2026-04-07] rMesh v2:** El indicador de conexión debe mostrar siempre la batería y la calidad de señal cuando esté "Online".
- **[2026-04-07] Performance:** Las animaciones de los iconos de cristal (glassmorphism) pueden afectar el framerate en dispositivos de gama baja. Usar animaciones simplificadas si el dispositivo no soporta blur avanzado.

---

## 4. Estándares de Implementación (Flutter)
- Los widgets de modo deben ser independientes y reutilizables (`lib/widgets/lvs_mode_card.dart`).
- Se debe usar un `ThemeData` personalizado que maneje los colores `primaryColor` (Fucsia) y `secondaryHeaderColor` (Cian).
