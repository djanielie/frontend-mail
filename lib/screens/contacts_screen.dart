import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/mail_controller.dart';
import '../providers/mail_preferences.dart';
import '../widgets/account_switcher.dart';
import 'compose_screen.dart';

enum _ContactSort { frequent, name }

class ContactsScreen extends ConsumerStatefulWidget {
  const ContactsScreen({super.key});

  @override
  ConsumerState<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends ConsumerState<ContactsScreen> {
  final _search = TextEditingController();
  var _sort = _ContactSort.frequent;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<MailContact> _visible(List<MailContact> contacts) {
    final needle = _search.text.trim().toLowerCase();
    final filtered = needle.isEmpty
        ? contacts
        : contacts.where((contact) {
            return contact.name.toLowerCase().contains(needle) ||
                contact.address.toLowerCase().contains(needle);
          }).toList();
    if (_sort == _ContactSort.name) {
      return [...filtered]..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
    }
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final contacts = ref.watch(mailPreferencesProvider).contacts;
    final rows = _visible(contacts);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Contacts'),
        actions: [
          IconButton(
            tooltip: 'Importer depuis Envoyés',
            onPressed: () async {
              try {
                final count = await ref.read(mailControllerProvider.notifier).importSentContacts();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(count == 0 ? 'Aucun contact dans Envoyés' : '$count contacts importés')),
                );
              } catch (err) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$err')));
              }
            },
            icon: const Icon(Icons.download_outlined),
          ),
          PopupMenuButton<_ContactSort>(
            initialValue: _sort,
            tooltip: 'Trier',
            onSelected: (value) => setState(() => _sort = value),
            itemBuilder: (context) => const [
              PopupMenuItem(value: _ContactSort.frequent, child: Text('Plus fréquents')),
              PopupMenuItem(value: _ContactSort.name, child: Text('Nom')),
            ],
            icon: const Icon(Icons.sort),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _edit(context),
        tooltip: 'Ajouter un contact',
        child: const Icon(Icons.person_add_alt_1),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: TextField(
                  controller: _search,
                  decoration: InputDecoration(
                    hintText: 'Rechercher un nom ou une adresse',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _search.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Effacer',
                            onPressed: () {
                              _search.clear();
                              setState(() {});
                            },
                            icon: const Icon(Icons.close),
                          ),
                    isDense: true,
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 10, 24, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    contacts.isEmpty
                        ? 'Les adresses s’ajoutent en ouvrant ou en envoyant des mails.'
                        : '${rows.length} contact${rows.length > 1 ? 's' : ''}',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
              ),
              Expanded(
                child: rows.isEmpty
                    ? Center(
                        child: Text(
                          contacts.isEmpty ? 'Aucun contact pour l’instant' : 'Aucun résultat',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 88),
                        itemCount: rows.length,
                        separatorBuilder: (_, _) => Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: 0.5)),
                        itemBuilder: (context, index) {
                          final contact = rows[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: scheme.primaryContainer.withValues(alpha: 0.7),
                              foregroundColor: scheme.primary,
                              child: Text(
                                _initials(contact),
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                              ),
                            ),
                            title: Text(
                              contact.name.isEmpty ? contact.address : contact.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: contact.name.isEmpty
                                ? null
                                : Text(contact.address, maxLines: 1, overflow: TextOverflow.ellipsis),
                            trailing: contact.uses > 0
                                ? Text(
                                    '${contact.uses}',
                                    style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w700),
                                  )
                                : null,
                            onTap: () => _open(context, contact),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context, MailContact contact) async {
    final scheme = Theme.of(context).colorScheme;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: scheme.primaryContainer.withValues(alpha: 0.7),
                    foregroundColor: scheme.primary,
                    child: Text(_initials(contact), style: const TextStyle(fontWeight: FontWeight.w800)),
                  ),
                  title: Text(contact.name.isEmpty ? contact.address : contact.name),
                  subtitle: Text(contact.name.isEmpty ? 'Contact' : contact.address),
                ),
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: const Text('Écrire'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _write(contact);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.drive_file_rename_outline),
                  title: const Text('Modifier'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _edit(context, contact);
                  },
                ),
                ListTile(
                  leading: Icon(Icons.delete_outline, color: scheme.error),
                  title: Text('Supprimer', style: TextStyle(color: scheme.error)),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _delete(context, contact);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _write(MailContact contact) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ComposeScreen(args: ComposeArgs(to: contact.address))),
    );
  }

  Future<void> _edit(BuildContext context, [MailContact? contact]) async {
    final name = TextEditingController(text: contact?.name ?? '');
    final address = TextEditingController(text: contact?.address ?? '');
    final saved = await showDialog<MailContact>(
      context: context,
      builder: (dialogContext) {
        String? error;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(contact == null ? 'Nouveau contact' : 'Modifier le contact'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: name,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Nom'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: address,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    decoration: InputDecoration(
                      labelText: 'Adresse',
                      errorText: error,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Annuler')),
                FilledButton(
                  onPressed: () {
                    final nextAddress = address.text.trim();
                    if (!_isEmail(nextAddress)) {
                      setDialogState(() => error = 'Adresse e-mail invalide');
                      return;
                    }
                    Navigator.pop(
                      dialogContext,
                      MailContact(
                        name: name.text.trim(),
                        address: nextAddress,
                        uses: contact?.uses ?? 0,
                      ),
                    );
                  },
                  child: const Text('Enregistrer'),
                ),
              ],
            );
          },
        );
      },
    );
    name.dispose();
    address.dispose();
    if (saved == null) return;
    await ref.read(mailPreferencesProvider.notifier).upsertContact(
          saved,
          previousAddress: contact?.address,
        );
  }

  Future<void> _delete(BuildContext context, MailContact contact) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer le contact'),
        content: Text('Retirer ${contact.label} de ce carnet ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Supprimer')),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(mailPreferencesProvider.notifier).removeContact(contact.address);
    }
  }

  String _initials(MailContact contact) {
    final name = contact.name.trim();
    if (name.isNotEmpty) {
      final parts = name.split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
      if (parts.length >= 2) return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
      return parts.first.substring(0, parts.first.length >= 2 ? 2 : 1).toUpperCase();
    }
    return emailInitials(contact.address);
  }

  bool _isEmail(String value) {
    return RegExp(r'^[^\s@<>]+@[^\s@<>]+\.[^\s@<>]+$').hasMatch(value);
  }
}
