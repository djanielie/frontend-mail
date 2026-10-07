import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/mail_models.dart';
import 'auth_controller.dart';

class MailContact {
  const MailContact({required this.name, required this.address});

  final String name;
  final String address;

  String get label {
    if (name.isEmpty) return address;
    if (address.isEmpty) return name;
    return '$name <$address>';
  }

  Map<String, String> toJson() => {'name': name, 'address': address};

  static MailContact? fromJson(Object? json) {
    if (json is! Map) return null;
    final address = json['address']?.toString() ?? '';
    if (address.isEmpty) return null;
    return MailContact(name: json['name']?.toString() ?? '', address: address);
  }

  static MailContact? fromAddress(MailAddress? address) {
    if (address == null || address.address.isEmpty) return null;
    return MailContact(name: address.name, address: address.address);
  }
}

class MailPreferences {
  const MailPreferences({
    this.signature = '',
    this.displayName = '',
    this.color = 0xFF7B93FF,
    this.density = 'comfortable',
    this.sentFolder = '',
    this.draftsFolder = '',
    this.contacts = const [],
    this.pollMinutes = 2,
  });

  final String signature;
  final String displayName;
  final int color;
  final String density;
  final String sentFolder;
  final String draftsFolder;
  final List<MailContact> contacts;
  final int pollMinutes;

  bool get compact => density == 'compact';
  Color get accountColor => Color(color);

  MailPreferences copyWith({
    String? signature,
    String? displayName,
    int? color,
    String? density,
    String? sentFolder,
    String? draftsFolder,
    List<MailContact>? contacts,
    int? pollMinutes,
  }) {
    return MailPreferences(
      signature: signature ?? this.signature,
      displayName: displayName ?? this.displayName,
      color: color ?? this.color,
      density: density ?? this.density,
      sentFolder: sentFolder ?? this.sentFolder,
      draftsFolder: draftsFolder ?? this.draftsFolder,
      contacts: contacts ?? this.contacts,
      pollMinutes: pollMinutes ?? this.pollMinutes,
    );
  }

  Map<String, Object> toJson() => {
        'signature': signature,
        'displayName': displayName,
        'color': color,
        'density': density,
        'sentFolder': sentFolder,
        'draftsFolder': draftsFolder,
        'pollMinutes': pollMinutes,
        'contacts': contacts.map((item) => item.toJson()).toList(),
      };

  static MailPreferences fromJson(Object? json) {
    if (json is! Map) return const MailPreferences();
    final contacts = json['contacts'] is List ? json['contacts'] as List : const [];
    return MailPreferences(
      signature: json['signature']?.toString() ?? '',
      displayName: json['displayName']?.toString() ?? '',
      color: json['color'] is num ? (json['color'] as num).toInt() : 0xFF7B93FF,
      density: json['density'] == 'compact' ? 'compact' : 'comfortable',
      sentFolder: json['sentFolder']?.toString() ?? '',
      draftsFolder: json['draftsFolder']?.toString() ?? '',
      pollMinutes: json['pollMinutes'] is num ? (json['pollMinutes'] as num).toInt().clamp(1, 30) : 2,
      contacts: contacts.map(MailContact.fromJson).whereType<MailContact>().toList(),
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
    if (raw == null || raw.isEmpty) return MailPreferences(signature: _defaultSignature(email));
    try {
      final parsed = MailPreferences.fromJson(jsonDecode(raw));
      if (parsed.signature.trim().isEmpty) {
        return parsed.copyWith(signature: _defaultSignature(email));
      }
      return parsed;
    } catch (_) {
      return MailPreferences(signature: _defaultSignature(email));
    }
  }

  Future<void> _write(MailPreferences next) async {
    state = next;
    if (_email.isEmpty) return;
    await _prefs.setString(_key(_email), jsonEncode(next.toJson()));
  }

  Future<void> update(MailPreferences next) => _write(next);

  Future<void> addContacts(Iterable<MailContact?> contacts) async {
    final merged = <String, MailContact>{
      for (final contact in state.contacts) contact.address.toLowerCase(): contact,
    };
    for (final contact in contacts.whereType<MailContact>()) {
      merged[contact.address.toLowerCase()] = contact;
    }
    final next = merged.values.take(250).toList()
      ..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
    await _write(state.copyWith(contacts: next));
  }
}

String _defaultSignature(String email) {
  if (email.toLowerCase() != 'eliedjani@ibelucky.com') return '';
  return '''
<table role="presentation" cellpadding="0" cellspacing="0" style="font-family:Arial,Helvetica,sans-serif;color:#111827;border-collapse:collapse;margin-top:24px">
  <tr>
    <td style="vertical-align:top;padding-right:16px;border-right:3px solid #4B66D8">
      <img src="https://ibelucky.com/assets/images/logo.svg?v=1787574648" alt="iBeLucky" width="72" style="display:block;width:72px;height:auto">
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
