import '../../../../core/result/result.dart';

/// Endereco do servidor ParentaLynx usado por este aparelho.
abstract interface class IServerConfigRepository {
  /// Endereco atual, sem barra no final. Vazio quando nunca foi configurado.
  String get current;

  /// Endereco atual seguido das trocas.
  Stream<String> watch();

  Future<void> save(String url);

  /// Confere se ha um servidor ParentaLynx respondendo no endereco atual.
  Future<Result<void>> probe();
}
