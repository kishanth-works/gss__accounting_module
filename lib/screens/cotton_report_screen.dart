import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/sheets_service.dart';

class CottonReportScreen extends StatefulWidget {
  const CottonReportScreen({super.key});

  @override
  State<CottonReportScreen> createState() => _CottonReportScreenState();
}

class _CottonReportScreenState extends State<CottonReportScreen> {
  List<Map<String, dynamic>> _allEntries = [];
  List<Map<String, dynamic>> _filteredEntries = [];

  bool _isLoading = true;
  DateTimeRange? _selectedDateRange;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchData();
    _searchController.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    final data = await SheetsService.getAllCottonEntries();
    if (!mounted) return;
    setState(() {
      _allEntries = data;
      _isLoading = false;
    });
    _applyFilters();
  }

  void _applyFilters() {
    List<Map<String, dynamic>> temp = List.from(_allEntries);

    // Apply Search Filter (Roll No or Name)
    String query = _searchController.text.toLowerCase().trim();
    if (query.isNotEmpty) {
      temp = temp.where((entry) {
        final name = (entry['workerName'] ?? '').toLowerCase();
        final rollNo = (entry['rollNo'] ?? '').toLowerCase();
        return name.contains(query) || rollNo.contains(query);
      }).toList();
    }

    // Apply Date Range Filter
    if (_selectedDateRange != null) {
      temp = temp.where((entry) {
        try {
          DateTime rowDate = DateFormat(
            'dd/MM/yyyy',
          ).parseStrict(entry['date']);
          DateTime pureRowDate = DateTime(
            rowDate.year,
            rowDate.month,
            rowDate.day,
          );
          DateTime start = DateTime(
            _selectedDateRange!.start.year,
            _selectedDateRange!.start.month,
            _selectedDateRange!.start.day,
          );
          DateTime end = DateTime(
            _selectedDateRange!.end.year,
            _selectedDateRange!.end.month,
            _selectedDateRange!.end.day,
          );

          return !pureRowDate.isBefore(start) && !pureRowDate.isAfter(end);
        } catch (_) {
          return true; // Keep visible if date parsing fails
        }
      }).toList();
    }

    setState(() {
      _filteredEntries = temp;
    });
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: _selectedDateRange,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.teal.shade700,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDateRange = picked);
      _applyFilters();
    }
  }

  void _clearDateFilter() {
    setState(() => _selectedDateRange = null);
    _applyFilters();
  }

  Future<void> _deleteEntry(Map<String, dynamic> entry) async {
    bool confirm =
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text(
              'Confirm Delete',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: const Text(
              'Are you sure you want to delete this entry? This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text(
                  'Delete',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (confirm) {
      setState(() => _isLoading = true);
      bool success = await SheetsService.deleteCottonEntry(entry['_rowIndex']);
      if (success) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Entry Deleted Successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        _fetchData();
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete entry.'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  void _showEditDialog(Map<String, dynamic> entry) {
    final noOfSutCtrl = TextEditingController(text: entry['noOfSut']);
    final sutWeightCtrl = TextEditingController(text: entry['sutWeight']);
    final rateCtrl = TextEditingController(text: entry['rate']);
    final puniRateCtrl = TextEditingController(text: entry['puniRate']);

    double gundiSankhya = double.tryParse(entry['gundiSankhya']) ?? 0.0;
    double dam = double.tryParse(entry['dam']) ?? 0.0;
    double puniDam = double.tryParse(entry['puniDam']) ?? 0.0;
    double prashikshanAay = double.tryParse(entry['prashikshanAay']) ?? 0.0;
    double finalAmount = double.tryParse(entry['finalAmount']) ?? 0.0;

    bool isUpdating = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void calculateMath() {
              double sut = double.tryParse(noOfSutCtrl.text) ?? 0.0;
              double weight = double.tryParse(sutWeightCtrl.text) ?? 0.0;
              double rt = double.tryParse(rateCtrl.text) ?? 0.0;
              double prt = double.tryParse(puniRateCtrl.text) ?? 0.0;

              setDialogState(() {
                gundiSankhya = sut * weight;
                dam = weight * rt;
                puniDam = weight * prt;
                prashikshanAay = 0.30 * gundiSankhya;
                finalAmount = dam - puniDam - prashikshanAay;
              });
            }

            return AlertDialog(
              title: Text(
                'Edit Entry: ${entry['workerName']}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Date: ${entry['date']} | Roll No: ${entry['rollNo']}',
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: noOfSutCtrl,
                            decoration: const InputDecoration(
                              labelText: 'नं० सूत',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (v) => calculateMath(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: sutWeightCtrl,
                            decoration: const InputDecoration(
                              labelText: 'सूत तौल',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (v) => calculateMath(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: rateCtrl,
                            decoration: const InputDecoration(
                              labelText: 'दर',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (v) => calculateMath(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: puniRateCtrl,
                            decoration: const InputDecoration(
                              labelText: 'पूनी दर',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (v) => calculateMath(),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 30),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('गुंडी संख्या:'),
                        Text(gundiSankhya.toStringAsFixed(2)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('दाम:'),
                        Text('₹ ${dam.toStringAsFixed(2)}'),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('पुनि दाम:'),
                        Text('₹ ${puniDam.toStringAsFixed(2)}'),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('प्रशिक्षण आय:'),
                        Text('₹ ${prashikshanAay.toStringAsFixed(2)}'),
                      ],
                    ),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'दी गयी रकम:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          '₹ ${finalAmount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.teal,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isUpdating ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isUpdating
                      ? null
                      : () async {
                          setDialogState(() => isUpdating = true);

                          Map<String, dynamic> updatedData = {
                            'date': entry['date'],
                            'workerId': entry['workerId'],
                            'workerName': entry['workerName'],
                            'rollNo': entry['rollNo'],
                            'gundiSankhya': gundiSankhya.toStringAsFixed(2),
                            'noOfSut': noOfSutCtrl.text.trim(),
                            'sutWeight': sutWeightCtrl.text.trim(),
                            'rate': rateCtrl.text.trim(),
                            'dam': dam.toStringAsFixed(2),
                            'puniWeight': sutWeightCtrl.text.trim(),
                            'puniRate': puniRateCtrl.text.trim(),
                            'puniDam': puniDam.toStringAsFixed(2),
                            'finalAmount': finalAmount.toStringAsFixed(2),
                            'prashikshanAay': prashikshanAay.toStringAsFixed(2),
                          };

                          bool success = await SheetsService.updateCottonEntry(
                            entry['_rowIndex'],
                            updatedData,
                          );

                          if (context.mounted) {
                            Navigator.pop(context);
                            if (success) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Entry Updated!'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                              _fetchData();
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Failed to update.'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                  ),
                  child: isUpdating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('Save Changes'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'सूती सूत रिपोर्ट (Reports)',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchData),
        ],
      ),
      body: Column(
        children: [
          // Filter Bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: 'Search Roll No or Name...',
                      prefixIcon: const Icon(Icons.search, color: Colors.teal),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 1,
                  child: InkWell(
                    onTap: _selectDateRange,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.calendar_month,
                            color: Colors.teal,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _selectedDateRange == null
                                ? 'Filter Date'
                                : '${DateFormat('dd/MM').format(_selectedDateRange!.start)} - ${DateFormat('dd/MM').format(_selectedDateRange!.end)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          if (_selectedDateRange != null)
                            IconButton(
                              icon: const Icon(Icons.close, size: 16),
                              onPressed: _clearDateFilter,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Data Table
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.teal),
                  )
                : _filteredEntries.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.receipt_long,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No entries found.',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    child: SizedBox(
                      width: double.infinity,
                      child: PaginatedDataTable(
                        header: Text(
                          'Total Entries: ${_filteredEntries.length}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        rowsPerPage: _filteredEntries.length > 10
                            ? 10
                            : (_filteredEntries.isEmpty
                                  ? 1
                                  : _filteredEntries.length),
                        columnSpacing: 20,
                        horizontalMargin: 16,
                        columns: const [
                          DataColumn(
                            label: Text(
                              'Date',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Roll No',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Name',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Weight',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            numeric: true,
                          ),
                          DataColumn(
                            label: Text(
                              'Final Amt',
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
                        source: _CottonDataSource(
                          _filteredEntries,
                          _showEditDialog,
                          _deleteEntry,
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// Data Source for Pagination
class _CottonDataSource extends DataTableSource {
  final List<Map<String, dynamic>> _data;
  final Function(Map<String, dynamic>) onEdit;
  final Function(Map<String, dynamic>) onDelete;

  _CottonDataSource(this._data, this.onEdit, this.onDelete);

  @override
  DataRow? getRow(int index) {
    if (index >= _data.length) return null;
    final row = _data[index];

    return DataRow(
      cells: [
        DataCell(Text(row['date'].toString())),
        DataCell(
          Text(
            row['rollNo'].toString(),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.teal,
            ),
          ),
        ),
        DataCell(Text(row['workerName'].toString())),
        DataCell(Text(row['sutWeight'].toString())),
        DataCell(
          Text(
            '₹ ${row['finalAmount']}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                onPressed: () => onEdit(row),
                tooltip: 'Edit Entry',
                splashRadius: 20,
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                onPressed: () => onDelete(row),
                tooltip: 'Delete Entry',
                splashRadius: 20,
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
