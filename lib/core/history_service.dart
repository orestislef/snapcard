import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/business_card.dart';

/// In-app history of scanned cards, persisted as a JSON list in
/// `shared_preferences`. Nothing here ever leaves the device.
class HistoryService {
  static const String _key = 'scan_history';

  /// All saved cards, newest first.
  Future<List<BusinessCard>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      final cards = list
          .map((e) => BusinessCard.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      cards.sort((a, b) => b.scannedAt.compareTo(a.scannedAt));
      return cards;
    } catch (_) {
      return [];
    }
  }

  Future<void> _save(List<BusinessCard> cards) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(cards.map((c) => c.toJson()).toList()),
    );
  }

  /// Inserts a new card or replaces the existing one with the same id.
  Future<void> upsert(BusinessCard card) async {
    final cards = await load();
    final idx = cards.indexWhere((c) => c.id == card.id);
    if (idx >= 0) {
      cards[idx] = card;
    } else {
      cards.add(card);
    }
    await _save(cards);
  }

  Future<void> delete(String id) async {
    final cards = await load();
    cards.removeWhere((c) => c.id == id);
    await _save(cards);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
