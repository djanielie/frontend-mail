import 'package:url_launcher/url_launcher.dart';

Future<bool> openUrlInNewTab(Uri uri) {
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}

Future<bool> openUrlInExternalBrowser(Uri uri) {
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}
