import 'dart:convert';

/// Erro de formato ao ler um JSON vindo de fora (servidor ou ponte nativa).
class JsonFormatException implements Exception {
  const JsonFormatException(this.message);

  final String message;

  @override
  String toString() => 'JsonFormatException: $message';
}

/// Leitura tipada de um objeto JSON.
///
/// E a unica fronteira onde `Object?` aparece: cada acesso verifica o tipo e devolve um valor
/// tipado ou lanca [JsonFormatException]. Os modelos de dominio sao construidos a partir daqui.
extension type const JsonMap(Map<String, Object?> raw) {
  const JsonMap.empty() : raw = const <String, Object?>{};

  bool has(String key) => raw[key] != null;

  String str(String key) => _require<String>(key);

  String? strOrNull(String key) => _optional<String>(key);

  bool boolean(String key) => _require<bool>(key);

  bool boolOr(String key, {required bool fallback}) => _optional<bool>(key) ?? fallback;

  /// Inteiro. Aceita numero sem parte fracionaria vindo como `double`.
  int integer(String key) {
    final int? value = intOrNull(key);
    if (value == null) {
      throw JsonFormatException('Campo obrigatorio ausente: $key');
    }
    return value;
  }

  int? intOrNull(String key) {
    final Object? value = raw[key];
    if (value == null) {
      return null;
    }
    if (value is int) {
      return value;
    }
    if (value is double && value == value.truncateToDouble()) {
      return value.toInt();
    }
    throw JsonFormatException('Campo $key deveria ser inteiro, veio ${value.runtimeType}');
  }

  int intOr(String key, {required int fallback}) => intOrNull(key) ?? fallback;

  double number(String key) {
    final Object? value = raw[key];
    if (value is num) {
      return value.toDouble();
    }
    throw JsonFormatException('Campo $key deveria ser numero');
  }

  JsonMap obj(String key) {
    final JsonMap? value = objOrNull(key);
    if (value == null) {
      throw JsonFormatException('Campo obrigatorio ausente: $key');
    }
    return value;
  }

  JsonMap? objOrNull(String key) {
    final Object? value = raw[key];
    if (value == null) {
      return null;
    }
    return _asObject(value, key);
  }

  /// Lista de objetos. Campo ausente vira lista vazia.
  List<JsonMap> objList(String key) {
    return <JsonMap>[for (final Object? item in _list(key)) _asObject(item, key)];
  }

  List<String> strList(String key) {
    return <String>[
      for (final Object? item in _list(key))
        if (item is String) item else throw JsonFormatException('Lista $key deveria ter textos'),
    ];
  }

  List<int> intList(String key) {
    return <int>[
      for (final Object? item in _list(key))
        if (item is int)
          item
        else if (item is double && item == item.truncateToDouble())
          item.toInt()
        else
          throw JsonFormatException('Lista $key deveria ter inteiros'),
    ];
  }

  /// Chaves do objeto, para mapas de chave dinamica (regras por pacote, por exemplo).
  Iterable<String> get keys => raw.keys;

  List<Object?> _list(String key) {
    final Object? value = raw[key];
    if (value == null) {
      return const <Object?>[];
    }
    if (value is List<Object?>) {
      return value;
    }
    throw JsonFormatException('Campo $key deveria ser lista');
  }

  T _require<T extends Object>(String key) {
    final T? value = _optional<T>(key);
    if (value == null) {
      throw JsonFormatException('Campo obrigatorio ausente: $key');
    }
    return value;
  }

  T? _optional<T extends Object>(String key) {
    final Object? value = raw[key];
    if (value == null) {
      return null;
    }
    if (value is T) {
      return value;
    }
    throw JsonFormatException('Campo $key deveria ser $T, veio ${value.runtimeType}');
  }

  static JsonMap _asObject(Object? value, String context) {
    if (value is Map<String, Object?>) {
      return JsonMap(value);
    }
    if (value is Map<Object?, Object?>) {
      return JsonMap(value.map((Object? k, Object? v) => MapEntry<String, Object?>('$k', v)));
    }
    throw JsonFormatException('Campo $context deveria ser objeto');
  }
}

/// Decodifica um texto JSON cujo valor de topo e um objeto.
JsonMap decodeJsonObject(String source) {
  final Object? decoded;
  try {
    decoded = jsonDecode(source);
  } on FormatException catch (error) {
    throw JsonFormatException('JSON invalido: ${error.message}');
  }
  if (decoded is Map<String, Object?>) {
    return JsonMap(decoded);
  }
  throw const JsonFormatException('O JSON deveria ser um objeto');
}
