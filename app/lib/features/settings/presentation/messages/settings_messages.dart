import '../../../../core/errors/app_failure.dart';
import '../../../authentication/presentation/messages/auth_messages.dart';
import '../../domain/entities/password_change_errors.dart';

/// Mensagens das falhas das telas de conta.

bool _wrongPassword(AppFailure failure) {
  return failure is ApiFailure && failure.code == 'invalid_credentials';
}

/// Erros da troca de senha para uma recusa do servidor: senha atual errada marca o campo da
/// senha atual e senha fraca, o da senha nova; o resto vira a mensagem geral do formulario.
PasswordChangeErrors passwordChangeErrorsFor(AppFailure failure) {
  if (failure is ApiFailure && failure.code == 'weak_password') {
    return PasswordChangeErrors(next: authFailureMessage(failure));
  }
  if (_wrongPassword(failure)) {
    return const PasswordChangeErrors(current: 'A senha atual está incorreta.');
  }
  return PasswordChangeErrors(form: authFailureMessage(failure));
}

/// Mensagem para a senha recusada ao gerar a chave de recuperacao e ao excluir a conta.
String passwordConfirmationErrorFor(AppFailure failure) {
  return authFailureMessage(failure, wrongCredentials: 'Senha incorreta.');
}

/// A recusa foi da senha digitada (e nao da conexao ou do servidor).
bool isPasswordRejection(AppFailure failure) {
  return _wrongPassword(failure) || (failure is ApiFailure && failure.isLocked);
}
