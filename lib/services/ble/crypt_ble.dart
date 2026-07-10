/// CryptBle - Encriptación para dispositivos BLE LoveSpouse
///
/// Basado en el APK descompilado de LoveSpouse (CryptBleUtils.java).
///
/// Algoritmo:
/// 1. PSK = XOR(seed[0..3], MAC[2..5])
/// 2. ciphertext[i] = ((PSK[i%4] + random_byte) & 0xFF) ^ plaintext[i]
/// 3. checksum = (PSK[0] ^ (random_byte + sum(plaintext)) ^ 0x55) ^ (PSK[2] + random_byte)
/// 4. Packet: [len, 0x81, random_byte, ciphertext..., checksum]
library;

import 'dart:math';

/// Implementación del cifrado CryptBle para LoveSpouse.
class CryptBle {
  /// Deriva el PSK (Pre-Shared Key) de 4 bytes desde seed y MAC.
  /// seed: 4+ bytes del scan record / MMKV
  /// macBytes: bytes de la dirección MAC (6 bytes)
  static List<int> derivePsk(List<int> seed, List<int> macBytes) {
    final psk = <int>[0, 0, 0, 0];
    for (int i = 0; i < 4; i++) {
      psk[i] = (seed[i] & 0xFF) ^ (macBytes[i + 2] & 0xFF);
    }
    return psk;
  }

  /// Encripta un comando plaintext usando CryptBle.
  ///
  /// [plaintext] - bytes del comando a enviar
  /// [psk] - PSK de 4 bytes derivado por [derivePsk]
  ///
  /// Retorna el paquete completo: [len, 0x81, random, ciphertext..., checksum]
  static List<int> encrypt(List<int> plaintext, List<int> psk) {
    final random = Random();
    final x = random.nextInt(256); // byte aleatorio

    // Calcular checksum intermedio: X + sum(plaintext)
    var sum = x;
    for (final b in plaintext) {
      sum = (sum + (b & 0xFF)) & 0xFF;
    }

    // checksum = (PSK[0] ^ sum ^ 0x55) ^ (PSK[2] + X)
    final checksum = ((psk[0] & 0xFF) ^ sum ^ 0x55) ^ ((psk[2] & 0xFF) + x) & 0xFF;

    // Cifrar: ciphertext[i] = ((PSK[i%4] + X) & 0xFF) ^ plaintext[i]
    final ciphertext = <int>[for (int i = 0; i < plaintext.length; i++) 0];
    for (int i = 0; i < plaintext.length; i++) {
      final keyByte = ((psk[i % 4] & 0xFF) + x) & 0xFF;
      ciphertext[i] = keyByte ^ (plaintext[i] & 0xFF);
    }

    // Construir paquete: [len, 0x81, X, ciphertext..., checksum]
    final totalLen = plaintext.length + 4;
    final packet = <int>[for (int i = 0; i < totalLen; i++) 0];
    packet[0] = totalLen;
    packet[1] = 0x81;
    packet[2] = x;
    for (int i = 0; i < ciphertext.length; i++) {
      packet[3 + i] = ciphertext[i];
    }
    packet[totalLen - 1] = checksum;

    return packet;
  }

  /// Encripta un comando IPAO (2-byte: [value, mode]) a CryptBle.
  /// Esta es la forma en que CryptBleUtils recibe comandos.
  static List<int> encryptCommand(int value, int mode, List<int> psk) {
    return encrypt([value, mode], psk);
  }

  /// Parsea la dirección MAC string a bytes
  static List<int> macToBytes(String mac) {
    final parts = mac.split(':');
    return parts.map((p) => int.parse(p, radix: 16)).toList();
  }
}
