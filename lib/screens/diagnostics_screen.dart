import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_controller.dart';

class DiagnosticsScreen extends ConsumerStatefulWidget {
  const DiagnosticsScreen({super.key});

  @override
  ConsumerState<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends ConsumerState<DiagnosticsScreen> {
  Map<String, dynamic>? _data;
  String? _error;
  var _loading = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ref.read(apiClientProvider).getJson('/api/diagnostics');
      if (!mounted) return;
      setState(() => _data = data);
    } catch (err) {
      if (!mounted) return;
      setState(() => _error = err.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = _data ?? const {};
    return Scaffold(
      appBar: AppBar(
        title: const Text('Diagnostics'),
        actions: [
          IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (_loading) const LinearProgressIndicator(),
          if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          _StatusTile(label: 'API', value: rows['status']?.toString() ?? '-'),
          _StatusTile(label: 'IMAP', value: rows['imap']?.toString() ?? '-'),
          _StatusTile(label: 'SMTP', value: rows['smtp']?.toString() ?? '-'),
          _StatusTile(label: 'Database', value: rows['database']?.toString() ?? '-'),
          _StatusTile(label: 'Folders', value: rows['folderCount']?.toString() ?? '-'),
          const SizedBox(height: 16),
          Text('Folders', style: Theme.of(context).textTheme.titleMedium),
          for (final folder in (rows['folders'] is List ? rows['folders'] as List : const []))
            if (folder is Map)
              ListTile(
                title: Text(folder['name']?.toString() ?? ''),
                subtitle: Text(folder['path']?.toString() ?? ''),
                trailing: Text('${folder['unreadCount'] ?? 0}'),
              ),
        ],
      ),
    );
  }
}

class _StatusTile extends StatelessWidget {
  const _StatusTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ok = value == 'ok';
    return ListTile(
      leading: Icon(ok ? Icons.check_circle_outline : Icons.info_outline, color: ok ? Colors.green : null),
      title: Text(label),
      trailing: Text(value),
    );
  }
}
