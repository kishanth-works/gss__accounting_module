// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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

  @override
  void initState() {
    super.initState();
    _fetchTransactions();
  }

  Future<void> _fetchTransactions({bool isSilent = false}) async {
    if (!isSilent) {
      setState(() {
        _isLoading = true;
      });
    }
    try {
      final rawRows = await SheetsService.getAllEntries();
      List<Map<String, dynamic>> parsedRows = [];

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
                rowDate = DateFormat('yyyy-MM-dd').parse(dateStr);
              } catch (_) {
                rowDate = DateTime.tryParse(dateStr);
              }
            }
          }

          if (_selectedDateRange != null && rowDate != null) {
            if (rowDate.isBefore(_selectedDateRange!.start) ||
                rowDate.isAfter(
                  _selectedDateRange!.end.add(const Duration(days: 1)),
                )) {
              continue;
            }
          }

          if (rowDate != null) {
            row['displayDate'] = DateFormat('yyyy-MM-dd').format(rowDate);
          } else {
            row['displayDate'] = dateStr;
          }

          parsedRows.add(row);
        } catch (e) {
          continue;
        }
      }

      parsedRows.sort((a, b) {
        DateTime dateA =
            DateTime.tryParse(a['displayDate'] ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        DateTime dateB =
            DateTime.tryParse(b['displayDate'] ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0);

        int dateComparison = dateB.compareTo(dateA);
        if (dateComparison != 0) {
          return dateComparison;
        } else {
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
        }
      });

      setState(() {
        _allTransactions = parsedRows;
        _applySearchFilter();
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

  void _applySearchFilter() {
    if (_searchQuery.isEmpty) {
      _filteredTransactions = _allTransactions;
    } else {
      _filteredTransactions = _allTransactions.where((row) {
        final account = (row['Account'] ?? row['account'] ?? '').toLowerCase();
        final desc = (row['Description'] ?? row['description'] ?? '')
            .toLowerCase();
        final id = (row['ID'] ?? row['id'] ?? '').toLowerCase();
        final query = _searchQuery.toLowerCase();
        return account.contains(query) ||
            desc.contains(query) ||
            id.contains(query);
      }).toList();
    }
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
      _fetchTransactions();
    }
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
              setState(() {
                _isLoading = true;
              });

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
                  setState(() {
                    _isLoading = false;
                  });
                }
              } catch (e) {
                if (mounted) {
                  setState(() {
                    _isLoading = false;
                  });
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
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Search Account or Particulars...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val;
                        _applySearchFilter();
                      });
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 1,
                  child: InkWell(
                    onTap: _selectDateRange,
                    child: Container(
                      height: 55,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Center(
                        child: Text(
                          _selectedDateRange == null
                              ? 'Filter Date'
                              : '${DateFormat('MMM dd').format(_selectedDateRange!.start)} - ${DateFormat('MMM dd').format(_selectedDateRange!.end)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredTransactions.isEmpty
                ? const Center(child: Text('No entries match your search.'))
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
                              'Account',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Particulars',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Credit',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            numeric: true,
                          ), // SWAPPED!
                          DataColumn(
                            label: Text(
                              'Debit',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            numeric: true,
                          ), // SWAPPED!
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

    String id = row['ID'] ?? row['id'] ?? '';
    String date = row['displayDate'] ?? '';
    String type = row['EntryType'] ?? row['entryType'] ?? '';
    String account = row['Account'] ?? row['account'] ?? '';
    String desc = row['Description'] ?? row['description'] ?? '';

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
        DataCell(Text(id)),
        DataCell(Text(date)),
        DataCell(Text(type)),
        DataCell(Text(account)),
        DataCell(Text(desc)),
        DataCell(
          Text('₹$creditStr'),
        ), // SWAPPED: Credit is mapped to the new column
        DataCell(
          Text('₹$debitStr'),
        ), // SWAPPED: Debit is mapped to the new column
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
                onPressed: () => onDelete(id),
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

    // SMART MAPPER: Converts old 'Cash' and 'Journal' entries to the new format automatically
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

    _selectedDate =
        DateTime.tryParse(widget.transaction['displayDate'] ?? '') ??
        DateTime.now();
  }

  Future<void> _updateEntry() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isSaving = true;
      });

      Map<String, dynamic> updatedEntry = {
        'id': widget.transaction['ID'] ?? widget.transaction['id'],
        'date': DateFormat('yyyy-MM-dd').format(_selectedDate),
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
        setState(() {
          _isSaving = false;
        });
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
                          setState(() {
                            _selectedDate = picked;
                          });
                        }
                      },
                      child: Text(
                        DateFormat('yyyy-MM-dd').format(_selectedDate),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _entryType,
                      // STRICTLY TWO TRADITIONAL OPTIONS
                      items: ['Rokad', 'Jama-Kharchi']
                          .map(
                            (v) => DropdownMenuItem(value: v, child: Text(v)),
                          )
                          .toList(),
                      onChanged: (val) {
                        setState(() {
                          _entryType = val!;
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descController,
                decoration: const InputDecoration(
                  labelText: 'Particulars/Description',
                ),
              ),
              const SizedBox(height: 12),
              // SWAPPED: Credit is edited before Debit
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
