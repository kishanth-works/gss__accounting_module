// ignore_for_file: use_build_context_synchronously

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart' as excel;
import 'package:file_picker/file_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../services/sheets_service.dart';

class LedgerScreen extends StatefulWidget {
  const LedgerScreen({super.key});

  @override
  State<LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends State<LedgerScreen> {
  DateTimeRange? _selectedDateRange;
  bool _isLoading = false;

  List<Map<String, dynamic>> _allTransactions = [];
  List<Map<String, dynamic>> _filteredTransactions = [];

  String _searchQuery = '';
  final List<String> _selectedAccountsFilter = [];
  String _selectedTypeFilter = 'All';
  List<String> _availableAccounts = [];

  @override
  void initState() {
    super.initState();
    _fetchTransactions();
  }

  Future<void> _fetchTransactions({bool isSilent = false}) async {
    if (!isSilent) {
      setState(() => _isLoading = true);
    }

    try {
      final rawRows = await SheetsService.getAllEntries();
      List<Map<String, dynamic>> parsedRows = [];
      Set<String> accountsSet = {};

      for (var row in rawRows) {
        try {
          String dateStr = row['Date'] ?? row['date'] ?? '';
          DateTime? rowDate;
          if (dateStr.isNotEmpty) {
            if (int.tryParse(dateStr) != null && dateStr.length == 5) {
              rowDate = DateTime(
                1899,
                12,
                30,
              ).add(Duration(days: int.parse(dateStr)));
            } else {
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
          }

          if (_selectedDateRange != null && rowDate != null) {
            DateTime pureRowDate = DateTime(
              rowDate.year,
              rowDate.month,
              rowDate.day,
            );
            DateTime pureStart = DateTime(
              _selectedDateRange!.start.year,
              _selectedDateRange!.start.month,
              _selectedDateRange!.start.day,
            );
            DateTime pureEnd = DateTime(
              _selectedDateRange!.end.year,
              _selectedDateRange!.end.month,
              _selectedDateRange!.end.day,
            );

            if (pureRowDate.isBefore(pureStart) ||
                pureRowDate.isAfter(pureEnd)) {
              continue;
            }
          }

          if (rowDate != null) {
            row['displayDate'] = DateFormat('dd/MM/yyyy').format(rowDate);
          } else {
            row['displayDate'] = dateStr;
          }

          String acc = row['Account'] ?? row['account'] ?? '';
          if (acc.isNotEmpty) {
            accountsSet.add(acc);
          }

          parsedRows.add(row);
        } catch (e) {
          continue;
        }
      }

      parsedRows.sort((a, b) {
        DateTime dateA = DateTime.fromMillisecondsSinceEpoch(0);
        DateTime dateB = DateTime.fromMillisecondsSinceEpoch(0);
        try {
          dateA = DateFormat('dd/MM/yyyy').parse(a['displayDate'] ?? '');
        } catch (_) {}
        try {
          dateB = DateFormat('dd/MM/yyyy').parse(b['displayDate'] ?? '');
        } catch (_) {}

        int dateComparison = dateB.compareTo(dateA);
        if (dateComparison != 0) {
          return dateComparison;
        }

        int idA =
            int.tryParse(
              (a['ID'] ?? a['id'] ?? '0').replaceAll(RegExp(r'[^0-9]'), ''),
            ) ??
            0;
        int idB =
            int.tryParse(
              (b['ID'] ?? b['id'] ?? '0').replaceAll(RegExp(r'[^0-9]'), ''),
            ) ??
            0;
        return idB.compareTo(idA);
      });

      setState(() {
        _allTransactions = parsedRows;
        _availableAccounts = accountsSet.toList()..sort();
        _selectedAccountsFilter.removeWhere(
          (acc) => !_availableAccounts.contains(acc),
        );
        _applySearchFilter();
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _applySearchFilter() {
    _filteredTransactions = _allTransactions.where((row) {
      final account = (row['Account'] ?? row['account'] ?? '');
      final type = (row['EntryType'] ?? row['entryType'] ?? '');
      final desc = (row['Description'] ?? row['description'] ?? '')
          .toLowerCase();
      final id = (row['ID'] ?? row['id'] ?? '').toLowerCase();
      final query = _searchQuery.toLowerCase();

      bool matchesSearch =
          query.isEmpty ||
          account.toLowerCase().contains(query) ||
          desc.contains(query) ||
          id.contains(query);
      bool matchesAccount =
          _selectedAccountsFilter.isEmpty ||
          _selectedAccountsFilter.contains(account);
      bool matchesType =
          _selectedTypeFilter == 'All' || type == _selectedTypeFilter;

      return matchesSearch && matchesAccount && matchesType;
    }).toList();
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: _selectedDateRange,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != _selectedDateRange) {
      setState(() => _selectedDateRange = picked);
      _fetchTransactions();
    }
  }

  void _showMultiSelectDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Select Particulars'),
              content: SizedBox(
                width: double.maxFinite,
                child: _availableAccounts.isEmpty
                    ? const Text("No particulars found.")
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: _availableAccounts.length,
                        itemBuilder: (context, index) {
                          final account = _availableAccounts[index];
                          return CheckboxListTile(
                            title: Text(account),
                            value: _selectedAccountsFilter.contains(account),
                            onChanged: (bool? value) {
                              setDialogState(() {
                                if (value == true) {
                                  _selectedAccountsFilter.add(account);
                                } else {
                                  _selectedAccountsFilter.remove(account);
                                }
                              });
                            },
                          );
                        },
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    setDialogState(() {
                      _selectedAccountsFilter.clear();
                    });
                  },
                  child: const Text('Clear All'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    setState(() {
                      _applySearchFilter();
                    });
                  },
                  child: const Text('Apply Filter'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _printLedgerDirectly() async {
    final pdf = pw.Document();

    // Download safe Google Fonts (Regular and Bold) to prevent Helvetica crashes
    final font = await PdfGoogleFonts.notoSansRegular();
    final boldFont = await PdfGoogleFonts.notoSansBold();

    List<Map<String, dynamic>> printData = List.from(_filteredTransactions);

    // Deep Sort - Ascending by Date, then Ascending by ID
    printData.sort((a, b) {
      DateTime dateA = DateTime.fromMillisecondsSinceEpoch(0);
      DateTime dateB = DateTime.fromMillisecondsSinceEpoch(0);
      try {
        dateA = DateFormat('dd/MM/yyyy').parse(a['displayDate'] ?? '');
      } catch (_) {}
      try {
        dateB = DateFormat('dd/MM/yyyy').parse(b['displayDate'] ?? '');
      } catch (_) {}

      int dateComparison = dateA.compareTo(dateB);
      if (dateComparison != 0) {
        return dateComparison;
      }

      int idA =
          int.tryParse(
            (a['ID'] ?? a['id'] ?? '0').replaceAll(RegExp(r'[^0-9]'), ''),
          ) ??
          0;
      int idB =
          int.tryParse(
            (b['ID'] ?? b['id'] ?? '0').replaceAll(RegExp(r'[^0-9]'), ''),
          ) ??
          0;
      return idA.compareTo(idB);
    });

    // UPDATED TITLE LOGIC
    String reportName = "Ledger Report";
    if (_selectedTypeFilter != 'All') {
      reportName = "$_selectedTypeFilter Report";
    }
    if (_selectedAccountsFilter.isNotEmpty) {
      if (_selectedAccountsFilter.length == 1) {
        reportName =
            "Particular Ledger: ${_selectedAccountsFilter.first.toUpperCase()}";
      } else {
        reportName =
            "Combined Ledger (${_selectedAccountsFilter.length} Accounts)";
      }
    }
    if (_selectedDateRange != null &&
        _selectedDateRange!.start == _selectedDateRange!.end) {
      reportName = "CashBook";
    }

    String dateRangeStr = "Date: All Time";
    if (_selectedDateRange != null) {
      dateRangeStr =
          "Date: ${DateFormat('dd/MM/yyyy').format(_selectedDateRange!.start)} to ${DateFormat('dd/MM/yyyy').format(_selectedDateRange!.end)}";
    }

    double tDebit = 0;
    double tCredit = 0;
    final List<List<dynamic>> tableData = [];

    // Adding all 7 columns to perfectly match the Excel sheet
    for (var row in printData) {
      String id = row['ID'] ?? row['id'] ?? '';
      String type = row['EntryType'] ?? row['entryType'] ?? '';
      String acc = row['Account'] ?? row['account'] ?? '';
      String desc = row['Description'] ?? row['description'] ?? '';
      double c =
          double.tryParse(
            (row['Credit'] ?? row['credit'] ?? '0').toString().replaceAll(
              RegExp(r'[^0-9.-]'),
              '',
            ),
          ) ??
          0;
      double d =
          double.tryParse(
            (row['Debit'] ?? row['debit'] ?? '0').toString().replaceAll(
              RegExp(r'[^0-9.-]'),
              '',
            ),
          ) ??
          0;

      tCredit += c;
      tDebit += d;

      tableData.add([
        id,
        row['displayDate'] ?? '',
        type,
        acc,
        desc,
        c > 0 ? c.toStringAsFixed(2) : '-',
        d > 0 ? d.toStringAsFixed(2) : '-',
      ]);
    }

    final boldStyle = pw.TextStyle(
      fontWeight: pw.FontWeight.bold,
      color: PdfColors.black,
    );

    tableData.add([
      '',
      '',
      '',
      '',
      pw.Text('TOTAL', style: boldStyle),
      pw.Text(tCredit.toStringAsFixed(2), style: boldStyle),
      pw.Text(tDebit.toStringAsFixed(2), style: boldStyle),
    ]);

    tableData.add([
      '',
      '',
      '',
      '',
      pw.Text('CLOSING BALANCE', style: boldStyle),
      pw.Text(
        (tDebit - tCredit) < 0 ? (tCredit - tDebit).toStringAsFixed(2) : '-',
        style: boldStyle,
      ),
      pw.Text(
        (tDebit - tCredit) > 0 ? (tDebit - tCredit).toStringAsFixed(2) : '-',
        style: boldStyle,
      ),
    ]);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.only(
          top: 70,
          bottom: 30,
          left: 30,
          right: 30,
        ),
        theme: pw.ThemeData.withFont(base: font, bold: boldFont),

        header: (pw.Context context) {
          return pw.Container(
            width: double.infinity,
            alignment: pw.Alignment.center,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(
                  "Gramodyog Seva Sansthan",
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  reportName,
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  dateRangeStr,
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 16),
              ],
            ),
          );
        },

        footer: (pw.Context context) {
          return pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 10),
            child: pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 10),
            ),
          );
        },

        build: (context) => [
          pw.TableHelper.fromTextArray(
            border: pw.TableBorder.all(color: PdfColors.black, width: 1),
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.black,
            ),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.white),
            cellStyle: const pw.TextStyle(color: PdfColors.black),
            rowDecoration: const pw.BoxDecoration(color: PdfColors.white),
            cellHeight: 22,

            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerLeft,
              2: pw.Alignment.centerLeft,
              3: pw.Alignment.centerLeft,
              4: pw.Alignment.centerLeft,
              5: pw.Alignment.centerRight,
              6: pw.Alignment.centerRight,
            },

