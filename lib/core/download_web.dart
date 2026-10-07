import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

Future<String?> saveBytes({
  required String filename,
  required List<int> bytes,
  required String mime,
}) async {
  final safe = filename.replaceAll(RegExp(r'[\\/]'), '_');
  final extension = safe.contains('.') ? safe.split('.').last : null;
  return FilePicker.platform.saveFile(
    dialogTitle: 'Save attachment',
    fileName: safe,
    type: extension == null ? FileType.any : FileType.custom,
    allowedExtensions: extension == null ? null : [extension],
    bytes: Uint8List.fromList(bytes),
  );
}
