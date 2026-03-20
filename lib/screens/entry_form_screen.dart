// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/sheets_service.dart';

List<Map<String, dynamic>> globalBatchEntries = [];

class EntryFormScreen extends StatefulWidget {
  const EntryFormScreen({super.key});

  @override
  State<EntryFormScreen> createState() => _EntryFormScreenState();
}

class _EntryFormScreenState extends State<EntryFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _descController = TextEditingController();
  final TextEditingController _debitController = TextEditingController();
  final TextEditingController _creditController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  String _entryType = 'Rokad';

  bool _isLoadingAccounts = true;
  bool _isSubmittingBatch = false;

  bool _isBatchMode = true;

  Map<String, List<String>> _categorizedAccounts = {};
  String? _selectedHead;
  String? _selectedAccount;

  double get _totalDebit => globalBatchEntries.fold(
    0,
    (sum, item) => sum + (double.tryParse(item['debit'].toString()) ?? 0.0),
  );
  double get _totalCredit => globalBatchEntries.fold(
    0,
    (sum, item) => sum + (double.tryParse(item['credit'].toString()) ?? 0.0),
  );
  bool get _isBalanced =>
      _totalDebit == _totalCredit &&
      globalBatchEntries.isNotEmpty &&
      _totalDebit > 0;

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    setState(() => _isLoadingAccounts = true);
    final accounts = await SheetsService.getCategorizedAccounts();

    DateTime lastDate = DateTime.now();
    try {
      final rows = await SheetsService.getAllEntries();
      if (rows.isNotEmpty) {
        rows.sort((a, b) {
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

        String dateStr = rows.last['Date'] ?? rows.last['date'] ?? '';
        if (int.tryParse(dateStr) != null && dateStr.length == 5) {
          lastDate = DateTime(
            1899,
            12,
            30,
          ).add(Duration(days: int.parse(dateStr)));
        } else {
          try {
            lastDate = DateFormat('dd/MM/yyyy').parse(dateStr);
          } catch (_) {
            try {
              lastDate = DateFormat('yyyy-MM-dd').parse(dateStr);
            } catch (_) {
              lastDate = DateTime.tryParse(dateStr) ?? DateTime.now();
            }
          }
        }
      }
    } catch (_) {
      // Ignored: Fallback to current date
    }

    setState(() {
      _categorizedAccounts = accounts;
      _selectedDate = lastDate;
      _isLoadingAccounts = false;
      if (_selectedHead != null &&
          !_categorizedAccounts.containsKey(_selectedHead)) {
        _selectedHead = null;
        _selectedAccount = null;
      }
    });
  }

  Future<void> _addNewAccountDialog() async {
    final headController = TextEditingController(text: _selectedHead);
    final accController = TextEditingController();
    bool isSaving = false;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text('Add New Account'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: headController,
                decoration: const InputDecoration(labelText: 'Head / Category'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: accController,
                decoration: const InputDecoration(labelText: 'Particular Name'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      if (headController.text.isNotEmpty &&
                          accController.text.isNotEmpty) {
                        setStateDialog(() => isSaving = true);
                        await SheetsService.addAccount(
                          headController.text.trim(),
                          accController.text.trim(),
                        );
                        if (!mounted) {
                          return;
                        }
                        Navigator.pop(context);
                        _fetchInitialData();
                      }
                    },
              child: isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  void _processFormSubmission() {
    if (_formKey.currentState!.validate()) {
      if (_selectedAccount == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a Particular.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final String debitVal = _debitController.text.isEmpty
          ? '0'
          : _debitController.text;
      final String creditVal = _creditController.text.isEmpty
          ? '0'
          : _creditController.text;

      final entryData = {
        'date': DateFormat('MM/dd/yyyy').format(_selectedDate),
        'displayDate': DateFormat('dd/MM/yyyy').format(_selectedDate),
        'entryType': _entryType,
        'head': _selectedHead,
        'account': _selectedAccount,
        'description': _descController.text,
        'debit': debitVal,
        'credit': creditVal,
      };

      if (_isBatchMode) {
        setState(() {
          globalBatchEntries.add(entryData);
          _descController.clear();
          _debitController.clear();
          _creditController.clear();
          _selectedHead = null;
          _selectedAccount = null;
        });
      } else {
        _submitSingleEntry(entryData);
      }
    }
  }

  Future<void> _submitSingleEntry(Map<String, dynamic> entry) async {
    setState(() => _isSubmittingBatch = true);
    try {
      final String generateId = await SheetsService.getNextId();
      entry['id'] = generateId;
      bool success = await SheetsService.insertEntry(entry);

      if (success) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Entry $generateId saved!'),
            backgroundColor: Colors.green,
          ),
        );
        _descController.clear();
        _debitController.clear();
        _creditController.clear();
        setState(() {
          _selectedHead = null;
          _selectedAccount = null;
        });
      } else {
        throw Exception("Failed to save.");
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to save entry.'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmittingBatch = false);
      }
    }
  }

  Future<void> _submitEntireBatch() async {
    if (!_isBalanced) {
      return;
    }
    setState(() => _isSubmittingBatch = true);

    try {
      for (var entry in globalBatchEntries) {
        final String generateId = await SheetsService.getNextId();
        entry['id'] = generateId;
        bool success = await SheetsService.insertEntry(entry);
        if (!success) {
          throw Exception("Failed to insert ${entry['account']}");
        }
      }
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Entire batch successfully saved!'),
          backgroundColor: Colors.green,
        ),
      );
      setState(() => globalBatchEntries.clear());
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving batch: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmittingBatch = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    List<String> availableHeads = _categorizedAccounts.keys.toList();
    List<String> availableAccounts = _selectedHead != null
        ? (_categorizedAccounts[_selectedHead] ?? [])
        : [];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        leadingWidth:
            120, // Increased width to fit both the back button and the switch
        leading: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.pop(context),
            ),
            Switch(
              value: _isBatchMode,
              activeTrackColor: Colors.green.shade300,
              thumbColor: const WidgetStatePropertyAll(Colors.green),
              onChanged: (val) => setState(() => _isBatchMode = val),
            ),
          ],
        ),
        title: Text(_isBatchMode ? 'Batch Entry' : 'Single Entry'),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: OutlinedButton.icon(
                                onPressed: _pickDate,
                                icon: const Icon(
                                  Icons.calendar_today,
                                  size: 18,
                                ),
                                label: Text(
                                  DateFormat(
                                    'dd/MM/yyyy',
                                  ).format(_selectedDate),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 1,
                              child: DropdownButtonFormField<String>(
                                key: ValueKey('type-$_entryType'),
                                initialValue: _entryType,
                                decoration: const InputDecoration(
                                  labelText: 'Type',
                                  border: OutlineInputBorder(),
                                ),
                                items: ['Rokad', 'Jama-Kharchi']
                                    .map(
                                      (v) => DropdownMenuItem(
                                        value: v,
                                        child: Text(v),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (v) =>
                                    setState(() => _entryType = v!),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                children: [
                                  DropdownButtonFormField<String>(
                                    key: ValueKey('head-$_selectedHead'),
                                    initialValue: _selectedHead,
                                    decoration: const InputDecoration(
                                      labelText: 'Select Head',
                                      border: OutlineInputBorder(),
                                    ),
                                    items: availableHeads
                                        .map(
                                          (h) => DropdownMenuItem(
                                            value: h,
                                            child: Text(h),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (v) => setState(() {
                                      _selectedHead = v;
                                      _selectedAccount = null;
                                    }),
                                  ),
                                  const SizedBox(height: 12),
                                  DropdownButtonFormField<String>(
                                    key: ValueKey('account-$_selectedAccount'),
                                    initialValue: _selectedAccount,
                                    decoration: const InputDecoration(
                                      labelText: 'Select Particular',
                                      border: OutlineInputBorder(),
                                    ),
                                    items: availableAccounts
                                        .map(
                                          (a) => DropdownMenuItem(
                                            value: a,
                                            child: Text(a),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (v) =>
                                        setState(() => _selectedAccount = v),
                                    disabledHint: const Text(
                                      'Select a Head first',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(
                                Icons.add_circle,
                                color: Colors.blue,
                                size: 36,
                              ),
                              tooltip: 'Create New Particular',
                              onPressed: _addNewAccountDialog,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _descController,
                          decoration: const InputDecoration(
                            labelText: 'Description',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _creditController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Credit (Cr)',
                                  border: OutlineInputBorder(),
                                  prefixText: '₹ ',
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: _debitController,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Debit (Dr)',
                                  border: OutlineInputBorder(),
                                  prefixText: '₹ ',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: _isBatchMode
                                ? Theme.of(context).colorScheme.primaryContainer
                                : Colors.blue,
                            foregroundColor: _isBatchMode
                                ? Colors.black
                                : Colors.white,
                          ),
                          onPressed:
                              _isLoadingAccounts ||
                                  (_isSubmittingBatch && !_isBatchMode)
                              ? null
                              : _processFormSubmission,
                          icon: _isSubmittingBatch && !_isBatchMode
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Icon(
                                  _isBatchMode
                                      ? Icons.add_task
                                      : Icons.cloud_upload,
                                ),
                          label: Text(
                            _isBatchMode
                                ? 'Add to Local Batch'
                                : 'Save Directly to Database',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (_isBatchMode && globalBatchEntries.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const Divider(thickness: 2),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(
                        "Local Staging Area",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: globalBatchEntries.length,
                      itemBuilder: (context, index) {
                        final entry = globalBatchEntries[index];
                        return Card(
                          elevation: 2,
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            title: Text(
                              "${entry['account']} (${entry['displayDate']})",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              "${entry['description'].toString().isNotEmpty ? entry['description'] + '\n' : ''}Dr: ₹${entry['debit']}  |  Cr: ₹${entry['credit']}",
                            ),
                            isThreeLine: entry['description']
                                .toString()
                                .isNotEmpty,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit,
                                    color: Colors.blue,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      try {
                                        _selectedDate = DateFormat(
                                          'MM/dd/yyyy',
                                        ).parse(entry['date']);
                                      } catch (_) {}
                                      _entryType = entry['entryType'];
                                      if (availableHeads.contains(
                                        entry['head'],
                                      )) {
                                        _selectedHead = entry['head'];
                                        if ((_categorizedAccounts[entry['head']] ??
                                                [])
                                            .contains(entry['account'])) {
                                          _selectedAccount = entry['account'];
                                        }
                                      }
                                      _descController.text =
                                          entry['description'];
                                      _debitController.text =
                                          entry['debit'] == '0'
                                          ? ''
                                          : entry['debit'];
                                      _creditController.text =
                                          entry['credit'] == '0'
                                          ? ''
                                          : entry['credit'];
                                      globalBatchEntries.removeAt(index);
                                    });
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                  onPressed: () => setState(
                                    () => globalBatchEntries.removeAt(index),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),

          if (_isBatchMode)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(26),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: globalBatchEntries.isEmpty
                      ? Colors.grey
                      : (_isBalanced ? Colors.green : Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  minimumSize: const Size(double.infinity, 50),
                ),
                onPressed: (_isSubmittingBatch || globalBatchEntries.isEmpty)
                    ? null
                    : (_isBalanced
                          ? _submitEntireBatch
                          : () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    "Cannot save! Debits and Credits must be equal.",
                                  ),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                            }),
                child: _isSubmittingBatch
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        globalBatchEntries.isEmpty
                            ? 'Add entries to batch'
                            : (_isBalanced
                                  ? 'Save Batch to Database'
                                  : 'Unbalanced (Dr: ₹$_totalDebit | Cr: ₹$_totalCredit)'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
        ],
      ),
    );
  }
}
