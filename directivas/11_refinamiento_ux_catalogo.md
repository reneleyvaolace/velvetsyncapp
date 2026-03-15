## Versión: 1.1.0 | Última actualización: 2026-03-10
# Directiva: Refinamiento de UX y Catálogo

## Objetivos
1. Priorizar el flujo de conexión virtual mediante el catálogo de dispositivos.
2. Asegurar la persistencia de nombres personalizados y metadatos de usuario.
3. Optimizar la interfaz del Panel de Control (Dashboard) para una mejor visualización de identidad y seguridad.

## Lógica y Pasos
1. **Catálogo de Usuario (Mis Dispositivos)**:
   - Debe iniciar vacío. No se muestran dispositivos hardcoded en la lista principal.
   - Solo se registran dispositivos cuando el usuario los agrega mediante ID o QR.
   - Cualquier edición (Renombrado) debe promocionar el dispositivo del catálogo general a la lista de pre-registrados y persistirse en el almacenamiento seguro.
2. **Dashboard (ControlTab)**:
   - Mostrar la imagen del juguete en la parte superior del panel de control para confirmar la identidad del dispositivo conectado.
   - El botón de **ALTO (Stop de Emergencia)** debe ser el elemento más accesible, ubicado debajo de los presets de intensidad.
   - Etiquetas de intensidad en español: BAJO, MED, ALTO.
3. **Modos de Juego (ModesTab)**:
   - Desbloquear Canvas y Ritmos dinámicamente al detectar cualquier conexión (GATT o Virtual).
   - Utilizar el proveedor reactivo `ref.watch(bleProvider)` para asegurar que la UI responda a cambios de estado de conexión.
4. **Desuso del Escaneo Tradicional**:
   - Ocultar botones de escaneo BLE manual en favor del escaneo QR o ingreso de ID por catálogo para cumplir con el modelo de "Sin Scan".

## Restricciones / Historial de Aprendizaje
- **Nota**: El sistema de `StateNotifier` en `CatalogService` debe usar `_preregisteredList` como fuente única del `state` para evitar que dispositivos temporales del catálogo general aparezcan en "Mis Dispositivos".
- **Nota**: La actualización de nombres fallaba porque solo afectaba al `state` volátil; ahora se fuerza la actualización en `FlutterSecureStorage` en cada cambio.
- **Nota**: `ref.read` en el método `build` de una pestaña impedía que los modos se desbloquearan automáticamente al cambiar el estado del servicio BLE. Usar siempre `ref.watch`.
- **Nota**: El catálogo de productos en el Dashboard ahora actúa como una **pasarela (Gateway)** al catálogo web externo. No vincula dispositivos localmente desde el scroll horizontal para evitar saturación de registros accidentales.
- **Restricción de URL**: La URL del catálogo web (`kWebCatalogUrl`) es volátil y será un subdominio de Vercel en el futuro cercano. Mantenerla centralizada en `catalog_service.dart`.

## Skills Relacionadas
- Flutter + Riverpod
- FlutterSecureStorage (Cifrado)
- Supabase Realtime/Database
- Mobile Scanner (QR)
