// ═══════════════════════════════════════════════════════════════
// LVS Control · android/app/src/main/kotlin/.../MainActivity.kt
// Actividad principal — Flutter + FlutterForegroundTask compat.
// ═══════════════════════════════════════════════════════════════
package com.lvs.control

import com.pravera.flutter_foreground_task.FlutterForegroundTaskPlugin
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Registrar el plugin de ForegroundTask para garantizar
        // que el canal de comunicación esté disponible
        FlutterForegroundTaskPlugin.registerWith(
            flutterEngine.dartExecutor.binaryMessenger
        )
    }
}
