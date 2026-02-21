import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:railway_secretariat/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Login screen renders without startup errors',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('نظام إدارة المراسلات'), findsOneWidget);
    expect(find.text('تسجيل الدخول'), findsWidgets);
  });
}
