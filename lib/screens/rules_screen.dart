import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/mail_models.dart';
import '../providers/mail_controller.dart';
import '../providers/mail_preferences.dart';

class RulesScreen extends ConsumerWidget {
  const RulesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(mailPreferencesProvider);
    final folders = ref.watch(mailControllerProvider).folders.where((item) => item.selectable).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Règles')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _edit(context, ref, folders),
        child: const Icon(Icons.add),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: prefs.rules.isEmpty
              ? const Center(child: Text('Aucune règle. Les mails de la boîte de réception peuvent être triés automatiquement.'))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 88),
                  itemCount: prefs.rules.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final rule = prefs.rules[index];
                    return ListTile(
                      title: Text(rule.name.isEmpty ? _label(rule) : rule.name),
                      subtitle: Text(_label(rule)),
                      onTap: () => _edit(context, ref, folders, rule),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          final next = [...prefs.rules]..removeAt(index);
                          await ref.read(mailPreferencesProvider.notifier).update(prefs.copyWith(rules: next));
                        },
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }

  String _label(MailRule rule) {
    final match = [
      if (rule.from.isNotEmpty) 'de ${rule.from}',
      if (rule.subject.isNotEmpty) 'objet ${rule.subject}',
      if (rule.q.isNotEmpty) '« ${rule.q} »',
    ].join(', ');
    final action = switch (rule.action) {
      'spam' => 'Junk',
      'trash' => 'Corbeille',
      'read' => 'Lu',
      'mute' => 'Ne pas notifier',
      _ => rule.destination.isEmpty ? 'Déplacer' : 'Vers ${rule.destination}',
    };
    return '${match.isEmpty ? 'Tous' : match} → $action';
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, List<MailFolder> folders, [MailRule? rule]) async {
    final name = TextEditingController(text: rule?.name ?? '');
    final from = TextEditingController(text: rule?.from ?? '');
    final subject = TextEditingController(text: rule?.subject ?? '');
    final query = TextEditingController(text: rule?.q ?? '');
    var action = rule?.action ?? 'move';
    var destination = rule?.destination ?? '';
    final saved = await showDialog<MailRule>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(rule == null ? 'Nouvelle règle' : 'Modifier la règle'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(controller: name, decoration: const InputDecoration(labelText: 'Nom')),
                    TextField(controller: from, decoration: const InputDecoration(labelText: 'De (contient)')),
                    TextField(controller: subject, decoration: const InputDecoration(labelText: 'Objet (contient)')),
                    TextField(controller: query, decoration: const InputDecoration(labelText: 'Mot-clé')),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: action,
                      decoration: const InputDecoration(labelText: 'Action'),
                      items: const [
                        DropdownMenuItem(value: 'move', child: Text('Déplacer')),
                        DropdownMenuItem(value: 'spam', child: Text('Junk')),
                        DropdownMenuItem(value: 'trash', child: Text('Corbeille')),
                        DropdownMenuItem(value: 'read', child: Text('Marquer lu')),
                        DropdownMenuItem(value: 'mute', child: Text('Ne pas notifier')),
                      ],
                      onChanged: (value) => setDialogState(() => action = value ?? action),
                    ),
                    if (action == 'move')
                      DropdownButtonFormField<String>(
                        initialValue: destination.isEmpty ? null : destination,
                        decoration: const InputDecoration(labelText: 'Dossier'),
                        items: [
                          for (final folder in folders)
                            DropdownMenuItem(value: folder.path, child: Text(folder.name)),
                        ],
                        onChanged: (value) => setDialogState(() => destination = value ?? ''),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Annuler')),
                FilledButton(
                  onPressed: () => Navigator.pop(
                    dialogContext,
                    MailRule(
                      id: rule?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                      name: name.text.trim(),
                      from: from.text.trim(),
                      subject: subject.text.trim(),
                      q: query.text.trim(),
                      action: action,
                      destination: destination,
                    ),
                  ),
                  child: const Text('Enregistrer'),
                ),
              ],
            );
          },
        );
      },
    );
    name.dispose();
    from.dispose();
    subject.dispose();
    query.dispose();
    if (saved == null) return;
    if (saved.from.isEmpty && saved.subject.isEmpty && saved.q.isEmpty) return;
    final prefs = ref.read(mailPreferencesProvider);
    final next = [...prefs.rules];
    final index = next.indexWhere((item) => item.id == saved.id);
    if (index >= 0) {
      next[index] = saved;
    } else {
      next.add(saved);
    }
    await ref.read(mailPreferencesProvider.notifier).update(prefs.copyWith(rules: next));
  }
}
