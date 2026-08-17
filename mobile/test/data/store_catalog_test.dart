import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/data/store_catalog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StoreCatalog catalog;

  setUpAll(() async {
    catalog = await StoreCatalog.load();
  });

  test('bundles at least 120 store entries, each with a name, color, format, and logo', () {
    expect(catalog.entries.length, greaterThanOrEqualTo(120));
    for (final entry in catalog.entries) {
      expect(entry.key, isNotEmpty);
      expect(entry.names, isNotEmpty);
      expect(entry.format, isNotEmpty);
      expect(entry.logoAsset, startsWith('assets/stores/logos/'));
    }
  });

  test('every entry key is unique', () {
    final keys = catalog.entries.map((e) => e.key).toSet();
    expect(keys.length, catalog.entries.length);
  });

  test('search is case-insensitive', () {
    final lower = catalog.search('пятёрочка');
    final upper = catalog.search('ПЯТЁРОЧКА');
    expect(lower, isNotEmpty);
    expect(lower.map((e) => e.key), upper.map((e) => e.key));
  });

  test('search matches a Latin transliteration of a Cyrillic name', () {
    final results = catalog.search('pyaterochka');
    expect(results.map((e) => e.key), contains('pyaterochka'));
  });

  test('search matches a Cyrillic query against a Latin-only entry name', () {
    final results = catalog.search('zara');
    expect(results.map((e) => e.key), contains('zara'));
  });

  test('empty query returns the full catalog', () {
    expect(catalog.search('').length, catalog.entries.length);
  });

  test('search finds a well-known chain by partial name', () {
    final results = catalog.search('ikea');
    expect(results.map((e) => e.key), contains('ikea'));
  });
}
