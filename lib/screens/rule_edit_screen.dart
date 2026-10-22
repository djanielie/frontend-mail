import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/mail_models.dart';
import '../providers/mail_controller.dart';
import '../providers/mail_preferences.dart';

class RuleEditScreen extends ConsumerStatefulWidget {
  const RuleEditScreen({super.key, this.rule});

  final MailRule? rule;

  @override
  ConsumerState<RuleEditScreen> createState() => _RuleEditScreenState();
}

class _RuleEditScreenState extends ConsumerState<RuleEditScreen> {
  late final TextEditingController _name;
  late final TextEditingController _from;
  late final TextEditingController _subject;
  late final TextEditingController _query;
  late String _action;
  late String _destination;
  String? _error;

  bool get _editing => widget.rule != null;

  @override
  void initState() {
    super.initState();
    final rule = widget.rule;
    _name = TextEditingController(text: rule?.name ?? '');
    _from = TextEditingController(text: rule?.from ?? '');
    _subject = TextEditingController(text: rule?.subject ?? '');
    _query = TextEditingController(text: rule?.q ?? '');
    _action = rule?.action ?? 'move';
    _destination = rule?.destination ?? '';
  }

  @override
  void dispose() {
    _name.dispose();
    _from.dispose();
    _subject.dispose();
    _query.dispose();
    super.dispose();
  }

  void _clearError() {
    if (_error == null) return;
    setState(() => _error = null);
  }

  Future<void> _save() async {
    final from = _from.text.trim();
    final subject = _subject.text.trim();
    final query = _query.text.trim();
    if (from.isEmpty && subject.isEmpty && query.isEmpty) {
      setState(() => _error = 'Indique au moins un critère : expéditeur, objet ou mot-clé.');
      return;
    }
    if (_action == 'move' && _destination.isEmpty) {
      setState(() => _error = 'Choisis un dossier de destination.');
      return;
    }

    final saved = MailRule(
      id: widget.rule?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: _name.text.trim(),
      from: from,
      subject: subject,
      q: query,
      action: _action,
      destination: _action == 'move' ? _destination : '',
    );
    final prefs = ref.read(mailPreferencesProvider);
    final next = [...prefs.rules];
    final index = next.indexWhere((item) => item.id == saved.id);
    if (index >= 0) {
      next[index] = saved;
    } else {
      next.add(saved);
    }
    await ref.read(mailPreferencesProvider.notifier).update(prefs.copyWith(rules: next));
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final wide = MediaQuery.sizeOf(context).width >= 720;
    final folders = ref.watch(mailControllerProvider).folders.where((item) => item.selectable).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Modifier la règle' : 'Nouvelle règle'),
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
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: EdgeInsets.fromLTRB(wide ? 8 : 20, wide ? 36 : 20, wide ? 8 : 20, 40),
            children: [
              Text(
                'La règle s’applique aux nouveaux mails de la boîte de réception.',
                style: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant, height: 1.45),
              ),
              if (_error != null) ...[
                const SizedBox(height: 18),
                Text(_error!, style: text.bodyMedium?.copyWith(color: scheme.error, height: 1.4)),
              ],
              const SizedBox(height: 32),
              _SectionLabel(title: 'Nom', subtitle: 'Pour te y retrouver dans la liste.'),
              const SizedBox(height: 14),
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Nom de la règle',
                  hintText: 'Ex. Newsletters, Factures…',
                ),
                onChanged: (_) => _clearError(),
              ),
              const SizedBox(height: 36),
              _SectionLabel(
                title: 'Quand le mail correspond',
                subtitle: 'Au moins un critère suffit. Les champs se combinent s’il y en a plusieurs.',
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _from,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'De',
                  hintText: 'Adresse ou domaine',
                  helperText: 'Contient — ex. boutique@ ou @newsletter.com',
                ),
                onChanged: (_) => _clearError(),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _subject,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Objet',
                  hintText: 'Facture, confirmation…',
                  helperText: 'Contient ce texte dans le sujet',
                ),
                onChanged: (_) => _clearError(),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _query,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Mot-clé',
                  hintText: 'Promo, tracking…',
                  helperText: 'Cherché dans l’objet ou l’expéditeur',
                ),
                onChanged: (_) => _clearError(),
              ),
              const SizedBox(height: 36),
              _SectionLabel(title: 'Alors', subtitle: 'Action appliquée aux messages correspondants.'),
              const SizedBox(height: 16),
              ..._actions.map((item) {
                final selected = _action == item.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Material(
                    color: selected ? scheme.primaryContainer.withValues(alpha: 0.55) : scheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => setState(() {
                        _action = item.value;
                        _error = null;
                      }),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        child: Row(
                          children: [
                            Icon(item.icon, size: 22, color: selected ? scheme.primary : scheme.onSurfaceVariant),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.label, style: text.titleSmall),
                                  const SizedBox(height: 2),
                                  Text(item.hint, style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                                ],
                              ),
                            ),
                            Icon(
                              selected ? Icons.radio_button_checked : Icons.radio_button_off,
                              color: selected ? scheme.primary : scheme.outline,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),
              if (_action == 'move') ...[
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _destination.isEmpty ? null : _destination,
                  decoration: const InputDecoration(labelText: 'Dossier de destination'),
                  items: [
                    for (final folder in folders) DropdownMenuItem(value: folder.path, child: Text(folder.name)),
                  ],
                  onChanged: (value) => setState(() {
                    _destination = value ?? '';
                    _error = null;
                  }),
                ),
              ],
              const SizedBox(height: 36),
              FilledButton(
                onPressed: _save,
                child: const Text('Enregistrer la règle'),
              ),
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        Text(subtitle, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant, height: 1.4)),
      ],
    );
  }
}

const _actions = [
  (value: 'move', label: 'Déplacer', hint: 'Ranger dans un dossier', icon: Icons.drive_file_move_outline),
  (value: 'spam', label: 'Junk', hint: 'Envoyer dans les indésirables', icon: Icons.report_gmailerrorred_outlined),
  (value: 'trash', label: 'Corbeille', hint: 'Supprimer le message', icon: Icons.delete_outline),
  (value: 'read', label: 'Marquer lu', hint: 'Sans changer de dossier', icon: Icons.mark_email_read_outlined),
  (value: 'mute', label: 'Ne pas notifier', hint: 'Garder le mail, couper l’alerte', icon: Icons.notifications_off_outlined),
];
