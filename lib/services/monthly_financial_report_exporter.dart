import 'package:excel/excel.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../data/dummy_transactions.dart';
import '../data/month_names.dart';
import '../data/monthly_financial_report.dart';
import 'app_clock.dart';

typedef ReportFileSaver =
    Future<String?> Function({
      required Uint8List bytes,
      required String name,
      required String extension,
      required MimeType mimeType,
    });

class MonthlyFinancialReportExporter {
  MonthlyFinancialReportExporter({ReportFileSaver? saveFile})
    : _saveFile = saveFile ?? _saveGeneratedFile;

  final ReportFileSaver _saveFile;

  Future<String?> exportPdf(MonthlyFinancialReport report) async {
    final bytes = await buildPdf(report);
    return _save(
      report,
      bytes: bytes,
      extension: 'pdf',
      mimeType: MimeType.pdf,
    );
  }

  Future<String?> exportExcel(MonthlyFinancialReport report) async {
    final bytes = buildExcel(report);
    return _save(
      report,
      bytes: bytes,
      extension: 'xlsx',
      mimeType: MimeType.microsoftExcel,
    );
  }

  Future<String?> _save(
    MonthlyFinancialReport report, {
    required Uint8List bytes,
    required String extension,
    required MimeType mimeType,
  }) async {
    final fullName = fileName(report, extension);
    final name = fullName.substring(0, fullName.length - extension.length - 1);
    final savedPath = await _saveFile(
      bytes: bytes,
      name: name,
      extension: extension,
      mimeType: mimeType,
    );
    if (savedPath == null) return null;
    if (savedPath.trim().isEmpty ||
        savedPath.startsWith('Something went wrong')) {
      throw StateError('File tidak berhasil disimpan.');
    }
    return savedPath;
  }