            headers: [
              'ID',
              'Date',
              'Type',
              'Particular',
              'Description',
              'Credit (Cr.)',
              'Debit (Dr.)',
            ],
            columnWidths: {
              0: const pw.FlexColumnWidth(0.8),
              1: const pw.FlexColumnWidth(1.2),
              2: const pw.FlexColumnWidth(1.2),
              3: const pw.FlexColumnWidth(2.5),
              4: const pw.FlexColumnWidth(3.0),
              5: const pw.FlexColumnWidth(1.5),
              6: const pw.FlexColumnWidth(1.5),
            },
            data: tableData,
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Ledger_Report.pdf',
      format: PdfPageFormat.a4.landscape,
    );
  }

  Future<void> _exportLedgerToExcel() async {
    setState(() => _isLoading = true);

    try {
      var excelFile = excel.Excel.createExcel();
      excel.Sheet sheetObject = excelFile['Report'];
      excelFile.setDefaultSheet('Report');

      sheetObject.setColumnWidth(0, 10.0);
      sheetObject.setColumnWidth(1, 12.0);
      sheetObject.setColumnWidth(2, 14.0);
      sheetObject.setColumnWidth(3, 30.0);
      sheetObject.setColumnWidth(4, 40.0);
      sheetObject.setColumnWidth(5, 18.0);
      sheetObject.setColumnWidth(6, 18.0);

      var borderStyle = excel.Border(borderStyle: excel.BorderStyle.Thin);
      var titleStyle = excel.CellStyle(
        fontFamily: 'Times New Roman',
        fontSize: 16,
        bold: true,
        horizontalAlign: excel.HorizontalAlign.Center,
      );
      var subTitleStyle = excel.CellStyle(
        fontFamily: 'Times New Roman',
        fontSize: 14,
        bold: true,
        horizontalAlign: excel.HorizontalAlign.Center,
      );
      var headerStyle = excel.CellStyle(
        fontFamily: 'Times New Roman',
        fontSize: 12,
        bold: true,
        horizontalAlign: excel.HorizontalAlign.Center,
        leftBorder: borderStyle,
        rightBorder: borderStyle,
        topBorder: borderStyle,
        bottomBorder: borderStyle,
      );
      var contentStyle = excel.CellStyle(
        fontFamily: 'Times New Roman',
        fontSize: 12,
        leftBorder: borderStyle,
        rightBorder: borderStyle,
        topBorder: borderStyle,
        bottomBorder: borderStyle,
      );
      var boldAccountStyle = excel.CellStyle(
        fontFamily: 'Times New Roman',
        fontSize: 12,
        bold: true,
        leftBorder: borderStyle,
        rightBorder: borderStyle,
        topBorder: borderStyle,
        bottomBorder: borderStyle,
      );
      var currencyStyle = excel.CellStyle(
        fontFamily: 'Times New Roman',
        fontSize: 12,
        horizontalAlign: excel.HorizontalAlign.Right,
        numberFormat: excel.NumFormat.standard_2,
        leftBorder: borderStyle,
        rightBorder: borderStyle,
        topBorder: borderStyle,
        bottomBorder: borderStyle,
      );
      var totalStyle = excel.CellStyle(
        fontFamily: 'Times New Roman',
        fontSize: 12,
        bold: true,
        horizontalAlign: excel.HorizontalAlign.Right,
        numberFormat: excel.NumFormat.standard_2,
        leftBorder: borderStyle,
        rightBorder: borderStyle,
        topBorder: borderStyle,
        bottomBorder: borderStyle,
      );

      sheetObject.merge(
        excel.CellIndex.indexByString("A1"),
        excel.CellIndex.indexByString("G1"),
      );
      sheetObject.updateCell(
        excel.CellIndex.indexByString("A1"),
        excel.TextCellValue("Gramodyog Seva Sansthan"),
        cellStyle: titleStyle,
      );

      // UPDATED TITLE LOGIC
      String reportName = "Ledger Report";
      if (_selectedTypeFilter != 'All') {
        reportName = "$_selectedTypeFilter Report";
      }
      if (_selectedAccountsFilter.isNotEmpty) {
        if (_selectedAccountsFilter.length == 1) {
          reportName =
              "Particular Ledger: ${_selectedAccountsFilter.first.toUpperCase()}";
        } else {
          reportName =
              "Combined Ledger (${_selectedAccountsFilter.length} Accounts)";
        }
      }
      if (_selectedDateRange != null &&
          _selectedDateRange!.start == _selectedDateRange!.end) {
        reportName = "CashBook";
      }

      sheetObject.merge(
        excel.CellIndex.indexByString("A2"),
        excel.CellIndex.indexByString("G2"),
      );
      sheetObject.updateCell(
        excel.CellIndex.indexByString("A2"),
        excel.TextCellValue(reportName),
        cellStyle: titleStyle,
      );

      sheetObject.merge(
        excel.CellIndex.indexByString("A3"),
        excel.CellIndex.indexByString("G3"),
      );
      String dateRangeStr = "Date: All Time";
      if (_selectedDateRange != null) {
        dateRangeStr =
            "Date: ${DateFormat('dd/MM/yyyy').format(_selectedDateRange!.start)} to ${DateFormat('dd/MM/yyyy').format(_selectedDateRange!.end)}";
      }
      sheetObject.updateCell(
        excel.CellIndex.indexByString("A3"),
        excel.TextCellValue(dateRangeStr),
        cellStyle: subTitleStyle,
      );

      sheetObject.updateCell(
        excel.CellIndex.indexByString("A5"),
        excel.TextCellValue("ID"),
        cellStyle: headerStyle,
      );
      sheetObject.updateCell(
        excel.CellIndex.indexByString("B5"),
        excel.TextCellValue("Date"),
        cellStyle: headerStyle,
      );
      sheetObject.updateCell(
        excel.CellIndex.indexByString("C5"),
        excel.TextCellValue("Type"),
        cellStyle: headerStyle,
      );
      sheetObject.updateCell(
        excel.CellIndex.indexByString("D5"),
        excel.TextCellValue("Particular"),
        cellStyle: headerStyle,
      );
      sheetObject.updateCell(
        excel.CellIndex.indexByString("E5"),
        excel.TextCellValue("Description"),
        cellStyle: headerStyle,
      );
      sheetObject.updateCell(
        excel.CellIndex.indexByString("F5"),
        excel.TextCellValue("Credit (Cr.)"),
        cellStyle: headerStyle,
      );
      sheetObject.updateCell(
        excel.CellIndex.indexByString("G5"),
        excel.TextCellValue("Debit (Dr.)"),
        cellStyle: headerStyle,
      );

      int currentRow = 5;
      double totalDebit = 0.0;
      double totalCredit = 0.0;

      List<Map<String, dynamic>> excelExportData = List.from(
        _filteredTransactions,
      );
      excelExportData.sort((a, b) {
        DateTime dateA = DateTime.fromMillisecondsSinceEpoch(0);
        DateTime dateB = DateTime.fromMillisecondsSinceEpoch(0);
        try {
          dateA = DateFormat('dd/MM/yyyy').parse(a['displayDate'] ?? '');
        } catch (_) {}
        try {
          dateB = DateFormat('dd/MM/yyyy').parse(b['displayDate'] ?? '');
        } catch (_) {}
        int dateComparison = dateA.compareTo(dateB);
        if (dateComparison != 0) {
          return dateComparison;
        }
        int idA =
            int.tryParse(
              (a['ID'] ?? a['id'] ?? '0').replaceAll(RegExp(r'[^0-9]'), ''),
            ) ??
            0;
        int idB =
            int.tryParse(
              (b['ID'] ?? b['id'] ?? '0').replaceAll(RegExp(r'[^0-9]'), ''),
            ) ??
            0;
        return idA.compareTo(idB);
      });

      for (var row in excelExportData) {
        String debitStr = (row['Debit'] ?? row['debit'] ?? '0').replaceAll(
          RegExp(r'[^0-9.-]'),
          '',
        );
        String creditStr = (row['Credit'] ?? row['credit'] ?? '0').replaceAll(
          RegExp(r'[^0-9.-]'),
          '',
        );

        double debit = double.tryParse(debitStr) ?? 0.0;
        double credit = double.tryParse(creditStr) ?? 0.0;

        totalDebit += debit;
        totalCredit += credit;

        sheetObject.updateCell(
          excel.CellIndex.indexByColumnRow(
            columnIndex: 0,
            rowIndex: currentRow,
          ),
          excel.TextCellValue(row['ID'] ?? row['id'] ?? ''),
          cellStyle: contentStyle,
        );
        sheetObject.updateCell(
          excel.CellIndex.indexByColumnRow(
            columnIndex: 1,
            rowIndex: currentRow,
          ),
          excel.TextCellValue(row['displayDate'] ?? ''),
          cellStyle: contentStyle,
        );
        sheetObject.updateCell(
          excel.CellIndex.indexByColumnRow(
            columnIndex: 2,
            rowIndex: currentRow,
          ),
          excel.TextCellValue(row['EntryType'] ?? row['entryType'] ?? ''),
          cellStyle: contentStyle,
        );
        sheetObject.updateCell(
          excel.CellIndex.indexByColumnRow(
            columnIndex: 3,
            rowIndex: currentRow,
          ),
          excel.TextCellValue(row['Account'] ?? row['account'] ?? ''),
          cellStyle: boldAccountStyle,
        );
        sheetObject.updateCell(
          excel.CellIndex.indexByColumnRow(
            columnIndex: 4,
            rowIndex: currentRow,
          ),
          excel.TextCellValue(row['Description'] ?? row['description'] ?? ''),
          cellStyle: contentStyle,
        );
        sheetObject.updateCell(
          excel.CellIndex.indexByColumnRow(
            columnIndex: 5,
            rowIndex: currentRow,
          ),
          credit > 0 ? excel.DoubleCellValue(credit) : excel.TextCellValue('-'),
          cellStyle: currencyStyle,
        );
        sheetObject.updateCell(
          excel.CellIndex.indexByColumnRow(
            columnIndex: 6,
            rowIndex: currentRow,
          ),
          debit > 0 ? excel.DoubleCellValue(debit) : excel.TextCellValue('-'),
          cellStyle: currencyStyle,
        );

        currentRow++;
      }

      sheetObject.updateCell(
        excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow),
        excel.TextCellValue(''),
        cellStyle: contentStyle,
      );
      sheetObject.updateCell(
        excel.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: currentRow),
        excel.TextCellValue(''),
        cellStyle: contentStyle,
      );
      sheetObject.updateCell(
        excel.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: currentRow),
        excel.TextCellValue(''),
        cellStyle: contentStyle,
      );
      sheetObject.updateCell(
        excel.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: currentRow),
        excel.TextCellValue(''),
        cellStyle: contentStyle,
      );

      sheetObject.updateCell(
        excel.CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: currentRow),
        excel.TextCellValue('TOTAL'),
        cellStyle: totalStyle,
      );
      sheetObject.updateCell(
        excel.CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: currentRow),
        excel.DoubleCellValue(totalCredit),
        cellStyle: totalStyle,
      );
      sheetObject.updateCell(
        excel.CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: currentRow),
        excel.DoubleCellValue(totalDebit),
        cellStyle: totalStyle,
      );

      currentRow++;
      double balance = totalDebit - totalCredit;

      sheetObject.updateCell(
        excel.CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: currentRow),
        excel.TextCellValue('CLOSING BALANCE'),
        cellStyle: totalStyle,
      );

      if (balance < 0) {
        sheetObject.updateCell(
          excel.CellIndex.indexByColumnRow(
            columnIndex: 5,
            rowIndex: currentRow,
          ),
          excel.DoubleCellValue(balance.abs()),
          cellStyle: totalStyle,
        );
        sheetObject.updateCell(
          excel.CellIndex.indexByColumnRow(
            columnIndex: 6,
            rowIndex: currentRow,
          ),
          excel.TextCellValue('-'),
          cellStyle: totalStyle,
        );
      } else if (balance > 0) {
        sheetObject.updateCell(
          excel.CellIndex.indexByColumnRow(
            columnIndex: 5,
            rowIndex: currentRow,
          ),
          excel.TextCellValue('-'),
          cellStyle: totalStyle,
        );
        sheetObject.updateCell(
          excel.CellIndex.indexByColumnRow(
            columnIndex: 6,
            rowIndex: currentRow,
          ),
          excel.DoubleCellValue(balance),
          cellStyle: totalStyle,
        );
      } else {
        sheetObject.updateCell(
          excel.CellIndex.indexByColumnRow(
            columnIndex: 5,
            rowIndex: currentRow,
          ),
          excel.TextCellValue('-'),
          cellStyle: totalStyle,
        );
        sheetObject.updateCell(
          excel.CellIndex.indexByColumnRow(
            columnIndex: 6,
            rowIndex: currentRow,
          ),
          excel.TextCellValue('-'),
          cellStyle: totalStyle,
        );
      }

      var bytes = excelFile.save();

      String defaultFileName = "Ledger_Report.xlsx";
      if (_selectedAccountsFilter.isNotEmpty) {
        if (_selectedAccountsFilter.length == 1) {
          defaultFileName = "${_selectedAccountsFilter.first}_Ledger.xlsx";
        } else {
          defaultFileName = "Combined_Ledger_Report.xlsx";
        }
      }

      defaultFileName = defaultFileName.replaceAll(
        RegExp(r'[<>:"/\\|?*]'),
        '_',
      );

      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Ledger Report',
        fileName: defaultFileName,
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

  void _deleteTransaction(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Transaction?'),
        content: Text('Are you sure you want to delete Entry $id?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isLoading = true);
              try {
                bool success = await SheetsService.deleteEntry(id);
                await Future.delayed(const Duration(milliseconds: 500));
                if (!mounted) {
                  return;
                }
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Deleted successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  await _fetchTransactions();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Failed to delete from Sheets'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  setState(() => _isLoading = false);
                }
              } catch (e) {
                if (mounted) {
                  setState(() => _isLoading = false);
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(Map<String, dynamic> transaction) {
    showDialog(
      context: context,
      builder: (context) => _EditTransactionDialog(
        transaction: transaction,
        onSaved: _fetchTransactions,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final LedgerDataSource dataSource = LedgerDataSource(
      _filteredTransactions,
      _showEditDialog,
      _deleteTransaction,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ledger Book'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            tooltip: 'Print Ledger directly',
            onPressed: _printLedgerDirectly,
          ),
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Export Report to Excel',
            onPressed: _exportLedgerToExcel,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Manual Refresh',
            onPressed: _fetchTransactions,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        decoration: const InputDecoration(
                          labelText: 'Search Description or ID...',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12),
                        ),
                        onChanged: (val) => setState(() {
                          _searchQuery = val;
                          _applySearchFilter();
                        }),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 1,
                      child: InkWell(
                        onTap: _selectDateRange,
                        child: Container(
                          height: 50,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade400),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Text(
                                  _selectedDateRange == null
                                      ? 'Filter Date'
                                      : '${DateFormat('dd/MM/yy').format(_selectedDateRange!.start)} - ${DateFormat('dd/MM/yy').format(_selectedDateRange!.end)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                  textAlign: TextAlign.center,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              // THE RED 'X' CLEAR BUTTON
                              if (_selectedDateRange != null)
                                InkWell(
                                  onTap: () {
                                    setState(() => _selectedDateRange = null);
                                    _fetchTransactions(); // Reloads all data instantly
                                  },
                                  child: const Padding(
                                    padding: EdgeInsets.only(left: 4.0),
                                    child: Icon(
                                      Icons.cancel,
                                      color: Colors.redAccent,
                                      size: 20,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: InkWell(
                        onTap: _showMultiSelectDialog,
                        child: Container(
                          height: 50,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade400),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  _selectedAccountsFilter.isEmpty
                                      ? 'Filter by Particulars (All)'
                                      : _selectedAccountsFilter.length == 1
                                      ? _selectedAccountsFilter.first
                                      : '${_selectedAccountsFilter.length} Particulars Selected',
                                  style: TextStyle(
                                    color: _selectedAccountsFilter.isEmpty
                                        ? Colors.grey.shade700
                                        : Colors.black,
                                    fontSize: 16,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const Icon(
                                Icons.arrow_drop_down,
                                color: Colors.grey,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 1,
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedTypeFilter,
                        decoration: const InputDecoration(
                          labelText: 'Entry Type',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12),
                        ),
                        items: ['All', 'Rokad', 'Jama-Kharchi']
                            .map(
                              (type) => DropdownMenuItem(
                                value: type,
                                child: Text(type),
                              ),
                            )
                            .toList(),
                        onChanged: (val) => setState(() {
                          _selectedTypeFilter = val!;
                          _applySearchFilter();
                        }),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredTransactions.isEmpty
                ? const Center(child: Text('No entries match your filters.'))
                : ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    children: [
                      PaginatedDataTable(
                        header: const Text('Transaction History'),
                        rowsPerPage: _filteredTransactions.length > 10
                            ? 10
                            : (_filteredTransactions.isEmpty
                                  ? 1
                                  : _filteredTransactions.length),
                        columnSpacing: 15,
                        horizontalMargin: 10,
                        columns: const [
                          DataColumn(
                            label: Text(
                              'ID',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Date',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Type',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Particular',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Description',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Credit',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            numeric: true,
                          ),
                          DataColumn(
                            label: Text(
                              'Debit',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            numeric: true,
                          ),
                          DataColumn(
                            label: Text(
                              'Actions',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                        source: dataSource,
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class LedgerDataSource extends DataTableSource {
  final List<Map<String, dynamic>> _data;
  final Function(Map<String, dynamic>) onEdit;
  final Function(String) onDelete;

  LedgerDataSource(this._data, this.onEdit, this.onDelete);

  @override
  DataRow? getRow(int index) {
    if (index >= _data.length) {
      return null;
    }
    final row = _data[index];

    String debitStr = (row['Debit'] ?? row['debit'] ?? '0').replaceAll(
      RegExp(r'[^0-9.-]'),
      '',
    );
    String creditStr = (row['Credit'] ?? row['credit'] ?? '0').replaceAll(
      RegExp(r'[^0-9.-]'),
      '',
    );

    return DataRow(
      cells: [
        DataCell(Text(row['ID'] ?? row['id'] ?? '')),
        DataCell(Text(row['displayDate'] ?? '')),
        DataCell(Text(row['EntryType'] ?? row['entryType'] ?? '')),
        DataCell(Text(row['Account'] ?? row['account'] ?? '')),
        DataCell(Text(row['Description'] ?? row['description'] ?? '')),
        DataCell(Text('₹$creditStr')),
        DataCell(Text('₹$debitStr')),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                onPressed: () => onEdit(row),
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                onPressed: () => onDelete(row['ID'] ?? row['id'] ?? ''),
              ),
            ],
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

class _EditTransactionDialog extends StatefulWidget {
  final Map<String, dynamic> transaction;
  final VoidCallback onSaved;

  const _EditTransactionDialog({
    required this.transaction,
    required this.onSaved,
  });

  @override
  State<_EditTransactionDialog> createState() => _EditTransactionDialogState();
}

class _EditTransactionDialogState extends State<_EditTransactionDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _descController;
  late TextEditingController _debitController;
  late TextEditingController _creditController;
  late String _entryType;
  late DateTime _selectedDate;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _descController = TextEditingController(
      text:
          widget.transaction['Description'] ??
          widget.transaction['description'],
    );
    String cleanDebit =
        (widget.transaction['Debit'] ?? widget.transaction['debit'] ?? '')
            .replaceAll(RegExp(r'[^0-9.-]'), '');
    String cleanCredit =
        (widget.transaction['Credit'] ?? widget.transaction['credit'] ?? '')
            .replaceAll(RegExp(r'[^0-9.-]'), '');
    _debitController = TextEditingController(
      text: cleanDebit == '0' ? '' : cleanDebit,
    );
    _creditController = TextEditingController(
      text: cleanCredit == '0' ? '' : cleanCredit,
    );

    String tempType =
        widget.transaction['EntryType'] ??
        widget.transaction['entryType'] ??
        'Rokad';
    if (tempType == 'Cash') {
      tempType = 'Rokad';
    }
    if (tempType == 'Journal') {
      tempType = 'Jama-Kharchi';
    }
    if (!['Rokad', 'Jama-Kharchi'].contains(tempType)) {
      tempType = 'Rokad';
    }
    _entryType = tempType;

    try {
      _selectedDate = DateFormat(
        'dd/MM/yyyy',
      ).parse(widget.transaction['displayDate'] ?? '');
    } catch (_) {
      _selectedDate = DateTime.now();
    }
  }

  Future<void> _updateEntry() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSaving = true);
      Map<String, dynamic> updatedEntry = {
        'id': widget.transaction['ID'] ?? widget.transaction['id'],
        'date': DateFormat('MM/dd/yyyy').format(_selectedDate),
        'entryType': _entryType,
        'account':
            widget.transaction['Account'] ?? widget.transaction['account'],
        'description': _descController.text,
        'debit': _debitController.text.isEmpty ? '0' : _debitController.text,
        'credit': _creditController.text.isEmpty ? '0' : _creditController.text,
      };

      bool success = await SheetsService.updateEntry(
        updatedEntry['id'],
        updatedEntry,
      );
      if (!mounted) {
        return;
      }
      if (success) {
        Navigator.pop(context);
        widget.onSaved();
      } else {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Update failed.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'Edit Entry ${widget.transaction['ID'] ?? widget.transaction['id']}',
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setState(() => _selectedDate = picked);
                        }
                      },
                      child: Text(
                        DateFormat('dd/MM/yyyy').format(_selectedDate),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _entryType,
                      items: ['Rokad', 'Jama-Kharchi']
                          .map(
                            (v) => DropdownMenuItem(value: v, child: Text(v)),
                          )
                          .toList(),
                      onChanged: (val) => setState(() => _entryType = val!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descController,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _creditController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Credit (₹)'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _debitController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Debit (₹)'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _updateEntry,
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Update'),
        ),
      ],
    );
  }
}
