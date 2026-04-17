# Directiva: Corrección de Pantalla Negra (Recursión en Logger)

## Versión: 1.0.0 | Última actualización: 2026-04-16

### Objetivo
Resolver el fallo crítico que causa una pantalla negra al iniciar la aplicación, causado por una recursión infinita en el sistema de logging.

### Contexto
Se detectó que en `lib/utils/logger.dart`, el método `log` utiliza la variable global `lvsLog` para imprimir en consola en modo debug. Dado que `lvsLog` es un alias de `Logger().log`, esto provoca una recursión infinita (Stack Overflow) al primer intento de logueo, que ocurre inmediatamente en `main.dart`.

### Pasos de Ejecución
1. **Modificar lib/utils/logger.dart:**
   - Localizar el método `log` dentro de la clase `Logger`.
   - Cambiar la llamada `lvsLog(entry.toString())` por `debugPrint(entry.toString())`.
   - Asegurar que `package:flutter/foundation.dart` esté importado (ya lo está para `kDebugMode`).
2. **Verificación de main.dart:**
   - Confirmar que la inicialización de servicios tiene los timeouts adecuados.
   - Verificar que no existan otras llamadas recursivas.
3. **Validación:**
   - Ejecutar `flutter analyze` para asegurar limpieza sintáctica.
   - Ejecutar un build de prueba si es posible (no requerido inmediatamente si la lógica es clara).

### Historial de Aprendizaje
- **2026-04-16:** El uso de alias globales (`tear-offs`) dentro de los mismos métodos que definen el alias puede causar recursión infinita si no se tiene cuidado. Siempre usar métodos base de Flutter (`debugPrint`) o de Dart (`print`) para el output de bajo nivel del logger.
