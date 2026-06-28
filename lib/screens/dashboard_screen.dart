// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'accounting_dashboard.dart';
import 'cotton_dashboard.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50, // Clean, off-white background
      appBar: AppBar(
        title: const Text(
          'GSS Dashboard',
          style: TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.5),
        ),
        backgroundColor: Colors.blueGrey.shade900, // Enterprise dark header
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'WORKSPACE OVERVIEW',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey.shade600,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 20),

              // Accounting Module Card
              _buildModuleCard(
                context,
                title: 'Accounting Module',
                subtitle:
                    'Manage trial balances, ledgers, and standard transactions.',
                icon: Icons.account_balance_wallet,
                iconColor: Colors.blue.shade700,
                bgColor: Colors.blue.shade50,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AccountingDashboardScreen(),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Cotton Module Card
              _buildModuleCard(
                context,
                title: 'Cotton-Sut Kharid',
                subtitle:
                    'Manage worker entries, cotton weights, rates, and reports.',
                icon: Icons.inventory_2,
                iconColor: Colors.teal.shade700,
                bgColor: Colors.teal.shade50,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CottonDashboardScreen(),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Future Features Card
              _buildModuleCard(
                context,
                title: 'System Settings',
                subtitle: 'Configure application preferences and new features.',
                icon: Icons.settings,
                iconColor: Colors.orange.shade700,
                bgColor: Colors.orange.shade50,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Settings module coming soon.'),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // A sleek, professional horizontal card widget
  Widget _buildModuleCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            // Soft colored icon container
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 28, color: iconColor),
            ),
            const SizedBox(width: 20),

            // Text Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade600,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // Minimalist chevron
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }
}
