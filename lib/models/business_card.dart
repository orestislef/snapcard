import 'dart:convert';

/// A single phone number with a coarse, contact-friendly label.
class PhoneEntry {
  PhoneEntry({required this.label, required this.number});

  /// One of [BusinessCard.phoneLabels].
  String label;
  String number;

  Map<String, dynamic> toJson() => {'label': label, 'number': number};

  factory PhoneEntry.fromJson(Map<String, dynamic> j) => PhoneEntry(
        label: (j['label'] as String?) ?? 'other',
        number: (j['number'] as String?) ?? '',
      );
}

/// A single email address with a coarse label.
class EmailEntry {
  EmailEntry({required this.label, required this.address});

  /// One of [BusinessCard.emailLabels].
  String label;
  String address;

  Map<String, dynamic> toJson() => {'label': label, 'address': address};

  factory EmailEntry.fromJson(Map<String, dynamic> j) => EmailEntry(
        label: (j['label'] as String?) ?? 'other',
        address: (j['address'] as String?) ?? '',
      );
}

/// The parsed contents of one business card.
///
/// Doubles as the in-app history record: it carries an [id], the [scannedAt]
/// time and whether it has already been [addedToContacts].
class BusinessCard {
  BusinessCard({
    String? id,
    DateTime? scannedAt,
    this.addedToContacts = false,
    this.fullName,
    this.firstName,
    this.lastName,
    this.jobTitle,
    this.company,
    List<PhoneEntry>? phones,
    List<EmailEntry>? emails,
    List<String>? websites,
    this.address,
    this.notes,
  })  : id = id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        scannedAt = scannedAt ?? DateTime.now(),
        phones = phones ?? [],
        emails = emails ?? [],
        websites = websites ?? [];

  final String id;
  final DateTime scannedAt;
  bool addedToContacts;

  String? fullName;
  String? firstName;
  String? lastName;
  String? jobTitle;
  String? company;
  List<PhoneEntry> phones;
  List<EmailEntry> emails;
  List<String> websites;
  String? address;
  String? notes;

  static const List<String> phoneLabels = [
    'mobile',
    'work',
    'home',
    'fax',
    'other',
  ];
  static const List<String> emailLabels = ['work', 'personal', 'other'];

  /// True when the parse produced essentially nothing usable — used to detect a
  /// failed/blurry scan and prompt the user to retry.
  bool get isEmpty =>
      (fullName == null || fullName!.trim().isEmpty) &&
      (firstName == null || firstName!.trim().isEmpty) &&
      (lastName == null || lastName!.trim().isEmpty) &&
      (company == null || company!.trim().isEmpty) &&
      phones.every((p) => p.number.trim().isEmpty) &&
      emails.every((e) => e.address.trim().isEmpty) &&
      websites.every((w) => w.trim().isEmpty);

  /// A short, human label for history lists.
  String get displayTitle {
    final name = (fullName?.trim().isNotEmpty ?? false)
        ? fullName!.trim()
        : [firstName, lastName]
            .where((s) => s != null && s.trim().isNotEmpty)
            .join(' ')
            .trim();
    if (name.isNotEmpty) return name;
    if (company?.trim().isNotEmpty ?? false) return company!.trim();
    if (emails.any((e) => e.address.trim().isNotEmpty)) {
      return emails.firstWhere((e) => e.address.trim().isNotEmpty).address;
    }
    return 'Untitled card';
  }

  String get displaySubtitle {
    final parts = <String>[];
    if (jobTitle?.trim().isNotEmpty ?? false) parts.add(jobTitle!.trim());
    if (company?.trim().isNotEmpty ?? false) parts.add(company!.trim());
    return parts.join(' · ');
  }

  // ---- Gemma JSON (the model's raw output) -------------------------------

