// ignore_for_file: use_build_context_synchronously
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart' as excel;
import 'package:file_picker/file_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../services/sheets_service.dart';

// ==========================================
// 1. HINDI NUMBER TO WORDS ENGINE
// ==========================================
class HindiWordsConverter {
  static const List<String> _words0To99 = [
    "",
    "एक",
    "दो",
    "तीन",
    "चार",
    "पाँच",
    "छह",
    "सात",
    "आठ",
    "नौ",
    "दस",
    "ग्यारह",
    "बारह",
    "तेरह",
    "चौदह",
    "पंद्रह",
    "सोलह",
    "सत्रह",
    "अठारह",
    "उन्नीस",
    "बीस",
    "इक्कीस",
    "बाईस",
    "तेईस",
    "चौबीस",
    "पच्चीस",
    "छब्बीस",
    "सत्ताईस",
    "अट्ठाईस",
    "उनतीस",
    "तीस",
    "इकतीस",
    "बत्तीस",
    "तेतीस",
    "चौंतीस",
    "पैंतीस",
    "छत्तीस",
    "सैंतीस",
    "अड़तीस",
    "उनतालीस",
    "चालीस",
    "इकतालीस",
    "बयालीस",
    "तिरालीस",
    "चौवालीस",
    "पैंतालीस",
    "छियालीस",
    "सैंतालीस",
    "अड़तालीस",
    "उनचास",
    "पचास",
    "इक्यावन",
    "बावन",
    "तिरपन",
    "चौवन",
    "पचपन",
    "छप्पन",
    "सत्तावन",
    "अट्ठावन",
    "उनसठ",
    "साठ",
    "इकसठ",
    "बासठ",
    "तिरसठ",
    "चौंसठ",
    "पैंसठ",
    "छियासठ",
    "सड़सठ",
    "अड़सठ",
    "उनहत्तर",
    "सत्तर",
    "इकहत्तर",
    "बहत्तर",
    "तिहत्तर",
    "चौहत्तर",
    "पचहत्तर",
    "छिहत्तर",
    "सतहत्तर",
    "अठहत्तर",
    "उनासी",
    "अस्सी",
    "इक्यासी",
    "बयासी",
    "तिरासी",
    "चौरासी",
    "पचासी",
    "छियासी",
    "सत्तासी",
    "अट्ठासी",
    "नवासी",
    "नब्बे",
    "इक्यानबे",
    "बयानबे",
    "तिरानबे",
    "चौरानबे",
    "पचानबे",
    "छियानबे",
    "सत्तानबे",
    "अट्ठानबे",
    "निन्यानबे",
  ];

  static String convert(double amount, {String suffix = "रुपया मात्र"}) {
    int val = amount.round();
    if (val == 0) return "शून्य $suffix";

    String result = "";

    int crore = val ~/ 10000000;
    val %= 10000000;
    if (crore > 0) result += "${_words0To99[crore]} करोड़ ";

    int lakh = val ~/ 100000;
    val %= 100000;
    if (lakh > 0) result += "${_words0To99[lakh]} लाख ";

    int thousand = val ~/ 1000;
    val %= 1000;
    if (thousand > 0) result += "${_words0To99[thousand]} हजार ";

    int hundred = val ~/ 100;
    val %= 100;
    if (hundred > 0) result += "${_words0To99[hundred]} सौ ";

    if (val > 0) result += _words0To99[val];

    return "कुल ${result.trim()} $suffix";
  }
}

class CottonReportScreen extends StatefulWidget {
  const CottonReportScreen({super.key});

  @override
  State<CottonReportScreen> createState() => _CottonReportScreenState();
}

class _CottonReportScreenState extends State<CottonReportScreen> {
  List<Map<String, dynamic>> _allEntries = [];
  List<Map<String, dynamic>> _filteredEntries = [];

