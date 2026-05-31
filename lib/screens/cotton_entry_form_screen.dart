import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/sheets_service.dart';

class CottonEntryFormScreen extends StatefulWidget {
  const CottonEntryFormScreen({super.key});

  @override
  State<CottonEntryFormScreen> createState() => _CottonEntryFormScreenState();
}

class _CottonEntryFormScreenState extends State<CottonEntryFormScreen> {
  final _formKey = GlobalKey<FormState>();

  static DateTime? _lastSelectedDate;

  // Manual Inputs
  final TextEditingController _rollNoController = TextEditingController();
  final TextEditingController _noOfSutController = TextEditingController();
  final TextEditingController _sutWeightController = TextEditingController();
  final TextEditingController _rateController = TextEditingController();
  final TextEditingController _puniRateController = TextEditingController();

  // Fetched Worker Data
  String? _workerName;
  String? _workerId;
  late DateTime _selectedDate;

  // State
  bool _isSearching = false;
  bool _isSaving = false;

  // Auto-Calculated Fields
  double _gundiSankhya = 0.0;
  double _dam = 0.0;
  double _puniDam = 0.0;
  double _prashikshanAay = 0.0; // NEW: प्रशिक्षण आय
  double _finalAmount = 0.0;

  @override
  void initState() {
    super.initState();
    _selectedDate = _lastSelectedDate ?? DateTime.now();

    // Listeners to trigger math when user types
    _noOfSutController.addListener(_calculateTotal);
    _sutWeightController.addListener(_calculateTotal);
    _rateController.addListener(_calculateTotal);
    _puniRateController.addListener(_calculateTotal);
  }

  @override
  void dispose() {
    _rollNoController.dispose();
    _noOfSutController.dispose();
    _sutWeightController.dispose();
    _rateController.dispose();
    _puniRateController.dispose();
    super.dispose();
  }

  void _calculateTotal() {
    // Grab the values typed by the user (default to 0 if empty)
    double noOfSut = double.tryParse(_noOfSutController.text) ?? 0.0;
    double sutWeight = double.tryParse(_sutWeightController.text) ?? 0.0;
    double rate = double.tryParse(_rateController.text) ?? 0.0;
    double puniRate = double.tryParse(_puniRateController.text) ?? 0.0;

    setState(() {
      // 1. गुंडी संख्या
      _gundiSankhya = noOfSut * sutWeight;
      // 2. दाम
      _dam = sutWeight * rate;
      // 3. पुनि दाम (Puni Weight is same as Sut Weight)
      _puniDam = sutWeight * puniRate;

      // 4. प्रशिक्षण आय (NEW Formula: 0.30 * गुंडी संख्या)
      _prashikshanAay = 0.30 * _gundiSankhya;

      // 5. दी गयी रकम (Final Amount = Dam - Puni Dam - Prashikshan Aay)
      _finalAmount = _dam - _puniDam - _prashikshanAay;
    });
  }

