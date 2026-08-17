import 'dart:convert';
import 'dart:ui' show Color;

import 'package:flutter/services.dart' show rootBundle;

/// A known retail chain suggestion for the card editor's store-name
/// autocomplete: a canonical [key], the display/search name variants,
/// a brand [color], a default barcode [format], and a generated logo
/// asset path (see scripts/gen-logos.py - never a downloaded third-party
/// logo, per FamilyCards_SQLite_Master_Prompt.md §8).
class StoreCatalogEntry {
  final String key;
  final List<String> names;
  final Color color;
  final String format;
  final String logoAsset;

  const StoreCatalogEntry({
    required this.key,
    required this.names,
    required this.color,
    required this.format,
    required this.logoAsset,
  });

  String get displayName => names.first;

  factory StoreCatalogEntry.fromJson(Map<String, dynamic> json) {
    return StoreCatalogEntry(
      key: json['key'] as String,
      names: (json['names'] as List<dynamic>).cast<String>(),
      color: Color(
        int.parse((json['color'] as String).substring(1), radix: 16) |
            0xFF000000,
      ),
      format: json['format'] as String,
      logoAsset: 'assets/stores/logos/${json['logo'] as String}',
    );
  }
}

/// Loads and searches the bundled store catalog (assets/stores/catalog.json).
/// Search is case-insensitive and transliteration-aware, so typing either
/// a Cyrillic or a Latin transliteration of a chain's name finds it.
class StoreCatalog {
  final List<StoreCatalogEntry> entries;
  StoreCatalog._(this.entries);

  static StoreCatalog? _cached;

  static Future<StoreCatalog> load() async {
    final cached = _cached;
    if (cached != null) return cached;
    final raw = await rootBundle.loadString('assets/stores/catalog.json');
    final list = (jsonDecode(raw) as List<dynamic>)
        .map((e) => StoreCatalogEntry.fromJson(e as Map<String, dynamic>))
        .toList(growable: false);
    final catalog = StoreCatalog._(list);
    _cached = catalog;
    return catalog;
  }

  /// Returns entries whose canonical key or any name variant (compared in
  /// both original and transliterated form) contains [query].
  List<StoreCatalogEntry> search(String query) {
    final needle = _normalize(query);
    if (needle.isEmpty) return entries;
    return entries
        .where((entry) {
          for (final name in entry.names) {
            final normalized = _normalize(name);
            if (normalized.contains(needle)) return true;
            if (_transliterate(normalized).contains(needle)) return true;
            if (normalized.contains(_transliterate(needle))) return true;
          }
          return false;
        })
        .toList(growable: false);
  }

  static String _normalize(String s) => s.toLowerCase().trim();
}

const Map<String, String> _cyrillicToLatin = {
  'а': 'a',
  'б': 'b',
  'в': 'v',
  'г': 'g',
  'д': 'd',
  'е': 'e',
  'ё': 'e',
  'ж': 'zh',
  'з': 'z',
  'и': 'i',
  'й': 'y',
  'к': 'k',
  'л': 'l',
  'м': 'm',
  'н': 'n',
  'о': 'o',
  'п': 'p',
  'р': 'r',
  'с': 's',
  'т': 't',
  'у': 'u',
  'ф': 'f',
  'х': 'h',
  'ц': 'ts',
  'ч': 'ch',
  'ш': 'sh',
  'щ': 'sch',
  'ъ': '',
  'ы': 'y',
  'ь': '',
  'э': 'e',
  'ю': 'yu',
  'я': 'ya',
};

/// Best-effort Cyrillic-to-Latin transliteration used only to widen search
/// matching, not for display.
String _transliterate(String s) {
  final buffer = StringBuffer();
  for (final rune in s.runes) {
    final char = String.fromCharCode(rune);
    buffer.write(_cyrillicToLatin[char] ?? char);
  }
  return buffer.toString();
}
