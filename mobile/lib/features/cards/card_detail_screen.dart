import 'dart:convert';

import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart' hide Card;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/barcode/barcode_formats.dart';
import '../../core/crypto/canonical_json.dart';
import '../../core/db/daos/cards_dao.dart';
import '../../core/db/database.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import 'card_editor_screen.dart';
import 'photo_attachment.dart';

/// Full-screen barcode presentation for a card, with swipe navigation to
/// neighboring cards. While visible: raises screen brightness and keeps
/// the screen awake, both restored on exit or backgrounding. A fullscreen
/// toggle rotates to landscape and hides all chrome for scanning at a
/// register. Deliberately does not set `FLAG_SECURE` (or any platform
/// equivalent) - a card's barcode is meant to be shown to a cashier, so
/// screenshots/screen-recording must stay possible.
class CardDetailScreen extends ConsumerStatefulWidget {
  final String cardId;
  const CardDetailScreen({super.key, required this.cardId});

  @override
  ConsumerState<CardDetailScreen> createState() => _CardDetailScreenState();
}

class _CardDetailScreenState extends ConsumerState<CardDetailScreen>
    with WidgetsBindingObserver {
  bool _fullscreen = false;
  bool _brightnessRaised = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WakelockPlus.enable();
    _raiseBrightness();
    // Counts as "using" this card, once per screen open - not per swipe
    // to a neighbor - see CardsDao.incrementUseCount.
    ref.read(cardRepositoryProvider).recordUsage(widget.cardId);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    WakelockPlus.disable();
    _restoreBrightness();
    if (_fullscreen) _exitFullscreen();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _raiseBrightness();
    } else {
      _restoreBrightness();
    }
  }

  Future<void> _raiseBrightness() async {
    try {
      await ScreenBrightness.instance.setApplicationScreenBrightness(1.0);
      _brightnessRaised = true;
    } catch (_) {
      // Best-effort: some platforms/emulators reject brightness overrides.
    }
  }

  Future<void> _restoreBrightness() async {
    if (!_brightnessRaised) return;
    _brightnessRaised = false;
    try {
      await ScreenBrightness.instance.resetApplicationScreenBrightness();
    } catch (_) {}
  }

  Future<void> _enterFullscreen() async {
    setState(() => _fullscreen = true);
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  Future<void> _exitFullscreen() async {
    if (mounted) setState(() => _fullscreen = false);
    await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  @override
  Widget build(BuildContext context) {
    final dao = ref.watch(cardsDaoProvider);
    return StreamBuilder<List<Card>>(
      stream: dao.watchVisibleCards(),
      builder: (context, snapshot) {
        final cards = snapshot.data;
        if (cards == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (cards.indexWhere((c) => c.id == widget.cardId) == -1) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && Navigator.canPop(context)) {
              Navigator.of(context).pop();
            }
          });
          return const Scaffold(body: SizedBox.shrink());
        }
        // The swipeable neighbor order is handed down as a plain list of
        // ids; each pager below freezes it once (in initState) rather
        // than re-reading it on every rebuild - see their doc comments
        // for why that matters.
        final orderedIds = cards.map((c) => c.id).toList(growable: false);
        return _fullscreen
            ? _FullscreenPager(
                initialCardIds: orderedIds,
                initialCardId: widget.cardId,
                onExit: _exitFullscreen,
              )
            : _NormalPager(
                initialCardIds: orderedIds,
                initialCardId: widget.cardId,
                onEnterFullscreen: _enterFullscreen,
              );
      },
    );
  }
}