  bool _isLoading = true;
  DateTime _selectedMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    final data = await SheetsService.getAllCottonEntries();
    if (!mounted) return;
    setState(() {
      _allEntries = data;
      _filterByMonth();
      _isLoading = false;
    });
  }

  void _filterByMonth() {
    setState(() {
      _filteredEntries = _allEntries.where((entry) {
        String dateStr = (entry['date'] ?? '').toString().trim();
        if (dateStr.isEmpty) return false;

        DateTime? rowDate;

        // 1. Google Sheets 5-Digit Serial Number Fix (e.g. 45123 -> Date)
        if (int.tryParse(dateStr) != null && dateStr.length == 5) {
          rowDate = DateTime(
            1899,
            12,
            30,
          ).add(Duration(days: int.parse(dateStr)));
        } else {
          // 2. Strict DD/MM/YYYY Parsing with fallbacks
          try {
            rowDate = DateFormat('dd/MM/yyyy').parseStrict(dateStr);
          } catch (_) {
            try {
              rowDate = DateFormat('MM/dd/yyyy').parseStrict(dateStr);
            } catch (_) {
              try {
                rowDate = DateFormat('yyyy-MM-dd').parseStrict(dateStr);
              } catch (_) {
                rowDate = DateTime.tryParse(dateStr);
              }
            }
          }
        }

        if (rowDate == null) return false;

        // 3. FORCE PERFECT FORMATTING:
        // This permanently overwrites whatever mess was in Google Sheets
        // to a strict DD/MM/YYYY string for the PDF, Excel, and UI to use!
        entry['date'] = DateFormat('dd/MM/yyyy').format(rowDate);

        // 4. Check if it belongs to the selected month
        return rowDate.month == _selectedMonth.month &&
            rowDate.year == _selectedMonth.year;
      }).toList();
    });
  }

  Future<void> _pickMonth() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      // Set to selectable by month-level visualization
      initialDatePickerMode: DatePickerMode.year,
    );
    if (picked != null &&
        (picked.month != _selectedMonth.month ||
            picked.year != _selectedMonth.year)) {
      setState(() {
        _selectedMonth = picked;
        _filterByMonth();
      });
    }
  }

  // ==========================================
  // RETINA HINDI SHAPER FOR PDF
  // ==========================================
  Future<pw.Widget> _buildHindiText(
    String text, {
    double fontSize = 12,
    bool isBold = false,
    pw.TextAlign align = pw.TextAlign.left,
  }) async {
    if (text.trim().isEmpty) return pw.SizedBox(height: fontSize);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const double scale = 3.0; // 300 DPI sharpness
    final scaledFontSize = fontSize * scale;

    final textSpan = TextSpan(
      text: text,
      style: TextStyle(
        fontSize: scaledFontSize,
        fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
        color: Colors.black,
      ),
    );

    final textPainter = TextPainter(
      text: textSpan,
      // FIX: Added 'ui.' prefix to bypass the intl package conflict
      textDirection: ui.TextDirection.ltr,
    );

    textPainter.layout();
    textPainter.paint(canvas, Offset.zero);

    final picture = recorder.endRecording();
    final img = await picture.toImage(
      textPainter.width.ceil(),
      textPainter.height.ceil(),
    );
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

    return pw.Container(
      alignment: align == pw.TextAlign.center
          ? pw.Alignment.center
          : (align == pw.TextAlign.right
                ? pw.Alignment.centerRight
                : pw.Alignment.centerLeft),
      child: pw.Image(
        pw.MemoryImage(byteData!.buffer.asUint8List()),
        width: textPainter.width / scale,
        height: textPainter.height / scale,
        fit: pw.BoxFit.fill,
      ),
    );
  }

  // ==========================================
  // EXPORT TO PDF (A4 LANDSCAPE WITH 2-INCH MARGIN)
  // ==========================================
  Future<void> _exportToPdf() async {
    if (_filteredEntries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No data to export for this month.')),
      );
      return;
    }

    final pdf = pw.Document();
    final font = await PdfGoogleFonts.tiroDevanagariHindiRegular();
    final boldFont = await PdfGoogleFonts.tiroDevanagariHindiRegular();

    double totalSutWeight = 0.0;
    double totalPuniWeight = 0.0;
    double totalAmount = 0.0;
    final List<List<dynamic>> tableData = [];

    for (int i = 0; i < _filteredEntries.length; i++) {
      var row = _filteredEntries[i];
      double sutWt =
          double.tryParse(
            (row['sutWeight'] ?? '0').toString().replaceAll(
              RegExp(r'[^0-9.-]'),
              '',
            ),
          ) ??
          0.0;
      double puniWt =
          double.tryParse(
            (row['puniWeight'] ?? '0').toString().replaceAll(
              RegExp(r'[^0-9.-]'),
              '',
            ),
          ) ??
          0.0;
      double amt =
          double.tryParse(
            (row['finalAmount'] ?? '0').toString().replaceAll(
              RegExp(r'[^0-9.-]'),
              '',
            ),
          ) ??
          0.0;

      totalSutWeight += sutWt;
      totalPuniWeight += puniWt;
      totalAmount += amt;

      tableData.add([
        row['date'] ?? '',
        row['workerName'] ?? '',
        row['rollNo'] ?? '',
        row['gundiSankhya'] ?? '',
        sutWt > 0 ? sutWt.toStringAsFixed(3) : '-',
        puniWt > 0 ? puniWt.toStringAsFixed(3) : '-',
        amt.toStringAsFixed(2),
      ]);
    }

    String monthYearStr = DateFormat('MMMM yyyy').format(_selectedMonth);
    String hindiWords = HindiWordsConverter.convert(totalAmount);

    final titleImg = await _buildHindiText(
      "ग्रामोद्योग सेवा संस्थान",
      fontSize: 18,
      isBold: true,
      align: pw.TextAlign.center,
    );
    final subTitleImg = await _buildHindiText(
      "इटौरा, अदौना – मऊ",
      fontSize: 14,
      align: pw.TextAlign.center,
    );
    final reportTitleImg = await _buildHindiText(
      "सूत-पूनी खरीद रिपोर्ट (माह: $monthYearStr)",
      fontSize: 14,
      isBold: true,
      align: pw.TextAlign.center,
    );

    final footerTitleImg = await _buildHindiText(
      "कुल विवरण:",
      fontSize: 12,
      isBold: true,
    );
    final footerSutImg = await _buildHindiText(
      "कुल सूत वजन: ${totalSutWeight.toStringAsFixed(3)} किग्रा",
      fontSize: 12,
    );
    final footerPuniImg = await _buildHindiText(
      "कुल पूनी वजन: ${totalPuniWeight.toStringAsFixed(3)} किग्रा",
      fontSize: 12,
    );
    final footerWordsImg = await _buildHindiText(
      "कुल देय राशि: ₹${totalAmount.toStringAsFixed(2)} ( $hindiWords )",
      fontSize: 12,
      isBold: true,
    );

    pdf.addPage(
      pw.MultiPage(
        // Using Landscape so all 7 important columns fit nicely
        pageFormat: PdfPageFormat.a4.landscape,
        // 144 points = Exactly 2 Inches from the top for Letterhead!
        margin: const pw.EdgeInsets.only(
          top: 144,
          bottom: 36,
          left: 36,
          right: 36,
        ),
        theme: pw.ThemeData.withFont(base: font, bold: boldFont),
        build: (context) => [
          titleImg,
          pw.SizedBox(height: 2),
          subTitleImg,
          pw.SizedBox(height: 12),
          reportTitleImg,
          pw.SizedBox(height: 20),

          pw.TableHelper.fromTextArray(
            border: pw.TableBorder.all(width: 1, color: PdfColors.black),
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 11,
            ),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
            cellStyle: const pw.TextStyle(fontSize: 10),
            cellHeight: 22,
            cellAlignments: {
              0: pw.Alignment.center,
              1: pw.Alignment.centerLeft,
              2: pw.Alignment.center,
              3: pw.Alignment.centerRight,
              4: pw.Alignment.centerRight,
              5: pw.Alignment.centerRight,
              6: pw.Alignment.centerRight,
            },
            headers: [
              'Date',
              'Worker Name',
              'Roll No.',
              'Gundi',
              'Sut Wt (Kg)',
              'Puni Wt (Kg)',
              'Amount (₹)',
            ],
            columnWidths: {
              0: const pw.FlexColumnWidth(1.2),
              1: const pw.FlexColumnWidth(2.5),
              2: const pw.FlexColumnWidth(1.0),
              3: const pw.FlexColumnWidth(1.0),
              4: const pw.FlexColumnWidth(1.2),
              5: const pw.FlexColumnWidth(1.2),
              6: const pw.FlexColumnWidth(1.5),
            },
            data: tableData,
          ),

          pw.SizedBox(height: 20),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.black),
              color: PdfColors.grey100,
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                footerTitleImg,
                pw.SizedBox(height: 8),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [footerSutImg, footerPuniImg],
                ),
                pw.SizedBox(height: 8),
                footerWordsImg,
              ],
            ),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name:
          'Cotton_Report_${DateFormat('MMM_yyyy').format(_selectedMonth)}.pdf',
      format: PdfPageFormat.a4.landscape,
    );
  }

  // ==========================================
  // EXPORT TO EXCEL
  // ==========================================
  Future<void> _exportToExcel() async {
    if (_filteredEntries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No data to export for this month.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      var excelFile = excel.Excel.createExcel();
      excel.Sheet sheet = excelFile['Monthly Report'];
      excelFile.setDefaultSheet('Monthly Report');

      sheet.setColumnWidth(0, 12.0);
      sheet.setColumnWidth(1, 25.0);
      sheet.setColumnWidth(2, 10.0);
      sheet.setColumnWidth(3, 10.0);
      sheet.setColumnWidth(4, 15.0);
      sheet.setColumnWidth(5, 15.0);
      sheet.setColumnWidth(6, 18.0);

      var borderStyle = excel.Border(borderStyle: excel.BorderStyle.Thin);
      String hindiFont = 'Nirmala UI';

      var boldCenter = excel.CellStyle(
        bold: true,
        horizontalAlign: excel.HorizontalAlign.Center,
        fontSize: 16,
        fontFamily: hindiFont,
      );
      var normalCenter = excel.CellStyle(
        horizontalAlign: excel.HorizontalAlign.Center,
        fontSize: 12,
        fontFamily: hindiFont,
      );
      var boldHeader = excel.CellStyle(
        bold: true,
        horizontalAlign: excel.HorizontalAlign.Center,
        fontSize: 11,
        fontFamily: hindiFont,
        leftBorder: borderStyle,
        rightBorder: borderStyle,
        topBorder: borderStyle,
        bottomBorder: borderStyle,
      );
      var borderCell = excel.CellStyle(
        fontSize: 11,
        fontFamily: hindiFont,
        leftBorder: borderStyle,
        rightBorder: borderStyle,
        topBorder: borderStyle,
        bottomBorder: borderStyle,
      );
      var rightBorderCell = excel.CellStyle(
        fontSize: 11,
        horizontalAlign: excel.HorizontalAlign.Right,
        fontFamily: hindiFont,
        leftBorder: borderStyle,
        rightBorder: borderStyle,
        topBorder: borderStyle,
        bottomBorder: borderStyle,
      );
      var boldBorderRight = excel.CellStyle(
        bold: true,
        fontSize: 11,
        horizontalAlign: excel.HorizontalAlign.Right,
        fontFamily: hindiFont,
        leftBorder: borderStyle,
        rightBorder: borderStyle,
        topBorder: borderStyle,
        bottomBorder: borderStyle,
      );

      // Headers
      sheet.merge(
        excel.CellIndex.indexByString("A1"),
        excel.CellIndex.indexByString("G1"),
      );
      sheet.updateCell(
        excel.CellIndex.indexByString("A1"),
        excel.TextCellValue("ग्रामोद्योग सेवा संस्थान"),
        cellStyle: boldCenter,
      );

      sheet.merge(
        excel.CellIndex.indexByString("A2"),
        excel.CellIndex.indexByString("G2"),
      );
      sheet.updateCell(
        excel.CellIndex.indexByString("A2"),
        excel.TextCellValue("इटौरा, अदौना – मऊ"),
        cellStyle: normalCenter,
      );

      String monthYearStr = DateFormat('MMMM yyyy').format(_selectedMonth);
      sheet.merge(
        excel.CellIndex.indexByString("A3"),
        excel.CellIndex.indexByString("G3"),
      );
      sheet.updateCell(
        excel.CellIndex.indexByString("A3"),
        excel.TextCellValue("सूत-पूनी खरीद रिपोर्ट (माह: $monthYearStr)"),
        cellStyle: boldCenter,
      );

      List<String> headers = [
        'Date',
        'Worker Name',
        'Roll No.',
        'Gundi',
        'Sut Wt (Kg)',
        'Puni Wt (Kg)',
        'Amount (₹)',
      ];
      for (int i = 0; i < headers.length; i++) {
        sheet.updateCell(
          excel.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 4),
          excel.TextCellValue(headers[i]),
          cellStyle: boldHeader,
        );
      }

      double totalSutWeight = 0.0;
      double totalPuniWeight = 0.0;
      double totalAmount = 0.0;

      int currentRow = 5;
      for (var row in _filteredEntries) {
        double sutWt =
            double.tryParse(
              (row['sutWeight'] ?? '0').toString().replaceAll(
                RegExp(r'[^0-9.-]'),
                '',
              ),
            ) ??
            0.0;
        double puniWt =
            double.tryParse(
              (row['puniWeight'] ?? '0').toString().replaceAll(
                RegExp(r'[^0-9.-]'),
                '',
              ),
            ) ??
            0.0;
        double amt =
            double.tryParse(
              (row['finalAmount'] ?? '0').toString().replaceAll(
                RegExp(r'[^0-9.-]'),
                '',
              ),
            ) ??
            0.0;

        totalSutWeight += sutWt;
        totalPuniWeight += puniWt;
        totalAmount += amt;

        sheet.updateCell(
          excel.CellIndex.indexByColumnRow(
            columnIndex: 0,
            rowIndex: currentRow,
          ),
          excel.TextCellValue(row['date'] ?? ''),
          cellStyle: borderCell,
        );
        sheet.updateCell(
          excel.CellIndex.indexByColumnRow(
            columnIndex: 1,
            rowIndex: currentRow,
          ),
          excel.TextCellValue(row['workerName'] ?? ''),
          cellStyle: borderCell,
        );
        sheet.updateCell(
          excel.CellIndex.indexByColumnRow(
            columnIndex: 2,
            rowIndex: currentRow,
          ),
          excel.TextCellValue(row['rollNo'] ?? ''),
          cellStyle: borderCell,
        );
        sheet.updateCell(
          excel.CellIndex.indexByColumnRow(
            columnIndex: 3,
            rowIndex: currentRow,
          ),
          excel.TextCellValue(row['gundiSankhya'] ?? ''),
          cellStyle: rightBorderCell,
        );
        sheet.updateCell(
          excel.CellIndex.indexByColumnRow(
            columnIndex: 4,
            rowIndex: currentRow,
          ),
          excel.DoubleCellValue(sutWt),
          cellStyle: rightBorderCell,
        );
        sheet.updateCell(
          excel.CellIndex.indexByColumnRow(
            columnIndex: 5,
            rowIndex: currentRow,
          ),
          excel.DoubleCellValue(puniWt),
          cellStyle: rightBorderCell,
        );
        sheet.updateCell(
          excel.CellIndex.indexByColumnRow(
            columnIndex: 6,
            rowIndex: currentRow,
          ),
          excel.DoubleCellValue(amt),
          cellStyle: rightBorderCell,
        );
        currentRow++;
      }

      // Totals
      sheet.merge(
        excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow),
        excel.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: currentRow),
      );
      sheet.updateCell(
        excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow),
        excel.TextCellValue("कुल योग (TOTAL)"),
        cellStyle: boldBorderRight,
      );
      sheet.updateCell(
        excel.CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: currentRow),
        excel.DoubleCellValue(totalSutWeight),
        cellStyle: boldBorderRight,
      );
      sheet.updateCell(
        excel.CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: currentRow),
        excel.DoubleCellValue(totalPuniWeight),
        cellStyle: boldBorderRight,
      );
      sheet.updateCell(
        excel.CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: currentRow),
        excel.DoubleCellValue(totalAmount),
        cellStyle: boldBorderRight,
      );
      currentRow++;

      String hindiWords = HindiWordsConverter.convert(totalAmount);
      sheet.merge(
        excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow),
        excel.CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: currentRow),
      );
      sheet.updateCell(
        excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow),
        excel.TextCellValue(hindiWords),
        cellStyle: boldCenter,
      );

      var bytes = excelFile.save();
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Report Excel',
        fileName:
            'Cotton_Report_${DateFormat('MMM_yyyy').format(_selectedMonth)}.xlsx',
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );

      if (outputFile != null) {
        if (!outputFile.endsWith('.xlsx')) outputFile += '.xlsx';
        File(outputFile)
          ..createSync(recursive: true)
          ..writeAsBytesSync(bytes!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Saved to: $outputFile'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export Failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    double totalSutWeight = 0.0;
    double totalPuniWeight = 0.0;
    double totalAmount = 0.0;

    for (var r in _filteredEntries) {
      totalSutWeight +=
          double.tryParse(
            (r['sutWeight'] ?? '0').toString().replaceAll(
              RegExp(r'[^0-9.-]'),
              '',
            ),
          ) ??
          0.0;
      totalPuniWeight +=
          double.tryParse(
            (r['puniWeight'] ?? '0').toString().replaceAll(
              RegExp(r'[^0-9.-]'),
              '',
            ),
          ) ??
          0.0;
      totalAmount +=
          double.tryParse(
            (r['finalAmount'] ?? '0').toString().replaceAll(
              RegExp(r'[^0-9.-]'),
              '',
            ),
          ) ??
          0.0;
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Cotton-Sut Kharid Reports',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Control Panel
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_month, color: Colors.teal),
                  label: Text(
                    'Month: ${DateFormat('MMMM yyyy').format(_selectedMonth)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.teal,
                      fontSize: 16,
                    ),
                  ),
                  onPressed: _pickMonth,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                  ),
                ),
                const Spacer(),
                OutlinedButton.icon(
                  icon: const Icon(Icons.picture_as_pdf, color: Colors.red),
                  label: const Text(
                    'Export PDF',
                    style: TextStyle(color: Colors.red),
                  ),
                  onPressed: _exportToPdf,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  icon: const Icon(Icons.table_chart),
                  label: const Text('Export Excel'),
                  onPressed: _exportToExcel,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          // Stats Summary Bar
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            color: Colors.teal.shade50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('Records', _filteredEntries.length.toString()),
                _buildStatItem(
                  'Total Sut',
                  '${totalSutWeight.toStringAsFixed(2)} Kg',
                ),
                _buildStatItem(
                  'Total Puni',
                  '${totalPuniWeight.toStringAsFixed(2)} Kg',
                ),
                _buildStatItem(
                  'Total Amount',
                  '₹ ${totalAmount.toStringAsFixed(2)}',
                  isCurrency: true,
                ),
              ],
            ),
          ),

          // Data Table
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredEntries.isEmpty
                ? Center(
                    child: Text(
                      'No records found for ${DateFormat('MMMM yyyy').format(_selectedMonth)}.',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 16,
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      PaginatedDataTable(
                        header: const Text('Monthly Entries'),
                        rowsPerPage: _filteredEntries.length > 10
                            ? 10
                            : (_filteredEntries.isEmpty
                                  ? 1
                                  : _filteredEntries.length),
                        columns: const [
                          DataColumn(
                            label: Text(
                              'Date',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Name',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Roll No.',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Sut Wt',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            numeric: true,
                          ),
                          DataColumn(
                            label: Text(
                              'Puni Wt',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            numeric: true,
                          ),
                          DataColumn(
                            label: Text(
                              'Amount',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            numeric: true,
                          ),
                        ],
                        source: _CottonDataSource(_filteredEntries),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, {bool isCurrency = false}) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.teal.shade800,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: isCurrency ? Colors.green.shade700 : Colors.black87,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _CottonDataSource extends DataTableSource {
  final List<Map<String, dynamic>> _data;
  _CottonDataSource(this._data);

  @override
  DataRow? getRow(int index) {
    if (index >= _data.length) return null;
    final row = _data[index];
    return DataRow(
      cells: [
        DataCell(Text(row['date'] ?? '')),
        DataCell(
          Text(
            row['workerName'] ?? '',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        DataCell(Text(row['rollNo'] ?? '')),
        DataCell(Text(row['sutWeight'] ?? '')),
        DataCell(Text(row['puniWeight'] ?? '')),
        DataCell(
          Text(
            '₹ ${row['finalAmount'] ?? ''}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
        ),
      ],
    );
  }

  @override
  bool get isRowCountApproximate => false;
  @override
  int get rowCount => _data.length;
  @override
  int get selectedRowCount => 0;
}
