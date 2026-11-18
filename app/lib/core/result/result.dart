import '../errors/app_failure.dart';

/// Resultado de uma operacao que pode falhar: [Ok] com o valor ou [Err] com a falha tipada.
///
/// Repositorios e casos de uso devolvem `Result` em vez de lancar excecoes. Quem recebe trata
/// os dois casos de forma explicita, em geral com `switch`:
///
/// ```dart
/// switch (await signIn(params)) {
///   case Ok(:final value): ...
///   case Err(:final failure): ...
/// }
/// ```
sealed class Result<T> {
  const Result();

  /// Executa [operation] e converte qualquer excecao em [Err] com [toFailure].
  ///
  /// E a fronteira entre o codigo que lanca (clientes HTTP, ponte nativa) e o codigo que
  /// devolve resultados. Fica na camada de dados.
  static Future<Result<T>> guard<T>(Future<T> Function() operation) async {
    try {
      return Ok<T>(await operation());
    } on Object catch (error) {
      return Err<T>(toFailure(error));
    }
  }

  bool get isOk => this is Ok<T>;

  bool get isErr => this is Err<T>;

  /// Valor em caso de sucesso, ou nulo.
  T? get valueOrNull {
    return switch (this) {
      Ok<T>(:final T value) => value,
      Err<T>() => null,
    };
  }

  /// Falha em caso de erro, ou nulo.
  AppFailure? get failureOrNull {
    return switch (this) {
      Ok<T>() => null,
      Err<T>(:final AppFailure failure) => failure,
    };
  }

  /// Reduz os dois casos a um unico valor.
  R fold<R>({required R Function(T value) onOk, required R Function(AppFailure failure) onErr}) {
    return switch (this) {
      Ok<T>(:final T value) => onOk(value),
      Err<T>(:final AppFailure failure) => onErr(failure),
    };
  }

  /// Transforma o valor de sucesso, mantendo a falha.
  Result<R> map<R>(R Function(T value) transform) {
    return switch (this) {
      Ok<T>(:final T value) => Ok<R>(transform(value)),
      Err<T>(:final AppFailure failure) => Err<R>(failure),
    };
  }

  /// Encadeia outra operacao que tambem pode falhar. A primeira falha interrompe a cadeia.
  Future<Result<R>> then<R>(Future<Result<R>> Function(T value) next) async {
    return switch (this) {
      Ok<T>(:final T value) => next(value),
      Err<T>(:final AppFailure failure) => Err<R>(failure),
    };
  }
}

/// Sucesso com o valor produzido.
final class Ok<T> extends Result<T> {
  const Ok(this.value);

  final T value;

  @override
  bool operator ==(Object other) => other is Ok<T> && other.value == value;

  @override
  int get hashCode => Object.hash(Ok<T>, value);

  @override
  String toString() => 'Ok($value)';
}

/// Falha tipada, pronta para a interface.
final class Err<T> extends Result<T> {
  const Err(this.failure);

  final AppFailure failure;

  @override
  bool operator ==(Object other) => other is Err<T> && other.failure == failure;

  @override
  int get hashCode => Object.hash(Err<T>, failure);

  @override
  String toString() => 'Err($failure)';
}

/// Resultado de uma operacao sem valor de retorno.
typedef VoidResult = Result<void>;

/// Sucesso sem valor, para operacoes `Result<void>`.
const Ok<void> okVoid = Ok<void>(null);
