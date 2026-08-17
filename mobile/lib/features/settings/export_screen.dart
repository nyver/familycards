import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import 'export_service.dart';

/// Encrypted local export of every visible card - see client/settings
/// spec, "Локальная зашифрованная выгрузка". The archive is written to
/// the app's own documents directory (no new file-picker dependency) and
/// offered for sharing via the platform share sheet, which is how the
/// user actually moves it to wherever they want it.
class ExportScreen extends ConsumerStatefulWidget {
  const ExportScreen({super.key});

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _submitting = false;
  String? _error;
  String? _resultPath;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _export() async {
    final l10n = AppLocalizations.of(context)!;
    final password = _passwordController.text;
    if (password.isEmpty || password != _confirmController.text) {
      setState(() => _error = l10n.exportPasswordMismatch);
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    final cards = await ref
        .read(cardRepositoryProvider)
        .watchVisibleCards()
        .first;
    final bytes = await ExportService.encryptCards(cards, password);

    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'exports'));
    if (!await dir.exists()) await dir.create(recursive: true);
    final fileName =
        'family-cards-${DateTime.now().millisecondsSinceEpoch}.fcw';
    final file = File(p.join(dir.path, fileName));
    await file.writeAsBytes(bytes, flush: true);

    if (!mounted) return;
    setState(() {
      _submitting = false;
      _resultPath = file.path;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final resultPath = _resultPath;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.exportTitle)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: resultPath == null
              ? _buildForm(context, l10n)
              : _buildSuccess(context, l10n, resultPath),
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.exportWarning),
        const SizedBox(height: 24),
        TextField(
          controller: _passwordController,
          obscureText: true,
          enabled: !_submitting,
          decoration: InputDecoration(
            labelText: l10n.exportPasswordLabel,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _confirmController,
          obscureText: true,
          enabled: !_submitting,
          decoration: InputDecoration(
            labelText: l10n.exportPasswordConfirmLabel,
            border: const OutlineInputBorder(),
            errorText: _error,
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _submitting ? null : _export,
          child: _submitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.exportButton),
        ),
      ],
    );
  }

  Widget _buildSuccess(
    BuildContext context,
    AppLocalizations l10n,
    String path,
  ) {
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
          l10n.exportSuccessTitle,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(l10n.exportSuccessBody(path)),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: () =>
              SharePlus.instance.share(ShareParams(files: [XFile(path)])),
          icon: const Icon(Icons.share_outlined),
          label: Text(l10n.exportShareButton),
        ),
      ],
    );
  }
}
