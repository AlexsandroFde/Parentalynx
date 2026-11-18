import '../../../../core/errors/app_failure.dart';
import '../../../authentication/presentation/messages/auth_messages.dart';
import '../../domain/entities/password_change_errors.dart';

/// Mensagens das falhas das telas de conta.

/// Erros da troca de senha para uma recusa do servidor: senha fraca marca o campo da senha
/// nova; o resto vira a mensagem geral do formulario.
PasswordChangeErrors passwordChangeErrorsFor(AppFailure failure) {
  if (failure is ApiFailure && failure.code == 'weak_password') {
    return PasswordChangeErrors(next: authFailureMessage(failure));
  }
  return PasswordChangeErrors(
    form: authFailureMessage(failure, wrongCredentials: 'A senha atual está incorreta.'),
  );
}

/// Mensagem para a senha recusada ao gerar a chave de recuperacao e ao excluir a conta.
String passwordConfirmationErrorFor(AppFailure failure) {
  return authFailureMessage(failure, wrongCredentials: 'Senha incorreta.');
}
