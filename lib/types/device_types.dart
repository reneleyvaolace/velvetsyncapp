// ═══════════════════════════════════════════════════════════════
// Velvet Sync Platform · lib/core/types/device_types.dart
// Tipos y enumeraciones para dispositivos
// ═══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';

/// Tipos de dispositivo según anatomía y uso
enum DeviceType {
  /// Vibrador universal
  vibrator,
  
  /// Huevo vibrador
  egg,
  
  /// Bala vibradora
  bullet,
  
  /// Anillo vibrador
  ring,
  
  /// Estimulador clitoriano
  clitoral,
  
  /// Estimulador de próstata
  prostate,
  
  /// Estimulador anal
  anal,
  
  /// Estimulador peneano
  penis,
  
  /// Estimulador de pezones
  nipple,
  
  /// Dispositivo de electroestimulación
  ems,
  
  /// Dispositivo de succión
  suction,
  
  /// Dispositivo de embestida (thrusting)
  thrusting,
  
  /// Dispositivo de rotación
  rotating,
  
  /// Dispositivo multifunción
  multi,
  
  /// Ejercitador Kegel
  kegel,
  
  /// Tipo desconocido o personalizado
  unknown,
}

/// Tipo de conexión del dispositivo
enum ConnectionType {
  /// Bluetooth Low Energy (BLE)
  ble,
  
  /// Bluetooth Classic
  bluetoothClassic,
  
  /// USB cable
  usb,
  
  /// Serial/UART
  serial,
  
  /// WiFi
  wifi,
  
  /// Conexión virtual (sin hardware)
  virtual,
}

/// Estado de la conexión
enum ConnectionStatus {
  /// Desconectado
  disconnected,
  
  /// Conectando
  connecting,
  
  /// Conectado
  connected,
  
  /// Desconectando
  disconnecting,
  
  /// Error en la conexión
  error,
}

/// Estado del dispositivo
enum DeviceStatus {
  /// Disponible
  available,
  
  /// En uso
  inUse,
  
  /// No disponible
  unavailable,
  
  /// En modo emparejamiento
  pairing,
  
  /// Batería baja
  lowBattery,
}

/// Features/capacidades del dispositivo
enum DeviceFeature {
  /// Vibración
  vibrate,
  
  /// Rotación
  rotate,
  
  /// Oscilación
  oscillate,
  
  /// Embestida (thrusting)
  thrust,
  
  /// Succión
  suction,
  
  /// Estimulación eléctrica (EMS/TENS)
  ems,
  
  /// Calentamiento
  heat,
  
  /// Iluminación LED
  light,
  
  /// Sonido
  sound,
  
  /// Sensor de batería
  battery,
  
  /// Sensor de fuerza/presión
  pressure,
  
  /// Sensor de temperatura
  temperature,
  
  /// Acelerómetro
  accelerometer,
  
  /// Giroscopio
  gyroscope,
}

/// Nivel de precisión del control
enum ControlPrecision {
  /// Básico (Stop/Low/Medium/High)
  basic,
  
  /// Proporcional (0-100)
  proportional,
  
  /// Preciso (0-255)
  precise,
}

/// Canal del dispositivo (para dispositivos dual-channel)
enum DeviceChannel {
  /// Canal único
  single,
  
  /// Canal 1 (izquierdo/primario)
  channel1,
  
  /// Canal 2 (derecho/secundario)
  channel2,
  
  /// Ambos canales sincronizados
  both,
}

/// Extensión para obtener descripción legible
extension DeviceTypeExtension on DeviceType {
  String get displayName {
    switch (this) {
      case DeviceType.vibrator: return 'Vibrador';
      case DeviceType.egg: return 'Huevo';
      case DeviceType.bullet: return 'Bala';
      case DeviceType.ring: return 'Anillo';
      case DeviceType.clitoral: return 'Estimulador Clitoriano';
      case DeviceType.prostate: return 'Estimulador de Próstata';
      case DeviceType.anal: return 'Estimulador Anal';
      case DeviceType.penis: return 'Estimulador Peneano';
      case DeviceType.nipple: return 'Estimulador de Pezones';
      case DeviceType.ems: return 'Electroestimulador';
      case DeviceType.suction: return 'Estimulador de Succión';
      case DeviceType.thrusting: return 'Dispositivo de Embestida';
      case DeviceType.rotating: return 'Dispositivo de Rotación';
      case DeviceType.multi:
      case DeviceType.kegel: return 'Multifunción';
      case DeviceType.unknown: return 'Desconocido';
    }
  }
  String get iconAsset {
    switch (this) {
      case DeviceType.vibrator: return 'assets/icons/icon_vibrator.png';
      case DeviceType.egg: return 'assets/icons_icon_egg.png';
      case DeviceType.bullet: return 'assets/icons/icon_bullet.png';
      case DeviceType.ring: return 'assets/icons/icon_ring.png';
      case DeviceType.clitoral: return 'assets/icons/icon_clitoral.png';
      case DeviceType.prostate: return 'assets/icons_icon_prostate.png';
      case DeviceType.anal: return 'assets/icons_icon_anal.png';
      case DeviceType.penis: return 'assets/icons_icon_male_anatomy.png';
      case DeviceType.ems: return 'assets/icons_icon_ems.png';
      case DeviceType.suction: return 'assets/icons_icon_suction.png';
      case DeviceType.thrusting: return 'assets/icons_icon_thrust.png';
      case DeviceType.rotating: return 'assets/icons_icon_rotate.png';
      case DeviceType.multi:
      case DeviceType.kegel: return 'assets/icons_icon_dual_motor.png';
      default: return 'assets/icons_icon_vibrator.png';
    }
  }

  IconData get materialIcon {
    switch (this) {
      case DeviceType.vibrator: return Icons.vibration;
      case DeviceType.egg: return Icons.egg;
      case DeviceType.bullet: return Icons.rocket_launch;
      case DeviceType.ring: return Icons.donut_large;
      case DeviceType.clitoral: return Icons.flare;
      case DeviceType.prostate: return Icons.gamepad;
      case DeviceType.anal: return Icons.adjust;
      case DeviceType.penis: return Icons.water_drop;
      case DeviceType.ems: return Icons.bolt;
      case DeviceType.suction: return Icons.cyclone;
      case DeviceType.thrusting: return Icons.unfold_more;
      case DeviceType.rotating: return Icons.sync_rounded;
      case DeviceType.multi: return Icons.hub;
      case DeviceType.kegel: return Icons.spa;
      default: return Icons.vibration;
    }
  }
}

extension DeviceFeatureExtension on DeviceFeature {
  String get displayName {
    switch (this) {
      case DeviceFeature.vibrate: return 'Vibración';
      case DeviceFeature.rotate: return 'Rotación';
      case DeviceFeature.oscillate: return 'Oscilación';
      case DeviceFeature.thrust: return 'Embestida';
      case DeviceFeature.suction: return 'Succión';
      case DeviceFeature.ems: return 'Electroestimulación';
      case DeviceFeature.heat: return 'Calentamiento';
      case DeviceFeature.light: return 'Iluminación';
      case DeviceFeature.sound: return 'Sonido';
      case DeviceFeature.battery: return 'Sensor de Batería';
      case DeviceFeature.pressure: return 'Sensor de Presión';
      case DeviceFeature.temperature: return 'Sensor de Temperatura';
      case DeviceFeature.accelerometer: return 'Acelerómetro';
      case DeviceFeature.gyroscope: return 'Giroscopio';
    }
  }
}
