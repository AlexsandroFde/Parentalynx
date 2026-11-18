import '../../../../core/errors/app_failure.dart';
import '../../../../core/security/password_policy.dart';
import '../../domain/entities/credential_errors.dart';

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

/// Texto para uma falha de autenticacao (entrada, registro, recuperacao, desbloqueio).
///
/// [wrongCredentials] troca o texto de credencial errada conforme a tela.
String authFailureMessage(
  AppFailure failure, {
  String wrongCredentials = 'E-mail ou senha incorretos.',
}) {
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

bool _hasCode(AppFailure failure, String code) => failure is ApiFailure && failure.code == code;

/// Erros da tela de entrada para uma recusa do servidor.
CredentialErrors loginErrorsFor(AppFailure failure) {
  return CredentialErrors(form: authFailureMessage(failure));
}

/// Erros da tela de criar conta: e-mail ja usado e senha fraca marcam o campo.
CredentialErrors registrationErrorsFor(AppFailure failure) {
  final String message = authFailureMessage(failure);
  if (_hasCode(failure, 'email_in_use')) {
    return CredentialErrors(email: message);
  }
  if (_hasCode(failure, 'weak_password')) {
    return CredentialErrors(password: message);
  }
  return CredentialErrors(form: message);
}

/// Erros da tela de recuperacao: senha fraca marca o campo.
CredentialErrors recoveryErrorsFor(AppFailure failure) {
  if (_hasCode(failure, 'weak_password')) {
    return CredentialErrors(password: authFailureMessage(failure));
  }
  return CredentialErrors(
    form: authFailureMessage(
      failure,
      wrongCredentials: 'E-mail ou chave de recuperação incorretos.',
    ),
  );
}

/// Mensagem para a senha recusada no desbloqueio e na confirmacao de senha.
String unlockErrorFor(AppFailure failure) {
  return authFailureMessage(failure, wrongCredentials: 'Senha incorreta.');
}
