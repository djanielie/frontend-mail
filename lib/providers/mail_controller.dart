import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import '../core/api_exception.dart';
import '../models/mail_models.dart';
import 'auth_controller.dart';
import 'mail_preferences.dart';

class MailState {
  const MailState({
    this.folders = const [],
    this.folderPath = '',
    this.messages = const [],
    this.page = 1,
    this.total = 0,
    this.listLoading = false,
    this.loadingMore = false,
    this.detail,
    this.detailLoading = false,
    this.selectedUid,
    this.query = '',
    this.filter = 'all',
    this.sort = 'newest',
    this.from = '',
    this.to = '',
    this.subject = '',
    this.since,
    this.before,
    this.selectedUids = const {},
    this.newUnreadCount = 0,
    this.error,
  });

  final List<MailFolder> folders;
  final String folderPath;
  final List<MailSummary> messages;
  final int page;
  final int total;
  final bool listLoading;
  final bool loadingMore;
  final MailMessage? detail;
  final bool detailLoading;
  final int? selectedUid;
  final String query;
  final String filter;
  final String sort;
  final String from;
  final String to;
  final String subject;
  final DateTime? since;
  final DateTime? before;
  final Set<int> selectedUids;
  final int newUnreadCount;
  final String? error;

  bool get hasMore => messages.length < total;
  bool get selecting => selectedUids.isNotEmpty;

  MailFolder? get folder {
    for (final item in folders) {
      if (item.path == folderPath) return item;
    }
    return null;
  }

