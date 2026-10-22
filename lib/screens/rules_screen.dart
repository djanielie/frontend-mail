import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/mail_models.dart';
import '../providers/mail_preferences.dart';
import 'rule_edit_screen.dart';

class RulesScreen extends ConsumerWidget {
  const RulesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(mailPreferencesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Règles')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _edit(context),
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
                      onTap: () => _edit(context, rule),
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

  Future<void> _edit(BuildContext context, [MailRule? rule]) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => RuleEditScreen(rule: rule)));
  }
}
