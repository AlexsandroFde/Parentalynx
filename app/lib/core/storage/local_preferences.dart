import 'package:shared_preferences/shared_preferences.dart';

/// Preferencias locais nao sensiveis (tempo de bloqueio do painel, avisos ja mostrados).
/// Segredos ficam no armazenamento seguro, nunca aqui.
abstract interface class LocalPreferences {
  Future<int?> readInt(String key);

  Future<void> writeInt(String key, int value);

  Future<bool?> readBool(String key);

  Future<void> writeBool(String key, bool value);
}

/// Implementacao sobre o shared_preferences.
class SharedPreferencesStore implements LocalPreferences {
  const SharedPreferencesStore();

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
