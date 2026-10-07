import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:pdfrx/pdfrx.dart';

import '../core/download.dart';
import '../models/mail_models.dart';
import '../providers/auth_controller.dart';
import '../providers/mail_controller.dart';
import '../screens/compose_screen.dart';
import '../widgets/mail_panes.dart';

class MessageReader extends ConsumerWidget {
  const MessageReader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mail = ref.watch(mailControllerProvider);
    final scheme = Theme.of(context).colorScheme;

    if (mail.detailLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final message = mail.detail;
    if (message == null) {
      return Center(
        child: Text(
          'Select a message',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
      );
    }

    final summary = MailSummary(
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
    );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Reply',
                onPressed: () => _open(context, ComposeArgs.reply(message)),
                icon: const Icon(Icons.reply_outlined),
              ),
              IconButton(
                tooltip: 'Reply all',
                onPressed: () => _open(context, ComposeArgs.replyAll(message, ref.read(authControllerProvider).email ?? '')),
                icon: const Icon(Icons.reply_all_outlined),
              ),
              IconButton(
                tooltip: 'Forward',
                onPressed: () => _open(context, ComposeArgs.forward(message)),
                icon: const Icon(Icons.forward_outlined),
              ),
              IconButton(
                tooltip: 'Copy text',
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: message.text));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Message text copied')));
                },
                icon: const Icon(Icons.copy_outlined),
              ),
              IconButton(
                tooltip: message.isFlagged ? 'Remove flag' : 'Flag',
                onPressed: () => ref.read(mailControllerProvider.notifier).toggleFlag(summary),
                icon: Icon(message.isFlagged ? Icons.flag : Icons.flag_outlined),
              ),
              IconButton(
                tooltip: 'Move to trash',
                onPressed: () => ref.read(mailControllerProvider.notifier).trash(summary),
                icon: const Icon(Icons.delete_outline),
              ),
              if (mail.folder?.icon == 'drafts')
                IconButton(
                  tooltip: 'Edit draft',
                  onPressed: () => _open(context, ComposeArgs.editDraft(message)),
                  icon: const Icon(Icons.edit_outlined),
                ),
              const Spacer(),
              IconButton(
                tooltip: 'Previous message',
                onPressed: _index(mail) > 0
                    ? () => ref.read(mailControllerProvider.notifier).openAdjacent(-1)
                    : null,
                icon: const Icon(Icons.keyboard_arrow_up),
              ),
              IconButton(
                tooltip: 'Next message',
                onPressed: _hasNext(mail)
                    ? () => ref.read(mailControllerProvider.notifier).openAdjacent(1)
                    : null,
                icon: const Icon(Icons.keyboard_arrow_down),
              ),
            ],
          ),
        ),
        Expanded(
          child: SelectionArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              children: [
                Text(
                  message.subject.isEmpty ? '(No subject)' : message.subject,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 16),
                _addressLine(context, 'From', message.from == null ? '' : message.from!.label),
                _addressLine(context, 'To', message.to.map((item) => item.label).join(', ')),
                if (message.cc.isNotEmpty)
                  _addressLine(context, 'Cc', message.cc.map((item) => item.label).join(', ')),
                _addressLine(context, 'Date', formatMailDate(message.date)),
                const SizedBox(height: 20),
                if (message.html.trim().isNotEmpty)
                  HtmlWidget(
                    message.html,
                    textStyle: Theme.of(context).textTheme.bodyLarge,
                  )
                else
                  SelectableText(message.text, style: Theme.of(context).textTheme.bodyLarge),
                if (message.attachments.isNotEmpty) ...[
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      Expanded(child: Text('Attachments', style: Theme.of(context).textTheme.titleMedium)),
                      if (message.attachments.length > 1)
                        TextButton.icon(
                          onPressed: () => _downloadAll(context, ref, message),
                          icon: const Icon(Icons.archive_outlined),
                          label: const Text('Download all'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  for (final attachment in message.attachments)
                    _AttachmentCard(message: message, attachment: attachment),
                ],
                if (message.subject.trim().isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.forum_outlined),
                      title: const Text('Conversation'),
                      subtitle: const Text('Show messages with this subject'),
                      onTap: () => ref.read(mailControllerProvider.notifier).setView(query: _threadSubject(message.subject)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _addressLine(BuildContext context, String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: '$label  ', style: TextStyle(color: scheme.onSurfaceVariant)),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  int _index(MailState mail) {
    return mail.messages.indexWhere((item) => item.uid == mail.detail?.uid);
  }

  bool _hasNext(MailState mail) {
    final index = _index(mail);
    if (index < 0) return false;
    return index < mail.messages.length - 1 || mail.hasMore;
  }

  Future<void> _open(BuildContext context, ComposeArgs args) {
    return Navigator.of(context).push(MaterialPageRoute(builder: (_) => ComposeScreen(args: args)));
  }

  Future<void> _downloadAll(BuildContext context, WidgetRef ref, MailMessage message) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final archive = Archive();
      for (final attachment in message.attachments) {
        final bytes = await ref.read(apiClientProvider).getBytes(
              '/api/mail/message/${message.uid}/attachment/${Uri.encodeComponent(attachment.id)}?folder=${Uri.encodeQueryComponent(message.folder)}',
            );
        final safe = attachment.filename.replaceAll(RegExp(r'[\\/]'), '_');
        archive.addFile(ArchiveFile(safe, bytes.length, bytes));
      }
      final zipped = ZipEncoder().encode(archive);
      final name = '${_threadSubject(message.subject).isEmpty ? 'attachments' : _threadSubject(message.subject)}.zip'
          .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final path = await saveBytes(filename: name, bytes: zipped, mime: 'application/zip');
      messenger.showSnackBar(SnackBar(content: Text(path == null ? 'Save started' : 'Saved to $path')));
    } catch (err) {
      messenger.showSnackBar(SnackBar(content: Text(err.toString())));
    }
  }

  String _threadSubject(String subject) {
    return subject.replaceFirst(RegExp(r'^\s*(re|fwd):\s*', caseSensitive: false), '').trim();
  }
}

class _AttachmentCard extends ConsumerWidget {
  const _AttachmentCard({required this.message, required this.attachment});

  final MailMessage message;
  final MailAttachment attachment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pdf = _isPdf;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(pdf ? Icons.picture_as_pdf_outlined : Icons.attach_file),
        title: Text(attachment.filename),
        subtitle: Text('${attachment.contentType} · ${formatBytes(attachment.size)}'),
        trailing: Wrap(
          spacing: 4,
          children: [
            TextButton(onPressed: () => _fetch(context, ref, open: true), child: const Text('Open')),
            TextButton(onPressed: () => _fetch(context, ref, open: false), child: const Text('Download')),
          ],
        ),
      ),
    );
  }

  bool get _isPdf {
    return attachment.contentType.toLowerCase().contains('pdf') ||
        attachment.filename.toLowerCase().endsWith('.pdf');
  }

  Future<void> _fetch(BuildContext context, WidgetRef ref, {required bool open}) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final bytes = await ref.read(apiClientProvider).getBytes(
            '/api/mail/message/${message.uid}/attachment/${Uri.encodeComponent(attachment.id)}?folder=${Uri.encodeQueryComponent(message.folder)}',
          );
      if (!context.mounted) return;
      if (open && _isPdf) {
        await showDialog<void>(
          context: context,
          builder: (context) => Dialog.fullscreen(
            child: _PdfPreview(filename: attachment.filename, bytes: Uint8List.fromList(bytes)),
          ),
        );
        return;
      }
      if (open && attachment.contentType.startsWith('image/')) {
        await showDialog<void>(
          context: context,
          builder: (context) => Dialog(
            child: InteractiveViewer(child: Image.memory(bytes)),
          ),
        );
        return;
      }
      final path = await saveBytes(filename: attachment.filename, bytes: bytes, mime: attachment.contentType);
      messenger.showSnackBar(SnackBar(content: Text(path == null ? 'Save started' : 'Saved to $path')));
    } catch (err) {
      messenger.showSnackBar(SnackBar(content: Text(err.toString())));
    }
  }
}

class _PdfPreview extends StatelessWidget {
  const _PdfPreview({required this.filename, required this.bytes});

  final String filename;
  final Uint8List bytes;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(filename, overflow: TextOverflow.ellipsis),
        leading: IconButton(
          tooltip: 'Close',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close),
        ),
      ),
      body: PdfViewer.data(
        bytes,
        sourceName: filename,
      ),
    );
  }
}
