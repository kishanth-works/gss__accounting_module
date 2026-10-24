// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/sheets_service.dart';
// Import the smart bank detector from the report screen
import 'payroll_report_screen.dart' show getBankName;

class PayrollEntryScreen extends StatefulWidget {
  final String? editChequeNo;
  final String? editDate;
  final List<Map<String, dynamic>>? editEntries;

  const PayrollEntryScreen({
    super.key,
    this.editChequeNo,
    this.editDate,
    this.editEntries,
  });

  @override
  State<PayrollEntryScreen> createState() => _PayrollEntryScreenState();
}

class _PayrollEntryScreenState extends State<PayrollEntryScreen> {
  DateTime _selectedDate = DateTime.now();
  final TextEditingController _chequeController = TextEditingController();

  List<Map<String, String>> _allEmployees = [];
  final List<Map<String, dynamic>> _selectedEmployees = [];
  final Map<String, TextEditingController> _amountControllers = {};

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _initializeEditMode();
    _loadEmployees();
  }

  void _initializeEditMode() {
    if (widget.editChequeNo != null) {
      _chequeController.text = widget.editChequeNo!;
    }

    if (widget.editDate != null) {
      try {
        _selectedDate = DateFormat(
          'dd/MM/yyyy',
        ).parseStrict(widget.editDate!.replaceAll("'", ""));
      } catch (_) {
        try {
          _selectedDate = DateFormat(
            'yyyy-MM-dd',
          ).parseStrict(widget.editDate!);
        } catch (_) {}
      }
    }

    if (widget.editEntries != null) {
      for (var entry in widget.editEntries!) {
        _selectedEmployees.add({
          'name': entry['name'] ?? '',
          'bank': entry['bank'] ?? '',
          'ifsc': entry['ifsc'] ?? '',
          'ac': entry['ac'] ?? '',
          '_rowIndex': entry['_rowIndex'],
        });

        String key = (entry['name'] ?? '') + (entry['ac'] ?? '');
        _amountControllers[key] = TextEditingController(
          text: entry['amount']?.toString() ?? '',
        );
      }
    }
  }

  @override
  void dispose() {
    _chequeController.dispose();
    for (var ctrl in _amountControllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  Future<void> _loadEmployees() async {
    setState(() => _isLoading = true);
    final data = await SheetsService.getEmployees();
    if (!mounted) return;
    setState(() {
      _allEmployees = data;
      _isLoading = false;
    });
  }

  void _showEmployeeSelectDialog() {
    List<Map<String, String>> filtered = List.from(_allEmployees);
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text(
                'Select Employees',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.9,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Search Employee Name or A/C...',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (query) {
                        setDialogState(() {
                          filtered = _allEmployees.where((emp) {
                            final name = emp['name']!.toLowerCase();
                            final ac = emp['ac']!.toLowerCase();
                            final q = query.toLowerCase();
                            return name.contains(q) || ac.contains(q);
                          }).toList();
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final emp = filtered[index];
                          final isAlreadyAdded = _selectedEmployees.any(
                            (e) =>
                                e['name'] == emp['name'] &&
                                e['ac'] == emp['ac'],
                          );

                          // SMART UI: Uses the auto-detector here too!
                          String smartBankName = getBankName(
                            emp['bank'] ?? '',
                            emp['ifsc'] ?? '',
                          );

                          return CheckboxListTile(
                            title: Text(
                              emp['name']!,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              'Bank: $smartBankName | A/C: ${emp['ac']}',
                            ),
                            value: isAlreadyAdded,
                            onChanged: (bool? val) {
                              setDialogState(() {
                                setState(() {
                                  if (val == true && !isAlreadyAdded) {
                                    _selectedEmployees.add({
                                      'name': emp['name']!,
                                      'bank': emp['bank']!,
                                      'ifsc': emp['ifsc']!,
                                      'ac': emp['ac']!,
                                      '_rowIndex': null,
                                    });
                                    _amountControllers[emp['name']! +
                                            emp['ac']!] =
                                        TextEditingController();
                                  } else {
                                    _selectedEmployees.removeWhere(
                                      (e) =>
                                          e['name'] == emp['name'] &&
                                          e['ac'] == emp['ac'],
                                    );
                                    _amountControllers.remove(
                                      emp['name']! + emp['ac']!,
                                    );
                                  }
                                });
                              });
                            },
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
                  child: const Text('Done'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _submitBatch() async {
    if (_chequeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a Master Cheque Number.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (_selectedEmployees.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one employee.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    String chequeNo = _chequeController.text.trim();

    // FIX: Lock to ISO format so Google Sheets NEVER flips dates again!
    String dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

    if (widget.editEntries != null) {
      for (var emp in _selectedEmployees) {
        if (emp['_rowIndex'] != null) {
          String key = emp['name']! + emp['ac']!;
          double amount =
              double.tryParse(_amountControllers[key]?.text.trim() ?? '0') ??
              0.0;
          await SheetsService.updatePayrollEntry(emp['_rowIndex'], [
            dateStr,
            chequeNo,
            emp['name'],
            emp['bank'],
            emp['ifsc'],
            emp['ac'],
            amount.toStringAsFixed(2),
          ]);
        }
      }

      List<List<dynamic>> newRows = [];
      for (var emp in _selectedEmployees) {
        if (emp['_rowIndex'] == null) {
          String key = emp['name']! + emp['ac']!;
          double amount =
              double.tryParse(_amountControllers[key]?.text.trim() ?? '0') ??
              0.0;
          newRows.add([
            dateStr,
            chequeNo,
            emp['name'],
            emp['bank'],
            emp['ifsc'],
            emp['ac'],
            amount.toStringAsFixed(2),
          ]);
        }
      }
      if (newRows.isNotEmpty) await SheetsService.insertPayrollBatch(newRows);

      List<int> rowsToDelete = [];
      for (var originalEntry in widget.editEntries!) {
        bool stillExists = _selectedEmployees.any(
          (e) =>
              e['name'] == originalEntry['name'] &&
              e['ac'] == originalEntry['ac'],
        );
        if (!stillExists && originalEntry['_rowIndex'] != null) {
          rowsToDelete.add(originalEntry['_rowIndex']);
        }
      }
      rowsToDelete.sort((a, b) => b.compareTo(a));
      for (int rowIndex in rowsToDelete) {
        await SheetsService.deletePayrollEntry(rowIndex);
      }
    } else {
      List<List<dynamic>> batchRows = [];
      for (var emp in _selectedEmployees) {
        String key = emp['name']! + emp['ac']!;
        double amount =
            double.tryParse(_amountControllers[key]?.text.trim() ?? '0') ?? 0.0;
        batchRows.add([
          dateStr,
          chequeNo,
          emp['name'],
          emp['bank'],
          emp['ifsc'],
          emp['ac'],
          amount.toStringAsFixed(2),
        ]);
      }
      await SheetsService.insertPayrollBatch(batchRows);
    }

    setState(() => _isSaving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Payroll Batch Saved Successfully!'),
        backgroundColor: Colors.green,
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 600;
    final bool isEditMode = widget.editEntries != null;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          isEditMode ? 'Edit Payroll Batch' : 'New Payroll Batch',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.indigo.shade700,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: isMobile
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                OutlinedButton.icon(
                                  icon: const Icon(
                                    Icons.calendar_today,
                                    color: Colors.indigo,
                                  ),
                                  label: Text(
                                    DateFormat(
                                      'dd/MM/yyyy',
                                    ).format(_selectedDate),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
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
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _chequeController,
                                  decoration: const InputDecoration(
                                    labelText: 'Master Cheque No.',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(
                                      Icons.numbers,
                                      color: Colors.indigo,
                                    ),
                                    isDense: true,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ElevatedButton.icon(
                                  onPressed: _showEmployeeSelectDialog,
                                  icon: const Icon(Icons.person_add),
                                  label: const Text('Select Employees'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.indigo,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Row(
                              children: [
                                Expanded(
                                  flex: 1,
                                  child: OutlinedButton.icon(
                                    icon: const Icon(
                                      Icons.calendar_today,
                                      color: Colors.indigo,
                                    ),
                                    label: Text(
                                      DateFormat(
                                        'dd/MM/yyyy',
                                      ).format(_selectedDate),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
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
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 18,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  flex: 2,
                                  child: TextField(
                                    controller: _chequeController,
                                    decoration: const InputDecoration(
                                      labelText: 'Master Cheque No.',
                                      border: OutlineInputBorder(),
                                      prefixIcon: Icon(
                                        Icons.numbers,
                                        color: Colors.indigo,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                ElevatedButton.icon(
                                  onPressed: _showEmployeeSelectDialog,
                                  icon: const Icon(Icons.person_add),
                                  label: const Text('Add/Select Employees'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.indigo,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 18,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _selectedEmployees.isEmpty
                        ? Center(
                            child: Text(
                              'No employees selected.\nClick "Select Employees" above to start.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 16,
                              ),
                            ),
                          )
                        : Card(
                            elevation: 2,
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  color: Colors.indigo.shade50,
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Selected (${_selectedEmployees.length})',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: Colors.indigo,
                                        ),
                                      ),
                                      const Text(
                                        'Amount (₹)',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: Colors.indigo,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: ListView.separated(
                                    padding: const EdgeInsets.all(12),
                                    itemCount: _selectedEmployees.length,
                                    separatorBuilder: (_, _) => const Divider(),
                                    itemBuilder: (context, index) {
                                      final emp = _selectedEmployees[index];
                                      final key = emp['name']! + emp['ac']!;
                                      return Row(
                                        children: [
                                          IconButton(
                                            icon: const Icon(
                                              Icons.delete_outline,
                                              color: Colors.red,
                                            ),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            onPressed: () => setState(() {
                                              _selectedEmployees.removeAt(
                                                index,
                                              );
                                              _amountControllers.remove(key);
                                            }),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            flex: 3,
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  emp['name']!,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                Text(
                                                  'A/C: ${emp['ac']}',
                                                  style: TextStyle(
                                                    color: Colors.grey.shade600,
                                                    fontSize: 12,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          SizedBox(
                                            width: isMobile ? 110 : 150,
                                            child: TextFormField(
                                              controller:
                                                  _amountControllers[key],
                                              keyboardType:
                                                  const TextInputType.numberWithOptions(
                                                    decimal: true,
                                                  ),
                                              textAlign: TextAlign.right,
                                              decoration: const InputDecoration(
                                                prefixText: '₹ ',
                                                border: OutlineInputBorder(),
                                                contentPadding:
                                                    EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 8,
                                                    ),
                                                isDense: true,
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _submitBatch,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isEditMode
                          ? Colors.orange.shade700
                          : Colors.green.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            isEditMode
                                ? 'UPDATE BATCH (अपडेट करें)'
                                : 'SAVE PAYROLL BATCH (वेतन सुरक्षित करें)',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}
