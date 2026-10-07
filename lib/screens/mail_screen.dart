import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../providers/auth_controller.dart';
import '../providers/mail_controller.dart';
import '../models/mail_models.dart';
import '../screens/compose_screen.dart';
import '../screens/diagnostics_screen.dart';
import '../screens/login_screen.dart';
import '../screens/mailbox_admin_screen.dart';
import '../screens/mail_settings_screen.dart';
import '../widgets/ibelucky_mark.dart';
import '../widgets/mail_panes.dart';
import '../widgets/message_reader.dart';

class MailScreen extends ConsumerStatefulWidget {
  const MailScreen({super.key});

  @override
  ConsumerState<MailScreen> createState() => _MailScreenState();
}

class _MailScreenState extends ConsumerState<MailScreen> {
  final _scaffold = GlobalKey<ScaffoldState>();
  final _keyboardFocus = FocusNode();
  var _pane = 1;
  var _mobileNavExpanded = false;
  var _desktopFoldersExpanded = true;

  @override
  void dispose() {
    _keyboardFocus.dispose();
    super.dispose();
  }

  Future<void> _compose() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ComposeScreen()));
  }

  Future<void> _signOut() async {
    final email = ref.read(authControllerProvider).email ?? 'this account';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out'),
        content: Text('Disconnect $email? Other mailboxes stay signed in.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sign out')),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(authControllerProvider.notifier).signOutActive();
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final large = width >= 1100;
    final medium = width >= 760;
    final mail = ref.watch(mailControllerProvider);
    final auth = ref.watch(authControllerProvider);

    ref.listen(mailControllerProvider, (previous, next) {
      if (next.error != null && next.error != previous?.error) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(next.error!)));
      }
      if (next.newUnreadCount > 0 && next.newUnreadCount != previous?.newUnreadCount) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(next.newUnreadCount == 1 ? '1 new message' : '${next.newUnreadCount} new messages'),
          action: SnackBarAction(
            label: 'Refresh',
            onPressed: () {
              ref.read(mailControllerProvider.notifier).clearNewMailBadge();
              ref.read(mailControllerProvider.notifier).refresh();
            },
          ),
        ));
      }
    });

    return KeyboardListener(
      focusNode: _keyboardFocus,
      autofocus: true,
      onKeyEvent: (event) => _handleShortcut(event),
      child: Scaffold(
      key: _scaffold,
      drawer: medium && !large
          ? Drawer(
              child: SafeArea(
                child: FolderPane(onSelected: () => Navigator.of(context).pop()),
              ),
            )
          : null,
      appBar: AppBar(
        leading: !medium && _pane > 1
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _pane = 1),
              )
            : null,
        automaticallyImplyLeading: medium && !large,
        title: Row(
          children: [
            const IbeLuckyMark(size: 28),
            const SizedBox(width: 10),
            Flexible(child: Text(mail.folder?.name ?? 'iBeLucky', overflow: TextOverflow.ellipsis)),
          ],
        ),
        actions: medium
            ? [
                IconButton(
                  tooltip: 'Refresh',
                  onPressed: () => ref.read(mailControllerProvider.notifier).refresh(),
                  icon: const Icon(Icons.refresh),
                ),
                IconButton(
                  tooltip: 'New message',
                  onPressed: _compose,
                  icon: const Icon(Icons.edit_outlined),
                ),
                _AccountMenu(auth: auth, onSignOut: _signOut),
              ]
            : null,
      ),
      body: large
          ? Row(
              children: [
                _DesktopFolderNav(
                  expanded: _desktopFoldersExpanded,
                  onToggle: () => setState(() => _desktopFoldersExpanded = !_desktopFoldersExpanded),
                ),
                const VerticalDivider(width: 1),
                SizedBox(
                  width: 400,
                  child: MessageListPane(onOpen: (message) {
                    ref.read(mailControllerProvider.notifier).openMessage(message);
                  }),
                ),
                const VerticalDivider(width: 1),
                const Expanded(child: MessageReader()),
              ],
            )
          : medium
              ? Row(
                  children: [
                    Expanded(
                      flex: 5,
                      child: MessageListPane(onOpen: (message) {
                        ref.read(mailControllerProvider.notifier).openMessage(message);
                      }),
                    ),
                    const VerticalDivider(width: 1),
                    const Expanded(flex: 7, child: MessageReader()),
                  ],
                )
              : Row(
                  children: [
                    _MobileMailNav(
                      expanded: _mobileNavExpanded,
                      auth: auth,
                      onToggle: () => setState(() => _mobileNavExpanded = !_mobileNavExpanded),
                      onCompose: _compose,
                      onSignOut: _signOut,
                      onSelected: () => setState(() => _pane = 1),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(
                      child: _pane <= 1
                          ? MessageListPane(onOpen: (message) {
                              ref.read(mailControllerProvider.notifier).openMessage(message);
                              setState(() => _pane = 2);
                            })
                          : const MessageReader(),
                    ),
                  ],
                ),
      ),
    );
  }

  void _handleShortcut(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    final focused = FocusManager.instance.primaryFocus?.context?.widget;
    if (focused is EditableText) return;

    final mail = ref.read(mailControllerProvider);
    final notifier = ref.read(mailControllerProvider.notifier);
    if (event.logicalKey == LogicalKeyboardKey.keyJ || event.logicalKey == LogicalKeyboardKey.arrowDown) {
      notifier.openAdjacent(1);
    } else if (event.logicalKey == LogicalKeyboardKey.keyK || event.logicalKey == LogicalKeyboardKey.arrowUp) {
      notifier.openAdjacent(-1);
    } else if (event.logicalKey == LogicalKeyboardKey.delete || event.logicalKey == LogicalKeyboardKey.backspace) {
      if (mail.selecting) notifier.batch('trash');
      if (!mail.selecting && mail.detail != null) {
        final message = mail.detail!;
        notifier.trash(MailSummary(
          uid: message.uid,
          folder: message.folder,
          subject: message.subject,
          date: message.date,
          snippet: '',
          isRead: message.isRead,
          isFlagged: message.isFlagged,
          hasAttachments: message.attachments.isNotEmpty,
          size: 0,
          from: message.from,
        ));
      }
    } else if (event.logicalKey == LogicalKeyboardKey.keyR && mail.detail != null) {
      _composeWith(ComposeArgs.reply(mail.detail!));
    } else if (event.logicalKey == LogicalKeyboardKey.keyF && mail.detail != null) {
      _composeWith(ComposeArgs.forward(mail.detail!));
    }
  }

  Future<void> _composeWith(ComposeArgs args) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ComposeScreen(args: args)));
  }
}

