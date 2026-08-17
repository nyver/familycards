import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../auth/auth_providers.dart';

/// Biometric unlock toggle - see client/settings spec, "Биометрическая
/// защита и автоблокировка". The 5-minute background auto-lock itself is
/// always on (see core/crypto/vault_key.dart's backgroundLockTimeout) and
/// is not user-configurable, so this screen only surfaces the biometric
/// opt-in.
class SecurityScreen extends ConsumerStatefulWidget {
  const SecurityScreen({super.key});

  @override
  ConsumerState<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends ConsumerState<SecurityScreen> {
  bool? _enabled;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    ref.read(securitySettingsStoreProvider).isBiometricEnabled().then((
      enabled,
    ) {
      if (mounted) setState(() => _enabled = enabled);
    });
  }

  Future<void> _setEnabled(bool enabled) async {
    final l10n = AppLocalizations.of(context)!;
    final vaultKeyHolder = ref
        .read(sessionControllerProvider.notifier)
        .vaultKeyHolder;
    final store = ref.read(securitySettingsStoreProvider);

    if (!enabled) {
      await vaultKeyHolder.clearPersisted();
      await store.setBiometricEnabled(false);
      if (mounted) setState(() => _enabled = false);
      return;
    }

    setState(() => _busy = true);
    final authenticator = ref.read(biometricAuthenticatorProvider);
    final available = await authenticator.isAvailable();
    if (!available) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.securityBiometricUnavailable)),
        );
      }
      return;
    }

    final confirmed = await authenticator.authenticate(
      l10n.securityBiometricConfirmReason,
    );
    if (!mounted) return;
    if (!confirmed) {
      setState(() => _busy = false);
      return;
    }

    await vaultKeyHolder.persistIfBiometricEnabled();
    await store.setBiometricEnabled(true);
    if (mounted) {
      setState(() {
        _enabled = true;
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final enabled = _enabled;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.securityBiometricTitle)),
      body: SafeArea(
        child: Column(
          children: [
            SwitchListTile(
              title: Text(l10n.securityBiometricToggle),
              value: enabled ?? false,
              onChanged: (enabled == null || _busy) ? null : _setEnabled,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                l10n.securityAutoLockNotice,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
