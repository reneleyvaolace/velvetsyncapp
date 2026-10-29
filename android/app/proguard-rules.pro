# ═══════════════════════════════════════════════════════════════
# Velvet Sync · proguard-rules.pro
# Reglas de optimización R8 / ProGuard
# ════════════════════════════════════════════════════════════════

# ════════════════════════════════════════════════════════════════
# Mantener modelos de datos (serialización JSON)
# ═══════════════════════════════════════════════════════════════
-keep class com.velvetsync.devices.models.** { *; }
-keep class com.velvetsync.devices.models.**$* { *; }
-keep class com.velvetsync.devices.models.lovespouse_device.** { *; }
-keep class com.velvetsync.devices.models.toy_model.** { *; }
-keep class com.velvetsync.devices.models.toy_model.* { *; }

# ════════════════════════════════════════════════════════════════
# Servicios BLE y Protocolos
# ═══════════════════════════════════════════════════════════════
-keep class com.velvetsync.services.ble.** { *; }
-keep class com.velvetsync.services.ble.**$* { *; }
-keep class com.velvetsync.services.ble.lovespouse_protocol.** { *; }
-keep class com.velvetsync.services.ble.lvs_commands.** { *; }
-keep class com.velvetsync.services.ble.ble_protocol.** { *; }
-keep class com.velvetsync.services.ble.ipao_protocol.** { *; }
-keep class com.velvetsync.services.ble.crypt_ble.** { *; }
-keep class com.velvetsync.services.ble.toy_profile.** { *; }

# ════════════════════════════════════════════════════════════════
# Servicios de Catálogo y Parsers
# ═══════════════════════════════════════════════════════════════
-keep class com.velvetsync.services.catalog.** { *; }
-keep class com.velvetsync.devices.parsers.lovespouse_parser_service.** { *; }
-keep class com.velvetsync.services.catalog.catalog_service.** { *; }

# ════════════════════════════════════════════════════════════════
# Servicios de Media (Video, Audio, Voice)
# ═══════════════════════════════════════════════════════════════
-keep class com.velvetsync.services.media.** { *; }

# ════════════════════════════════════════════════════════════════
# Servicios Backend (Supabase, Auth, Sync)
# ═══════════════════════════════════════════════════════════════
-keep class com.velvetsync.services.backend.** { *; }
-keep class com.velvetsync.services.backend.sync_service.** { *; }
-keep class com.velvetsync.services.backend.auth_service.** { *; }
-keep class com.velvetsync.services.backend.profile_service.** { *; }
-keep class com.velvetsync.services.backend.supabase_service.** { *; }

# ════════════════════════════════════════════════════════════════
# Servicios AI y Game Mode
# ═══════════════════════════════════════════════════════════════
-keep class com.velvetsync.services.ai.** { *; }
-keep class com.velvetsync.services.game.** { *; }
-keep class com.velvetsync.services.game.game_mode_service.** { *; }

# ════════════════════════════════════════════════════════════════
# Riverpod / State Management
# ═══════════════════════════════════════════════════════════════
-keep class com.riverpod.** { *; }
-keep class io.flutter.plugins.riverpod.** { *; }
-keep class io.flutter.plugins.riverpod.** { *; }

# ════════════════════════════════════════════════════════════════
# Supabase / Realtime / Postgrest
# ═══════════════════════════════════════════════════════════════
-keep class io.supabase.** { *; }
-keep class io.supabase.flutter.** { *; }
-keep class org.postgresql.** { *; }

# ════════════════════════════════════════════════════════════════
# Play Core / Play Core Split Compat (para deferred components de Flutter)
# ════════════════════════════════════════════════════════════════
# Keep all Play Core classes
-keep class com.google.android.play.core.** { *; }

# No warn for missing classes (referenciados por Flutter engine)
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.SplitInstallException
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManager
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManagerFactory
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest$Builder
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest
-dontwarn com.google.android.play.core.splitinstall.SplitInstallSessionState
-dontwarn com.google.android.play.core.splitinstall.SplitInstallStateUpdatedListener
-dontwarn com.google.android.play.core.tasks.OnFailureListener
-dontwarn com.google.android.play.core.tasks.OnSuccessListener
-dontwarn com.google.android.play.core.tasks.Task

# ════════════════════════════════════════════════════════════════
# Flutter Engine / Engine Plugins
# ═══════════════════════════════════════════════════════════════
-keep class io.flutter.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.embedding.engine.** { *; }
-keep class io.flutter.plugins.** { *; }

# ════════════════════════════════════════════════════════════════
# JSON Serialization (json_annotation, freezed, etc.)
# ═══════════════════════════════════════════════════════════════
-keep class * implements com.google.gson.JsonSerializer { *; }
-keep class * implements com.google.gson.JsonDeserializer { *; }
-keep class * implements com.google.gson.JsonSerializer { *; }
-keep class * implements com.google.gson.JsonDeserializer { *; }
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName *;
}

# ════════════════════════════════════════════════════════════════
# Kotlin / Coroutines / Coroutines Flow
# ═══════════════════════════════════════════════════════════════
-keep class kotlinx.coroutines.** { *; }
-keep class kotlinx.coroutines.flow.** { *; }
-keep class kotlin.coroutines.** { *; }
-keep class kotlin.coroutines.jvm.internal.** { *; }

# ════════════════════════════════════════════════════════════════
# Exoplayer / Media
# ═══════════════════════════════════════════════════════════════
-keep class com.google.android.exoplayer2.** { *; }
-keep class com.google.android.exoplayer2.ui.** { *; }

# ════════════════════════════════════════════════════════════════
# Supabase Realtime / WebSocket
# ═══════════════════════════════════════════════════════════════
-keep class org.java_websocket.** { *; }
-keep class io.socket.** { *; }

# ════════════════════════════════════════════════════════════════
# Evitar ofuscación de nombres de recursos (R8)
# ════════════════════════════════════════════════════════════════
-keepclassmembers class * {
    @androidx.annotation.Keep *;
    @androidx.annotation.NonNull *;
    @androidx.annotation.Nullable *;
}

# ════════════════════════════════════════════════════════════════
# Evitar warnings de reflexión en Kotlin
# ═══════════════════════════════════════════════════════════════
-keepclassmembers class * {
    @kotlin.Metadata *;
}

# ════════════════════════════════════════════════════════════════
# Evitar que R8 elimine clases usadas solo por reflexión
# ═══════════════════════════════════════════════════════════════
-keep class * {
    *** ...;
}