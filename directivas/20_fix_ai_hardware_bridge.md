## Versión: 1.0.0 | Última actualización: 2026-06-28

# Directiva: Fix AI Hardware Bridge
# Objetivo
Corregir las vulnerabilidades lógicas en `lib/services/ai/ai_hardware_bridge_service.dart`.

# Cambios
1. **Evitar concurrencia**: Retornar si `_isExecuting` ya está en true cuando entra un nuevo evento de IA.
2. **Validar Dual Channel**: El guard de seguridad ahora revisa tanto CH1 como CH2 si es dual channel.
3. **Aplicar Ajuste de Guard**: El `adjustedIntensity` devuelto por `_preciseControlGuard` ahora se aplica al mapa de intensidades antes de pasarlo a `_executeSingleChannel` o `_executeDualChannel`.

# Historial de Aprendizaje
- Nota: No pasar `intensityMap` original sin aplicar el `adjustedIntensity` del Guard, porque anula la seguridad y manda intensidades fuera de rango (>100) en dispositivos que no soportan control preciso. En su lugar, mutar o crear un nuevo mapa de intensidad aplicando el `adjustedIntensity`.
- Nota: No llamar rutinas asíncronas de ejecución BLE en paralelo desde eventos AI sin verificar el estado de ejecución, porque causa saturación y "Race Conditions". En su lugar, descartar el evento si ya estamos ejecutando otro comando de IA (`_isExecuting == true`).
