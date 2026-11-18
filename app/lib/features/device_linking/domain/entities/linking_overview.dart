import 'package:equatable/equatable.dart';

import 'link_code.dart';
import 'link_request.dart';

/// Situacao da vinculacao no servidor: o codigo ativo (sem o texto) e os pedidos aguardando
/// aprovacao.
final class LinkingOverview extends Equatable {
  const LinkingOverview({required this.requests, this.activeCode});

  final ActiveLinkCode? activeCode;
  final List<LinkRequest> requests;

  @override
  List<Object?> get props => <Object?>[activeCode, requests];
}

/// Resultado de uma consulta, conferido com o codigo mostrado neste aparelho.
final class LinkingSnapshot extends Equatable {
  const LinkingSnapshot({
    required this.requests,
    required this.codeChangedMeanwhile,
    this.shownCode,
    this.otherCodeExpiresAt,
  });

  /// Pedidos aguardando aprovacao.
  final List<LinkRequest> requests;

  /// Um codigo foi gerado ou cancelado durante a consulta. So [requests] e confiavel: a
  /// situacao do codigo veio de antes da mudanca.
  final bool codeChangedMeanwhile;

  /// Codigo gerado neste aparelho que o servidor ainda considera ativo.
  final LinkCode? shownCode;

  /// Validade de um codigo ativo que nao e o mostrado aqui (gerado antes ou em outro
  /// aparelho). O texto dele nao pode ser recuperado.
  final int? otherCodeExpiresAt;

  @override
  List<Object?> get props => <Object?>[
    requests,
    codeChangedMeanwhile,
    shownCode,
    otherCodeExpiresAt,
  ];
}
