import 'package:ezsplit_mobile/domain/money.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseRupees', () {
    test('strips commas, rupee sign and spaces', () {
      expect(parseRupees('1,500'), 150000);
      expect(parseRupees('₹ 600'), 60000);
      expect(parseRupees('12.5'), 1250);
      expect(parseRupees('0.05'), 5);
    });
    test('rejects invalid input', () {
      expect(parseRupees('1500.555'), isNull);
      expect(parseRupees('0'), isNull);
      expect(parseRupees('0.00'), isNull);
      expect(parseRupees('-5'), isNull);
      expect(parseRupees(''), isNull);
      expect(parseRupees('abc'), isNull);
      expect(parseRupees('1.2.3'), isNull);
    });
  });

  group('api conversion', () {
    test('paiseFromApi', () {
      expect(paiseFromApi('600.0'), 60000);
      expect(paiseFromApi('333.34'), 33334);
      expect(paiseFromApi('12'), 1200);
      expect(paiseFromApi('0.5'), 50);
    });
    test('paiseToApi', () {
      expect(paiseToApi(60000), '600.00');
      expect(paiseToApi(5), '0.05');
      expect(paiseToApi(33334), '333.34');
    });
  });

  group('formatRupees', () {
    test('uses Indian grouping and hides zero decimals', () {
      expect(formatRupees(10000000), '₹1,00,000');
      expect(formatRupees(60000), '₹600');
      expect(formatRupees(33334), '₹333.34');
      expect(formatRupees(1000000000), '₹1,00,00,000');
      expect(formatRupees(0), '₹0');
      expect(formatRupees(5), '₹0.05');
      expect(formatRupees(1050), '₹10.50');
    });
  });
}
