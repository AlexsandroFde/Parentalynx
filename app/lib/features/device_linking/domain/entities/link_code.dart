import 'package:equatable/equatable.dart';

/// Codigo de vinculacao recem-gerado pelo responsavel (protocolo, secao 3).
///
/// O texto do codigo so existe na resposta da criacao: o servidor guarda apenas o hash.
final class LinkCode extends Equatable {
  const LinkCode({required this.id, required this.code, required this.expiresAt});

  final String id;

  /// Oito caracteres, sem hifen. A tela formata.
  final String code;

  /// Instante (ms desde a epoca) em que o codigo deixa de valer.
  final int expiresAt;

  /// Tempo que falta ate o codigo vencer, a partir de [nowMs]. Nunca negativo.
  Duration remainingAt(int nowMs) {
    final int remaining = expiresAt - nowMs;
    return Duration(milliseconds: remaining < 0 ? 0 : remaining);
  }

  @override
  List<Object?> get props => <Object?>[id, code, expiresAt];
}

/// Referencia ao codigo ativo no servidor, sem o texto.
final class ActiveLinkCode extends Equatable {
  const ActiveLinkCode({required this.id, required this.expiresAt});

  final String id;
  final int expiresAt;

  @override
  List<Object?> get props => <Object?>[id, expiresAt];
}
