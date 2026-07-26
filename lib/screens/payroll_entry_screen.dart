// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/sheets_service.dart';

class PayrollEntryScreen extends StatefulWidget {
  const PayrollEntryScreen({super.key});

  @override
  State<PayrollEntryScreen> createState() => _PayrollEntryScreenState();
}

class _PayrollEntryScreenState extends State<PayrollEntryScreen> {
  DateTime _selectedDate = DateTime.now();
  final TextEditingController _chequeController = TextEditingController();

  List<Map<String, String>> _allEmployees = [];
  final List<Map<String, String>> _selectedEmployees = [];
  final Map<String, TextEditingController> _amountControllers = {};

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadEmployees();
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
                width: 450,
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
                          return CheckboxListTile(
                            title: Text(
                              emp['name']!,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              'Bank: ${emp['bank']} | A/C: ${emp['ac']}',
                            ),
                            value: isAlreadyAdded,
                            onChanged: (bool? val) {
                              setDialogState(() {
                                setState(() {
                                  if (val == true && !isAlreadyAdded) {
                                    _selectedEmployees.add(emp);
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
    String dateStr = DateFormat('dd/MM/yyyy').format(_selectedDate);
    String chequeNo = _chequeController.text.trim();

    List<List<dynamic>> batchRows = [];
    for (var emp in _selectedEmployees) {
      String key = emp['name']! + emp['ac']!;
      String amountStr = _amountControllers[key]?.text.trim() ?? '0.00';
      double amount = double.tryParse(amountStr) ?? 0.00;

      // Structure: Date | Cheque No. | Name | Bank | IFSC Code | A/C no. | Amount
      batchRows.add([
        dateStr,
        chequeNo,
        emp['name']!,
        emp['bank']!,
        emp['ifsc']!,
        emp['ac']!,
        amount.toStringAsFixed(2),
      ]);
    }

    bool success = await SheetsService.insertPayrollBatch(batchRows);
    setState(() => _isSaving = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payroll Batch Saved Successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to save batch.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'New Payroll Batch',
          style: TextStyle(fontWeight: FontWeight.w600),
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
                  // TOP HALF: Global Controls
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 1,
                            child: OutlinedButton.icon(
                              icon: const Icon(
                                Icons.calendar_today,
                                color: Colors.indigo,
                              ),
                              label: Text(
                                DateFormat('dd/MM/yyyy').format(_selectedDate),
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
                                  vertical: 16,
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
                                labelText:
                                    'Master Cheque No. (सभी के लिए एक चेक नं०)',
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
                            label: const Text('Select Employees'),
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

                  // BOTTOM HALF: Selected Employees Grid
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
                                        'Selected Employees (${_selectedEmployees.length})',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: Colors.indigo,
                                        ),
                                      ),
                                      const Text(
                                        'Enter Amount (₹)',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
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
                                            onPressed: () {
                                              setState(() {
                                                _selectedEmployees.removeAt(
                                                  index,
                                                );
                                                _amountControllers.remove(key);
                                              });
                                            },
                                          ),
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
                                                    fontSize: 15,
                                                  ),
                                                ),
                                                Text(
                                                  'Bank: ${emp['bank']} | A/C: ${emp['ac']} | IFSC: ${emp['ifsc']}',
                                                  style: TextStyle(
                                                    color: Colors.grey.shade600,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Expanded(
                                            flex: 1,
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
                                                      horizontal: 10,
                                                      vertical: 8,
                                                    ),
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

                  // Submit Button
                  ElevatedButton(
                    onPressed: _isSaving ? null : _submitBatch,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
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
                        : const Text(
                            'SAVE PAYROLL BATCH (वेतन सुरक्षित करें)',
                            style: TextStyle(
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
