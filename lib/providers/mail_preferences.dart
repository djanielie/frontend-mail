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
    if (raw == null || raw.isEmpty) return const MailPreferences();
    try {
      return MailPreferences.fromJson(jsonDecode(raw));
    } catch (_) {
      return const MailPreferences();
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

final mailPreferencesProvider = StateNotifierProvider<MailPreferencesController, MailPreferences>((ref) {
  final email = ref.watch(authControllerProvider).email ?? '';
  return MailPreferencesController(ref.watch(sharedPreferencesProvider), email);
});
