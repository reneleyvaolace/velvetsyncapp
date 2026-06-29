import 'package:flutter_test/flutter_test.dart';
import 'package:velvet_sync/screens/kegel_screen.dart';

void main() {
  group('KegelLevel', () {
    test('contains 3 predefined levels', () {
      expect(kegelLevels.length, 3);
    });

    test('beginner level has correct values', () {
      final beginner = kegelLevels[0];
      expect(beginner.name, 'PRINCIPIANTE');
      expect(beginner.contractSeconds, 3);
      expect(beginner.relaxSeconds, 3);
      expect(beginner.repetitions, 10);
    });

    test('intermediate level has correct values', () {
      final intermediate = kegelLevels[1];
      expect(intermediate.name, 'INTERMEDIO');
      expect(intermediate.contractSeconds, 5);
      expect(intermediate.relaxSeconds, 5);
      expect(intermediate.repetitions, 15);
    });

    test('advanced level has correct values', () {
      final advanced = kegelLevels[2];
      expect(advanced.name, 'AVANZADO');
      expect(advanced.contractSeconds, 10);
      expect(advanced.relaxSeconds, 5);
      expect(advanced.repetitions, 20);
    });

    test('difficulty increases with each level', () {
      for (var i = 1; i < kegelLevels.length; i++) {
        expect(kegelLevels[i].contractSeconds, greaterThanOrEqualTo(kegelLevels[i - 1].contractSeconds));
        expect(kegelLevels[i].repetitions, greaterThanOrEqualTo(kegelLevels[i - 1].repetitions));
      }
    });
  });

  group('KegelPhase', () {
    test('has all required phases', () {
      expect(KegelPhase.values.length, 4);
      expect(KegelPhase.values, containsAll([
        KegelPhase.ready,
        KegelPhase.contract,
        KegelPhase.relax,
        KegelPhase.finished,
      ]));
    });
  });
}
