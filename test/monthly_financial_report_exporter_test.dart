import 'dart:convert';

import 'package:dompetku/data/dummy_transactions.dart';
import 'package:dompetku/data/monthly_financial_report.dart';
import 'package:dompetku/services/monthly_financial_report_exporter.dart';
import 'package:excel/excel.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MonthlyFinancialReportExporter', () {
    test('exports the selected period and matching financial summary', () {
      final report = _report(
        transactions: [
          _transaction(2026, 10, 5, 250000, true, 'Gaji', note: 'Gaji bulanan'),
          _transaction(
            2026,
            10,
            8,
            50000,
            false,
            'Makanan',
            note: 'Makan siang',
          ),
          _transaction(2026, 9, 30, 900000, true, 'Bonus'),
        ],
      );
      final exporter = MonthlyFinancialReportExporter();

      final workbook = Excel.decodeBytes(exporter.buildExcel(report));
      final rows = workbook['Laporan Keuangan'].rows
          .map(
            (row) => row
                .map((cell) => _textValue(cell?.value))
                .whereType<String>()
                .toList(),
          )
          .toList();
      final cells = rows.expand((row) => row).toList();

      expect(cells, containsAll(['DompetKu', 'Oktober 2026']));
      expect(cells, containsAll(['Pemasukan', 'Rp 250.000']));
      expect(cells, containsAll(['Pengeluaran', 'Rp 50.000']));
      expect(cells, containsAll(['Selisih', 'Rp 200.000']));
      expect(
        cells,
        containsAll([
          '2026-10-05 12:00:00',
          'Gaji',
          'Gaji bulanan',
          'Pemasukan',
          'Rp 250.000',
          'Makan siang',
          'Pengeluaran',
          'Rp 50.000',
        ]),
      );
      expect(cells, isNot(contains('Bonus')));
    });

    test('formats filenames and transaction dates consistently', () {
      final transaction = _transaction(
        2026,
        10,
        5,
        1000,
        true,
        'Gaji',
        note: 'Gaji',
      );
      final report = _report(transactions: [transaction]);

      expect(
        MonthlyFinancialReportExporter.fileName(report, 'pdf'),
        'dompetku_laporan_keuangan_2026_10.pdf',
      );
      expect(
        MonthlyFinancialReportExporter.fileName(report, 'xlsx'),
        'dompetku_laporan_keuangan_2026_10.xlsx',
      );
      expect(
        MonthlyFinancialReportExporter.formatReportTransactionDate(transaction),
        '2026-10-05 12:00:00',
      );
      expect(
        MonthlyFinancialReportExporter.formatReportTransactionDate(
          _transaction(2026, 10, 5, 1000, true, 'Gaji', hasTime: false),
        ),
        '2026-10-05',
      );
    });

    test('creates a readable PDF for the chosen report', () async {
      final report = _report(
        transactions: [
          _transaction(2026, 10, 5, 250000, true, 'Gaji', note: 'Gaji bulanan'),
        ],
      );

      final bytes = await MonthlyFinancialReportExporter().buildPdf(report);

      expect(latin1.decode(bytes.sublist(0, 5)), '%PDF-');
      expect(bytes.length, greaterThan(500));
    });

    test('creates a PDF for a month without transactions', () async {
      final bytes = await MonthlyFinancialReportExporter().buildPdf(
        _report(transactions: []),
      );

      expect(latin1.decode(bytes.sublist(0, 5)), '%PDF-');
    });

    test('represents a period with no transactions without inventing rows', () {
      final report = _report(transactions: []);
      final workbook = Excel.decodeBytes(
        MonthlyFinancialReportExporter().buildExcel(report),
      );
      final cells = workbook['Laporan Keuangan'].rows
          .expand((row) => row)
          .map((cell) => _textValue(cell?.value))
          .whereType<String>()
          .toList();

      expect(cells, containsAll(['Rp 0', 'Belum ada pengeluaran']));
      expect(cells, contains('Belum ada transaksi'));
      expect(report.transactions, isEmpty);
    });

    test(
      'saves with the selected period filename and Excel MIME type',
      () async {
        String? savedName;
        MimeType? savedMimeType;
        final exporter = MonthlyFinancialReportExporter(
          saveFile:
              ({
                required bytes,
                required name,
                required extension,
                required mimeType,
              }) async {
                savedName = '$name.$extension';
                savedMimeType = mimeType;
                expect(bytes, isNotEmpty);
                return 'saved-file-path';
              },
        );

        final savedPath = await exporter.exportExcel(_report(transactions: []));

        expect(savedPath, 'saved-file-path');
        expect(savedName, 'dompetku_laporan_keuangan_2026_10.xlsx');
        expect(savedMimeType, MimeType.microsoftExcel);
      },
    );

    test('reports a failed file save instead of returning success', () async {
      final exporter = MonthlyFinancialReportExporter(
        saveFile:
            ({
              required bytes,
              required name,
              required extension,
              required mimeType,
            }) async => '',
      );

      await expectLater(
        exporter.exportPdf(_report(transactions: [])),
        throwsA(isA<StateError>()),
      );
    });
  });
}

MonthlyFinancialReport _report({required List<TransactionItem> transactions}) =>
    MonthlyFinancialReport.fromTransactions(
      transactions: transactions,
      year: 2026,
      month: 10,
    );

TransactionItem _transaction(
  int year,
  int month,
  int day,
  int amount,
  bool income,
  String category, {
  String note = '',
  bool hasTime = true,
}) => TransactionItem(
  id: day,
  category: category,
  amount: amount,
  date: DateTime.utc(year, month, day, hasTime ? 12 : 0),
  isIncome: income,
  icon: income ? Icons.savings : Icons.receipt,
  hasTime: hasTime,
  note: note,
);

String? _textValue(CellValue? value) => switch (value) {
  TextCellValue(:final value) => value.text,
  _ => null,
};
