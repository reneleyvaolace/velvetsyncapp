// ═══════════════════════════════════════════════════════════════
// Velvet Sync Platform · lib/velvet_sync_core.dart
// Export del CORE de la plataforma (100% reutilizable, sin UI)
// ═══════════════════════════════════════════════════════════════
//
// USO:
// ```dart
// import 'package:velvet_sync_platform/velvet_sync_core.dart';
//
// // Solo el core, sin dependencias de Flutter
// final device = DeviceInterface(...);
// ```
// ═══════════════════════════════════════════════════════════════

// Types
export 'types/device_types.dart';
export 'types/command_types.dart';
export 'types/event_types.dart';
export 'types/result_types.dart';

// HAL - Hardware Abstraction Layer
export 'core/hal/device_interface.dart';
export 'core/hal/connection_manager.dart';
export 'core/hal/command_queue.dart';
export 'core/hal/protocol_adapter.dart';

// Protocols
export 'core/protocols/protocol_base.dart';
export 'core/protocols/lvs_protocol.dart';

// Config
export 'core/config/device_config.dart';
export 'core/config/device_config_loader.dart';
export 'core/config/buttplug_config_loader.dart';

// Platform Info (sin Flutter)
