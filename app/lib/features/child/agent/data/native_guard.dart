import 'package:flutter/services.dart';

import '../../../../core/errors/app_failure.dart';

/// Mensagem padrao quando o lado nativo falha sem um texto pensado para a pessoa.
const String nativeFallbackMessage = 'O aparelho não respondeu como esperado. Tente de novo.';

/// Executa uma chamada a ponte nativa convertendo [PlatformException] em [AppFailure].
///
/// O lado nativo recusa algumas operacoes de proposito (por exemplo, quando a autenticacao do
/// responsavel venceu) e nesses casos manda um texto pronto. Ja uma excecao inesperada chega
/// com o nome da classe e a pilha, que nao servem para mostrar na tela: nesse caso usa-se
/// [fallback].
Future<T> guardNative<T>(
  Future<T> Function() call, {
  String fallback = nativeFallbackMessage,
}) async {
  try {
    return await call();
  } on PlatformException catch (error) {
    throw nativeFailure(error, fallback: fallback);
  }
}

/// Converte um erro da ponte em falha tipada.
AppFailure nativeFailure(PlatformException error, {String fallback = nativeFallbackMessage}) {
  final String? message = error.message;
  final Object? details = error.details;
  final bool unexpected =
      error.code == 'channel-error' || (details is String && details.startsWith('Cause: '));
  if (unexpected || message == null || message.trim().isEmpty) {
    return UnexpectedFailure(fallback, error);
  }
  return UnexpectedFailure(message, error);
}
