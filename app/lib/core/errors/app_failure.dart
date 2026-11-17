import '../json/json_reader.dart';

/// Falha tipada que chega ate a interface. Toda excecao de rede ou de API e convertida para
/// uma destas variantes antes de sair da camada de dados.
sealed class AppFailure implements Exception {
  const AppFailure(this.message);

  /// Texto em portugues, pronto para mostrar ao usuario.
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// Sem conexao, tempo esgotado ou servidor inalcancavel.
final class NetworkFailure extends AppFailure {
  const NetworkFailure([
    super.message = 'Sem conexão com o servidor. Verifique a internet e tente de novo.',
  ]);
}

/// Erro devolvido pela API no formato do protocolo.
final class ApiFailure extends AppFailure {
  const ApiFailure({
    required this.status,
    required this.code,
    required String message,
    this.details = const JsonMap.empty(),
  }) : super(message);

  final int status;

  /// Codigo do protocolo (`elevation_required`, `version_conflict`, ...).
  final String code;
  final JsonMap details;

  bool get isElevationRequired => code == 'elevation_required';

  bool get isSessionInvalid => code == 'session_expired' || code == 'unauthorized';

  bool get isVersionConflict => code == 'version_conflict';

  bool get isLocked => code == 'account_locked' || code == 'rate_limited';

  /// Segundos ate poder tentar de novo, quando o servidor informa.
  int? get retryAfterSec => details.intOrNull('retryAfterSec');

  /// Motivos de recusa de senha (`too_short`, `few_classes`, ...).
  List<String> get reasons =>
      details.has('reasons') ? details.strList('reasons') : const <String>[];
}

/// Resposta fora do formato esperado ou erro interno do app.
final class UnexpectedFailure extends AppFailure {
  const UnexpectedFailure([super.message = 'Algo deu errado. Tente de novo.', this.cause]);

  final Object? cause;
}

/// A pessoa desistiu de uma operacao (por exemplo fechou o pedido de senha). Quem captura
/// normalmente ignora em silencio, sem mostrar mensagem de erro.
final class CancelledFailure extends AppFailure {
  const CancelledFailure([super.message = 'Operação cancelada.']);
}

/// Converte qualquer erro capturado em um [AppFailure].
AppFailure toFailure(Object error) {
  if (error is AppFailure) {
    return error;
  }
  if (error is JsonFormatException) {
    return UnexpectedFailure('O servidor respondeu em um formato inesperado.', error);
  }
  return UnexpectedFailure('Algo deu errado. Tente de novo.', error);
}
