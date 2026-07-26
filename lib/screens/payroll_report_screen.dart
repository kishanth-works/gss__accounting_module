// ignore_for_file: use_build_context_synchronously
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:excel/excel.dart' as excel;
import 'package:file_picker/file_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../services/sheets_service.dart';

// ==========================================
// 1. HINDI NUMBER TO WORDS ENGINE
// ==========================================
class HindiAmountWords {
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

  static String convert(double amount) {
    int val = amount.round();
    if (val == 0) return "शून्य रुपया मात्र";

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

    return "कुल ${result.trim()} रुपया मात्र";
  }
}

// ==========================================
// 2. PAYROLL REPORT SCREEN (BATCH VIEW)
// ==========================================
class PayrollReportScreen extends StatefulWidget {
  const PayrollReportScreen({super.key});

  @override
  State<PayrollReportScreen> createState() => _PayrollReportScreenState();
}

class _PayrollReportScreenState extends State<PayrollReportScreen> {
  List<Map<String, dynamic>> _allEntries = [];
  Map<String, List<Map<String, dynamic>>> _groupedBatches = {};
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    final data = await SheetsService.getPayrollEntries();
    if (!mounted) return;
    setState(() {
      _allEntries = data;
      _groupData();
      _isLoading = false;
    });
  }

  void _groupData() {
    Map<String, List<Map<String, dynamic>>> temp = {};
    for (var entry in _allEntries) {
      String cheque = (entry['chequeNo'] ?? '').toString().trim();
      String date = (entry['date'] ?? '').toString().trim();
      String key = "$cheque|$date";

      if (_searchQuery.isNotEmpty) {
        bool match =
            cheque.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            date.contains(_searchQuery) ||
            (entry['name'] ?? '').toString().toLowerCase().contains(
              _searchQuery.toLowerCase(),
            );
        if (!match) continue;
      }

      if (!temp.containsKey(key)) temp[key] = [];
      temp[key]!.add(entry);
    }
    _groupedBatches = temp;
  }

  // ==========================================
  // 3. INTERACTIVE BATCH EDITOR (MOBILE RESPONSIVE)
  // ==========================================
  void _showBatchEditDialog(
    String batchKey,
    List<Map<String, dynamic>> entries,
  ) {
    List<String> parts = batchKey.split('|');
    String chequeNo = parts[0];
    String date = parts.length > 1 ? parts[1] : '';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Edit Chq #$chequeNo',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    'Date: $date',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ],
              ),
              // RESPONSIVE UPGRADE: Dynamically fills 95% width on mobile screens
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.95,
                height: MediaQuery.of(context).size.height * 0.7,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      color: Colors.indigo.shade50,
                      child: const Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: Text(
                              'Name',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              'A/C No.',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              'Amount (₹)',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          SizedBox(width: 36),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: entries.length,
                        itemBuilder: (context, idx) {
                          final item = entries[idx];
                          TextEditingController amtCtrl = TextEditingController(
                            text: item['amount'],
                          );
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Text(
                                    item['name'] ?? '',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    item['ac'] ?? '',
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: TextField(
                                    controller: amtCtrl,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      border: OutlineInputBorder(),
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 8,
                                      ),
                                      isDense: true,
                                    ),
                                    onSubmitted: (newVal) async {
                                      setState(() => _isLoading = true);
                                      item['amount'] = newVal;
                                      List<dynamic> updatedRow = [
                                        item['date'],
                                        item['chequeNo'],
                                        item['name'],
                                        item['bank'],
                                        item['ifsc'],
                                        item['ac'],
                                        newVal,
                                      ];
                                      await SheetsService.updatePayrollEntry(
                                        item['_rowIndex'],
                                        updatedRow,
                                      );
                                      _fetchData();
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text('Amount Updated'),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                    size: 20,
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  tooltip: 'Remove from Batch',
                                  onPressed: () async {
                                    setState(() => _isLoading = true);
                                    await SheetsService.deletePayrollEntry(
                                      item['_rowIndex'],
                                    );
                                    Navigator.pop(context);
                                    _fetchData();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Employee removed from batch',
                                        ),
                                        backgroundColor: Colors.orange,
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Done Editing'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ==========================================
  // 4. RETINA HINDI SHAPER FOR PDF
  // ==========================================
  Future<pw.Widget> _buildHindiText(
    String text, {
    double fontSize = 12,
    bool isBold = false,
    pw.TextAlign align = pw.TextAlign.left,
  }) async {
    if (text.trim().isEmpty) {
      return pw.SizedBox(height: fontSize);
    }

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    const double scale = 3.0;
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
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();
    textPainter.paint(canvas, Offset.zero);

    final picture = recorder.endRecording();
    final img = await picture.toImage(
      textPainter.width.ceil(),
      textPainter.height.ceil(),
    );
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

    final memoryImage = pw.MemoryImage(byteData!.buffer.asUint8List());

    return pw.Container(
      alignment: align == pw.TextAlign.center
          ? pw.Alignment.center
          : (align == pw.TextAlign.right
                ? pw.Alignment.centerRight
                : pw.Alignment.centerLeft),
      child: pw.Image(
        memoryImage,
        width: textPainter.width / scale,
        height: textPainter.height / scale,
        fit: pw.BoxFit.fill,
      ),
    );
  }

  // ==========================================
  // 5. HINDI PDF GENERATOR (2-INCH TOP MARGIN)
  // ==========================================
  Future<void> _exportBatchToPdf(
    String chequeNo,
    String date,
    List<Map<String, dynamic>> entries,
  ) async {
    final pdf = pw.Document();

    double totalAmount = 0.0;
    final List<List<dynamic>> tableData = [];

    for (int i = 0; i < entries.length; i++) {
      var row = entries[i];
      double amt =
          double.tryParse(
            (row['amount'] ?? '0').toString().replaceAll(
              RegExp(r'[^0-9.-]'),
              '',
            ),
          ) ??
          0.0;
      totalAmount += amt;

      tableData.add([
        (i + 1).toString(),
        row['name'] ?? '',
        row['bank'] ?? '',
        row['ifsc'] ?? '',
        row['ac'] ?? '',
        amt.toStringAsFixed(2),
      ]);
    }

    String hindiWords = HindiAmountWords.convert(totalAmount);
    String formattedTotal = totalAmount.toStringAsFixed(0);

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

    final sevaMeImg = await _buildHindiText("सेवा में,", fontSize: 12);
    final shrimanImg = await _buildHindiText(
      "श्री मान् शाखा प्रबंधक",
      fontSize: 12,
    );
    final bankImg = await _buildHindiText(
      "यूनियन बैंक आफ इंडिया",
      fontSize: 12,
    );
    final shakhaImg = await _buildHindiText(
      "शाखा – करहाँ, जनपद – मऊ",
      fontSize: 12,
    );
    final mahodayImg = await _buildHindiText("महोदय,", fontSize: 12);

    final line1Img = await _buildHindiText(
      "सादर अवगत कराना है कि संस्था के चेक नं0–$chequeNo दि0. $date",
      fontSize: 12,
      align: pw.TextAlign.center,
    );
    final line2Img = await _buildHindiText(
      "धनराशि रू0–$formattedTotal=00 ( $hindiWords ) की रकम",
      fontSize: 12,
      align: pw.TextAlign.center,
    );
    final line3Img = await _buildHindiText(
      "संस्था के कारीगर के खातों में हस्तांतरण करने की कृपा करें।",
      fontSize: 12,
      align: pw.TextAlign.center,
    );

    final footerWordsImg = await _buildHindiText(
      hindiWords,
      fontSize: 11,
      isBold: true,
      align: pw.TextAlign.center,
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.portrait,
        margin: const pw.EdgeInsets.only(
          top: 144,
          bottom: 36,
          left: 36,
          right: 36,
        ),
        build: (context) => [
          titleImg,
          pw.SizedBox(height: 2),
          subTitleImg,
          pw.SizedBox(height: 12),

          pw.Padding(
            padding: const pw.EdgeInsets.only(left: 30),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                sevaMeImg,
                pw.Padding(
                  padding: const pw.EdgeInsets.only(left: 20),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      shrimanImg,
                      pw.SizedBox(height: 2),
                      bankImg,
                      pw.SizedBox(height: 2),
                      shakhaImg,
                    ],
                  ),
                ),
                pw.SizedBox(height: 6),
                mahodayImg,
              ],
            ),
          ),

          pw.SizedBox(height: 6),
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                line1Img,
                pw.SizedBox(height: 3),
                line2Img,
                pw.SizedBox(height: 3),
                line3Img,
              ],
            ),
          ),
          pw.SizedBox(height: 16),

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
              2: pw.Alignment.centerLeft,
              3: pw.Alignment.centerLeft,
              4: pw.Alignment.centerLeft,
              5: pw.Alignment.centerRight,
            },
            headers: ['S.N.', 'Name', 'Bank', 'IFSC Code', 'A/C No.', 'Amount'],
            columnWidths: {
              0: const pw.FlexColumnWidth(0.8),
              1: const pw.FlexColumnWidth(2.5),
              2: const pw.FlexColumnWidth(1.2),
              3: const pw.FlexColumnWidth(2.0),
              4: const pw.FlexColumnWidth(2.5),
              5: const pw.FlexColumnWidth(1.5),
            },
            data: tableData,
          ),

          pw.Table(
            border: pw.TableBorder.all(width: 1, color: PdfColors.black),
            columnWidths: {
              0: const pw.FlexColumnWidth(9.0),
              1: const pw.FlexColumnWidth(1.5),
            },
            children: [
              pw.TableRow(
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: footerWordsImg,
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(
                      "${totalAmount.toStringAsFixed(2)}  ",
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 11,
                      ),
                      textAlign: pw.TextAlign.right,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Bank_Transfer_Chq_$chequeNo.pdf',
      format: PdfPageFormat.a4.portrait,
    );
  }

  // ==========================================
  // 6. HINDI EXCEL GENERATOR
  // ==========================================
  Future<void> _exportBatchToExcel(
    String chequeNo,
    String date,
    List<Map<String, dynamic>> entries,
  ) async {
    setState(() => _isLoading = true);
    try {
      var excelFile = excel.Excel.createExcel();
      excel.Sheet sheet = excelFile['Bank Transfer Mandate'];
      excelFile.setDefaultSheet('Bank Transfer Mandate');

      sheet.setColumnWidth(0, 8.0);
      sheet.setColumnWidth(1, 25.0);
      sheet.setColumnWidth(2, 12.0);
      sheet.setColumnWidth(3, 18.0);
      sheet.setColumnWidth(4, 22.0);
      sheet.setColumnWidth(5, 15.0);

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
      var boldBorderCenter = excel.CellStyle(
        bold: true,
        fontSize: 11,
        horizontalAlign: excel.HorizontalAlign.Center,
        fontFamily: hindiFont,
        leftBorder: borderStyle,
        rightBorder: borderStyle,
        topBorder: borderStyle,
        bottomBorder: borderStyle,
      );

      sheet.merge(
        excel.CellIndex.indexByString("A2"),
        excel.CellIndex.indexByString("F2"),
      );
      sheet.updateCell(
        excel.CellIndex.indexByString("A2"),
        excel.TextCellValue("ग्रामोद्योग सेवा संस्थान"),
        cellStyle: boldCenter,
      );

      sheet.merge(
        excel.CellIndex.indexByString("A3"),
        excel.CellIndex.indexByString("F3"),
      );
      sheet.updateCell(
        excel.CellIndex.indexByString("A3"),
        excel.TextCellValue("इटौरा, अदौना – मऊ"),
        cellStyle: normalCenter,
      );

      sheet.updateCell(
        excel.CellIndex.indexByString("B4"),
        excel.TextCellValue("सेवा में,"),
        cellStyle: borderCell,
      );
      sheet.updateCell(
        excel.CellIndex.indexByString("C5"),
        excel.TextCellValue("श्री मान् शाखा प्रबंधक"),
        cellStyle: borderCell,
      );
      sheet.updateCell(
        excel.CellIndex.indexByString("C6"),
        excel.TextCellValue("यूनियन बैंक आफ इंडिया"),
        cellStyle: borderCell,
      );
      sheet.updateCell(
        excel.CellIndex.indexByString("C7"),
        excel.TextCellValue("शाखा – करहाँ, जनपद – मऊ"),
        cellStyle: borderCell,
      );
      sheet.updateCell(
        excel.CellIndex.indexByString("B8"),
        excel.TextCellValue("महोदय,"),
        cellStyle: borderCell,
      );

      double totalAmount = 0.0;
      for (var r in entries) {
        totalAmount +=
            double.tryParse(
              (r['amount'] ?? '0').toString().replaceAll(
                RegExp(r'[^0-9.-]'),
                '',
              ),
            ) ??
            0.0;
      }
      String hindiWords = HindiAmountWords.convert(totalAmount);
      String formattedTotal = totalAmount.toStringAsFixed(0);

      sheet.merge(
        excel.CellIndex.indexByString("A9"),
        excel.CellIndex.indexByString("F9"),
      );
      sheet.updateCell(
        excel.CellIndex.indexByString("A9"),
        excel.TextCellValue(
          "     सादर अवगत कराना है कि संस्था के चेक नं0–$chequeNo दि0. $date",
        ),
        cellStyle: normalCenter,
      );

      sheet.merge(
        excel.CellIndex.indexByString("A10"),
        excel.CellIndex.indexByString("F10"),
      );
      sheet.updateCell(
        excel.CellIndex.indexByString("A10"),
        excel.TextCellValue(
          "धनराशि रू0–$formattedTotal=00 ( $hindiWords ) की रकम",
        ),
        cellStyle: normalCenter,
      );

      sheet.merge(
        excel.CellIndex.indexByString("A11"),
        excel.CellIndex.indexByString("F11"),
      );
      sheet.updateCell(
        excel.CellIndex.indexByString("A11"),
        excel.TextCellValue(
          "संस्था के कारीगर के खातों में हस्तांतरण करने की कृपा करें।",
        ),
        cellStyle: normalCenter,
      );

      List<String> headers = [
        'S.N.',
        'Name',
        'Bank',
        'IFSC Code',
        'A/C No.',
        'Amount',
      ];
      for (int i = 0; i < headers.length; i++) {
        sheet.updateCell(
          excel.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 11),
          excel.TextCellValue(headers[i]),
          cellStyle: boldHeader,
        );
      }

      int currentRow = 12;
      for (int i = 0; i < entries.length; i++) {
        var row = entries[i];
        double amt =
            double.tryParse(
              (row['amount'] ?? '0').toString().replaceAll(
                RegExp(r'[^0-9.-]'),
                '',
              ),
            ) ??
            0.0;

        sheet.updateCell(
          excel.CellIndex.indexByColumnRow(
            columnIndex: 0,
            rowIndex: currentRow,
          ),
          excel.IntCellValue(i + 1),
          cellStyle: borderCell,
        );
        sheet.updateCell(
          excel.CellIndex.indexByColumnRow(
            columnIndex: 1,
            rowIndex: currentRow,
          ),
          excel.TextCellValue((row['name'] ?? '').toString().trim()),
          cellStyle: borderCell,
        );
        sheet.updateCell(
          excel.CellIndex.indexByColumnRow(
            columnIndex: 2,
            rowIndex: currentRow,
          ),
          excel.TextCellValue((row['bank'] ?? '').toString().trim()),
          cellStyle: borderCell,
        );
        sheet.updateCell(
          excel.CellIndex.indexByColumnRow(
            columnIndex: 3,
            rowIndex: currentRow,
          ),
          excel.TextCellValue((row['ifsc'] ?? '').toString().trim()),
          cellStyle: borderCell,
        );
        sheet.updateCell(
          excel.CellIndex.indexByColumnRow(
            columnIndex: 4,
            rowIndex: currentRow,
          ),
          excel.TextCellValue((row['ac'] ?? '').toString().trim()),
          cellStyle: borderCell,
        );
        sheet.updateCell(
          excel.CellIndex.indexByColumnRow(
            columnIndex: 5,
            rowIndex: currentRow,
          ),
          excel.DoubleCellValue(amt),
          cellStyle: rightBorderCell,
        );
        currentRow++;
      }

      sheet.merge(
        excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow),
        excel.CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: currentRow),
      );
      sheet.updateCell(
        excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow),
        excel.TextCellValue(hindiWords),
        cellStyle: boldBorderCenter,
      );
      sheet.updateCell(
        excel.CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: currentRow),
        excel.DoubleCellValue(totalAmount),
        cellStyle: boldBorderRight,
      );

      var bytes = excelFile.save();
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Bank Mandate Excel',
        fileName: 'Bank_Transfer_Chq_$chequeNo.xlsx',
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );

      if (outputFile != null) {
        if (!outputFile.endsWith('.xlsx')) {
          outputFile += '.xlsx';
        }
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

  // ==========================================
  // 7. BUILD BATCH CARD UI (MOBILE ADAPTIVE)
  // ==========================================
  @override
  Widget build(BuildContext context) {
    // RESPONSIVE BREAKPOINT: Dynamically stacks buttons on mobile screens (< 600px wide)
    final bool isMobile = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Payroll Batches (बैंक हस्तांतरण)',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.indigo.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Data',
            onPressed: _fetchData,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Search by Cheque No, Date, or Employee Name...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                fillColor: Colors.white,
                filled: true,
              ),
              onChanged: (val) => setState(() {
                _searchQuery = val;
                _groupData();
              }),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _groupedBatches.isEmpty
                ? const Center(child: Text('No payroll batches found.'))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    itemCount: _groupedBatches.length,
                    itemBuilder: (context, idx) {
                      String key = _groupedBatches.keys.elementAt(idx);
                      List<Map<String, dynamic>> entries =
                          _groupedBatches[key]!;

                      List<String> parts = key.split('|');
                      String chequeNo = parts[0];
                      String date = parts.length > 1 ? parts[1] : '';

                      double batchTotal = 0.0;
                      for (var e in entries) {
                        batchTotal +=
                            double.tryParse(
                              (e['amount'] ?? '0').toString().replaceAll(
                                RegExp(r'[^0-9.-]'),
                                '',
                              ),
                            ) ??
                            0.0;
                      }

                      return Card(
                        elevation: 3,
                        margin: const EdgeInsets.only(bottom: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.indigo.shade100),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _showBatchEditDialog(key, entries),
                          onLongPress: () => _showBatchEditDialog(key, entries),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          backgroundColor:
                                              Colors.indigo.shade100,
                                          child: const Icon(
                                            Icons.receipt_long,
                                            color: Colors.indigo,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              "Chq: #$chequeNo",
                                              style: const TextStyle(
                                                fontSize: 17,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.black87,
                                              ),
                                            ),
                                            Text(
                                              "Date: $date",
                                              style: TextStyle(
                                                color: Colors.grey.shade600,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.green.shade50,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: Colors.green.shade300,
                                        ),
                                      ),
                                      child: Text(
                                        "₹ ${batchTotal.toStringAsFixed(2)}",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: Colors.green.shade800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: 24),
                                // RESPONSIVE FOOTER: Stacks buttons vertically on narrow mobile phones
                                isMobile
                                    ? Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          Text(
                                            "${entries.length} Employees in this batch • (Tap to Edit)",
                                            style: TextStyle(
                                              color: Colors.indigo.shade600,
                                              fontWeight: FontWeight.w500,
                                              fontSize: 13,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                          const SizedBox(height: 12),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: OutlinedButton.icon(
                                                  icon: const Icon(
                                                    Icons.picture_as_pdf,
                                                    color: Colors.red,
                                                    size: 18,
                                                  ),
                                                  label: const Text(
                                                    "PDF Mandate",
                                                    style: TextStyle(
                                                      color: Colors.red,
                                                    ),
                                                  ),
                                                  style: OutlinedButton.styleFrom(
                                                    side: const BorderSide(
                                                      color: Colors.red,
                                                    ),
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          vertical: 12,
                                                        ),
                                                  ),
                                                  onPressed: () =>
                                                      _exportBatchToPdf(
                                                        chequeNo,
                                                        date,
                                                        entries,
                                                      ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: OutlinedButton.icon(
                                                  icon: const Icon(
                                                    Icons.table_chart,
                                                    color: Colors.green,
                                                    size: 18,
                                                  ),
                                                  label: const Text(
                                                    "Excel",
                                                    style: TextStyle(
                                                      color: Colors.green,
                                                    ),
                                                  ),
                                                  style: OutlinedButton.styleFrom(
                                                    side: const BorderSide(
                                                      color: Colors.green,
                                                    ),
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          vertical: 12,
                                                        ),
                                                  ),
                                                  onPressed: () =>
                                                      _exportBatchToExcel(
                                                        chequeNo,
                                                        date,
                                                        entries,
                                                      ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      )
                                    : Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            "${entries.length} Employees in this batch  •  (Long-press to Edit)",
                                            style: TextStyle(
                                              color: Colors.indigo.shade600,
                                              fontWeight: FontWeight.w500,
                                              fontSize: 13,
                                            ),
                                          ),
                                          Row(
                                            children: [
                                              OutlinedButton.icon(
                                                icon: const Icon(
                                                  Icons.picture_as_pdf,
                                                  color: Colors.red,
                                                  size: 18,
                                                ),
                                                label: const Text(
                                                  "PDF Mandate",
                                                  style: TextStyle(
                                                    color: Colors.red,
                                                  ),
                                                ),
                                                style: OutlinedButton.styleFrom(
                                                  side: const BorderSide(
                                                    color: Colors.red,
                                                  ),
                                                ),
                                                onPressed: () =>
                                                    _exportBatchToPdf(
                                                      chequeNo,
                                                      date,
                                                      entries,
                                                    ),
                                              ),
                                              const SizedBox(width: 10),
                                              OutlinedButton.icon(
                                                icon: const Icon(
                                                  Icons.table_chart,
                                                  color: Colors.green,
                                                  size: 18,
                                                ),
                                                label: const Text(
                                                  "Excel",
                                                  style: TextStyle(
                                                    color: Colors.green,
                                                  ),
                                                ),
                                                style: OutlinedButton.styleFrom(
                                                  side: const BorderSide(
                                                    color: Colors.green,
                                                  ),
                                                ),
                                                onPressed: () =>
                                                    _exportBatchToExcel(
                                                      chequeNo,
                                                      date,
                                                      entries,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
