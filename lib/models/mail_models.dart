class MailAddress {
  const MailAddress({required this.name, required this.address});

  final String name;
  final String address;

  String get label {
    if (name.isEmpty) return address;
    if (address.isEmpty) return name;
    return '$name <$address>';
  }

  static MailAddress? fromJson(Object? json) {
    if (json is! Map) return null;
    return MailAddress(
      name: json['name']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
    );
  }

  static List<MailAddress> listFrom(Object? json) {
    if (json is! List) return const [];
    return json.map(MailAddress.fromJson).whereType<MailAddress>().toList();
  }
}

class MailFolder {
  const MailFolder({
    required this.path,
    required this.name,
    required this.icon,
    required this.unreadCount,
    required this.selectable,
    this.specialUse,
  });

  final String path;
  final String name;
  final String? specialUse;
  final String icon;
  final int unreadCount;
  final bool selectable;

  factory MailFolder.fromJson(Map<String, dynamic> json) {
    return MailFolder(
      path: json['path']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      specialUse: json['specialUse']?.toString(),
      icon: json['icon']?.toString() ?? 'folder',
      unreadCount: json['unreadCount'] is num ? (json['unreadCount'] as num).toInt() : 0,
      selectable: json['selectable'] != false,
    );
  }

  MailFolder copyWith({int? unreadCount}) {
    return MailFolder(
      path: path,
      name: name,
      icon: icon,
      unreadCount: unreadCount ?? this.unreadCount,
      selectable: selectable,
      specialUse: specialUse,
    );
  }
}

class MailSummary {
  const MailSummary({
    required this.uid,
    required this.folder,
    required this.subject,
    required this.date,
    required this.snippet,
    required this.isRead,
    required this.isFlagged,
    required this.hasAttachments,
    required this.size,
    this.from,
  });

  final int uid;
  final String folder;
  final String subject;
  final MailAddress? from;
  final String date;
  final String snippet;
  final bool isRead;
  final bool isFlagged;
  final bool hasAttachments;
  final int size;

  factory MailSummary.fromJson(Map<String, dynamic> json) {
    return MailSummary(
      uid: json['uid'] is num ? (json['uid'] as num).toInt() : 0,
      folder: json['folder']?.toString() ?? '',
      subject: json['subject']?.toString() ?? '',
      from: MailAddress.fromJson(json['from']),
      date: json['date']?.toString() ?? '',
      snippet: json['snippet']?.toString() ?? '',
      isRead: json['isRead'] == true,
      isFlagged: json['isFlagged'] == true,
      hasAttachments: json['hasAttachments'] == true,
      size: json['size'] is num ? (json['size'] as num).toInt() : 0,
    );
  }

  MailSummary copyWith({bool? isRead, bool? isFlagged}) {
    return MailSummary(
      uid: uid,
      folder: folder,
      subject: subject,
      date: date,
      snippet: snippet,
      isRead: isRead ?? this.isRead,
      isFlagged: isFlagged ?? this.isFlagged,
      hasAttachments: hasAttachments,
      size: size,
      from: from,
    );
  }
}

class MailAttachment {
  const MailAttachment({
    required this.id,
    required this.filename,
    required this.contentType,
    required this.size,
    required this.disposition,
  });

  final String id;
  final String filename;
  final String contentType;
  final int size;
  final String disposition;

  factory MailAttachment.fromJson(Map<String, dynamic> json) {
    return MailAttachment(
      id: json['id']?.toString() ?? '',
      filename: json['filename']?.toString() ?? 'attachment',
      contentType: json['contentType']?.toString() ?? 'application/octet-stream',
      size: json['size'] is num ? (json['size'] as num).toInt() : 0,
      disposition: json['disposition']?.toString() ?? 'attachment',
    );
  }
}

class MailMessage {
  const MailMessage({
    required this.uid,
    required this.folder,
    required this.subject,
    required this.date,
    required this.text,
    required this.html,
    required this.to,
    required this.cc,
    required this.bcc,
    required this.replyTo,
    required this.attachments,
    required this.messageId,
    required this.inReplyTo,
    required this.references,
    required this.isRead,
    required this.isFlagged,
    this.from,
  });

  final int uid;
  final String folder;
  final String subject;
  final MailAddress? from;
  final String date;
  final String text;
  final String html;
  final List<MailAddress> to;
  final List<MailAddress> cc;
  final List<MailAddress> bcc;
  final List<MailAddress> replyTo;
  final List<MailAttachment> attachments;
  final String messageId;
  final String inReplyTo;
  final String references;
  final bool isRead;
  final bool isFlagged;

  factory MailMessage.fromJson(Map<String, dynamic> json) {
    final headers = json['headers'] is Map ? json['headers'] as Map : const {};
    final attachments = json['attachments'] is List ? json['attachments'] as List : const [];
    return MailMessage(
      uid: json['uid'] is num ? (json['uid'] as num).toInt() : 0,
      folder: json['folder']?.toString() ?? '',
      subject: json['subject']?.toString() ?? '',
      from: MailAddress.fromJson(json['from']),
      date: json['date']?.toString() ?? '',
      text: json['text']?.toString() ?? '',
      html: json['html']?.toString() ?? '',
      to: MailAddress.listFrom(json['to']),
      cc: MailAddress.listFrom(json['cc']),
      bcc: MailAddress.listFrom(json['bcc']),
      replyTo: MailAddress.listFrom(json['replyTo']),
      attachments: attachments
          .whereType<Map>()
          .map((item) => MailAttachment.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      messageId: headers['messageId']?.toString() ?? '',
      inReplyTo: headers['inReplyTo']?.toString() ?? '',
      references: headers['references']?.toString() ?? '',
      isRead: json['isRead'] == true,
      isFlagged: json['isFlagged'] == true,
    );
  }
}
