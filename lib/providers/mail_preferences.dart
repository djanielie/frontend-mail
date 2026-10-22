import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/mail_models.dart';
import 'auth_controller.dart';

class MailContact {
  const MailContact({required this.name, required this.address, this.uses = 0});

  final String name;
  final String address;
  final int uses;

  String get label {
    if (name.isEmpty) return address;
    if (address.isEmpty) return name;
    return '$name <$address>';
  }

  MailContact copyWith({String? name, String? address, int? uses}) {
    return MailContact(
      name: name ?? this.name,
      address: address ?? this.address,
      uses: uses ?? this.uses,
    );
  }

  Map<String, Object> toJson() => {'name': name, 'address': address, 'uses': uses};

  static MailContact? fromJson(Object? json) {
    if (json is! Map) return null;
    final address = json['address']?.toString() ?? '';
    if (address.isEmpty) return null;
    return MailContact(
      name: json['name']?.toString() ?? '',
      address: address,
      uses: json['uses'] is num ? (json['uses'] as num).toInt() : 0,
    );
  }

  static MailContact? fromAddress(MailAddress? address) {
    if (address == null || address.address.isEmpty) return null;
    return MailContact(name: address.name, address: address.address);
  }
}

class MailRule {
  const MailRule({
    required this.id,
    this.name = '',
    this.from = '',
    this.subject = '',
    this.q = '',
    this.action = 'move',
    this.destination = '',
  });

  final String id;
  final String name;
  final String from;
  final String subject;
  final String q;
  final String action;
  final String destination;

  Map<String, String> toJson() => {
        'id': id,
        'name': name,
        'from': from,
        'subject': subject,
        'q': q,
        'action': action,
        'destination': destination,
      };

  static MailRule? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id']?.toString() ?? '';
    if (id.isEmpty) return null;
    return MailRule(
      id: id,
      name: json['name']?.toString() ?? '',
      from: json['from']?.toString() ?? '',
      subject: json['subject']?.toString() ?? '',
      q: json['q']?.toString() ?? '',
      action: json['action']?.toString() ?? 'move',
      destination: json['destination']?.toString() ?? '',
    );
  }
}

class MailSignature {
  const MailSignature({required this.id, this.name = '', this.html = ''});

  final String id;
  final String name;
  final String html;

  String get label {
    final trimmed = name.trim();
    return trimmed.isEmpty ? 'Sans nom' : trimmed;
  }

  MailSignature copyWith({String? name, String? html}) {
    return MailSignature(id: id, name: name ?? this.name, html: html ?? this.html);
  }

  Map<String, String> toJson() => {'id': id, 'name': name, 'html': html};

  static MailSignature? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id']?.toString() ?? '';
    if (id.isEmpty) return null;
    return MailSignature(
      id: id,
      name: json['name']?.toString() ?? '',
      html: json['html']?.toString() ?? '',
    );
  }
}

class MailPreferences {
  const MailPreferences({
    this.signatures = const [],
    this.activeSignatureId = '',
    this.displayName = '',
    this.color = 0xFF7B93FF,
    this.density = 'comfortable',
    this.sentFolder = '',
    this.draftsFolder = '',
    this.contacts = const [],
    this.pollMinutes = 2,
    this.notificationsEnabled = true,
    this.notifyPeople = true,
    this.notifyNewsletters = false,
    this.notifyAutomated = false,
    this.conversations = true,
    this.rules = const [],
  });

  final List<MailSignature> signatures;
  final String activeSignatureId;
  final String displayName;
  final int color;
  final String density;
  final String sentFolder;
  final String draftsFolder;
  final List<MailContact> contacts;
  final int pollMinutes;
  final bool notificationsEnabled;
  final bool notifyPeople;
  final bool notifyNewsletters;
  final bool notifyAutomated;
  final bool conversations;
  final List<MailRule> rules;

  bool get compact => density == 'compact';
  Color get accountColor => Color(color);

