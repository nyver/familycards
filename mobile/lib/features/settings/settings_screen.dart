import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../auth/auth_providers.dart';
import 'export_screen.dart';
import 'import_screen.dart';
import 'members_screen.dart';
import 'security_screen.dart';
import 'server_settings_screen.dart';
import 'trash_screen.dart';

/// Entry point for everything that isn't day-to-day card use - see
/// client/settings spec.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.group_outlined),
            title: Text(l10n.settingsMembersTile),
            onTap: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const MembersScreen())),
          ),
          ListTile(
            leading: const Icon(Icons.fingerprint),
            title: Text(l10n.settingsSecurityTile),
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const SecurityScreen())),
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: Text(l10n.settingsTrashTile),
            onTap: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const TrashScreen())),
          ),
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: Text(l10n.settingsExportTile),
            onTap: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const ExportScreen())),
          ),
          ListTile(
            leading: const Icon(Icons.upload_outlined),
            title: Text(l10n.settingsImportTile),
            onTap: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const ImportScreen())),
          ),
          ListTile(
            leading: const Icon(Icons.dns_outlined),
            title: Text(l10n.settingsServerTile),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ServerSettingsScreen()),
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: Text(l10n.settingsLogoutTile),
            onTap: () => _confirmLogout(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    final pending = await ref.read(cardsDaoProvider).countDirtyCards();

    if (!context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.logoutConfirmTitle),
        content: Text(
          pending > 0
              ? l10n.logoutConfirmBodyUnsynced(pending)
              : l10n.logoutConfirmBodyClean,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.settingsLogoutTile),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(sessionControllerProvider.notifier).logout();
    }
  }
}
