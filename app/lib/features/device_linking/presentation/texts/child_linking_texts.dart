import '../../../../core/errors/app_failure.dart';
import '../../../../core/time/formatters.dart';
import '../../domain/entities/link_state.dart';

/// Textos da vinculacao no aparelho da crianca.

/// Texto para mostrar quando o pedido de vinculo falha.
String linkingErrorMessage(AppFailure failure) {
  if (failure is! ApiFailure) {
    return failure.message;
  }
  switch (failure.code) {
    case 'code_expired':
      return 'Este código venceu ou já foi usado. Peça um novo código ao responsável.';
    case 'invalid_credentials':
    case 'not_found':
    case 'validation_error':
      return 'Código incorreto. Confira com o responsável e tente de novo.';
    case 'rate_limited':
    case 'account_locked':
      final int? retry = failure.retryAfterSec;
      if (retry == null || retry <= 0) {
        return 'Muitas tentativas. Espere alguns minutos e tente de novo.';
      }
      return 'Muitas tentativas. Tente de novo em ${formatMinutes((retry / 60).ceil())}.';
    default:
      return failure.message;
  }
}

/// Explicacao mostrada na tela do codigo depois que o vinculo foi desfeito.
String? unlinkNotice(UnlinkReason? reason) {
  return switch (reason) {
    UnlinkReason.revokedByGuardian =>
      'O vínculo deste aparelho foi removido pelo responsável. '
          'Para voltar a usar o controle, peça um novo código.',
    null => null,
  };
}

const String rejectedMessage =
    'O responsável não aprovou este aparelho. Se foi engano, peça um novo código.';

const String expiredMessage =
    'O pedido venceu antes de ser aprovado. Peça um novo código ao responsável.';

/// Aprovado, mas o agente nao ligou.
String activationFailedMessage(AppFailure failure) {
  return 'O responsável aprovou, mas não foi possível ligar o controle neste aparelho. '
      '${failure.message} Peça um novo código e tente de novo.';
}
