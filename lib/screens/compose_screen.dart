import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../core/api_exception.dart';
import '../mail_html.dart';
import '../models/mail_models.dart';
import '../providers/auth_controller.dart';
import '../providers/mail_controller.dart';
import '../providers/mail_preferences.dart';
import '../widgets/mail_html_view.dart';

class ComposeArgs {
  const ComposeArgs({
    this.draftUid,
    this.to = '',
    this.cc = '',
    this.bcc = '',
    this.subject = '',
    this.body = '',
    this.inReplyTo = '',
    this.references = '',
  });

  final int? draftUid;
  final String to;
  final String cc;
  final String bcc;
  final String subject;
  final String body;
  final String inReplyTo;
  final String references;

  factory ComposeArgs.reply(MailMessage message) {
    final quoted = message.text.split('\n').map((line) => '> $line').join('\n');
    return ComposeArgs(
      to: _replyAddress(message),
      subject: _prefix(message.subject, 'Re:'),
      body: '\n\nOn ${message.date}, ${message.from?.label ?? ''} wrote:\n$quoted',
      inReplyTo: message.messageId,
      references: [message.references, message.messageId].where((item) => item.isNotEmpty).join(' '),
    );
  }

  factory ComposeArgs.replyAll(MailMessage message, String me) {
    final others = <String>{
      ...message.to.map((item) => item.address),
      ...message.cc.map((item) => item.address),
    }.where((address) => address.isNotEmpty && address.toLowerCase() != me.toLowerCase());
    final reply = ComposeArgs.reply(message);
    return ComposeArgs(
      to: reply.to,
      cc: others.join(', '),
      subject: reply.subject,
      body: reply.body,
      inReplyTo: reply.inReplyTo,
      references: reply.references,
    );
  }

  factory ComposeArgs.forward(MailMessage message) {
    return ComposeArgs(
      subject: _prefix(message.subject, 'Fwd:'),
      body: '\n\n---------- Forwarded message ----------\nFrom: ${message.from?.label ?? ''}\nSubject: ${message.subject}\n\n${message.text}',
    );
  }

  factory ComposeArgs.editDraft(MailMessage message) {
    return ComposeArgs(
      draftUid: message.uid,
      to: message.to.map((item) => item.address).join(', '),
      cc: message.cc.map((item) => item.address).join(', '),
      bcc: message.bcc.map((item) => item.address).join(', '),
      subject: message.subject,
      body: message.text,
    );
  }

  static String _replyAddress(MailMessage message) {
    if (message.replyTo.isNotEmpty) return message.replyTo.first.address;
    return message.from?.address ?? '';
  }

  static String _prefix(String subject, String prefix) {
    if (subject.toLowerCase().startsWith(prefix.toLowerCase())) return subject;
    return '$prefix $subject'.trim();
  }
}

class ComposeScreen extends ConsumerStatefulWidget {
  const ComposeScreen({super.key, this.args = const ComposeArgs()});

  final ComposeArgs args;

  @override
  ConsumerState<ComposeScreen> createState() => _ComposeScreenState();
}

class _ComposeScreenState extends ConsumerState<ComposeScreen> {
  late final TextEditingController _to;
  late final TextEditingController _cc;
  late final TextEditingController _bcc;
  late final TextEditingController _subject;
  late final TextEditingController _body;
  late final FocusNode _toFocus;
  late final FocusNode _ccFocus;
  late final FocusNode _bccFocus;
  final List<OutgoingFile> _files = [];
  Timer? _autosaveTimer;
  int? _draftUid;
  var _showBcc = false;
  var _preview = false;
  var _busy = false;
  var _progress = 0.0;
  String? _error;

  @override
  void initState() {
    super.initState();
    final args = widget.args;
    final signature = ref.read(mailPreferencesProvider).signature.trim();
    _draftUid = args.draftUid;
    _to = TextEditingController(text: args.to);
    _cc = TextEditingController(text: args.cc);
    _bcc = TextEditingController(text: args.bcc);
    _subject = TextEditingController(text: args.subject);
    _body = TextEditingController(text: _withSignature(args.body, signature));
    _toFocus = FocusNode();
    _ccFocus = FocusNode();
    _bccFocus = FocusNode();
    _showBcc = args.bcc.isNotEmpty;
    for (final controller in [_to, _cc, _bcc]) {
      controller.addListener(_onAddressChanged);
    }
    for (final controller in [_subject, _body]) {
      controller.addListener(_scheduleAutosave);
    }
  }

  @override
  void dispose() {
    _autosaveTimer?.cancel();
    _to.dispose();
    _cc.dispose();
    _bcc.dispose();
    _subject.dispose();
    _body.dispose();
    _toFocus.dispose();
    _ccFocus.dispose();
    _bccFocus.dispose();
    super.dispose();
  }

