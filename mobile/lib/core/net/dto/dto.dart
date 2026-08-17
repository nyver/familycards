/// Wire DTOs for every server endpoint (see docs/API.md). All binary
/// fields are base64-encoded strings on the wire; JSON round-trip lives
/// here, decoupled from the domain model used by the rest of the app.
library;

class DeviceDto {
  final String? id;
  final String name;
  final String platform;

  const DeviceDto({this.id, required this.name, required this.platform});

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'name': name,
    'platform': platform,
  };
}

class RecoveryDto {
  final String wrappedVaultKey;
  final String wrapNonce;
  final String kdfSalt;
  final Map<String, dynamic> kdfParams;
  // The recovery phrase's canonical string form, sent once over TLS at
  // bootstrap so the server can hash and store it as verifier_hash - see
  // docs/API.md and core/crypto/recovery_phrase.dart.
  final String verifier;

  const RecoveryDto({
    required this.wrappedVaultKey,
    required this.wrapNonce,
    required this.kdfSalt,
    required this.kdfParams,
    required this.verifier,
  });

  Map<String, dynamic> toJson() => {
    'wrapped_vault_key': wrappedVaultKey,
    'wrap_nonce': wrapNonce,
    'kdf_salt': kdfSalt,
    'kdf_params': kdfParams,
    'verifier': verifier,
  };
}

class BootstrapRequest {
  final String login;
  final String displayName;
  final String password;
  final String kdfSalt;
  final Map<String, dynamic> kdfParams;
  final String wrappedVaultKey;
  final String wrapNonce;
  final RecoveryDto recovery;
  final DeviceDto device;

  const BootstrapRequest({
    required this.login,
    required this.displayName,
    required this.password,
    required this.kdfSalt,
    required this.kdfParams,
    required this.wrappedVaultKey,
    required this.wrapNonce,
    required this.recovery,
    required this.device,
  });

  Map<String, dynamic> toJson() => {
    'login': login,
    'display_name': displayName,
    'password': password,
    'kdf_salt': kdfSalt,
    'kdf_params': kdfParams,
    'wrapped_vault_key': wrappedVaultKey,
    'wrap_nonce': wrapNonce,
    'recovery': recovery.toJson(),
    'device': device.toJson(),
  };
}

class SessionResponse {
  final String userId;
  final String vaultId;
  final String deviceId;
  final String accessToken;
  final String refreshToken;
  final String? wrappedVaultKey;
  final String? wrapNonce;
  final String? kdfSalt;
  final Map<String, dynamic>? kdfParams;

  const SessionResponse({
    required this.userId,
    required this.vaultId,
    required this.deviceId,
    required this.accessToken,
    required this.refreshToken,
    this.wrappedVaultKey,
    this.wrapNonce,
    this.kdfSalt,
    this.kdfParams,
  });

  factory SessionResponse.fromJson(Map<String, dynamic> json) =>
      SessionResponse(
        userId: json['user_id'] as String,
        vaultId: json['vault_id'] as String,
        deviceId: json['device_id'] as String,
        accessToken: json['access_token'] as String,
        refreshToken: json['refresh_token'] as String,
        wrappedVaultKey: json['wrapped_vault_key'] as String?,
        wrapNonce: json['wrap_nonce'] as String?,
        kdfSalt: json['kdf_salt'] as String?,
        kdfParams: json['kdf_params'] as Map<String, dynamic>?,
      );
}

class PreloginResponse {
  final String kdfSalt;
  final Map<String, dynamic> kdfParams;

  const PreloginResponse({required this.kdfSalt, required this.kdfParams});

  factory PreloginResponse.fromJson(Map<String, dynamic> json) =>
      PreloginResponse(
        kdfSalt: json['kdf_salt'] as String,
        kdfParams: json['kdf_params'] as Map<String, dynamic>,
      );
}

class RecoveryPreloginResponse {
  final String kdfSalt;
  final Map<String, dynamic> kdfParams;
  final String wrappedVaultKey;
  final String wrapNonce;

