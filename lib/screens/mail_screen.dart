import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../providers/mail_controller.dart';
import '../models/mail_models.dart';
import '../screens/compose_screen.dart';
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
  var _desktopFoldersExpanded = true;
  var _desktopMessageListWidth = 400.0;

  @override
  void dispose() {
    _keyboardFocus.dispose();
    super.dispose();
  }

  Future<void> _compose() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ComposeScreen()));
  }

  Widget? _fabs({required bool showCompose, required MailState mail}) {
    final undo = mail.undo;
    final pendingSend = mail.pendingSend != null;
    if (undo == null && !pendingSend && !showCompose) return null;
    final scheme = Theme.of(context).colorScheme;
    final compose = FloatingActionButton(
      heroTag: 'mail-compose',
      onPressed: _compose,
      tooltip: 'Nouveau message',
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      child: const Icon(Icons.edit_outlined),
    );
    final cancel = pendingSend || undo != null
        ? FloatingActionButton.extended(
            heroTag: 'mail-undo',
            onPressed: () => pendingSend
                ? ref.read(mailControllerProvider.notifier).undoSend()
                : ref.read(mailControllerProvider.notifier).undoLast(),
            backgroundColor: scheme.secondaryContainer,
            foregroundColor: scheme.onSecondaryContainer,
            icon: const Icon(Icons.undo),
            label: Text(pendingSend ? 'Annuler l’envoi' : 'Annuler'),
          )
        : null;
    if (cancel == null) return compose;
    if (!showCompose) return cancel;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        cancel,
        const SizedBox(height: 12),
        compose,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final large = width >= 1100;
    final medium = width >= 760;
    final mail = ref.watch(mailControllerProvider);

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
      drawer: !large
          ? Drawer(
              child: SafeArea(
                child: FolderPane(
                  onSelected: () {
                    Navigator.of(context).pop();
                    if (!medium) setState(() => _pane = 1);
                  },
                ),
              ),
            )
          : null,
      appBar: AppBar(
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: const SizedBox.expand(),
          ),
        ),
        leading: !medium
            ? IconButton(
                tooltip: _pane > 1 ? 'Back' : 'Folders',
                icon: Icon(_pane > 1 ? Icons.arrow_back : Icons.menu),
                onPressed: () {
                  if (_pane > 1) {
                    setState(() => _pane = 1);
                  } else {
                    _scaffold.currentState?.openDrawer();
                  }
                },
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
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => ref.read(mailControllerProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: _fabs(
        showCompose: medium || _pane <= 1,
        mail: mail,
      ),
      body: large
          ? LayoutBuilder(
              builder: (context, constraints) {
                const minListWidth = 320.0;
                const maxListWidth = 720.0;
                const minReaderWidth = 380.0;
                const dividerWidth = 1.0;
                const dragHandleWidth = 12.0;
                final folderWidth = _desktopFoldersExpanded ? 260.0 : 74.0;
                final availableForList = constraints.maxWidth - folderWidth - (dividerWidth * 2) - dragHandleWidth - minReaderWidth;
                final effectiveMax = availableForList.clamp(minListWidth, maxListWidth);
                final listWidth = _desktopMessageListWidth.clamp(minListWidth, effectiveMax);

                return Row(
                  children: [
                    _DesktopFolderNav(
                      expanded: _desktopFoldersExpanded,
                      onToggle: () => setState(() => _desktopFoldersExpanded = !_desktopFoldersExpanded),
                    ),
                    const VerticalDivider(width: 1),
                    SizedBox(
                      width: listWidth,
                      child: MessageListPane(onOpen: (message) {
                        ref.read(mailControllerProvider.notifier).openMessage(message);
                      }),
                    ),
                    _ResizeHandle(
                      onDrag: (delta) {
                        setState(() {
                          _desktopMessageListWidth = (_desktopMessageListWidth + delta).clamp(minListWidth, effectiveMax);
                        });
                      },
                    ),
                    const Expanded(child: MessageReader()),
                  ],
                );
              },
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
              : IndexedStack(
                  index: _pane <= 1 ? 0 : 1,
                  children: [
                    MessageListPane(onOpen: (message) {
                      ref.read(mailControllerProvider.notifier).openMessage(message);
                      setState(() => _pane = 2);
                    }),
                    const MessageReader(),
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

class _ResizeHandle extends StatelessWidget {
  const _ResizeHandle({required this.onDrag});

  final ValueChanged<double> onDrag;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return MouseRegion(
      cursor: SystemMouseCursors.resizeLeftRight,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: (details) => onDrag(details.delta.dx),
        child: SizedBox(
          width: 12,
          child: Center(
            child: Container(
              width: 3,
              height: 44,
              decoration: BoxDecoration(
                color: scheme.outlineVariant,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ),
      ),
    );
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
      color: scheme.surfaceContainerLow.withValues(alpha: 0.72),
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
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    children: [
                      for (final folder in mail.folders)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
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