  String _withSignature(String body, String signature) {
    if (signature.isEmpty || body.contains(signature)) return body;
    if (RegExp(r'</?[a-z][\s\S]*>', caseSensitive: false).hasMatch(signature)) return body;
    if (body.trim().isEmpty) return '\n\n$signature';
    return '$body\n\n$signature';
  }

  Map<String, String> get _fields => {
        'to': _to.text.trim(),
        'cc': _cc.text.trim(),
        'bcc': _bcc.text.trim(),
        'subject': _subject.text.trim(),
        'text': plainWithSignature(_body.text, ref.read(mailPreferencesProvider).signature),
        'html': documentWithSignature(_body.text, ref.read(mailPreferencesProvider).signature),
        'inReplyTo': widget.args.inReplyTo,
        'references': widget.args.references,
      };

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true, withData: true);
    if (result == null) return;
    setState(() {
      for (final file in result.files) {
        final bytes = file.bytes;
        if (bytes == null) continue;
        _files.add(OutgoingFile(name: file.name, bytes: bytes));
      }
    });
  }

  void _wrap(String mark) {
    final value = _body.value;
    final start = value.selection.start < 0 ? _body.text.length : value.selection.start;
    final end = value.selection.end < 0 ? _body.text.length : value.selection.end;
    final selected = _body.text.substring(start, end);
    final next = _body.text.replaceRange(start, end, '$mark$selected$mark');
    _body.value = TextEditingValue(
      text: next,
      selection: TextSelection(
        baseOffset: start + mark.length,
        extentOffset: start + mark.length + selected.length,
      ),
    );
  }

  Future<void> _submit({required bool draft, bool close = true}) async {
    if (_busy && close) return;
    setState(() {
      _busy = true;
      _progress = 0;
      _error = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final uid = _draftUid;
      Map<String, dynamic> result;
      if (draft && uid != null) {
        result = await api.sendForm('/api/mail/draft/$uid', method: 'PUT', fields: _fields, files: _files, onProgress: _onProgress);
      } else if (draft) {
        result = await api.sendForm('/api/mail/draft', fields: _fields, files: _files, onProgress: _onProgress);
      } else {
        await _recordRecipients();
        if (!mounted) return;
        await ref.read(mailControllerProvider.notifier).queueSend(_fields, List.of(_files));
        if (close && mounted) Navigator.of(context).pop();
        return;
      }
      if (draft && result['uid'] is num) _draftUid = (result['uid'] as num).toInt();
      if (!mounted) return;
      await ref.read(mailControllerProvider.notifier).refresh();
      if (!mounted) return;
      if (close) Navigator.of(context).pop();
    } on ApiException catch (err) {
      setState(() => _error = err.message);
    } catch (_) {
      setState(() => _error = draft ? 'The draft could not be saved.' : 'The message could not be sent.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _onAddressChanged() {
    _scheduleAutosave();
    setState(() {});
  }

  void _scheduleAutosave() {
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted || _busy || _files.isNotEmpty) return;
      final hasDraft = _to.text.trim().isNotEmpty || _subject.text.trim().isNotEmpty || _body.text.trim().isNotEmpty;
      if (!hasDraft) return;
      _submit(draft: true, close: false);
    });
  }

  void _onProgress(double value) {
    if (mounted) setState(() => _progress = value);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final preferences = ref.watch(mailPreferencesProvider);
    final frequent = _frequentContacts(preferences.contacts);
    return Scaffold(
      appBar: AppBar(
        title: Text(_draftUid == null ? 'New message' : 'Edit draft'),
        actions: [
          TextButton(onPressed: _busy ? null : () => _submit(draft: true), child: const Text('Save draft')),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            child: FilledButton(
              onPressed: _busy ? null : () => _submit(draft: false),
              child: const Text('Send'),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_busy) LinearProgressIndicator(value: _progress == 0 ? null : _progress),
          Expanded(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 860),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                  children: [
                    _addressField(
                      controller: _to,
                      focusNode: _toFocus,
                      label: 'To',
                      contacts: preferences.contacts,
                    ),
                    if (frequent.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final contact in frequent)
                            ActionChip(
                              avatar: const Icon(Icons.person_add_alt_1, size: 16),
                              label: Text(contact.label, overflow: TextOverflow.ellipsis),
                              onPressed: () => _appendAddress(_to, contact),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 10),
                    _addressField(
                      controller: _cc,
                      focusNode: _ccFocus,
                      label: 'Cc',
                      contacts: preferences.contacts,
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () => setState(() => _showBcc = !_showBcc),
                        child: Text(_showBcc ? 'Hide Bcc' : 'Add Bcc'),
                      ),
                    ),
                    if (_showBcc)
                      _addressField(
                        controller: _bcc,
                        focusNode: _bccFocus,
                        label: 'Bcc',
                        contacts: preferences.contacts,
                      ),
                    const SizedBox(height: 10),
                    TextField(controller: _subject, decoration: const InputDecoration(labelText: 'Subject')),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        SegmentedButton<bool>(
                          segments: const [
                            ButtonSegment(value: false, label: Text('Write')),
                            ButtonSegment(value: true, label: Text('Preview')),
                          ],
                          selected: {_preview},
                          onSelectionChanged: (value) => setState(() => _preview = value.first),
                        ),
                        const Spacer(),
                        IconButton(tooltip: 'Bold', onPressed: () => _wrap('**'), icon: const Icon(Icons.format_bold)),
                        IconButton(tooltip: 'Italic', onPressed: () => _wrap('*'), icon: const Icon(Icons.format_italic)),
                        IconButton(tooltip: 'Attach files', onPressed: _pickFiles, icon: const Icon(Icons.attach_file)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_preview)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: SelectionArea(
                            child: MailHtmlView(
                              documentWithSignature(_body.text, ref.read(mailPreferencesProvider).signature),
                              textStyle: Theme.of(context).textTheme.bodyLarge,
                            ),
                          ),
                        ),
                      )
                    else
                      TextField(
                        controller: _body,
                        minLines: 12,
                        maxLines: null,
                        keyboardType: TextInputType.multiline,
                        decoration: const InputDecoration(
                          alignLabelWithHint: true,
                          labelText: 'Message',
                          hintText: 'Write here. You can paste text copied from a message.',
                        ),
                      ),
                    if (_files.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      for (final file in _files)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.insert_drive_file_outlined),
                          title: Text(file.name),
                          subtitle: Text(_size(file.bytes.length)),
                          trailing: IconButton(
                            onPressed: () => setState(() => _files.remove(file)),
                            icon: const Icon(Icons.close),
                          ),
                        ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!, style: TextStyle(color: scheme.error)),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _addressField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required List<MailContact> contacts,
  }) {
    return RawAutocomplete<MailContact>(
      textEditingController: controller,
      focusNode: focusNode,
      displayStringForOption: (contact) => _completedValue(controller.text, contact.address),
      optionsBuilder: (value) {
        final token = _currentToken(value.text);
        if (token.isEmpty) return const Iterable<MailContact>.empty();
        final used = _usedAddresses();
        final query = token.toLowerCase();
        return contacts.where((contact) {
          if (used.contains(contact.address.toLowerCase())) return false;
          return contact.address.toLowerCase().contains(query) ||
              contact.name.toLowerCase().contains(query);
        }).take(8);
      },
      onSelected: (contact) {
        _bumpContact(contact);
        setState(() {});
      },
      fieldViewBuilder: (context, textController, fieldFocus, onFieldSubmitted) {
        return TextField(
          controller: textController,
          focusNode: fieldFocus,
          decoration: InputDecoration(labelText: label),
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          onSubmitted: (_) => onFieldSubmitted(),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240, maxWidth: 420),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final contact = options.elementAt(index);
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.person_outline, size: 20),
                    title: Text(contact.name.isEmpty ? contact.address : contact.name),
                    subtitle: contact.name.isEmpty ? null : Text(contact.address),
                    onTap: () => onSelected(contact),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  List<MailContact> _frequentContacts(List<MailContact> contacts) {
    final used = _usedAddresses();
    return contacts.where((contact) => !used.contains(contact.address.toLowerCase())).take(3).toList();
  }

  Set<String> _usedAddresses() {
    final used = <String>{};
    for (final controller in [_to, _cc, _bcc]) {
      for (final part in controller.text.split(RegExp(r'[,;]'))) {
        final token = part.trim();
        if (token.isEmpty) continue;
        final match = RegExp(r'<([^>]+)>').firstMatch(token);
        used.add((match?.group(1) ?? token).trim().toLowerCase());
      }
    }
    return used;
  }

  String _currentToken(String text) {
    final parts = text.split(RegExp(r'[,;]'));
    return parts.isEmpty ? '' : parts.last.trim();
  }

  String _completedValue(String text, String address) {
    final matches = RegExp(r'[,;]').allMatches(text);
    if (matches.isEmpty) return address;
    final prefix = text.substring(0, matches.last.end).trimRight();
    return '$prefix $address';
  }

  void _appendAddress(TextEditingController controller, MailContact contact) {
    final current = controller.text.trim();
    final next = current.isEmpty ? contact.address : '$current, ${contact.address}';
    controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
    _bumpContact(contact);
  }

  Future<void> _bumpContact(MailContact contact) {
    return ref.read(mailPreferencesProvider.notifier).addContacts([contact], bumpUses: true);
  }

  Future<void> _recordRecipients() {
    return ref.read(mailPreferencesProvider.notifier).addContacts(
      _usedAddresses().map((address) => MailContact(name: '', address: address)),
      bumpUses: true,
    );
  }

  String _size(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
