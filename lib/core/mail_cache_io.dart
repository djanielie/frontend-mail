import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class MailCache {
  static Future<Directory> _dir(String email) async {
    final root = await getApplicationSupportDirectory();
    final folder = Directory('${root.path}/mail-cache/${email.toLowerCase().replaceAll(RegExp(r'[^a-z0-9@._-]'), '_')}');
    await folder.create(recursive: true);
    return folder;
  }

  static Future<void> _write(String email, String name, Object value) async {
    final file = File('${(await _dir(email)).path}/$name.json');
    await file.writeAsString(jsonEncode(value));
  }

  static Future<dynamic> _read(String email, String name) async {
    final file = File('${(await _dir(email)).path}/$name.json');
    if (!await file.exists()) return null;
    return jsonDecode(await file.readAsString());
  }

  static Future<void> saveFolders(String email, List<Map<String, dynamic>> folders) {
    return _write(email, 'folders', folders);
  }

  static Future<void> saveMessages(String email, String folder, Map<String, dynamic> payload) {
    return _write(email, 'messages', {'folder': folder, ...payload});
  }

  static Future<void> saveDetail(String email, Map<String, dynamic> payload) {
    return _write(email, 'detail', payload);
  }

  static Future<List<Map<String, dynamic>>?> loadFolders(String email) async {
    final raw = await _read(email, 'folders');
    if (raw is! List) return null;
    return raw.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
  }

  static Future<Map<String, dynamic>?> loadMessages(String email, String folder) async {
    final raw = await _read(email, 'messages');
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    if (map['folder']?.toString() != folder) return null;
    return map;
  }

  static Future<Map<String, dynamic>?> loadDetail(String email) async {
    final raw = await _read(email, 'detail');
    if (raw is! Map) return null;
    return Map<String, dynamic>.from(raw);
  }
}
