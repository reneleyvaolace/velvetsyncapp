import 'package:flutter_test/flutter_test.dart';
import 'package:velvet_sync/utils/logger.dart';

void main() {
  group('Logger - Singleton', () {
    test('Logger() returns the same instance', () {
      final a = Logger();
      final b = Logger();
      expect(a, same(b));
    });
  });

  group('Logger - basic logging', () {
    late Logger logger;

    setUp(() {
      logger = Logger();
      logger.enabled = true;
      logger.minLevel = LogLevel.debug;
      logger.clear();
    });

    test('log adds entry to recentLogs', () {
      logger.log('Test message');
      expect(logger.recentLogs.length, 1);
      expect(logger.recentLogs.first.message, 'Test message');
    });

    test('debug adds entry with debug level', () {
      logger.debug('Debug msg');
      expect(logger.recentLogs.first.level, LogLevel.debug);
    });

    test('info adds entry with info level', () {
      logger.info('Info msg');
      expect(logger.recentLogs.first.level, LogLevel.info);
    });

    test('warning adds entry with warning level', () {
      logger.warning('Warning msg');
      expect(logger.recentLogs.first.level, LogLevel.warning);
    });

    test('error adds entry with error level', () {
      logger.error('Error msg');
      expect(logger.recentLogs.first.level, LogLevel.error);
    });

    test('critical adds entry with critical level', () {
      logger.critical('Critical msg');
      expect(logger.recentLogs.first.level, LogLevel.critical);
    });
  });

  group('Logger - filtering', () {
    late Logger logger;

    setUp(() {
      logger = Logger();
      logger.enabled = true;
      logger.minLevel = LogLevel.debug;
      logger.clear();
    });

    test('does not log when disabled', () {
      logger.enabled = false;
      logger.log('Should not appear');
      expect(logger.recentLogs.length, 0);
    });

    test('filters by minimum level', () {
      logger.minLevel = LogLevel.warning;
      logger.debug('Debug msg');
      logger.info('Info msg');
      logger.warning('Warning msg');
      logger.error('Error msg');

      expect(logger.recentLogs.length, 2);
      expect(logger.recentLogs[0].level, LogLevel.warning);
      expect(logger.recentLogs[1].level, LogLevel.error);
    });
  });

  group('Logger - getLogsByLevel', () {
    setUp(() {
      Logger().enabled = true;
      Logger().minLevel = LogLevel.debug;
      Logger().clear();
    });

    test('filters logs by level', () {
      final logger = Logger();
      logger.clear();
      logger.info('Info 1');
      logger.error('Error 1');
      logger.info('Info 2');
      logger.debug('Debug 1');

      final errors = logger.getLogsByLevel(LogLevel.error);
      expect(errors.length, 1);
      expect(errors.first.message, 'Error 1');

      final infos = logger.getLogsByLevel(LogLevel.info);
      expect(infos.length, 2);
    });
  });

  group('Logger - getLogsByTag', () {
    setUp(() {
      Logger().enabled = true;
      Logger().minLevel = LogLevel.debug;
      Logger().clear();
    });

    test('filters logs by tag', () {
      final logger = Logger();
      logger.clear();
      logger.log('BLE msg', tag: 'BLE');
      logger.log('APP msg', tag: 'APP');
      logger.log('Another BLE', tag: 'BLE');

      final bleLogs = logger.getLogsByTag('BLE');
      expect(bleLogs.length, 2);
    });
  });

  group('Logger - searchLogs', () {
    setUp(() {
      Logger().enabled = true;
      Logger().minLevel = LogLevel.debug;
      Logger().clear();
    });

    test('finds logs by message content', () {
      final logger = Logger();
      logger.clear();
      logger.log('Device connected');
      logger.log('Device disconnected');
      logger.log('Scan started');

      final found = logger.searchLogs('Device');
      expect(found.length, 2);
    });

    test('is case insensitive', () {
      final logger = Logger();
      logger.clear();
      logger.log('DEVICE ERROR');
      final found = logger.searchLogs('device');
      expect(found.length, 1);
    });
  });

  group('Logger - getLogsByTimeRange', () {
    setUp(() {
      Logger().enabled = true;
      Logger().minLevel = LogLevel.debug;
      Logger().clear();
    });

    test('filters logs by time range', () async {
      final logger = Logger();
      logger.clear();

      logger.log('Before');
      // Ensure distinct timestamps
      await Future.delayed(const Duration(milliseconds: 5));
      final midPoint = DateTime.now();
      await Future.delayed(const Duration(milliseconds: 5));
      logger.log('After');

      final beforeLogs = logger.getLogsByTimeRange(endTime: midPoint);
      expect(beforeLogs.length, 1);
      expect(beforeLogs.first.message, 'Before');
    });
  });

  group('Logger - getStats', () {
    setUp(() {
      Logger().enabled = true;
      Logger().minLevel = LogLevel.debug;
      Logger().clear();
    });

    test('returns correct statistics', () {
      final logger = Logger();
      logger.clear();
      logger.info('Info 1');
      logger.info('Info 2');
      logger.error('Error 1');
      logger.debug('Debug 1');

      final stats = logger.getStats();
      expect(stats['info'], 2);
      expect(stats['error'], 1);
      expect(stats['debug'], 1);
      expect(stats['total'], 4);
    });
  });

  group('Logger - clear', () {
    setUp(() {
      Logger().enabled = true;
      Logger().minLevel = LogLevel.debug;
      Logger().clear();
    });

    test('removes all logs', () {
      final logger = Logger();
      logger.log('Test');
      expect(logger.recentLogs.length, 1);
      logger.clear();
      expect(logger.recentLogs.length, 0);
    });
  });

  group('LogEntry', () {
    test('toString formats correctly', () {
      final entry = LogEntry(
        timestamp: DateTime(2026, 6, 26, 14, 30, 0),
        level: LogLevel.info,
        message: 'Test message',
        tag: 'TEST',
      );

      final str = entry.toString();
      expect(str, contains('TEST'));
      expect(str, contains('Test message'));
    });

    test('toJson serializes correctly', () {
      final entry = LogEntry(
        timestamp: DateTime(2026, 6, 26),
        level: LogLevel.error,
        message: 'Error!',
        tag: 'ERR',
        source: 'test.dart',
      );

      final json = entry.toJson();
      expect(json['level'], 'error');
      expect(json['message'], 'Error!');
      expect(json['tag'], 'ERR');
      expect(json['source'], 'test.dart');
    });
  });
}
