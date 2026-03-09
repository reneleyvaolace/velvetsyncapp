## Versión: 1.0.0 | Última actualización: 2026-03-06

# Directiva: Experiencia de Acompañante Digital Discreto (Modelo Knight No. 3 - ID 8154)

## Objetivo
Transformar la aplicación en una experiencia interactiva discreta utilizando capacidades generativas (Gemini 2.0 Flash) combinadas con comandos BLE para el dispositivo Knight No. 3 (Motor 1: 0xD, Motor 2: 0xA), e integrar varios modos de gamificación háptica: Dados, Suika Háptico, Ruleta Rusa y Lector Háptico.

## 1. Integración de IA (Experiencia Principal)
- **Tecnología**: Paquete `google_generative_ai`.
- **Restricción de Seguridad Crítica**: `HarmCategory.HARM_CATEGORY_SEXUALLY_EXPLICIT` debe estar en `HarmBlockThreshold.BLOCK_NONE`.
- **Instrucción de Sistema**: La IA debe finalizar cada respuesta con la etiqueta `[H:M1,M2]` donde `M1` (Motor 1 - Empuje - 0xD) y `M2` (Motor 2 - Vibración - 0xA) son valores entre 0 y 255.
- **Parser**: Expresión regular `\[H:(\d+),(\d+)\]` para extraer intensidades y eliminarlas del texto antes de mostrarlo al usuario en pantalla.
- **Hardware**: Enviar el flujo BLE al dispositivo cada 250ms usando `ble_service`. Al interrumpirse o salir del chat, se debe despachar el comando de bloqueo absoluto: `0x6DB643CE97FE427C` concatenado con `0xE5157D` (11 bytes total).

## 2. Avatar Personalizable y Feedback Visual
- **Configuración**: `image_picker` para cargar imagen desde galería.
- **Persistencia**: `shared_preferences` para almacenar y cargar la ruta local de la imagen.
- **Animación (Shake/Glow)**: Envolver en `AnimatedBuilder`. La amplitud de vibración visual en píxeles debe ser un cálculo proporcional a los motores: `(M1 + M2) / 510 * Shake_Max_Pixels`. A 255 en ambos canales, vibración máxima.

## 3. Dados de Patrones Combinados
- **Lógica**: Generación de números aleatorios `(1, 9)` para M1 (modo constante) y `(1, 9)` para M2 (modo rítmico).
- **Control**: Combinación de `0xD` (motor 1) y `0xA` (motor 2) enviados simultáneamente mediante la función dual-channel de Fastcon.

## 4. Suika Háptico (Rompecabezas de Frutas)
- **Lógica**: Uso del paquete `flame` para simular colisiones.
- **Calculadora**: En `CollisionCallback`, al fusionar frutas del tamaño `S`, la intensidad al Motor 1 será: `Intensidad = S * Multiplicador` acotada a 255.
- **Carga**: Solo motor `0xD` (Empuje).

## 5. Ruleta Rusa de Sensaciones
- **Lógica**: Un generador de números aleatorios dispara eventos `Timer.periodic`.
- **Calculadora**: El Timer se programa con `Random().nextInt(30000) + 15000` (15 a 45 segundos).
- **Intensidad**: Asignación aleatoria entre 10 y 255.

## 6. Lector Háptico
- **Lógica**: Parseo de `.txt` o `.epub`.
- **Calculadora**: Detección de palabras clave durante el desplazamiento (ScrollController listener).
   - "Fuerte", "Golpe", "Acción" -> Enviar a `0xD`.
   - "Suave", "Caricia", "Lento" -> Enviar a `0xA`.

## Historial de Aprendizaje
- TBD
