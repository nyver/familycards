import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/crypto/envelope.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../cards/card_repository.dart';
import 'export_service.dart';
import 'import_service.dart';

/// Picks a `.fcw` file with the platform file picker and returns its raw
/// bytes, or null if the user cancelled.
Future<Uint8List?> _pickArchiveFile() async {
  final file = await FilePicker.pickFile(
    type: FileType.custom,
    allowedExtensions: ['fcw'],
  );
  return file?.readAsBytes();
}

/// Imports cards from a local encrypted export archive - the reverse of
/// [ExportScreen]. See client/settings spec, "Импорт из локального
/// зашифрованного архива".
class ImportScreen extends ConsumerStatefulWidget {
  const ImportScreen({super.key});

  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen> {
  final _passwordController = TextEditingController();

  Uint8List? _fileBytes;
  List<Map<String, dynamic>>? _decoded;
  bool _includeDuplicates = false;
  bool _submitting = false;
  String? _error;
  ImportResult? _result;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    setState(() => _error = null);
    final bytes = await _pickArchiveFile();
    if (bytes == null || !mounted) return;
    setState(() {
      _fileBytes = bytes;
      _decoded = null;
    });
  }

  Future<void> _decrypt() async {
    final l10n = AppLocalizations.of(context)!;
    final bytes = _fileBytes;
    if (bytes == null) return;

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final decoded = await ExportService.decryptCards(
        bytes,
        _passwordController.text,
      );
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _decoded = decoded;
      });
    } on DecryptionFailedException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        // ExportService.decryptCards checks the container's magic before
        // ever touching the password, so this message prefix reliably
        // means "not our file format" rather than "wrong password" - see
        // export_service.dart.
        _error = e.message.startsWith('not a Family Card Wallet export')
            ? l10n.importInvalidFile
            : l10n.importWrongPassword;
      });
    }
  }

  Future<void> _confirmImport() async {
    final decoded = _decoded;
    if (decoded == null) return;

    setState(() => _submitting = true);
    final now = DateTime.now().millisecondsSinceEpoch;
    final payloads = decoded
        .map(
          (json) =>
              ImportService.payloadFromExportJson(json, importedAt: now),
        )
        .toList();
    final result = await ref
        .read(cardRepositoryProvider)
        .importCards(payloads, includeDuplicates: _includeDuplicates);
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _result = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final result = _result;
    final decoded = _decoded;
    final fileBytes = _fileBytes;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.importTitle)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: result != null
              ? _buildSuccess(l10n, result)
              : decoded != null
              ? _buildPreview(l10n, decoded)
              : fileBytes != null
              ? _buildPasswordForm(l10n)
              : _buildPickStep(l10n),
        ),
      ),
    );
  }

  Widget _buildPickStep(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(l10n.importPickPrompt),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _pickFile,
          icon: const Icon(Icons.file_open_outlined),
          label: Text(l10n.importPickButton),
        ),
      ],
    );
  }

  Widget _buildPasswordForm(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _passwordController,
          obscureText: true,
          enabled: !_submitting,
          autofocus: true,
          decoration: InputDecoration(
            labelText: l10n.importPasswordLabel,
            border: const OutlineInputBorder(),
            errorText: _error,
          ),
          onSubmitted: (_) => _decrypt(),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _submitting ? null : _decrypt,
          child: _submitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.importDecryptButton),
        ),
        TextButton(
          onPressed: _submitting
              ? null
              : () => setState(() {
                  _fileBytes = null;
                  _error = null;
                  _passwordController.clear();
                }),
          child: Text(l10n.importPickAnotherButton),
        ),
      ],
    );
  }

  Widget _buildPreview(
    AppLocalizations l10n,
    List<Map<String, dynamic>> decoded,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          l10n.importCardsFound(decoded.length),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          value: _includeDuplicates,
          onChanged: _submitting
              ? null
              : (value) => setState(() => _includeDuplicates = value),
          title: Text(l10n.importIncludeDuplicatesToggle),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _submitting ? null : _confirmImport,
          child: _submitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.importConfirmButton),
        ),
      ],
    );
  }

  Widget _buildSuccess(AppLocalizations l10n, ImportResult result) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.check_circle_outline,
          size: 48,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 16),
        Text(
          l10n.importSuccessTitle,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(
          l10n.importSuccessBody(result.added, result.skippedDuplicates),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
