import 'package:flutter/material.dart' hide Card;

/// Derives a short, uppercase monogram from a store name for cards that
/// have no bundled catalog logo (see [StoreCatalogEntry.logoAsset] in
/// data/store_catalog.dart) - e.g. "Corner Shop" -> "CS", "Costco" -> "CO".
/// Pure function of the name, so it needs no storage: it is recomputed on
/// every render and therefore applies to every card, old or new, without
/// a data migration.
///
/// Truncates by grapheme cluster (via package:characters), not UTF-16 code
/// unit, so a name starting with an emoji or a combining-mark script isn't
/// split mid-character.
String initialsFor(String storeName) {
  final words = storeName
      .trim()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();
  if (words.isEmpty) return '?';
  if (words.length == 1) {
    final chars = words.first.characters;
    return chars.take(2).toString().toUpperCase();
  }
  final first = words[0].characters.take(1).toString();
  final second = words[1].characters.take(1).toString();
  return (first + second).toUpperCase();
}

/// A generated placeholder logo shown in place of a bundled catalog logo:
/// a rounded badge with the store name's monogram, tinted to match the
/// card tile it sits on.
class GeneratedLogo extends StatelessWidget {
  final String storeName;
  final Color foreground;
  final double size;

  const GeneratedLogo({
    super.key,
    required this.storeName,
    required this.foreground,
    this.size = 32,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: foreground.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        initialsFor(storeName),
        style: TextStyle(
          color: foreground,
          fontWeight: FontWeight.bold,
          fontSize: size * 0.4,
        ),
      ),
    );
  }
}
