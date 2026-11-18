import 'package:flutter/services.dart';

import '../errors/app_failure.dart';
import '../result/result.dart';

/// Mensagem padrao quando o lado nativo falha sem um texto pensado para a pessoa.
const String nativeFallbackMessage = 'O aparelho não respondeu como esperado. Tente de novo.';

/// Executa uma chamada a ponte nativa e devolve [Result], convertendo [PlatformException] em
/// [NativeFailure] com o codigo padronizado.
///
/// O lado nativo recusa algumas operacoes de proposito (autenticacao do responsavel vencida,
/// troca de modo com vinculo ativo) e nesses casos manda um codigo e um texto pronto. Ja uma
/// excecao inesperada chega com o nome da classe e a pilha, que nao servem para mostrar na
/// tela: nesse caso usa-se [fallback].
Future<Result<T>> callNative<T>(
  Future<T> Function() call, {
  String fallback = nativeFallbackMessage,
}) async {
  try {
    return Ok<T>(await call());
  } on PlatformException catch (error) {
    return Err<T>(nativeFailure(error, fallback: fallback));
  }
}

/// Converte um erro da ponte em falha tipada.
NativeFailure nativeFailure(PlatformException error, {String fallback = nativeFallbackMessage}) {
  final NativeErrorCode code = NativeErrorCode.parse(error.code);
  final String? message = error.message;
  final Object? details = error.details;
  final bool unexpected =
      code == NativeErrorCode.channelError || (details is String && details.startsWith('Cause: '));
  if (unexpected || message == null || message.trim().isEmpty) {
    return NativeFailure(code: code, message: fallback);
  }
  return NativeFailure(code: code, message: message);
}

/// Executa uma chamada cujo erro nao interessa a quem chama (reforcos opcionais, como a busca
/// de alertas em segundo plano). Devolve [fallback] se a ponte falhar.
Future<T> callNativeOr<T>(Future<T> Function() call, T fallback) async {
  try {
    return await call();
  } on PlatformException {
    return fallback;
  }
}
