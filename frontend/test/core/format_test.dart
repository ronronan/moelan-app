import 'package:app/core/format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatCents', () {
    test('formats zero', () {
      expect(formatCents(0), '0,00 €');
    });

    test('formats whole euros', () {
      expect(formatCents(100), '1,00 €');
    });

    test('formats cents', () {
      expect(formatCents(150), '1,50 €');
    });

    test('formats negative amounts (debits) with a leading minus', () {
      expect(formatCents(-300), '-3,00 €');
    });

    test('never loses precision converting cents to euros', () {
      // 100 lots of 1 cent must sum to exactly 1,00€, not 0,99€ or
      // 1,01€ from float drift — this is the whole reason money is
      // cents everywhere except this formatting boundary.
      var totalCents = 0;
      for (var i = 0; i < 100; i++) {
        totalCents += 1;
      }
      expect(formatCents(totalCents), '1,00 €');
    });
  });
}