  MailSignature? get activeSignature {
    for (final item in signatures) {
      if (item.id == activeSignatureId) return item;
    }
    return signatures.isEmpty ? null : signatures.first;
  }

  String get signature => activeSignature?.html ?? '';

  bool notifiesCategory(String category) {
    if (!notificationsEnabled) return false;
    if (category == 'newsletter') return notifyNewsletters;
    if (category == 'automated') return notifyAutomated;
    return notifyPeople;
  }

  MailPreferences copyWith({
    List<MailSignature>? signatures,
    String? activeSignatureId,
    String? displayName,
    int? color,
    String? density,
    String? sentFolder,
    String? draftsFolder,
    List<MailContact>? contacts,
    int? pollMinutes,
    bool? notificationsEnabled,
    bool? notifyPeople,
    bool? notifyNewsletters,
    bool? notifyAutomated,
    bool? conversations,
    List<MailRule>? rules,
  }) {
    return MailPreferences(
      signatures: signatures ?? this.signatures,
      activeSignatureId: activeSignatureId ?? this.activeSignatureId,
      displayName: displayName ?? this.displayName,
      color: color ?? this.color,
      density: density ?? this.density,
      sentFolder: sentFolder ?? this.sentFolder,
      draftsFolder: draftsFolder ?? this.draftsFolder,
      contacts: contacts ?? this.contacts,
      pollMinutes: pollMinutes ?? this.pollMinutes,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      notifyPeople: notifyPeople ?? this.notifyPeople,
      notifyNewsletters: notifyNewsletters ?? this.notifyNewsletters,
      notifyAutomated: notifyAutomated ?? this.notifyAutomated,
      conversations: conversations ?? this.conversations,
      rules: rules ?? this.rules,
    );
  }

  Map<String, Object> toJson() => {
        'signature': signature,
        'signatures': signatures.map((item) => item.toJson()).toList(),
        'activeSignatureId': activeSignatureId,
        'displayName': displayName,
        'color': color,
        'density': density,
        'sentFolder': sentFolder,
        'draftsFolder': draftsFolder,
        'pollMinutes': pollMinutes,
        'contacts': contacts.map((item) => item.toJson()).toList(),
        'notificationsEnabled': notificationsEnabled,
        'notifyPeople': notifyPeople,
        'notifyNewsletters': notifyNewsletters,
        'notifyAutomated': notifyAutomated,
        'conversations': conversations,
        'rules': rules.map((item) => item.toJson()).toList(),
      };

  static MailPreferences fromJson(Object? json) {
    if (json is! Map) return const MailPreferences();
    final contacts = json['contacts'] is List ? json['contacts'] as List : const [];
    final rules = json['rules'] is List ? json['rules'] as List : const [];
    var signatures = (json['signatures'] is List ? json['signatures'] as List : const [])
        .map(MailSignature.fromJson)
        .whereType<MailSignature>()
        .toList();
    final legacy = json['signature']?.toString() ?? '';
    if (signatures.isEmpty && legacy.trim().isNotEmpty) {
      signatures = [MailSignature(id: 'default', name: 'Principale', html: legacy)];
    }
    return MailPreferences(
      signatures: signatures,
      activeSignatureId: json['activeSignatureId']?.toString() ?? '',
      displayName: json['displayName']?.toString() ?? '',
      color: json['color'] is num ? (json['color'] as num).toInt() : 0xFF7B93FF,
      density: json['density'] == 'compact' ? 'compact' : 'comfortable',
      sentFolder: json['sentFolder']?.toString() ?? '',
      draftsFolder: json['draftsFolder']?.toString() ?? '',
      pollMinutes: json['pollMinutes'] is num ? (json['pollMinutes'] as num).toInt().clamp(1, 30) : 2,
      contacts: contacts.map(MailContact.fromJson).whereType<MailContact>().toList(),
      notificationsEnabled: json['notificationsEnabled'] != false,
      notifyPeople: json['notifyPeople'] != false,
      notifyNewsletters: json['notifyNewsletters'] == true,
      notifyAutomated: json['notifyAutomated'] == true,
      conversations: json['conversations'] != false,
      rules: rules.map(MailRule.fromJson).whereType<MailRule>().toList(),
    );
  }
}

