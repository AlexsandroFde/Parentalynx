import 'package:equatable/equatable.dart';

/// Pedido de vinculo aceito pelo servidor e ainda aguardando a aprovacao do responsavel
/// (protocolo, secao 3).
final class PairingClaim extends Equatable {
  const PairingClaim({
    required this.linkId,
    required this.pollToken,
    required this.confirmCode,
    required this.guardianName,
    required this.expiresAt,
  });

  final String linkId;

  /// Token que so serve para consultar o andamento deste pedido.
  final String pollToken;

  /// Numero mostrado nos dois aparelhos para o responsavel conferir.
  final String confirmCode;
  final String guardianName;
  final int expiresAt;

  @override
  List<Object?> get props => <Object?>[linkId, pollToken, confirmCode, guardianName, expiresAt];
}
