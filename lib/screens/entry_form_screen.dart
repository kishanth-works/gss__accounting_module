// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/sheets_service.dart';

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

  // NEW DEFAULT TYPE
  String _entryType = 'Rokad';

  bool _isLoading = false;
  bool _isLoadingAccounts = true;

  Map<String, List<String>> _categorizedAccounts = {};
  String? _selectedHead;
  String? _selectedAccount;

  @override
  void initState() {
    super.initState();
    _fetchAccounts();
  }

  Future<void> _fetchAccounts() async {
    setState(() => _isLoadingAccounts = true);
    final accounts = await SheetsService.getCategorizedAccounts();
    setState(() {
      _categorizedAccounts = accounts;
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
                decoration: const InputDecoration(
                  labelText: 'Head / Category (e.g., Bank)',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: accController,
                decoration: const InputDecoration(
                  labelText: 'Account Name (e.g., SBI Bank)',
                ),
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
                        if (!mounted) return;
                        Navigator.pop(context);
                        _fetchAccounts();
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

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedAccount == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select an Account.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      setState(() => _isLoading = true);

      final String generateId = await SheetsService.getNextId();
      final String debitVal = _debitController.text.isEmpty
          ? '0'
          : _debitController.text;
      final String creditVal = _creditController.text.isEmpty
          ? '0'
          : _creditController.text;

      final entryData = {
        'id': generateId,
        'date': DateFormat('yyyy-MM-dd').format(_selectedDate),
        'entryType': _entryType,
        'account': _selectedAccount,
        'description': _descController.text,
        'debit': debitVal,
        'credit': creditVal,
      };

      bool success = await SheetsService.insertEntry(entryData);

      setState(() => _isLoading = false);

      if (success) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Entry $generateId saved!'),
            backgroundColor: Colors.green,
          ),
        );
        _formKey.currentState!.reset();
        _descController.clear();
        _debitController.clear();
        _creditController.clear();
        setState(() {
          _selectedHead = null;
          _selectedAccount = null;
        });
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save entry.'),
            backgroundColor: Colors.red,
          ),
        );
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
        title: const Text('New Entry'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
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
                      icon: const Icon(Icons.calendar_today, size: 18),
                      label: Text(
                        DateFormat('yyyy-MM-dd').format(_selectedDate),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 1,
                    child: DropdownButtonFormField<String>(
                      initialValue: _entryType,
                      decoration: const InputDecoration(
                        labelText: 'Type',
                        border: OutlineInputBorder(),
                      ),
                      // UPDATED TO TRADITIONAL NAMES
                      items: ['Rokad', 'Jama-Kharchi']
                          .map(
                            (v) => DropdownMenuItem(value: v, child: Text(v)),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _entryType = v!),
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
                          initialValue: _selectedHead,
                          decoration: const InputDecoration(
                            labelText: 'Select Head',
                            border: OutlineInputBorder(),
                          ),
                          items: availableHeads
                              .map(
                                (h) =>
                                    DropdownMenuItem(value: h, child: Text(h)),
                              )
                              .toList(),
                          onChanged: (v) => setState(() {
                            _selectedHead = v;
                            _selectedAccount = null;
                          }),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedAccount,
                          decoration: const InputDecoration(
                            labelText: 'Select Account',
                            border: OutlineInputBorder(),
                          ),
                          items: availableAccounts
                              .map(
                                (a) =>
                                    DropdownMenuItem(value: a, child: Text(a)),
                              )
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _selectedAccount = v),
                          disabledHint: const Text('Select a Head first'),
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
                    tooltip: 'Create New Account',
                    onPressed: _addNewAccountDialog,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _descController,
                decoration: const InputDecoration(
                  labelText: 'Particulars / Narration',
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
                        labelText: 'Credit Amount (Cr)',
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
                        labelText: 'Debit Amount (Dr)',
                        border: OutlineInputBorder(),
                        prefixText: '₹ ',
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primaryContainer,
                ),
                onPressed: (_isLoading || _isLoadingAccounts)
                    ? null
                    : _submitForm,
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text(
                        'Save Entry',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
