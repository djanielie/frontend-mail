import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../core/email_screenshot.dart';
import '../mail_html.dart';
import 'mail_html_controller.dart';
import 'mail_html_view.dart';
import 'mail_link_sheet.dart';

class MailHtmlDocument extends StatefulWidget {
  const MailHtmlDocument(
    this.html, {
    super.key,
    this.controller,
    this.onScrollDelta,
  });

  final String html;
  final MailHtmlController? controller;
  final ValueChanged<Offset>? onScrollDelta;

  @override
  State<MailHtmlDocument> createState() => _MailHtmlDocumentIoState();
}

class _MailHtmlDocumentIoState extends State<MailHtmlDocument> {
  WebViewController? _controller;
  Completer<Uint8List?>? _capture;
  late final String _token;
  late final Future<Uint8List?> Function() _boundCapture;
  var _failed = false;
  var _height = 160.0;

  bool get _inTest => WidgetsBinding.instance.runtimeType.toString().contains('TestWidgetsFlutterBinding');

  @override
  void initState() {
    super.initState();
    _token = identityHashCode(this).toString();
    _boundCapture = _capturePng;
    widget.controller?.bind(_boundCapture);
    if (_inTest) {
      _failed = true;
      return;
    }
    _createController();
  }

  Future<void> _createController() async {
    try {
      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.white)
        ..addJavaScriptChannel(
          'MailHtml',
          onMessageReceived: (message) => _onMessage(message.message),
        )
        ..setNavigationDelegate(
          NavigationDelegate(
            onNavigationRequest: (request) {
              final url = request.url;
              if (url.startsWith('about:') || url.startsWith('data:') || url == 'https://mail.local/') {
                return NavigationDecision.navigate;
              }
              if (mounted) handleMailLink(context, url);
              return NavigationDecision.prevent;
            },
          ),
        );
      await controller.loadHtmlString(
        emailDocumentHtml(widget.html, token: _token),
        baseUrl: 'https://mail.local/',
      );
      if (!mounted) return;
      setState(() => _controller = controller);
    } catch (_) {
      if (!mounted) return;
      setState(() => _failed = true);
    }
  }

  @override
  void didUpdateWidget(MailHtmlDocument oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.unbind(_boundCapture);
      widget.controller?.bind(_boundCapture);
    }
    if (oldWidget.html != widget.html) {
      _controller?.loadHtmlString(
        emailDocumentHtml(widget.html, token: _token),
        baseUrl: 'https://mail.local/',
      );
    }
  }

  @override
  void dispose() {
    widget.controller?.unbind(_boundCapture);
    _finishCapture(null);
    super.dispose();
  }

  Future<Uint8List?> _capturePng() async {
    final pending = _capture;
    if (pending != null) return pending.future;
    final completer = Completer<Uint8List?>();
    _capture = completer;
    final controller = _controller;
    if (controller == null) {
      _finishCapture(null);
      return completer.future;
    }
    try {
      await controller.runJavaScript('window.__mailCapture && window.__mailCapture();');
    } catch (_) {
      _finishCapture(null);
      return completer.future;
    }
    Future<void>.delayed(const Duration(seconds: 12), () {
      if (!completer.isCompleted) _finishCapture(null);
    });
    return completer.future;
  }

  void _finishCapture(Uint8List? bytes) {
    final pending = _capture;
    if (pending == null || pending.isCompleted) return;
    pending.complete(bytes);
    _capture = null;
  }

  void _onMessage(String raw) {
    Map<String, dynamic> payload;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      payload = Map<String, dynamic>.from(decoded);
    } catch (_) {
      return;
    }
    if (payload['source'] != 'mail-html' || payload['token']?.toString() != _token) return;

    final href = payload['href']?.toString();
    if (href != null && href.isNotEmpty && mounted) {
      handleMailLink(context, href);
    }

    final height = payload['height'];
    if (height is num) {
      final next = height.toDouble().clamp(80.0, 20000.0);
      if ((next - _height).abs() > 4 && mounted) {
        setState(() => _height = next);
      }
    }

    final wheel = payload['wheel'];
    if (wheel is Map && widget.onScrollDelta != null) {
      widget.onScrollDelta!(Offset(
        (wheel['deltaX'] as num?)?.toDouble() ?? 0,
        (wheel['deltaY'] as num?)?.toDouble() ?? 0,
      ));
    }

    if (payload.containsKey('screenshot') || payload.containsKey('screenshotError')) {
      _finishCapture(decodePngDataUrl(payload['screenshot']?.toString() ?? ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_failed || _controller == null) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: MailHtmlView(widget.html),
        ),
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.45)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: _height,
          width: double.infinity,
          child: WebViewWidget(controller: _controller!),
        ),
      ),
    );
  }
}
