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

String documentWithSignature(String source, String signature) {
  final body = documentFromPlain(source).replaceFirst(RegExp(r'^<!DOCTYPE html><html><head><meta charset="utf-8"></head><body>'), '').replaceFirst('</body></html>', '');
  final sig = signature.trim();
  if (sig.isEmpty) return _document(body);
  if (_looksLikeHtml(sig)) return _document('$body$sig');
  final signatureBody = documentFromPlain(sig)
      .replaceFirst(RegExp(r'^<!DOCTYPE html><html><head><meta charset="utf-8"></head><body>'), '')
      .replaceFirst('</body></html>', '');
  return _document('$body$signatureBody');
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

String plainWithSignature(String source, String signature) {
  final sig = signature.trim();
  if (sig.isEmpty) return plainFromSource(source);
  final plainSig = _looksLikeHtml(sig)
      ? sig.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n').replaceAll(RegExp(r'<[^>]+>'), ' ')
      : plainFromSource(sig);
  return '${plainFromSource(source)}\n\n${plainSig.replaceAll(RegExp(r'\s+'), ' ').trim()}'.trim();
}

bool _looksLikeHtml(String value) {
  return RegExp(r'</?[a-z][\s\S]*>', caseSensitive: false).hasMatch(value);
}

String htmlBodyFragment(String html) {
  final source = html.trim();
  if (source.isEmpty) return '';
  final match = RegExp(r'<body[^>]*>([\s\S]*)</body>', caseSensitive: false).firstMatch(source);
  if (match != null) return match.group(1)!.trim();
  return source;
}

String emailDocumentHtml(String html, {required String token}) {
  final body = htmlBodyFragment(html)
      .replaceAll(RegExp(r'</script', caseSensitive: false), r'<\/script');
  return '''
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="color-scheme" content="light">
<style>
  html, body { margin: 0; padding: 12px 16px; background: #fff; color: #202124; height: auto; overflow: visible; }
  body { font-family: 'Google Sans', Roboto, Arial, Helvetica, sans-serif; font-size: 14px; line-height: 1.45; }
  img { max-width: 100%; height: auto; }
  table { border-collapse: collapse; }
  a { color: #1a73e8; }
</style>
</head>
<body>
$body
<script>
(function () {
  var token = ${jsonEncode(token)};
  function send(payload) {
    payload.source = 'mail-html';
    payload.token = token;
    var json = JSON.stringify(payload);
    if (window.MailHtml && window.MailHtml.postMessage) {
      window.MailHtml.postMessage(json);
    } else if (parent) {
      parent.postMessage(json, '*');
    }
  }
  function contentHeight() {
    return Math.max(
      document.body.scrollHeight,
      document.documentElement.scrollHeight,
      document.body.offsetHeight,
      document.documentElement.offsetHeight
    );
  }
  function notifyHeight() {
    send({ height: contentHeight() + 8 });
  }
  function capturePng() {
    var width = Math.max(document.documentElement.scrollWidth, document.body.scrollWidth, 1);
    var height = Math.max(contentHeight(), 1);
    var scale = Math.min(2, 4096 / width, 8192 / height);
    width = Math.ceil(width);
    height = Math.ceil(height);
    var clone = document.body.cloneNode(true);
    var scripts = clone.querySelectorAll('script');
    for (var i = 0; i < scripts.length; i++) scripts[i].remove();
    var wrapper = document.createElement('div');
    wrapper.setAttribute('xmlns', 'http://www.w3.org/1999/xhtml');
    wrapper.style.cssText = 'width:' + width + 'px;background:#fff;color:#202124;font-family:Arial,Helvetica,sans-serif;font-size:14px;line-height:1.45;';
    wrapper.appendChild(clone);
    var xhtml = new XMLSerializer().serializeToString(wrapper);
    var svg = '<svg xmlns="http://www.w3.org/2000/svg" width="' + width + '" height="' + height + '">' +
      '<foreignObject width="100%" height="100%">' + xhtml + '</foreignObject></svg>';
    var blob = new Blob([svg], { type: 'image/svg+xml;charset=utf-8' });
    var url = URL.createObjectURL(blob);
    var img = new Image();
    img.onload = function () {
      var canvas = document.createElement('canvas');
      canvas.width = Math.max(1, Math.ceil(width * scale));
      canvas.height = Math.max(1, Math.ceil(height * scale));
      var ctx = canvas.getContext('2d');
      ctx.fillStyle = '#ffffff';
      ctx.fillRect(0, 0, canvas.width, canvas.height);
      ctx.drawImage(img, 0, 0, canvas.width, canvas.height);
      URL.revokeObjectURL(url);
      try {
        send({ screenshot: canvas.toDataURL('image/png') });
      } catch (err) {
        send({ screenshotError: String(err) });
      }
    };
    img.onerror = function () {
      URL.revokeObjectURL(url);
      send({ screenshotError: 'render' });
    };
    img.src = url;
  }
  window.__mailCapture = capturePng;
  window.addEventListener('message', function (event) {
    var data = event.data;
    if (typeof data !== 'string') return;
    var parsed;
    try { parsed = JSON.parse(data); } catch (e) { return; }
    if (!parsed || parsed.source !== 'mail-html-host' || parsed.token !== token) return;
    if (parsed.cmd === 'capture') capturePng();
  });
  document.addEventListener('click', function (event) {
    var target = event.target;
    var link = target && target.closest ? target.closest('a') : null;
    if (!link || !link.getAttribute('href')) return;
    event.preventDefault();
    event.stopPropagation();
    send({ href: link.href });
  }, true);
  window.addEventListener('wheel', function (event) {
    send({ wheel: { deltaX: event.deltaX, deltaY: event.deltaY } });
  }, { passive: true });
  if (window.ResizeObserver) {
    new ResizeObserver(notifyHeight).observe(document.body);
  }
  var images = document.querySelectorAll('img');
  for (var i = 0; i < images.length; i++) {
    images[i].addEventListener('load', notifyHeight);
    images[i].addEventListener('error', notifyHeight);
  }
  window.addEventListener('load', notifyHeight);
  notifyHeight();
  setTimeout(notifyHeight, 80);
  setTimeout(notifyHeight, 400);
})();
</script>
</body>
</html>
''';
}

bool htmlHasVisibleContent(String html) {
  if (RegExp(r'<img\b', caseSensitive: false).hasMatch(html)) return true;
  final text = html
      .replaceAll(RegExp(r'<style[\s\S]*?</style>', caseSensitive: false), ' ')
      .replaceAll(RegExp(r'<script[\s\S]*?</script>', caseSensitive: false), ' ')
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<[^>]+>'), ' ')
      .replaceAll('&nbsp;', ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return text.isNotEmpty;
}
