import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/mail_models.dart';
import '../providers/mail_controller.dart';
import '../providers/mail_preferences.dart';

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
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: scheme.surfaceContainerLow,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
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
    );
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

class MessageListPane extends ConsumerStatefulWidget {
  const MessageListPane({super.key, required this.onOpen});

  final ValueChanged<MailSummary> onOpen;

  @override
  ConsumerState<MessageListPane> createState() => _MessageListPaneState();
}

class _MessageListPaneState extends ConsumerState<MessageListPane> {
  final _scroll = ScrollController();
  final _search = TextEditingController();
  Timer? _searchTimer;

  @override
  void initState() {
    super.initState();
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
        _search.text = next.query;
      }
    });

    final filtering = mail.query.isNotEmpty || mail.filter != 'all';
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
        itemCount: mail.messages.length + (mail.loadingMore ? 1 : 0),
        separatorBuilder: (_, _) => Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: 0.5)),
        itemBuilder: (context, index) {
          if (index >= mail.messages.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final message = mail.messages[index];
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
              if (direction == DismissDirection.startToEnd) {
                await ref.read(mailControllerProvider.notifier).toggleFlag(message);
                return false;
              }
              await ref.read(mailControllerProvider.notifier).trash(message);
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
                    suffixIcon: _search.text.isEmpty
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
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (mail.selecting)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    Text('${mail.selectedUids.length} selected', style: const TextStyle(fontWeight: FontWeight.w700)),
                    const Spacer(),
                    IconButton(tooltip: 'Mark read', onPressed: () => ref.read(mailControllerProvider.notifier).batch('read'), icon: const Icon(Icons.mark_email_read_outlined)),
                    IconButton(tooltip: 'Mark unread', onPressed: () => ref.read(mailControllerProvider.notifier).batch('unread'), icon: const Icon(Icons.mark_email_unread_outlined)),
                    IconButton(tooltip: 'Flag', onPressed: () => ref.read(mailControllerProvider.notifier).batch('flag'), icon: const Icon(Icons.flag_outlined)),
                    IconButton(tooltip: 'Move to', onPressed: () => _moveSelected(context), icon: const Icon(Icons.drive_file_move_outlined)),
                    IconButton(tooltip: 'Trash', onPressed: () => ref.read(mailControllerProvider.notifier).batch('trash'), icon: const Icon(Icons.delete_outline)),
                    IconButton(tooltip: 'Cancel', onPressed: () => ref.read(mailControllerProvider.notifier).clearSelection(), icon: const Icon(Icons.close)),
                  ],
                ),
              ),
            ),
          ),
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            children: [
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
