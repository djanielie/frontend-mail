import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/link_open.dart';
import '../core/mail_link.dart';
import 'mail_html_pointer.dart';

var _sheetOpen = false;

Future<void> handleMailLink(BuildContext context, String url) async {
  final link = parseMailLink(url);
  if (link == null) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ce lien n’est pas sûr et n’a pas été ouvert.')),
    );
    return;
  }
  if (!context.mounted || _sheetOpen) return;
  await showMailLinkSheet(context, link);
}

Future<void> showMailLinkSheet(BuildContext context, MailLink link) async {
  if (_sheetOpen) return;
  _sheetOpen = true;
  MailHtmlPointer.pause();
  try {
    final wide = MediaQuery.sizeOf(context).width >= 720;
    if (wide) {
      await showDialog<void>(
        context: context,
        useRootNavigator: true,
        barrierDismissible: true,
        builder: (context) => Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
              child: _MailLinkActions(link: link),
            ),
          ),
        ),
      );
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isDismissible: true,
      enableDrag: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
          child: _MailLinkActions(link: link),
        ),
      ),
    );
  } finally {
    _sheetOpen = false;
    MailHtmlPointer.resume();
  }
}

class _MailLinkActions extends StatelessWidget {
  const _MailLinkActions({required this.link});

  final MailLink link;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final openInTab = kIsWeb && link.isHttp;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Text('Lien du message', style: text.titleMedium),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(
            link.hostLabel,
            style: text.titleLarge?.copyWith(color: scheme.primary),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: SelectableText(
            link.displayUrl,
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant, height: 1.4),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            'Le texte du mail peut mentir : c’est cette adresse qui s’ouvrira.',
            style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant, height: 1.35),
          ),
        ),
        if (openInTab)
          ListTile(
            leading: const Icon(Icons.open_in_new),
            title: const Text('Ouvrir dans un nouvel onglet'),
            onTap: () => _open(context, newTab: true),
          ),
        if (!kIsWeb || !link.isHttp)
          ListTile(
            leading: Icon(link.isMailto ? Icons.mail_outline : Icons.open_in_browser),
            title: Text(link.isMailto ? 'Écrire à cette adresse' : 'Ouvrir dans le navigateur'),
            onTap: () => _open(context, newTab: false),
          ),
        ListTile(
          leading: const Icon(Icons.copy),
          title: const Text('Copier le lien'),
          onTap: () => _copy(context),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
            child: TextButton(
              onPressed: () => _close(context),
              child: const Text('Annuler'),
            ),
          ),
        ),
      ],
    );
  }

  void _close(BuildContext context) {
    final navigator = Navigator.of(context, rootNavigator: true);
    if (navigator.canPop()) navigator.pop();
  }

  Future<void> _open(BuildContext context, {required bool newTab}) async {
    _close(context);
    final opened = newTab ? await openUrlInNewTab(link.uri) : await openUrlInExternalBrowser(link.uri);
    if (opened || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Le lien n’a pas pu être ouvert.')),
    );
  }

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: link.displayUrl));
    if (!context.mounted) return;
    _close(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Lien copié')),
    );
  }
}
