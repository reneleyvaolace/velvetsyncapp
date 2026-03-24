// ═══════════════════════════════════════════════════════════════
// Velvet Sync Platform · lib/velvet_sync_platform.dart
// Export unificado de toda la plataforma
// ═══════════════════════════════════════════════════════════════
//
// USO BÁSICO:
// ```dart
// import 'package:velvet_sync_platform/velvet_sync_platform.dart';
//
// // Core
// final device = DeviceInterface(...);
// await device.vibrate(0.75);
//
// // Devices
// final toy = ToyModel(id: '1001', ...);
//
// // Services
// final ble = BleService();
// await ble.connect(deviceId);
// ```
//
// ═══════════════════════════════════════════════════════════════

// ═══════════════════════════════════════════════════════════════
// CORE - Base tecnológica (100% reutilizable, sin dependencias UI)
// ═══════════════════════════════════════════════════════════════

// Types
export 'core/types/device_types.dart';
export 'core/types/command_types.dart';
export 'core/types/event_types.dart';
export 'core/types/result_types.dart';

// HAL - Hardware Abstraction Layer
export 'core/hal/device_interface.dart';
export 'core/hal/connection_manager.dart';
export 'core/hal/command_queue.dart' hide QueueCommandQueuedEvent, QueueCommandExecutingEvent, QueueCommandCompletedEvent, QueueCommandFailedEvent;
export 'core/hal/protocol_adapter.dart';

// Protocols
export 'core/protocols/protocol_base.dart';
export 'core/protocols/lvs_protocol.dart';

// Config
export 'core/config/device_config.dart';
export 'core/config/device_config_loader.dart';
export 'core/config/buttplug_config_loader.dart';

// ═══════════════════════════════════════════════════════════════
// DEVICES - Modelos y parsers de dispositivos
// ═══════════════════════════════════════════════════════════════

// Models
export 'devices/models/toy_model.dart';
export 'devices/models/lovespouse_device.dart';
export 'devices/models/buttplug_devices.dart' hide ConnectionType;
export 'devices/models/device_sync_model.dart';
export 'devices/models/session_models.dart';
export 'devices/models/funscript.dart';
export 'devices/models/game_profile.dart';

// Parsers

// ═══════════════════════════════════════════════════════════════
// SERVICES - Servicios de negocio (en implementación)
// ═══════════════════════════════════════════════════════════════

// BLE Service
export 'services/ble/ble_service_platform.dart' hide getBleService;
export 'services/ble/ble_service_mobile.dart';
export 'services/ble/lvs_commands.dart' hide PacketMode;
export 'services/ble/toy_profile.dart';

// Buttplug Service

// Catalog Service
export 'services/catalog/catalog_service.dart';

// ═══════════════════════════════════════════════════════════════
// UTILS - Utilidades generales
// ═══════════════════════════════════════════════════════════════

export 'utils/logger.dart' hide LogEntry;
export 'utils/cache_manager.dart';
export 'utils/protocol_translator.dart';
export 'utils/snack_helper.dart';

// ═══════════════════════════════════════════════════════════════
// NOTA: UI y servicios avanzados están en desarrollo
// Para usar la base tecnológica, importa los módulos específicos:
// - velvet_sync_core.dart (Core)
// - velvet_sync_devices.dart (Dispositivos)
// - velvet_sync_services.dart (Servicios)
// ═══════════════════════════════════════════════════════════════
