import 'package:web/web.dart' as web;

Future<bool> openUrlInNewTab(Uri uri) async {
  web.window.open(uri.toString(), '_blank', 'noopener,noreferrer');
  return true;
}

Future<bool> openUrlInExternalBrowser(Uri uri) => openUrlInNewTab(uri);
