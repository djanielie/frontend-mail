import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/mail_preferences.dart';
import '../widgets/mail_html_view.dart';

class SignatureEditScreen extends ConsumerStatefulWidget {
  const SignatureEditScreen({super.key, this.signature});

  final MailSignature? signature;

  @override
  ConsumerState<SignatureEditScreen> createState() => _SignatureEditScreenState();
}

class _SignatureEditScreenState extends ConsumerState<SignatureEditScreen> {
  late final TextEditingController _name;
  late final TextEditingController _html;
  late bool _editHtml;

  bool get _creating => widget.signature == null;

  @override
  void initState() {
    super.initState();
    final signature = widget.signature;
    _name = TextEditingController(text: signature?.name ?? '');
    _html = TextEditingController(text: signature?.html ?? '');
    _html.addListener(() => setState(() {}));
    _editHtml = _creating || (signature?.html.trim().isEmpty ?? true);
  }

  @override
  void dispose() {
    _name.dispose();
    _html.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final html = _html.text.trim();
    if (html.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La signature ne peut pas être vide.')),
      );
      return;
    }
    await ref.read(mailPreferencesProvider.notifier).upsertSignature(
          MailSignature(
            id: widget.signature?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
            name: _name.text.trim(),
            html: html,
          ),
          activate: _creating || ref.read(mailPreferencesProvider).signatures.isEmpty,
        );
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final wide = MediaQuery.sizeOf(context).width >= 720;
    final preview = _html.text.trim();

    return Scaffold(
      appBar: AppBar(
        title: Text(_creating ? 'Nouvelle signature' : 'Modifier la signature'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(onPressed: _save, child: const Text('Enregistrer')),
          ),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: EdgeInsets.fromLTRB(wide ? 8 : 20, wide ? 36 : 20, wide ? 8 : 20, 40),
            children: [
              Text(
                _creating
                    ? 'Donne-lui un nom, puis colle le HTML si besoin. L’aperçu se met à jour en dessous.'
                    : 'L’aperçu est celui envoyé. Le HTML n’apparaît que si tu l’ouvres.',
                style: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant, height: 1.45),
              ),
              const SizedBox(height: 28),
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Nom',
                  hintText: 'Ex. Travail, Perso…',
                ),
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  Expanded(child: Text('Aperçu', style: text.titleMedium)),
                  TextButton.icon(
                    onPressed: () => setState(() => _editHtml = !_editHtml),
                    icon: Icon(_editHtml ? Icons.visibility_outlined : Icons.code),
                    label: Text(_editHtml ? 'Masquer le HTML' : 'Modifier le HTML'),
                  ),
                ],
              ),
              if (_editHtml) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _html,
                  minLines: 10,
                  maxLines: 18,
                  style: text.bodyMedium?.copyWith(fontFamily: 'monospace', height: 1.4),
                  decoration: const InputDecoration(
                    labelText: 'HTML',
                    alignLabelWithHint: true,
                    helperText: 'Images, tableaux et liens sont pris en charge.',
                  ),
                ),
              ],
              const SizedBox(height: 20),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: preview.isEmpty
                      ? Text(
                          'Rien à afficher pour l’instant.',
                          style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                        )
                      : MailHtmlView(preview),
                ),
              ),
              const SizedBox(height: 32),
              FilledButton(onPressed: _save, child: const Text('Enregistrer la signature')),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Annuler'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