  const RecoveryPreloginResponse({
    required this.kdfSalt,
    required this.kdfParams,
    required this.wrappedVaultKey,
    required this.wrapNonce,
  });

  factory RecoveryPreloginResponse.fromJson(Map<String, dynamic> json) =>
      RecoveryPreloginResponse(
        kdfSalt: json['kdf_salt'] as String,
        kdfParams: json['kdf_params'] as Map<String, dynamic>,
        wrappedVaultKey: json['wrapped_vault_key'] as String,
        wrapNonce: json['wrap_nonce'] as String,
      );
}

class TokenPair {
  final String accessToken;
  final String refreshToken;

  const TokenPair({required this.accessToken, required this.refreshToken});

  factory TokenPair.fromJson(Map<String, dynamic> json) => TokenPair(
    accessToken: json['access_token'] as String,
    refreshToken: json['refresh_token'] as String,
  );
}

class MeResponse {
  final String userId;
  final String login;
  final String displayName;
  final String vaultId;
  final int maxUsers;
  final int userCount;
  final int serverRev;

  const MeResponse({
    required this.userId,
    required this.login,
    required this.displayName,
    required this.vaultId,
    required this.maxUsers,
    required this.userCount,
    required this.serverRev,
  });

  factory MeResponse.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>;
    final vault = json['vault'] as Map<String, dynamic>;
    return MeResponse(
      userId: user['id'] as String,
      login: user['login'] as String,
      displayName: user['display_name'] as String,
      vaultId: vault['id'] as String,
      maxUsers: vault['max_users'] as int,
      userCount: vault['user_count'] as int,
      serverRev: json['server_rev'] as int,
    );
  }
}

class ItemDto {
  final String itemId;
  final String kind;
  final int rev;
  final int updatedAt;
  final bool deleted;
  final String deviceId;
  final String? nonce;
  final String? ciphertext;
  final List<String> blobRefs;

  const ItemDto({
    required this.itemId,
    required this.kind,
    required this.rev,
    required this.updatedAt,
    required this.deleted,
    required this.deviceId,
    this.nonce,
    this.ciphertext,
    this.blobRefs = const [],
  });

  factory ItemDto.fromJson(Map<String, dynamic> json) => ItemDto(
    itemId: json['item_id'] as String,
    kind: json['kind'] as String,
    rev: json['rev'] as int,
    updatedAt: json['updated_at'] as int,
    deleted: json['deleted'] as bool,
    deviceId: json['device_id'] as String,
    nonce: json['nonce'] as String?,
    ciphertext: json['ciphertext'] as String?,
    blobRefs: (json['blob_refs'] as List<dynamic>? ?? const [])
        .map((e) => e as String)
        .toList(),
  );
}

class PushItemDto {
  final String itemId;
  final String kind;
  final int baseRev;
  final int updatedAt;
  final bool deleted;
  final String? nonce;
  final String? ciphertext;
  final List<String> blobRefs;

  const PushItemDto({
    required this.itemId,
    required this.kind,
    required this.baseRev,
    required this.updatedAt,
    required this.deleted,
    this.nonce,
    this.ciphertext,
    this.blobRefs = const [],
  });

  Map<String, dynamic> toJson() => {
    'item_id': itemId,
    'kind': kind,
    'base_rev': baseRev,
    'updated_at': updatedAt,
    'deleted': deleted,
    'nonce': nonce,
    'ciphertext': ciphertext,
    'blob_refs': blobRefs,
  };
}

class ChangesResponse {
  final int serverRev;
  final int nextSince;
  final bool hasMore;
  final List<ItemDto> items;

  const ChangesResponse({
    required this.serverRev,
    required this.nextSince,
    required this.hasMore,
    required this.items,
  });

