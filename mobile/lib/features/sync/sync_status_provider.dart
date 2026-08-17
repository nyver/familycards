import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../auth/auth_providers.dart';
import '../auth/auth_state.dart';
import 'sync_service.dart';

/// Builds and owns the [SyncController] for the current authenticated
/// session. `autoDispose` so it is torn down (timers cancelled, stream
/// subscriptions closed) as soon as nothing watches it anymore - in
/// practice, that is exactly the lifetime of the authenticated shell that
/// hosts the card list (see app.dart's `_AuthenticatedShell`).
final syncControllerProvider =
    StateNotifierProvider.autoDispose<SyncController, SyncStatus>((ref) {
      final authState = ref.watch(sessionControllerProvider);
      final identity = switch (authState) {
        AuthReady(:final identity) => identity,
        _ => throw StateError(
          'syncControllerProvider read while not authenticated',
        ),
      };
      final session = ref.watch(sessionControllerProvider.notifier);
      // AuthReady is only ever entered with the vault key already unlocked -
      // see SessionController._completeSession / unlockWithPassword and the
      // background-lock timeout, which always routes back through
      // AuthNeedsUnlock before the key is cleared (see SessionController's
      // background/foreground handling).
      final vaultKey = ref.watch(vaultKeyProvider)!;
      final db = ref.watch(databaseProvider);

      final controller = SyncController(
        api: session.apiClient,
        cardsDao: db.cardsDao,
        blobsDao: db.localBlobsDao,
        syncStateDao: db.syncStateDao,
        vaultKey: vaultKey,
        deviceId: identity.deviceId,
      );
      ref.onDispose(controller.dispose);
      return controller;
    });

/// Compact, non-blocking sync status indicator: an icon plus a short
/// label. Never a spinner overlaying the card list - see "не показывать
/// блокирующих индикаторов загрузки поверх списка карт".
class SyncStatusIndicator extends ConsumerWidget {
  const SyncStatusIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(syncControllerProvider);
    final l10n = AppLocalizations.of(context)!;

    final (icon, label) = switch (status) {
      SyncStatus(phase: SyncPhase.syncing) => (
        Icons.sync,
        l10n.syncStatusSyncing,
      ),
      SyncStatus(phase: SyncPhase.error) => (
        Icons.sync_problem_outlined,
        l10n.syncStatusError,
      ),
      SyncStatus(pendingCount: > 0) => (
        Icons.cloud_upload_outlined,
        l10n.syncStatusPendingChanges(status.pendingCount),
      ),
      _ => (Icons.cloud_done_outlined, l10n.syncStatusIdle),
    };

    return Tooltip(
      message: label,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 4),
            Text(label, style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ),
    );
  }
}
