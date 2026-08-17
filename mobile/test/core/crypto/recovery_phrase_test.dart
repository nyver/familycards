import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/crypto/recovery_phrase.dart';

Future<List<String>> _loadRealWordlist() async {
  final file = File('assets/bip39/english.txt');
  final content = await file.readAsString();
  return content
      .split('\n')
      .map((w) => w.trim())
      .where((w) => w.isNotEmpty)
      .toList();
}

void main() {
  late List<String> wordlist;

  setUpAll(() async {
    wordlist = await _loadRealWordlist();
  });

  test('the bundled wordlist has exactly 2048 unique words', () {
    expect(wordlist.length, 2048);
    expect(
      wordlist.toSet().length,
      2048,
      reason: 'wordlist must not contain duplicates',
    );
  });

  test(
    'generates a 12-word phrase where every word is in the dictionary',
    () async {
      final phrase = await RecoveryPhrase.generate(wordlist);
      expect(phrase, hasLength(12));
      for (final word in phrase) {
        expect(wordlist, contains(word));
      }
    },
  );

  test('a freshly generated phrase always validates', () async {
    final phrase = await RecoveryPhrase.generate(wordlist);
    final valid = await RecoveryPhrase.validate(phrase, wordlist);
    expect(valid, isTrue);
  });

  test('two generated phrases are (almost certainly) different', () async {
    final a = await RecoveryPhrase.generate(wordlist);
    final b = await RecoveryPhrase.generate(wordlist);
    expect(a, isNot(equals(b)));
  });

  test('rejects a phrase containing a word outside the dictionary', () async {
    final phrase = await RecoveryPhrase.generate(wordlist);
    final tampered = [...phrase.sublist(0, 11), 'not-a-real-bip39-word'];
    final valid = await RecoveryPhrase.validate(tampered, wordlist);
    expect(valid, isFalse);
  });

  test(
    'rejects a phrase with a valid-looking but incorrect checksum',
    () async {
      final phrase = await RecoveryPhrase.generate(wordlist);
      // Swap the last word for a different in-dictionary word, which will
      // almost certainly break the checksum even though every word is
      // individually valid.
      final lastIndex = wordlist.indexOf(phrase.last);
      final replacement = wordlist[(lastIndex + 1) % wordlist.length];
      final tampered = [...phrase.sublist(0, 11), replacement];

      final valid = await RecoveryPhrase.validate(tampered, wordlist);
      expect(valid, isFalse);
    },
  );

  test('rejects a phrase with the wrong word count', () async {
    final phrase = await RecoveryPhrase.generate(wordlist);
    final tooShort = phrase.sublist(0, 11);
    expect(await RecoveryPhrase.validate(tooShort, wordlist), isFalse);
  });

  test('validation is case-insensitive and trims whitespace', () async {
    final phrase = await RecoveryPhrase.generate(wordlist);
    final messy = phrase.map((w) => ' ${w.toUpperCase()} ').toList();
    expect(await RecoveryPhrase.validate(messy, wordlist), isTrue);
  });

  test('toKdfInput normalizes to lowercase, single-spaced words', () {
    final input = RecoveryPhrase.toKdfInput([' Abandon ', 'ABILITY', 'able']);
    expect(input, 'abandon ability able');
  });

  test('generate throws if given a wordlist of the wrong length', () async {
    expect(
      () => RecoveryPhrase.generate(['only', 'a', 'few', 'words']),
      throwsA(isA<ArgumentError>()),
    );
  });
}
