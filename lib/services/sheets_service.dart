import 'package:flutter/foundation.dart';
import 'package:gsheets/gsheets.dart';
import '../secrets.dart';

class SheetsService {
  static final _gsheets = GSheets(Secrets.credentialsJson);
  static Worksheet? _transactionsSheet;
  static Worksheet? _accountsSheet;
  static Worksheet? _kattinSheet;
  static Worksheet? _cottonSheet;
  static Worksheet? _employeesSheet;
  static Worksheet? _payrollsSheet;

  static Future<void> init() async {
    try {
      final spreadsheet = await _gsheets.spreadsheet(Secrets.spreadsheetId);

      _transactionsSheet = spreadsheet.worksheetByTitle('Transactions');
      _accountsSheet = spreadsheet.worksheetByTitle('Accounts');
      _kattinSheet = spreadsheet.worksheetByTitle('Kattin');
      _cottonSheet = spreadsheet.worksheetByTitle('Cotton-Sut-Kharid');
      _employeesSheet = spreadsheet.worksheetByTitle('Employees');
      _payrollsSheet = spreadsheet.worksheetByTitle('Payrolls');

      _accountsSheet ??= await spreadsheet.addWorksheet('Accounts');
      _kattinSheet ??= await spreadsheet.addWorksheet('Kattin');
      _cottonSheet ??= await spreadsheet.addWorksheet('Cotton-Sut-Kharid');
      _employeesSheet ??= await spreadsheet.addWorksheet('Employees');
      _payrollsSheet ??= await spreadsheet.addWorksheet('Payrolls');

      debugPrint('Google Sheets Initialized Successfully!');
    } catch (e) {
      debugPrint('Error initializing Sheets: $e');
    }
  }

  // ==========================================
  // --- ACCOUNTING MODULE METHODS ---
  // ==========================================

  static Future<String> getNextId() async {
    if (_transactionsSheet == null) return '0001';
    try {
      final rows = await _transactionsSheet!.values.map.allRows();
      if (rows == null || rows.isEmpty) return '0001';

      int maxId = 0;
      for (var row in rows) {
        String idRaw = row['id'] ?? row['ID'] ?? '0';
        String idStr = idRaw.replaceAll(RegExp(r'[^0-9]'), '');
        if (idStr.isNotEmpty) {
          int? parsedId = int.tryParse(idStr);
          if (parsedId != null && parsedId > maxId) {
            maxId = parsedId;
          }
        }
      }
      return (maxId + 1).toString().padLeft(4, '0');
    } catch (e) {
      return '0001';
    }
  }

