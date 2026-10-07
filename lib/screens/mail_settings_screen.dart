import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/mail_controller.dart';
import '../providers/mail_preferences.dart';

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
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(controller: _displayName, decoration: const InputDecoration(labelText: 'Display name')),
          const SizedBox(height: 12),
          TextField(
            controller: _signature,
            minLines: 4,
            maxLines: null,
            decoration: const InputDecoration(labelText: 'Signature'),
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
}
