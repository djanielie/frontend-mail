import 'dart:convert';

String documentFromPlain(String source) {
  final escaped = const HtmlEscape(HtmlEscapeMode.element).convert(source);
  final paragraphs = escaped
      .replaceAll('\r\n', '\n')
      .split(RegExp(r'\n{2,}'))
      .map((block) => '<p>${_marks(block).replaceAll('\n', '<br>')}</p>')
      .join();
  return _document(paragraphs.isEmpty ? '<p></p>' : paragraphs);
}

String documentFromFragment(String fragment) {
  final trimmed = fragment.trim();
  if (trimmed.isEmpty) return documentFromPlain('');
  if (trimmed.toLowerCase().startsWith('<!doctype html') || trimmed.toLowerCase().startsWith('<html')) {
    return trimmed;
  }
  return _document(trimmed);
}

String _document(String body) {
  return '<!DOCTYPE html><html><head><meta charset="utf-8"></head><body>$body</body></html>';
}

String _marks(String escaped) {
  var text = escaped.replaceAllMapped(
    RegExp(r'\*\*(.+?)\*\*'),
    (match) => '<strong>${match[1]}</strong>',
  );
  text = text.replaceAllMapped(
    RegExp(r'(?<!\*)\*(.+?)\*(?!\*)'),
    (match) => '<em>${match[1]}</em>',
  );
  text = text.replaceAllMapped(
    RegExp(r'(https?://[^\s<]+)'),
    (match) => '<a href="${match[1]}">${match[1]}</a>',
  );
  return text;
}

String plainFromSource(String source) {
  return source
      .replaceAllMapped(RegExp(r'\*\*(.+?)\*\*'), (match) => match[1] ?? '')
      .replaceAllMapped(RegExp(r'\*(.+?)\*'), (match) => match[1] ?? '');
}
