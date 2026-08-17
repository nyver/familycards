import 'package:flutter/material.dart' hide Card;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';

const _trashRetentionDays = 30;

/// Deleted cards, with remaining time before the 30-day auto-purge, and
/// the ability to restore or permanently delete each one - see
/// client/settings spec, "Корзина".
class TrashScreen extends ConsumerWidget {
  const TrashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final dao = ref.watch(cardsDaoProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.trashTitle)),
      body: StreamBuilder<List<Card>>(
        stream: dao.watchTrash(),
        builder: (context, snapshot) {
          final cards = snapshot.data;
          if (cards == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (cards.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  l10n.trashEmpty,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            );
          }
          return ListView.builder(
            itemCount: cards.length,
            itemBuilder: (context, i) => _TrashTile(card: cards[i]),
          );
        },
      ),
    );
  }
}

class _TrashTile extends ConsumerWidget {
  final Card card;
  const _TrashTile({required this.card});

  int _daysRemaining() {
    final deletedAt = card.deletedAt;
    if (deletedAt == null) return _trashRetentionDays;
    final deletedDate = DateTime.fromMillisecondsSinceEpoch(deletedAt);
    final expiresAt = deletedDate.add(
      const Duration(days: _trashRetentionDays),
    );
    final remaining = expiresAt.difference(DateTime.now()).inDays;
    return remaining < 0 ? 0 : remaining;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return ListTile(
      leading: CircleAvatar(backgroundColor: Color(card.color)),
      title: Text(card.storeName),
      subtitle: Text(l10n.trashDaysRemaining(_daysRemaining())),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.restore_outlined),
            tooltip: l10n.trashRestoreButton,
            onPressed: () => ref.read(cardRepositoryProvider).restore(card.id),
          ),
          IconButton(
            icon: const Icon(Icons.delete_forever_outlined),
            tooltip: l10n.trashDeleteForeverButton,
            onPressed: () => _confirmDeleteForever(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteForever(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.trashDeleteForeverConfirmTitle),
        content: Text(l10n.trashDeleteForeverConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(cardRepositoryProvider).purgeForever(card.id);
    }
  }
}
