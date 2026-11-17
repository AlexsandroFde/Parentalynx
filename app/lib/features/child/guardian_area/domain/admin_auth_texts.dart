import '../../../../core/time/formatters.dart';
import '../../agent/domain/child_models.dart';

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

/// Deixa so os digitos do codigo de acesso offline, que tem 8.
String normalizeOfflineCode(String input) {
  final String digits = input.replaceAll(RegExp(r'[^0-9]'), '');
  return digits.length > offlineCodeLength ? digits.substring(0, offlineCodeLength) : digits;
}

const int offlineCodeLength = 8;

/// Opcoes de liberacao do uso pelo responsavel, em minutos.
const List<int> localOverrideOptions = <int>[15, 30, 60];
