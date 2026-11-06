import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:carelink/main.dart';
import 'package:carelink/state.dart';

void main() {
  testWidgets('Care Link shows a loading spinner at startup',
      (WidgetTester tester) async {
    await tester.pumpWidget(CareLinkApp(state: AppState()));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}