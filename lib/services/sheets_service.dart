import 'package:flutter/foundation.dart';
import 'package:gsheets/gsheets.dart';
import '../secrets.dart';

class SheetsService {
  // 1. Pass the secret JSON string directly from Secrets!
  static final _gsheets = GSheets(Secrets.credentialsJson);
  // REPLACE THESE WITH YOUR ACTUAL KEYS!
  static Worksheet? _transactionsSheet;
  static Worksheet? _accountsSheet; // NEW: For dynamic accounts

  static Future<void> init() async {
    try {
      // 2. Pass the secret Spreadsheet ID directly from Secrets!
      final spreadsheet = await _gsheets.spreadsheet(Secrets.spreadsheetId);
      _transactionsSheet = spreadsheet.worksheetByTitle('Transactions');
      _accountsSheet = spreadsheet.worksheetByTitle('Accounts');

      // Auto-create Accounts sheet if it doesn't exist yet
      _accountsSheet ??= await spreadsheet.addWorksheet('Accounts');

      debugPrint('Google Sheets Initialized Successfully!');
    } catch (e) {
      debugPrint('Error initializing Sheets: $e');
    }
  }

  // FIXED: Strictly sequential IDs starting at 0001
  static Future<String> getNextId() async {
    if (_transactionsSheet == null) return '0001';
    try {
      final rows = await _transactionsSheet!.values.map.allRows();
      if (rows == null || rows.isEmpty) return '0001';

      int maxId = 0;
      for (var row in rows) {
        String idRaw = row['id'] ?? row['ID'] ?? '0';
        // Strip out any non-numeric characters (like 'TXN-')
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

  // RESTORED: Single row entry
  static Future<bool> insertEntry(Map<String, dynamic> entry) async {
    if (_transactionsSheet == null) return false;
    try {
      await _transactionsSheet!.values.appendRow([
        entry['id'],
        entry['date'],
        entry['entryType'],
        entry['account'], // We just save the selected account
        entry['description'],
        entry['credit'],
        entry['debit'],
      ]);
      return true;
    } catch (e) {
      return false;
    }
  }

  // FETCH TRANSACTIONS
  static Future<List<Map<String, String>>> getAllEntries() async {
    if (_transactionsSheet == null) return [];
    try {
      final rows = await _transactionsSheet!.values.map.allRows();
      return rows ?? [];
    } catch (e) {
      return [];
    }
  }

  // UPDATE TRANSACTION
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

  // DELETE TRANSACTION
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

  // --- NEW: DYNAMIC ACCOUNTS LOGIC ---
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
}
