import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../l10n/app_localizations.dart';
import '../auth/auth_providers.dart';
import '../auth/change_server_screen.dart';
import '../sync/sync_status_provider.dart';

/// Server address, reachability, and sync diagnostics, plus manual sync
/// and the entry point to switch servers - see client/settings spec,
/// "Диагностика подключения к серверу".
class ServerSettingsScreen extends ConsumerStatefulWidget {
  const ServerSettingsScreen({super.key});

  @override
  ConsumerState<ServerSettingsScreen> createState() =>
      _ServerSettingsScreenState();
}

class _ServerSettingsScreenState extends ConsumerState<ServerSettingsScreen> {
  bool? _reachable;

  @override
  void initState() {
    super.initState();
    _checkReachability();
  }

  Future<void> _checkReachability() async {
    final api = ref.read(sessionControllerProvider.notifier).apiClient;
    final result = await api.health();
    if (mounted) setState(() => _reachable = result.isOk);
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
