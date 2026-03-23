// ═══════════════════════════════════════════════════════════════
// Velvet Sync Platform · lib/core/types/result_types.dart
// Tipos Result/Either para manejo funcional de errores
// ═══════════════════════════════════════════════════════════════

// import 'event_types.dart' show DeviceError; // Removed recursive/conflicting import

/// Tipo Result para manejo funcional de errores
/// 
/// Uso:
/// ```dart
/// Future<Result<Device, DeviceError>> connectToDevice(String id) async {
///   try {
///     final device = await _connect(id);
///     return Success(device);
///   } on ConnectionTimeoutException {
///     return Failure(DeviceError.connectionTimeout);
///   }
/// }
/// 
/// final result = await connectToDevice('device-1');
/// result.fold(
///   (error) => lvsLog('Error: $error'),
///   (device) => lvsLog('Conectado: ${device.name}'),
/// );
/// ```
abstract class Result<T, E> {
  const Result();
  
  /// Ejecutar callback según el resultado
  R fold<R>(
    R Function(E error) onFailure,
    R Function(T value) onSuccess,
  );
  
  /// Ejecutar callback solo si es éxito
  void forEach(void Function(T value) f) {
    fold((_) => {}, f);
  }
  
  /// Ejecutar callback solo si es fallo
  void forEachFailure(void Function(E error) f) {
    fold(f, (_) => {});
  }
  
  /// Verificar si es éxito
  bool get isSuccess;
  
  /// Verificar si es fallo
  bool get isFailure;
  
  /// Obtener valor o lanzar excepción
  T get value {
    return fold(
      (error) => throw const ResultException('Attempted to get value from Failure'),
      (value) => value,
    );
  }
  
  /// Obtener error o lanzar excepción
  E get error {
    return fold(
      (error) => error,
      (value) => throw const ResultException('Attempted to get error from Success'),
    );
  }
  
  /// Obtener valor o valor por defecto
  T getOrElse(T Function(E error) defaultValue) {
    return fold((error) => defaultValue(error), (value) => value);
  }
  
  /// Convertir a nullable
  T? toNullable() {
    return fold((_) => null, (value) => value);
  }
  
  /// Mapear el valor de éxito
  Result<U, E> map<U>(U Function(T value) f) {
    return fold(
      (error) => Failure(error),
      (value) => Success(f(value)),
    );
  }
  
  /// Mapear el error
  Result<T, U> mapError<U>(U Function(E error) f) {
    return fold(
      (error) => Failure(f(error)),
      (value) => Success(value),
    );
  }
  
  /// Mapear asíncrono el valor de éxito
  Future<Result<U, E>> asyncMap<U>(Future<U> Function(T value) f) async {
    return fold(
      (error) => Failure(error),
      (value) async => Success(await f(value)),
    );
  }

  /// Mapear asíncrono el error
  Future<Result<T, U>> asyncMapError<U>(Future<U> Function(E error) f) async {
    return fold(
      (error) async => Failure(await f(error)),
      (value) => Success(value),
    );
  }
  
  /// Convertir a Future
  Future<Result<T, E>> toFuture() async => this;
}

/// Resultado exitoso
class Success<T, E> extends Result<T, E> {
  final T _value;
  
  const Success(this._value);
  
  @override
  R fold<R>(
    R Function(E error) onFailure,
    R Function(T value) onSuccess,
  ) {
    return onSuccess(_value);
  }
  
  @override
  bool get isSuccess => true;
  
  @override
  bool get isFailure => false;
  
  @override
  T get value => _value;
  
  @override
  String toString() => 'Success($value)';
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Success<T, E> && runtimeType == other.runtimeType && _value == other._value;
  
  @override
  int get hashCode => _value.hashCode;
}

/// Resultado fallido
class Failure<T, E> extends Result<T, E> {
  final E _error;
  
  const Failure(this._error);
  
