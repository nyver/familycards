import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/net/dto/dto.dart';
import '../../core/result.dart';
import '../../l10n/app_localizations.dart';
import '../auth/auth_providers.dart';
import 'invite_screen.dart';

/// A member counts as active if at least one of their devices has not
/// been revoked - `DELETE /v1/members/{id}` always revokes every device
/// in the same transaction it disables the user (see
/// specs/server/membership/spec.md, "Отзыв участника"), so this is
/// exactly equivalent to the server's own `disabled` flag without the API
/// needing to expose it separately.
bool _isActive(MemberDto member) => member.devices.any((d) => !d.revoked);

/// All members of the vault, their devices, and the ability to revoke
/// access - see client/settings spec, "Управление участниками семьи".
class MembersScreen extends ConsumerStatefulWidget {
  const MembersScreen({super.key});

  @override
  ConsumerState<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends ConsumerState<MembersScreen> {
  Result<List<MemberDto>>? _result;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = ref.read(sessionControllerProvider.notifier).apiClient;
    final result = await api.listMembers();
    if (mounted) setState(() => _result = result);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final result = _result;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.membersTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_outlined),
            tooltip: l10n.inviteTitle,
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const InviteScreen())),
          ),
        ],
      ),
      body: switch (result) {
        null => const Center(child: CircularProgressIndicator()),
        Err<List<MemberDto>>() => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(l10n.membersNoNetwork, textAlign: TextAlign.center),
          ),
        ),
        Ok<List<MemberDto>>(value: final members) => _MembersList(
          members: members,
          onRefresh: _load,
          onRevoked: _load,
        ),
      },
    );
  }
}

class _MembersList extends ConsumerWidget {
  final List<MemberDto> members;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onRevoked;
  const _MembersList({
    required this.members,
    required this.onRefresh,
    required this.onRevoked,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeCount = members.where(_isActive).length;
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: members.length,
        itemBuilder: (context, i) => _MemberTile(
          member: members[i],
          canRevoke: _isActive(members[i]) && activeCount > 1,
          onRevoked: onRevoked,
        ),
      ),
    );
  }
}

class _MemberTile extends ConsumerWidget {
  final MemberDto member;
  final bool canRevoke;
  final Future<void> Function() onRevoked;
  const _MemberTile({
    required this.member,
    required this.canRevoke,
    required this.onRevoked,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final active = _isActive(member);
    final deviceCount = l10n.membersDeviceCount(member.devices.length);
    return ListTile(
      title: Text(member.displayName),
      subtitle: Text(
        active
            ? '${member.login} · $deviceCount'
            : '${member.login} · $deviceCount · ${l10n.membersRevokedLabel}',
      ),
      trailing: canRevoke
          ? IconButton(
              icon: const Icon(Icons.person_remove_outlined),
              tooltip: l10n.membersRevokeButton,
              onPressed: () => _confirmRevoke(context, ref),
            )
          : null,
    );
  }

  Future<void> _confirmRevoke(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.membersRevokeConfirmTitle),
        content: Text(l10n.membersRevokeConfirmBody(member.displayName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.membersRevokeButton),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final api = ref.read(sessionControllerProvider.notifier).apiClient;
    await api.removeMember(member.userId);
    await onRevoked();
  }
}
