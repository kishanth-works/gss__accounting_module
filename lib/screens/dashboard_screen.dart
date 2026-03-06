import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart' as excel;
import 'package:file_picker/file_picker.dart';
import '../services/sheets_service.dart';
import 'entry_form_screen.dart';
import 'ledger_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DateTimeRange? _selectedDateRange;
  bool _isLoading = false;

  List<Map<String, dynamic>> _trialBalanceData = [];
  double _totalDebit = 0.0;
  double _totalCredit = 0.0;

  // UI header trackers
  double _openingCashUI = 0.0;
  double _closingCashUI = 0.0;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDateRange = DateTimeRange(
      start: DateTime(now.year, now.month, 1),
      end: DateTime(now.year, now.month + 1, 0),
    );
    _fetchAndCalculateTrialBalance();
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: _selectedDateRange,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != _selectedDateRange) {
      setState(() {
        _selectedDateRange = picked;
      });
      _fetchAndCalculateTrialBalance();
    }
  }

  Future<void> _fetchAndCalculateTrialBalance({bool isSilent = false}) async {
    if (!isSilent) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final rows = await SheetsService.getAllEntries();

      Map<String, double> periodBalances = {};

      // Trackers for Boundary Cash Extraction
      DateTime? earliestOpeningDate;
      double openingDebit = 0.0;
      double openingCredit = 0.0;

      DateTime? latestClosingDate;
      double closingDebit = 0.0;
      double closingCredit = 0.0;

      for (var row in rows) {
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
                rowDate = DateFormat('yyyy-MM-dd').parse(dateStr);
              } catch (_) {
                rowDate = DateTime.tryParse(dateStr);
              }
            }
          }

          if (rowDate != null && _selectedDateRange != null) {
            if (rowDate.isBefore(_selectedDateRange!.start) ||
                rowDate.isAfter(
                  _selectedDateRange!.end.add(const Duration(days: 1)),
                )) {
              continue;
            }
          }

          String account = row['Account'] ?? row['account'] ?? 'Unknown';
          String accLower = account.toLowerCase();

          String rawDebit = (row['Debit'] ?? row['debit'] ?? '0').replaceAll(
            RegExp(r'[^0-9.-]'),
            '',
          );
          String rawCredit = (row['Credit'] ?? row['credit'] ?? '0').replaceAll(
            RegExp(r'[^0-9.-]'),
            '',
          );

          // RESTORED: Standard mapping! Debit is Debit, Credit is Credit.
          double debit = double.tryParse(rawDebit) ?? 0.0;
          double credit = double.tryParse(rawCredit) ?? 0.0;

          // BOUNDARY EXTRACTION LOGIC
          if (accLower == 'shree rokad' ||
              accLower == 'opening cash' ||
              accLower == 'opening balance') {
            if (earliestOpeningDate == null ||
                (rowDate != null && rowDate.isBefore(earliestOpeningDate))) {
              earliestOpeningDate = rowDate;
              openingDebit = debit;
              openingCredit = credit;
            }
          } else if (accLower == 'rokad shree' ||
              accLower == 'closing cash' ||
              accLower == 'cash in hand') {
            if (latestClosingDate == null ||
                (rowDate != null && rowDate.isAfter(latestClosingDate))) {
              latestClosingDate = rowDate;
              closingDebit = debit;
              closingCredit = credit;
            }
          } else {
            // STANDARD SUMMATION FOR ALL OTHER ACCOUNTS
            double netAmount = debit - credit;
            if (!periodBalances.containsKey(account)) {
              periodBalances[account] = 0.0;
            }
            periodBalances[account] = periodBalances[account]! + netAmount;
          }
        } catch (e) {
          continue;
        }
      }

      List<Map<String, dynamic>> rawData = [];
      double tDebit = 0.0;
      double tCredit = 0.0;

      // Translate Net Balances back into Final Debits/Credits
      periodBalances.forEach((account, netBalance) {
        if (netBalance.abs() > 0.01) {
          double finalDebit = netBalance > 0 ? netBalance : 0.0;
          double finalCredit = netBalance < 0 ? netBalance.abs() : 0.0;
          tDebit += finalDebit;
          tCredit += finalCredit;
          rawData.add({
            'account': account,
            'debit': finalDebit,
            'credit': finalCredit,
          });
        }
      });

      // Sort middle entries alphabetically
      rawData.sort(
        (a, b) => a['account'].toString().compareTo(b['account'].toString()),
      );

      List<Map<String, dynamic>> finalSortedData = [];

      // 1. PIN SHREE ROKAD TO THE VERY TOP
      if (openingDebit > 0 || openingCredit > 0) {
        tDebit += openingDebit;
        tCredit += openingCredit;
        finalSortedData.add({
          'displayAccount': 'Opening Cash',
          'debit': openingDebit,
          'credit': openingCredit,
        });
      }

      // 2. MIDDLE ACCOUNTS
      for (var row in rawData) {
        row['displayAccount'] = row['account'];
        finalSortedData.add(row);
      }

      // 3. PIN ROKAD SHREE TO THE VERY BOTTOM
      if (closingDebit > 0 || closingCredit > 0) {
        tDebit += closingDebit;
        tCredit += closingCredit;
        finalSortedData.add({
          'displayAccount': 'Cash In Hand',
          'debit': closingDebit,
          'credit': closingCredit,
        });
      }

      setState(() {
        _trialBalanceData = finalSortedData;
        _totalDebit = tDebit;
        _totalCredit = tCredit;

        // Setup UI Header cards
        _openingCashUI = openingDebit > 0 ? openingDebit : openingCredit;
        _closingCashUI = closingDebit > 0 ? closingDebit : closingCredit;

        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _exportToExcel() async {
    setState(() {
      _isLoading = true;
    });

    try {
      var excelFile = excel.Excel.createExcel();
      excel.Sheet sheetObject = excelFile['Trial Balance'];
      excelFile.setDefaultSheet('Trial Balance');

      // 1. Column Formatting
      sheetObject.setColumnWidth(0, 45.0);
      sheetObject.setColumnWidth(1, 18.0); // Cr.
      sheetObject.setColumnWidth(2, 18.0); // Dr.

      // 2. Custom Styles
      var titleStyle = excel.CellStyle(
        bold: true,
        fontSize: 14,
        horizontalAlign: excel.HorizontalAlign.Center,
      );
      var borderStyle = excel.Border(borderStyle: excel.BorderStyle.Thin);
      var headerStyle = excel.CellStyle(
        bold: true,
        horizontalAlign: excel.HorizontalAlign.Center,
        leftBorder: borderStyle,
        rightBorder: borderStyle,
        topBorder: borderStyle,
        bottomBorder: borderStyle,
      );
      var dataStyle = excel.CellStyle(
        leftBorder: borderStyle,
        rightBorder: borderStyle,
        topBorder: borderStyle,
        bottomBorder: borderStyle,
      );
      var currencyStyle = excel.CellStyle(
        horizontalAlign: excel.HorizontalAlign.Right,
        numberFormat: excel.NumFormat.standard_2,
        leftBorder: borderStyle,
        rightBorder: borderStyle,
        topBorder: borderStyle,
        bottomBorder: borderStyle,
      );
      var totalStyle = excel.CellStyle(
        bold: true,
        horizontalAlign: excel.HorizontalAlign.Right,
        numberFormat: excel.NumFormat.standard_2,
        leftBorder: borderStyle,
        rightBorder: borderStyle,
        topBorder: borderStyle,
        bottomBorder: borderStyle,
      );

      // 3. Document Headers (Rows 1 & 2)
      sheetObject.merge(
        excel.CellIndex.indexByString("A1"),
        excel.CellIndex.indexByString("C1"),
      );
      sheetObject.updateCell(
        excel.CellIndex.indexByString("A1"),
        excel.TextCellValue("Gramodyog Seva Sansthan"),
        cellStyle: titleStyle,
      );

      sheetObject.merge(
        excel.CellIndex.indexByString("A2"),
        excel.CellIndex.indexByString("C2"),
      );
      sheetObject.updateCell(
        excel.CellIndex.indexByString("A2"),
        excel.TextCellValue("Ettaura, Ardawna, Mau. Pin Code-221705"),
        cellStyle: titleStyle,
      );

      // DYNAMIC DATE ROW (Row 3)
      sheetObject.merge(
        excel.CellIndex.indexByString("A3"),
        excel.CellIndex.indexByString("C3"),
      );
      String dateRangeStr = "All Time";
      if (_selectedDateRange != null) {
        dateRangeStr =
            "${DateFormat('dd MMM yyyy').format(_selectedDateRange!.start)} to ${DateFormat('dd MMM yyyy').format(_selectedDateRange!.end)}";
      }
      sheetObject.updateCell(
        excel.CellIndex.indexByString("A3"),
        excel.TextCellValue("Trial Balance Sheet ($dateRangeStr)"),
        cellStyle: titleStyle,
      );

      // 4. Table Headers (Cr. First, Dr. Second)
      sheetObject.updateCell(
        excel.CellIndex.indexByString("A5"),
        excel.TextCellValue("Particular"),
        cellStyle: headerStyle,
      );
      sheetObject.updateCell(
        excel.CellIndex.indexByString("B5"),
        excel.TextCellValue("Cr."),
        cellStyle: headerStyle,
      );
      sheetObject.updateCell(
        excel.CellIndex.indexByString("C5"),
        excel.TextCellValue("Dr."),
        cellStyle: headerStyle,
      );

      int currentRow = 5;

      // 5. Insert Data
      for (var row in _trialBalanceData) {
        double credit = row['credit'] ?? 0.0;
        double debit = row['debit'] ?? 0.0;

        sheetObject.updateCell(
          excel.CellIndex.indexByColumnRow(
            columnIndex: 0,
            rowIndex: currentRow,
          ),
          excel.TextCellValue(row['displayAccount']),
          cellStyle: dataStyle,
        );
        sheetObject.updateCell(
          excel.CellIndex.indexByColumnRow(
            columnIndex: 1,
            rowIndex: currentRow,
          ),
          credit > 0 ? excel.DoubleCellValue(credit) : excel.TextCellValue(''),
          cellStyle: currencyStyle,
        );
        sheetObject.updateCell(
          excel.CellIndex.indexByColumnRow(
            columnIndex: 2,
            rowIndex: currentRow,
          ),
          debit > 0 ? excel.DoubleCellValue(debit) : excel.TextCellValue(''),
          cellStyle: currencyStyle,
        );
        currentRow++;
      }

      // 6. Grand Totals (Cr. First, Dr. Second)
      sheetObject.updateCell(
        excel.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: currentRow),
        excel.TextCellValue(''),
        cellStyle: dataStyle,
      );
      sheetObject.updateCell(
        excel.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: currentRow),
        excel.DoubleCellValue(_totalCredit),
        cellStyle: totalStyle,
      );
      sheetObject.updateCell(
        excel.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: currentRow),
        excel.DoubleCellValue(_totalDebit),
        cellStyle: totalStyle,
      );

      var bytes = excelFile.save();

      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Trial Balance Report',
        fileName: 'TrialBalance_Report.xlsx',
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

        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved to: $outputFile'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Export Cancelled'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export Failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final TrialBalanceDataSource dataSource = TrialBalanceDataSource(
      _trialBalanceData,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Accounting Dashboard'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Export Excel',
            onPressed: _exportToExcel,
          ),
          IconButton(
            icon: const Icon(Icons.book),
            tooltip: 'Ledger Book',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LedgerScreen()),
              );
              _fetchAndCalculateTrialBalance();
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Manual Refresh',
            onPressed: _fetchAndCalculateTrialBalance,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: InkWell(
              onTap: _selectDateRange,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.date_range, color: Colors.blueGrey),
                        const SizedBox(width: 8),
                        Text(
                          _selectedDateRange == null
                              ? 'Select Date Range'
                              : '${DateFormat('dd MMM yyyy').format(_selectedDateRange!.start)} - ${DateFormat('dd MMM yyyy').format(_selectedDateRange!.end)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const Icon(Icons.arrow_drop_down),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Expanded(
                  child: Card(
                    color: Colors.blue.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          const Text('Shree Rokad (Opening)'),
                          Text(
                            '₹${_openingCashUI.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Card(
                    color: Colors.blue.shade100,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          const Text('Rokad Shree (Closing)'),
                          Text(
                            '₹${_closingCashUI.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _trialBalanceData.isEmpty
                ? const Center(child: Text('No transactions found.'))
                : ListView(
                    padding: const EdgeInsets.all(16.0),
                    children: [
                      PaginatedDataTable(
                        header: const Text('Trial Balance'),
                        rowsPerPage: _trialBalanceData.length > 10
                            ? 10
                            : (_trialBalanceData.isEmpty
                                  ? 1
                                  : _trialBalanceData.length),
                        columns: const [
                          DataColumn(
                            label: Text(
                              'Particular',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Cr.',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            numeric: true,
                          ),
                          DataColumn(
                            label: Text(
                              'Dr.',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            numeric: true,
                          ),
                        ],
                        source: dataSource,
                      ),
                      const SizedBox(height: 16),
                      Card(
                        color: (_totalDebit - _totalCredit).abs() < 0.01
                            ? Colors.green.shade50
                            : Colors.red.shade50,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'TOTALS',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Cr: ₹${_totalCredit.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blueGrey,
                                ),
                              ),
                              Text(
                                'Dr: ₹${_totalDebit.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blueGrey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 80),
                    ],
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const EntryFormScreen()),
          );
          _fetchAndCalculateTrialBalance();
        },
        icon: const Icon(Icons.add),
        label: const Text('New Entry'),
      ),
    );
  }
}

class TrialBalanceDataSource extends DataTableSource {
  final List<Map<String, dynamic>> _data;
  TrialBalanceDataSource(this._data);

  @override
  DataRow? getRow(int index) {
    if (index >= _data.length) {
      return null;
    }
    final row = _data[index];

    return DataRow(
      cells: [
        DataCell(Text(row['displayAccount'].toString())),
        DataCell(
          Text(row['credit'] > 0 ? row['credit'].toStringAsFixed(2) : '-'),
        ), // Cr is Col 1
        DataCell(
          Text(row['debit'] > 0 ? row['debit'].toStringAsFixed(2) : '-'),
        ), // Dr is Col 2
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