class _DesktopFolderNav extends ConsumerWidget {
  const _DesktopFolderNav({required this.expanded, required this.onToggle});

  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mail = ref.watch(mailControllerProvider);
    final scheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      width: expanded ? 260 : 74,
      color: scheme.surfaceContainerLow,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: Align(
              alignment: expanded ? Alignment.centerRight : Alignment.center,
              child: IconButton(
                tooltip: expanded ? 'Shrink folders' : 'Expand folders',
                onPressed: onToggle,
                icon: Icon(expanded ? Icons.keyboard_double_arrow_left : Icons.keyboard_double_arrow_right),
              ),
            ),
          ),
          Expanded(
            child: expanded
                ? const FolderPane()
                : ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                    children: [
                      for (final folder in mail.folders)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Tooltip(
                            message: folder.name,
                            child: IconButton.filledTonal(
                              isSelected: folder.path == mail.folderPath,
                              onPressed: folder.selectable
                                  ? () => ref.read(mailControllerProvider.notifier).selectFolder(folder, force: true)
                                  : null,
                              icon: Badge(
                                isLabelVisible: folder.unreadCount > 0,
                                label: Text('${folder.unreadCount}'),
                                child: Icon(folderIcon(folder.icon)),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _AccountMenu extends ConsumerWidget {
  const _AccountMenu({required this.auth, required this.onSignOut, this.expanded = false});

  final AuthState auth;
  final Future<void> Function() onSignOut;
  final bool expanded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      tooltip: 'Accounts',
      onSelected: (value) async {
        if (value == 'add') {
          await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LoginScreen()));
          return;
        }
        if (value == 'signout') {
          await onSignOut();
          return;
        }
        if (value == 'settings') {
          await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MailSettingsScreen()));
          return;
        }
        if (value == 'diagnostics') {
          await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DiagnosticsScreen()));
          return;
        }
        if (value == 'mailbox-admin') {
          await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MailboxAdminScreen()));
          return;
        }
        if (value.startsWith('account:')) {
          ref.read(authControllerProvider.notifier).switchAccount(value.substring('account:'.length));
        }
      },
      itemBuilder: (context) => [
        for (final account in auth.accounts)
          PopupMenuItem(
            value: 'account:${account.email}',
            child: Text(
              account.email == auth.email ? '✓  ${account.email}' : account.email,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        const PopupMenuDivider(),
        if ((auth.email ?? '').toLowerCase() == 'eliedjani@ibelucky.com')
          const PopupMenuItem(value: 'mailbox-admin', child: Text('Mailbox admin')),
        const PopupMenuItem(value: 'settings', child: Text('Mail settings')),
        const PopupMenuItem(value: 'diagnostics', child: Text('Diagnostics')),
        const PopupMenuItem(value: 'add', child: Text('Add account')),
        const PopupMenuItem(value: 'signout', child: Text('Sign out this account')),
      ],
      child: expanded
          ? _RailAction(icon: Icons.person_outline, label: auth.email ?? 'Accounts')
          : const Padding(
              padding: EdgeInsets.all(12),
              child: Icon(Icons.person_outline),
            ),
    );
  }
}

