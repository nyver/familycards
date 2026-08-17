import 'dart:io';

/// Launches the real, compiled Go wallet server as a subprocess against a
/// throwaway temp database, for genuine end-to-end tests of the client
/// against the actual server contract - not a fake or a mock. This is
/// deliberately heavier than a unit test: it exists specifically to catch
/// client/server protocol mismatches that per-layer unit tests cannot see
/// (exactly the kind of gap that motivated adding it - see the recovery
/// flow's wrap-material exchange).
class TestServer {
  final Process _process;
  final int port;
  final String bootstrapToken;

  TestServer._(this._process, this.port, this.bootstrapToken);

  String get baseUrl => 'http://127.0.0.1:$port';

  static Future<String> _findServerRoot() async {
    var dir = Directory.current;
    for (var i = 0; i < 6; i++) {
      final candidate = Directory('${dir.path}/server');
      if (await candidate.exists()) return candidate.path;
      final parent = dir.parent;
      if (parent.path == dir.path) break;
      dir = parent;
    }
    throw StateError(
      'could not locate the server/ directory from ${Directory.current.path}',
    );
  }

  static Future<int> _findFreePort() async {
    final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = socket.port;
    await socket.close();
    return port;
  }

  static String? _cachedBinaryPath;

  /// Builds the server binary once per test run and caches its path.
  /// Bootstrap only ever succeeds once per running server (by design - see
  /// server/internal/auth spec), so every test that needs its own vault
  /// must call [start] again for a fresh process, not share one server
  /// across tests. Building is the expensive part; reusing the compiled
  /// binary keeps per-test startup fast.
  static Future<String> _buildOnce() async {
    final cached = _cachedBinaryPath;
    if (cached != null) return cached;

    final serverRoot = await _findServerRoot();
    final buildDir = await Directory.systemTemp.createTemp('wallet_it_build_');
    final binaryName = Platform.isWindows ? 'wallet_it.exe' : 'wallet_it';
    final binaryPath = '${buildDir.path}/$binaryName';

    final build = await Process.run('go', [
      'build',
      '-o',
      binaryPath,
      './cmd/wallet',
    ], workingDirectory: serverRoot);
    if (build.exitCode != 0) {
      throw StateError(
        'failed to build wallet server:\n${build.stdout}\n${build.stderr}',
      );
    }

    _cachedBinaryPath = binaryPath;
    return binaryPath;
  }

  /// Starts a fresh server process against a fresh, empty temp database,
  /// waiting until GET /v1/health responds before returning. Each call
  /// gets its own vault (bootstrap only succeeds once per server), so
  /// tests that each need a clean account should each call [start].
  static Future<TestServer> start() async {
    final binaryPath = await _buildOnce();
    final tempDir = await Directory.systemTemp.createTemp('wallet_it_run_');
    final port = await _findFreePort();
    const bootstrapToken = 'integration-test-bootstrap-token';
    const jwtSecret = 'integration-test-jwt-secret-0123456789ab';

    final process = await Process.start(
      binaryPath,
      [],
      environment: {
        'WALLET_ADDR': '127.0.0.1:$port',
        'WALLET_DB_PATH': '${tempDir.path}/wallet.db',
        'WALLET_BLOB_DIR': '${tempDir.path}/blobs',
        'WALLET_JWT_SECRET': jwtSecret,
        'WALLET_BOOTSTRAP_TOKEN': bootstrapToken,
        'WALLET_LOG_LEVEL': 'error',
        'WALLET_ALLOW_INSECURE': 'true',
      },
      runInShell: false,
    );

    final server = TestServer._(process, port, bootstrapToken);
    await server._waitUntilHealthy();
    return server;
  }

  Future<void> _waitUntilHealthy() async {
    final client = HttpClient();
    final deadline = DateTime.now().add(const Duration(seconds: 10));
    try {
      while (DateTime.now().isBefore(deadline)) {
        try {
          final request = await client.getUrl(Uri.parse('$baseUrl/v1/health'));
          final response = await request.close();
          await response.drain<void>();
          if (response.statusCode == 200) return;
        } catch (_) {
          // not up yet
        }
        await Future.delayed(const Duration(milliseconds: 100));
      }
    } finally {
      client.close(force: true);
    }
    throw StateError('server did not become healthy in time');
  }

  Future<void> stop() async {
    _process.kill();
    await _process.exitCode;
  }
}
