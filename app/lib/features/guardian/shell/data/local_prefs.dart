import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Preferencias locais nao sensiveis do modo responsavel (tempo de bloqueio do app, avisos ja
/// mostrados). Segredos ficam no armazenamento seguro, nunca aqui.
abstract interface class LocalPrefs {
  Future<int?> readInt(String key);

  Future<void> writeInt(String key, int value);

  Future<bool?> readBool(String key);

  Future<void> writeBool(String key, bool value);
}

/// Chaves das preferencias locais do responsavel.
abstract final class LocalPrefKeys {
  static const String appLockTimeoutSeconds = 'guardian.app_lock_timeout_seconds';
  static const String notificationsPrompted = 'guardian.notifications_prompted';
}

/// Implementacao sobre o shared_preferences.
class SharedPrefsLocalPrefs implements LocalPrefs {
  const SharedPrefsLocalPrefs();

  @override
  Future<int?> readInt(String key) async => (await SharedPreferences.getInstance()).getInt(key);

  @override
  Future<void> writeInt(String key, int value) async {
    await (await SharedPreferences.getInstance()).setInt(key, value);
  }

  @override
  Future<bool?> readBool(String key) async => (await SharedPreferences.getInstance()).getBool(key);

  @override
  Future<void> writeBool(String key, bool value) async {
    await (await SharedPreferences.getInstance()).setBool(key, value);
  }
}

/// Implementacao em memoria para testes.
class InMemoryLocalPrefs implements LocalPrefs {
  InMemoryLocalPrefs([Map<String, Object>? initial]) : _values = <String, Object>{...?initial};

  final Map<String, Object> _values;

  @override
  Future<int?> readInt(String key) async {
    final Object? value = _values[key];
    return value is int ? value : null;
  }

  @override
  Future<void> writeInt(String key, int value) async {
    _values[key] = value;
  }

  @override
  Future<bool?> readBool(String key) async {
    final Object? value = _values[key];
    return value is bool ? value : null;
  }

  @override
  Future<void> writeBool(String key, bool value) async {
    _values[key] = value;
  }
}

final Provider<LocalPrefs> localPrefsProvider = Provider<LocalPrefs>(
  (Ref ref) => const SharedPrefsLocalPrefs(),
);

/// Relogio do modo responsavel. Trocado nos testes para simular a passagem do tempo.
final Provider<DateTime Function()> guardianClockProvider = Provider<DateTime Function()>(
  (Ref ref) => DateTime.now,
);
