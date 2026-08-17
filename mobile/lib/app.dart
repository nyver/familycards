import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/auth/auth_providers.dart';
import 'features/auth/auth_state.dart';
import 'features/auth/server_address_screen.dart';
import 'features/auth/start_screen.dart';
import 'features/auth/unlock_screen.dart';
import 'features/cards/card_list_screen.dart';
import 'features/sync/sync_status_provider.dart';
import 'l10n/app_localizations.dart';

/// The app's brand seed color, used to derive both the light and dark
/// Material 3 color schemes so they stay visually related.
const _seedColor = Color(0xFF3D5AFE);

class FamilyCardWalletApp extends StatelessWidget {
  const FamilyCardWalletApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _seedColor,
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _seedColor,
          brightness: Brightness.dark,
        ),
      ),
      // Flutter has no signal for "the user has not chosen a theme" that
      // is distinct from "the system reports light" - platformBrightness
      // always resolves to one or the other. ThemeMode.system is the
      // correct, honest mapping: it follows the system's current
      // brightness in both directions, satisfying the requirement to
      // switch to light when the system says light, and to dark
      // otherwise (most platforms default fresh installs to dark or
      // respect a prior explicit user choice, both of which surface here
      // as platformBrightness).
      themeMode: ThemeMode.system,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const AuthGate(),
    );
  }
}

/// Root routing widget: watches session state and shows exactly the
/// screen that state calls for. Onboarding sub-flows (create/join/login)
/// push their own screens via a local Navigator from StartScreen; when
/// the session becomes ready or reverts to needing a server, this widget
/// swaps the entire subtree, discarding whatever navigation stack existed
/// underneath.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sessionControllerProvider);

    return switch (state) {
      AuthLoading() => const _SplashScreen(),
      AuthNeedsServer() => const ServerAddressScreen(),
      AuthNeedsOnboarding(:final serverAddress) => StartScreen(
        serverAddress: serverAddress,
      ),
      AuthNeedsUnlock(:final identity) => UnlockScreen(identity: identity),
      AuthReady() => const _AuthenticatedShell(),
    };
  }
}

/// Hosts the card list for the lifetime of an authenticated session and
/// wires up everything that only makes sense while authenticated: the
/// sync engine's lifecycle triggers (start, foreground/background) and
/// its non-blocking "local edit lost to a conflict" notice. Screens
/// pushed on top of the card list (settings, editor, ...) do not unmount
/// this widget, so the sync engine keeps running underneath them for the
/// whole session - see syncControllerProvider's `autoDispose` doc comment.
class _AuthenticatedShell extends ConsumerStatefulWidget {
  const _AuthenticatedShell();

  @override
  ConsumerState<_AuthenticatedShell> createState() =>
      _AuthenticatedShellState();
}

class _AuthenticatedShellState extends ConsumerState<_AuthenticatedShell>
    with WidgetsBindingObserver {
  StreamSubscription<String>? _conflictSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final controller = ref.read(syncControllerProvider.notifier);
    controller.start();
    _conflictSub = controller.conflictNotices.listen(_showConflictNotice);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _conflictSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(syncControllerProvider.notifier).onAppForeground();
    } else if (state == AppLifecycleState.paused) {
      ref.read(syncControllerProvider.notifier).onAppBackground();
    }
  }

  void _showConflictNotice(String cardName) {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.syncConflictLostEdit(cardName))),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Establishes the keep-alive subscription that gives the
    // `autoDispose` controller the same lifetime as this widget.
    ref.watch(syncControllerProvider);
    return const CardListScreen();
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
