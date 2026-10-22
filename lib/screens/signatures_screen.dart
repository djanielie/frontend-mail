import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/mail_preferences.dart';
import '../widgets/mail_html_view.dart';
import 'signature_edit_screen.dart';

class SignaturesScreen extends ConsumerWidget {
  const SignaturesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(mailPreferencesProvider);
    final wide = MediaQuery.sizeOf(context).width >= 800;
    final selected = prefs.activeSignature;

    return Scaffold(
      appBar: AppBar(title: const Text('Signatures')),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Nouvelle signature',
        onPressed: () => _edit(context),
        child: const Icon(Icons.add),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: 280,
                      child: _SignatureList(
                        signatures: prefs.signatures,
                        activeId: prefs.activeSignatureId,
                        onSelect: (id) => ref.read(mailPreferencesProvider.notifier).setActiveSignature(id),
                        onEdit: (item) => _edit(context, item),
                        onDelete: (item) => _delete(context, ref, item),
                      ),
                    ),
                    VerticalDivider(width: 1, color: Theme.of(context).dividerColor),
                    Expanded(child: _SignaturePreview(signature: selected)),
                  ],
                )
              : Column(
                  children: [
                    SizedBox(
                      height: 220,
                      child: _SignatureList(
                        signatures: prefs.signatures,
                        activeId: prefs.activeSignatureId,
                        onSelect: (id) => ref.read(mailPreferencesProvider.notifier).setActiveSignature(id),
                        onEdit: (item) => _edit(context, item),
                        onDelete: (item) => _delete(context, ref, item),
                      ),
                    ),
                    Divider(height: 1, color: Theme.of(context).dividerColor),
                    Expanded(child: _SignaturePreview(signature: selected)),
                  ],
                ),
        ),
      ),
    );
  }

  Future<void> _edit(BuildContext context, [MailSignature? signature]) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => SignatureEditScreen(signature: signature)),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, MailSignature signature) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer la signature'),
        content: Text('Retirer « ${signature.label} » ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Supprimer')),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(mailPreferencesProvider.notifier).removeSignature(signature.id);
    }
  }
}

class _SignatureList extends StatelessWidget {
  const _SignatureList({
    required this.signatures,
    required this.activeId,
    required this.onSelect,
    required this.onEdit,
    required this.onDelete,
  });

  final List<MailSignature> signatures;
  final String activeId;
  final ValueChanged<String> onSelect;
  final ValueChanged<MailSignature> onEdit;
  final ValueChanged<MailSignature> onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (signatures.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Aucune signature. Ajoute-en une pour l’aperçu.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 88),
      itemCount: signatures.length,
      separatorBuilder: (_, _) => const SizedBox(height: 4),
      itemBuilder: (context, index) {
        final item = signatures[index];
        final selected = item.id == activeId;
        return ListTile(
          selected: selected,
          selectedTileColor: scheme.primaryContainer.withValues(alpha: 0.45),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Text(item.label),
          subtitle: selected ? const Text('Utilisée à l’envoi') : null,
          onTap: () => onSelect(item.id),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Modifier',
                onPressed: () => onEdit(item),
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                tooltip: 'Supprimer',
                onPressed: () => onDelete(item),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SignaturePreview extends StatelessWidget {
  const _SignaturePreview({required this.signature});

  final MailSignature? signature;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    if (signature == null) {
      return Center(
        child: Text(
          'Choisis une signature pour voir le rendu.',
          style: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 40),
      children: [
        Text(signature!.label, style: text.titleLarge),
        const SizedBox(height: 6),
        Text(
          'Aperçu tel qu’il apparaîtra sous tes messages.',
          style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 22),
        DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.55)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: MailHtmlView(signature!.html),
          ),
        ),
      ],
    );
  }
}
