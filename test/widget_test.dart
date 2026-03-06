import 'package:flutter_test/flutter_test.dart';
import 'package:accounting_module/main.dart';

void main() {
  testWidgets('App loads smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const AccountingApp());
    expect(find.text('Accounting Dashboard'), findsNothing);
  });
}
