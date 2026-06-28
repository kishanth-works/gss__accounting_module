import 'package:flutter/material.dart';
import 'cotton_entry_form_screen.dart';
import 'cotton_report_screen.dart';

class CottonDashboardScreen extends StatelessWidget {
  const CottonDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cotton-Sut-Kharid Module'),
        backgroundColor: Colors.teal.shade400,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildActionCard(
            context,
            title: 'New Entry (खरीद दर्ज करें)',
            icon: Icons.add_circle_outline,
            color: Colors.teal,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CottonEntryFormScreen()),
            ),
          ),
          const SizedBox(height: 16),
          _buildActionCard(
            context,
            title: 'View Reports (रिपोर्ट)',
            icon: Icons.receipt_long,
            color: Colors.blueGrey,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CottonReportScreen()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border(left: BorderSide(color: color, width: 8)),
          ),
          child: Row(
            children: [
              Icon(icon, size: 40, color: color),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Icon(Icons.arrow_forward_ios, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
