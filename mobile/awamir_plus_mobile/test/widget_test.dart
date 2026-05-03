import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:awamir_plus_mobile/main.dart';

void main() {
  testWidgets('login renders branch employee home', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const AwamirPlusApp(useMockData: true));
    await tester.pumpAndSettle();

    expect(find.text('تسجيل الدخول'), findsOneWidget);

    await tester.enterText(find.byType(EditableText).at(0), 'employee');
    await tester.enterText(find.byType(EditableText).at(1), '123456');
    await tester.tap(find.text('دخول'));
    await tester.pumpAndSettle();

    expect(find.text('مرحباً، أحمد الراجحي'), findsOneWidget);
    expect(find.text('طلبات اليوم'), findsOneWidget);
    expect(find.text('طلب جديد'), findsWidgets);
  });
}
