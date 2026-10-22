import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:front_mailclient/app.dart';
import 'package:front_mailclient/core/api_client.dart';
import 'package:front_mailclient/core/email_screenshot.dart';
import 'package:front_mailclient/core/mail_link.dart';
import 'package:front_mailclient/models/mail_models.dart';
import 'package:front_mailclient/providers/account_unread.dart';
import 'package:front_mailclient/providers/auth_controller.dart';
import 'package:front_mailclient/providers/mail_controller.dart';
import 'package:front_mailclient/providers/mail_preferences.dart';
import 'package:front_mailclient/screens/rule_edit_screen.dart';
import 'package:front_mailclient/screens/signatures_screen.dart';
import 'package:front_mailclient/widgets/account_switcher.dart';
import 'package:front_mailclient/widgets/mail_html_view.dart';
import 'package:front_mailclient/widgets/mail_link_sheet.dart';
import 'package:front_mailclient/widgets/message_reader.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('login screen shows mailbox fields', (tester) async {
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

  testWidgets('rule editor is a full screen with a bounded desktop width', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
      ],
      child: const MaterialApp(home: RuleEditScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Nouvelle règle'), findsOneWidget);
    expect(find.text('Quand le mail correspond'), findsOneWidget);
    expect(find.text('Alors'), findsOneWidget);
    expect(find.text('Déplacer'), findsOneWidget);

    final constraints = tester.widgetList<ConstrainedBox>(find.byType(ConstrainedBox))
        .map((box) => box.constraints.maxWidth)
        .where((width) => width == 560);
    expect(constraints, isNotEmpty);

    await tester.tap(find.widgetWithText(TextButton, 'Enregistrer'));
    await tester.pump();
    expect(find.textContaining('au moins un critère'), findsOneWidget);
  });

  testWidgets('signatures screen lists names and renders html instead of source', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        mailPreferencesProvider.overrideWith((ref) {
          final controller = MailPreferencesController(preferences, 'ada@example.com');
          controller.state = const MailPreferences(
            signatures: [
              MailSignature(id: 'a', name: 'Travail', html: '<p>Equipe iBeLucky</p>'),
              MailSignature(id: 'b', name: 'Perso', html: '<p>Signature perso</p>'),
            ],
            activeSignatureId: 'a',
          );
          return controller;
        }),
      ],
      child: const MaterialApp(home: SignaturesScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Travail'), findsWidgets);
    expect(find.text('Perso'), findsOneWidget);
    expect(find.byType(MailHtmlView), findsOneWidget);
    expect(find.textContaining('<p>'), findsNothing);
    expect(find.widgetWithText(TextField, 'HTML'), findsNothing);

    await tester.tap(find.byTooltip('Modifier').first);
    await tester.pumpAndSettle();
    expect(find.text('Modifier le HTML'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'HTML'), findsNothing);
    await tester.tap(find.text('Modifier le HTML'));
    await tester.pump();
    expect(find.widgetWithText(TextField, 'HTML'), findsOneWidget);
  });

  test('mail links accept http(s) and reject javascript', () {
    expect(parseMailLink('javascript:alert(1)'), isNull);
    expect(parseMailLink('https://evil@paypal.com/login'), isNull);
    expect(parseMailLink('https://example.com/reset?x=1')?.hostLabel, 'example.com');
    expect(parseMailLink('mailto:ada@example.com')?.isMailto, isTrue);
    expect(parseMailLink('www.ibelucky.com')?.uri.scheme, 'https');
  });

  testWidgets('mail link sheet shows the real host before opening', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => handleMailLink(context, 'https://example.com/reset'),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Lien du message'), findsOneWidget);
    expect(find.text('example.com'), findsOneWidget);
    expect(find.text('https://example.com/reset'), findsOneWidget);
    expect(find.text('Ouvrir dans le navigateur'), findsOneWidget);
    expect(find.text('Copier le lien'), findsOneWidget);
    expect(find.text('Annuler'), findsOneWidget);

    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(find.text('Lien du message'), findsNothing);
  });

  test('screenshot filename stays filesystem-safe', () {
    expect(emailScreenshotFilename('Re: Reset your password'), 'Reset your password.png');
    expect(emailScreenshotFilename('a/b:c*d'), 'a_b_c_d.png');
    expect(emailScreenshotFilename(''), 'email.png');
  });

  test('stitches screenshots vertically', () async {
    final top = await _solidPng(10, 4, const Color(0xFF0000FF));
    final bottom = await _solidPng(8, 6, const Color(0xFFFF0000));
    final out = await stitchPngs([top, bottom]);
    final codec = await ui.instantiateImageCodec(out);
    final frame = await codec.getNextFrame();
    expect(frame.image.width, 10);
    expect(frame.image.height, 10);
  });

  testWidgets('conversation scrolls with the message and screenshot is in the menu', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    tester.view.physicalSize = const Size(1100, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const from = MailAddress(name: 'Ada', address: 'ada@example.com');
    const message = MailMessage(
      uid: 1,
      folder: 'INBOX',
      subject: 'Reset your password',
      date: '2026-10-21T10:00:00Z',
      text: 'Hello there, this is the body.',
      html: '',
      to: [MailAddress(name: '', address: 'you@example.com')],
      cc: [],
      bcc: [],
      replyTo: [],
      attachments: [],
      messageId: '<a@b>',
      inReplyTo: '',
      references: '',
      isRead: true,
      isFlagged: false,
      from: from,
    );
    const current = MailSummary(
      uid: 1,
      folder: 'INBOX',
      subject: 'Reset your password',
      date: '2026-10-21T10:00:00Z',
      snippet: '',
      isRead: true,
      isFlagged: false,
      hasAttachments: false,
      size: 0,
      from: from,
    );
    const previous = MailSummary(
      uid: 2,
      folder: 'INBOX',
      subject: 'Re: Reset your password',
      date: '2026-10-20T09:00:00Z',
      snippet: '',
      isRead: true,
      isFlagged: false,
      hasAttachments: false,
      size: 0,
      from: MailAddress(name: 'Bob', address: 'bob@example.com'),
    );

    await tester.pumpWidget(ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        mailControllerProvider.overrideWith((ref) {
          return _SeededMailController(
            ApiClient(baseUrl: 'http://127.0.0.1', token: () => 'token'),
            ref,
            const MailState(detail: message, thread: [current, previous]),
          );
        }),
      ],
      child: const MaterialApp(home: Scaffold(body: MessageReader())),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Reset your password'), findsWidgets);
    expect(find.text('Conversation (2)'), findsOneWidget);
    expect(find.byIcon(Icons.more_vert), findsOneWidget);

    final list = find.ancestor(of: find.text('Conversation (2)'), matching: find.byType(ListView));
    expect(list, findsOneWidget);
    expect(find.descendant(of: list, matching: find.text('Hello there, this is the body.')), findsOneWidget);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(find.text('Export screenshot'), findsOneWidget);
    expect(find.text('Copy text'), findsOneWidget);
    expect(find.text('Details / source'), findsOneWidget);
  });

  test('inbox unread uses the inbox folder only', () {
    const folders = [
      MailFolder(path: 'Sent', name: 'Sent', icon: 'send', unreadCount: 9, selectable: true),
      MailFolder(path: 'INBOX', name: 'Inbox', icon: 'inbox', unreadCount: 3, selectable: true),
    ];
    expect(inboxUnreadFromFolders(folders), 3);
    expect(inboxUnreadFromFolders(const []), 0);
    expect(unreadFromResponse({'unread': 7}), 7);
    expect(unreadFromResponse({'folders': []}), isNull);
  });

  testWidgets('unread badge hides at zero and shows a count otherwise', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: AccountUnreadBadge(count: 0, child: Text('box'))),
    ));
    expect(find.text('0'), findsNothing);
    expect(find.text('box'), findsOneWidget);

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: AccountUnreadBadge(count: 4, child: Text('box'))),
    ));
    expect(find.text('4'), findsOneWidget);
  });

  testWidgets('account switcher shows unread next to other mailboxes', (tester) async {
    SharedPreferences.setMockInitialValues({
      'mail_accounts': jsonEncode([
        {'email': 'ada@example.com', 'token': 'a'},
        {'email': 'bob@example.com', 'token': 'b'},
      ]),
      'mail_active': 'ada@example.com',
    });
    final preferences = await SharedPreferences.getInstance();

    await tester.pumpWidget(ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        accountUnreadProvider.overrideWith((ref) {
          return AccountUnreadController(
            ref,
            seed: {'ada@example.com': 0, 'bob@example.com': 4},
            start: false,
          );
        }),
      ],
      child: const MaterialApp(home: Scaffold(body: AccountSwitcher())),
    ));
    await tester.pumpAndSettle();

    expect(find.text('0'), findsNothing);
    await tester.tap(find.text('ada@example.com'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('bob@example.com'), findsOneWidget);
    expect(find.text('4'), findsWidgets);
  });
}

class _SeededMailController extends MailController {
  _SeededMailController(super.api, super.ref, MailState seed) {
    state = seed;
  }
}

Future<Uint8List> _solidPng(int width, int height, Color color) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..color = color,
  );
  final image = await recorder.endRecording().toImage(width, height);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}