  MailState copyWith({
    List<MailFolder>? folders,
    String? folderPath,
    List<MailSummary>? messages,
    int? page,
    int? total,
    bool? listLoading,
    bool? loadingMore,
    MailMessage? detail,
    bool clearDetail = false,
    bool? detailLoading,
    int? selectedUid,
    bool clearSelection = false,
    String? query,
    String? filter,
    String? sort,
    String? from,
    String? to,
    String? subject,
    DateTime? since,
    bool clearSince = false,
    DateTime? before,
    bool clearBefore = false,
    Set<int>? selectedUids,
    bool clearSelectedUids = false,
    int? newUnreadCount,
    bool clearNewUnread = false,
    String? error,
    bool clearError = false,
  }) {
    return MailState(
      folders: folders ?? this.folders,
      folderPath: folderPath ?? this.folderPath,
      messages: messages ?? this.messages,
      page: page ?? this.page,
      total: total ?? this.total,
      listLoading: listLoading ?? this.listLoading,
      loadingMore: loadingMore ?? this.loadingMore,
      detail: clearDetail ? null : (detail ?? this.detail),
      detailLoading: detailLoading ?? this.detailLoading,
      selectedUid: clearSelection ? null : (selectedUid ?? this.selectedUid),
      query: query ?? this.query,
      filter: filter ?? this.filter,
      sort: sort ?? this.sort,
      from: from ?? this.from,
      to: to ?? this.to,
      subject: subject ?? this.subject,
      since: clearSince ? null : (since ?? this.since),
      before: clearBefore ? null : (before ?? this.before),
      selectedUids: clearSelectedUids ? const {} : (selectedUids ?? this.selectedUids),
      newUnreadCount: clearNewUnread ? 0 : (newUnreadCount ?? this.newUnreadCount),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class MailController extends StateNotifier<MailState> {
  MailController(this._api, this._ref) : super(const MailState());

  final ApiClient _api;
  final Ref _ref;
  var _started = false;
  var _listToken = 0;
  Timer? _pollTimer;

  Future<void> bootstrap() async {
    if (_started) return;
    _started = true;
    await refreshFolders(selectInbox: true);
    _startPolling();
  }

  void reset() {
    _started = false;
    _pollTimer?.cancel();
    state = const MailState();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    final minutes = _ref.read(mailPreferencesProvider).pollMinutes;
    _pollTimer = Timer.periodic(Duration(minutes: minutes), (_) => pollForNewMail());
  }

  Future<void> pollForNewMail() async {
    final previousUnread = state.folders.fold<int>(0, (sum, folder) => sum + folder.unreadCount);
    await refreshFolders();
    final nextUnread = state.folders.fold<int>(0, (sum, folder) => sum + folder.unreadCount);
    if (previousUnread > 0 && nextUnread > previousUnread) {
      state = state.copyWith(newUnreadCount: nextUnread - previousUnread);
    }
  }

  void clearNewMailBadge() {
    state = state.copyWith(clearNewUnread: true);
  }

  Future<void> refreshFolders({bool selectInbox = false}) async {
    state = state.copyWith(listLoading: true, clearError: true);
    try {
      final json = await _api.getJson('/api/mail/folders');
      final rows = (json['folders'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => MailFolder.fromJson(Map<String, dynamic>.from(item)))
          .toList();
      state = state.copyWith(folders: rows, listLoading: false);
      if (selectInbox || state.folderPath.isEmpty) {
        MailFolder? inbox;
        for (final folder in rows) {
          if (folder.icon == 'inbox' && folder.selectable) inbox = folder;
        }
        inbox ??= rows.cast<MailFolder?>().firstWhere(
              (folder) => folder!.selectable,
              orElse: () => null,
            );
        if (inbox != null) await selectFolder(inbox, force: true);
      }
    } on ApiException catch (err) {
      state = state.copyWith(listLoading: false, error: err.message);
    } catch (_) {
      state = state.copyWith(listLoading: false, error: 'The mailbox could not be opened.');
    }
  }

  Future<void> selectFolder(MailFolder folder, {bool force = false}) async {
    if (!folder.selectable) return;
    if (!force && folder.path == state.folderPath && state.messages.isNotEmpty) return;
    state = state.copyWith(
      folderPath: folder.path,
      messages: const [],
      page: 1,
      total: 0,
      listLoading: true,
      clearDetail: true,
      clearSelection: true,
      clearSelectedUids: true,
      clearError: true,
    );
    await _loadPage(folder.path, 1, replace: true);
  }

  Future<void> setView({
    String? query,
    String? filter,
    String? sort,
    String? from,
    String? to,
    String? subject,
    DateTime? since,
    bool clearSince = false,
    DateTime? before,
    bool clearBefore = false,
  }) async {
    final path = state.folderPath;
    state = state.copyWith(
      query: query,
      filter: filter,
      sort: sort,
      from: from,
      to: to,
      subject: subject,
      since: since,
      clearSince: clearSince,
      before: before,
      clearBefore: clearBefore,
      messages: const [],
      page: 1,
      total: 0,
      listLoading: path.isNotEmpty,
      clearDetail: true,
      clearSelection: true,
      clearSelectedUids: true,
      clearError: true,
    );
    if (path.isEmpty) return;
    await _loadPage(path, 1, replace: true);
  }

  Future<void> openAdjacent(int delta) async {
    final index = state.messages.indexWhere((item) => item.uid == state.selectedUid);
    if (index < 0) return;
    final target = index + delta;
    if (target < 0) return;
    if (target >= state.messages.length) {
      if (!state.hasMore) return;
      await loadMore();
    }
    if (target < 0 || target >= state.messages.length) return;
    await openMessage(state.messages[target]);
  }

  Future<void> refresh() async {
    final path = state.folderPath;
    if (path.isEmpty) {
      await refreshFolders(selectInbox: true);
      return;
    }
    state = state.copyWith(listLoading: true, clearError: true);
    await _loadPage(path, 1, replace: true);
  }

  Future<void> loadMore() async {
    if (state.loadingMore || state.listLoading || !state.hasMore || state.folderPath.isEmpty) return;
    state = state.copyWith(loadingMore: true);
    await _loadPage(state.folderPath, state.page + 1, replace: false);
  }

  Future<void> openMessage(MailSummary summary) async {
    state = state.copyWith(selectedUid: summary.uid, detailLoading: true, clearDetail: true, clearError: true);
    try {
      final detail = await _message(summary.folder, summary.uid);
      state = state.copyWith(detail: detail, detailLoading: false);
      await _ref.read(mailPreferencesProvider.notifier).addContacts([
        MailContact.fromAddress(detail.from),
        ...detail.to.map(MailContact.fromAddress),
        ...detail.cc.map(MailContact.fromAddress),
        ...detail.replyTo.map(MailContact.fromAddress),
      ]);
      if (!summary.isRead) {
        await _api.postJson('/api/mail/message/${summary.uid}/read?folder=${Uri.encodeQueryComponent(summary.folder)}', {});
        state = state.copyWith(
          messages: [
            for (final item in state.messages)
              if (item.uid == summary.uid) item.copyWith(isRead: true) else item,
          ],
          folders: [
            for (final folder in state.folders)
              if (folder.path == summary.folder && folder.unreadCount > 0)
                folder.copyWith(unreadCount: folder.unreadCount - 1)
              else
                folder,
          ],
        );
      }
    } on ApiException catch (err) {
      state = state.copyWith(detailLoading: false, error: err.message);
    } catch (_) {
      state = state.copyWith(detailLoading: false, error: 'The message could not be opened.');
    }
  }

  Future<void> toggleFlag(MailSummary summary) async {
    final action = summary.isFlagged ? 'unflag' : 'flag';
    await _api.postJson(
      '/api/mail/message/${summary.uid}/$action?folder=${Uri.encodeQueryComponent(summary.folder)}',
      {},
    );
    state = state.copyWith(
      messages: [
        for (final item in state.messages)
          if (item.uid == summary.uid) item.copyWith(isFlagged: !summary.isFlagged) else item,
      ],
    );
  }

  void toggleSelected(MailSummary summary) {
    final next = {...state.selectedUids};
    if (!next.add(summary.uid)) next.remove(summary.uid);
    state = state.copyWith(selectedUids: next);
  }

  void clearSelection() {
    state = state.copyWith(clearSelectedUids: true);
  }

  void selectAllLoaded() {
    state = state.copyWith(selectedUids: state.messages.map((message) => message.uid).toSet());
  }

  Future<void> batch(String action, {String? destination}) async {
    if (state.selectedUids.isEmpty || state.folderPath.isEmpty) return;
    try {
      await _api.postJson('/api/mail/messages/batch', {
        'folder': state.folderPath,
        'uids': state.selectedUids.toList(),
        'action': action,
        ...?destination == null ? null : {'destination': destination},
      });
      state = state.copyWith(clearSelectedUids: true);
      await refresh();
    } on ApiException catch (err) {
      state = state.copyWith(error: err.message);
    } catch (_) {
      state = state.copyWith(error: 'The selected messages could not be updated.');
    }
  }

  bool get hasBulkCriteria {
    return state.query.trim().isNotEmpty ||
        state.from.trim().isNotEmpty ||
        state.to.trim().isNotEmpty ||
        state.subject.trim().isNotEmpty ||
        state.since != null ||
        state.before != null ||
        state.filter != 'all';
  }

  Future<int> trashMatchingCurrentView() async {
    if (state.folderPath.isEmpty) return 0;
    if (!hasBulkCriteria) {
      state = state.copyWith(error: 'Add a keyword, date, sender, recipient, subject, or filter before bulk deleting messages.');
      return 0;
    }
    try {
      final json = await _api.postJson('/api/mail/messages/trash-query', {
        'folder': state.folderPath,
        'q': state.query,
        'filter': state.filter,
        'from': state.from,
        'to': state.to,
        'subject': state.subject,
        'since': _dateParam(state.since),
        'before': _dateParam(state.before),
      });
      final count = json['count'] is num ? (json['count'] as num).toInt() : 0;
      state = state.copyWith(clearSelectedUids: true);
      await refresh();
      await refreshFolders();
      return count;
    } on ApiException catch (err) {
      state = state.copyWith(error: err.message);
      rethrow;
    } catch (_) {
      state = state.copyWith(error: 'Matching messages could not be deleted.');
      rethrow;
    }
  }

  Future<int> emptyTrash() async {
    if (state.folderPath.isEmpty) return 0;
    try {
      final json = await _api.postJson('/api/mail/trash/empty', {'folder': state.folderPath});
      final count = json['count'] is num ? (json['count'] as num).toInt() : 0;
      state = state.copyWith(clearSelectedUids: true);
      await refresh();
      await refreshFolders();
      return count;
    } on ApiException catch (err) {
      state = state.copyWith(error: err.message);
      rethrow;
    } catch (_) {
      state = state.copyWith(error: 'Trash could not be emptied.');
      rethrow;
    }
  }

  Future<void> createFolder(String path) async {
    await _api.postJson('/api/mail/folders', {'path': path});
    await refreshFolders();
  }

  Future<void> renameFolder(String path, String newPath) async {
    await _api.putJson('/api/mail/folders', {'path': path, 'newPath': newPath});
    await refreshFolders();
  }

  Future<void> deleteFolder(String path) async {
    await _api.deleteJson('/api/mail/folders', {'path': path});
    await refreshFolders(selectInbox: true);
  }

  Future<void> trash(MailSummary summary) async {
    await _api.deleteJson('/api/mail/message/${summary.uid}?folder=${Uri.encodeQueryComponent(summary.folder)}');
    final remaining = state.messages.where((item) => item.uid != summary.uid).toList();
    state = state.copyWith(
      messages: remaining,
      total: state.total > 0 ? state.total - 1 : 0,
      clearDetail: state.selectedUid == summary.uid,
      clearSelection: state.selectedUid == summary.uid,
    );
  }

  Future<MailMessage> _message(String folder, int uid) async {
    final json = await _api.getJson('/api/mail/message/$uid?folder=${Uri.encodeQueryComponent(folder)}');
    return MailMessage.fromJson(json);
  }

  Future<void> _loadPage(String folder, int page, {required bool replace}) async {
    final token = replace ? ++_listToken : _listToken;
    final view = state;
    try {
      final json = await _api.getJson(
        '/api/mail/messages?folder=${Uri.encodeQueryComponent(folder)}'
        '&page=$page&limit=30'
        '&q=${Uri.encodeQueryComponent(view.query)}'
        '&filter=${Uri.encodeQueryComponent(view.filter)}'
        '&sort=${Uri.encodeQueryComponent(view.sort)}'
        '&from=${Uri.encodeQueryComponent(view.from)}'
        '&to=${Uri.encodeQueryComponent(view.to)}'
        '&subject=${Uri.encodeQueryComponent(view.subject)}'
        '&since=${_dateParam(view.since)}'
        '&before=${_dateParam(view.before)}',
      );
      if (token != _listToken) return;
      final rows = (json['messages'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => MailSummary.fromJson(Map<String, dynamic>.from(item)))
          .toList();
      state = state.copyWith(
        messages: replace ? rows : [...state.messages, ...rows],
        page: page,
        total: json['total'] is num ? (json['total'] as num).toInt() : rows.length,
        listLoading: false,
        loadingMore: false,
      );
    } on ApiException catch (err) {
      if (token != _listToken) return;
      state = state.copyWith(listLoading: false, loadingMore: false, error: err.message);
    } catch (_) {
      if (token != _listToken) return;
      state = state.copyWith(listLoading: false, loadingMore: false, error: 'Messages could not be loaded.');
    }
  }
}

final mailControllerProvider = StateNotifierProvider<MailController, MailState>((ref) {
  final controller = MailController(ref.watch(apiClientProvider), ref);
  ref.listen(authControllerProvider, (previous, next) {
    final sameAccount = previous?.email == next.email && previous?.token == next.token;
    if (!next.signedIn) {
      controller.reset();
      return;
    }
    if (!sameAccount) {
      controller.reset();
      controller.bootstrap();
    }
  });
  if (ref.read(authControllerProvider).signedIn) {
    Future.microtask(controller.bootstrap);
  }
  return controller;
});

String _dateParam(DateTime? value) {
  if (value == null) return '';
  final year = value.year.toString().padLeft(4, '0');
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}
