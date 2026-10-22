import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

String emailScreenshotFilename(String subject) {
  final trimmed = subject.replaceFirst(RegExp(r'^\s*(re|fwd):\s*', caseSensitive: false), '').trim();
  final safe = (trimmed.isEmpty ? 'email' : trimmed)
      .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  final cut = safe.length > 60 ? safe.substring(0, 60).trim() : safe;
  return '$cut.png';
}

Uint8List? decodePngDataUrl(String dataUrl) {
  final match = RegExp(r'^data:image/png;base64,(.+)$', dotAll: true).firstMatch(dataUrl.trim());
  if (match == null) return null;
  try {
    return base64Decode(match.group(1)!);
  } catch (_) {
    return null;
  }
}

Future<Uint8List?> captureRepaintBoundary(GlobalKey key, {double pixelRatio = 2}) async {
  final boundary = key.currentContext?.findRenderObject();
  if (boundary is! RenderRepaintBoundary) return null;
  final image = await boundary.toImage(pixelRatio: pixelRatio);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data?.buffer.asUint8List();
}

Future<Uint8List> renderTextPng(String text, {double width = 960}) async {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: const TextStyle(
        color: Color(0xFF202124),
        fontSize: 14,
        height: 1.45,
      ),
    ),
    textDirection: TextDirection.ltr,
  );
  painter.layout(maxWidth: math.max(120, width - 48));
  final height = math.max(64, painter.height + 48);
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(Rect.fromLTWH(0, 0, width, height.toDouble()), Paint()..color = const Color(0xFFFFFFFF));
  painter.paint(canvas, const Offset(24, 24));
  final image = await recorder.endRecording().toImage(width.round(), height.ceil());
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

Future<Uint8List> stitchPngs(List<Uint8List> parts, {Color background = const Color(0xFFFFFFFF)}) async {
  if (parts.isEmpty) {
    throw ArgumentError('No images to stitch');
  }
  if (parts.length == 1) return parts.first;

  final images = <ui.Image>[];
  for (final bytes in parts) {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    images.add(frame.image);
  }

  final width = images.map((image) => image.width).reduce(math.max);
  final height = images.fold<int>(0, (sum, image) => sum + image.height);
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..color = background,
  );
  var y = 0.0;
  for (final image in images) {
    canvas.drawImage(image, Offset(0, y), Paint());
    y += image.height;
  }
  final out = await recorder.endRecording().toImage(width, height);
  final data = await out.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}
