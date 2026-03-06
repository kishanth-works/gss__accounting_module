import 'package:flutter/material.dart';
import 'services/sheets_service.dart';
import 'screens/dashboard_screen.dart';

void main() async {
  // Ensure Flutter bindings are initialized before calling async code
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize our Google Sheets connection
  await SheetsService.init();

  runApp(const AccountingApp());
}

class AccountingApp extends StatelessWidget {
  const AccountingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Accounting Module',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
        useMaterial3: true,
      ),
      // We are pointing the home route to our new Dashboard
      home: const DashboardScreen(),
    );
  }
}
