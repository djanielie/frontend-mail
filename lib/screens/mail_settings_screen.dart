import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_exception.dart';
import '../providers/auth_controller.dart';
import '../providers/mail_controller.dart';
import '../providers/mail_preferences.dart';
import '../providers/theme_controller.dart';
import 'rules_screen.dart';

class MailSettingsScreen extends ConsumerStatefulWidget {
  const MailSettingsScreen({super.key});

  @override
  ConsumerState<MailSettingsScreen> createState() => _MailSettingsScreenState();
}

class _MailSettingsScreenState extends ConsumerState<MailSettingsScreen> {
  late final TextEditingController _displayName;
  late final TextEditingController _signature;
  late int _color;
  late String _density;
  late String _sentFolder;
  late String _draftsFolder;
  late int _pollMinutes;

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(mailPreferencesProvider);
    _displayName = TextEditingController(text: prefs.displayName);
    _signature = TextEditingController(text: prefs.signature);
    _color = prefs.color;
    _density = prefs.density;
    _sentFolder = prefs.sentFolder;
    _draftsFolder = prefs.draftsFolder;
    _pollMinutes = prefs.pollMinutes;
  }

  @override
  void dispose() {
    _displayName.dispose();
    _signature.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final folders = ref.watch(mailControllerProvider).folders.where((item) => item.selectable).toList();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mail settings'),
        actions: [
          TextButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              TextField(controller: _displayName, decoration: const InputDecoration(labelText: 'Display name')),
              const SizedBox(height: 12),
              TextField(
                controller: _signature,
                minLines: 6,
                maxLines: null,
                decoration: const InputDecoration(
                  labelText: 'Signature',
                  helperText: 'HTML is supported for rich signatures, images and columns.',
                ),
              ),
              const SizedBox(height: 20),
              Text('Appearance', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              SegmentedButton<ThemeMode>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.brightness_auto), label: Text('System')),
                  ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_outlined), label: Text('Light')),
                  ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_outlined), label: Text('Dark')),
                ],
                selected: {ref.watch(themeModeProvider)},
                onSelectionChanged: (value) => ref.read(themeModeProvider.notifier).setMode(value.first),
              ),
              const SizedBox(height: 20),
              SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'comfortable', label: Text('Comfortable')),
              ButtonSegment(value: 'compact', label: Text('Compact')),
            ],
            selected: {_density},
            onSelectionChanged: (value) => setState(() => _density = value.first),
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<int>(
            initialValue: _color,
            decoration: const InputDecoration(labelText: 'Account color'),
            items: const [
              DropdownMenuItem(value: 0xFF7B93FF, child: Text('Blue')),
              DropdownMenuItem(value: 0xFF3EE0FF, child: Text('Cyan')),
              DropdownMenuItem(value: 0xFFFFC14A, child: Text('Amber')),
              DropdownMenuItem(value: 0xFF8B5CF6, child: Text('Purple')),
            ],
            onChanged: (value) => setState(() => _color = value ?? _color),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
            initialValue: _sentFolder.isEmpty ? null : _sentFolder,
            decoration: const InputDecoration(labelText: 'Preferred Sent folder'),
            items: [
              for (final folder in folders) DropdownMenuItem(value: folder.path, child: Text(folder.name)),
            ],
            onChanged: (value) => setState(() => _sentFolder = value ?? ''),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
            initialValue: _draftsFolder.isEmpty ? null : _draftsFolder,
            decoration: const InputDecoration(labelText: 'Preferred Drafts folder'),
            items: [
              for (final folder in folders) DropdownMenuItem(value: folder.path, child: Text(folder.name)),
            ],
            onChanged: (value) => setState(() => _draftsFolder = value ?? ''),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Conversations'),
                subtitle: const Text('Grouper les réponses dans la liste'),
                value: ref.watch(mailPreferencesProvider).conversations,
                onChanged: (value) => ref.read(mailPreferencesProvider.notifier).update(
                      ref.read(mailPreferencesProvider).copyWith(conversations: value),
                    ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Notifications'),
                subtitle: const Text('Hors de l’app, selon les catégories'),
                value: ref.watch(mailPreferencesProvider).notificationsEnabled,
                onChanged: (value) => ref.read(mailPreferencesProvider.notifier).update(
                      ref.read(mailPreferencesProvider).copyWith(notificationsEnabled: value),
                    ),
              ),
              if (ref.watch(mailPreferencesProvider).notificationsEnabled) ...[
                SwitchListTile(
                  contentPadding: const EdgeInsets.only(left: 12),
                  title: const Text('Personnes'),
                  value: ref.watch(mailPreferencesProvider).notifyPeople,
                  onChanged: (value) => ref.read(mailPreferencesProvider.notifier).update(
                        ref.read(mailPreferencesProvider).copyWith(notifyPeople: value),
                      ),
                ),
                SwitchListTile(
                  contentPadding: const EdgeInsets.only(left: 12),
                  title: const Text('Newsletters'),
                  value: ref.watch(mailPreferencesProvider).notifyNewsletters,
                  onChanged: (value) => ref.read(mailPreferencesProvider.notifier).update(
                        ref.read(mailPreferencesProvider).copyWith(notifyNewsletters: value),
                      ),
                ),
                SwitchListTile(
                  contentPadding: const EdgeInsets.only(left: 12),
                  title: const Text('Automatiques / no-reply'),
                  value: ref.watch(mailPreferencesProvider).notifyAutomated,
                  onChanged: (value) => ref.read(mailPreferencesProvider.notifier).update(
                        ref.read(mailPreferencesProvider).copyWith(notifyAutomated: value),
                      ),
                ),
              ],
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.rule_folder_outlined),
                title: const Text('Règles'),
                subtitle: const Text('Trier la boîte de réception automatiquement'),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RulesScreen())),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.password),
                title: const Text('Changer le mot de passe'),
                subtitle: Text(ref.watch(authControllerProvider).email ?? ''),
                onTap: () => _changePassword(context),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
            initialValue: _pollMinutes,
            decoration: const InputDecoration(labelText: 'Refresh interval'),
            items: const [
              DropdownMenuItem(value: 1, child: Text('Every minute')),
              DropdownMenuItem(value: 2, child: Text('Every 2 minutes')),
              DropdownMenuItem(value: 5, child: Text('Every 5 minutes')),
              DropdownMenuItem(value: 10, child: Text('Every 10 minutes')),
            ],
            onChanged: (value) => setState(() => _pollMinutes = value ?? _pollMinutes),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final current = ref.read(mailPreferencesProvider);
    await ref.read(mailPreferencesProvider.notifier).update(current.copyWith(
          displayName: _displayName.text.trim(),
          signature: _signature.text.trim(),
          color: _color,
          density: _density,
          sentFolder: _sentFolder,
          draftsFolder: _draftsFolder,
          pollMinutes: _pollMinutes,
        ));
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _changePassword(BuildContext context) async {
    final current = TextEditingController();
    final next = TextEditingController();
    final confirm = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        String? error;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Changer le mot de passe'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: current, obscureText: true, decoration: const InputDecoration(labelText: 'Mot de passe actuel')),
                  TextField(controller: next, obscureText: true, decoration: const InputDecoration(labelText: 'Nouveau mot de passe')),
                  TextField(
                    controller: confirm,
                    obscureText: true,
                    decoration: InputDecoration(labelText: 'Confirmer', errorText: error),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Annuler')),
                FilledButton(
                  onPressed: () {
                    if (next.text.length < 8) {
                      setDialogState(() => error = 'Au moins 8 caractères');
                      return;
                    }
                    if (next.text != confirm.text) {
                      setDialogState(() => error = 'Les mots de passe ne correspondent pas');
                      return;
                    }
                    Navigator.pop(dialogContext, true);
                  },
                  child: const Text('Enregistrer'),
                ),
              ],
            );
          },
        );
      },
    );
    final currentPassword = current.text;
    final newPassword = next.text;
    current.dispose();
    next.dispose();
    confirm.dispose();
    if (ok != true) return;
    try {
      await ref.read(apiClientProvider).postJson('/api/auth/password', {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      });
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mot de passe mis à jour')));
    } on ApiException catch (err) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err.message)));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Le mot de passe n’a pas pu être changé.')));
    }
  }
}
