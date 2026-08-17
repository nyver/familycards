import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/crypto/invite_code.dart';
import '../../core/providers.dart';
import '../../core/result.dart';
import '../../l10n/app_localizations.dart';
import '../auth/auth_providers.dart';

const _defaultTtlHours = 24;

/// Generates a single invite code, shown once as text and a QR code - see
/// client/settings spec, "Приглашение нового участника". The plaintext
/// code is never persisted anywhere; once this screen is left, only
/// cancellation (while the invite is still active) remains possible, not
/// viewing the code again.
class InviteScreen extends ConsumerStatefulWidget {
  const InviteScreen({super.key});

  @override
  ConsumerState<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends ConsumerState<InviteScreen> {
  bool _generating = false;
  String? _error;
  ({String code, String codeHash})? _invite;
  DateTime? _expiresAt;
  bool _cancelled = false;

  Future<void> _generate() async {
    final l10n = AppLocalizations.of(context)!;
    final vaultKey = ref.read(vaultKeyProvider);
    if (vaultKey == null) return;

    setState(() {
      _generating = true;
      _error = null;
    });

    final result = await ref
        .read(sessionControllerProvider.notifier)
        .createInvite(vaultKey: vaultKey, ttlHours: _defaultTtlHours);

    if (!mounted) return;
    setState(() {
      _generating = false;
      result.fold(
        (invite) {
          _invite = invite;
          _expiresAt = DateTime.now().add(
            const Duration(hours: _defaultTtlHours),
          );
        },
        (error) {
          _error = error.kind == AppErrorKind.conflict
              ? l10n.inviteLimitReached
              : error.message;
        },
      );
    });
  }

  Future<void> _cancel() async {
    final invite = _invite;
    if (invite == null) return;
    final api = ref.read(sessionControllerProvider.notifier).apiClient;
    await api.deleteInvite(invite.codeHash);
    if (mounted) setState(() => _cancelled = true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final invite = _invite;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.inviteTitle)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: invite == null
              ? _buildGenerate(l10n)
              : _buildShow(context, l10n, invite),
        ),
      ),
    );
  }

  Widget _buildGenerate(AppLocalizations l10n) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_error != null) ...[
          Text(_error!, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 16),
        ],
        FilledButton(
          onPressed: _generating ? null : _generate,
          child: _generating
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.inviteGenerateButton),
        ),
      ],
    );
  }

  Widget _buildShow(
    BuildContext context,
    AppLocalizations l10n,
    ({String code, String codeHash}) invite,
  ) {
    final formatted = InviteCode.format(invite.code);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        QrImageView(data: invite.code, size: 200),
        const SizedBox(height: 24),
        SelectableText(
          formatted,
          style: Theme.of(context).textTheme.headlineMedium
              ?.copyWith(fontFamily: 'monospace'),
        ),
        const SizedBox(height: 8),
        if (_expiresAt != null)
          Text(
            l10n.inviteExpiresAt(
              DateFormat.yMMMd(l10n.localeName)
                  .add_Hm()
                  .format(_expiresAt!.toLocal()),
            ),
          ),
        const SizedBox(height: 24),
        if (_cancelled)
          Text(l10n.inviteCancelledMessage)
        else ...[
          FilledButton.icon(
            onPressed: () =>
                SharePlus.instance.share(ShareParams(text: formatted)),
            icon: const Icon(Icons.share_outlined),
            label: Text(l10n.inviteShareButton),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => _confirmCancel(context, l10n),
            child: Text(l10n.inviteCancelButton),
          ),
        ],
      ],
    );
  }

  Future<void> _confirmCancel(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.inviteCancelButton),
        content: Text(l10n.inviteCancelConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.inviteCancelButton),
          ),
        ],
      ),
    );
    if (confirmed == true) await _cancel();
  }
}
