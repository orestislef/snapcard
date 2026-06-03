import 'package:flutter_contacts/flutter_contacts.dart';

import '../models/business_card.dart';

/// Writes a reviewed [BusinessCard] into the device address book via
/// `flutter_contacts`. All fields the card carries are mapped through — name,
/// org/title, every phone (with its type), emails, websites, address, notes.
class ContactService {
  /// Requests read+write contacts access. Returns true if usable.
  Future<bool> ensurePermission() async {
    final status =
        await FlutterContacts.permissions.request(PermissionType.readWrite);
    return status == PermissionStatus.granted ||
        status == PermissionStatus.limited;
  }

  Future<PermissionStatus> permissionStatus() =>
      FlutterContacts.permissions.check(PermissionType.readWrite);

  /// True when the user blocked contacts access for good — the only fix is the
  /// system settings page.
  Future<bool> isPermanentlyDenied() async {
    final s = await permissionStatus();
    return s == PermissionStatus.permanentlyDenied ||
        s == PermissionStatus.restricted;
  }

  Future<void> openSettings() => FlutterContacts.permissions.openSettings();

  /// Creates a new device contact from [card]. Returns the new contact id.
  Future<String> save(BusinessCard card) async {
    // Name: prefer explicit first/last; fall back to splitting fullName.
    var first = card.firstName?.trim() ?? '';
    var last = card.lastName?.trim() ?? '';
    if (first.isEmpty && last.isEmpty && (card.fullName?.trim().isNotEmpty ?? false)) {
      final parts = card.fullName!.trim().split(RegExp(r'\s+'));
      first = parts.first;
      if (parts.length > 1) last = parts.sublist(1).join(' ');
    }

    final organizations = <Organization>[];
    if ((card.company?.trim().isNotEmpty ?? false) ||
        (card.jobTitle?.trim().isNotEmpty ?? false)) {
      organizations.add(Organization(
        name: card.company?.trim(),
        jobTitle: card.jobTitle?.trim(),
      ));
    }

    final contact = Contact(
      name: Name(first: first, last: last),
      organizations: organizations,
      phones: card.phones
          .where((p) => p.number.trim().isNotEmpty)
          .map((p) => Phone(number: p.number.trim(), label: Label(_phoneLabel(p.label))))
          .toList(),
      emails: card.emails
          .where((e) => e.address.trim().isNotEmpty)
          .map((e) => Email(address: e.address.trim(), label: Label(_emailLabel(e.label))))
          .toList(),
      websites: card.websites
          .where((w) => w.trim().isNotEmpty)
          .map((w) => Website(url: w.trim(), label: const Label(WebsiteLabel.homepage)))
          .toList(),
      addresses: (card.address?.trim().isNotEmpty ?? false)
          ? [Address(formatted: card.address!.trim(), label: const Label(AddressLabel.work))]
          : const [],
      notes: (card.notes?.trim().isNotEmpty ?? false)
          ? [Note(note: card.notes!.trim())]
          : const [],
    );

    return FlutterContacts.create(contact);
  }

  PhoneLabel _phoneLabel(String label) {
    switch (label) {
      case 'mobile':
        return PhoneLabel.mobile;
      case 'work':
        return PhoneLabel.work;
      case 'home':
        return PhoneLabel.home;
      case 'fax':
        return PhoneLabel.workFax;
      default:
        return PhoneLabel.other;
    }
  }

  EmailLabel _emailLabel(String label) {
    switch (label) {
      case 'work':
        return EmailLabel.work;
      case 'personal':
        return EmailLabel.home;
      default:
        return EmailLabel.other;
    }
  }
}
