import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/mail_models.dart';
import '../providers/auth_controller.dart';
import '../providers/mail_controller.dart';
import '../providers/mail_preferences.dart';
import '../screens/contacts_screen.dart';
import '../screens/diagnostics_screen.dart';
import '../screens/login_screen.dart';
import '../screens/mailbox_admin_screen.dart';
import '../screens/mail_settings_screen.dart';
import 'account_switcher.dart';
import 'glass.dart';

IconData folderIcon(String icon) {
  switch (icon) {
    case 'inbox':
      return Icons.inbox_outlined;
    case 'send':
      return Icons.send_outlined;
    case 'drafts':
      return Icons.drafts_outlined;
    case 'report':
      return Icons.report_gmailerrorred_outlined;
    case 'delete':
      return Icons.delete_outline;
    case 'archive':
      return Icons.archive_outlined;
    default:
      return Icons.folder_outlined;
  }
}

String formatMailDate(String value) {
  final date = DateTime.tryParse(value)?.toLocal();
  if (date == null) return '';
  final now = DateTime.now();
  if (date.year == now.year && date.month == now.month && date.day == now.day) {
    return DateFormat.jm().format(date);
  }
  if (date.year == now.year) return DateFormat.MMMd().format(date);
  return DateFormat.yMMMd().format(date);
}

String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

class FolderPane extends ConsumerWidget {
  const FolderPane({super.key, this.onSelected});

  final VoidCallback? onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mail = ref.watch(mailControllerProvider);
    final auth = ref.watch(authControllerProvider);
    final scheme = Theme.of(context).colorScheme;
    final admin = (auth.email ?? '').toLowerCase() == 'eliedjani@ibelucky.com';

    return Material(
      color: Colors.transparent,
      child: Column(
        children: [
          const AccountSwitcher(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 4, 8),
                  child: Row(
                    children: [
                      Expanded(child: Text('Folders', style: Theme.of(context).textTheme.titleMedium)),
                      IconButton(
                        tooltip: 'New folder',
                        onPressed: () => _createFolder(context, ref),
                        icon: const Icon(Icons.create_new_folder_outlined),
                      ),
                    ],
                  ),
                ),
                for (final folder in mail.folders)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: ListTile(
                      selected: folder.path == mail.folderPath,
                      enabled: folder.selectable,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      leading: Icon(folderIcon(folder.icon)),
                      title: Text(folder.name),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (folder.unreadCount > 0)
                            Text(
                              '${folder.unreadCount}',
                              style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w700),
                            ),
                          PopupMenuButton<String>(
                            tooltip: 'Folder actions',
                            onSelected: (value) => _folderAction(context, ref, folder, value),
                            itemBuilder: (context) => [
                              const PopupMenuItem(value: 'rename', child: Text('Rename')),
                              if (!['inbox', 'send', 'drafts', 'delete'].contains(folder.icon))
                                const PopupMenuItem(value: 'delete', child: Text('Delete')),
                            ],
                          ),
                        ],
                      ),
                      onTap: folder.selectable
                          ? () async {
                              await ref.read(mailControllerProvider.notifier).selectFolder(folder, force: true);
                              onSelected?.call();
                            }
                          : null,
                    ),
                  ),
              ],
            ),
          ),
          _AccountActionsPanel(
            admin: admin,
            onOpen: (page) => _open(context, page),
            onSignOut: () => _signOut(context, ref),
          ),
        ],
      ),
    );
  }

  void _open(BuildContext context, Widget page) {
    final navigator = Navigator.of(context);
    onSelected?.call();
    navigator.push(MaterialPageRoute(builder: (_) => page));
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final email = ref.read(authControllerProvider).email ?? 'ce compte';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Se déconnecter'),
        content: Text('Déconnecter $email ? Les autres boîtes restent connectées.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Se déconnecter')),
        ],
      ),
    );
    if (confirmed == true) {
      onSelected?.call();
      await ref.read(authControllerProvider.notifier).signOutActive();
    }
  }

  Future<void> _createFolder(BuildContext context, WidgetRef ref) async {
    final name = await _folderNameDialog(context, title: 'New folder', initial: '');
    if (name == null || name.trim().isEmpty) return;
    await ref.read(mailControllerProvider.notifier).createFolder(name.trim());
  }

  Future<void> _folderAction(BuildContext context, WidgetRef ref, MailFolder folder, String value) async {
    if (value == 'rename') {
      final name = await _folderNameDialog(context, title: 'Rename folder', initial: folder.path);
      if (name == null || name.trim().isEmpty || name.trim() == folder.path) return;
      await ref.read(mailControllerProvider.notifier).renameFolder(folder.path, name.trim());
    } else if (value == 'delete') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete folder'),
          content: Text('Delete ${folder.name}? Messages in that folder may be removed by the mail server.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
          ],
        ),
      );
      if (confirmed == true) {
        await ref.read(mailControllerProvider.notifier).deleteFolder(folder.path);
      }
    }
  }

  Future<String?> _folderNameDialog(BuildContext context, {required String title, required String initial}) {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Folder path'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Save')),
        ],
      ),
    );
  }
}

