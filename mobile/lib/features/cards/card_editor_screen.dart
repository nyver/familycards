import 'dart:convert';
import 'dart:typed_data';

import 'package:barcode_widget/barcode_widget.dart';
import 'package:flutter/material.dart' hide Card;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/barcode/barcode_formats.dart';
import '../../core/crypto/canonical_json.dart';
import '../../core/db/database.dart';
import '../../core/providers.dart';
import '../../data/store_catalog.dart';
import '../../l10n/app_localizations.dart';
import 'photo_attachment.dart';
import 'scanner_screen.dart';

/// A fixed 12-color palette offered in the editor, chosen to be visually
/// distinct and to read well as a full-tile background in the card list
/// and detail screens.
List<CustomField> _decodeCustomFields(String json) =>
    (jsonDecode(json) as List<dynamic>)
        .map((e) => CustomField.fromJson(e as Map<String, dynamic>))
        .toList();

const cardColorPalette = <int>[
  0xFFE53935, 0xFFD81B60, 0xFF8E24AA, 0xFF5E35B1, //
  0xFF3949AB, 0xFF1E88E5, 0xFF00897B, 0xFF43A047, //
  0xFFFDD835, 0xFFFB8C00, 0xFF6D4C41, 0xFF546E7A, //
];

/// Creates a new card, or edits [existing] if provided. Handles store-name
/// autocomplete from the bundled catalog, barcode number/format entry with
/// a scan shortcut and live preview, a 12-color palette (plus picking the
/// selected store's brand color), a note, freeform custom fields, and
/// front/back photo attachment. Confirms before discarding unsaved edits.
class CardEditorScreen extends ConsumerStatefulWidget {
  final Card? existing;
  const CardEditorScreen({super.key, this.existing});

  @override
  ConsumerState<CardEditorScreen> createState() => _CardEditorScreenState();
}

class _CardEditorScreenState extends ConsumerState<CardEditorScreen> {
  late final TextEditingController _storeNameController;
  late final TextEditingController _cardNumberController;
  late final TextEditingController _secondaryNumberController;
  late final TextEditingController _noteController;

  late String _format;
  late int _color;
  late List<CustomField> _customFields;
  String? _frontBlob;
  String? _backBlob;
  bool _saving = false;

