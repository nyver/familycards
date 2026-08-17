import 'dart:convert';

import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart' hide Card;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/barcode/barcode_formats.dart';
import '../../core/crypto/canonical_json.dart';
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
        if (cards == null)
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        final index = cards.indexWhere((c) => c.id == widget.cardId);
        if (index == -1) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && Navigator.canPop(context))
              Navigator.of(context).pop();
          });
          return const Scaffold(body: SizedBox.shrink());
        }
        return _fullscreen
            ? _FullscreenView(
                cards: cards,
                initialIndex: index,
                onExit: _exitFullscreen,
              )
            : _NormalView(
                cards: cards,
                initialIndex: index,
                onEnterFullscreen: _enterFullscreen,
              );
      },
    );
  }
}

class _NormalView extends ConsumerWidget {
  final List<Card> cards;
  final int initialIndex;
  final VoidCallback onEnterFullscreen;
  const _NormalView({
    required this.cards,
    required this.initialIndex,
    required this.onEnterFullscreen,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final card = cards[initialIndex];
    return Scaffold(
      appBar: AppBar(
        title: Text(card.storeName),
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
            onPressed: () => _confirmDelete(context, ref, card),
          ),
        ],
      ),
      body: PageView.builder(
        controller: PageController(initialPage: initialIndex),
        itemCount: cards.length,
        itemBuilder: (context, i) => _CardDetailBody(
          card: cards[i],
          onEnterFullscreen: onEnterFullscreen,
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Card card,
  ) async {
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

class _FullscreenView extends StatelessWidget {
  final List<Card> cards;
  final int initialIndex;
  final VoidCallback onExit;
  const _FullscreenView({
    required this.cards,
    required this.initialIndex,
    required this.onExit,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: PageController(initialPage: initialIndex),
              itemCount: cards.length,
              itemBuilder: (context, i) => _BarcodeArea(
                card: cards[i],
                heightFraction: 0.6,
                textColor: Colors.white,
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.fullscreen_exit, color: Colors.white),
                onPressed: onExit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardDetailBody extends ConsumerWidget {
  final Card card;
  final VoidCallback onEnterFullscreen;
  const _CardDetailBody({required this.card, required this.onEnterFullscreen});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