class _MobileMailNav extends ConsumerWidget {
  const _MobileMailNav({
    required this.expanded,
    required this.auth,
    required this.onToggle,
    required this.onCompose,
    required this.onSignOut,
    required this.onSelected,
  });

  final bool expanded;
  final AuthState auth;
  final VoidCallback onToggle;
  final VoidCallback onCompose;
  final Future<void> Function() onSignOut;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mail = ref.watch(mailControllerProvider);
    final scheme = Theme.of(context).colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      width: expanded ? 248 : 76,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        border: Border(right: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.45))),
      ),
      child: SafeArea(
        right: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
              child: Container(
                padding: EdgeInsets.all(expanded ? 14 : 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      scheme.primary.withValues(alpha: 0.95),
                      const Color(0xFF3EE0FF).withValues(alpha: 0.55),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: scheme.primary.withValues(alpha: 0.22),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const IbeLuckyMark(size: 32),
                    if (expanded) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'iBeLucky Mail',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            IconButton(
              tooltip: expanded ? 'Collapse navigation' : 'Expand navigation',
              onPressed: onToggle,
              icon: Icon(expanded ? Icons.keyboard_double_arrow_left : Icons.keyboard_double_arrow_right),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: expanded
                  ? FilledButton.icon(
                      onPressed: onCompose,
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Compose'),
                    )
                  : IconButton.filled(
                      tooltip: 'New message',
                      onPressed: onCompose,
                      icon: const Icon(Icons.edit_outlined),
                    ),
            ),
            _RailAction(
              icon: Icons.refresh,
              label: 'Refresh',
              expanded: expanded,
              onTap: () => ref.read(mailControllerProvider.notifier).refresh(),
            ),
            _AccountMenu(auth: auth, onSignOut: onSignOut, expanded: expanded),
            const Divider(height: 20),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                children: [
                  for (final folder in mail.folders)
                    _FolderRailItem(
                      folder: folder,
                      selected: folder.path == mail.folderPath,
                      expanded: expanded,
                      onTap: folder.selectable
                          ? () async {
                              await ref.read(mailControllerProvider.notifier).selectFolder(folder, force: true);
                              onSelected();
                            }
                          : null,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FolderRailItem extends StatelessWidget {
  const _FolderRailItem({
    required this.folder,
    required this.selected,
    required this.expanded,
    required this.onTap,
  });

  final MailFolder folder;
  final bool selected;
  final bool expanded;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = selected ? scheme.primary : scheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Tooltip(
        message: expanded ? '' : folder.name,
        child: Material(
          color: selected ? scheme.primaryContainer.withValues(alpha: 0.65) : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: expanded ? 14 : 0, vertical: 12),
              child: Row(
                mainAxisAlignment: expanded ? MainAxisAlignment.start : MainAxisAlignment.center,
                children: [
                  Badge(
                    isLabelVisible: !expanded && folder.unreadCount > 0,
                    label: Text('${folder.unreadCount}'),
                    child: Icon(folderIcon(folder.icon), color: color),
                  ),
                  if (expanded) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        folder.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: color, fontWeight: selected ? FontWeight.w800 : FontWeight.w600),
                      ),
                    ),
                    if (folder.unreadCount > 0)
                      Text(
                        '${folder.unreadCount}',
                        style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w800),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RailAction extends StatelessWidget {
  const _RailAction({
    required this.icon,
    required this.label,
    this.expanded = true,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool expanded;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: expanded ? 14 : 0, vertical: 11),
            child: Row(
              mainAxisAlignment: expanded ? MainAxisAlignment.start : MainAxisAlignment.center,
              children: [
                Icon(icon, color: scheme.onSurfaceVariant),
                if (expanded) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: scheme.onSurface, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
