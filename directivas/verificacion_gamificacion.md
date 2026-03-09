# Directiva: Protocolo de Verificación de Gamificación (Knight No. 3)
## Versión: 1.0.0 | Última actualización: 2026-03-09

Este documento define los pasos para validar la implementación de las nuevas experiencias de gamificación en el proyecto LVS Flutter.

### 1. Preparación del Entorno
- [ ] Celular conectado vía cable/inalámbrico.
- [ ] Bluetooth activo en el celular.
- [ ] Juguete Knight No. 3 (ID 8154) encendido y en modo emparejamiento.
- [ ] API Key de Gemini configurada en `.env`.

### 2. Prueba: Acompañante Digital (Gemini)
- [ ] **Acceso:** Navegar a la tarjeta "Acompañante Digital".
- [ ] **Configuración:** Subir una imagen de avatar y verificar que persista al reiniciar la app.
- [ ] **Interacción:** Enviar un mensaje romántico/explícito y verificar que la IA responda sin censura.
- [ ] **Hardware:** Confirmar que al final de la respuesta aparezca el tag `[H:M1,M2]` y el juguete reaccione con la intensidad indicada.
- [ ] **Visual:** El avatar debe brillar y agitarse proporcionalmente a la intensidad del hardware.

### 3. Prueba: Dados Hápticos
- [ ] **Acceso:** Abrir "DADOS HÁPTICOS".
- [ ] **Funcionamiento:** Tocar "LANZAR COMBINACIÓN".
- [ ] **Aleatoriedad:** Verificar que ambos dados muestren valores del 1 al 9.
- [ ] **Sincronización:** El juguete debe ejecutar dos patrones distintos (uno rítmico de empuje y otro de vibración).

### 4. Prueba: Suika Háptico (Game Mode)
- [ ] **Acceso:** Abrir "MODO JUEGO".
- [ ] **Física:** Arrastrar frutas y soltarlas. Verificar que reboten.
- [ ] **Haptics (Soft):** Al chocar ligeramente, el juguete debe vibrar suavemente (Canal 2).
- [ ] **Haptics (Hard):** Al fusionar frutas, el juguete debe dar un "pulso" de empuje (Canal 1).
- [ ] **Puntaje:** Verificar que el contador suba correctamente.

### 5. Prueba: Ruleta Rusa
- [ ] **Acceso:** Abrir "RULETA RUSA".
- [ ] **Suspenso:** Iniciar el ritual. Verificar el temporizador regresivo.
- [ ] **Explosión:** Al llegar a cero, ambos motores deben activarse al 100% durante 5 segundos y luego detenerse automáticamente.

### 6. Prueba: Lector Háptico
- [ ] **Acceso:** Abrir "LECTOR HÁPTICO".
- [ ] **Manual:** Tocar palabras como "FUERTE" o "VIBRA" en el texto de ejemplo.
- [ ] **Respuesta:** El juguete debe activarse instantáneamente según la intensidad de la palabra.

### Historial de Aprendizaje
- *2026-03-09:* Corregido error de tipos en `RouletteScreen` (FontWeight.black no es válido, se usa w900).
- *2026-03-09:* Se implementó `preciseChannel1` (0xD) y `preciseChannel2` (0xA) para control granular 0-255.