  late final String _initialSnapshot;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _storeNameController = TextEditingController(
      text: existing?.storeName ?? '',
    );
    _cardNumberController = TextEditingController(
      text: existing?.cardNumber ?? '',
    );
    _secondaryNumberController = TextEditingController(
      text: existing?.secondaryNumber ?? '',
    );
    _noteController = TextEditingController(text: existing?.note ?? '');
    _format = existing?.barcodeFormat ?? CardBarcodeFormat.code128;
    _color = existing?.color ?? cardColorPalette.first;
    _customFields = existing == null
        ? []
        : _decodeCustomFields(existing.customFields);
    _frontBlob = existing?.frontBlobId;
    _backBlob = existing?.backBlobId;
    _initialSnapshot = _snapshot();
  }

  @override
  void dispose() {
    _storeNameController.dispose();
    _cardNumberController.dispose();
    _secondaryNumberController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  String _snapshot() => [
    _storeNameController.text,
    _cardNumberController.text,
    _secondaryNumberController.text,
    _noteController.text,
    _format,
    _color,
    _customFields.map((f) => '${f.k}=${f.v}').join(','),
    _frontBlob,
    _backBlob,
  ].join('|');

  bool get _isDirty => _snapshot() != _initialSnapshot;
  bool get _isValid =>
      _storeNameController.text.trim().isNotEmpty &&
      _cardNumberController.text.trim().isNotEmpty;

  Future<bool> _confirmDiscardIfDirty() async {
    if (!_isDirty) return true;
    final l10n = AppLocalizations.of(context)!;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.discardChangesTitle),
        content: Text(l10n.discardChangesBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.discardChangesConfirm),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _scan() async {
    final result = await Navigator.of(context).push<ScanResult>(
      MaterialPageRoute(builder: (_) => const ScannerScreen()),
    );
    if (result == null) return;
    setState(() {
      _cardNumberController.text = result.number;
      _format = result.format;
    });
  }

  Future<void> _pickPhoto({required bool front}) async {
    final vaultKey = ref.read(vaultKeyProvider);
    if (vaultKey == null) return;
    final l10n = AppLocalizations.of(context)!;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(l10n.photoSourceCamera),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(l10n.photoSourceGallery),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final blobId = await pickAndAttachPhoto(
      source: source,
      vaultKey: vaultKey,
      dao: ref.read(localBlobsDaoProvider),
    );
    if (blobId == null) return;
    setState(() {
      if (front) {
        _frontBlob = blobId;
      } else {
        _backBlob = blobId;
      }
    });
  }

  void _removePhoto({required bool front}) {
    setState(() {
      if (front) {
        _frontBlob = null;
      } else {
        _backBlob = null;
      }
    });
  }

  void _addCustomField() {
    setState(
      () => _customFields = [..._customFields, const CustomField('', '')],
    );
  }

  void _updateCustomField(int index, {String? key, String? value}) {
    setState(() {
      final field = _customFields[index];
      _customFields = [..._customFields]
        ..[index] = CustomField(key ?? field.k, value ?? field.v);
    });
  }

  void _removeCustomField(int index) {
    setState(() => _customFields = [..._customFields]..removeAt(index));
  }

  Future<void> _save() async {
    if (!_isValid || _saving) return;
    setState(() => _saving = true);
    final now = DateTime.now().millisecondsSinceEpoch;
    final payload = CardPayload(
      backBlob: _backBlob,
      barcodeFormat: _format,
      cardNumber: _cardNumberController.text.trim(),
      color: _color,
      createdAt: widget.existing?.createdAt ?? now,
      customFields: _customFields.where((f) => f.k.trim().isNotEmpty).toList(),
      favorite: widget.existing?.favorite ?? false,
      frontBlob: _frontBlob,
      logoAsset: widget.existing?.logoAsset,
      note: _noteController.text.trim(),
      secondaryNumber: _secondaryNumberController.text.trim().isEmpty
          ? null
          : _secondaryNumberController.text.trim(),
      sortOrder: widget.existing?.sortOrder ?? 0,
      storeName: _storeNameController.text.trim(),
    );

    final repository = ref.read(cardRepositoryProvider);
    final existing = widget.existing;
    if (existing == null) {
      await repository.createCard(payload);
    } else {
      await repository.updateCard(existing.id, payload);
    }
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isEdit = widget.existing != null;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (await _confirmDiscardIfDirty() && mounted) {
          navigator.pop(false);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            isEdit ? l10n.cardEditorTitleEdit : l10n.cardEditorTitleNew,
          ),
          actions: [
            TextButton(
              onPressed: _isValid && !_saving ? _save : null,
              child: Text(l10n.commonSave),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _StoreNameField(
              controller: _storeNameController,
              onSelected: _onStoreSelected,
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _cardNumberController,
                    decoration: InputDecoration(
                      labelText: l10n.cardNumberLabel,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.qr_code_scanner),
                  tooltip: l10n.scanBarcodeButton,
                  onPressed: _scan,
                ),
              ],
            ),
            TextField(
              controller: _secondaryNumberController,
              decoration: InputDecoration(labelText: l10n.secondaryNumberLabel),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _format,
              decoration: InputDecoration(labelText: l10n.barcodeFormatLabel),
              items: CardBarcodeFormat.all
                  .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                  .toList(),
              onChanged: (value) => setState(() => _format = value ?? _format),
            ),
            if (_cardNumberController.text.trim().isNotEmpty) ...[
              const SizedBox(height: 16),
              SizedBox(
                height: 100,
                child: BarcodeWidget(
                  data: _cardNumberController.text.trim(),
                  barcode: toRenderBarcode(_format),
                  color: Color(_color),
                  drawText: isOneDimensional(_format),
                  errorBuilder: (context, error) => const SizedBox.shrink(),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              l10n.colorLabel,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            _ColorPalette(
              selected: _color,
              onSelected: (c) => setState(() => _color = c),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _noteController,
              decoration: InputDecoration(labelText: l10n.noteLabel),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            _PhotoSlots(
              frontBlob: _frontBlob,
              backBlob: _backBlob,
              onPickFront: () => _pickPhoto(front: true),
              onPickBack: () => _pickPhoto(front: false),
              onRemoveFront: () => _removePhoto(front: true),
              onRemoveBack: () => _removePhoto(front: false),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.customFieldsSection,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: _addCustomField,
                ),
              ],
            ),
            for (var i = 0; i < _customFields.length; i++)
              _CustomFieldRow(
                field: _customFields[i],
                l10n: l10n,
                onChanged: (k, v) => _updateCustomField(i, key: k, value: v),
                onRemove: () => _removeCustomField(i),
              ),
            if (!_isValid) ...[
              const SizedBox(height: 16),
              Text(
                l10n.cardEditorValidationRequired,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _onStoreSelected(StoreCatalogEntry entry) {
    setState(() {
      _storeNameController.text = entry.displayName;
      _color = entry.color.toARGB32();
      if (_cardNumberController.text.trim().isEmpty) {
        _format = entry.format;
      }
    });
  }
}

class _StoreNameField extends ConsumerWidget {
  final TextEditingController controller;
  final void Function(StoreCatalogEntry) onSelected;
  const _StoreNameField({required this.controller, required this.onSelected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final catalogAsync = ref.watch(storeCatalogProvider);
    return catalogAsync.when(
      data: (catalog) => Autocomplete<StoreCatalogEntry>(
        initialValue: TextEditingValue(text: controller.text),
        displayStringForOption: (entry) => entry.displayName,
        optionsBuilder: (value) {
          if (value.text.trim().isEmpty) return const Iterable.empty();
          return catalog.search(value.text).take(20);
        },
        onSelected: onSelected,
        fieldViewBuilder: (context, fieldController, focusNode, onSubmitted) {
          // Keep the outer controller (used for validation/save) mirrored.
          fieldController.text = controller.text;
          fieldController.addListener(
            () => controller.text = fieldController.text,
          );
          return TextField(
            controller: fieldController,
            focusNode: focusNode,
            decoration: InputDecoration(labelText: l10n.storeNameLabel),
          );
        },
      ),
      loading: () => TextField(
        controller: controller,
        decoration: InputDecoration(labelText: l10n.storeNameLabel),
      ),
      error: (error, stack) => TextField(
        controller: controller,
        decoration: InputDecoration(labelText: l10n.storeNameLabel),
      ),
    );
  }
}

class _ColorPalette extends StatelessWidget {
  final int selected;
  final void Function(int) onSelected;
  const _ColorPalette({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final color in cardColorPalette)
          GestureDetector(
            onTap: () => onSelected(color),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Color(color),
                shape: BoxShape.circle,
                border: color == selected
                    ? Border.all(
                        color: Theme.of(context).colorScheme.onSurface,
                        width: 3,
                      )
                    : null,
              ),
            ),
          ),
      ],
    );
  }
}

class _PhotoSlots extends ConsumerWidget {
  final String? frontBlob;
  final String? backBlob;
  final VoidCallback onPickFront;
  final VoidCallback onPickBack;
  final VoidCallback onRemoveFront;
  final VoidCallback onRemoveBack;

  const _PhotoSlots({
    required this.frontBlob,
    required this.backBlob,
    required this.onPickFront,
    required this.onPickBack,
    required this.onRemoveFront,
    required this.onRemoveBack,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        Expanded(
          child: _PhotoSlot(
            label: l10n.photoFrontLabel,
            blobId: frontBlob,
            onPick: onPickFront,
            onRemove: onRemoveFront,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _PhotoSlot(
            label: l10n.photoBackLabel,
            blobId: backBlob,
            onPick: onPickBack,
            onRemove: onRemoveBack,
          ),
        ),
      ],
    );
  }
}

class _PhotoSlot extends ConsumerWidget {
  final String label;
  final String? blobId;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  const _PhotoSlot({
    required this.label,
    required this.blobId,
    required this.onPick,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final blobId = this.blobId;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        AspectRatio(
          aspectRatio: 1.6,
          child: blobId == null
              ? OutlinedButton.icon(
                  onPressed: onPick,
                  icon: const Icon(Icons.add_a_photo_outlined),
                  label: Text(l10n.photoAddButton),
                )
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    _PhotoPreview(blobId: blobId),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black45,
                        ),
                        tooltip: l10n.photoRemoveButton,
                        onPressed: onRemove,
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _PhotoPreview extends ConsumerWidget {
  final String blobId;
  const _PhotoPreview({required this.blobId});

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
        if (bytes == null) return const ColoredBox(color: Colors.black12);
        return Image.memory(bytes, fit: BoxFit.cover);
      },
    );
  }
}

class _CustomFieldRow extends StatelessWidget {
  final CustomField field;
  final AppLocalizations l10n;
  final void Function(String? key, String? value) onChanged;
  final VoidCallback onRemove;

  const _CustomFieldRow({
    required this.field,
    required this.l10n,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: TextFormField(
              initialValue: field.k,
              decoration: InputDecoration(labelText: l10n.customFieldKeyLabel),
              onChanged: (v) => onChanged(v, null),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextFormField(
              initialValue: field.v,
              decoration: InputDecoration(
                labelText: l10n.customFieldValueLabel,
              ),
              onChanged: (v) => onChanged(null, v),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}