class MailPreferencesController extends StateNotifier<MailPreferences> {
  MailPreferencesController(this._prefs, this._email) : super(_read(_prefs, _email));

  final SharedPreferences _prefs;
  final String _email;

  static String _key(String email) => 'mail_preferences:${email.toLowerCase()}';

  static MailPreferences _read(SharedPreferences prefs, String email) {
    if (email.isEmpty) return const MailPreferences();
    final raw = prefs.getString(_key(email));
    if (raw == null || raw.isEmpty) return _withSignatures(const MailPreferences(), email, legacyHtml: _defaultSignature(email));
    try {
      return _withSignatures(MailPreferences.fromJson(jsonDecode(raw)), email);
    } catch (_) {
      return _withSignatures(const MailPreferences(), email, legacyHtml: _defaultSignature(email));
    }
  }

  static MailPreferences _withSignatures(MailPreferences parsed, String email, {String? legacyHtml}) {
    var signatures = [
      for (final item in parsed.signatures) item.copyWith(html: _withCurrentLogo(item.html)),
    ];
    final inherited = (legacyHtml ?? parsed.signature).trim();
    if (signatures.isEmpty && inherited.isNotEmpty) {
      signatures = [
        MailSignature(id: 'default', name: 'Principale', html: _withCurrentLogo(inherited)),
      ];
    }
    if (signatures.isEmpty) {
      final fallback = _defaultSignature(email);
      if (fallback.trim().isNotEmpty) {
        signatures = [MailSignature(id: 'default', name: 'Principale', html: fallback)];
      }
    }
    var activeId = parsed.activeSignatureId;
    if (activeId.isEmpty || !signatures.any((item) => item.id == activeId)) {
      activeId = signatures.isEmpty ? '' : signatures.first.id;
    }
    return parsed.copyWith(signatures: signatures, activeSignatureId: activeId);
  }

  Future<void> _write(MailPreferences next) async {
    state = next;
    if (_email.isEmpty) return;
    await _prefs.setString(_key(_email), jsonEncode(next.toJson()));
  }

  Future<void> update(MailPreferences next) => _write(next);

  Future<void> addContacts(Iterable<MailContact?> contacts, {bool bumpUses = false}) async {
    final merged = <String, MailContact>{
      for (final contact in state.contacts) contact.address.toLowerCase(): contact,
    };
    for (final contact in contacts.whereType<MailContact>()) {
      final key = contact.address.toLowerCase();
      final previous = merged[key];
      merged[key] = MailContact(
        name: contact.name.isNotEmpty ? contact.name : (previous?.name ?? ''),
        address: contact.address,
        uses: (previous?.uses ?? 0) + (bumpUses ? 1 : 0),
      );
    }
    final next = merged.values.toList()
      ..sort((a, b) {
        final byUses = b.uses.compareTo(a.uses);
        if (byUses != 0) return byUses;
        return a.label.toLowerCase().compareTo(b.label.toLowerCase());
      });
    await _write(state.copyWith(contacts: next.take(250).toList()));
  }

  Future<void> upsertContact(MailContact contact, {String? previousAddress}) async {
    final address = contact.address.trim();
    if (address.isEmpty) return;
    final merged = <String, MailContact>{
      for (final item in state.contacts) item.address.toLowerCase(): item,
    };
    final nextKey = address.toLowerCase();
    final previousKey = (previousAddress ?? address).trim().toLowerCase();
    var uses = contact.uses;
    if (previousKey.isNotEmpty && previousKey != nextKey) {
      final moved = merged.remove(previousKey);
      if (moved != null && moved.uses > uses) uses = moved.uses;
    }
    final existing = merged[nextKey];
    if (existing != null && existing.uses > uses) uses = existing.uses;
    merged[nextKey] = MailContact(
      name: contact.name.trim(),
      address: address,
      uses: uses,
    );
    final next = merged.values.toList()
      ..sort((a, b) {
        final byUses = b.uses.compareTo(a.uses);
        if (byUses != 0) return byUses;
        return a.label.toLowerCase().compareTo(b.label.toLowerCase());
      });
    await _write(state.copyWith(contacts: next.take(250).toList()));
  }

