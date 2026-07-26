// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'payroll_entry_screen.dart';
import 'payroll_report_screen.dart';

class PayrollDashboard extends StatelessWidget {
  const PayrollDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Payrolls Module (वेतन)', style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.indigo.shade700,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'PAYROLL WORKSPACE',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.blueGrey, letterSpacing: 1.2),
            ),
            const SizedBox(height: 16),
            _buildActionCard(
              context,
              title: 'New Entry (वेतन दर्ज करें)',
              icon: Icons.add_circle_outline,
              color: Colors.indigo,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PayrollEntryScreen())),
            ),
            const SizedBox(height: 16),
            _buildActionCard(
              context,
              title: 'View Reports (रिपोर्ट)',
              icon: Icons.receipt_long,
              color: Colors.blueGrey,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PayrollReportScreen())),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(BuildContext context, {required String title, required IconData icon, required Color color, required VoidCallback onTap}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Row(
            children: [
              CircleAvatar(backgroundColor: color.withOpacity(0.1), radius: 24, child: Icon(icon, color: color, size: 28)),
              const SizedBox(width: 20),
              Expanded(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black87))),
              const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}