  factory ChangesResponse.fromJson(Map<String, dynamic> json) =>
      ChangesResponse(
        serverRev: json['server_rev'] as int,
        nextSince: json['next_since'] as int,
        hasMore: json['has_more'] as bool,
        items: (json['items'] as List<dynamic>)
            .map((e) => ItemDto.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class AcceptedItem {
  final String itemId;
  final int rev;

  const AcceptedItem({required this.itemId, required this.rev});

  factory AcceptedItem.fromJson(Map<String, dynamic> json) =>
      AcceptedItem(itemId: json['item_id'] as String, rev: json['rev'] as int);
}

class PushResponse {
  final int serverRev;
  final List<AcceptedItem> accepted;
  final List<ItemDto> conflicts;

  const PushResponse({
    required this.serverRev,
    required this.accepted,
    required this.conflicts,
  });

  factory PushResponse.fromJson(Map<String, dynamic> json) => PushResponse(
    serverRev: json['server_rev'] as int,
    accepted: (json['accepted'] as List<dynamic>)
        .map((e) => AcceptedItem.fromJson(e as Map<String, dynamic>))
        .toList(),
    conflicts: (json['conflicts'] as List<dynamic>)
        .map((e) => ItemDto.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

class UploadBlobResponse {
  final String blobId;
  final int size;

  const UploadBlobResponse({required this.blobId, required this.size});

  factory UploadBlobResponse.fromJson(Map<String, dynamic> json) =>
      UploadBlobResponse(
        blobId: json['blob_id'] as String,
        size: json['size'] as int,
      );
}

class HealthResponse {
  final String status;
  final String version;

  const HealthResponse({required this.status, required this.version});

  factory HealthResponse.fromJson(Map<String, dynamic> json) => HealthResponse(
    status: json['status'] as String,
    version: json['version'] as String,
  );
}

class InviteMaterialDto {
  final String vaultId;
  final String wrappedVaultKey;
  final String wrapNonce;
  final String kdfSalt;
  final Map<String, dynamic> kdfParams;

  const InviteMaterialDto({
    required this.vaultId,
    required this.wrappedVaultKey,
    required this.wrapNonce,
    required this.kdfSalt,
    required this.kdfParams,
  });

  factory InviteMaterialDto.fromJson(Map<String, dynamic> json) =>
      InviteMaterialDto(
        vaultId: json['vault_id'] as String,
        wrappedVaultKey: json['wrapped_vault_key'] as String,
        wrapNonce: json['wrap_nonce'] as String,
        kdfSalt: json['kdf_salt'] as String,
        kdfParams: json['kdf_params'] as Map<String, dynamic>,
      );
}

class MemberDeviceDto {
  final String id;
  final String name;
  final String platform;
  final int createdAt;
  final int lastSeenAt;
  final bool revoked;

  const MemberDeviceDto({
    required this.id,
    required this.name,
    required this.platform,
    required this.createdAt,
    required this.lastSeenAt,
    required this.revoked,
  });

  factory MemberDeviceDto.fromJson(Map<String, dynamic> json) =>
      MemberDeviceDto(
        id: json['id'] as String,
        name: json['name'] as String,
        platform: json['platform'] as String,
        createdAt: json['created_at'] as int,
        lastSeenAt: json['last_seen_at'] as int,
        revoked: json['revoked'] as bool,
      );
}

class MemberDto {
  final String userId;
  final String displayName;
  final String login;
  final int createdAt;
  final int lastSeenAt;
  final List<MemberDeviceDto> devices;

  const MemberDto({
    required this.userId,
    required this.displayName,
    required this.login,
    required this.createdAt,
    required this.lastSeenAt,
    required this.devices,
  });

  factory MemberDto.fromJson(Map<String, dynamic> json) => MemberDto(
    userId: json['user_id'] as String,
    displayName: json['display_name'] as String,
    login: json['login'] as String,
    createdAt: json['created_at'] as int,
    lastSeenAt: json['last_seen_at'] as int,
    devices: (json['devices'] as List<dynamic>)
        .map((e) => MemberDeviceDto.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}