  static Future<bool> insertEntry(Map<String, dynamic> entry) async {
    if (_transactionsSheet == null) return false;
    try {
      await _transactionsSheet!.values.appendRow([
        entry['id'],
        entry['date'],
        entry['entryType'],
        entry['account'],
        entry['description'],
        entry['credit'],
        entry['debit'],
      ]);
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<List<Map<String, String>>> getAllEntries() async {
    if (_transactionsSheet == null) return [];
    try {
      final rows = await _transactionsSheet!.values.map.allRows();
      return rows ?? [];
    } catch (e) {
      return [];
    }
  }

  static Future<bool> updateEntry(
    String id,
    Map<String, dynamic> newEntry,
  ) async {
    if (_transactionsSheet == null) return false;
    try {
      final rows = await _transactionsSheet!.values.map.allRows();
      if (rows == null) return false;
      for (int i = 0; i < rows.length; i++) {
        if (rows[i]['id'] == id || rows[i]['ID'] == id) {
          await _transactionsSheet!.values.insertRow(i + 2, [
            newEntry['id'],
            newEntry['date'],
            newEntry['entryType'],
            newEntry['account'],
            newEntry['description'],
            newEntry['credit'],
            newEntry['debit'],
          ]);
          return true;
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> deleteEntry(String id) async {
    if (_transactionsSheet == null) return false;
    try {
      final rows = await _transactionsSheet!.values.map.allRows();
      if (rows == null) return false;
      for (int i = rows.length - 1; i >= 0; i--) {
        if (rows[i]['id'] == id || rows[i]['ID'] == id) {
          await _transactionsSheet!.deleteRow(i + 2);
        }
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<Map<String, List<String>>> getCategorizedAccounts() async {
    if (_accountsSheet == null) return {};
    try {
      final rows = await _accountsSheet!.values.map.allRows();
      Map<String, List<String>> accountsMap = {};
      if (rows != null) {
        for (var row in rows) {
          String head = row['head'] ?? row['Head'] ?? 'Uncategorized';
          String acc = row['account'] ?? row['Account'] ?? '';
          if (acc.isNotEmpty) {
            if (!accountsMap.containsKey(head)) accountsMap[head] = [];
            accountsMap[head]!.add(acc);
          }
        }
      }
      return accountsMap;
    } catch (e) {
      return {};
    }
  }

  static Future<bool> addAccount(String head, String account) async {
    if (_accountsSheet == null) return false;
    try {
      await _accountsSheet!.values.appendRow([head, account]);
      return true;
    } catch (e) {
      return false;
    }
  }

  // ==========================================
  // --- COTTON MODULE METHODS ---
  // ==========================================

  static Future<Map<String, String>?> getWorkerByRollNo(String rollNo) async {
    if (_kattinSheet == null) return null;
    try {
      final rows = await _kattinSheet!.values.map.allRows();
      if (rows == null) return null;

      for (var row in rows) {
        String sheetRollNo =
            row['Roll no.'] ?? row['Roll No'] ?? row['roll no'] ?? '';
        if (sheetRollNo.toString().trim() == rollNo.trim()) {
          return {
            'name': row['Name'] ?? row['name'] ?? 'Unknown Name',
            'id': row['id'] ?? row['ID'] ?? 'Unknown ID',
          };
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching worker by roll no: $e');
      return null;
    }
  }

  static Future<bool> insertCottonEntry(Map<String, dynamic> entry) async {
    if (_cottonSheet == null) return false;
    try {
      await _cottonSheet!.values.appendRow([
        entry['date'],
        entry['workerId'],
        entry['workerName'],
        entry['rollNo'],
        entry['gundiSankhya'],
        entry['noOfSut'],
        entry['sutWeight'],
        entry['rate'],
        entry['dam'],
        entry['puniWeight'],
        entry['puniRate'],
        entry['puniDam'],
        entry['finalAmount'],
        entry['prashikshanAay'],
      ]);
      return true;
    } catch (e) {
      debugPrint('Error inserting cotton entry: $e');
      return false;
    }
  }

  static Future<Map<String, String>?> getLastCottonRates() async {
    if (_cottonSheet == null) return null;
    try {
      final allRows = await _cottonSheet!.values.allRows();
      if (allRows.isEmpty) return null;

      for (int i = allRows.length - 1; i >= 1; i--) {
        List<String> row = allRows[i];
        if (row.length >= 11 &&
            row[0].trim().isNotEmpty &&
            !row[0].contains('क्रम')) {
          return {
            'noOfSut': row.length > 5 ? row[5] : '',
            'rate': row.length > 7 ? row[7] : '',
            'puniRate': row.length > 10 ? row[10] : '',
          };
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching last cotton rates: $e');
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>> getAllCottonEntries() async {
    if (_cottonSheet == null) return [];
    try {
      final allRows = await _cottonSheet!.values.allRows();
      if (allRows.length <= 1) return []; // Skip if empty or only headers

      List<Map<String, dynamic>> entries = [];
      // Start at 1 to skip header row
      for (int i = 1; i < allRows.length; i++) {
        var row = allRows[i];
        String safeGet(int index) => index < row.length ? row[index] : '';

        entries.add({
          '_rowIndex':
              i + 1, // Store the exact Google Sheet row number (1-based index)
          'date': safeGet(0),
          'workerId': safeGet(1),
          'workerName': safeGet(2),
          'rollNo': safeGet(3),
          'gundiSankhya': safeGet(4),
          'noOfSut': safeGet(5),
          'sutWeight': safeGet(6),
          'rate': safeGet(7),
          'dam': safeGet(8),
          'puniWeight': safeGet(9),
          'puniRate': safeGet(10),
          'puniDam': safeGet(11),
          'finalAmount': safeGet(12),
          'prashikshanAay': safeGet(13),
        });
      }
      return entries.reversed.toList(); // Newest entries at the top
    } catch (e) {
      debugPrint('Error fetching cotton entries: $e');
      return [];
    }
  }

  static Future<bool> updateCottonEntry(
    int rowIndex,
    Map<String, dynamic> entry,
  ) async {
    if (_cottonSheet == null) return false;
    try {
      await _cottonSheet!.values.insertRow(rowIndex, [
        entry['date'],
        entry['workerId'],
        entry['workerName'],
        entry['rollNo'],
        entry['gundiSankhya'],
        entry['noOfSut'],
        entry['sutWeight'],
        entry['rate'],
        entry['dam'],
        entry['puniWeight'],
        entry['puniRate'],
        entry['puniDam'],
        entry['finalAmount'],
        entry['prashikshanAay'],
      ]);
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> deleteCottonEntry(int rowIndex) async {
    if (_cottonSheet == null) return false;
    try {
      await _cottonSheet!.deleteRow(rowIndex);
      return true;
    } catch (e) {
      return false;
    }
  }

  // ==========================================
  // --- PAYROLL & EMPLOYEE METHODS ---
  // ==========================================

  static Future<List<Map<String, String>>> getEmployees() async {
    if (_employeesSheet == null) return [];
    try {
      final rows = await _employeesSheet!.values.allRows();
      if (rows.length <= 1) return []; // Skip header row

      List<Map<String, String>> employees = [];
      for (int i = 1; i < rows.length; i++) {
        var r = rows[i];
        String get(int idx) => idx < r.length ? r[idx].toString().trim() : '';
        if (get(1).isNotEmpty) {
          // Ensure Name is not blank
          employees.add({
            'sn': get(0),
            'name': get(1),
            'bank': get(2),
            'ifsc': get(3),
            'ac': get(4),
          });
        }
      }
      return employees;
    } catch (e) {
      debugPrint('Error fetching employees: $e');
      return [];
    }
  }

  static Future<bool> insertPayrollBatch(List<List<dynamic>> rowsData) async {
    if (_payrollsSheet == null) return false;
    try {
      for (var row in rowsData) {
        await _payrollsSheet!.values.appendRow(row);
      }
      return true;
    } catch (e) {
      debugPrint('Error inserting payroll batch: $e');
      return false;
    }
  }

  static Future<List<Map<String, dynamic>>> getPayrollEntries() async {
    if (_payrollsSheet == null) return [];
    try {
      final rows = await _payrollsSheet!.values.allRows();
      if (rows.length <= 1) return [];

      List<Map<String, dynamic>> entries = [];
      for (int i = 1; i < rows.length; i++) {
        var r = rows[i];
        String get(int idx) => idx < r.length ? r[idx].toString().trim() : '';
        entries.add({
          '_rowIndex': i + 1,
          'date': get(0),
          'chequeNo': get(1),
          'name': get(2),
          'bank': get(3),
          'ifsc': get(4),
          'ac': get(5),
          'amount': get(6),
        });
      }
      return entries.reversed.toList(); // Newest first
    } catch (e) {
      debugPrint('Error fetching payrolls: $e');
      return [];
    }
  }

  static Future<bool> updatePayrollEntry(
    int rowIndex,
    List<dynamic> rowData,
  ) async {
    if (_payrollsSheet == null) return false;
    try {
      await _payrollsSheet!.values.insertRow(rowIndex, rowData);
      return true;
    } catch (e) {
      debugPrint('Error updating payroll: $e');
      return false;
    }
  }

  static Future<bool> deletePayrollEntry(int rowIndex) async {
    if (_payrollsSheet == null) return false;
    try {
      await _payrollsSheet!.deleteRow(rowIndex);
      return true;
    } catch (e) {
      debugPrint('Error deleting payroll: $e');
      return false;
    }
  }
}
