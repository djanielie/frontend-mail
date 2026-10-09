import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';

import '../core/download.dart';
import '../models/mail_models.dart';
import '../providers/auth_controller.dart';
import '../providers/mail_controller.dart';
import '../screens/compose_screen.dart';
import '../widgets/mail_html_view.dart';
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
                tooltip: 'Details / source',
                onPressed: () => _showDetails(context, ref, message),
                icon: const Icon(Icons.article_outlined),
              ),
              IconButton(
                tooltip: message.isFlagged ? 'Remove flag' : 'Flag',
                onPressed: () => ref.read(mailControllerProvider.notifier).toggleFlag(summary),
                icon: Icon(message.isFlagged ? Icons.flag : Icons.flag_outlined),
              ),
              IconButton(
                tooltip: 'Junk',
                onPressed: () => ref.read(mailControllerProvider.notifier).markSpam(summary),
                icon: const Icon(Icons.report_gmailerrorred_outlined),
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
                  MailHtmlView(
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
                if (mail.thread.length > 1) ...[
                  const SizedBox(height: 28),
                  Text('Conversation (${mail.thread.length})', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  for (final item in mail.thread)
                    ListTile(
                      dense: true,
                      selected: item.uid == message.uid,
                      leading: const Icon(Icons.forum_outlined, size: 18),
                      title: Text(item.from?.label.isNotEmpty == true ? item.from!.label : 'Unknown', maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(item.subject.isEmpty ? formatMailDate(item.date) : item.subject, maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: Text(formatMailDate(item.date), style: Theme.of(context).textTheme.labelSmall),
                      onTap: item.uid == message.uid ? null : () => ref.read(mailControllerProvider.notifier).openMessage(item),
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

  Future<void> _showDetails(BuildContext context, WidgetRef ref, MailMessage message) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final json = await ref.read(apiClientProvider).getJson(
            '/api/mail/message/${message.uid}/source?folder=${Uri.encodeQueryComponent(message.folder)}',
          );
      if (!context.mounted) return;

      final headers = (json['headers'] is List ? json['headers'] as List : const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      final headersRaw = json['headersRaw']?.toString() ?? '';
      final source = json['source']?.toString() ?? '';
      final truncated = json['truncated'] == true;
      final flags = (json['flags'] is List ? json['flags'] as List : const []).map((item) => item.toString()).join(', ');
      final size = json['size'] is num ? (json['size'] as num).toInt() : 0;

      await showDialog<void>(
        context: context,
        builder: (context) => DefaultTabController(
          length: 2,
          child: AlertDialog(
            title: const Text('Message details'),
            content: SizedBox(
              width: 760,
              height: 560,
              child: Column(
                children: [
                  const TabBar(tabs: [
                    Tab(text: 'Details'),
                    Tab(text: 'Raw source'),
                  ]),
                  const SizedBox(height: 12),
                  Expanded(
                    child: TabBarView(
                      children: [
                        ListView(
                          children: [
                            _detailLine('Subject', json['subject']?.toString() ?? message.subject),
                            _detailLine('Date', json['date']?.toString() ?? message.date),
                            _detailLine('Folder', json['folder']?.toString() ?? message.folder),
                            _detailLine('UID', '${json['uid'] ?? message.uid}'),
                            _detailLine('Size', formatBytes(size)),
                            if (flags.isNotEmpty) _detailLine('Flags', flags),
                            const Divider(height: 28),
                            for (final header in headers)
                              _detailLine(header['name']?.toString() ?? '', header['value']?.toString() ?? ''),
                          ],
                        ),
                        ListView(
                          children: [
                            if (truncated)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Text(
                                  'Source preview truncated by MAX_RAW_SOURCE_MB.',
                                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                                ),
                              ),
                            SelectableText(source.isEmpty ? headersRaw : source),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Clipboard.setData(ClipboardData(text: headersRaw)),
                child: const Text('Copy headers'),
              ),
              TextButton(
                onPressed: () => Clipboard.setData(ClipboardData(text: source.isEmpty ? headersRaw : source)),
                child: const Text('Copy source'),
              ),
              FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
            ],
          ),
        ),
      );
    } catch (err) {
      messenger.showSnackBar(SnackBar(content: Text(err.toString())));
    }
  }

  Widget _detailLine(String label, String value) {
    if (label.isEmpty || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SelectableText.rich(
        TextSpan(
          children: [
            TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.w700)),
            TextSpan(text: value),
          ],
        ),
      ),
    );
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
