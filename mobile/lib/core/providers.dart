import 'package:cryptography/cryptography.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/store_catalog.dart';
import '../features/auth/auth_providers.dart';
import '../features/cards/card_repository.dart';
import '../features/settings/security_settings_store.dart';
import 'biometrics/biometric_authenticator.dart';
import 'db/daos/cards_dao.dart';
import 'db/daos/local_blobs_dao.dart';
import 'db/database.dart';

/// Riverpod provider skeleton. Providers are declared manually (no
/// code-gen / riverpod_generator, per the client design) and grow as each
/// feature is implemented.
///
/// The database is a singleton for the app's lifetime: every screen reads
/// from and writes to the same local database instance, which is what
/// makes drift's reactive streams work as a live source of truth.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final cardsDaoProvider = Provider<CardsDao>(
  (ref) => ref.watch(databaseProvider).cardsDao,
);

final localBlobsDaoProvider = Provider<LocalBlobsDao>(
  (ref) => ref.watch(databaseProvider).localBlobsDao,
);

final cardRepositoryProvider = Provider<CardRepository>(
  (ref) => CardRepository(ref.watch(cardsDaoProvider)),
);

/// The bundled store catalog (name/color/format suggestions), loaded once
/// from assets.
final storeCatalogProvider = FutureProvider<StoreCatalog>(
  (ref) => StoreCatalog.load(),
);

/// The in-memory vault key, or null while locked. Rebuilds whenever the
/// session's auth state changes (unlock/lock/logout all transition
/// [sessionControllerProvider]'s state alongside the key itself), then
/// reads the current key straight off the holder.
final vaultKeyProvider = Provider<SecretKey?>((ref) {
  ref.watch(sessionControllerProvider);
  return ref.watch(sessionControllerProvider.notifier).vaultKeyHolder.keyOrNull;
});

final securitySettingsStoreProvider = Provider<SecuritySettingsStore>(
  (ref) => SecuritySettingsStore(),
);

final biometricAuthenticatorProvider = Provider<BiometricAuthenticator>(
  (ref) => LocalAuthBiometricAuthenticator(),
);
