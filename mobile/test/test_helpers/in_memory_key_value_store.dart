import 'package:mobile/core/storage/key_value_store.dart';

/// In-memory [KeyValueStore] fake shared across tests, so none of them
/// need real platform secure storage (unavailable in plain widget/unit
/// tests).
class InMemoryKeyValueStore implements KeyValueStore {
  final Map<String, String> _values = {};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;

  @override
  Future<void> delete(String key) async => _values.remove(key);
}
