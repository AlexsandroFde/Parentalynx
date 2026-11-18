import 'package:equatable/equatable.dart';

import '../json/json_reader.dart';

/// Falha tipada que chega ate a interface. Toda excecao de rede, da API ou da ponte nativa e
/// convertida para uma destas variantes antes de sair da camada de dados.
///
/// As falhas tem igualdade por valor, para que estados e resultados possam ser comparados
/// nos testes.
sealed class AppFailure with Equatable implements Exception {
  const AppFailure(this.message);

  /// Texto em portugues, pronto para mostrar ao usuario.
  final String message;

  @override
  List<Object?> get props => <Object?>[message];

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

  @override
  List<Object?> get props => <Object?>[status, code, message, details.raw];
}

/// Codigos de erro padronizados da ponte nativa (ver `docs/02-arquitetura.md`, secao 4.8).
enum NativeErrorCode {
  /// A operacao exige autenticacao do responsavel valida no aparelho.
  adminAuthRequired('admin_auth_required'),

  /// O modo do app nao pode ser trocado com o aparelho vinculado.
  modeLocked('mode_locked'),

  /// Chave do armazenamento seguro reservada ao agente nativo.
  forbiddenKey('forbidden_key'),

  /// A politica recebida nao pode ser lida pelo agente.
  policyInvalid('policy_invalid'),

  /// Argumento fora do intervalo aceito pelo lado nativo.
  invalidArgument('invalid_argument'),

  /// O canal com o lado nativo nao respondeu.
  channelError('channel-error'),

  /// Erro sem codigo conhecido.
  unknown('unknown');

  const NativeErrorCode(this.code);

  final String code;

  static NativeErrorCode parse(String code) {
    for (final NativeErrorCode value in values) {
      if (value.code == code) {
        return value;
      }
    }
    return NativeErrorCode.unknown;
  }
}

/// Recusa ou erro do lado nativo (agente Android), com o codigo padronizado da ponte.
final class NativeFailure extends AppFailure {
  const NativeFailure({required this.code, required String message}) : super(message);

  final NativeErrorCode code;

  bool get isAdminAuthRequired => code == NativeErrorCode.adminAuthRequired;

  @override
  List<Object?> get props => <Object?>[code, message];
}

/// Dado informado pela pessoa fora da regra (codigo incompleto, nome vazio...). A mensagem
/// explica o que corrigir.
final class ValidationFailure extends AppFailure {
  const ValidationFailure(super.message);
}

/// Resposta fora do formato esperado ou erro interno do app.
final class UnexpectedFailure extends AppFailure {
  const UnexpectedFailure([super.message = 'Algo deu errado. Tente de novo.', this.cause]);

  /// Excecao original, para registro. Nao entra na comparacao.
  final Object? cause;
}

/// A pessoa desistiu de uma operacao (por exemplo fechou o pedido de senha). Quem recebe
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
