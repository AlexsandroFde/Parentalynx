import 'package:equatable/equatable.dart';

import '../services/browser_navigation_rules.dart';

/// Decisao do filtro para uma navegacao de pagina principal.
final class NavigationVerdict extends Equatable {
  const NavigationVerdict({required this.allowed, this.reason, this.category, this.rewrittenUrl});

  /// Bloqueio usado quando o filtro nao respondeu: na duvida, a pagina nao abre.
  const NavigationVerdict.checkFailed()
    : allowed = false,
      reason = checkFailedReason,
      category = null,
      rewrittenUrl = null;

  static const String checkFailedReason = 'check_failed';

  final bool allowed;

  /// `domain_blocked`, `category`, `safe_dns`, `not_in_allowlist` ou [checkFailedReason].
  final String? reason;
  final String? category;

  /// Endereco a carregar no lugar do pedido (busca segura), quando diferente.
  final String? rewrittenUrl;

  /// Verdadeiro quando o bloqueio veio da falta de resposta do filtro, e nao de uma regra.
  bool get isCheckFailure => !allowed && reason == checkFailedReason;

  /// Endereco que deve ser carregado para o pedido [requestedUrl]: o reescrito pelo filtro
  /// (busca segura) quando ele e um endereco web valido, senao o proprio pedido.
  String targetFor(String requestedUrl) {
    final String? rewritten = rewrittenUrl;
    return rewritten != null && rewritten.isNotEmpty && isWebUrl(rewritten)
        ? rewritten
        : requestedUrl;
  }

  @override
  List<Object?> get props => <Object?>[allowed, reason, category, rewrittenUrl];
}
