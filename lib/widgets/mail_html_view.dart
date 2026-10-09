import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';

import 'ibelucky_logo_bytes.dart';
import 'ibelucky_mark.dart';

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
    return HtmlWidget(
      html,
      textStyle: textStyle,
      factoryBuilder: MailHtmlFactory.new,
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