class _AccountActionsPanel extends StatefulWidget {
  const _AccountActionsPanel({
    required this.admin,
    required this.onOpen,
    required this.onSignOut,
  });

  final bool admin;
  final void Function(Widget page) onOpen;
  final VoidCallback onSignOut;

  @override
  State<_AccountActionsPanel> createState() => _AccountActionsPanelState();
}

class _AccountActionsPanelState extends State<_AccountActionsPanel> {
  var _expanded = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GlassPanel(
      margin: const EdgeInsets.fromLTRB(8, 8, 8, 12),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        alignment: Alignment.bottomCenter,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.tune),
              title: const Text('Compte'),
              trailing: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
              onTap: () => setState(() => _expanded = !_expanded),
            ),
            if (_expanded) ...[
              ListTile(
                leading: const Icon(Icons.contacts_outlined),
                title: const Text('Contacts'),
                onTap: () => widget.onOpen(const ContactsScreen()),
              ),
              ListTile(
                leading: const Icon(Icons.settings_outlined),
                title: const Text('Paramètres'),
                onTap: () => widget.onOpen(const MailSettingsScreen()),
              ),
              if (widget.admin)
                ListTile(
                  leading: const Icon(Icons.admin_panel_settings_outlined),
                  title: const Text('Mailbox admin'),
                  onTap: () => widget.onOpen(const MailboxAdminScreen()),
                ),
              ListTile(
                leading: const Icon(Icons.monitor_heart_outlined),
                title: const Text('Diagnostics'),
                onTap: () => widget.onOpen(const DiagnosticsScreen()),
              ),
              ListTile(
                leading: const Icon(Icons.person_add_outlined),
                title: const Text('Ajouter un compte'),
                onTap: () => widget.onOpen(const LoginScreen()),
              ),
              ListTile(
                leading: Icon(Icons.logout, color: scheme.error),
                title: Text('Se déconnecter', style: TextStyle(color: scheme.error, fontWeight: FontWeight.w700)),
                onTap: widget.onSignOut,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class MessageListPane extends ConsumerStatefulWidget {
  const MessageListPane({super.key, required this.onOpen});

  final ValueChanged<MailSummary> onOpen;

  @override
  ConsumerState<MessageListPane> createState() => _MessageListPaneState();
}

class _MessageListPaneState extends ConsumerState<MessageListPane> {
  final _scroll = ScrollController();
  late final TextEditingController _search;
  Timer? _searchTimer;

  @override
  void initState() {
    super.initState();
    _search = TextEditingController(text: ref.read(mailControllerProvider).query);
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 240) {
        ref.read(mailControllerProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onSearch(String value) {
    _searchTimer?.cancel();
    _searchTimer = Timer(const Duration(milliseconds: 350), () {
      ref.read(mailControllerProvider.notifier).setView(query: value.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final mail = ref.watch(mailControllerProvider);
    final preferences = ref.watch(mailPreferencesProvider);
    final scheme = Theme.of(context).colorScheme;
    final narrow = MediaQuery.sizeOf(context).width < 760;

    ref.listen(mailControllerProvider, (previous, next) {
      if (previous != null && next.query != previous.query && next.query != _search.text) {
        _search.value = TextEditingValue(
          text: next.query,
          selection: TextSelection.collapsed(offset: next.query.length),
        );
      }
    });

    final filtering = mail.query.isNotEmpty || mail.filter != 'all' || mail.searchAll;
    final displayed = _displayed(mail.messages, preferences.conversations);
    final body = mail.listLoading && mail.messages.isEmpty
        ? const Center(child: CircularProgressIndicator())
        : mail.messages.isEmpty
            ? Center(
                child: Text(filtering ? 'No messages match' : 'No messages'),
              )
            : RefreshIndicator(
      onRefresh: () => ref.read(mailControllerProvider.notifier).refresh(),
      child: ListView.separated(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: displayed.length + (mail.loadingMore ? 1 : 0),
        separatorBuilder: (_, _) => Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: 0.5)),
        itemBuilder: (context, index) {
          if (index >= displayed.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final message = displayed[index];
          final threadCount = message.threadId.isEmpty
              ? 1
              : mail.messages.where((item) => item.threadId == message.threadId).length;
          final selected = message.uid == mail.selectedUid;
          final checked = mail.selectedUids.contains(message.uid);
          final row = ListTile(
            dense: preferences.compact,
            selected: selected,
            selectedTileColor: scheme.secondaryContainer.withValues(alpha: 0.65),
            leading: mail.selecting
                ? Checkbox(
                    value: checked,
                    onChanged: (_) => ref.read(mailControllerProvider.notifier).toggleSelected(message),
                  )
                : null,
            title: Text(
              message.from?.label.isNotEmpty == true ? message.from!.label : 'Unknown sender',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: message.isRead ? FontWeight.w500 : FontWeight.w700),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.subject.isEmpty ? '(No subject)' : message.subject,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: message.isRead ? FontWeight.w500 : FontWeight.w700),
                ),
                Text(
                  message.snippet,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(formatMailDate(message.date), style: Theme.of(context).textTheme.labelMedium),
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!message.isRead)
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(color: scheme.primary, shape: BoxShape.circle),
                      ),
                    if (message.hasAttachments) Icon(Icons.attachment, size: 16, color: scheme.onSurfaceVariant),
                    if (message.isFlagged) Icon(Icons.flag, size: 16, color: scheme.tertiary),
                    if (threadCount > 1)
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Text('$threadCount', style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w800)),
                      ),
                  ],
                ),
              ],
            ),
            onTap: () {
              if (mail.selecting) {
                ref.read(mailControllerProvider.notifier).toggleSelected(message);
                return;
              }
              widget.onOpen(message);
            },
            onLongPress: () => ref.read(mailControllerProvider.notifier).toggleSelected(message),
          );

          if (!narrow) return row;
          return Dismissible(
            key: ValueKey('${message.folder}-${message.uid}'),
            background: Container(
              color: scheme.tertiaryContainer,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.only(left: 20),
              child: const Icon(Icons.flag_outlined),
            ),
            secondaryBackground: Container(
              color: scheme.errorContainer,
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              child: Icon(Icons.delete_outline, color: scheme.onErrorContainer),
            ),
            confirmDismiss: (direction) async {
              final notifier = ref.read(mailControllerProvider.notifier);
              if (direction == DismissDirection.startToEnd) {
                await notifier.queueFlag(message);
                return false;
              }
              await notifier.queueTrash(message);
              return true;
            },
            child: row,
          );
        },
      ),
    );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _search,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search sender, subject, text',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _search.text.isEmpty && mail.query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            onPressed: () {
                              _searchTimer?.cancel();
                              _search.clear();
                              ref.read(mailControllerProvider.notifier).setView(query: '');
                            },
                            icon: const Icon(Icons.close),
                          ),
                    isDense: true,
                  ),
                  onChanged: (value) {
                    setState(() {});
                    _onSearch(value);
                  },
                  onSubmitted: (value) {
                    _searchTimer?.cancel();
                    ref.read(mailControllerProvider.notifier).setView(query: value.trim());
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: 'Advanced search',
                onPressed: () => _advancedSearch(context),
                icon: const Icon(Icons.tune),
              ),
              const SizedBox(width: 8),
              IconButton.outlined(
                tooltip: 'Delete matching search',
                onPressed: mail.messages.isEmpty ? null : () => _trashMatchingSearch(context),
                icon: const Icon(Icons.delete_sweep_outlined),
              ),
              if (mail.folder?.icon == 'delete') ...[
                const SizedBox(width: 8),
                IconButton.filled(
                  tooltip: 'Empty Trash',
                  onPressed: mail.messages.isEmpty ? null : () => _emptyTrash(context),
                  icon: const Icon(Icons.delete_forever_outlined),
                ),
              ],
            ],
          ),
        ),
        if (mail.offline)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text('Hors ligne — liste en cache', style: TextStyle(color: scheme.tertiary)),
          ),
        const SizedBox(height: 8),
        if (mail.selecting)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: GlassPanel(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                  children: [
                    Text('${mail.selectedUids.length} selected', style: const TextStyle(fontWeight: FontWeight.w700)),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => ref.read(mailControllerProvider.notifier).selectAllLoaded(),
                      icon: const Icon(Icons.select_all),
                      label: const Text('All'),
                    ),
                    IconButton(tooltip: 'Mark read', onPressed: () => ref.read(mailControllerProvider.notifier).batch('read'), icon: const Icon(Icons.mark_email_read_outlined)),
                    IconButton(tooltip: 'Mark unread', onPressed: () => ref.read(mailControllerProvider.notifier).batch('unread'), icon: const Icon(Icons.mark_email_unread_outlined)),
                    IconButton(tooltip: 'Flag', onPressed: () => ref.read(mailControllerProvider.notifier).batch('flag'), icon: const Icon(Icons.flag_outlined)),
                    IconButton(tooltip: 'Junk', onPressed: () => ref.read(mailControllerProvider.notifier).batch('spam'), icon: const Icon(Icons.report_gmailerrorred_outlined)),
                    IconButton(tooltip: 'Move to', onPressed: () => _moveSelected(context), icon: const Icon(Icons.drive_file_move_outlined)),
                    IconButton(tooltip: 'Trash', onPressed: () => ref.read(mailControllerProvider.notifier).batch('trash'), icon: const Icon(Icons.delete_outline)),
                    IconButton(tooltip: 'Cancel', onPressed: () => ref.read(mailControllerProvider.notifier).clearSelection(), icon: const Icon(Icons.close)),
                  ],
                ),
            ),
          ),
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            children: [
              FilterChip(
                label: const Text('All folders'),
                selected: mail.searchAll,
                onSelected: (value) => ref.read(mailControllerProvider.notifier).setView(searchAll: value),
              ),
              const SizedBox(width: 8),
              for (final item in const [
                ('all', 'All'),
                ('unread', 'Unread'),
                ('flagged', 'Flagged'),
                ('files', 'Files'),
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(item.$2),
                    selected: mail.filter == item.$1,
                    onSelected: (_) => ref.read(mailControllerProvider.notifier).setView(filter: item.$1),
                  ),
                ),
              PopupMenuButton<String>(
                tooltip: 'Sort',
                initialValue: mail.sort,
                onSelected: (value) => ref.read(mailControllerProvider.notifier).setView(sort: value),
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'newest', child: Text('Newest')),
                  PopupMenuItem(value: 'oldest', child: Text('Oldest')),
                  PopupMenuItem(value: 'from', child: Text('Sender')),
                  PopupMenuItem(value: 'subject', child: Text('Subject')),
                  PopupMenuItem(value: 'size', child: Text('Largest')),
                ],
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.sort, size: 18, color: scheme.primary),
                      const SizedBox(width: 4),
                      Text(_sortLabel(mail.sort), style: TextStyle(color: scheme.primary)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!mail.listLoading || mail.messages.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                mail.total == 1 ? '1 message' : '${mail.total} messages',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
          ),
        Expanded(child: body),
      ],
    );
  }

  List<MailSummary> _displayed(List<MailSummary> messages, bool conversations) {
    if (!conversations) return messages;
    final seen = <String>{};
    final rows = <MailSummary>[];
    for (final message in messages) {
      final key = message.threadId.isEmpty ? 'uid:${message.uid}' : message.threadId;
      if (seen.add(key)) rows.add(message);
    }
    return rows;
  }

  String _sortLabel(String sort) {
    switch (sort) {
      case 'oldest':
        return 'Oldest';
      case 'from':
        return 'Sender';
      case 'subject':
        return 'Subject';
      case 'size':
        return 'Largest';
      default:
        return 'Newest';
    }
  }

  Future<void> _moveSelected(BuildContext context) async {
    final mail = ref.read(mailControllerProvider);
    final folders = mail.folders.where((folder) => folder.selectable && folder.path != mail.folderPath).toList();
    final destination = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final folder in folders)
              ListTile(
                leading: Icon(folderIcon(folder.icon)),
                title: Text(folder.name),
                onTap: () => Navigator.pop(context, folder.path),
              ),
          ],
        ),
      ),
    );
    if (destination == null) return;
    await ref.read(mailControllerProvider.notifier).batch('move', destination: destination);
  }

  Future<void> _trashMatchingSearch(BuildContext context) async {
    final mail = ref.read(mailControllerProvider);
    final hasCriteria = mail.query.trim().isNotEmpty ||
        mail.from.trim().isNotEmpty ||
        mail.to.trim().isNotEmpty ||
        mail.subject.trim().isNotEmpty ||
        mail.since != null ||
        mail.before != null ||
        mail.filter != 'all';
    if (!hasCriteria) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a keyword, date, sender, recipient, subject, or filter before bulk deleting.')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete matching messages?'),
        content: Text(
          'This will move every message matching the current search/filter in "${mail.folder?.name ?? mail.folderPath}" to Trash.\n\n'
          'Current match count: ${mail.total}',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton.tonalIcon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.delete_sweep_outlined),
            label: const Text('Move to Trash'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(this.context);

    try {
      final count = await ref.read(mailControllerProvider.notifier).trashMatchingCurrentView();
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('$count matching messages moved to Trash.')));
    } catch (_) {
      if (!mounted) return;
      final error = ref.read(mailControllerProvider).error ?? 'Matching messages could not be deleted.';
      messenger.showSnackBar(SnackBar(content: Text(error)));
    }
  }

  Future<void> _emptyTrash(BuildContext context) async {
    final mail = ref.read(mailControllerProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Empty Trash?'),
        content: Text(
          'This will permanently delete ${mail.total == 1 ? '1 message' : '${mail.total} messages'} from Trash. This cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.delete_forever_outlined),
            label: const Text('Empty Trash'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(this.context);

    try {
      final count = await ref.read(mailControllerProvider.notifier).emptyTrash();
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('$count messages permanently deleted.')));
    } catch (_) {
      if (!mounted) return;
      final error = ref.read(mailControllerProvider).error ?? 'Trash could not be emptied.';
      messenger.showSnackBar(SnackBar(content: Text(error)));
    }
  }

  Future<void> _advancedSearch(BuildContext context) async {
    final mail = ref.read(mailControllerProvider);
    final from = TextEditingController(text: mail.from);
    final to = TextEditingController(text: mail.to);
    final subject = TextEditingController(text: mail.subject);
    DateTime? since = mail.since;
    DateTime? before = mail.before;

    final applied = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Advanced search'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: from, decoration: const InputDecoration(labelText: 'From')),
                const SizedBox(height: 8),
                TextField(controller: to, decoration: const InputDecoration(labelText: 'To')),
                const SizedBox(height: 8),
                TextField(controller: subject, decoration: const InputDecoration(labelText: 'Subject')),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: Text('Since: ${_dateLabel(since)}')),
                    TextButton(
                      onPressed: () async {
                        final picked = await _pickDate(context, since);
                        setDialogState(() => since = picked);
                      },
                      child: const Text('Choose'),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(child: Text('Before: ${_dateLabel(before)}')),
                    TextButton(
                      onPressed: () async {
                        final picked = await _pickDate(context, before);
                        setDialogState(() => before = picked);
                      },
                      child: const Text('Choose'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                from.clear();
                to.clear();
                subject.clear();
                since = null;
                before = null;
                Navigator.pop(context, true);
              },
              child: const Text('Clear'),
            ),
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Apply')),
          ],
        ),
      ),
    );
    if (applied != true) return;
    await ref.read(mailControllerProvider.notifier).setView(
          from: from.text.trim(),
          to: to.text.trim(),
          subject: subject.text.trim(),
          since: since,
          before: before,
          clearSince: since == null,
          clearBefore: before == null,
        );
  }

  Future<DateTime?> _pickDate(BuildContext context, DateTime? initial) {
    final now = DateTime.now();
    return showDatePicker(
      context: context,
      initialDate: initial ?? now,
      firstDate: DateTime(now.year - 20),
      lastDate: DateTime(now.year + 1),
    );
  }

  String _dateLabel(DateTime? value) {
    if (value == null) return 'Any';
    return DateFormat.yMMMd().format(value);
  }

}
