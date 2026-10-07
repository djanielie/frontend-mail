import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api_client.dart';
import '../core/api_exception.dart';
import '../core/config.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences must be overridden at startup.');
});

class MailAccount {
  const MailAccount({required this.email, required this.token});

  final String email;
  final String token;

  Map<String, String> toJson() => {'email': email, 'token': token};

  static MailAccount? fromJson(Object? json) {
    if (json is! Map) return null;
    final email = json['email']?.toString() ?? '';
    final token = json['token']?.toString() ?? '';
    if (email.isEmpty || token.isEmpty) return null;
    return MailAccount(email: email, token: token);
  }
}

class AuthState {
  const AuthState({
    this.accounts = const [],
    this.activeEmail,
    this.busy = false,
    this.ready = false,
    this.error,
  });

  final List<MailAccount> accounts;
  final String? activeEmail;
  final bool busy;
  final bool ready;
  final String? error;

  MailAccount? get active {
    for (final account in accounts) {
      if (account.email.toLowerCase() == activeEmail?.toLowerCase()) return account;
    }
    return accounts.isEmpty ? null : accounts.first;
  }

  String? get token => active?.token;
  String? get email => active?.email;
  bool get signedIn => token != null && token!.isNotEmpty;

  AuthState copyWith({
    List<MailAccount>? accounts,
    String? activeEmail,
    bool clearActive = false,
    bool? busy,
    bool? ready,
    String? error,
    bool clearError = false,
  }) {
    return AuthState(
      accounts: accounts ?? this.accounts,
      activeEmail: clearActive ? null : (activeEmail ?? this.activeEmail),
      busy: busy ?? this.busy,
      ready: ready ?? this.ready,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._prefs) : super(const AuthState()) {
    state = _read();
  }

  final SharedPreferences _prefs;

  AuthState _read() {
    final stored = _prefs.getString('mail_accounts');
    final accounts = <MailAccount>[];
    if (stored != null && stored.isNotEmpty) {
      final decoded = jsonDecode(stored);
      if (decoded is List) {
        accounts.addAll(decoded.map(MailAccount.fromJson).whereType<MailAccount>());
      }
    } else {
      final legacyToken = _prefs.getString('mail_token');
      final legacyEmail = _prefs.getString('mail_email');
      if (legacyToken != null && legacyToken.isNotEmpty && legacyEmail != null && legacyEmail.isNotEmpty) {
        accounts.add(MailAccount(email: legacyEmail, token: legacyToken));
      }
    }
    final active = _prefs.getString('mail_active') ?? (accounts.isEmpty ? null : accounts.first.email);
    return AuthState(accounts: accounts, activeEmail: active, ready: true);
  }

  Future<void> _write(AuthState next) async {
    await _prefs.setString(
      'mail_accounts',
      jsonEncode(next.accounts.map((account) => account.toJson()).toList()),
    );
    final active = next.email;
    if (active == null) {
      await _prefs.remove('mail_active');
    } else {
      await _prefs.setString('mail_active', active);
    }
    await _prefs.remove('mail_token');
    await _prefs.remove('mail_email');
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      final api = ApiClient(baseUrl: AppConfig.apiBase, token: () => null);
      final json = await api.postJson('/api/auth/login', {
        'email': email.trim(),
        'password': password,
      });
      final token = json['token']?.toString() ?? '';
      final storedEmail = json['email']?.toString() ?? email.trim();
      if (token.isEmpty) throw ApiException('Sign in failed.');
      final account = MailAccount(email: storedEmail, token: token);
      final others = state.accounts.where(
        (item) => item.email.toLowerCase() != storedEmail.toLowerCase(),
      );
      final next = AuthState(
        accounts: [...others, account],
        activeEmail: storedEmail,
        ready: true,
      );
      await _write(next);
      state = next;
      return true;
    } on ApiException catch (err) {
      state = state.copyWith(busy: false, error: err.message);
      return false;
    } catch (_) {
      state = state.copyWith(busy: false, error: 'Sign in failed.');
      return false;
    }
  }

  void switchAccount(String email) {
    final match = state.accounts.where((account) => account.email.toLowerCase() == email.toLowerCase());
    if (match.isEmpty) return;
    final next = state.copyWith(activeEmail: match.first.email, clearError: true);
    state = next;
    _write(next);
  }

  Future<void> signOutActive() async {
    final current = state.active;
    if (current == null) return;
    final remaining = state.accounts.where((account) => account.token != current.token).toList();
    final next = AuthState(
      accounts: remaining,
      activeEmail: remaining.isEmpty ? null : remaining.first.email,
      ready: true,
    );
    await _write(next);
    state = next;
    try {
      final api = ApiClient(baseUrl: AppConfig.apiBase, token: () => current.token);
      await api.postJson('/api/auth/logout', {});
    } catch (_) {}
  }
}

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(ref.watch(sharedPreferencesProvider));
});

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    baseUrl: AppConfig.apiBase,
    token: () => ref.read(authControllerProvider).token,
  );
});