/// The non-fullscreen detail view: an AppBar (favorite/edit/delete, all
/// acting on whichever card is currently on screen) over a swipeable
/// [PageView].
///
/// Deliberately freezes [initialCardIds] once, in [initState], instead of
/// tracking `CardsDao.watchVisibleCards()` live: that stream re-sorts
/// favorites to the front, and `PageView`'s scroll *position* survives
/// widget rebuilds even when a brand-new `PageController` is constructed
/// each time (Flutter re-attaches the existing `ScrollPosition` to the
/// new controller rather than recreating it, so `initialPage` only ever
/// applies once). Without freezing the order, favoriting the very card
/// being viewed would reorder the list out from under a fixed page
/// index, silently swapping in whatever card now landed on that index -
/// wrong store name, wrong number, wrong barcode format. Each page
/// instead looks up its own card reactively by id via [CardsDao.watchCard],
/// so edits still show up live without ever changing *which* card a given
/// page shows.
class _NormalPager extends ConsumerStatefulWidget {
  final List<String> initialCardIds;
  final String initialCardId;
  final VoidCallback onEnterFullscreen;
  const _NormalPager({
    required this.initialCardIds,
    required this.initialCardId,
    required this.onEnterFullscreen,
  });

  @override
  ConsumerState<_NormalPager> createState() => _NormalPagerState();
}

class _NormalPagerState extends ConsumerState<_NormalPager> {
  late final List<String> _orderedIds = widget.initialCardIds;
  late final PageController _pageController;
  late String _currentCardId;

