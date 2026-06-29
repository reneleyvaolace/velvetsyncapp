import 'dart:async';

enum BleState { idle, scanning, connecting, connected, error }
enum WaveType { none, pulse, wave, ramp, storm }

class LogEntry {
  final DateTime time;
  final String msg;
  final String type;
  LogEntry(this.time, this.msg, this.type);
}

class QueuedCommand {
  final List<int> cmdBytes;
  final String label;
  final bool silent;
  final Completer<bool> completer;

  QueuedCommand(this.cmdBytes, this.label, this.silent, this.completer);
}
