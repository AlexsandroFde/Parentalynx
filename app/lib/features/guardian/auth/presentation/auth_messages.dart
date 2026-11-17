import '../../../../core/errors/app_failure.dart';
import '../../../../core/security/password_policy.dart';

/// Mensagens em linguagem simples para as falhas de conta e de senha.

/// Tempo de espera legivel: `30 segundos`, `1 minuto`, `5 minutos`, `1 hora`.
String waitLabel(int seconds) {
  if (seconds < 60) {
    return seconds <= 1 ? '1 segundo' : '$seconds segundos';
  }
  final int minutes = (seconds / 60).ceil();
  if (minutes < 60) {
    return minutes == 1 ? '1 minuto' : '$minutes minutos';
  }
  final int hours = (minutes / 60).ceil();
  return hours == 1 ? '1 hora' : '$hours horas';
}

/// Texto para uma falha de autenticacao (login, registro, recuperacao, desbloqueio).
///
/// [wrongCredentials] troca o texto de credencial errada conforme a tela.
String authFailureMessage(Object error, {String wrongCredentials = 'E-mail ou senha incorretos.'}) {
  final AppFailure failure = toFailure(error);
  if (failure is! ApiFailure) {
    return failure.message;
  }
  final int? retry = failure.retryAfterSec;
  switch (failure.code) {
    case 'invalid_credentials':
      return wrongCredentials;
    case 'email_in_use':
      return 'Já existe uma conta com este e-mail. Entre com ela ou use outro e-mail.';
    case 'account_locked':
      return retry == null
          ? 'Muitas tentativas. Aguarde um pouco antes de tentar de novo.'
          : 'Muitas tentativas. Tente de novo em ${waitLabel(retry)}.';
    case 'rate_limited':
      return retry == null
          ? 'Muitas requisições em pouco tempo. Aguarde um pouco e tente de novo.'
          : 'Muitas requisições em pouco tempo. Tente de novo em ${waitLabel(retry)}.';
    case 'weak_password':
      return weakPasswordMessage(failure);
    default:
      return failure.message;
  }
}

/// Junta os motivos de recusa de senha devolvidos pelo servidor.
String weakPasswordMessage(ApiFailure failure) {
  final List<String> messages = <String>[
    for (final String code in failure.reasons)
      if (PasswordIssue.fromCode(code) case final PasswordIssue issue) issue.message,
  ];
  if (messages.isEmpty) {
    return 'A senha não atende aos requisitos de segurança.';
  }
  return messages.join(' ');
}

/// Verdadeiro quando a falha e de senha fraca, para a tela marcar o campo da senha.
bool isWeakPassword(Object error) {
  final AppFailure failure = toFailure(error);
  return failure is ApiFailure && failure.code == 'weak_password';
}

/// Verdadeiro quando o e-mail ja tem conta, para a tela marcar o campo do e-mail.
bool isEmailInUse(Object error) {
  final AppFailure failure = toFailure(error);
  return failure is ApiFailure && failure.code == 'email_in_use';
}

final RegExp _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');

/// Validacao simples de e-mail para dar retorno antes de enviar. Devolve a mensagem de erro
/// ou nulo.
String? validateEmail(String value) {
  final String email = value.trim();
  if (email.isEmpty) {
    return 'Informe o e-mail.';
  }
  if (!_emailPattern.hasMatch(email)) {
    return 'Esse e-mail não parece válido.';
  }
  return null;
}
