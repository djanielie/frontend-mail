import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import '../core/config.dart';
import '../models/mail_models.dart';
import 'auth_controller.dart';
import 'mail_controller.dart';
import 'mail_preferences.dart';

int inboxUnreadFromFolders(Iterable<MailFolder> folders) {
  for (final folder in folders) {
    if (folder.icon == 'inbox') return folder.unreadCount;
  }
  return 0;
}

int? unreadFromResponse(Map<String, dynamic> json) {
  final unread = json['unread'];
  if (unread is num) return unread.toInt();
  return null;
}

class AccountUnreadController extends StateNotifier<Map<String, int>> {
  AccountUnreadController(this._ref, {Map<String, int>? seed, bool start = true}) : super(seed ?? const {}) {
    if (!start) return;
    _restore();
    _syncActive();
    _authSub = _ref.listen(authControllerProvider, (previous, next) {
      unawaited(refresh());
    });
    _mailSub = _ref.listen(mailControllerProvider, (previous, next) {
      _syncActive();
    });
    unawaited(refresh());
    _startTimer();
  }

  final Ref _ref;
  Timer? _timer;
  ProviderSubscription<AuthState>? _authSub;
  ProviderSubscription<MailState>? _mailSub;
  var _busy = false;

  void _startTimer() {
    _timer?.cancel();
    final minutes = _ref.read(mailPreferencesProvider).pollMinutes.clamp(1, 30);
    _timer = Timer.periodic(Duration(minutes: minutes), (_) => refresh());
  }

  void _restore() {
    final raw = _ref.read(sharedPreferencesProvider).getString('mail_account_unread');
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      state = {
        for (final entry in decoded.entries)
          if (entry.value is num) entry.key.toString().toLowerCase(): (entry.value as num).toInt(),
      };
    } catch (_) {}
  }

  Future<void> _persist() async {
    await _ref.read(sharedPreferencesProvider).setString('mail_account_unread', jsonEncode(state));
  }

  void _syncActive() {
    final email = _ref.read(authControllerProvider).email;
    if (email == null || email.isEmpty) return;
    final unread = inboxUnreadFromFolders(_ref.read(mailControllerProvider).folders);
    _set(email, unread);
  }

  void _set(String email, int unread) {
    final key = email.toLowerCase();
    if (state[key] == unread) return;
    state = {...state, key: unread};
    unawaited(_persist());
  }

  int countFor(String email) => state[email.toLowerCase()] ?? 0;

  Future<void> refresh() async {
    if (_busy) return;
    _busy = true;
    try {
      final accounts = _ref.read(authControllerProvider).accounts;
      final active = _ref.read(authControllerProvider).email?.toLowerCase();
      final next = <String, int>{
        for (final account in accounts)
          if (state.containsKey(account.email.toLowerCase()))
            account.email.toLowerCase(): state[account.email.toLowerCase()]!,
      };
      if (active != null) {
        next[active] = inboxUnreadFromFolders(_ref.read(mailControllerProvider).folders);
      }
      for (final account in accounts) {
        final key = account.email.toLowerCase();
        if (key == active) continue;
        final unread = await _fetch(account.token);
        if (unread != null) next[key] = unread;
      }
      if (!_mapEquals(state, next)) {
        state = next;
        await _persist();
      }
    } finally {
      _busy = false;
    }
  }

  Future<int?> _fetch(String token) async {
    final api = ApiClient(baseUrl: AppConfig.apiBase, token: () => token);
    try {
      final unread = unreadFromResponse(await api.getJson('/api/mail/unread'));
      if (unread != null) return unread;
    } catch (_) {}
    try {
      final json = await api.getJson('/api/mail/folders');
      final rows = (json['folders'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => MailFolder.fromJson(Map<String, dynamic>.from(item)));
      return inboxUnreadFromFolders(rows);
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _authSub?.close();
    _mailSub?.close();
    super.dispose();
  }
}

bool _mapEquals(Map<String, int> left, Map<String, int> right) {
  if (left.length != right.length) return false;
  for (final entry in left.entries) {
    if (right[entry.key] != entry.value) return false;
  }
  return true;
}

final accountUnreadProvider = StateNotifierProvider<AccountUnreadController, Map<String, int>>((ref) {
  return AccountUnreadController(ref);
});
