import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/net/api_client.dart';
import '../../core/net/certificate_fingerprint.dart';
import '../../core/result.dart';
import '../../l10n/app_localizations.dart';
import '../auth/auth_providers.dart';
import '../auth/certificate_pin_ui.dart';
import '../auth/change_server_screen.dart';
import '../sync/sync_status_provider.dart';

/// Server address, reachability, and sync diagnostics, plus manual sync,
/// certificate pin management, and the entry point to switch servers -
/// see client/settings spec, "Диагностика подключения к серверу". Stays
/// fully usable (view/replace/remove the pin) even while the connection
/// is actively broken by a certificate mismatch - none of its actions
/// depend on a successful health check succeeding first.
class ServerSettingsScreen extends ConsumerStatefulWidget {
  const ServerSettingsScreen({super.key});

  @override
  ConsumerState<ServerSettingsScreen> createState() =>
      _ServerSettingsScreenState();
}

class _ServerSettingsScreenState extends ConsumerState<ServerSettingsScreen> {
  bool? _reachable;
  bool _certificateMismatch = false;
  String? _pinnedFingerprint;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadPin();
    _checkReachability();
  }

  Future<void> _loadPin() async {
    final identityStore = ref.read(sessionControllerProvider.notifier).identityStore;
    final pin = await identityStore.getPinnedCertificateFingerprint();
    if (mounted) setState(() => _pinnedFingerprint = pin);
  }

  Future<void> _checkReachability() async {
    final api = ref.read(sessionControllerProvider.notifier).apiClient;
    final result = await api.health();
    if (!mounted) return;
    setState(() {
      _reachable = result.isOk;
      // Distinguish a certificate mismatch from an ordinary connectivity
      // failure (server down, no network) - otherwise a transient outage
      // would show the "replace or remove the pin" notice for a pin that
      // is actually still correct.
      _certificateMismatch =
          result.errorOrNull?.kind == AppErrorKind.certificateMismatch;
    });
  }

  /// Trust-on-first-use pinning/re-pinning: probes the current address for
  /// the certificate it presents, requires explicit confirmation of its
  /// fingerprint (no bypass), warns if that certificate also validates
  /// via public CA trust (renewal would silently break the pin later),
  /// then applies it to both the live client and persisted storage.
  Future<void> _pinOrReplace() async {
    final l10n = AppLocalizations.of(context)!;
    final controller = ref.read(sessionControllerProvider.notifier);
    final address = controller.apiClient.currentBaseUrl;

    setState(() => _busy = true);
    final cert = await controller.probePresentedCertificate(address);
    if (!mounted) return;
    if (cert == null) {
      setState(() => _busy = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.onboardingServerUnreachable)));
      return;
    }

    final confirmedPin = await confirmCertificateFingerprint(context, cert);
    if (!mounted) return;
    if (confirmedPin == null) {
      setState(() => _busy = false);
      return;
    }

    // Best-effort: if this certificate would also be accepted by ordinary
    // system-root verification (the ACME/public-CA case), warn that
    // renewal will rotate the fingerprint and silently break the pin.
    final trustedBySystem = await ApiClient.validatesWithSystemRoots(address);
    if (!mounted) return;
    if (trustedBySystem) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.serverSettingsCertificateAcmeWarningTitle),
          content: Text(l10n.serverSettingsCertificateAcmeWarningBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.commonCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.commonConfirm),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (proceed != true) {
        setState(() => _busy = false);
        return;
      }
    }

    controller.apiClient.setBaseUrl(address, pinnedFingerprint: confirmedPin);
    await controller.identityStore.setPinnedCertificateFingerprint(
      formatFingerprint(confirmedPin),
    );
    if (!mounted) return;
    setState(() {
      _pinnedFingerprint = formatFingerprint(confirmedPin);
      _busy = false;
    });
    _checkReachability();
  }

  Future<void> _removePin() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.serverSettingsCertificateRemoveConfirmTitle),
        content: Text(l10n.serverSettingsCertificateRemoveConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.serverSettingsCertificateRemoveButton),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final controller = ref.read(sessionControllerProvider.notifier);
    final address = controller.apiClient.currentBaseUrl;
    setState(() => _busy = true);
    controller.apiClient.setBaseUrl(address);
    await controller.identityStore.setPinnedCertificateFingerprint(null);
    if (!mounted) return;
    setState(() {
      _pinnedFingerprint = null;
      _busy = false;
    });
    _checkReachability();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final address = ref
        .read(sessionControllerProvider.notifier)
        .apiClient
        .currentBaseUrl;
    final status = ref.watch(syncControllerProvider);

    final lastSyncText = status.lastSyncAt == null
        ? '—'
        : DateFormat.yMMMd(l10n.localeName)
              .add_Hm()
              .format(status.lastSyncAt!.toLocal());

    return Scaffold(
      appBar: AppBar(title: Text(l10n.serverSettingsTitle)),
      body: ListView(
        children: [
          ListTile(
            title: Text(l10n.serverSettingsAddressLabel),
            subtitle: Text(address),
          ),
          ListTile(
            title: Text(
              _reachable == null
                  ? '…'
                  : (_reachable!
                        ? l10n.serverSettingsReachable
                        : l10n.serverSettingsUnreachable),
            ),
            leading: Icon(
              _reachable == false ? Icons.error_outline : Icons.dns_outlined,
              color: _reachable == false ? Colors.red : null,
            ),
          ),
          ListTile(
            title: Text(l10n.serverSettingsLastSync),
            subtitle: Text(lastSyncText),
          ),
          ListTile(
            title: Text(l10n.serverSettingsPendingCount),
            subtitle: Text('${status.pendingCount}'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.verified_user_outlined),
            title: Text(l10n.serverSettingsCertificateTitle),
            subtitle: Text(
              _pinnedFingerprint ?? l10n.serverSettingsCertificateNotPinned,
              style: _pinnedFingerprint == null
                  ? null
                  : const TextStyle(fontFamily: 'monospace'),
            ),
          ),
          if (_certificateMismatch && _pinnedFingerprint != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                l10n.serverSettingsCertificateMismatchNotice,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (_pinnedFingerprint == null)
                  OutlinedButton(
                    onPressed: _busy ? null : _pinOrReplace,
                    child: Text(l10n.serverSettingsCertificatePinButton),
                  )
                else ...[
                  OutlinedButton(
                    onPressed: _busy ? null : _pinOrReplace,
                    child: Text(l10n.serverSettingsCertificateReplaceButton),
                  ),
                  OutlinedButton(
                    onPressed: _busy ? null : _removePin,
                    child: Text(l10n.serverSettingsCertificateRemoveButton),
                  ),
                ],
              ],
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.sync),
            title: Text(l10n.serverSettingsForceSyncButton),
            onTap: () {
              ref.read(syncControllerProvider.notifier).refreshNow();
              _checkReachability();
            },
          ),
          ListTile(
            leading: const Icon(Icons.dns_outlined),
            title: Text(l10n.serverSettingsChangeAddressButton),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ChangeServerScreen()),
            ),
          ),
        ],
      ),
    );
  }
}
