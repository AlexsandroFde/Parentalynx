/// Textos da area do responsavel no aparelho da crianca.
library;

import '../../../../core/time/formatters.dart';
import '../../domain/entities/admin_auth.dart';

/// Mensagem para uma tentativa de autenticacao do responsavel que nao deu certo.
///
/// [viaCode] indica que a tentativa foi com o codigo de acesso offline, e nao com a senha.
/// Devolve nulo quando a autenticacao deu certo.
String? adminAuthMessage(AdminAuth result, {required bool viaCode}) {
  switch (result.status) {
    case AdminAuthStatus.ok:
      return null;
    case AdminAuthStatus.invalid:
      final String base = viaCode ? 'Código incorreto.' : 'Senha incorreta.';
      if (result.attemptsLeft < 0) {
        return base;
      }
      if (result.attemptsLeft == 0) {
        return '$base Esta foi a última tentativa antes do bloqueio.';
      }
      return result.attemptsLeft == 1
          ? '$base Resta 1 tentativa.'
          : '$base Restam ${result.attemptsLeft} tentativas.';
    case AdminAuthStatus.locked:
      if (result.retryAfterSec <= 0) {
        return 'Muitas tentativas. Espere alguns minutos e tente de novo.';
      }
      return 'Muitas tentativas. Tente de novo em '
          '${formatMinutes((result.retryAfterSec / 60).ceil())}.';
    case AdminAuthStatus.offline:
      return 'Sem conexão com o servidor para conferir a senha. Use o código de acesso '
          'offline.';
    case AdminAuthStatus.error:
      final String? message = result.message;
      if (message != null && message.trim().isNotEmpty) {
        return message;
      }
      return viaCode
          ? 'Não foi possível conferir o código agora.'
          : 'Não foi possível conferir a senha agora.';
  }
}

/// A autenticacao do responsavel venceu no lado nativo durante uma operacao protegida.
const String adminAccessExpiredMessage =
    'O acesso do responsável venceu. Entre de novo para continuar.';

/// O agente nao conseguiu desvincular o aparelho.
const String unlinkFailedMessage = 'Não foi possível desvincular agora. Tente de novo.';

String overrideGrantedMessage(int minutes) => 'Uso liberado por ${formatMinutes(minutes)}.';

const String overrideClearedMessage = 'Liberação encerrada.';

const String ownershipReleasedMessage = 'O aparelho deixou de ser gerenciado.';

const String deviceAdminRemovedMessage = 'Administrador desativado.';
