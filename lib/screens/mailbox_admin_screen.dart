import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_controller.dart';

class MailboxAdminScreen extends ConsumerStatefulWidget {
  const MailboxAdminScreen({super.key});

  @override
  ConsumerState<MailboxAdminScreen> createState() => _MailboxAdminScreenState();
}

class _MailboxAdminScreenState extends ConsumerState<MailboxAdminScreen> {
  final _search = TextEditingController();
  List<Map<String, dynamic>> _mailboxes = const [];
  String? _error;
  var _loading = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final json = await ref.read(apiClientProvider).getJson('/api/admin/mailboxes');
      final rows = (json['mailboxes'] is List ? json['mailboxes'] as List : const [])
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
      if (!mounted) return;
      setState(() => _mailboxes = rows);
    } catch (err) {
      if (!mounted) return;
      setState(() => _error = err.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final needle = _search.text.trim().toLowerCase();
    final rows = needle.isEmpty
        ? _mailboxes
        : _mailboxes.where((row) => '${row['email'] ?? ''}'.toLowerCase().contains(needle)).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mailbox admin'),
        actions: [
          IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: FilledButton.icon(
              onPressed: _create,
              icon: const Icon(Icons.add),
              label: const Text('New mailbox'),
            ),
          ),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              if (_loading) const LinearProgressIndicator(),
              if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              TextField(
                controller: _search,
                decoration: const InputDecoration(prefixIcon: Icon(Icons.search), labelText: 'Search mailbox'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              Card(
                child: Column(
                  children: [
                    for (final row in rows)
                      ListTile(
                        leading: const Icon(Icons.alternate_email),
                        title: Text('${row['email'] ?? ''}'),
                        trailing: Wrap(
                          spacing: 6,
                          children: [
                            IconButton(
                              tooltip: 'Change password',
                              onPressed: () => _changePassword(row),
                              icon: const Icon(Icons.key_outlined),
                            ),
                            IconButton(
                              tooltip: 'Delete',
                              onPressed: () => _delete(row),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _create() async {
    final result = await _mailboxDialog(title: 'New mailbox', includeEmail: true);
    if (result == null) return;
    await ref.read(apiClientProvider).postJson('/api/admin/mailboxes', result);
    await _load();
  }

  Future<void> _changePassword(Map<String, dynamic> row) async {
    final result = await _mailboxDialog(title: 'Change password', includeEmail: false, email: '${row['email'] ?? ''}');
    if (result == null) return;
    await ref.read(apiClientProvider).putJson('/api/admin/mailboxes/${row['id']}/password', {
      'password': result['password'],
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password updated')));
  }

  Future<void> _delete(Map<String, dynamic> row) async {
    final email = '${row['email'] ?? ''}';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete mailbox'),
        content: Text('Delete $email? This removes the account from the mail user database.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(apiClientProvider).deleteJson('/api/admin/mailboxes/${row['id']}');
    await _load();
  }

  Future<Map<String, String>?> _mailboxDialog({required String title, required bool includeEmail, String email = ''}) {
    final emailController = TextEditingController(text: email);
    final passwordController = TextEditingController();
    return showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (includeEmail)
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
              )
            else
              Align(alignment: Alignment.centerLeft, child: Text(email)),
            const SizedBox(height: 12),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(context, {
              if (includeEmail) 'email': emailController.text.trim(),
              'password': passwordController.text,
            }),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
