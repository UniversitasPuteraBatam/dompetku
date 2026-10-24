import 'package:dompetku/data/dummy_transactions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatRupiah', () {
    test('groups positive amounts by thousands', () {
      expect(formatRupiah(0), 'Rp 0');
      expect(formatRupiah(500), 'Rp 500');
      expect(formatRupiah(45000), 'Rp 45.000');
      expect(formatRupiah(450000), 'Rp 450.000');
      expect(formatRupiah(5000000), 'Rp 5.000.000');
    });

    test('puts the minus sign before Rp for negative amounts', () {
      expect(formatRupiah(-500), '-Rp 500');
      expect(formatRupiah(-45000), '-Rp 45.000');
      expect(formatRupiah(-450000), '-Rp 450.000');
      expect(formatRupiah(-5000000), '-Rp 5.000.000');
    });
  });
}
