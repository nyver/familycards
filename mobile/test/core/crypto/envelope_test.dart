import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/crypto/envelope.dart';

void main() {
  group('item encryption', () {
    test('round-trips plaintext through encrypt and decrypt', () async {
      final vk = await Xchacha20.poly1305Aead().newSecretKey();
      final plaintext = utf8.encode('{"store_name":"Test"}');

      final envelope = await encryptItem(
        itemId: 'item-1',
        canonicalPayload: plaintext,
        vaultKey: vk,
      );
      final decrypted = await decryptItem(
        itemId: 'item-1',
        envelope: envelope,
        vaultKey: vk,
      );

      expect(decrypted, equals(plaintext));
    });

    test('two encryptions of the same plaintext use different nonces and ciphertexts', () async {
      final vk = await Xchacha20.poly1305Aead().newSecretKey();
      final plaintext = utf8.encode('same content');

      final e1 = await encryptItem(
        itemId: 'item-1',
        canonicalPayload: plaintext,
        vaultKey: vk,
      );
      final e2 = await encryptItem(
        itemId: 'item-1',
        canonicalPayload: plaintext,
        vaultKey: vk,
      );

      expect(e1.nonce, isNot(equals(e2.nonce)));
      expect(e1.ciphertext, isNot(equals(e2.ciphertext)));
    });

    test('decryption fails when item_id in the AAD does not match', () async {
      final vk = await Xchacha20.poly1305Aead().newSecretKey();
      final plaintext = utf8.encode('secret card data');
      final envelope = await encryptItem(
        itemId: 'item-1',
        canonicalPayload: plaintext,
        vaultKey: vk,
      );

      await expectLater(
        decryptItem(itemId: 'item-2', envelope: envelope, vaultKey: vk),
        throwsA(isA<DecryptionFailedException>()),
      );
    });

    test('decryption fails with the wrong vault key', () async {
      final vk1 = await Xchacha20.poly1305Aead().newSecretKey();
      final vk2 = await Xchacha20.poly1305Aead().newSecretKey();
      final plaintext = utf8.encode('secret card data');
      final envelope = await encryptItem(
        itemId: 'item-1',
        canonicalPayload: plaintext,
        vaultKey: vk1,
      );

      await expectLater(
        decryptItem(itemId: 'item-1', envelope: envelope, vaultKey: vk2),
        throwsA(isA<DecryptionFailedException>()),
      );
    });

    test('decryption fails when the ciphertext is tampered with', () async {
      final vk = await Xchacha20.poly1305Aead().newSecretKey();
      final plaintext = utf8.encode('secret card data');
      final envelope = await encryptItem(
        itemId: 'item-1',
        canonicalPayload: plaintext,
        vaultKey: vk,
      );

      final tampered = Uint8List.fromList(envelope.ciphertext);
      tampered[0] ^= 0xFF;
      final tamperedEnvelope = Envelope(
        nonce: envelope.nonce,
        ciphertext: tampered,
      );

      await expectLater(
        decryptItem(itemId: 'item-1', envelope: tamperedEnvelope, vaultKey: vk),
        throwsA(isA<DecryptionFailedException>()),
      );
    });
  });

  group('blob encryption', () {
    test('round-trips image bytes through encrypt and decrypt', () async {
      final vk = await Xchacha20.poly1305Aead().newSecretKey();
      final imageBytes = List.generate(1000, (i) => i % 256);

      final result = await encryptBlob(imageBytes: imageBytes, vaultKey: vk);
      final decrypted = await decryptBlob(
        uploadBytes: result.uploadBytes,
        vaultKey: vk,
      );

      expect(decrypted, equals(imageBytes));
    });

    test('blob_id equals the sha256 of the exact uploaded bytes', () async {
      final vk = await Xchacha20.poly1305Aead().newSecretKey();
      final imageBytes = [1, 2, 3, 4, 5];

      final result = await encryptBlob(imageBytes: imageBytes, vaultKey: vk);
      final digest = await Sha256().hash(result.uploadBytes);
      final expectedId = digest.bytes
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();

      expect(result.blobId, expectedId);
    });

    test('re-encrypting the same image produces a different blob_id (random nonce)', () async {
      final vk = await Xchacha20.poly1305Aead().newSecretKey();
      final imageBytes = [9, 9, 9];

      final r1 = await encryptBlob(imageBytes: imageBytes, vaultKey: vk);
      final r2 = await encryptBlob(imageBytes: imageBytes, vaultKey: vk);

      expect(r1.blobId, isNot(equals(r2.blobId)));
    });

    test('decryption fails with the wrong vault key', () async {
      final vk1 = await Xchacha20.poly1305Aead().newSecretKey();
      final vk2 = await Xchacha20.poly1305Aead().newSecretKey();
      final result = await encryptBlob(imageBytes: [1, 2, 3], vaultKey: vk1);

      await expectLater(
        decryptBlob(uploadBytes: result.uploadBytes, vaultKey: vk2),
        throwsA(isA<DecryptionFailedException>()),
      );
    });
  });

  group('key wrapping', () {
    test('round-trips a vault key through wrap and unwrap', () async {
      final kek = await Xchacha20.poly1305Aead().newSecretKey();
      final vk = Uint8List.fromList(List.generate(32, (i) => i));

      final envelope = await wrapVaultKey(
        vaultKey: vk,
        keyEncryptionKey: kek,
        aad: AadTags.vkWrap,
      );
      final unwrapped = await unwrapVaultKey(
        envelope: envelope,
        keyEncryptionKey: kek,
        aad: AadTags.vkWrap,
      );

      expect(unwrapped, equals(vk));
    });

    test('unwrap fails with a key derived from the wrong password (simulated by a different KEK)', () async {
      final correctKek = await Xchacha20.poly1305Aead().newSecretKey();
      final wrongKek = await Xchacha20.poly1305Aead().newSecretKey();
      final vk = Uint8List.fromList(List.generate(32, (i) => i));

      final envelope = await wrapVaultKey(
        vaultKey: vk,
        keyEncryptionKey: correctKek,
        aad: AadTags.vkWrap,
      );

      await expectLater(
        unwrapVaultKey(
          envelope: envelope,
          keyEncryptionKey: wrongKek,
          aad: AadTags.vkWrap,
        ),
        throwsA(isA<DecryptionFailedException>()),
      );
    });

    test('unwrap fails when the envelope is corrupted', () async {
      final kek = await Xchacha20.poly1305Aead().newSecretKey();
      final vk = Uint8List.fromList(List.generate(32, (i) => i));
      final envelope = await wrapVaultKey(
        vaultKey: vk,
        keyEncryptionKey: kek,
        aad: AadTags.vkWrap,
      );

      final corrupted = Envelope(
        nonce: envelope.nonce,
        ciphertext: Uint8List.fromList([...envelope.ciphertext]..[0] ^= 0xFF),
      );

      await expectLater(
        unwrapVaultKey(
          envelope: corrupted,
          keyEncryptionKey: kek,
          aad: AadTags.vkWrap,
        ),
        throwsA(isA<DecryptionFailedException>()),
      );
    });

    test('a wrap tagged for one purpose cannot be unwrapped under another purpose tag', () async {
      final kek = await Xchacha20.poly1305Aead().newSecretKey();
      final vk = Uint8List.fromList(List.generate(32, (i) => i));

      final envelope = await wrapVaultKey(
        vaultKey: vk,
        keyEncryptionKey: kek,
        aad: AadTags.vkWrap,
      );

      await expectLater(
        unwrapVaultKey(
          envelope: envelope,
          keyEncryptionKey: kek,
          aad: AadTags.invite,
        ),
        throwsA(isA<DecryptionFailedException>()),
      );
    });
  });
}
