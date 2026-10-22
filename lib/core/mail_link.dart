class MailLink {
  const MailLink({required this.uri, required this.original});

  final Uri uri;
  final String original;

  String get scheme => uri.scheme.toLowerCase();
  bool get isHttp => scheme == 'http' || scheme == 'https';
  bool get isMailto => scheme == 'mailto';
  bool get isTel => scheme == 'tel';

  String get hostLabel {
    if (isMailto) {
      final email = uri.path.isNotEmpty ? uri.path : uri.toString().replaceFirst(RegExp(r'^mailto:', caseSensitive: false), '');
      return email;
    }
    if (isTel) {
      return Uri.decodeComponent(uri.path.isNotEmpty ? uri.path : original);
    }
    return uri.host;
  }

  String get displayUrl {
    if (isMailto) return 'mailto:$hostLabel';
    if (isTel) return 'tel:$hostLabel';
    return uri.toString();
  }
}

MailLink? parseMailLink(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  var uri = Uri.tryParse(trimmed);
  if (uri == null) return null;
  if (!uri.hasScheme) {
    if (RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(trimmed)) {
      uri = Uri(scheme: 'mailto', path: trimmed);
    } else if (RegExp(r'^(www\.)?[a-z0-9.-]+\.[a-z]{2,}([/:?#].*)?$', caseSensitive: false).hasMatch(trimmed)) {
      uri = Uri.tryParse('https://$trimmed');
    }
  }
  if (uri == null || !uri.hasScheme) return null;
  final scheme = uri.scheme.toLowerCase();
  const allowed = {'http', 'https', 'mailto', 'tel'};
  if (!allowed.contains(scheme)) return null;
  if ((scheme == 'http' || scheme == 'https') && (uri.host.isEmpty || uri.userInfo.isNotEmpty)) {
    return null;
  }
  if (scheme == 'mailto' && uri.path.isEmpty) return null;
  return MailLink(uri: uri, original: trimmed);
}
