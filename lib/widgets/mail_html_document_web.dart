import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

import '../core/email_screenshot.dart';
import '../mail_html.dart';
import 'mail_html_controller.dart';
import 'mail_html_pointer.dart';
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
  State<MailHtmlDocument> createState() => _MailHtmlDocumentWebState();
}

class _MailHtmlDocumentWebState extends State<MailHtmlDocument> {
  late final String _viewType;
  late final String _token;
  late final Future<Uint8List?> Function() _boundCapture;
  web.HTMLIFrameElement? _iframe;
  JSFunction? _listener;
  Completer<Uint8List?>? _capture;
  var _height = 160.0;

  @override
  void initState() {
    super.initState();
    _token = identityHashCode(this).toString();
    _viewType = 'mail-html-$_token';
    _boundCapture = _capturePng;
    widget.controller?.bind(_boundCapture);
    MailHtmlPointer.enabled.addListener(_applyPointerEvents);
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int id) {
      final iframe = web.HTMLIFrameElement()
        ..srcdoc = emailDocumentHtml(widget.html, token: _token).toJS
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '${_height}px'
        ..style.overflow = 'hidden'
        ..style.backgroundColor = '#ffffff';
      iframe.setAttribute('sandbox', 'allow-scripts allow-popups allow-popups-to-escape-sandbox');
      iframe.setAttribute('referrerpolicy', 'no-referrer');
      iframe.setAttribute('data-mail-html', '1');
      _iframe = iframe;
      _applyPointerEvents();
      return iframe;
    });
    _listener = _onWindowMessage.toJS;
    web.window.addEventListener('message', _listener!);
  }

  void _applyPointerEvents() {
    final interactive = MailHtmlPointer.enabled.value ? 'auto' : 'none';
    web.Element? node = _iframe;
    var depth = 0;
    while (node != null && depth < 3) {
      if (node.isA<web.HTMLElement>()) {
        (node as web.HTMLElement).style.pointerEvents = interactive;
      }
      node = node.parentElement;
      depth++;
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
      _iframe?.srcdoc = emailDocumentHtml(widget.html, token: _token).toJS;
    }
  }

  @override
  void dispose() {
    widget.controller?.unbind(_boundCapture);
    MailHtmlPointer.enabled.removeListener(_applyPointerEvents);
    _finishCapture(null);
    if (_listener != null) {
      web.window.removeEventListener('message', _listener!);
    }
    super.dispose();
  }

  Future<Uint8List?> _capturePng() {
    final pending = _capture;
    if (pending != null) return pending.future;
    final completer = Completer<Uint8List?>();
    _capture = completer;
    final iframe = _iframe;
    if (iframe == null) {
      _finishCapture(null);
      return completer.future;
    }
    iframe.contentWindow?.postMessage(
      jsonEncode(MailHtmlHostMessage(token: _token, cmd: 'capture').toJson()).toJS,
      '*'.toJS,
    );
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

  void _onWindowMessage(web.Event raw) {
    final event = raw as web.MessageEvent;
    final data = event.data;
    if (data == null || !data.isA<JSString>()) return;
    Map<String, dynamic> payload;
    try {
      final decoded = jsonDecode((data as JSString).toDart);
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
      if ((next - _height).abs() > 4) {
        _iframe?.style.height = '${next}px';
        if (mounted) setState(() => _height = next);
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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.45)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(height: _height, width: double.infinity, child: HtmlElementView(viewType: _viewType)),
      ),
    );
  }
}