  Future<Uint8List> buildPdf(MonthlyFinancialReport report) async {
    final document = pw.Document();
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 10),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(color: PdfColors.blueGrey200),
            ),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'DompetKu',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blueGrey900,
                ),
              ),
              pw.Text(
                'Laporan Keuangan - ${periodLabel(report)}',
                style: const pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.blueGrey700,
                ),
              ),
            ],
          ),
        ),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Halaman ${context.pageNumber} dari ${context.pagesCount}',
            style: const pw.TextStyle(
              fontSize: 9,
              color: PdfColors.blueGrey600,
            ),
          ),
        ),
        build: (context) => [
          pw.SizedBox(height: 18),
          pw.Text(
            'Ringkasan Keuangan',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headers: const ['Pemasukan', 'Pengeluaran', 'Selisih'],
            data: [
              [
                formatRupiah(report.income),
                formatRupiah(report.expense),
                formatRupiah(report.difference),
              ],
            ],
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
              fontSize: 10,
            ),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColors.blueGrey800,
            ),
            cellStyle: const pw.TextStyle(fontSize: 10),
            cellAlignments: const {
              0: pw.Alignment.centerRight,
              1: pw.Alignment.centerRight,
              2: pw.Alignment.centerRight,
            },
          ),
          pw.SizedBox(height: 18),
          pw.Text(
            'Pengeluaran per Kategori',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headers: const ['Kategori', 'Total Pengeluaran'],
            data: report.expensesByCategory.isEmpty
                ? [
                    ['Belum ada pengeluaran', '-'],
                  ]
                : report.expensesByCategory
                      .map((item) => [item.category, formatRupiah(item.amount)])
                      .toList(),
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
              fontSize: 9,
            ),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColors.blueGrey800,
            ),
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellAlignments: const {1: pw.Alignment.centerRight},
          ),
          pw.SizedBox(height: 18),
          pw.Text(
            'Rincian Transaksi',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headers: const [
              'Tanggal',
              'Kategori',
              'Deskripsi',
              'Jenis',
              'Nominal',
            ],
            data: report.transactions.isEmpty
                ? [
                    ['-', '-', 'Belum ada transaksi', '-', '-'],
                  ]
                : report.transactions
                      .map(
                        (transaction) => [
                          formatReportTransactionDate(transaction),
                          transaction.category,
                          transaction.note.trim().isEmpty
                              ? '-'
                              : transaction.note.trim(),
                          transaction.isIncome ? 'Pemasukan' : 'Pengeluaran',
                          formatRupiah(transaction.amount),
                        ],
                      )
                      .toList(),
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
              fontSize: 8,
            ),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColors.blueGrey800,
            ),
            cellStyle: const pw.TextStyle(fontSize: 8),
            cellAlignments: const {
              0: pw.Alignment.centerLeft,
              4: pw.Alignment.centerRight,
            },
            columnWidths: const {
              0: pw.FlexColumnWidth(1.5),
              1: pw.FlexColumnWidth(1.4),
              2: pw.FlexColumnWidth(3),
              3: pw.FlexColumnWidth(1.3),
              4: pw.FlexColumnWidth(1.5),
            },
          ),
        ],
      ),
    );
    return document.save();
  }

  Uint8List buildExcel(MonthlyFinancialReport report) {
    final workbook = Excel.createExcel();
    final sheet = workbook['Laporan Keuangan'];
    workbook.delete('Sheet1');
    final rows = <List<CellValue?>>[
      [TextCellValue('DompetKu')],
      [TextCellValue('Laporan Keuangan Bulanan')],
      [TextCellValue('Periode'), TextCellValue(periodLabel(report))],
      [TextCellValue('')],
      [TextCellValue('Ringkasan Keuangan')],
      [TextCellValue('Pemasukan'), TextCellValue(formatRupiah(report.income))],
      [
        TextCellValue('Pengeluaran'),
        TextCellValue(formatRupiah(report.expense)),
      ],
      [
        TextCellValue('Selisih'),
        TextCellValue(formatRupiah(report.difference)),
      ],
      [TextCellValue('')],
      [TextCellValue('Pengeluaran per Kategori')],
      [TextCellValue('Kategori'), TextCellValue('Total Pengeluaran')],
      if (report.expensesByCategory.isEmpty)
        [TextCellValue('Belum ada pengeluaran'), TextCellValue('-')]
      else
        for (final item in report.expensesByCategory)
          [
            TextCellValue(item.category),
            TextCellValue(formatRupiah(item.amount)),
          ],
      [TextCellValue('')],
      [TextCellValue('Rincian Transaksi')],
      [
        TextCellValue('Tanggal'),
        TextCellValue('Kategori'),
        TextCellValue('Deskripsi'),
        TextCellValue('Jenis Transaksi'),
        TextCellValue('Nominal'),
      ],
      if (report.transactions.isEmpty)
        [
          TextCellValue('-'),
          TextCellValue('-'),
          TextCellValue('Belum ada transaksi'),
          TextCellValue('-'),
          TextCellValue('-'),
        ]
      else
        for (final transaction in report.transactions)
          [
            TextCellValue(formatReportTransactionDate(transaction)),
            TextCellValue(transaction.category),
            TextCellValue(
              transaction.note.trim().isEmpty ? '-' : transaction.note.trim(),
            ),
            TextCellValue(transaction.isIncome ? 'Pemasukan' : 'Pengeluaran'),
            TextCellValue(formatRupiah(transaction.amount)),
          ],
    ];
    final categoryRowCount = report.expensesByCategory.isEmpty
        ? 1
        : report.expensesByCategory.length;
    final transactionTitleRow = 12 + categoryRowCount;
    final transactionHeaderRow = transactionTitleRow + 1;

    for (final row in rows) {
      sheet.appendRow(row);
    }

    sheet.setColumnWidth(0, 22);
    sheet.setColumnWidth(1, 24);
    sheet.setColumnWidth(2, 36);
    sheet.setColumnWidth(3, 22);
    sheet.setColumnWidth(4, 20);

    final boldStyle = CellStyle(bold: true);
    for (final rowIndex in [0, 1, 4, 9, transactionTitleRow]) {
      sheet
              .cell(
                CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex),
              )
              .cellStyle =
          boldStyle;
    }
    for (final columnIndex in [0, 1, 2, 3, 4]) {
      sheet
              .cell(
                CellIndex.indexByColumnRow(
                  columnIndex: columnIndex,
                  rowIndex: transactionHeaderRow,
                ),
              )
              .cellStyle =
          boldStyle;
    }
    for (final columnIndex in [0, 1]) {
      sheet
              .cell(
                CellIndex.indexByColumnRow(
                  columnIndex: columnIndex,
                  rowIndex: 10,
                ),
              )
              .cellStyle =
          boldStyle;
    }

    final bytes = workbook.encode();
    if (bytes == null || bytes.isEmpty) {
      throw StateError('Gagal membuat file Excel.');
    }
    return Uint8List.fromList(bytes);
  }

  static String periodLabel(MonthlyFinancialReport report) =>
      '${monthNames[report.month - 1]} ${report.year}';

  static String fileName(MonthlyFinancialReport report, String extension) =>
      'dompetku_laporan_keuangan_${report.year}_'
      '${report.month.toString().padLeft(2, '0')}.$extension';

  static String formatReportTransactionDate(TransactionItem transaction) =>
      transaction.hasTime
      ? AppClock.timestampString(transaction.date)
      : AppClock.dateString(transaction.date);
}

Future<String?> _saveGeneratedFile({
  required Uint8List bytes,
  required String name,
  required String extension,
  required MimeType mimeType,
}) {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.linux) {
    return FileSaver.instance.saveFile(
      name: name,
      bytes: bytes,
      fileExtension: extension,
      mimeType: mimeType,
    );
  }
  return FileSaver.instance.saveAs(
    name: name,
    bytes: bytes,
    fileExtension: extension,
    mimeType: mimeType,
  );
}