  Future<void> upsertSignature(MailSignature signature, {bool activate = false}) async {
    final next = [...state.signatures];
    final index = next.indexWhere((item) => item.id == signature.id);
    if (index >= 0) {
      next[index] = signature;
    } else {
      next.add(signature);
    }
    await _write(state.copyWith(
      signatures: next,
      activeSignatureId: activate || state.activeSignatureId.isEmpty ? signature.id : state.activeSignatureId,
    ));
  }

  Future<void> removeSignature(String id) async {
    final next = state.signatures.where((item) => item.id != id).toList();
    var activeId = state.activeSignatureId;
    if (activeId == id) {
      activeId = next.isEmpty ? '' : next.first.id;
    }
    await _write(state.copyWith(signatures: next, activeSignatureId: activeId));
  }

  Future<void> setActiveSignature(String id) async {
    if (!state.signatures.any((item) => item.id == id)) return;
    await _write(state.copyWith(activeSignatureId: id));
  }

  Future<void> removeContact(String address) async {
    final key = address.trim().toLowerCase();
    if (key.isEmpty) return;
    await _write(
      state.copyWith(
        contacts: state.contacts.where((item) => item.address.toLowerCase() != key).toList(),
      ),
    );
  }
}

const _logoUrl = 'https://ibelucky.com/assets/images/ibelucky_2026_logo.png';

String _withCurrentLogo(String signature) {
  var next = signature.replaceAll(
    RegExp(r'https://ibelucky\.com/assets/images/logo\.svg[^"\s]*'),
    _logoUrl,
  );
  return next.replaceAllMapped(
    RegExp(
      r'<td[^>]*border-right:\s*3px solid #4B66D8[^>]*>\s*<img[^>]*>',
      caseSensitive: false,
    ),
    (_) => _logoCell,
  );
}

const _logoCell = '''
    <td width="96" align="right" valign="middle" style="vertical-align:middle;padding:0 16px 0 0;border-right:3px solid #4B66D8;text-align:right;width:96px">
      <img src="$_logoUrl" alt="iBeLucky" width="72" style="display:block;width:72px;height:auto;margin:0 0 0 auto">''';

String _defaultSignature(String email) {
  if (email.toLowerCase() != 'eliedjani@ibelucky.com') return '';
  return '''
<table role="presentation" cellpadding="0" cellspacing="0" style="font-family:Arial,Helvetica,sans-serif;color:#111827;border-collapse:collapse;margin-top:24px">
  <tr>
$_logoCell
    </td>
    <td style="vertical-align:top;padding-left:16px">
      <div style="font-size:16px;font-weight:700;color:#060910">ILUNGA DJANI Elie</div>
      <div style="font-size:13px;color:#4B66D8;font-weight:700;margin-top:2px">Director · iBeLucky</div>
      <div style="font-size:13px;line-height:1.45;margin-top:10px">
        <a href="mailto:eliedjani@ibelucky.com" style="color:#4B66D8;text-decoration:none">eliedjani@ibelucky.com</a><br>
        <a href="tel:+243995517430" style="color:#111827;text-decoration:none">+243995517430</a>
      </div>
      <div style="font-size:12px;line-height:1.45;color:#4b5563;margin-top:10px">
        Unit A, 82 James Carter Road<br>
        Mildenhall, Bury St. Edmunds<br>
        Suffolk, IP28 7DE<br>
        United Kingdom
      </div>
    </td>
  </tr>
</table>
''';
}

final mailPreferencesProvider = StateNotifierProvider<MailPreferencesController, MailPreferences>((ref) {
  final email = ref.watch(authControllerProvider).email ?? '';
  return MailPreferencesController(ref.watch(sharedPreferencesProvider), email);
});
