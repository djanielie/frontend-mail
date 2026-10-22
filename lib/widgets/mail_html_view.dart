import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';

import '../mail_html.dart';
import 'ibelucky_logo_bytes.dart';
import 'ibelucky_mark.dart';
import 'mail_link_sheet.dart';

final ibeLuckyLogoBytes = Uint8List.fromList(base64Decode(ibeLuckyLogoBase64));
final ibeLuckyLogoImage = MemoryImage(ibeLuckyLogoBytes);

bool isIbeLuckyLogoUrl(String url) {
  final uri = Uri.tryParse(url.trim());
  if (uri == null || !uri.hasScheme) return false;
  final host = uri.host.toLowerCase();
  if (host != 'ibelucky.com' && host != 'www.ibelucky.com') return false;
  final path = uri.path.toLowerCase();
  return path.contains('/assets/images/') && (path.contains('logo') || path.contains('ibelucky'));
}

class MailHtmlFactory extends WidgetFactory {
  MailHtmlFactory({required this.onOpenLink});

  final void Function(String url) onOpenLink;

  @override
  Future<bool> onTapUrl(String url) async {
    onOpenLink(url);
    return true;
  }

  @override
  Widget? buildGestureDetector(BuildTree tree, Widget child, GestureRecognizer recognizer) {
    if (recognizer is! TapGestureRecognizer) {
      return super.buildGestureDetector(tree, child, recognizer);
    }
    final href = tree.element.attributes['href'];
    final url = href == null ? null : (urlFull(href) ?? href);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: recognizer.onTap,
        onLongPress: url == null ? null : () => onOpenLink(url),
        onSecondaryTap: url == null ? null : () => onOpenLink(url),
        child: child,
      ),
    );
  }

  @override
  ImageProvider? imageProviderFromNetwork(String url) {
    if (isIbeLuckyLogoUrl(url)) {
      return ibeLuckyLogoImage;
    }
    return super.imageProviderFromNetwork(url);
  }

  @override
  Widget? buildImage(BuildTree tree, ImageMetadata data) {
    final built = super.buildImage(tree, data);
    if (built == null) return null;
    final url = data.sources.isNotEmpty ? data.sources.first.url : '';
    if (!isIbeLuckyLogoUrl(url)) return built;
    return Align(alignment: Alignment.centerRight, child: built);
  }
}

class MailHtmlView extends StatelessWidget {
  const MailHtmlView(this.html, {super.key, this.textStyle});

  final String html;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final fragment = htmlBodyFragment(html);
    return HtmlWidget(
      fragment.isEmpty ? html : fragment,
      textStyle: textStyle,
      factoryBuilder: () => MailHtmlFactory(
        onOpenLink: (url) => handleMailLink(context, url),
      ),
      onErrorBuilder: (context, element, error) {
        final src = element.attributes['src'] ?? '';
        if (isIbeLuckyLogoUrl(src)) {
          return Image(
            image: ibeLuckyLogoImage,
            width: 72,
            errorBuilder: (context, error, stackTrace) => const IbeLuckyMark(size: 72),
          );
        }
        return null;
      },
    );
  }
}
