import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/crypto/bip39_asset.dart';
import '../../core/providers.dart';
import 'auth_state.dart';
import 'session_controller.dart';

final sessionControllerProvider =
    StateNotifierProvider<SessionController, AuthState>((ref) {
      final database = ref.watch(databaseProvider);
      return SessionController(database: database);
    });

/// The BIP-39 wordlist, loaded once from assets and reused for both
/// recovery phrase generation (new vault) and validation (recovery).
final bip39WordlistProvider = FutureProvider<List<String>>(
  (ref) => loadBip39WordlistFromAssets(),
);
