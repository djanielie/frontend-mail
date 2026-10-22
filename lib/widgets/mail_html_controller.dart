import 'dart:typed_data';

class MailHtmlController {
  Future<Uint8List?> Function()? _capture;

  void bind(Future<Uint8List?> Function() capture) => _capture = capture;

  void unbind(Future<Uint8List?> Function() capture) {
    if (identical(_capture, capture)) _capture = null;
  }

  Future<Uint8List?> capturePng() async {
    final capture = _capture;
    if (capture == null) return null;
    return capture();
  }
}

class MailHtmlHostMessage {
  const MailHtmlHostMessage({required this.token, required this.cmd});

  final String token;
  final String cmd;

  Map<String, String> toJson() => {
        'source': 'mail-html-host',
        'token': token,
        'cmd': cmd,
      };
}
