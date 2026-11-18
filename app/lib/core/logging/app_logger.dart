import 'dart:convert';
import 'dart:developer' as developer;

/// Gravidade de um registro.
enum LogLevel {
  debug(500),
  info(800),
  warning(900),
  error(1000);

  const LogLevel(this.value);

  /// Nivel numerico no padrao do `dart:developer`.
  final int value;
}

/// Registro estruturado.
///
/// Cada registro tem um nome de evento estavel (`policy_save_failed`, `bloc_error`) e campos
/// com valores simples. Nunca registre dados pessoais (nomes, e-mails, senhas, enderecos de
/// sites): so identificadores tecnicos, codigos e contagens.
abstract interface class AppLogger {
  void log(
    LogLevel level,
    String event, {
    Map<String, Object?> fields,
    Object? error,
    StackTrace? stackTrace,
  });
}

extension AppLoggerShortcuts on AppLogger {
  void debug(String event, [Map<String, Object?> fields = const <String, Object?>{}]) {
    log(LogLevel.debug, event, fields: fields);
  }

  void info(String event, [Map<String, Object?> fields = const <String, Object?>{}]) {
    log(LogLevel.info, event, fields: fields);
  }

  void warning(
    String event, {
    Map<String, Object?> fields = const <String, Object?>{},
    Object? error,
  }) {
    log(LogLevel.warning, event, fields: fields, error: error);
  }

  void error(
    String event, {
    Map<String, Object?> fields = const <String, Object?>{},
    Object? error,
    StackTrace? stackTrace,
  }) {
    log(LogLevel.error, event, fields: fields, error: error, stackTrace: stackTrace);
  }
}

/// Grava no log do sistema pelo `dart:developer`, uma linha JSON por evento.
class DeveloperLogger implements AppLogger {
  const DeveloperLogger({this.minimumLevel = LogLevel.info});

  final LogLevel minimumLevel;

  @override
  void log(
    LogLevel level,
    String event, {
    Map<String, Object?> fields = const <String, Object?>{},
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (level.value < minimumLevel.value) {
      return;
    }
    developer.log(
      formatLogRecord(level, event, fields),
      name: 'parentalynx',
      level: level.value,
      error: error,
      stackTrace: stackTrace,
    );
  }
}

/// Monta a linha do registro: `{"level":"info","event":"...","campo":valor}`.
///
/// Campos com os nomes reservados (`level` e `event`) sao ignorados, para nao mascarar a
/// gravidade nem o evento.
String formatLogRecord(LogLevel level, String event, Map<String, Object?> fields) {
  return jsonEncode(<String, Object?>{
    'level': level.name,
    'event': event,
    for (final MapEntry<String, Object?> field in fields.entries)
      if (field.key != 'level' && field.key != 'event') field.key: _plain(field.value),
  });
}

/// Reduz o valor a algo que o JSON aceita, sem expor objetos inteiros.
Object? _plain(Object? value) {
  if (value == null || value is num || value is bool || value is String) {
    return value;
  }
  if (value is Enum) {
    return value.name;
  }
  return value.toString();
}

/// Registro que nao grava nada, para testes.
class SilentLogger implements AppLogger {
  const SilentLogger();

  @override
  void log(
    LogLevel level,
    String event, {
    Map<String, Object?> fields = const <String, Object?>{},
    Object? error,
    StackTrace? stackTrace,
  }) {}
}