  @override
  void initState() {
    super.initState();
    _currentCardId = widget.initialCardId;
    final startIndex = _orderedIds.indexOf(widget.initialCardId);
    _pageController = PageController(
      initialPage: startIndex < 0 ? 0 : startIndex,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dao = ref.watch(cardsDaoProvider);
    return StreamBuilder<Card?>(
      stream: dao.watchCard(_currentCardId),
      builder: (context, snapshot) {
        final card = snapshot.data;
        if (card == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return Scaffold(
          appBar: AppBar(
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (card.logoAsset != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.asset(card.logoAsset!, width: 28, height: 28),
                  ),
                  const SizedBox(width: 10),
                ],
                Flexible(
                  child: Text(card.storeName, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: Icon(card.favorite ? Icons.star : Icons.star_border),
                onPressed: () => ref
                    .read(cardRepositoryProvider)
                    .toggleFavorite(card.id, !card.favorite),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CardEditorScreen(existing: card),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _confirmDelete(context, card),
              ),
            ],
          ),
          body: PageView.builder(
            controller: _pageController,
            itemCount: _orderedIds.length,
            onPageChanged: (i) =>
                setState(() => _currentCardId = _orderedIds[i]),
            itemBuilder: (context, i) => _CardDetailBody(
              dao: dao,
              cardId: _orderedIds[i],
              onEnterFullscreen: widget.onEnterFullscreen,
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete(BuildContext context, Card card) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.cardDetailDeleteConfirmTitle),
        content: Text(l10n.cardDetailDeleteConfirmBody),
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
      await ref.read(cardRepositoryProvider).softDelete(card.id);
      if (context.mounted) Navigator.of(context).pop();
    }
  }
}

/// The fullscreen barcode-only view. See [_NormalPager]'s doc comment for
/// why the page order is frozen once rather than tracked live.
class _FullscreenPager extends ConsumerStatefulWidget {
  final List<String> initialCardIds;
  final String initialCardId;
  final VoidCallback onExit;
  const _FullscreenPager({
    required this.initialCardIds,
    required this.initialCardId,
    required this.onExit,
  });

  @override
  ConsumerState<_FullscreenPager> createState() => _FullscreenPagerState();
}

class _FullscreenPagerState extends ConsumerState<_FullscreenPager> {
  late final List<String> _orderedIds = widget.initialCardIds;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    final startIndex = _orderedIds.indexOf(widget.initialCardId);
    _pageController = PageController(
      initialPage: startIndex < 0 ? 0 : startIndex,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dao = ref.watch(cardsDaoProvider);
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: _orderedIds.length,
              itemBuilder: (context, i) => StreamBuilder<Card?>(
                stream: dao.watchCard(_orderedIds[i]),
                builder: (context, snapshot) {
                  final card = snapshot.data;
                  if (card == null) return const SizedBox.shrink();
                  return _BarcodeArea(
                    card: card,
                    heightFraction: 0.6,
                    textColor: Colors.white,
                  );
                },
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.fullscreen_exit, color: Colors.white),
                onPressed: widget.onExit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardDetailBody extends StatelessWidget {
  final CardsDao dao;
  final String cardId;
  final VoidCallback onEnterFullscreen;
  const _CardDetailBody({
    required this.dao,
    required this.cardId,
    required this.onEnterFullscreen,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Card?>(
      stream: dao.watchCard(cardId),
      builder: (context, snapshot) {
        final card = snapshot.data;
        if (card == null) return const SizedBox.shrink();
        final customFields = _decodeCustomFields(card.customFields);
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            GestureDetector(
              onTap: onEnterFullscreen,
              child: _BarcodeArea(
                card: card,
                heightFraction: 0.3,
                textColor: Colors.black,
              ),
            ),
            const SizedBox(height: 16),
            if (card.frontBlobId != null || card.backBlobId != null)
              Row(
                children: [
                  if (card.frontBlobId != null)
                    Expanded(child: _PhotoThumbnail(blobId: card.frontBlobId!)),
                  if (card.frontBlobId != null && card.backBlobId != null)
                    const SizedBox(width: 12),
                  if (card.backBlobId != null)
                    Expanded(child: _PhotoThumbnail(blobId: card.backBlobId!)),
                ],
              ),
            if (card.note.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(card.note),
            ],
            if (customFields.isNotEmpty) ...[
              const SizedBox(height: 16),
              for (final field in customFields)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('${field.k}: ${field.v}'),
                ),
            ],
          ],
        );
      },
    );
  }
}

class _BarcodeArea extends StatelessWidget {
  final Card card;
  final double heightFraction;
  final Color textColor;
  const _BarcodeArea({
    required this.card,
    required this.heightFraction,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: double.infinity,
          height: MediaQuery.of(context).size.height * heightFraction,
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: BarcodeWidget(
              data: card.cardNumber,
              barcode: toRenderBarcode(card.barcodeFormat),
              color: Colors.black,
              drawText: false,
              errorBuilder: (context, error) => const SizedBox.shrink(),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (isOneDimensional(card.barcodeFormat))
          GestureDetector(
            onTap: () => _copyNumber(context, card.cardNumber),
            child: Text(
              _groupNumber(card.cardNumber),
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 20,
                color: textColor,
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _copyNumber(BuildContext context, String number) async {
    await Clipboard.setData(ClipboardData(text: number));
    if (!context.mounted) return;
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(l10n.cardDetailNumberCopied)));
  }
}

String _groupNumber(String number) {
  final buffer = StringBuffer();
  for (var i = 0; i < number.length; i++) {
    if (i > 0 && i % 4 == 0) buffer.write(' ');
    buffer.write(number[i]);
  }
  return buffer.toString();
}

List<CustomField> _decodeCustomFields(String json) =>
    (jsonDecode(json) as List<dynamic>)
        .map((e) => CustomField.fromJson(e as Map<String, dynamic>))
        .toList();

class _PhotoThumbnail extends ConsumerWidget {
  final String blobId;
  const _PhotoThumbnail({required this.blobId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vaultKey = ref.watch(vaultKeyProvider);
    if (vaultKey == null) return const SizedBox.shrink();
    return FutureBuilder<Uint8List?>(
      future: loadPhoto(
        blobId: blobId,
        vaultKey: vaultKey,
        dao: ref.read(localBlobsDaoProvider),
      ),
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes == null) return const SizedBox.shrink();
        return GestureDetector(
          onTap: () => showDialog(
            context: context,
            builder: (context) => Dialog(child: Image.memory(bytes)),
          ),
          child: AspectRatio(
            aspectRatio: 1.6,
            child: Image.memory(bytes, fit: BoxFit.cover),
          ),
        );
      },
    );
  }
}