  @override
  R fold<R>(
    R Function(E error) onFailure,
    R Function(T value) onSuccess,
  ) {
    return onFailure(_error);
  }
  
  @override
  bool get isSuccess => false;
  
  @override
  bool get isFailure => true;
  
  @override
  E get error => _error;
  
  @override
  String toString() => 'Failure($error)';
  
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Failure<T, E> && runtimeType == other.runtimeType && _error == other._error;
  
  @override
  int get hashCode => _error.hashCode;
}

/// Excepción lanzada al intentar obtener valor/error incorrecto
class ResultException implements Exception {
  final String message;
  
  const ResultException([this.message = 'Invalid Result operation']);
  
  @override
  String toString() => 'ResultException: $message';
}

// ═══════════════════════════════════════════════════════════════
// ERRORES ESPECÍFICOS DE DISPOSITIVO
// ═══════════════════════════════════════════════════════════════

/// Error de dispositivo
enum DeviceError {
  /// Dispositivo no encontrado
  notFound,
  
  /// Timeout de conexión
  connectionTimeout,
  
  /// Error de conexión
  connectionError,
  
  /// Dispositivo ya conectado
  alreadyConnected,
  
  /// Dispositivo no conectado
  notConnected,
  
  /// Permiso denegado
  permissionDenied,
  
  /// Bluetooth no disponible
  bluetoothUnavailable,
  
  /// Protocolo no soportado
  unsupportedProtocol,
  
  /// Comando inválido
  invalidCommand,
  
  /// Error de hardware
  hardwareError,
  
  /// Batería baja
  lowBattery,
  
  /// Fuera de rango
  outOfRange,
  
  /// Error interno
  internalError,
}

/// Extensión para obtener mensajes de error legibles
extension DeviceErrorExtension on DeviceError {
  String get message {
    switch (this) {
      case DeviceError.notFound:
        return 'Dispositivo no encontrado';
      case DeviceError.connectionTimeout:
        return 'Timeout de conexión';
      case DeviceError.connectionError:
        return 'Error de conexión';
      case DeviceError.alreadyConnected:
        return 'El dispositivo ya está conectado';
      case DeviceError.notConnected:
        return 'El dispositivo no está conectado';
      case DeviceError.permissionDenied:
        return 'Permiso denegado';
      case DeviceError.bluetoothUnavailable:
        return 'Bluetooth no disponible';
      case DeviceError.unsupportedProtocol:
        return 'Protocolo no soportado';
      case DeviceError.invalidCommand:
        return 'Comando inválido';
      case DeviceError.hardwareError:
        return 'Error de hardware';
      case DeviceError.lowBattery:
        return 'Batería baja';
      case DeviceError.outOfRange:
        return 'Dispositivo fuera de rango';
      case DeviceError.internalError:
        return 'Error interno';
    }
  }
  
  String get description {
    switch (this) {
      case DeviceError.notFound:
        return 'El dispositivo especificado no fue encontrado. Verifica que esté encendido y en modo emparejamiento.';
      case DeviceError.connectionTimeout:
        return 'La conexión tardó demasiado. Intenta acercar el dispositivo.';
      case DeviceError.connectionError:
        return 'Error al establecer conexión. Reinicia Bluetooth e intenta nuevamente.';
      case DeviceError.alreadyConnected:
        return 'Ya estás conectado a este dispositivo.';
      case DeviceError.notConnected:
        return 'Debes conectarte al dispositivo primero.';
      case DeviceError.permissionDenied:
        return 'Se requieren permisos de Bluetooth. Concédelos en configuración.';
      case DeviceError.bluetoothUnavailable:
        return 'El Bluetooth no está disponible. Actívalo en configuración.';
      case DeviceError.unsupportedProtocol:
        return 'Este dispositivo usa un protocolo no soportado.';
      case DeviceError.invalidCommand:
        return 'El comando enviado es inválido para este dispositivo.';
      case DeviceError.hardwareError:
        return 'Error de hardware. Reinicia el dispositivo.';
      case DeviceError.lowBattery:
        return 'Batería baja. Conecta el dispositivo a cargar.';
      case DeviceError.outOfRange:
        return 'El dispositivo está fuera de rango. Acércalo.';
      case DeviceError.internalError:
        return 'Error interno. Reinicia la aplicación.';
    }
  }
  