  Future<void> _searchWorker() async {
    String rollNo = _rollNoController.text.trim();
    if (rollNo.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('कृपया रोल नंबर दर्ज करें')));
      return;
    }

    setState(() {
      _isSearching = true;
      _workerName = null;
      _workerId = null;
    });

    final workerData = await SheetsService.getWorkerByRollNo(rollNo);

    if (!mounted) return;

    setState(() {
      _isSearching = false;
    });

    if (workerData != null) {
      setState(() {
        _workerName = workerData['name'];
        _workerId = workerData['id'];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('कत्तिन मिल गई!'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('रोल नंबर नहीं मिला'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    if (_workerName == null || _workerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('कृपया पहले रोल नंबर खोजें')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    String formattedDate = DateFormat('dd/MM/yyyy').format(_selectedDate);

    // Map fields to match Google Sheets exactly, including the new column
    Map<String, dynamic> entryData = {
      'date': formattedDate,
      'workerId': _workerId,
      'workerName': _workerName,
      'rollNo': _rollNoController.text.trim(),
      'gundiSankhya': _gundiSankhya.toStringAsFixed(2),
      'noOfSut': _noOfSutController.text.trim(),
      'sutWeight': _sutWeightController.text.trim(),
      'rate': _rateController.text.trim(),
      'dam': _dam.toStringAsFixed(2),
      'puniWeight': _sutWeightController.text.trim(),
      'puniRate': _puniRateController.text.trim(),
      'puniDam': _puniDam.toStringAsFixed(2),
      'finalAmount': _finalAmount.toStringAsFixed(2),
      'prashikshanAay': _prashikshanAay.toStringAsFixed(2), // NEW COLUMN DATA
    };

    bool success = await SheetsService.insertCottonEntry(entryData);

    if (!mounted) return;

    setState(() {
      _isSaving = false;
    });

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('प्रविष्टि सफलतापूर्वक सहेजी गई!'),
          backgroundColor: Colors.green,
        ),
      );

      // Clear the form for the next entry
      setState(() {
        _rollNoController.clear();
        _workerName = null;
        _workerId = null;
        _noOfSutController.clear();
        _sutWeightController.clear();
        _rateController.clear();
        _puniRateController.clear();

        _gundiSankhya = 0.0;
        _dam = 0.0;
        _puniDam = 0.0;
        _prashikshanAay = 0.0;
        _finalAmount = 0.0;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('सहेजने में विफल'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('सूती सूत खरीद बही'),
        backgroundColor: Colors.teal.shade200,
      ),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // --- DATE SELECTOR ---
                    ListTile(
                      shape: RoundedRectangleBorder(
                        side: BorderSide(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      leading: const Icon(
                        Icons.calendar_today,
                        color: Colors.teal,
                      ),
                      title: const Text(
                        'दिनांक (Date)',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        DateFormat('dd/MM/yyyy').format(_selectedDate),
                      ),
                      onTap: () async {
                        DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: _selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setState(() {
                            _selectedDate = picked;
                            _lastSelectedDate = picked;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 20),

                    // --- ROLL NO SEARCH ---
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _rollNoController,
                            decoration: const InputDecoration(
                              labelText: 'रोल नंबर',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.badge),
                            ),
                            keyboardType: TextInputType.text,
                            validator: (value) =>
                                value!.isEmpty ? 'दर्ज करें' : null,
                            onChanged: (val) {
                              if (_workerName != null) {
                                setState(() {
                                  _workerName = null;
                                  _workerId = null;
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          height: 56,
                          child: ElevatedButton.icon(
                            onPressed: _isSearching ? null : _searchWorker,
                            icon: _isSearching
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.search),
                            label: const Text('खोजें'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal.shade100,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // --- WORKER DETAILS AND INPUT FIELDS ---
                    if (_workerName != null) ...[
                      Card(
                        color: Colors.green.shade50,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'नाम कत्तिन: $_workerName',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'ID: $_workerId',
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.blueGrey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Row 1: नं० सूत & सूत तौल
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _noOfSutController,
                              decoration: const InputDecoration(
                                labelText: 'नं० सूत',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              validator: (value) =>
                                  value!.isEmpty ? 'दर्ज करें' : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _sutWeightController,
                              decoration: const InputDecoration(
                                labelText: 'सूत तौल',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              validator: (value) =>
                                  value!.isEmpty ? 'दर्ज करें' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Row 2: दर & पूनी दर
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _rateController,
                              decoration: const InputDecoration(
                                labelText: 'दर',
                                border: OutlineInputBorder(),
                                prefixText: '₹ ',
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              validator: (value) =>
                                  value!.isEmpty ? 'दर्ज करें' : null,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _puniRateController,
                              decoration: const InputDecoration(
                                labelText: 'पूनी दर',
                                border: OutlineInputBorder(),
                                prefixText: '₹ ',
                              ),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              validator: (value) =>
                                  value!.isEmpty ? 'दर्ज करें' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // --- CALCULATIONS DISPLAY ---
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blueGrey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blueGrey.shade200),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'गुंडी संख्या:',
                                  style: TextStyle(fontSize: 16),
                                ),
                                Text(
                                  _gundiSankhya.toStringAsFixed(2),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'दाम:',
                                  style: TextStyle(fontSize: 16),
                                ),
                                Text(
                                  '₹ ${_dam.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'पुनि दाम (-):',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.orange,
                                  ),
                                ),
                                Text(
                                  '₹ ${_puniDam.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'प्रशिक्षण आय (-):',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.red,
                                  ),
                                ),
                                Text(
                                  '₹ ${_prashikshanAay.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red,
                                  ),
                                ),
                              ],
                            ),
                            const Divider(thickness: 1, height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'दी गयी रकम:',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '₹ ${_finalAmount.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.teal,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),

                      // --- SUBMIT BUTTON ---
                      ElevatedButton(
                        onPressed: _submitForm,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Colors.teal,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text(
                          'जमा करें (Submit)',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}
