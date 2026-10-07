import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme.dart';
import 'providers/auth_controller.dart';
import 'screens/login_screen.dart';
import 'screens/mail_screen.dart';

class MailApp extends ConsumerWidget {
  const MailApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    return MaterialApp(
      title: 'iBeLucky',
      debugShowCheckedModeBanner: false,
      theme: buildMailTheme(Brightness.light),
      darkTheme: buildMailTheme(Brightness.dark),
      themeMode: ThemeMode.dark,
      home: !auth.ready
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : auth.signedIn
              ? const MailScreen()
              : const LoginScreen(),
    );
  }
}
