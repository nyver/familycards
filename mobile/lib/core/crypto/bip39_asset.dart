import 'package:flutter/services.dart';

import 'recovery_phrase.dart';

/// Loads the bundled BIP-39 English wordlist via the Flutter asset
/// bundle. Split out from recovery_phrase.dart so that file stays pure
/// Dart (no Flutter framework dependency) and unit-testable without
/// initializing widget test bindings.
Future<List<String>> loadBip39WordlistFromAssets() {
  return loadBip39Wordlist(
    () => rootBundle.loadString('assets/bip39/english.txt'),
  );
}
