/// Deterministic last-writer-wins conflict resolution, mirroring
/// `server/internal/sync/resolve.go` exactly. Both sides must resolve
/// every case identically, or two offline devices will never converge to
/// the same state - see `testdata/lww_vectors.json` at the repo root for
/// the shared fixture both are tested against.
library;

/// The already-accepted state of an item, as seen by whoever is deciding
/// whether to accept a competing write. [exists] is false when there is no
/// record of the item at all.
class CurrentItemState {
  final bool exists;
  final int rev;
  final int updatedAt;
  final String deviceId;

  const CurrentItemState({
    required this.exists,
    this.rev = 0,
    this.updatedAt = 0,
    this.deviceId = '',
  });
}

/// A candidate write competing to replace [CurrentItemState].
class IncomingItemState {
  final int baseRev;
  final int updatedAt;
  final String deviceId;

  const IncomingItemState({
    required this.baseRev,
    required this.updatedAt,
    required this.deviceId,
  });
}

class ConflictResolver {
  const ConflictResolver._();

  /// Reports whether [incoming] should be accepted (replacing [current])
  /// per the spec's rule:
  ///
  ///  - no current record: accept iff `baseRev == 0` (a genuinely new item)
  ///  - `current.rev == incoming.baseRev`: accept (writer saw the latest
  ///    state)
  ///  - otherwise: accept iff `(updatedAt, deviceId)` sorts strictly after
  ///    the current version's, comparing `updatedAt` first and `deviceId`
  ///    lexicographically as the tiebreaker.
  static bool accept(CurrentItemState current, IncomingItemState incoming) {
    if (!current.exists) return incoming.baseRev == 0;
    if (current.rev == incoming.baseRev) return true;
    return _wins(
      incoming.updatedAt,
      incoming.deviceId,
      current.updatedAt,
      current.deviceId,
    );
  }

  static bool _wins(
    int aUpdatedAt,
    String aDeviceId,
    int bUpdatedAt,
    String bDeviceId,
  ) {
    if (aUpdatedAt != bUpdatedAt) return aUpdatedAt > bUpdatedAt;
    return aDeviceId.compareTo(bDeviceId) > 0;
  }

  /// Convenience for the pull path: does a locally dirty (not yet pushed)
  /// version of an item win over a version the server has already
  /// accepted? The local edit plays the role of [IncomingItemState] (it is
  /// unconfirmed) and the remote item plays [CurrentItemState] (it is
  /// authoritative) - this is the same rule the server would apply if the
  /// local edit were pushed right now, just evaluated on-device so a
  /// winning local edit is not clobbered by the pull that arrived first.
  static bool localWinsOverRemote({
    required int localBaseRev,
    required int localUpdatedAt,
    required String localDeviceId,
    required int remoteRev,
    required int remoteUpdatedAt,
    required String remoteDeviceId,
  }) {
    return accept(
      CurrentItemState(
        exists: true,
        rev: remoteRev,
        updatedAt: remoteUpdatedAt,
        deviceId: remoteDeviceId,
      ),
      IncomingItemState(
        baseRev: localBaseRev,
        updatedAt: localUpdatedAt,
        deviceId: localDeviceId,
      ),
    );
  }
}