  /// Tolerant parser for the JSON shape requested in the extraction prompt.
  /// Accepts missing/null fields and a few shape variations without throwing.
  factory BusinessCard.fromGemmaJson(Map<String, dynamic> j) {
    String? s(dynamic v) {
      if (v == null) return null;
      final str = v is String ? v : v.toString();
      final t = str.trim();
      return t.isEmpty || t.toLowerCase() == 'null' ? null : t;
    }

    final phones = <PhoneEntry>[];
    final rawPhones = j['phones'];
    if (rawPhones is List) {
      for (final p in rawPhones) {
        if (p is Map) {
          final num = s(p['number'] ?? p['phone'] ?? p['value']);
          if (num == null) continue;
          var label = (s(p['label']) ?? 'other').toLowerCase();
          if (!phoneLabels.contains(label)) {
            if (label.startsWith('cell') || label.startsWith('mob')) {
              label = 'mobile';
            } else if (label.startsWith('tel') ||
                label.startsWith('off') ||
                label == 'tel') {
              label = 'work';
            } else if (label.contains('fax')) {
              label = 'fax';
            } else {
              label = 'other';
            }
          }
          phones.add(PhoneEntry(label: label, number: num));
        } else if (p != null) {
          final num = s(p);
          if (num != null) phones.add(PhoneEntry(label: 'other', number: num));
        }
      }
    }

    final emails = <EmailEntry>[];
    final rawEmails = j['emails'];
    if (rawEmails is List) {
      for (final e in rawEmails) {
        if (e is Map) {
          final addr = s(e['address'] ?? e['email'] ?? e['value']);
          if (addr == null) continue;
          var label = (s(e['label']) ?? 'other').toLowerCase();
          if (!emailLabels.contains(label)) {
            label = label.startsWith('work') ? 'work' : 'other';
          }
          emails.add(EmailEntry(label: label, address: addr));
        } else if (e != null) {
          final addr = s(e);
          if (addr != null) {
            emails.add(EmailEntry(label: 'other', address: addr));
          }
        }
      }
    }

    final websites = <String>[];
    final rawSites = j['websites'] ?? j['website'];
    if (rawSites is List) {
      for (final w in rawSites) {
        final url = w is Map ? s(w['url'] ?? w['value']) : s(w);
        if (url != null) websites.add(url);
      }
    } else {
      final single = s(rawSites);
      if (single != null) websites.add(single);
    }

    return BusinessCard(
      fullName: s(j['fullName'] ?? j['name']),
      firstName: s(j['firstName']),
      lastName: s(j['lastName']),
      jobTitle: s(j['jobTitle'] ?? j['title']),
      company: s(j['company'] ?? j['organization']),
      phones: phones,
      emails: emails,
      websites: websites,
      address: s(j['address']),
      notes: s(j['notes']),
    );
  }

  // ---- Persistence (history) --------------------------------------------

  Map<String, dynamic> toJson() => {
        'id': id,
        'scannedAt': scannedAt.toIso8601String(),
        'addedToContacts': addedToContacts,
        'fullName': fullName,
        'firstName': firstName,
        'lastName': lastName,
        'jobTitle': jobTitle,
        'company': company,
        'phones': phones.map((p) => p.toJson()).toList(),
        'emails': emails.map((e) => e.toJson()).toList(),
        'websites': websites,
        'address': address,
        'notes': notes,
      };

  factory BusinessCard.fromJson(Map<String, dynamic> j) => BusinessCard(
        id: j['id'] as String?,
        scannedAt: DateTime.tryParse((j['scannedAt'] as String?) ?? ''),
        addedToContacts: (j['addedToContacts'] as bool?) ?? false,
        fullName: j['fullName'] as String?,
        firstName: j['firstName'] as String?,
        lastName: j['lastName'] as String?,
        jobTitle: j['jobTitle'] as String?,
        company: j['company'] as String?,
        phones: ((j['phones'] as List?) ?? [])
            .map((e) => PhoneEntry.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        emails: ((j['emails'] as List?) ?? [])
            .map((e) => EmailEntry.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        websites: ((j['websites'] as List?) ?? [])
            .map((e) => e.toString())
            .toList(),
        address: j['address'] as String?,
        notes: j['notes'] as String?,
      );

  String encode() => jsonEncode(toJson());
}
