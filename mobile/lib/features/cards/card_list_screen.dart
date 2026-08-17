import 'package:flutter/material.dart' hide Card;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../settings/settings_screen.dart';
import '../sync/sync_status_provider.dart';
import 'card_detail_screen.dart';
import 'card_editor_screen.dart';

/// Main authenticated screen: a two-column grid of card tiles, favorites
/// pinned in their own section above the rest, a search field, and a
/// floating add button. Reads live from the local database (via
/// [CardsDao.watchVisibleCards]) so it never shows a blocking spinner once
/// first loaded - sync happening in the background just updates the grid
/// in place.
class CardListScreen extends ConsumerStatefulWidget {
  const CardListScreen({super.key});

  @override
  ConsumerState<CardListScreen> createState() => _CardListScreenState();
}

class _CardListScreenState extends ConsumerState<CardListScreen> {
  String _query = '';

  @override
  void initState() {
    super.initState();
    // One-shot trash sweep: physically drops any card that has been in the
    // trash for over 30 days. Cheap enough to run on every cold start.
    ref.read(cardRepositoryProvider).purgeExpiredTrash();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dao = ref.watch(cardsDaoProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.cardsListTitle),
        actions: [
          const SyncStatusIndicator(),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: l10n.settingsTitle,
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const CardEditorScreen())),
        tooltip: l10n.cardsListAddCard,
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<Card>>(
        stream: dao.watchVisibleCards(),
        builder: (context, snapshot) {
          final cards = snapshot.data;
          if (cards == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (cards.isEmpty) {
            return RefreshIndicator(
              onRefresh: () =>
                  ref.read(syncControllerProvider.notifier).refreshNow(),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [_EmptyState(l10n: l10n)],
              ),
            );
          }

          final filtered = _query.trim().isEmpty
              ? cards
              : cards
                    .where(
                      (c) =>
                          c.storeName.toLowerCase().contains(
                            _query.toLowerCase(),
                          ) ||
                          c.cardNumber.contains(_query),
                    )
                    .toList();

          final favorites = filtered.where((c) => c.favorite).toList();
          final others = filtered.where((c) => !c.favorite).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: l10n.cardsListSearchHint,
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: (value) => setState(() => _query = value),
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () =>
                      ref.read(syncControllerProvider.notifier).refreshNow(),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      if (favorites.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            l10n.cardsListFavoritesSection,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        _CardGrid(cards: favorites, reorderable: false),
                        const SizedBox(height: 16),
                      ],
                      _CardGrid(
                        cards: others,
                        reorderable: _query.trim().isEmpty,
                      ),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final AppLocalizations l10n;
  const _EmptyState({required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.credit_card_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.cardsListEmptyTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.cardsListEmptySubtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

/// A grid of card tiles. When [reorderable] is true (only offered for the
/// unfiltered, non-favorite section - reordering a filtered or pinned view
/// would silently corrupt sort order relative to hidden items), dragging a
/// tile persists its new position via [CardRepository.reorder].
class _CardGrid extends ConsumerWidget {
  final List<Card> cards;
  final bool reorderable;
  const _CardGrid({required this.cards, required this.reorderable});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (cards.isEmpty) return const SizedBox.shrink();
    final crossAxisCount = 2;

    if (!reorderable) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.4,
        ),
        itemCount: cards.length,
        itemBuilder: (context, i) => _CardTile(card: cards[i]),
      );
    }

    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.4,
      ),
      children: [
        for (var i = 0; i < cards.length; i++)
          LongPressDraggable<int>(
            key: ValueKey(cards[i].id),
            data: i,
            feedback: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                width: 160,
                height: 110,
                child: _CardTile(card: cards[i]),
              ),
            ),
            childWhenDragging: Opacity(
              opacity: 0.3,
              child: _CardTile(card: cards[i]),
            ),
            child: DragTarget<int>(
              onAcceptWithDetails: (details) {
                final fromIndex = details.data;
                if (fromIndex == i) return;
                ref
                    .read(cardRepositoryProvider)
                    .reorder(cards[fromIndex].id, i);
              },
              builder: (context, candidateData, rejectedData) =>
                  _CardTile(card: cards[i]),
            ),
          ),
      ],
    );
  }
}

class _CardTile extends StatelessWidget {
  final Card card;
  const _CardTile({required this.card});

  @override
  Widget build(BuildContext context) {
    final color = Color(card.color);
    final isDark = color.computeLuminance() < 0.5;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Material(
      color: color,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => CardDetailScreen(cardId: card.id)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (card.logoAsset != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(card.logoAsset!, width: 32, height: 32),
                  ),
                ),
              Text(
                card.storeName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
