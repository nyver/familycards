import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import 'auth_providers.dart';
import 'session_controller.dart';

/// Step 2 of vault creation: requires the user to correctly re-enter the
/// words at three positions before the account is actually created on the
/// server. Failing does not lose the phrase - the user can go back to the
/// display screen (standard back navigation) and try again.
class RecoveryPhraseConfirmScreen extends ConsumerStatefulWidget {
  final PendingVault pending;
  final List<int> positionsToConfirm; // 0-indexed
  final String login;
  final String displayName;
  final String password;
  final String bootstrapToken;
  final String deviceName;
  final String devicePlatform;

  const RecoveryPhraseConfirmScreen({
    super.key,
    required this.pending,
    required this.positionsToConfirm,
    required this.login,
    required this.displayName,
    required this.password,
    required this.bootstrapToken,
    required this.deviceName,
    required this.devicePlatform,
  });

  @override
  ConsumerState<RecoveryPhraseConfirmScreen> createState() =>
      _RecoveryPhraseConfirmScreenState();
}

class _RecoveryPhraseConfirmScreenState
    extends ConsumerState<RecoveryPhraseConfirmScreen> {
  late final List<TextEditingController> _controllers = List.generate(
    widget.positionsToConfirm.length,
    (_) => TextEditingController(),
  );
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    for (var i = 0; i < widget.positionsToConfirm.length; i++) {
      final expected = widget.pending.phraseWords[widget.positionsToConfirm[i]];
      final entered = _controllers[i].text.trim().toLowerCase();
      if (entered != expected) {
        final l10n = AppLocalizations.of(context)!;
        setState(() => _error = l10n.recoveryPhraseConfirmMismatch);
        return;
      }
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    final result = await ref
        .read(sessionControllerProvider.notifier)
        .completeBootstrap(
          vault: widget.pending,
          login: widget.login,
          displayName: widget.displayName,
          password: widget.password,
          bootstrapToken: widget.bootstrapToken,
          deviceName: widget.deviceName,
          devicePlatform: widget.devicePlatform,
        );

    if (!mounted) return;
    setState(() => _submitting = false);

    result.fold((_) {}, (error) {
      setState(() => _error = error.message);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.recoveryPhraseConfirmTitle)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.recoveryPhraseConfirmInstructions,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              for (var i = 0; i < widget.positionsToConfirm.length; i++) ...[
                TextField(
                  controller: _controllers[i],
                  decoration: InputDecoration(
                    labelText: l10n.recoveryPhraseWordAt(
                      widget.positionsToConfirm[i] + 1,
                    ),
                    border: const OutlineInputBorder(),
                  ),
                  autocorrect: false,
                ),
                const SizedBox(height: 12),
              ],
              if (_error != null) ...[
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                const SizedBox(height: 12),
              ],
              FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.commonConfirm),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
