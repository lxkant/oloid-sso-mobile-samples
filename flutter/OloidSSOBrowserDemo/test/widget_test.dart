// Basic smoke test for the Oloid SSO Browser Demo.

import 'package:flutter_test/flutter_test.dart';

import 'package:oloid_sso_browser_demo/main.dart';

void main() {
  testWidgets('renders login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const OloidSsoApp());

    expect(find.text('Oloid SSO Browser Demo'), findsOneWidget);
    expect(find.text('Login with Oloid'), findsOneWidget);
  });
}
