import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:front_mailclient/app.dart';
import 'package:front_mailclient/providers/auth_controller.dart';
import 'package:front_mailclient/widgets/mail_html_view.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('login screen shows mailbox fields', (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
      ],
      child: const MailApp(),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Sign in'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Email'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Password'), findsOneWidget);
  });

  testWidgets('signature logo renders as image instead of alt text', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: MailHtmlView(
          '<img src="https://ibelucky.com/assets/images/ibelucky_2026_logo.png" alt="iBeLucky" width="72">',
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('iBeLucky'), findsNothing);
    expect(find.byType(Image), findsWidgets);
  });
}