  /// Intentar recuperar del error
  RecoveryAction? get recoveryAction {
    switch (this) {
      case DeviceError.connectionTimeout:
      case DeviceError.connectionError:
        return RecoveryAction.retry;
      case DeviceError.permissionDenied:
      case DeviceError.bluetoothUnavailable:
        return RecoveryAction.openSettings;
      case DeviceError.lowBattery:
        return RecoveryAction.charge;
      case DeviceError.outOfRange:
        return RecoveryAction.moveCloser;
      case DeviceError.internalError:
        return RecoveryAction.restart;
      default:
        return null;
    }
  }
}

/// Acción de recuperación sugerida
enum RecoveryAction {
  /// Reintentar operación
  retry,
  
  /// Abrir configuración
  openSettings,
  
  /// Cargar dispositivo
  charge,
  
  /// Acercar dispositivo
  moveCloser,
  
  /// Reiniciar aplicación
  restart,
  
  /// Reiniciar dispositivo
  restartDevice,
  
  /// Sin acción disponible
  none,
}

// ═══════════════════════════════════════════════════════════════
// ERRORES DE PROTOCOLO
// ═══════════════════════════════════════════════════════════════

/// Error de protocolo
enum ProtocolError {
  /// Protocolo desconocido
  unknownProtocol,
  
  /// Formato de paquete inválido
  invalidPacketFormat,
  
  /// Checksum inválido
  invalidChecksum,
  
  /// Comando no reconocido
  unrecognizedCommand,
  
  /// Respuesta inesperada
  unexpectedResponse,
  
  /// Timeout de respuesta
  responseTimeout,
  
  /// Secuencia inválida
  invalidSequence,
}

extension ProtocolErrorExtension on ProtocolError {
  String get message {
    switch (this) {
      case ProtocolError.unknownProtocol:
        return 'Protocolo desconocido';
      case ProtocolError.invalidPacketFormat:
        return 'Formato de paquete inválido';
      case ProtocolError.invalidChecksum:
        return 'Checksum inválido';
      case ProtocolError.unrecognizedCommand:
        return 'Comando no reconocido';
      case ProtocolError.unexpectedResponse:
        return 'Respuesta inesperada';
      case ProtocolError.responseTimeout:
        return 'Timeout de respuesta';
      case ProtocolError.invalidSequence:
        return 'Secuencia inválida';
    }
  }
}

// ═══════════════════════════════════════════════════════════════
// UTILIDADES
// ═══════════════════════════════════════════════════════════════

/// Extensión para convertir Future<Result> a operaciones más cómodas
extension FutureResultExtension<T, E> on Future<Result<T, E>> {
  /// Ejecutar callback si es éxito
  Future<Future<Result<T, E>>> onSuccess(void Function(T value) callback) async {
    final result = await this;
    result.forEach(callback);
    return result.toFuture();
  }
  
  /// Ejecutar callback si es fallo
  Future<Future<Result<T, E>>> onFailure(void Function(E error) callback) async {
    final result = await this;
    result.forEachFailure(callback);
    return result.toFuture();
  }
  
  /// Manejar ambos casos
  Future<R> handle<R>({
    required R Function(T value) onSuccess,
    required R Function(E error) onFailure,
  }) async {
    final result = await this;
    return result.fold(onFailure, onSuccess);
  }
  
  /// Lanzar excepción si es fallo
  Future<T> getOrThrow() async {
    final result = await this;
    return result.fold(
      (error) => throw ResultException('Operation failed: $error'),
      (value) => value,
    );
  }
}
