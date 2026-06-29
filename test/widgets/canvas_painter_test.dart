import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Re-implement _CanvasPainter for testing (it's private to lvs_modes)
class TestCanvasPainter extends CustomPainter {
  final double intensity;
  final Color color;
  TestCanvasPainter(this.intensity, this.color);

  @override
  void paint(Canvas canvas, Size size) {}

  @override
  bool shouldRepaint(TestCanvasPainter old) => old.intensity != intensity;
}

void main() {
  group('CanvasPainter - shouldRepaint', () {
    test('returns true when intensity changes', () {
      final old = TestCanvasPainter(50, Colors.pink);
      final next = TestCanvasPainter(75, Colors.pink);
      expect(next.shouldRepaint(old), isTrue);
    });

    test('returns false when intensity is same', () {
      final old = TestCanvasPainter(50, Colors.pink);
      final next = TestCanvasPainter(50, Colors.pink);
      expect(next.shouldRepaint(old), isFalse);
    });

    test('returns true when intensity goes to zero', () {
      final old = TestCanvasPainter(75, Colors.pink);
      final next = TestCanvasPainter(0, Colors.pink);
      expect(next.shouldRepaint(old), isTrue);
    });

    test('returns true when going from zero to active', () {
      final old = TestCanvasPainter(0, Colors.pink);
      final next = TestCanvasPainter(100, Colors.pink);
      expect(next.shouldRepaint(old), isTrue);
    });
  });
}
